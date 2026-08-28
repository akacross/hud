--[[
    akacross.draw_imgui - the ImDrawList backend for akacross.draw.

    Requiring this file registers a backend called `imgui`. It does not select
    it; `draw.use('imgui')` does, and a consumer that never calls that is
    unaffected by this file being on disk.

    WHAT IT BUYS

    Geometry, textures AND text stop being MoonLoader native calls that each set
    up their own device state, and become vertices in imgui's one batched draw
    list. Everything the HUD puts on screen now goes through a single renderer,
    in one pass, with one draw order.

    What is actually VISIBLE about that is rounding. Every shape a HUD draws is
    an axis-aligned rectangle or an unrotated texture, and antialiasing has
    nothing to bite on there - a square-cornered bar is the same pixels under
    both renderers, which is exactly what the first version of this backend
    produced and exactly why it looked like nothing had changed.
    `renderDrawBox` cannot round a corner and this can, so `caps` declares that
    and a consumer offers the control only while this backend is drawing.

    THE TEXT QUEUE IS GONE

    An earlier version drew text with the native D3D fonts and had to queue it,
    flushing from an `onD3DPresent` handler registered after mimgui's, because
    imgui renders at EndFrame and anything drawn natively during that present is
    already on the back buffer and therefore underneath. hud.lua's default
    layout puts the health value inside the health bar, so that was not a
    cosmetic problem.

    Text is in the draw list now, so the queue, the handler and the ordering
    dependency on MoonLoader's event dispatch are all deleted. There is one
    renderer and z-order is call order.

    WHAT THAT COST, AND WHAT IT CHANGES

    GDI takes a font FAMILY NAME and always returns something. ImGui takes a
    FILE, bakes one size into a shared atlas texture, and has no notion of bold,
    italics, border or shadow. So:

      - the family becomes a path through akacross.fonts, which has to cope with
        hud.lua's own default config asking for 'Aerial'
      - bold and italics pick a different FILE (arialbd.ttf, ariali.ttf)
      - border, shadow, underline and strikeout are DRAWN here: the border is
        the run stamped four times around itself, the shadow once below it, and
        the other two are rectangles
      - the atlas is APPEND-ONLY. `Fonts:Clear()` would destroy mimgui's own
        font zero and every font any other module added, so a spec that stops
        being used stays baked. It is deduped by file and size, and a spec that
        is dropped BEFORE the next rebuild never gets baked at all - which is
        what stops dragging a size slider from 8 to 30 baking twenty-two fonts.

    Expect the metrics to differ from GDI's. Different rasteriser, different
    hinting, so a line of text is not the same number of pixels wide as it was
    and centred text moves by a fraction.
]]

local M = {}

local ffi = require('ffi')
local bit = require('bit')
local imgui = require('mimgui')
local fontsM = require('akacross.fonts')
local renderM = require('akacross.render')
local draw = require('akacross.draw')

local band, bor, rshift, lshift = bit.band, bit.bor, bit.rshift, bit.lshift
local floor = math.floor

-- ---------------------------------------------------------------------------
-- Colour
-- ---------------------------------------------------------------------------
--[[
    ARGB (what akacross.draw carries, what the natives take, what every config
    in this family stores) -> ImU32, which is ABGR. R and B swap.

    The `% 4294967296` is not decoration: `bit.bor` yields a SIGNED 32-bit Lua
    number, so any colour with the top alpha bit set comes back negative, and
    handing a negative to an `unsigned int` parameter leans on a conversion rule
    rather than stating one. The modulo makes it the number it is meant to be.

    Not memoised. It is six machine ops; a hash lookup to avoid them would cost
    more, and a cache keyed by colour grows without bound while somebody drags a
    colour picker.
]]
local function toImU32(argb)
    if argb == nil then argb = -1 end
    local a = band(rshift(argb, 24), 0xFF)
    local r = band(rshift(argb, 16), 0xFF)
    local g = band(rshift(argb, 8), 0xFF)
    local b = band(argb, 0xFF)
    return bor(lshift(a, 24), lshift(b, 16), lshift(g, 8), r) % 4294967296
end
M.toImU32 = toImU32   -- exported for the host test; nothing else should need it

-- ---------------------------------------------------------------------------
-- Scratch
-- ---------------------------------------------------------------------------
--[[
    ImVec2 is a cdata struct, and every one of these functions takes two or four
    of them. Constructing them per call is an allocation per corner per element
    per frame - garbage measured in thousands of objects a second for numbers
    that are overwritten immediately. They are taken BY VALUE by the C
    functions, so reused structs are safe and are the whole cost.

    The UVs are here for the same reason and a sharper one: mimgui's AddImage
    wrapper defaults them with `uv_a or ImVec2(0,0)`, so omitting them allocates
    two vectors per texture per frame.
]]
local Vec2 = imgui.ImVec2
local pA, pB = Vec2(0, 0), Vec2(0, 0)
local pC, pD = Vec2(0, 0), Vec2(0, 0)
local uvA, uvB = Vec2(0, 0), Vec2(1, 1)
local uvC, uvD = Vec2(1, 1), Vec2(0, 1)
-- The out-parameter for text measurement. mimgui's ImFont:CalcTextSizeA
-- allocates a fresh ImVec2 per call; the raw entry point takes one to fill.
local sizeOut = Vec2(0, 0)

