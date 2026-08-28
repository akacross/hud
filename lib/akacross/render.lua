--[[
    akacross.render - MoonLoader's D3D font layer: one font cache, one
    measurement, one alignment convention.

    WHY THIS IS SHARED

    Four places in this family draw text with renderFontDrawText, and every one
    of them wrote the same three mechanics from scratch:

      lib/autobind/hud.lua   six draggable screen elements; sums the flag bits
                             out of a table of cdata bools, measures, aligns
      badge.lua              one element; ALIGN_FACTOR table, its own flag sum,
                             its own create/release dance
      hud.lua (the mod)      eight element groups, up to eleven font slots each;
                             alignText() with a 1/2/3 convention  [MIGRATED]
      admintools.lua         a fontCache keyed by name/size/style, and a draw
                             helper that re-measures per call to align

    None of them is about the same feature, which is what makes this runtime
    work rather than mod work. What they share is a resource with a create and
    a release, and that is exactly the kind of thing that goes wrong quietly.

    THE BUG THIS MODULE EXISTS TO END

    `renderCreateFont` allocates a D3D font. Nothing in MoonLoader reclaims it
    for you. badge.lua's header already records what that costs:

        "Released only after the new one exists: every font change reallocates,
         and the old script leaked one D3D font per keystroke in the font box."

    autobind still had the unfixed version of that. lib/autobind/ui/widgets.lua
    calls `hudM.createFont` from FIVE imgui widgets - a flag checkbox, the font
    name box, the size InputInt, and every size in the preset list - and the old
    createFont overwrote the handle with a fresh one and dropped the previous on
    the floor. Holding the InputInt's arrow leaks a font per repeat.

    So handles are REFCOUNTED AND DEDUPED here:

      - Two elements on `Arial 9 bold+border` share ONE font object.
      - Toggling a checkbox off and back on re-acquires the SAME handle. No
        allocation at all, which is the common case in a settings menu.
      - A handle is released exactly when its last holder lets go.

    `swap` is the whole safe sequence in one call - acquire the new spec BEFORE
    releasing the old, so a spec that has not actually changed can never be
    released and recreated, and a font that fails to create leaves the caller
    holding the one that works rather than nothing.

    MEASURE AND DRAW MUST AGREE ABOUT COLOUR TAGS

    `{RRGGBB}` inline tags are consumed by the renderer, not drawn. A caller
    that measures the raw string and draws the tagged one gets a width that
    includes text nobody can see, which shows up as an alignment that is subtly
    wrong and a drag box that does not line up with the words. `plain()` is the
    single answer, with a `find` fast path so untagged text costs no allocation.

    ALIGNMENT IS BY NAME, NEVER BY NUMBER

    The three mods that align text disagree about the numbers: badge uses
    0/1/2, hud.lua uses 1/2/3, autobind stores the word. A module that accepted
    an integer would have to guess which convention it was handed, and a wrong
    guess is a silently right-aligned element. So `alignFactor` takes the word
    and the numeric tables are exposed for a caller to index with its own
    convention, in the open, where it can be read.

    NATIVES ARE INJECTED. Defaults come from _G when the module is loaded into
    a game, so a caller normally passes nothing; the tests pass fakes.
]]

local M = { _VERSION = '0.3.0' }

-- ---------------------------------------------------------------------------
-- Natives
-- ---------------------------------------------------------------------------
--[[
    A PLAIN INDEX, not rawget - the same reason akacross.textdraw gives: the
    natives are not necessarily keys on the script's own globals table, and
    anything that fronts _G with a metatable (moondev does exactly this) puts
    them one hop away. rawget skips that hop and every read comes back nil,
    which here reads as "there is no font support" and draws nothing at all.
]]
local function bind(name)
    local ok, fn = pcall(function() return _G[name] end)
    if ok and type(fn) == 'function' then return fn end
    return nil
end

--[[
    An explicit LIST, not `pairs` over a table declared with nil values:
    `{createFont = nil, ...}` is an EMPTY table in Lua, so pairs() yields
    nothing and setup() would silently install none of the fakes.
]]
local NATIVE_KEYS = {'createFont', 'releaseFont', 'drawText', 'textLength', 'textHeight'}

local natives = {}

--- Re-read the natives out of _G. Called at load, and again by setup().
function M.rebind()
    natives.createFont  = bind('renderCreateFont')
    natives.releaseFont = bind('renderReleaseFont')
    natives.drawText    = bind('renderFontDrawText')
    natives.textLength  = bind('renderGetFontDrawTextLength')
    natives.textHeight  = bind('renderGetFontDrawHeight')
    return M
end
M.rebind()

--- setup{createFont =, drawText =, ...} - override any native. Anything
--- omitted keeps whatever _G had. This is the test seam.
function M.setup(opts)
    for _, key in ipairs(NATIVE_KEYS) do
        if opts and opts[key] then natives[key] = opts[key] end
    end
    return M
end

