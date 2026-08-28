--[[
    akacross.draw - the screen-drawing surface, behind a swappable backend.

    WHY THIS EXISTS

    hud.lua draws its whole HUD - bars, weapon icons, wanted stars, eleven
    lines of text - through exactly five leaf calls:

        renderDrawBox           renderDrawBoxWithBorder     renderDrawTexture
        renderLoadTextureFromFile                           akacross.render

    Everything above those (the per-element config, partPosition, the VISIBLE
    predicates, the RENDER table) is already backend-agnostic. So a second
    renderer - an ImDrawList one, with antialiasing, rounding, real alpha and
    one batched draw list instead of N native calls that each set up their own
    state - is not a rewrite of the HUD. It is a second implementation of the
    functions listed in CONTRACT below.

    This module is the seam. It is NOT an abstraction invented ahead of a
    need: the need is a user-facing toggle between the native renderer and a
    mimgui one, and the alternative to a seam is `if backend == 'imgui' then`
    at every one of those five call sites.

    WHAT IS AND IS NOT IN THE CONTRACT

    In: the leaf primitives. Geometry, textures, font handles, measurement,
    drawing a string at a final position.

    Out, deliberately:

      - ALIGNMENT. The caller aligns, because the caller already knows the
        width - it needed it for a hit box, or it cached it against a value
        that has not changed. See akacross.render's header; the same argument
        applies one level up.

      - FLAG AND TAG PARSING. `render.flags`, `render.flagsFromArray` and the
        `{RRGGBB}` grammar describe the CONFIG, not the renderer, and both
        backends read the same config. They stay in akacross.render, and a
        consumer of this module keeps using them from there. Two names for one
        function is worse than two requires.

    WHO OWNS THE FRAME

    In: `attach(drawPass, visible)`, `detach()` and `present()`, because the
    two backends genuinely disagree about WHEN.

      native   draws straight from the consumer's `onD3DPresent`.
      imgui    has to append to an ImDrawList from inside imgui's own frame,
               which is a different moment in the same present.

    So the consumer hands over its draw pass ONCE and calls `present()` on
    every present; each backend does what it needs with that. The consumer
    keeps the half that is not drawing - counting frames, clearing values when
    the HUD is hidden - in its own handler, because that has to happen on every
    present whatever is on screen.

    `visible` is a predicate, not a flag, and it is read at a moment the
    consumer does not choose: mimgui polls its subscription conditions from a
    worker thread, not from the present. Derive it once per present and let the
    predicate read the result.

    CAPABILITIES

    The two renderers are not equally able, and pretending otherwise produces
    the worst kind of setting: one that exists, takes a value, and does nothing.
    MoonLoader's `renderDrawBox` draws a rectangle with square corners and has
    no argument for anything else; an ImDrawList rounds, and that difference is
    most of what makes the second renderer worth choosing, because every shape
    a HUD draws is axis-aligned and antialiasing has nothing to bite on.

    So a backend declares what it can do in a `caps` table and a consumer asks
    `can('rounding')` before it offers the control. Extra arguments for things a
    backend cannot do are IGNORED, not an error - that keeps one call site for
    both renderers - and the gate is what stops that being a silent lie.

    COLOUR IS ARGB, ALWAYS

    Every colour crossing this interface is 0xAARRGGBB, because that is what
    MoonLoader's natives take and what every config in this family stores. An
    ImU32 is ABGR - R and B swapped - so a mimgui backend swizzles on the way
    out. That conversion belongs inside the backend that needs it, and stating
    the interface's byte order here is what stops it being done twice or none.

    HANDLES BELONG TO THE BACKEND THAT MADE THEM

    A font handle or a texture from one backend is meaningless to another. So
    `use()` reports whether the backend actually CHANGED, and `generation()`
    counts the switches: a holder compares the generation it acquired at and
    reacquires when it differs. Nothing here can do that for it - this module
    does not know which handles a caller kept.

    NATIVES ARE INJECTED, same as akacross.render: defaults come from _G at
    load, the tests pass fakes through setup().
]]

local M = { _VERSION = '0.2.0' }

local render = require('akacross.render')

-- ---------------------------------------------------------------------------
-- Natives
-- ---------------------------------------------------------------------------
--[[
    A PLAIN INDEX, not rawget - the reason akacross.render and akacross.textdraw
    both give: anything that fronts _G with a metatable (moondev does exactly
    this) puts the natives one hop away, and rawget skips that hop so every read
    comes back nil. Here that would read as "this machine cannot draw" and the
    HUD would silently render nothing at all.
]]
local function bind(name)
    local ok, fn = pcall(function() return _G[name] end)
    if ok and type(fn) == 'function' then return fn end
    return nil