local function at(v, x, y)
    v.x, v.y = x, y
    return v
end

-- ---------------------------------------------------------------------------
-- Frame state
-- ---------------------------------------------------------------------------
-- The draw list for the frame currently being built. nil outside a frame, and
-- every drawing function checks it: appending to a stale ImDrawList* is a write
-- through a pointer imgui has already recycled.
local list = nil

local drawPass, visible = nil, nil
local sub = nil

-- ---------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------
--[[
    `caps` is what a consumer reads before it offers a rounding control. The
    native renderer has no argument for it, so the setting must not exist while
    that one is active - see akacross.draw's CAPABILITIES.
]]
M.caps = {rounding = true}

--[[
    A rectangle with no width is not a rectangle.

    `renderDrawBox` hands a zero-area quad to D3D and D3D rasterises nothing.
    `AddRectFilled` runs it through AddConvexPolyFilled, which - with
    antialiasing on, which it is - expands the degenerate polygon outward by the
    AA fringe and leaves a translucent sliver a pixel or so wide, in the fill's
    own colour.

    That is the nub at the left end of every bar sitting at zero: hud.lua's
    value fill is `width * value / max`, so an empty armour bar asks for a fill
    0 pixels wide and got a white smear for it. Guarded here rather than at the
    call site because the two backends have to agree about what an empty
    rectangle looks like, and the native one already draws nothing.
]]
local function degenerate(w, h)
    return not (w > 0) or not (h > 0)   -- also catches nan
end

function M.box(x, y, w, h, color, rounding)
    if list == nil or degenerate(w, h) then return end
    list:AddRectFilled(at(pA, x, y), at(pB, x + w, y + h), toImU32(color), rounding or 0)
end

--[[
    A RING plus a fill, and getting this wrong is what made translucency stop
    working.

    The first version painted the whole w-by-h rect in the border colour and
    then the fill over it, inset. hud.lua's arithmetic is consistent with that -
    it draws the bar's value at `x + border` with width `sizex - 2 * border` -
    and it is wrong, which its own default configuration proves:

        fade    = 1677721600 = 0x64000000   39% black
        outline = -16777216  = 0xFF000000  100% black

    A 39% black fill composited over a 100% black backdrop is solid black. If
    the border were a filled rect under the fill, `fade` could not do anything
    at all and would not be a setting. It is a setting, and it works under the
    native renderer, so `renderDrawBoxWithBorder` draws the border as a ring
    INSIDE the given rectangle and the fill sits in the hole - blending over the
    game, which is the whole point of a fade.

    AddRect strokes centred on its path, so the path is inset by half the border
    and stroked at the full width: that lays the ring from the edge to exactly
    where the fill begins. The fill goes down FIRST and the ring over it, so the
    antialiased seam between them is covered by the opaque side rather than
    showing as a translucent hairline.
]]
function M.boxBorder(x, y, w, h, color, bsize, bcolor, rounding)
    if list == nil or degenerate(w, h) then return end
    bsize = bsize or 0
    rounding = rounding or 0

    --[[
        CONCENTRIC, not the same radius twice. Two rounded rects inset by
        `bsize` with an identical radius do not have parallel curves - the gap
        between them widens through the corner, so a 1px border reads as 1px on
        the flats and visibly thicker at every corner. Subtracting the inset is
        what makes the inner curve follow the outer one.

        imgui clamps rounding to half the shorter side itself, so a bar too
        short to take the radius becomes a lozenge rather than drawing wrong.
    ]]
    local inner = rounding - bsize
    if inner < 0 then inner = 0 end
    -- A border thick enough to meet in the middle leaves no hole to fill.
    if not degenerate(w - bsize * 2, h - bsize * 2) then
        list:AddRectFilled(at(pA, x + bsize, y + bsize),
                           at(pB, x + w - bsize, y + h - bsize), toImU32(color), inner)
    end

    if bsize > 0 then
        local half = bsize / 2
        local ringRadius = rounding - half
        if ringRadius < 0 then ringRadius = 0 end
        list:AddRect(at(pA, x + half, y + half),
                     at(pB, x + w - half, y + h - half),
                     toImU32(bcolor), ringRadius, nil, bsize)
    end
end

-- ---------------------------------------------------------------------------
-- Textures
-- ---------------------------------------------------------------------------
--[[
    A lazy handle. `path` is what was asked for, `tex` the D3D texture once it
    exists, `id` the same pointer cast to ImTextureID once (ffi.cast allocates a
    cdata, so doing it per frame would be an allocation per icon per frame).

    mimgui builds its renderer on the first present with an active subscription;
    hud.lua loads its 49 weapon icons during initialisation, long before that,
    and `CreateTextureFromFile` needs the renderer. So the load creates NOTHING
    and the texture is made on first draw, which happens inside the frame
    callback and therefore provably after the renderer exists.
]]
local function resolveTexture(handle)
    if handle.id ~= nil then return handle.id end
    if handle.failed then return nil end

    local ok, tex = pcall(imgui.CreateTextureFromFile, handle.path)
    if not ok or tex == nil then
        -- Written off rather than retried. This only runs inside a frame, so
        -- the renderer is up and the file genuinely will not load - and one
        -- unreadable png must not become a create attempt every frame forever.
        handle.failed = true
        return nil
    end
    handle.tex = tex
    if type(tex) == 'cdata' then
        local castOk, id = pcall(ffi.cast, 'void*', tex)
        handle.id = castOk and id or tex
    else
        handle.id = tex
    end
    return handle.id
