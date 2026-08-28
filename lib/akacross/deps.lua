--[[
    akacross.deps - one dependency loader for every akacross MoonLoader script.

    WHY THIS EXISTS
    ---------------
    Three copies of the same loader had grown up independently (autobind ~647
    lines, reports ~100, autofps ~35), all the same shape - a manifest table
    plus a pcall(require) loop - with progressively more feature sanded off.
    Every new mod split out of autobind would have made it four. See
    docs/SHARED_RUNTIME.md.

    This is tier 0: resolve, report, and fail readably. It does NOT download,
    version-check or self-heal; that is tier 1, still living inline in
    autobind.lua.

    USAGE
    -----
        local deps = require('akacross.deps')

        local M, report = deps.load({
            {name = 'moonloader', var = 'moonloader'},
            {name = 'mimgui',     var = 'imgui'},
            {name = 'fAwesome5',  var = 'fa', required = false},
        }, {label = 'AFPS'})

        if not report.ok then return end   -- deps already explained why

        local imgui = M.imgui

    WHY THE CALLER RETURNS INSTEAD OF deps
    --------------------------------------
    A module cannot abort the chunk that required it. When a required module is
    missing, load() prints the reason and installs a main() that surfaces it in
    chat once SA-MP is up - but the caller still has to `return`, and it must,
    or it will keep going and register hooks from a half-initialised state.
]]

local deps = {}
deps._VERSION = '0.4.0'

-- Colour of the in-chat fatal notice. Matches what autofps used before this
-- module existed.
local FATAL_COLOR = 0xAA3333

-- require() returns `true` for a module that returns nothing, so a truthiness
-- check alone is not enough to know we can index the result. `extras` is the
-- only thing that indexes it, so that is where this is enforced.
local function indexable(v)
    return type(v) == 'table' or type(v) == 'userdata'
end

local function defaultLabel()
    local ok, s = pcall(thisScript)
    if ok and s and s.name then return tostring(s.name):upper() end
    return 'SCRIPT'
end

