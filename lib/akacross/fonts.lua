--[[
    akacross.fonts - a Windows font FAMILY NAME to a .ttf file on disk.

    WHY THIS IS NEEDED AT ALL

    `renderCreateFont('Arial', 9, BOLD)` hands a family name to GDI, which owns
    a font database, applies its own substitution rules and always returns
    something. ImGui has none of that: `AddFontFromFileTTF` wants a path, and a
    path that is not there is a font that does not exist.

    So every config in this family - which stores a family name, because that is
    what the native renderer takes - needs a translation before an ImDrawList
    backend can draw a word of it.

    THE CASE THAT PROVES IT

    hud.lua's default text config says `font = 'Aerial'`. There is no such
    family. GDI has been quietly substituting for it since the day it was
    written and nobody noticed, because GDI substituting is invisible and
    ImGui finding nothing is not. A resolver that only did exact matches would
    leave the default configuration with no text at all.

    WHY THE DIRECTORY AND NOT THE REGISTRY

    `HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts` is the
    authoritative family-to-filename map and reading it means RegOpenKeyEx and
    RegEnumValue through ffi - a pointer-out parameter and a caller-sized buffer
    per value, in a process that has already crashed once this week. The payoff
    would be exact names for fonts whose FILENAMES are unconventional.

    Microsoft's own filenames are not unconventional. They are a convention:

        arial   arialbd   ariali   arialbi
        verdana verdanab  verdanai verdanaz
        segoeui segoeuib  segoeuii segoeuiz
        cour    courbd    couri    courbi

    A stem plus a style suffix, and the stem is the family with its spaces
    taken out. So this reads the directory, which cannot fault, and matches
    against it. What it gives up is a font whose file is named nothing like its
    family; what it gains is no ffi at all.

    NOTHING HERE EVER RETURNS NIL FOR A REASONABLE ASK. `resolve` falls through
    aliases, then a prefix match, then a chain of fonts that exist on every
    Windows install, then the first file in the directory. A HUD with the wrong
    face is a complaint; a HUD with no text is a bug report.
]]

local M = { _VERSION = '0.1.0' }

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------
--[[
    The directory listing and the folder path are INJECTED, same as the natives
    in akacross.render and akacross.draw: `getFolderPath(0x14)` is CSIDL_FONTS
    and lfs is what walks it, and neither exists on a host running the tests.
]]
local env = {
    dir = nil,      -- the fonts directory, with its trailing separator
    list = nil,     -- function() -> array of filenames in it
    lfs = nil,      -- the lfs module, or something shaped like it
}

local function defaultDir()
    local ok, path = pcall(function() return _G['getFolderPath'](0x14) end)
    if ok and type(path) == 'string' and path ~= '' then
        if not path:find('[\\/]$') then path = path .. '\\' end
        return path
    end
    return nil
end