end

function M.loadTexture(path)
    if type(path) ~= 'string' or path == '' then return nil end
    return {path = path, tex = nil, id = nil, failed = false}
end

function M.releaseTexture(handle)
    if type(handle) ~= 'table' then return false end
    if handle.tex ~= nil then pcall(imgui.ReleaseTexture, handle.tex) end
    handle.tex, handle.id, handle.failed = nil, nil, false
    return true
end

--[[
    Rotation is about the CENTRE of the rect, which is what renderDrawTexture
    does. It is implemented rather than ignored - hud.lua passes 0 for every
    icon it draws, and a backend that silently dropped a parameter would be a
    difference nobody discovers until something does use it.
]]
function M.texture(handle, x, y, w, h, angle, color)
    if list == nil or type(handle) ~= 'table' or degenerate(w, h) then return end
    local id = resolveTexture(handle)
    if id == nil then return end
    local col = toImU32(color)

    if not angle or angle == 0 then
        list:AddImage(id, at(pA, x, y), at(pB, x + w, y + h), uvA, uvB, col)
        return
    end

    local rad = math.rad(angle)
    local cos, sin = math.cos(rad), math.sin(rad)
    local cx, cy = x + w / 2, y + h / 2
    local hw, hh = w / 2, h / 2
    local function corner(v, dx, dy)
        return at(v, cx + dx * cos - dy * sin, cy + dx * sin + dy * cos)
    end
    -- Corner order matches the UVs below: top-left, top-right, bottom-right,
    -- bottom-left.
    list:AddImageQuad(id,
        corner(pA, -hw, -hh), corner(pB, hw, -hh),
        corner(pC, hw, hh),   corner(pD, -hw, hh),
        at(uvA, 0, 0), at(uvB, 1, 0), at(uvC, 1, 1), at(uvD, 0, 1), col)
    -- The two shared UVs are used unrotated by the common path above, so they
    -- go back to what it expects.
    at(uvA, 0, 0); at(uvB, 1, 1)
end

-- ---------------------------------------------------------------------------
-- The font atlas
-- ---------------------------------------------------------------------------
--[[
    TWO LEVELS, because they are keyed by different things.

      an ATLAS ENTRY   is one baked face: a file and a pixel size. Two elements
                       at Arial 8 share one, whatever else differs about them.
      a HANDLE         is what a caller holds: an entry plus the DRAWN flags
                       (border, shadow, underline, strikeout), which change
                       nothing about the glyphs and everything about the draw.

    Collapsing them would mean either baking the same face once per flag
    combination - four copies of Arial 8 in the atlas because four elements
    wanted different outlines - or losing the flags entirely.
]]
local BOLD, ITALICS = 0x1, 0x2
local BORDER, SHADOW, UNDERLINE, STRIKEOUT = 0x4, 0x8, 0x10, 0x20
local DRAW_FLAGS = BORDER + SHADOW + UNDERLINE + STRIKEOUT

--[[
    A backstop, not a budget. hud.lua asks for about a dozen distinct faces; a
    settings menu with somebody leaning on the size button could ask for
    hundreds, and every one of them is baked into a texture that can never be
    reclaimed. Past this, an ask is served by the closest face already baked -
    text a size or two out beats text that stops appearing.
]]
local MAX_FONTS = 64

local entries = {}    -- file\0size -> {file, size, imfont, refs, height, key}
local handles = {}    -- file\0size\0flags -> {entry, flags, refs, key}
local pending = {}    -- entries wanting a bake
local baked = 0
local cappedWarned = false

-- imgui keeps a POINTER to the glyph ranges for the life of the atlas, so this
-- has to outlive every font built from it. mimgui does exactly the same with
-- its own `defaultGlyphRanges`.
local glyphRanges = nil

local function closestEntry(file, size)
    local best, bestGap
    for _, e in pairs(entries) do
        if e.imfont ~= nil then
            local gap = math.abs((e.bakeSize or e.configSize) - size)
                        + (e.file == file and 0 or 1000)
            if not bestGap or gap < bestGap then best, bestGap = e, gap end
        end
    end
    return best
end

