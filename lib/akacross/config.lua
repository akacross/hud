--[[
    akacross.config - per-mod namespaced config sets.

    WHY THIS EXISTS
    ---------------
    autobind's config layer (autobind.core) is three hand-maintained lists of
    the same 18 names - one to load, one to save, one to reset - plus a fourth
    that clears list-valued configs before a load. Adding a config means editing
    four places, and forgetting one is silent: the b49 note in the entry records
    exactly that (gearbox.json and speedo.json "would silently never persist"
    on an install whose core was one version behind).

    A mod split out of autobind needs the same machinery over its own directory.
    Rather than copy the lists, this registers each config once and derives all
    four operations from the registry.

    Built on carbJsonConfig (cjc), which is what already persists these tables:
    it handles cdata (the `new.bool`/`new.float` config fields are cdata, not
    Lua values) and attaches the __call metamethod that makes `Gearbox()` save
    and `Gearbox("reset")` reset. This module owns namespacing, directory
    creation and the registry; cjc still owns the file format.

    USAGE
    -----
        local config = require('akacross.config')

        local cfg = config.open('driving')      -- config/driving/

        cfg:register('gearbox', Gearbox)
        cfg:register('speedo',  Speedo, {clear = function(t) t.List = {} end})

        cfg:load()              -- every registered config, clear hooks first
        cfg:save()              -- every registered config
        cfg:save('gearbox')     -- just one
        cfg:reset()             -- back to the defaults captured at register time

    ORDERING
    --------
    register() must be called while the table still holds its DEFAULTS. cjc
    snapshots them on first load to implement reset, so a table mutated before
    load() would have the mutation baked in as its "default" forever.
]]

local config = {}
config._VERSION = '0.1.0'

local cjc = require('carbJsonConfig')

-- io.open rather than doesFileExist: the question is only "is there a file to
-- merge from", which needs no MoonLoader native, and this keeps the module
-- loadable (and testable) outside the game.
--
-- Paths here are built Windows-style with backslashes, which io.open cannot
-- resolve on a Linux host (a moondev harness, or these tests). cjc normalizes
-- internally via its pathFixer, so a check that did not would silently
-- disagree with the load that follows it - reporting "no file" for a file cjc
-- then reads happily. Try both spellings.
--- Raw text of a config file, or nil when it does not exist. Same dual-path
--- handling as fileExists: these paths are Windows-style and a Linux host
--- cannot open them without normalising.
local function readFile(path)
    local f = io.open(path, 'r')
    if not f then f = io.open((path:gsub('\\', '/')), 'r') end
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    return content
end

local function fileExists(path)
    local f = io.open(path, 'r')
    if not f then f = io.open((path:gsub('\\', '/')), 'r') end
    if f then f:close() return true end
    return false
end

local Set = {}
Set.__index = Set

--[[
    open(namespace, opts) -> set

    namespace  directory under config/, e.g. 'driving' -> config/driving/
    opts.dir   override the whole directory instead (absolute, trailing sep)
    opts.log   defaults to print

    The directory is created eagerly: cjc writes defaults on first load, and
    io.open in write mode does not create missing directories.
]]
function config.open(namespace, opts)
    opts = opts or {}
    local dir = opts.dir
    if not dir then
        assert(type(namespace) == 'string' and #namespace > 0,
            'akacross.config: namespace required')
        dir = getWorkingDirectory() .. '\\config\\' .. namespace .. '\\'
    end
    if not doesDirectoryExist(dir) then createDirectory(dir) end

    return setmetatable({
        namespace = namespace,
        dir = dir,
        log = opts.log or print,
        order = {},     -- registration order, so load/save are deterministic
        entries = {},   -- name -> {table =, clear =, loaded =}
    }, Set)
end