--[[
    BOTH RETURN VALUES. `lfs.dir(path)` hands back an iterator AND the directory
    handle it reads from, and the iterator is a plain C function that
    luaL_checkudata's that handle as its first argument. Keeping only the
    iterator and writing `for name in iter do` calls it with nothing, which
    raises - and raised INSIDE this function, which its caller pcalls, so the
    whole font index came back empty and every font resolved to nil and the HUD
    drew no text at all, without a line in the log.

    `for name in iter, state do` is the same thing `for name in lfs.dir(path) do`
    does; it is spelled out only because the call is pcall-wrapped.
]]
local function defaultList()
    local dir = env.dir
    if not dir then return {} end

    local lfs = env.lfs
    if lfs == nil then
        local okLfs, mod = pcall(require, 'lfs')
        lfs = okLfs and mod or false
        env.lfs = lfs
    end
    if type(lfs) ~= 'table' or type(lfs.dir) ~= 'function' then return {} end

    local okIter, iter, state = pcall(lfs.dir, dir)
    if not okIter or type(iter) ~= 'function' then return {} end

    local names = {}
    local okWalk = pcall(function()
        for name in iter, state do
            if type(name) == 'string' then names[#names + 1] = name end
        end
    end)
    if not okWalk then return {} end
    return names
end

env.dir = defaultDir()
env.list = defaultList

--[[
    setup{dir =, list =, lfs =} - override any of them. The test seam.

    `list = false` restores the real directory walker, which is what lets a test
    exercise it against a fake `lfs` instead of replacing it - the distinction
    that matters, because the walker is where the bug was.
]]
function M.setup(opts)
    if opts then
        if opts.dir ~= nil then env.dir = opts.dir end
        if opts.list == false then env.list = defaultList
        elseif opts.list ~= nil then env.list = opts.list end
        if opts.lfs ~= nil then env.lfs = opts.lfs end
    end
    M.rescan()
    return M
end

-- ---------------------------------------------------------------------------
-- The stem index
-- ---------------------------------------------------------------------------
--[[
    normalised stem -> filename. `Arial Bold.ttf` and `arialbd.TTF` both reduce
    to something a family name can be compared against: lower case, no spaces,
    no extension. Only font extensions are indexed, because the Fonts directory
    also holds .fon bitmaps and desktop.ini, and stb_truetype reads neither.
]]
local FONT_EXT = {ttf = true, otf = true, ttc = true}

local stems = nil     -- built lazily; nil means "not scanned yet"
local anyFile = nil   -- the first font file seen, for the last-resort fallback

local function normalise(name)
    if type(name) ~= 'string' then return '' end
    return (name:lower():gsub('[%s_%-]', ''))
end

local function rescan()
    stems, anyFile = {}, nil
    if not env.dir or not env.list then return end
    local okList, names = pcall(env.list)
    if not okList or type(names) ~= 'table' then return end
    for i = 1, #names do
        local name = names[i]
        local stem, ext = name:match('^(.*)%.([^.]+)$')
        if stem and FONT_EXT[ext:lower()] then
            local key = normalise(stem)
            -- FIRST WINS, deliberately: a directory listing has no order worth
            -- relying on, and re-resolving the same family to a different file
            -- between sessions would move every glyph a fraction.
            if key ~= '' and not stems[key] then stems[key] = name end
            if not anyFile then anyFile = name end
        end
    end
end

--- Re-read the directory. Called by setup(); a caller with a font installed
--- mid-session can call it too.
function M.rescan()
    rescan()
    --[[
        An empty index means every family resolves to nil and every consumer
        draws nothing, which is exactly the failure this module had and exactly
        the one that produced no diagnostic at all. Said once, with the path, so
        the next version of that bug takes a minute instead of a run.
    ]]
    if not next(stems) and not M._warnedEmpty then
        M._warnedEmpty = true
        print(('[akacross.fonts] no font files found in %s - text will not draw')
            :format(tostring(env.dir)))
    end
    return M
end

local function index()
    if stems == nil then rescan() end
    return stems
end

local function pathOf(filename)
    if not filename then return nil end
    return (env.dir or '') .. filename
end

-- ---------------------------------------------------------------------------
-- Aliases
-- ---------------------------------------------------------------------------
--[[
    Families that are not families. This exists because hud.lua's own default
    config says 'Aerial', and it is not the only config in the wild that does -
    GDI substitutes silently, so a typo in a font box has never had a
    consequence before and has therefore never been corrected.

    Kept SHORT and literal on purpose. This is a list of known misspellings,
    not a fuzzy matcher: guessing that 'Ariel' means Arial is fine, guessing
    that 'Impact Label' means Impact is how someone ends up with a HUD in a
    face they did not choose and no way to tell why.
]]
M.ALIASES = {
    aerial      = 'arial',
    ariel       = 'arial',
    arail       = 'arial',
    tahome      = 'tahoma',
    verdanna    = 'verdana',
    couriernew  = 'cour',
    timesnewroman = 'times',
    segoe       = 'segoeui',
    trebuchetms = 'trebuc',
}

--[[
    The families every Windows install has, in the order they are worth trying.
    Arial first because it is what GDI substitutes toward and therefore what the
    HUD has actually been rendering in all along.
]]
M.FALLBACKS = {'arial', 'tahoma', 'verdana', 'segoeui', 'trebuc', 'times', 'cour'}

-- ---------------------------------------------------------------------------
-- Style suffixes
-- ---------------------------------------------------------------------------
--[[
    Microsoft uses several, and which one a family uses is not derivable - it is
    just history. Verdana Bold is `verdanab`, Arial Bold is `arialbd`; Verdana
    Bold Italic is `verdanaz`, Arial Bold Italic is `arialbi`. So each style is
    a LIST, tried in order, and the empty string is last for every one of them:
    a family with no italic file should render upright rather than not at all.
]]
local SUFFIXES = {
    regular    = {''},
    bold       = {'bd', 'b', 'bold', ''},
    italic     = {'i', 'it', 'italic', ''},
    bolditalic = {'bi', 'z', 'bdi', 'bolditalic', ''},
}

local function styleKey(bold, italic)
    if bold and italic then return 'bolditalic' end
    if bold then return 'bold' end
    if italic then return 'italic' end
    return 'regular'
end

--[[
    The base stem for a family.

    Exact first. Then the LONGEST indexed stem the family starts with, which is
    what turns `consolas` into `consola` - Microsoft dropped the s to fit the
    old eight-character limit and never renamed it. Bounded at four characters
    so that a three-letter family cannot match half the directory.
]]
local function baseStem(family)
    local map = index()
    local key = normalise(family)
    if key == '' then return nil end
    if map[key] then return key, 'exact' end

    local alias = M.ALIASES[key]
    if alias and map[alias] then return alias, 'alias' end

    local best
    for stem in pairs(map) do
        if #stem >= 4 and #stem <= #key and key:sub(1, #stem) == stem then
            if not best or #stem > #best then best = stem end
        end
    end
    if best then return best, 'prefix' end
    return nil
end

-- ---------------------------------------------------------------------------
-- Resolution
-- ---------------------------------------------------------------------------
--[[
    file(family, bold, italic) -> path, exact

    `exact` is false when the family itself could not be found and a fallback
    was used, so a caller can say which font it actually got. Returns nil only
    when the directory holds no font files at all.
]]
function M.file(family, bold, italic)
    local map = index()
    local suffixes = SUFFIXES[styleKey(bold, italic)]

    local base, how = baseStem(family)
    local exact = base ~= nil

    if not base then
        how = 'fallback'
        for i = 1, #M.FALLBACKS do
            if map[M.FALLBACKS[i]] then base = M.FALLBACKS[i]; break end
        end
    end

    if base then
        for i = 1, #suffixes do
            local name = map[base .. suffixes[i]]
            if name then return pathOf(name), exact, how end
        end
    end

    -- Nothing matched a name. Anything that is a font beats no text at all.
    if anyFile then return pathOf(anyFile), false, 'anything' end
    return nil, false, 'none'
end

--[[
    resolve(family, flags) -> path, exact

    `flags` is the summed bit field akacross.render uses, so a caller passes the
    same number it would have passed renderCreateFont. Only BOLD and ITALICS
    pick a file; border, shadow, underline and strikeout are drawn effects, not
    faces, and belong to whoever is drawing.
]]
local BOLD, ITALICS = 0x1, 0x2

--[[
    Every family this module has been asked for, and what it actually got.

    GDI substituting silently is why hud.lua's default has said 'Aerial' for
    years without anyone noticing. Substituting silently HERE would be the same
    mistake with the same shelf life, so a family that did not resolve to itself
    is recorded and said once. `resolved()` is what a diagnostic prints.
]]
local resolved = {}

--[[
    Keyed by family AND style, because one family resolves to four different
    files. Keying by family alone reported whichever style was asked for first -
    hud.lua's text defaults are bold+italics, so a report said `Aerial ->
    arialbi.ttf` and left a reader to wonder where the regular face went.
]]
local STYLE_NAME = {[0] = '', ' bold', ' italic', ' bold italic'}

function M.resolve(family, flags)
    flags = tonumber(flags) or 0
    -- No bit library needed for two bits, and this module stays dependency-free.
    local bold    = (flags % (BOLD * 2)) >= BOLD
    local italic  = (flags % (ITALICS * 2)) >= ITALICS
    local path, exact, how = M.file(family, bold, italic)

    local style = (bold and 1 or 0) + (italic and 2 or 0)
    local key = normalise(family) .. '\0' .. style
    if resolved[key] == nil then
        resolved[key] = {family = family, style = STYLE_NAME[style],
                         path = path, exact = exact, how = how}
        -- Said ONCE per family, not once per style: four lines telling someone
        -- the same thing about the same missing font is noise, not diagnosis.
        local warnKey = normalise(family)
        if not exact and path and not M._warnedFamily[warnKey] then
            M._warnedFamily[warnKey] = true
            print(('[akacross.fonts] %q is not installed - using %s')
                :format(tostring(family), path:match('[^\\/]+$') or path))
        end
    end
    return path, exact
end
M._warnedFamily = {}

--- family+style key -> {family =, style =, path =, exact =}. For a diagnostic.
function M.resolved() return resolved end

--- Every indexed stem, sorted. For a diagnostic command, and for a test to say
--- what it thinks is installed.
function M.list()
    local map = index()
    local out = {}
    for stem in pairs(map) do out[#out + 1] = stem end
    table.sort(out)
    return out
end

--- The directory being read, for the same reason.
function M.directory() return env.dir end

--- An array of lines describing what this module knows. For a diagnostic
--- command; the caller decides where they go.
function M.report()
    local lines = {}
    local n = #M.list()
    lines[#lines + 1] = ('fonts: %d files indexed in %s')
        :format(n, tostring(env.dir))
    if n == 0 then
        lines[#lines + 1] = '  NOTHING INDEXED - no text can draw through ImGui'
    end
    --[[
        HOW it resolved, not just to what.

        `alias`, `prefix` and `fallback` all mean the family the config names is
        NOT installed under that name - which means the game's own renderer is
        substituting for it too, by its own rules, and picking something else.
        That is the difference nobody can see from a screenshot and everybody
        can see on screen: two renderers using two different typefaces because
        the config named a font that does not exist.
    ]]
    local NOTE = {
        exact    = '',
        alias    = '   (alias - the game renderer picks its OWN substitute, so they will differ)',
        prefix   = '   (prefix match - the game renderer substitutes separately, so they may differ)',
        fallback = '   (NOT INSTALLED - the game renderer substitutes separately, so they will differ)',
        anything = '   (NOT INSTALLED - last resort)',
    }
    local rows = {}
    for _, r in pairs(resolved) do
        rows[#rows + 1] = ('  %-22s -> %s%s'):format(
            r.family .. r.style,
            tostring(r.path and r.path:match('[^\\/]+$') or 'NOTHING'),
            NOTE[r.how or 'exact'] or '')
    end
    table.sort(rows)
    for i = 1, #rows do lines[#lines + 1] = rows[i] end
    return lines
end

return M