-- ---------------------------------------------------------------------------
-- Flags
-- ---------------------------------------------------------------------------
--- MoonLoader's font_flag values, by name. Same numbers as the `font_flag`
--- constants table, spelled out so this module needs no dependency to read a
--- config that was written in these names.
M.FLAGS = {
    BOLD      = 0x1,
    ITALICS   = 0x2,
    BORDER    = 0x4,
    SHADOW    = 0x8,
    UNDERLINE = 0x10,
    STRIKEOUT = 0x20,
}

-- Explicit, for the same reason NATIVE_KEYS is: an order to iterate in that
-- does not depend on hash order, and a list that cannot be empty by accident.
M.FLAG_NAMES = {'BOLD', 'ITALICS', 'BORDER', 'SHADOW', 'UNDERLINE', 'STRIKEOUT'}

--[[
    A config flag is a plain boolean in one mod and an imgui `new.bool` cdata in
    another, and the cdata is TRUTHY even when it holds false - testing it
    without the `[0]` is the bug that made both of autobind's guard checkboxes
    permanently read "Enabled" (UI_OPTIMIZATION_PLAN section 2). So the truth
    test is written once, here.
]]
local function truthy(v)
    if v == nil or v == false then return false end
    if v == true then return true end
    local ok, b = pcall(function() return v[0] end)
    if ok then return b == true or b == 1 end
    return true   -- some other non-nil value: treat presence as set
end
M.truthy = truthy

--- flags{BOLD = <bool|cdata>, ...} -> the summed flag bits. Unknown keys are
--- ignored; a missing key is off.
function M.flags(t)
    local kind = type(t)
    if kind ~= 'table' and kind ~= 'cdata' then return 0 end
    local sum = 0
    local names, values = M.FLAG_NAMES, M.FLAGS
    for i = 1, #names do
        local name = names[i]
        local field
        if kind == 'table' then
            -- LOWER CASE TOO. A cdata config spells these BOLD because that is
            -- what the imgui field is called; a JSON config spells them `bold`,
            -- because a config file people open in an editor should read like
            -- one. Both are the same flag.
            field = t[name]
            if field == nil then field = t[name:lower()] end
        else
            -- a cdata struct raises on a field it does not have
            local ok, v = pcall(function() return t[name] end)
            field = ok and v or nil
        end
        if truthy(field) then sum = sum + values[name] end
    end
    return sum
end

--[[
    flagsFromArray(arr, names) -> flag bits, for POSITIONAL flag config.

    hud.lua stores `{true, true, true, true}` against a `{BOLD, ITALICS,
    BORDER, SHADOW}` list rebuilt at the call site, because its settings menu
    draws the flags as a numbered row of checkboxes. That is a reasonable
    config shape and a terrible thing to guess at - an array and a name-keyed
    table are indistinguishable in Lua the moment either one is empty - so it
    is a separate function rather than a heuristic inside flags().

    `names` defaults to FLAG_NAMES, whose order (bold, italics, border, shadow,
    underline, strikeout) is both MoonLoader's font_flag order and the order
    every settings menu in this family lists them in. A shorter array simply
    leaves the trailing flags off.
]]
function M.flagsFromArray(arr, names)
    if type(arr) ~= 'table' then return 0 end
    names = names or M.FLAG_NAMES
    local sum, values = 0, M.FLAGS
    for i = 1, #names do
        if truthy(arr[i]) then
            local value = values[names[i]]
            if value then sum = sum + value end
        end
    end
    return sum
end

-- ---------------------------------------------------------------------------
-- The font cache
-- ---------------------------------------------------------------------------
-- spec key -> {font =, refs =, key =, name =, size =, flags =}
local specs = {}
-- font handle -> the same entry, so release() is O(1) from what the caller holds
local holders = {}
-- font handle -> line height. Constant for the life of the handle, and one
-- native call is not free when six elements ask for it every frame.
local heights = {}

local function keyOf(name, size, flags)
    return name .. '\0' .. size .. '\0' .. flags
end

--[[
    acquire(name, size, flags) -> font handle or nil

    Deduped: the same spec returns the same handle with one more reference on
    it. The caller must hand every handle it takes back to `release` (or, for a
    change of spec, to `swap`, which does both halves in the right order).
]]
function M.acquire(name, size, flags)
    if type(name) ~= 'string' or name == '' then return nil end
    size = math.floor(tonumber(size) or 0)
    if size < 1 then return nil end
    flags = math.floor(tonumber(flags) or 0)

    local key = keyOf(name, size, flags)
    local entry = specs[key]
    if entry then
        entry.refs = entry.refs + 1
        return entry.font
    end

    if not natives.createFont then return nil end
    local ok, font = pcall(natives.createFont, name, size, flags)
    if not ok or font == nil then return nil end

    entry = {font = font, refs = 1, key = key, name = name, size = size, flags = flags}
    specs[key] = entry
    holders[font] = entry
    return font
end

--- Drop one reference. Returns true when that was the last one and the D3D
--- font was actually released. A handle this module did not hand out is
--- ignored rather than released - releasing someone else's font is worse than
--- leaking your own.
function M.release(font)
    local entry = font ~= nil and holders[font] or nil
    if not entry then return false end
    entry.refs = entry.refs - 1
    if entry.refs > 0 then return false end
    specs[entry.key], holders[font], heights[font] = nil, nil, nil
    if natives.releaseFont then pcall(natives.releaseFont, font) end
    return true