--[[
    register(name, tbl, opts) -> set  (chainable)

    opts.clear  clear(tbl, rawFileContent) - called before load() for configs
                holding lists that must not merge with what is already in
                memory. Only runs when the file EXISTS, and receives the file's
                raw text so it can clear ONLY the entries the file will restore
                - see load().
    opts.file   override the filename (defaults to <name>.json)
]]
function Set:register(name, tbl, opts)
    assert(type(name) == 'string' and #name > 0, 'akacross.config: name required')
    assert(type(tbl) == 'table', 'akacross.config: ' .. name .. ' must be a table')
    assert(not self.entries[name], 'akacross.config: ' .. name .. ' already registered')
    opts = opts or {}

    self.order[#self.order + 1] = name
    self.entries[name] = {
        table = tbl,
        clear = opts.clear,
        file = opts.file or (name .. '.json'),
        loaded = false,
    }
    return self
end

function Set:path(name)
    local e = self.entries[name]
    return e and (self.dir .. e.file) or nil
end

function Set:get(name)
    local e = self.entries[name]
    return e and e.table or nil
end

function Set:names()
    local out = {}
    for i, n in ipairs(self.order) do out[i] = n end
    return out
end

-- Iterate one entry or all of them, in registration order.
function Set:_each(name, fn)
    if name then
        local e = self.entries[name]
        if not e then
            self.log(('akacross.config: no config named %q in %s')
                :format(tostring(name), tostring(self.namespace)))
            return 0
        end
        fn(name, e)
        return 1
    end
    for _, n in ipairs(self.order) do fn(n, self.entries[n]) end
    return #self.order
end

--[[
    load(name?) -> count

    Runs each clear hook first, then cjc.load, which creates the file from the
    in-memory defaults when it does not exist yet. Each load is pcall'd: one
    corrupt config must not take the rest of the set - and the mod - down with
    it. A failed entry keeps its defaults and says so.

    THE CLEAR HOOK ONLY RUNS WHEN THE FILE EXISTS, and that guard is the whole
    point of it. Clearing exists to stop an on-disk list merging into a
    populated in-memory one. With no file there is nothing to merge, and cjc
    treats a missing file as "write what is in memory now" - so clearing first
    would persist the EMPTIED table as the initial config and destroy the
    defaults permanently.

    That is not hypothetical: it shipped. Both extracted mods wrote a
    keybinds.json with every `Keys` list empty on their first run, so no bind
    could ever fire. autobind's original guarded this with
    `if doesFileExist(Files.keybinds)`; the guard did not survive the move into
    this module, and now lives here where every caller gets it.
]]
function Set:load(name)
    return self:_each(name, function(n, e)
        local path = self.dir .. e.file
        if e.clear then
            -- The hook gets the file's raw text, not just the table. Clearing
            -- blind wipes entries the file does NOT contain, and the merge
            -- afterwards only restores what IS in the file - so every newly
            -- added default (a keybind added in a later version) came back
            -- EMPTY on any install with an older config. The hook uses the
            -- content to clear only what will be restored.
            local raw = readFile(path)
            if raw then
                local ok, err = pcall(e.clear, e.table, raw)
                if not ok then
                    self.log(('akacross.config: %s clear hook failed: %s'):format(n, tostring(err)))
                end
            end
        end
        local ok, err = pcall(cjc.load, self.dir .. e.file, e.table)
        if ok then
            e.loaded = true
        else
            self.log(('akacross.config: failed to load %s: %s'):format(n, tostring(err)))
        end
    end)
end

--[[
    save(name?) -> count

    cjc attaches __call on load, so an unloaded table has no way to save
    itself. Calling save() before load() is a programming error rather than a
    runtime condition, so it is reported rather than silently skipped.
]]
function Set:save(name)
    return self:_each(name, function(n, e)
        if not e.loaded then
            self.log(('akacross.config: %s not loaded, refusing to save'):format(n))
            return
        end
        local ok, err = pcall(e.table)
        if not ok then
            self.log(('akacross.config: failed to save %s: %s'):format(n, tostring(err)))
        end
    end)
end

-- reset(name?) -> count. Back to the defaults captured at first load.
function Set:reset(name)
    return self:_each(name, function(n, e)
        if not e.loaded then
            self.log(('akacross.config: %s not loaded, refusing to reset'):format(n))
            return
        end
        local ok, err = pcall(e.table, "reset")
        if not ok then
            self.log(('akacross.config: failed to reset %s: %s'):format(n, tostring(err)))
        end
    end)
end

return config