end

-- An explicit LIST rather than pairs() over a table declared with nil values:
-- `{drawBox = nil}` is an EMPTY table in Lua, so setup() would install nothing.
local NATIVE_KEYS = {'drawBox', 'drawBoxWithBorder', 'drawTexture', 'loadTexture', 'releaseTexture'}

local natives = {}

--- Re-read the geometry and texture natives out of _G. Called at load, and
--- again by setup(). The FONT natives belong to akacross.render and are rebound
--- through `render.rebind()`, not here.
function M.rebind()
    natives.drawBox           = bind('renderDrawBox')
    natives.drawBoxWithBorder = bind('renderDrawBoxWithBorder')
    natives.drawTexture       = bind('renderDrawTexture')
    natives.loadTexture       = bind('renderLoadTextureFromFile')
    natives.releaseTexture    = bind('renderReleaseTexture')
    return M
end
M.rebind()

--- setup{drawBox =, drawTexture =, ...} - override any native. Anything omitted
--- keeps whatever _G had. This is the test seam.
function M.setup(opts)
    for _, key in ipairs(NATIVE_KEYS) do
        if opts and opts[key] then natives[key] = opts[key] end
    end
    return M
end

-- ---------------------------------------------------------------------------
-- The contract
-- ---------------------------------------------------------------------------
--[[
    Every function a backend must provide. register() checks the whole list and
    names what is missing, rather than letting a half-written backend install
    itself and nil-call sixty times a second in the middle of a draw.

    Signatures:

      box(x, y, w, h, argb, rounding)
      boxBorder(x, y, w, h, argb, borderSize, borderArgb, rounding)
      texture(tex, x, y, w, h, angle, argb)

      loadTexture(path)  -> tex or nil        releaseTexture(tex)

      acquireFont(name, size, flags) -> font or nil
      swapFont(old, name, size, flags) -> the handle to hold from now on
      releaseFont(font)

      measure(font, text) -> pixel width      height(font) -> line height
      text(font, str, x, y, argb) -> drew?

      attach(drawPass, visible)               detach()
      present()

    `attach` hands the backend the pass to run and the predicate that says
    whether the HUD belongs on screen; `present()` is the consumer offering it
    one present. The native backend runs the pass right there; a backend that
    draws inside someone else's frame ignores `present()` and runs the pass
    from wherever it has to.

    A rectangle with no WIDTH OR HEIGHT draws nothing. The natives get this for
    free - D3D rasterises a zero-area quad as no pixels - but a backend built on
    an antialiased path renderer does not: it expands the degenerate polygon by
    the AA fringe and leaves a coloured sliver. hud.lua's bar fill is
    `width * value / max`, so every bar sitting at zero asks for exactly this,
    and the two renderers have to agree about what it looks like.

    `rounding` is a CAPABILITY, not a promise: a backend that cannot round
    corners ignores it, and the native one cannot. That is only safe because
    `can('rounding')` exists - a consumer asks before it offers the setting, so
    nobody ever sets a number that quietly does nothing. See CAPABILITIES.

    `measure` and `text` both take the RAW string, inline `{RRGGBB}` tags and
    all. Measuring a string that differs from the one being drawn is the
    alignment bug akacross.render's `plain()` exists to prevent, and pushing
    the decision into the backend is what keeps it prevented for a backend that
    renders those tags as coloured runs instead of eating them.
]]
M.CONTRACT = {
    'box', 'boxBorder', 'texture',
    'loadTexture', 'releaseTexture',
    'acquireFont', 'swapFont', 'releaseFont',
    'measure', 'height', 'text',
    'attach', 'detach', 'present',
}

-- ---------------------------------------------------------------------------
-- The native backend
-- ---------------------------------------------------------------------------
--[[
    It lives in this file rather than a sibling because it is thin by
    construction: akacross.render already owns the whole font half (the
    refcounted cache, the measurement, the tag stripping), so what is left is
    five natives with their arguments in the right order. The mimgui backend
    gets its own file - it has to resolve font family names to .ttf paths,
    rebuild the atlas outside the frame, emulate the border/shadow/underline
    flags and split tagged strings into coloured runs, none of which belongs
    next to this.
]]
local nativeBackend = {}

-- `rounding` is accepted and dropped: renderDrawBox has no argument for it and
-- no way to fake one that would not cost more than it is worth. `caps` below is
-- how a consumer knows not to offer the setting while this backend is active.
nativeBackend.caps = {}