end

--[[
    swap(old, name, size, flags) -> the handle to hold from now on.

    Acquire first, release second. That ordering is the point:

      - the spec did not really change   -> the SAME handle comes back, the
                                            extra reference is undone, and no
                                            font is destroyed or created
      - the new spec fails to create     -> the caller keeps the old handle,
                                            which still works, instead of being
                                            left with nil and drawing nothing
]]
function M.swap(old, name, size, flags)
    local font = M.acquire(name, size, flags)
    if font == nil then return old end
    if font == old then
        M.release(font)   -- undo the extra reference; refs cannot reach zero here
        return old
    end
    if old ~= nil then M.release(old) end
    return font
end

--- Release everything this module holds, whatever the refcounts. For script
--- teardown only - a caller that uses this mid-session invalidates handles
--- other code is still holding.
function M.releaseAll()
    local n = 0
    for font in pairs(holders) do
        if natives.releaseFont then pcall(natives.releaseFont, font) end
        n = n + 1
    end
    specs, holders, heights = {}, {}, {}
    return n
end

--- {specs =, refs =, fonts =} - distinct specs alive, total references held,
--- and live handles. For a diagnostic command; a spec count that climbs with
--- nothing but menu use is the leak this module exists to prevent.
function M.stats()
    local nSpecs, nRefs = 0, 0
    for _, entry in pairs(specs) do
        nSpecs = nSpecs + 1
        nRefs = nRefs + entry.refs
    end
    return {specs = nSpecs, refs = nRefs, fonts = nSpecs}
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------
--[[
    Strip the `{RRGGBB}` inline colour tags.

    The `find` first is not premature: most strings that reach a draw call have
    no tags at all, and gsub allocates a result string whether it replaced
    anything or not. This turns the common case into one search with no
    garbage.
]]
function M.plain(text)
    if type(text) ~= 'string' then return '' end
    if not text:find('{', 1, true) then return text end
    return (text:gsub('{%x+}', ''))
end

--- Pixel width of `text` in `font`. Pass the PLAIN string: see plain().
function M.measure(font, text)
    if font == nil or not natives.textLength then return 0 end
    if type(text) ~= 'string' or text == '' then return 0 end
    local ok, len = pcall(natives.textLength, font, text)
    return (ok and tonumber(len)) or 0
end

--- Line height for a font, memoized per handle for the life of that handle.
function M.height(font)
    if font == nil then return 0 end
    local h = heights[font]
    if h then return h end
    if not natives.textHeight then return 0 end
    local ok, v = pcall(natives.textHeight, font)
    h = (ok and tonumber(v)) or 0
    heights[font] = h
    return h
end

-- ---------------------------------------------------------------------------
-- Alignment
-- ---------------------------------------------------------------------------
--- Word -> the fraction of the text width to subtract from x.
M.ALIGN = {
    left = 0.0, center = 0.5, centre = 0.5, right = 1.0,
}

--- The two numeric conventions in this family, exposed rather than guessed at.
--- Index them yourself; see the header.
M.ALIGN_BY_INDEX0 = {[0] = 0.0, [1] = 0.5, [2] = 1.0}   -- badge.lua
M.ALIGN_BY_INDEX1 = {[1] = 0.0, [2] = 0.5, [3] = 1.0}   -- hud.lua

--- alignFactor('center') -> 0.5. An unknown or missing name is left-aligned,
--- which is the only choice that cannot move an element somewhere surprising.
function M.alignFactor(name)
    if type(name) ~= 'string' then return 0.0 end
    return M.ALIGN[name] or 0.0
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------
--[[
    draw(font, text, x, y, color) -> drew?

    x and y are the FINAL position - alignment is the caller's, because a
    caller that aligns already knows the width (it needed it for a hit box, or
    it cached it) and re-measuring here would be a native call per element per
    frame for a number that did not change.

    `color` defaults to -1 (0xFFFFFFFF): the inline `{RRGGBB}` tags are what
    normally colour these strings, and -1 is the neutral base they modify.
]]
function M.draw(font, text, x, y, color)
    if font == nil or not natives.drawText then return false end
    if type(text) ~= 'string' or text == '' then return false end
    natives.drawText(font, text, x, y, color or -1)
    return true
end

--[[
    drawAligned(font, text, x, y, color, factor, width) -> drew?

    For callers with nothing cached. `width` is optional; without it the plain
    text is measured here, which is the cost draw() exists to let you avoid.
]]
function M.drawAligned(font, text, x, y, color, factor, width)
    if font == nil then return false end
    if type(text) ~= 'string' or text == '' then return false end
    local offset = 0
    factor = factor or 0
    if factor ~= 0 then
        offset = (width or M.measure(font, M.plain(text))) * factor
    end
    return M.draw(font, text, x - offset, y, color)
end

return M