--[[
    THE SIZE THE GAME RENDERER WOULD HAVE MADE, not the number in the config.

    A config size is not a unit. `renderCreateFont(family, 10, ...)` hands 10 to
    GDI, which resolves it against a font it chose, at a DPI it knows about, and
    lands wherever it lands. ImGui's `size_pixels` is a pixel height that
    stb_truetype scales the face to directly. The two are not the same quantity,
    and treating them as one made every string 60% of its native width.

    TWO CORRECTIONS, because one was not enough.

    The first is the line height: build the native font, ask how tall its line
    is, bake at that. That is exact and it is not a constant - the config's
    8/10/16 came back as 11/16/24, ratios of 1.375, 1.6 and 1.5, because GDI is
    quantising to whatever it substituted. Nothing derived could have got that;
    it has to be asked, per size.

    The second is the FACE. Matching cell heights still left text at about 80%
    of its native width, because a config that names a family GDI has to
    substitute for gets two different typefaces - and a substituted system font
    is far wider than Arial at the same height. No amount of reasoning about
    metrics fixes that, because the substituted face is GDI's private choice.

    So the second correction is MEASURED, not derived: the same string is run
    through both renderers, and the ratio of the two widths scales the size.
    Measured once per family and style, from the first face baked for it, then
    reused for every size of that face. A derivation can be wrong about the
    outcome; a measurement of the outcome cannot.

    It converges in one step and cannot oscillate: ImGui's width is linear in
    `size_pixels`, so scaling the size by `native/imgui` makes the next
    measurement equal by construction, and the ratio is computed only when it is
    absent. The cost is one baked face per family and style that ends up
    unreferenced - the atlas is append-only, so a probe cannot be taken back.

    WHAT DOES NOT WORK YET, AND WHAT NOT TO TRY.

    On at least one Wine/MoonLoader build `renderGetFontDrawHeight` answers from
    an ordinary callback and returns 0 from inside mimgui's before-frame hook -
    which is where the bake, and therefore the question, happens. So the
    correction never engages there and text stays at the config size.

    Moving the question into the consumer's `present()` looked like the fix and
    is NOT: an entry whose native height never arrives is asked again every
    frame, and asking builds and destroys a D3D font. Six entries times sixty
    frames a second made the game unplayable and took the menu's icon glyphs
    with it. If this is attempted again, the measurement must be rate limited
    and hard bounded, and a font must never be created in a per-frame path.

    THE RESIDUAL AFTER BOTH is the letterforms, and that is not a size problem.
    A config naming a font that is actually installed gets the same file in both
    renderers and needs neither correction to be exact.
]]
-- Mixed case and digits, ASCII only: this is measured through two renderers
-- with different notions of what is in a font, and it has to be a string both
-- certainly have.
local SAMPLE = 'ABCabcdefgh0123'

local nativeMetrics = {}   -- family\0size\0flags -> {height =, width =}
local faceRatio = {}       -- family\0styleflags  -> native width / imgui width

local function faceKeyOf(family, flags)
    return family .. '\0' .. band(flags, BOLD + ITALICS)
end

--[[
    What the native layer makes of this spec. Cached: answering it builds a D3D
    font, and the answer does not change.
]]
--[[
    A FAILURE IS NOT CACHED. This is the bug that made the whole correction do
    nothing.

    The first version stored whatever came back, including nothing, and the
    first ask happened during initialisation - from a download callback, before
    a single frame had been drawn. Whatever made `renderCreateFont` decline at
    that moment was then the permanent answer: every face baked at its config
    size forever, and the report cheerfully printed a native height of 11 next
    to an ImGui face baked at 8, because the report asked later, when it worked.

    So an empty answer is thrown away and asked again next time. The question is
    cheap, the answer is stable once it exists, and a wrong permanent answer is
    the expensive kind.
]]
local function nativeOf(family, size, flags)
    local key = family .. '\0' .. size .. '\0' .. flags
    local m = nativeMetrics[key]
    if m then return m end

    m = {height = 0, width = 0}
    local font = renderM.acquire(family, size, flags)
    if font then
        m.height = tonumber(renderM.height(font)) or 0
        m.width  = tonumber(renderM.measure(font, SAMPLE)) or 0
        renderM.release(font)
    end
    if m.height > 0 then nativeMetrics[key] = m end
    return m
end

--[[
    ASKED AT BAKE TIME, not when the font was acquired.

    Acquiring happens wherever a consumer happens to build its fonts - for
    hud.lua that is inside initialisation, from a download callback, before
    anything has been drawn. Baking happens in mimgui's before-frame hook, which
    by construction is inside a live renderer with a device that is presenting.
    That is the moment the native layer can be asked and believed, so the size
    is decided there and an entry carries the REQUEST until then.
]]
--[[
    ASKED AT BAKE TIME, not when the font was acquired.

    Acquiring happens wherever a consumer happens to build its fonts - for
    hud.lua that is inside initialisation, from a download callback, before
    anything has been drawn. Baking happens in mimgui's before-frame hook, which
    by construction is inside a live renderer with a device that is presenting.
    That is the moment the native layer can be asked and believed, so the size
    is decided there and an entry carries the REQUEST until then.
]]
local function desiredBakeSize(entry)
    local m = nativeOf(entry.family, entry.configSize, entry.flags)

    -- Nothing to ask - a host test, or a machine where renderCreateFont
    -- declined. The config number is then the only number there is.
    local px = entry.configSize
    if m.height >= 1 and m.height <= 256 then px = m.height end

    local ratio = faceRatio[entry.faceKey]
    if ratio then px = px * ratio end

    px = floor(px + 0.5)
    if px < 1 then px = 1 end
    if px > 256 then px = 256 end
    return px
end

