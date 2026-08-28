--[[
    akacross.updater - the self-update cycle, shared.

    WHY IT EXISTS
    -------------
    hud and reports had each grown their own copy of the same three things:

      1. fetch a `version: X` file, compare it against the running version,
         and raise something if it is newer;
      2. download the new script to a staging path, check the bytes are a Lua
         file that PARSES, and only then replace the live one;
      3. a batch file downloader with a completion callback, used for the
         version file, for the script, and for a mod's assets.

    They were not the same copy. hud's version pattern was `version: (.+)` -
    which captures trailing whitespace and a newline; reports' was
    `version:%s*([%w%.%-]+)`. hud's batch downloader counted with a shared
    `callbackCalled` flag; reports' called `lua_thread.create` and slept 250 ms
    to let the handle flush, which hud's did not, so hud could validate a file
    the downloader had not finished writing.

    Both behaviours are here, and the safe one won each time.

    WHAT THIS IS NOT
    ----------------
    Not a library-installer. `akacross.deps.newInstaller` already fetches and
    validates lib/ and resource files against a manifest, and this delegates to
    `deps.validate` / `deps.installFile` rather than re-implementing them. What
    it adds is the part deps has no opinion about: the SCRIPT'S OWN version,
    the prompt, and replacing a running file with a newer one.

    THE HAZARD IT EXISTS TO CLOSE
    -----------------------------
    hud used to download straight over the live script and reload. Anything
    that is not the new script - a truncated transfer, a 404 page, the repo
    serving HTML - therefore replaced a working install with rubbish, and the
    reload then failed with a parse error on a file the user no longer had a
    copy of. akacross.downloads records the same class of bug from the other
    direction: "the script updater could then delete the live script and rename
    a file that was never downloaded".

    So: stage, validate, install. The live script is only ever at risk for as
    long as the copy takes, and only after the bytes have been proven to parse.

    USAGE

        local updater = require('akacross.updater').new{
            label      = 'HUD',
            scriptPath = thisScriptRef.path,
            version    = thisScriptRef.version,
            versionUrl = function() return url end,   -- or a plain string
            scriptUrl  = function() return url end,
            versionFile = workingDir .. '\\temp\\hud.txt',
            reload     = function() thisScriptRef:reload() end,
            say        = formattedAddChatMessage,
            onAvailable = function(remote) ... end,   -- raise your prompt
            onBegin     = function() ... end,         -- persist updateInProgress
            onFail      = function(why) ... end,
        }

        updater:check(announce)   -- announce = also say "up to date"
        updater:install()         -- what the prompt's Confirm calls
]]

local M = { _VERSION = '0.1.0' }

local Updater = {}
Updater.__index = Updater

local function resolve(v)
    if type(v) == 'function' then
        local ok, result = pcall(v)
        return ok and result or nil
    end
    return v
end

function M.new(cfg)
    assert(cfg and cfg.scriptPath and cfg.version and cfg.reload,
           'akacross.updater: scriptPath, version and reload are required')
    return setmetatable({
        label       = cfg.label or 'updater',
        scriptPath  = cfg.scriptPath,
        version     = cfg.version,
        versionUrl  = cfg.versionUrl,
        scriptUrl   = cfg.scriptUrl,
        versionFile = cfg.versionFile,
        reload      = cfg.reload,
        say         = cfg.say or function() end,
        log         = cfg.log or print,
        onAvailable = cfg.onAvailable or function() end,
        onBegin     = cfg.onBegin or function() end,
        onFail      = cfg.onFail or function() end,
        pending     = nil,
    }, Updater)
end

-- ---------------------------------------------------------------------------
-- The batch downloader
-- ---------------------------------------------------------------------------
--[[
    fetch(files, onComplete)

    files: {{url =, path =, replace =}}. A file that already exists is skipped
    unless `replace` is set, which is what makes this usable for assets that
    only need fetching once.

    onComplete(startedAnything).

    TWO ORDERING HAZARDS, both of which were live bugs in one copy or the
    other:

    1. The batch is counted BEFORE any download starts. A callback that fires
       synchronously - a tiny or cached file - must not zero the counter while
       later files are still unqueued.

    2. The completion callback runs after a SETTLE WAIT. MoonLoader fires
       STATUS_ENDDOWNLOADDATA before the downloader flushes and closes the
       file, so a caller that reads or validates in-callback can see zero
       bytes. hud's copy had no settle and did exactly that; reports' had one.
]]
local SETTLE_MS = 250