--[[
    load(manifest, opts) -> modules, report

    manifest entries:
        name      module path passed to require()
        var       key the result is stored under in the returned table
        required  default true; a missing one is fatal
        extras    {alias = 'field'} - pulls fields out of the loaded module and
                  publishes them alongside it, for modules that are really a
                  bag of constants (moonloader's download_status, font_flag).
                  Works with or without `var`: omit `var` to publish only the
                  fields and not the module itself.

    opts:
        label            prefix for messages; defaults to the script name
        globals          also assign every var (and extra) into _G, for scripts
                         whose bodies reference the modules as bare globals
        abortOnMissing   default true; install the fatal main() and set
                         report.ok = false. Set false to keep a script's
                         pre-existing carry-on-regardless behaviour.
        quiet            suppress the two status lines

    report:
        ok        false only when a required module is missing AND
                  abortOnMissing is on
        loaded    array of module names that resolved
        failed    array of "name (error)" strings
        missing   array of required module names that did not resolve
]]
function deps.load(manifest, opts)
    opts = opts or {}
    local label = opts.label or defaultLabel()
    local abortOnMissing = opts.abortOnMissing ~= false

    local modules = {}
    local report = {ok = true, loaded = {}, failed = {}, missing = {}}

    -- Kept separate from `modules` so an entry can declare `extras` without
    -- also declaring a `var`. Some modules are only ever wanted for a field or
    -- two (moonloader's font_flag) and publishing the whole bag alongside them
    -- would put a name in the caller's table that it never asked for.
    local resolved = {}

    for i, dep in ipairs(manifest) do
        local ok, result = pcall(require, dep.name)
        if ok and result then
            resolved[i] = result
            if dep.var then modules[dep.var] = result end
            report.loaded[#report.loaded + 1] = dep.name
        else
            report.failed[#report.failed + 1] =
                ("%s (%s)"):format(dep.name, tostring(result))
            -- required defaults to true: a dependency you did not think about
            -- is one you cannot run without.
            if dep.required ~= false then
                report.missing[#report.missing + 1] = dep.name
            end
        end
    end

    -- Second pass so extras cannot observe a half-filled table.
    for i, dep in ipairs(manifest) do
        local mod = resolved[i]
        if dep.extras and mod then
            if indexable(mod) then
                for alias, field in pairs(dep.extras) do
                    modules[alias] = mod[field]
                end
            else
                report.failed[#report.failed + 1] =
                    ("%s (returned %s, cannot read extras)")
                        :format(dep.name, type(mod))
            end
        end
    end

    if opts.globals then
        for var, mod in pairs(modules) do
            _G[var] = mod
        end
    end

    if not opts.quiet then
        print(("Loaded modules: %s"):format(
            #report.loaded > 0 and table.concat(report.loaded, ", ") or "none"))
        if #report.failed > 0 then
            print(("Failed to load modules: %s"):format(
                table.concat(report.failed, ", ")))
        end
    end

    if #report.missing > 0 and abortOnMissing then
        report.ok = false
        local fatal = ("[%s] cannot start - missing required module(s): %s")
            :format(label, table.concat(report.missing, ", "))
        print(fatal)
        -- The script body is about to return, so nothing else will define
        -- main(). This one exists purely to get the reason in front of the
        -- user rather than leaving them with a silently absent script.
        _G.main = function()
            if isSampLoaded() then
                while not isSampAvailable() do wait(100) end
                sampAddChatMessage(fatal, FATAL_COLOR)
            end
        end
    elseif #report.missing > 0 then
        -- abortOnMissing off: still say it plainly, the caller opted to carry on
        print(("[%s] missing module(s), continuing anyway: %s")
            :format(label, table.concat(report.missing, ", ")))
    end

    return modules, report
end

-- ===========================================================================
-- TIER 1 - fetch, validate, install, version-heal
-- ===========================================================================
-- Everything below is optional to use and injectable: it knows about no
-- particular mod, holds no module-level state, and reads no global other than
-- the MoonLoader natives it cannot avoid (downloadUrlToFile, doesFileExist,
-- createDirectory, lua_thread). Paths, URLs, logging, progress and the JSON
-- codec are all handed in by the caller.
--
-- The logic is autobind's, which earned it the hard way. The comments on
-- installFile and download record actual bugs; do not "simplify" them away.

-- Default comparator: numeric parts compared left to right, with a letter
-- suffix (1.2b, 1.2beta) weighted below the same number without one. Callers
-- with their own scheme pass cfg.compareVersions instead.
local LETTER_WEIGHT = {
    A = 1, B = 2, C = 3, D = 4, E = 5,
    a = 1, b = 2, c = 3, d = 4, e = 5,
    alpha = 1, beta = 2, rc = 3, p = 4, h = 5,
}

function deps.compareVersions(v1, v2)
    local function parse(v)
        local parts = {}
        for num, letter in tostring(v):gmatch("(%d+)(%a*)") do
            parts[#parts + 1] = {num = tonumber(num), letter = letter:lower()}
        end
        return parts
    end
    local a, b = parse(v1), parse(v2)
    for i = 1, math.max(#a, #b) do
        local pa = a[i] or {num = 0, letter = ""}
        local pb = b[i] or {num = 0, letter = ""}
        if pa.num ~= pb.num then return pa.num > pb.num and 1 or -1 end
        local wa = LETTER_WEIGHT[pa.letter] or 0
        local wb = LETTER_WEIGHT[pb.letter] or 0
        if wa ~= wb then return wa > wb and 1 or -1 end
    end
    return 0
end

--[[
    validate(path) -> ok, why

    A downloaded file is not trustworthy just because it arrived. Three ways it
    can be garbage: zero length, an HTML/404 error page the server returned with
    a 200, or a truncated Lua file that parses nowhere near where it broke.
]]
function deps.validate(path)
    local file = io.open(path, "rb")
    if not file then return false, "unreadable" end
    local head = file:read(256) or ""
    file:close()
    if #head == 0 then return false, "empty file" end
    if head:find("^%s*<") or head:find("^%s*404") then
        return false, "error page (404?)"
    end
    if path:lower():find("%.lua$") then
        local chunk, parseErr = loadfile(path)
        if not chunk then return false, "Lua parse: " .. tostring(parseErr) end
    end
    return true
end

--[[
    installFile(staging, target) -> ok, err

    os.rename fails under Wine/Windows while ANY handle is still attached to
    either file (seen 2026-07-16: the downloader's handle on a just-finished
    .new); fall back to a byte copy, which only needs write access to the
    target.
]]
function deps.installFile(staging, target)
    os.remove(target)
    if os.rename(staging, target) then return true end
    local src = io.open(staging, "rb")
    if not src then return false, "cannot read staged file" end
    local content = src:read("*a")
    src:close()
    local dst, openErr = io.open(target, "wb")
    if not dst then
        return false, "cannot write target: " .. tostring(openErr)
    end
    dst:write(content)
    dst:close()
    os.remove(staging)
    return true
end

--[[
    missingOrEmpty(path) -> bool

    A path existing is not enough: a zero-byte or unreadable file (crashed
    download, disk hiccup) must count as MISSING so it goes back through the
    validated download path instead of poisoning a require() later.
]]
function deps.missingOrEmpty(path)
    if not doesFileExist(path) then return true end
    local file = io.open(path, "rb")
    if not file then return true end
    local size = file:seek("end")
    file:close()
    return not size or size == 0
end

local Installer = {}
Installer.__index = Installer

--[[
    newInstaller(cfg) -> installer

    cfg:
        libDir, libUrl            where localFile / localFiles resolve, both ends
        resourceDir, resourceUrl  same for resourceFile; optional
        stateFile                 path for the sync record; optional, and
                                  without it versionsToFetch does no loop
                                  suppression
        encodeJson, decodeJson    required only when stateFile is set
        compareVersions           defaults to deps.compareVersions
        log                       defaults to print
        onProgress                called with {status, current, done, total}

    Nothing here touches a global config table, so two mods can each hold their
    own installer over their own lib dir without interfering.
]]
function deps.newInstaller(cfg)
    cfg = cfg or {}
    return setmetatable({
        libDir = cfg.libDir,
        libUrl = cfg.libUrl,
        resourceDir = cfg.resourceDir,
        resourceUrl = cfg.resourceUrl,
        stateFile = cfg.stateFile,
        encodeJson = cfg.encodeJson,
        decodeJson = cfg.decodeJson,
        cmp = cfg.compareVersions or deps.compareVersions,
        log = cfg.log or print,
        onProgress = cfg.onProgress or function() end,
    }, Installer)
end

local function joinPath(dir, file)
    return dir .. file:gsub("/", "\\")
end

--[[
    scan(manifest) -> missing

    Walks the same manifest tier 0 takes, reading `localFile` / `localFiles` /
    `resourceFile`, and returns {url =, path =} for every one that is absent or
    empty. Pure: no downloads, no side effects.
]]
function Installer:scan(manifest)
    local missing = {}
    for _, dep in ipairs(manifest) do
        local files = dep.localFiles or (dep.localFile and {dep.localFile})
        if files and self.libDir and self.libUrl then
            for _, file in ipairs(files) do
                local full = joinPath(self.libDir, file)
                if deps.missingOrEmpty(full) then
                    missing[#missing + 1] = {url = self.libUrl .. file, path = full}
                end
            end
        end
        if dep.resourceFile and self.resourceDir and self.resourceUrl then
            local full = joinPath(self.resourceDir, dep.resourceFile)
            if deps.missingOrEmpty(full) then
                missing[#missing + 1] =
                    {url = self.resourceUrl .. dep.resourceFile, path = full}
            end
        end
    end
    return missing
end

--[[
    download(files, onComplete)

    onComplete(ok, invalidFiles) once every file has arrived AND validated.

    Two ordering hazards are handled here and both were real bugs:

    1. The batch is counted BEFORE any download starts. A callback that fires
       synchronously (tiny or cached file) must not zero the counter while later
       files are still unqueued.

    2. Validation runs OUTSIDE the download callbacks. MoonLoader fires status 6
       before the downloader flushes and closes the file, so reading it
       in-callback can see 0 bytes - and the os.remove on that still-open handle
       fails silently, which is why a manual reload used to appear to "fix" it:
       the bytes had flushed by then. Hence the settle wait and the retry loop
       that only retries the two transient reasons.
]]
function Installer:download(files, onComplete)
    local total = #files
    local completed, finished = 0, false

    self.onProgress({status = "downloading", current = "", done = 0, total = total})

    if total == 0 then
        onComplete(false, {})
        return
    end

    local function onAllDone()
        -- raw lua_thread.create: this runs on the pre-module path, so no
        -- error-reporting wrapper from the calling mod is available yet
        lua_thread.create(function()
            wait(250) -- settle: let the downloader flush and close handles
            local invalid = {}
            for _, file in ipairs(files) do
                local okFile, why
                for attempt = 1, 8 do
                    okFile, why = deps.validate(file.path)
                    if okFile or (why ~= "empty file" and why ~= "unreadable") then
                        break -- valid, or definitively bad (error page / parse failure)
                    end
                    self.log(("still waiting on %s (attempt %d: %s)")
                        :format(file.path, attempt, why))
                    wait(250)
                end
                if okFile then
                    self.log("validated " .. file.path)
                else
                    if os.remove(file.path) then
                        self.log(("discarded invalid download %s (%s)")
                            :format(file.path, tostring(why)))
                    else
                        self.log(("invalid download %s (%s) could not be deleted - possibly still mid-write; it will be re-checked next launch")
                            :format(file.path, tostring(why)))
                    end
                    invalid[#invalid + 1] = {url = file.url, path = file.path, reason = why}
                end
            end
            onComplete(#invalid == 0, invalid)
        end)
    end

    for _, file in ipairs(files) do
        local folder = file.path:match("^(.*)[\\/].+$")
        if folder and #folder > 0 then createDirectory(folder) end

        local shortName = file.url:match("([^/]+)$") or file.url
        self.onProgress({status = "downloading", current = shortName,
                         done = completed, total = total})
        self.log("downloading " .. file.url)
        downloadUrlToFile(file.url, file.path, function(id, status)
            if status == 6 and not finished then
                completed = completed + 1
                self.onProgress({status = "downloading", current = shortName,
                                 done = completed, total = total})
                if completed >= total then
                    finished = true
                    self.onProgress({status = "validating", current = "",
                                     done = completed, total = total})
                    onAllDone()
                end
            end
        end)
    end
end

--[[
    versionCheck(pins) -> stale, satisfied

    pins: {name =, file =, installed = <string> or mod = <module>, required =}

    `installed` wins if given; otherwise the module's _VERSION is read, missing
    meaning "0.0.0" so an absent module always reads as stale.
]]
function Installer:versionCheck(pins)
    local stale, satisfied = {}, {}
    for _, pin in ipairs(pins) do
        local installed = pin.installed
            or (pin.mod and pin.mod._VERSION)
            or "0.0.0"
        if self.cmp(installed, pin.required) == -1 then
            stale[#stale + 1] = {
                name = pin.name, file = pin.file,
                installed = installed, required = pin.required,
            }
        else
            satisfied[#satisfied + 1] = pin.file
        end
    end
    return stale, satisfied
end

function Installer:readState()
    if not self.stateFile or not self.decodeJson then return {} end
    local file = io.open(self.stateFile, "r")
    if not file then return {} end
    local content = file:read("*a")
    file:close()
    if not content or content:find("^%s*$") then return {} end
    local ok, data = pcall(self.decodeJson, content)
    return (ok and type(data) == "table") and data or {}
end

function Installer:writeState(data)
    if not self.stateFile or not self.encodeJson then return end
    local file = io.open(self.stateFile, "w")
    if not file then return end
    file:write(self.encodeJson(data))
    file:close()
end

--[[
    versionsToFetch(stale, satisfied) -> fetch, stateChanged

    The loop guard. The state record remembers the required version last
    ATTEMPTED per file, so a repo that still serves the old lib cannot cause a
    download/reload loop forever: the second time we would ask for the same
    version of the same file, we skip it and say so. A file that reaches its pin
    clears its own record, so a later pin bump retries cleanly.

    Returns the subset worth downloading, and whether the record needs writing.
    The caller does the writing, because it must happen once, after it has
    decided to act.
]]
function Installer:versionsToFetch(stale, satisfied)
    local state = self:readState()
    local changed = false

    for _, file in ipairs(satisfied or {}) do
        if state[file] ~= nil then
            state[file] = nil
            changed = true
        end
    end

    local fetch = {}
    for _, lib in ipairs(stale or {}) do
        if state[lib.file] == lib.required then
            self.log(("Lib %s is still %s (need %s) after a previous redownload - the repo may not carry it yet, skipping.")
                :format(lib.name, lib.installed, lib.required))
        else
            fetch[#fetch + 1] = lib
        end
    end

    return fetch, changed, state
end

-- ---------------------------------------------------------------------------
-- Self-heal
-- ---------------------------------------------------------------------------
--[[
    selfHeal(cfg) -> true if a repair was started

    ONE IMPLEMENTATION. This was five near-identical copies - hud, driving,
    wanted, vstorage and fastmap each carried 78 to 96 lines of it - and they
    had already begun to drift: the marker path, the reinstall URL and the
    wording of every message were per-mod, but so were the details that
    matter (one checked `#head == 0`, another did not; the loop guard was
    spelled two different ways).

    WHAT IT IS FOR

    An install missing part of lib/ is otherwise terminal: deps.load() names
    the modules it cannot find and the mod refuses to start, with no way back
    except reinstalling. That is exactly what a partial extraction produces -
    drop in the entry, miss lib/akacross, and every shared module is gone. It
    is also what a single-file updater produces the first time a mod stops
    being a single file, which is how hud met it.

    WHY IT CANNOT USE THE REST OF THIS FILE

    It runs BEFORE the caller's first require(), because the point is to repair
    the very files require() is about to look for - so it uses nothing but
    MoonLoader natives. It cannot go through Installer:download either: that
    validates with deps.validate, and deps.lua is itself one of the files a
    broken install may be missing. The caller reaches this function through a
    pcall'd require and skips healing entirely when that fails, which is the
    honest answer - a healer that is itself absent cannot restore itself.

    RELOAD RATHER THAN CONTINUE. An entry builds its config tables, its window
    registry and its keybinds at load time, so there is no seam to resume from
    once the files arrive.

    LOOP GUARD. A reload after a download that fixed nothing would cycle
    forever. The marker records what was attempted; if the same files are still
    missing on the next pass, the mod reports and stays down.

    cfg:
        label         REQUIRED  short tag for the log lines, e.g. 'HUD'
        files         REQUIRED  relative paths under libDir, forward slashes
        baseUrl       REQUIRED  where a relative path is fetched from
        libDir        defaults to <working dir>\lib\
        markerDir     REQUIRED  a directory this mod owns, for the loop guard
        reinstallUrl  printed when the guard trips
        reload        REQUIRED  function that reloads the calling script
        log           defaults to print
]]
function deps.selfHeal(cfg)
    assert(cfg and cfg.label and cfg.files and cfg.baseUrl and cfg.markerDir and cfg.reload,
           'akacross.deps.selfHeal: label, files, baseUrl, markerDir and reload are required')

    local log = cfg.log or print
    local function say(fmt, ...)
        log(('[%s] ' .. fmt):format(cfg.label, ...))
    end

    --[[
        Nothing to repair WITH means nothing to repair.

        The healer needs createDirectory, downloadUrlToFile and
        lua_thread.create, and the last is the cheapest to test for because it
        is the only one that has to be a TABLE. Outside the game - the host
        test suites load whole entry chunks under stubbed natives on Linux -
        the backslash paths below would report every file missing and the
        download would have nowhere to go.
    ]]
    if type(lua_thread) ~= 'table' or type(downloadUrlToFile) ~= 'function' then
        return false
    end

    local libDir = cfg.libDir or (getWorkingDirectory() .. '\\lib\\')
    local marker = cfg.markerDir .. '\\.selfheal'

    local function pathFor(rel) return libDir .. rel:gsub('/', '\\') end

    local missing = {}
    for _, rel in ipairs(cfg.files) do
        local f = io.open(pathFor(rel), 'rb')
        if f then
            local head = f:read(16)
            f:close()
            if not head or #head == 0 then missing[#missing + 1] = rel end
        else
            missing[#missing + 1] = rel
        end
    end
    if #missing == 0 then return false end

    local want = table.concat(missing, ',')
    local mf = io.open(marker, 'rb')
    local prev = mf and mf:read('*a') or nil
    if mf then mf:close() end
    if prev == want then
        say('%d file(s) still missing after a repair attempt - not retrying:', #missing)
        for _, rel in ipairs(missing) do log('       lib/' .. rel) end
        if cfg.reinstallUrl then say('reinstall from %s', cfg.reinstallUrl) end
        os.remove(marker)
        return false
    end

    createDirectory(cfg.markerDir)
    mf = io.open(marker, 'wb')
    if mf then mf:write(want); mf:close() end

    say('%d file(s) missing from lib/ - repairing from the release repo', #missing)

    local done, total = 0, #missing
    for _, rel in ipairs(missing) do
        local path = pathFor(rel)
        local dir = path:match('^(.*)\\[^\\]+$')
        if dir then createDirectory(dir) end
        downloadUrlToFile(cfg.baseUrl .. rel, path, function(_, status)
            if status == 6 then done = done + 1 end
        end)
    end

    lua_thread.create(function()
        local waited = 0
        while done < total and waited < 60000 do wait(250); waited = waited + 250 end
        wait(500)  -- settle: status 6 fires before the handle closes

        local bad = {}
        for _, rel in ipairs(missing) do
            local path = pathFor(rel)
            local ok = false
            local f = io.open(path, 'rb')
            if f then
                local head = f:read(256) or ''
                f:close()
                -- a 404 page is valid text and would otherwise install happily
                ok = #head > 0 and not head:find('^%s*<') and loadfile(path) ~= nil
            end
            if not ok then os.remove(path); bad[#bad + 1] = rel end
        end

        if #bad > 0 then
            say('repair failed for %d file(s); check your connection', #bad)
            for _, rel in ipairs(bad) do log('       lib/' .. rel) end
            return
        end
        os.remove(marker)
        say('repaired - reloading')
        cfg.reload()
    end)
    return true
end

return deps