function nativeBackend.box(x, y, w, h, color, _rounding)
    if not natives.drawBox then return end
    natives.drawBox(x, y, w, h, color)
end

function nativeBackend.boxBorder(x, y, w, h, color, bsize, bcolor, _rounding)
    if not natives.drawBoxWithBorder then return end
    natives.drawBoxWithBorder(x, y, w, h, color, bsize, bcolor)
end

--[[
    The nil texture guard is not defensive padding. hud.lua indexes
    `assets.weapTextures[weaponId]` for weapon ids 0-48, populated only from the
    icon pngs that exist on disk - so one missing file used to raise inside
    onD3DPresent on every frame the player held that weapon. Drawing nothing is
    what a missing font already does one module over.
]]
function nativeBackend.texture(tex, x, y, w, h, angle, color)
    if tex == nil or not natives.drawTexture then return end
    natives.drawTexture(tex, x, y, w, h, angle or 0, color)
end

function nativeBackend.loadTexture(path)
    if not natives.loadTexture then return nil end
    if type(path) ~= 'string' or path == '' then return nil end
    local ok, tex = pcall(natives.loadTexture, path)
    if not ok then return nil end
    return tex
end

function nativeBackend.releaseTexture(tex)
    if tex == nil or not natives.releaseTexture then return false end
    pcall(natives.releaseTexture, tex)
    return true
end

nativeBackend.acquireFont = render.acquire
nativeBackend.swapFont    = render.swap
nativeBackend.releaseFont = render.release
nativeBackend.height      = render.height

--- Strip the inline tags HERE: render.measure takes plain text by contract,
--- and the interface takes raw. See the CONTRACT note.
function nativeBackend.measure(font, text)
    return render.measure(font, render.plain(text))
end

nativeBackend.text = render.draw

--[[
    The frame trio. The native renderer draws straight from the consumer's
    present, so `present()` IS the moment - there is nothing to defer and no
    second frame to append into.
]]
local nativeDrawPass, nativeVisible

function nativeBackend.attach(drawPass, visible)
    nativeDrawPass, nativeVisible = drawPass, visible
end

function nativeBackend.detach()
    nativeDrawPass, nativeVisible = nil, nil
end

function nativeBackend.present()
    if not nativeDrawPass then return end
    if nativeVisible and not nativeVisible() then return end
    nativeDrawPass()
end

-- ---------------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------------
local backends = {native = nativeBackend}
local activeName = 'native'
local active = nativeBackend
local generation = 0
-- The consumer's draw pass, kept HERE and not only in the backend: a switch
-- has to hand it to the new one, and the consumer must not have to re-attach
-- every time it changes renderer.
local attachedPass, attachedVisible = nil, nil