local function entryFor(family, configSize, flags, file, faceKey)
    local key = faceKey .. '\0' .. configSize
    local entry = entries[key]
    if entry then return entry end

    if baked >= MAX_FONTS then
        if not cappedWarned then
            cappedWarned = true
            print(('[akacross.draw_imgui] %d baked fonts is the cap; reusing the closest')
                :format(MAX_FONTS))
        end
        return closestEntry(file, configSize)
    end

    entry = {file = file, family = family, configSize = configSize, flags = flags,
             faceKey = faceKey, key = key,
             bakeSize = nil, imfont = nil, refs = 0, height = 0}
    entries[key] = entry
    pending[#pending + 1] = entry
    return entry
end

function M.acquireFont(family, size, flags)
    size = floor(tonumber(size) or 0)
    if size < 1 then return nil end
    flags = floor(tonumber(flags) or 0)

    local file = fontsM.resolve(family, flags)
    if not file then return nil end

    local entry = entryFor(family, size, flags, file, faceKeyOf(family, flags))
    if not entry then return nil end

    local hkey = entry.key .. '\0' .. band(flags, DRAW_FLAGS)
    local handle = handles[hkey]
    if handle then
        handle.refs = handle.refs + 1
        return handle
    end

    handle = {entry = entry, flags = flags, refs = 1, key = hkey}
    handles[hkey] = handle
    entry.refs = entry.refs + 1
    return handle
end

function M.releaseFont(handle)
    if type(handle) ~= 'table' or not handles[handle.key] then return false end
    handle.refs = handle.refs - 1
    if handle.refs > 0 then return false end
    handles[handle.key] = nil

    local entry = handle.entry
    entry.refs = entry.refs - 1
    --[[
        An entry nothing holds AND that was never baked is dropped outright.
        This is what keeps a size drag cheap: 8 -> 9 -> 10 -> ... -> 30 releases
        each intermediate before the next rebuild fires, so twenty-two specs are
        created and twenty-one are forgotten without ever reaching the atlas.

        A BAKED entry stays whatever its refcount says. There is no way to
        remove one font from an ImFontAtlas - only Fonts:Clear(), which would
        take mimgui's own font zero and every other module's with it.
    ]]
    if entry.refs <= 0 and entry.imfont == nil then
        entries[entry.key] = nil
    end
    return true
end

function M.swapFont(old, family, size, flags)
    local handle = M.acquireFont(family, size, flags)
    if handle == nil then return old end
    if handle == old then
        M.releaseFont(handle)   -- undo the extra reference
        return old
    end
    if old ~= nil then M.releaseFont(old) end
    return handle
end

local function measureRaw(font, size, text, from, to)
    if font == nil or text == nil or text == '' then return 0 end
    imgui.lib.ImFont_CalcTextSizeA_nonUDT(sizeOut, font, size, 3.4028234663853e+38, 0,
        from or text, to, nil)
    return sizeOut.x
end

--[[
    Bake everything pending, then rebuild the texture ONCE.

    Called from mimgui's before-frame hook, which runs after the previous
    EndFrame and before this NewFrame - the only moment the atlas is not in use.
    Doing it per added font would be a full re-rasterise and texture upload per
    font; doing it here is one of each per frame that changed anything.
]]
--[[
    A file ImGui cannot open reaches `IM_ASSERT(0)` inside AddFontFromFileTTF.
    In a release build of cimgui that is a no-op and the call returns NULL, but
    that is a property of how somebody else compiled a DLL, not a guarantee. One
    stat call per bake is cheaper than finding out.
]]
local function fileExists(path)
    local ok, exists = pcall(function() return _G['doesFileExist'](path) end)
    if not ok then return true end   -- no native to ask: proceed as before
    return exists and true or false
end

local function buildAtlas()
    if #pending == 0 then return end

    --[[
        BEFORE NewFrame, which is after the previous EndFrame. ImGui sets
        `Fonts->Locked` in NewFrame and clears it in EndFrame, and adding a font
        while it is set is an assert - so this is not merely a good moment, it
        is the only one in a present.
    ]]
    local atlas = imgui.GetIO().Fonts
    if glyphRanges == nil then
        local builder = imgui.ImFontGlyphRangesBuilder()
        builder:AddRanges(atlas:GetGlyphRangesCyrillic())   -- Latin comes with it
        glyphRanges = imgui.ImVector_ImWchar()
        builder:BuildRanges(glyphRanges)
    end

    local cfg = imgui.ImFontConfig()
    -- Small text on the pixel grid. hud draws at 8 and 10 pixels, where the
    -- horizontal oversampling ImGui does by default is the difference between
    -- legible and smeared, and snapping is the rest of it.
    cfg.PixelSnapH = true

    local added = 0
    -- The entries baked in THIS pass, kept because `pending` is cleared below
    -- and the ratio can only be learned from a face that now exists.
    local justBaked = {}
    for i = 1, #pending do
        local entry = pending[i]
        if entry.refs > 0 and entries[entry.key] == entry and fileExists(entry.file) then
            --[[
                The size is decided HERE, which is the point of doing this in
                the before-frame hook: the native layer can be asked and
                believed. An entry that is already baked comes back through when
                the face ratio has been learned since - it is re-baked at the
                corrected size and the old face is abandoned in the atlas, which
                cannot give one back anyway.
            ]]
            local want = desiredBakeSize(entry)
            --[[
                A bake that had to fall back to the config size is not finished.
                The native layer being unavailable is a state, not an answer, so
                the entry is kept on a short retry list rather than left at a
                size nobody chose. Capped, because a machine where the native
                layer never answers must not add a face per frame forever.
            ]]
            entry.uncalibrated = nativeOf(entry.family, entry.configSize, entry.flags).height <= 0
            if entry.imfont == nil or entry.bakeSize ~= want then
                local ok, font = pcall(atlas.AddFontFromFileTTF, atlas,
                    entry.file, want, cfg, glyphRanges[0].Data)
                if ok and font ~= nil then
                    entry.imfont = font
                    entry.bakeSize = want
                    entry.height = 0          -- re-measured below, at the new size
                    baked = baked + 1
                    added = added + 1
                    justBaked[#justBaked + 1] = entry
                elseif entry.imfont == nil then
                    -- A file the rasteriser would not take. Forget it rather
                    -- than retrying it every frame. A re-bake that fails keeps
                    -- the face that works.
                    entries[entry.key] = nil
                end
            end
        elseif entry.imfont == nil and entries[entry.key] == entry
               and not fileExists(entry.file) then
            entries[entry.key] = nil
        end
    end
    pending = {}

    --[[
        Anything baked without a native answer goes round again. Five passes,
        which is five frames - long enough for a renderer that is coming up,
        short enough that one that never will costs five faces and stops.
    ]]
    for _, entry in pairs(entries) do
        if entry.uncalibrated and entry.imfont ~= nil then
            entry.retries = (entry.retries or 0) + 1
            if entry.retries <= 5 then pending[#pending + 1] = entry end
        end
    end

    --[[
        LEARN THE FACE RATIO from what was just baked.

        This is the only moment the ImGui side of the comparison exists: the
        face is in the atlas and can be measured. The native side was taken when
        the spec was acquired. One ratio per family and style, computed once,
        which every other size of that face then uses without a probe of its
        own.
    ]]
    local learned = false
    for i = 1, #justBaked do
        local entry = justBaked[i]
        local nativeWidth = nativeOf(entry.family, entry.configSize, entry.flags).width
        if entry.imfont ~= nil and entry.faceKey and not faceRatio[entry.faceKey]
           and nativeWidth > 0 then
            local mine = measureRaw(entry.imfont, entry.bakeSize, SAMPLE)
            if mine > 0 then
                local ratio = nativeWidth / mine
                -- A ratio this far out is not a face difference, it is a
                -- measurement that means something other than what is assumed.
                if ratio > 0.25 and ratio < 4 and math.abs(ratio - 1) > 0.02 then
                    faceRatio[entry.faceKey] = ratio
                    learned = true
                    -- Everything baked for this face now wants a different
                    -- size, so it goes back in the queue for the next pass.
                    for _, other in pairs(entries) do
                        if other.faceKey == entry.faceKey then
                            pending[#pending + 1] = other
                        end
                    end
                else
                    faceRatio[entry.faceKey] = 1
                end
            end
        end
    end

    if added > 0 or learned then
        imgui.InvalidateFontsTexture()
        imgui.CreateFontsTexture()
        -- Heights are only knowable now, and every cached measurement a
        -- consumer took before this was taken against a font that did not
        -- exist. `invalidate` is how it finds out.
        for _, entry in pairs(entries) do
            if entry.imfont ~= nil and entry.height == 0 then
                --[[
                    ASCENT MINUS DESCENT, not a measured string.

                    ImFont::CalcTextSizeA returns `line_height = size` for its
                    y, unconditionally - so measuring 'Ag' to find the height
                    just hands back the size that was asked for, which is what
                    the first version did and what made every slot in the report
                    read h=8 for 8px text. The real line box is the ascender to
                    the descender, and it is what the drag boxes in a settings
                    menu need to cover the glyphs a user can see.
                ]]
                local ok, h = pcall(function()
                    return entry.imfont.Ascent - entry.imfont.Descent
                end)
                entry.height = (ok and h and h > 0) and h or entry.bakeSize
            end
        end
        draw.invalidate()
    end
end

function M.height(handle)
    if type(handle) ~= 'table' then return 0 end
    return handle.entry and handle.entry.height or 0
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------
--[[
    ImGui reads UTF-8; SA-MP hands out cp1251. Pure ASCII is already UTF-8 and
    is the overwhelmingly common case here - names, numbers, zone names out of
    the GXT - so it costs one search and no allocation. Anything with a high
    byte goes through iconv, if the encoding module is present; if it is not,
    the bytes go as they are and ImGui renders what it can of them.
]]
local encoder = nil
do
    local ok, encoding = pcall(require, 'encoding')
    if ok and type(encoding) == 'table' and encoding.UTF8 then
        encoder = encoding.UTF8
    end
end

local function utf8ify(text)
    if not text:find('[\128-\255]') then return text end
    if not encoder then return text end
    local ok, out = pcall(encoder.encode, encoder, text, 'cp1251')
    if ok and type(out) == 'string' then return out end
    return text
end

--[[
    One run of one colour, with the flags GDI would have baked into the face.

    The border is the run stamped at the four diagonals rather than the eight
    compass points: four draws instead of eight for an outline that is one pixel
    thick either way at these sizes. The shadow goes down first so the border
    sits on top of it, which is the order GDI composites them in.
]]
--[[
    Black at somebody else's alpha.

    A fixed opaque outline is the same mistake the bar border was: fade a text
    element to half and the glyphs go ghostly while a solid black outline stays
    exactly where it was, so the element does not look faded, it looks broken.
    GDI's border and shadow carry the alpha of the text they belong to.

    `col` is an ImU32, so the alpha is already the top byte and black is nothing
    but that byte. The modulo is the usual one: bit.band yields a signed 32-bit
    number and this has to arrive at an unsigned parameter as itself.
]]
local function shadeOf(col)
    return band(col, 0xFF000000) % 4294967296
end

local function drawRun(font, size, text, x, y, col, flags, width)
    local shade = shadeOf(col)
    if band(flags, SHADOW) ~= 0 then
        list:AddTextFontPtr(font, size, at(pA, x + 1, y + 1), shade, text)
    end
    if band(flags, BORDER) ~= 0 then
        list:AddTextFontPtr(font, size, at(pA, x - 1, y - 1), shade, text)
        list:AddTextFontPtr(font, size, at(pA, x + 1, y - 1), shade, text)
        list:AddTextFontPtr(font, size, at(pA, x - 1, y + 1), shade, text)
        list:AddTextFontPtr(font, size, at(pA, x + 1, y + 1), shade, text)
    end
    list:AddTextFontPtr(font, size, at(pA, x, y), col, text)

    if band(flags, UNDERLINE) ~= 0 then
        local ly = y + size
        list:AddRectFilled(at(pA, x, ly), at(pB, x + width, ly + 1), col, 0)
    end
    if band(flags, STRIKEOUT) ~= 0 then
        local ly = y + size * 0.5
        list:AddRectFilled(at(pA, x, ly), at(pB, x + width, ly + 1), col, 0)
    end
end

--[[
    `{RRGGBB}` replaces the RGB and KEEPS the alpha of the colour it was handed,
    which is what renderFontDrawText does - the tags are meant to recolour text
    that is already fading, not to make it opaque again.
]]
local function runColour(base, hex)
    local alpha = base - (base % 0x1000000)
    return alpha + tonumber(hex, 16)
end

function M.text(handle, str, x, y, color)
    if list == nil or type(handle) ~= 'table' then return false end
    if type(str) ~= 'string' or str == '' then return false end
    local entry = handle.entry
    local font = entry and entry.imfont
    if font == nil then return false end

    local size, flags = entry.bakeSize, handle.flags
    local base = (color or -1) % 4294967296

    -- No tags is the common case, and it is one draw with no substrings.
    if not str:find('{', 1, true) then
        local text = utf8ify(str)
        local width = 0
        if band(flags, UNDERLINE + STRIKEOUT) ~= 0 then
            width = measureRaw(font, size, text)
        end
        drawRun(font, size, text, x, y, toImU32(base), flags, width)
        return true
    end

    local i, n, col = 1, #str, base
    while i <= n do
        local s, e, hex = str:find('{(%x%x%x%x%x%x)}', i)
        local chunk
        if not s then
            chunk = str:sub(i)
            i = n + 1
        else
            chunk = (s > i) and str:sub(i, s - 1) or nil
            i = e + 1
        end
        if chunk and chunk ~= '' then
            local text = utf8ify(chunk)
            local width = measureRaw(font, size, text)
            drawRun(font, size, text, x, y, toImU32(col), flags, width)
            x = x + width
        end
        if s then col = runColour(base, hex) end
    end
    return true
end

--[[
    The width of what will actually be drawn: the tags are consumed, so they are
    stripped before measuring. Measuring the tagged string is the alignment bug
    akacross.render's `plain()` exists to prevent, one renderer along.
]]
function M.measure(handle, str)
    if type(handle) ~= 'table' or type(str) ~= 'string' or str == '' then return 0 end
    local entry = handle.entry
    local font = entry and entry.imfont
    if font == nil then return 0 end

    local text = str
    if text:find('{', 1, true) then text = (text:gsub('{%x%x%x%x%x%x}', '')) end
    if text == '' then return 0 end
    return measureRaw(font, entry.bakeSize, utf8ify(text))
end

-- ---------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------
local function frameCondition()
    if not drawPass then return false end
    if visible == nil then return true end
    local ok, on = pcall(visible)
    return ok and on and true or false
end

--[[
    Before mimgui's NewFrame, which is after the previous EndFrame: the one
    moment in a present when the font atlas is not being read.
]]
local function frameBefore()
    local ok, err = pcall(buildAtlas)
    if not ok then
        print('[akacross.draw_imgui] atlas build error: ' .. tostring(err))
        pending = {}
    end
end

local function frameDraw()
    -- This callback only runs between NewFrame and EndFrame, which is what
    -- makes it the one place a texture can safely be created.
    list = imgui.GetBackgroundDrawList()
    local ok, err = pcall(drawPass)
    list = nil
    if not ok then
        -- One frame's pass raising must not take the imgui frame down with it -
        -- that would leave the renderer between NewFrame and EndFrame.
        print('[akacross.draw_imgui] draw pass error: ' .. tostring(err))
    end
end

--[[
    SUBSCRIBED ONCE, AT LOAD. THIS COST A CRASH.

    The obvious shape is to subscribe in attach() and Unsubscribe in detach().
    It faults, hard - an ACCESS_VIOLATION inside lua51.dll:

        mimgui draws with `for _, sub in ipairs(subscriptionsNewFrame) do
        sub:_draw() end`, and a consumer's renderer toggle lives in a settings
        window drawn BY one of those `_draw` calls. So switching backends from
        that checkbox reached `imgui.OnFrame` (a table.insert) and
        `sub:Unsubscribe` (a table.remove) on the very list ipairs was walking.
        Grow the array part mid-loop and a compiled trace is holding a pointer
        to memory that was just freed.

    So the subscription is created here, once, and never inserted or removed
    again. attach() and detach() only set and clear `drawPass`, and
    `frameCondition` returns false when there is not one - an inactive
    subscription costs mimgui a predicate call per frame and nothing else.

    `HideCursor` is set because this subscription is active whenever the HUD is
    on screen, which is nearly always. Without it mimgui would take an active
    subscription to mean somebody wants a cursor. mimgui ANDs the flag across
    active subscriptions, so a settings window still gets one.
]]
do
    local okSub, made = pcall(imgui.OnFrame, frameCondition, frameBefore, frameDraw)
    if okSub and made then
        sub = made
        sub.HideCursor = true
    end
end

function M.attach(pass, visiblePredicate)
    drawPass, visible = pass, visiblePredicate
end

--- Stop drawing. The subscription STAYS - see above; it simply stops being
--- active, because frameCondition has no pass to report.
function M.detach()
    drawPass, visible = nil, nil
end

--- Nothing. This backend draws inside imgui's frame, not in the consumer's
--- present; see the header.
function M.present() end

--- {entries =, baked =, handles =, pending =} for a diagnostic command. A baked
--- count that climbs with nothing but menu use is the atlas growth the release
--- path exists to bound.
function M.stats()
    local nEntries, nHandles = 0, 0
    for _ in pairs(entries) do nEntries = nEntries + 1 end
    for _ in pairs(handles) do nHandles = nHandles + 1 end
    return {entries = nEntries, baked = baked, handles = nHandles, pending = #pending}
end

--- An array of lines, appended to akacross.draw's report.
function M.report()
    local st = M.stats()
    local lines = {
        ('imgui atlas: %d baked, %d faces, %d handles, %d pending%s')
            :format(st.baked, st.entries, st.handles, st.pending,
                    st.baked >= MAX_FONTS and ('   AT THE %d CAP'):format(MAX_FONTS) or ''),
        ('subscription: %s   drawing: %s')
            :format(sub and 'yes' or 'NO', drawPass and 'yes' or 'no'),
    }

    --[[
        SORTED SEPARATELY, then appended.

        The first version sorted the whole array with a comparator that
        returned false for any pair involving a header line. That is not a
        strict weak ordering - it is not even transitive - so table.sort was
        free to interleave the headers into the font list, and did: the
        subscription line came out between two faces. A comparator has to be a
        real ordering or the sort is undefined, and the fix is not a cleverer
        comparator, it is not sorting two different kinds of line together.
    ]]
    local faces = {}
    for _, entry in pairs(entries) do
        -- `holders` is what a reader means by refs: how many callers are
        -- holding a font on this face. `entry.refs` counts distinct HANDLES,
        -- which is a different and much smaller number - twenty elements
        -- sharing one flag combination are one handle.
        local holders = 0
        for _, handle in pairs(handles) do
            if handle.entry == entry then holders = holders + handle.refs end
        end
        faces[#faces + 1] = ('  %-20s cfg %2d -> baked %s  %s  %d holder(s)'):format(
            entry.file:match('[^\\/]+$') or entry.file, entry.configSize,
            tostring(entry.bakeSize or '-'),
            entry.imfont ~= nil and 'baked  ' or 'PENDING', holders)
    end
    table.sort(faces)
    for i = 1, #faces do lines[#lines + 1] = faces[i] end

    local ratios = {}
    for key, r in pairs(faceRatio) do
        local family, style = key:match('^(.*)%z(%d+)$')
        ratios[#ratios + 1] = ('  face %-16s style %-2s  width x%.3f%s'):format(
            tostring(family), tostring(style), r,
            math.abs(r - 1) < 0.02 and '   (same face in both)' or '   (substituted face - corrected)')
    end
    table.sort(ratios)
    for i = 1, #ratios do lines[#lines + 1] = ratios[i] end

    local fontLines = fontsM.report()
    for i = 1, #fontLines do lines[#lines + 1] = fontLines[i] end
    return lines
end

-- ---------------------------------------------------------------------------
local ok, err = draw.register('imgui', M)
if not ok then
    print('[akacross.draw_imgui] ' .. tostring(err))
end

return M