function M.fetch(files, onComplete)
    local pending, started, done = 0, false, false

    local function finish()
        if done then return end
        done = true
        if not onComplete then return end
        -- Settle even on the nothing-to-do path, so a caller cannot observe
        -- two different callback timings depending on the cache.
        if type(lua_thread) == 'table' then
            lua_thread.create(function()
                wait(SETTLE_MS)
                onComplete(started)
            end)
        else
            onComplete(started)
        end
    end

    -- Count first, queue second.
    local queue = {}
    for _, file in ipairs(files) do
        if not doesFileExist(file.path) or file.replace then
            queue[#queue + 1] = file
        end
    end
    pending, started = #queue, #queue > 0
    if pending == 0 then finish() return end

    for _, file in ipairs(queue) do
        local folder = file.path:match('^(.*)[\\/][^\\/]+$')
        if folder and #folder > 0 then createDirectory(folder) end
        downloadUrlToFile(file.url, file.path, function(_, status)
            if status == 6 then          -- STATUS_ENDDOWNLOADDATA
                pending = pending - 1
                if pending <= 0 then finish() end
            end
        end)
    end
end

--- Instance form, so a caller that already holds an updater does not also have
--- to reach for the module table.
function Updater:fetch(files, onComplete)
    return M.fetch(files, onComplete)
end

-- ---------------------------------------------------------------------------
-- The version check
-- ---------------------------------------------------------------------------
--[[
    The pattern is `version:%s*([%w%.%-]+)`, which is reports' rather than
    hud's `version: (.+)`.

    `(.+)` is greedy to end of line and captures the trailing carriage return a
    file written on Windows carries, so the comparison ran against "1.4.38\\r".
    compareVersions parses digits out with gmatch so it happened to survive
    that - but the string is also what gets shown to the user, and "Version
    1.4.38\\r is available" is a bug waiting for a different consumer.
]]
local VERSION_PATTERN = 'version:%s*([%w%.%-]+)'

--- The newest version seen by the last check, or nil.
function Updater:pendingVersion() return self.pending end

--[[
    check(announce)

    Fetches the version file and compares. `announce` also reports the
    up-to-date case, which is what a user-typed /<mod> update wants and a
    silent check at startup does not.
]]
function Updater:check(announce)
    local url = resolve(self.versionUrl)
    local path = self.versionFile
    if not (url and path) then return end

    local deps = require('akacross.deps')

    M.fetch({{url = url, path = path, replace = true}}, function(started)
        if not started then
            if announce then self.say('Could not reach the update server.') end
            return
        end
        local file = io.open(path, 'r')
        if not file then
            if announce then self.say('Could not read the version file.') end
            return
        end
        local content = file:read('*a')
        file:close()

        local remote = content and content:match(VERSION_PATTERN)
        if not remote then
            if announce then self.say('The version file did not name a version.') end
            return
        end

        if deps.compareVersions(self.version, remote) < 0 then
            self.pending = remote
            self.onAvailable(remote)
        elseif announce then
            self.say(('Up to date (%s).'):format(self.version))
        end
    end)
end

-- ---------------------------------------------------------------------------
-- The install
-- ---------------------------------------------------------------------------
--[[
    install()

    Stage to `<script>.new`, validate, install, reload.

    `onBegin` fires only once the bytes have been proven, because it is where a
    caller persists `updateInProgress` - and setting that flag for a download
    that then turns out to be a 404 page leaves the mod claiming an update is
    running that never started.

    installFile falls back to a byte copy: os.rename fails under Wine while any
    handle is still on either file.
]]
function Updater:install()
    local url = resolve(self.scriptUrl)
    if not url then
        self.onFail('no update URL')
        return
    end

    local deps = require('akacross.deps')
    local staging = self.scriptPath .. '.new'
    os.remove(staging)

    M.fetch({{url = url, path = staging, replace = true}}, function(started)
        if not started then
            self.onFail('nothing was downloaded')
            self.say('Update failed: nothing was downloaded.')
            return
        end

        local valid, why = deps.validate(staging)
        if not valid then
            os.remove(staging)
            self.onFail(why)
            self.say(('Update failed: %s. Your copy is untouched.'):format(tostring(why)))
            return
        end

        -- Only now is the live script at risk, and only for as long as the
        -- copy takes.
        self.onBegin()

        local installed, err = deps.installFile(staging, self.scriptPath)
        if not installed then
            self.onFail(err)
            self.say(('Update failed to install: %s'):format(tostring(err)))
            return
        end

        self.say('Update downloaded successfully. Reloading the script now.')
        self.reload()
    end)
end

return M