--[[
    register(name, impl) -> true, or nil and a message naming what is missing.

    Checked rather than trusted: a backend is registered once, at load, and a
    function it forgot would otherwise surface as a nil call inside a draw pass
    - the worst possible place to find out, and the hardest to read in a crash
    log that only says the line number in this file.
]]
function M.register(name, impl)
    if type(name) ~= 'string' or name == '' then
        return nil, 'draw.register: a backend needs a name'
    end
    if type(impl) ~= 'table' then
        return nil, ('draw.register: %s is not a table'):format(name)
    end
    local missing = {}
    for i = 1, #M.CONTRACT do
        local key = M.CONTRACT[i]
        if type(impl[key]) ~= 'function' then missing[#missing + 1] = key end
    end
    if #missing > 0 then
        return nil, ('draw.register: backend %q is missing %s')
            :format(name, table.concat(missing, ', '))
    end
    backends[name] = impl
    return true
end

--- Every registered backend name, sorted, so a settings menu can list what is
--- actually installed rather than what it was written expecting.
function M.list()
    local names = {}
    for name in pairs(backends) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function M.available(name) return backends[name] ~= nil end

--- The active backend's name.
function M.backend() return activeName end

--[[
    can('rounding') -> whether the ACTIVE backend can actually do that.

    A consumer asks before it offers a control. Unknown capability names are
    false, and a backend with no `caps` table can do nothing beyond the
    contract - both of which are the answer that cannot mislead anyone.
]]
function M.can(what)
    local caps = active.caps
    if type(caps) ~= 'table' then return false end
    return caps[what] and true or false
end

--[[
    Counts SWITCHES, not calls. Every font handle and every texture a caller is
    holding came from one particular backend and means nothing to the next one,
    so a holder records this number when it acquires and reacquires when it no
    longer matches. This module cannot do that for it: it does not know what
    anyone kept.
]]
function M.generation() return generation end

--[[
    invalidate() -> the new generation.

    For a BACKEND to call when handles it already handed out have changed
    meaning without the backend itself changing. The imgui one does this after a
    font atlas rebuild: the handles are the same tables, but a face that
    measured zero pixels wide a moment ago now has glyphs, and every width a
    consumer cached against it is wrong.

    Same signal as a switch because it is the same question - "is what I am
    holding still what I measured?" - and a consumer that answers it once
    answers it for both.
]]
function M.invalidate()
    generation = generation + 1
    return generation
end

--[[
    use(name) -> ok, changed

    `ok` false means no such backend and NOTHING changed - the caller keeps
    drawing with what it had, which is the only behaviour that cannot blank the
    screen over a typo in a config file.
]]
function M.use(name)
    local impl = backends[name]
    if not impl then return false, false end
    if impl == active then return true, false end

    -- Ordered: the OLD backend lets go of the pass before the new one takes
    -- it, so a backend that registered a subscription or a handler for it can
    -- tear that down while it is still the one being asked.
    if attachedPass then active.detach() end
    activeName, active = name, impl
    generation = generation + 1
    if attachedPass then active.attach(attachedPass, attachedVisible) end
    return true, true
end

-- ---------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------
--[[
    attach(drawPass, visible) -> true, or false if there is nothing to attach.

    `drawPass` is called once per frame the HUD is on screen, by whatever the
    active backend decided is the right moment. `visible` is optional and is a
    PREDICATE: mimgui polls its subscription conditions from a worker thread,
    so this is read at moments the consumer does not choose. Derive it once per
    present and let the predicate read the result.
]]
function M.attach(drawPass, visible)
    if type(drawPass) ~= 'function' then return false end
    if attachedPass then active.detach() end
    attachedPass, attachedVisible = drawPass, visible
    active.attach(drawPass, visible)
    return true
end

--- Stop drawing. The backend tears down whatever it registered.
function M.detach()
    if not attachedPass then return false end
    active.detach()
    attachedPass, attachedVisible = nil, nil
    return true
end

--- One present, offered to the backend. The consumer calls this from its own
--- `onD3DPresent`, on EVERY present, whichever backend is active.
function M.present()
    return active.present()
end

--[[
    An array of lines describing what is drawing and what it can do, plus
    whatever the active backend wants to add through its own `report`.

    This exists because the two failures this layer shipped were both SILENT:
    a crash with nothing in the log, and then an empty font index that made
    every string draw nothing while reporting success at every level. Neither
    was hard to fix and both were hard to see. A renderer that can be asked what
    it is doing turns the next one into a question rather than an investigation.
]]
function M.report()
    local lines = {
        ('renderer: %s   (available: %s)')
            :format(activeName, table.concat(M.list(), ', ')),
        ('generation: %d   rounding: %s   pass: %s')
            :format(generation, tostring(M.can('rounding')),
                    attachedPass and 'attached' or 'NONE'),
    }
    if type(active.report) == 'function' then
        local ok, extra = pcall(active.report)
        if ok and type(extra) == 'table' then
            for i = 1, #extra do lines[#lines + 1] = extra[i] end
        end
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- The surface
-- ---------------------------------------------------------------------------
--[[
    Written out one forwarder per function, rather than copying the backend's
    functions onto M inside use().

    Copying is one table lookup cheaper per call and wrong in two ways that
    matter: a caller that hoisted `local box = draw.box` out of a loop - the
    normal thing to do in a per-frame path - would keep drawing with the
    backend it started with, and the export audit (lib/akacross/test/exports.lua)
    reads assignments statically, so a surface assembled through a computed key
    would look like a module that exports nothing.
]]
function M.box(x, y, w, h, color, rounding)
    return active.box(x, y, w, h, color, rounding)
end

function M.boxBorder(x, y, w, h, color, bsize, bcolor, rounding)
    return active.boxBorder(x, y, w, h, color, bsize, bcolor, rounding)
end

function M.texture(tex, x, y, w, h, angle, color)
    return active.texture(tex, x, y, w, h, angle, color)
end

function M.loadTexture(path)
    return active.loadTexture(path)
end

function M.releaseTexture(tex)
    return active.releaseTexture(tex)
end

function M.acquireFont(name, size, flags)
    return active.acquireFont(name, size, flags)
end

function M.swapFont(old, name, size, flags)
    return active.swapFont(old, name, size, flags)
end

function M.releaseFont(font)
    return active.releaseFont(font)
end

function M.measure(font, text)
    return active.measure(font, text)
end

function M.height(font)
    return active.height(font)
end

function M.text(font, str, x, y, color)
    return active.text(font, str, x, y, color)
end

return M
