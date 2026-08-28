--[[
    akacross.window - a registry of mimgui overlay/menu windows.

    WHY THIS EXISTS
    ---------------
    autobind's window system is spread across five places in the entry script:
    a `menu` table of descriptors, `buildWindowSizes`, `clampWindowPositions`,
    a `cursorM.register` loop, and a ~95-line render loop whose per-window style
    is a chain of `if name == "VehicleStorage" then ... elseif name == "Wanted"`.
    A mod split out of autobind needs all five, and copying them is how the
    dragging fork happened.

    WHAT CHANGES vs THE ORIGINAL
    ----------------------------
    Only one thing, and it removes a bug class. The original pushes ImGui style
    in a name-keyed chain and pops with hand-counted literals - `PopStyleVar(5)`,
    `PopStyleVar(4) -- base WindowPadding + BorderSize/Rounding/WindowPadding`.
    Every edit to a push has to be mirrored in a count somewhere else in the
    file, and a mismatch corrupts the ImGui stack for every window drawn after
    it. Here a window's `style` hook receives a pusher that counts what it
    pushed, and the module pops exactly that. The counts cannot drift because
    nobody writes them.

    Everything else is preserved: same drag call, same clamp math, same
    condition predicate feeding both render and cursor ownership.

    USAGE
    -----
        local windows = require('akacross.window').new{
            screenRes = screenRes,   -- live vector, updated on resolution change
            mousePos  = mousePos,    -- live vector, updated per frame
        }

        windows:add('Speedometer', {
            open       = new.bool(true),
            conditions = function() return speedo.shouldRender() end,
            pos        = Windows.positions.Speedometer,
            pivot      = Speedo.Pivot,
            borderSize = Speedo.BorderSize,
            sizer      = function(size) size.x, size.y = speedo.windowSize() end,
            style      = function(p)
                p:color(imgui.Col.WindowBg, Speedo.BackgroundColor)
                p:varFloat(imgui.StyleVar.WindowRounding, Speedo.Rounding[0])
            end,
            draw       = function() speedo.render() end,
        })

        windows:buildSizes()             -- sizers + clamp; on load and on rebuild
        scaleM.onRebuild(function() windows:buildSizes() end)
        windows:attachCursor(cursorM, 'driving')
        -- inside your OnFrame:
        windows:render()

    PER-STATE, LIKE EVERYTHING ELSE
    -------------------------------
    MoonLoader gives each script its own Lua state, so each mod holds its own
    registry. Two mods drawing the same logical overlay is a coordination
    problem between scripts, not something this module can see; that is what
    akacross.claims is for.
]]

local window = {}
window._VERSION = '0.1.0'

local imgui = require('mimgui')
local imgui_funcs = require('akacross.imgui_funcs')

-- Default flags for a chromeless overlay. Callers override per window.
window.OVERLAY_FLAGS = imgui.WindowFlags.NoTitleBar
    + imgui.WindowFlags.NoResize
    + imgui.WindowFlags.NoScrollbar
    + imgui.WindowFlags.NoCollapse
    + imgui.WindowFlags.NoSavedSettings

--[[
    The pusher handed to a window's `style` hook. Counts every push so the
    module can pop precisely, instead of the caller maintaining a literal.
]]
local Pusher = {}
Pusher.__index = Pusher

local function newPusher()
    return setmetatable({vars = 0, colors = 0, fonts = 0}, Pusher)
end

function Pusher:color(col, value)
    imgui.PushStyleColor(col, value)
    self.colors = self.colors + 1
    return self
end

function Pusher:varFloat(var, value)
    imgui.PushStyleVarFloat(var, value)
    self.vars = self.vars + 1
    return self
end

function Pusher:varVec2(var, value)
    imgui.PushStyleVarVec2(var, value)
    self.vars = self.vars + 1
    return self
end

function Pusher:font(ptr)
    imgui.PushFont(ptr)
    self.fonts = self.fonts + 1
    return self
end

function Pusher:_unwind()
    if self.vars > 0 then imgui.PopStyleVar(self.vars) end
    if self.colors > 0 then imgui.PopStyleColor(self.colors) end
    for _ = 1, self.fonts do imgui.PopFont() end
    self.vars, self.colors, self.fonts = 0, 0, 0
end

local Registry = {}
Registry.__index = Registry

--[[
    The rect to hit-test drags and clamps against.

    For a normal window that is `size`. For an AlwaysAutoResize window `size`
    stays (0,0) forever - ImGui owns the size - so the drag box would have zero
    area and the window could never be picked up at all. `measured` is last
    frame's actual size, captured after Begin, and stands in for exactly those.

    Defined here, above every method that calls it: as a local it is only
    visible to functions declared after it, and a later definition would leave
    the earlier callers resolving it as a nil global.
]]
local function dragRect(e)
    if e.size.x > 0 or e.size.y > 0 then return e.size end
    return e.measured or e.size
end

--[[
    new(cfg) -> registry

    cfg.screenRes  live vector read for clamping; required
    cfg.mousePos   live vector read for dragging; required
    cfg.log        defaults to print
    cfg.onError    (name, err) -> nil. Called when a window's draw throws.
                   Defaults to logging. A throwing window never takes the frame
                   down: imgui.End() still runs and the style stack still
                   unwinds, or every window after it would be corrupted too.
    cfg.onTitleBar (name, titleText) -> nil. Drawn inside Begin for windows
                   that are not overlays. Optional.
]]
function window.new(cfg)
    cfg = cfg or {}
    assert(cfg.screenRes, 'akacross.window: screenRes required')
    assert(cfg.mousePos, 'akacross.window: mousePos required')
    return setmetatable({
        screenRes = cfg.screenRes,
        mousePos = cfg.mousePos,
        log = cfg.log or print,
        onError = cfg.onError,
        onTitleBar = cfg.onTitleBar,
        order = {},
        entries = {},
        pusher = newPusher(),
        errorSeen = {},   -- dedup for per-frame draw errors
    }, Registry)
end

--[[
    add(name, spec) -> registry (chainable)

    Required: open (bool cdata), pos (vector), pivot (vector)
    Optional: conditions, size, sizer, draw, style, title, flags, dragging,
              titlebarHeight, borderSize, overlay, allowCursor, onOpen, onClose

    onOpen/onClose fire on the EDGE of visible() - once when the window becomes
    visible, once when it stops. Windows routinely need per-open setup and
    per-close teardown (re-measuring something, resetting a one-shot flag), and
    without an edge the caller has to keep its own previous-state table, which
    is exactly the bookkeeping this registry exists to absorb.

    `open` is the persisted user toggle; `conditions` is everything else that
    decides visibility. Both must pass. They are kept separate because the
    cursor predicate needs exactly the same answer as the render predicate -
    a window must never hold the cursor while invisible.
]]
function Registry:add(name, spec)
    assert(type(name) == 'string' and #name > 0, 'akacross.window: name required')
    assert(not self.entries[name], 'akacross.window: ' .. name .. ' already added')
    assert(spec and spec.open, 'akacross.window: ' .. name .. ' needs open')
    assert(spec.pos and spec.pivot, 'akacross.window: ' .. name .. ' needs pos and pivot')

    spec.size = spec.size or imgui.ImVec2(0, 0)
    spec.flags = spec.flags or window.OVERLAY_FLAGS
    spec.conditions = spec.conditions or function() return true end

    self.order[#self.order + 1] = name
    self.entries[name] = spec
    return self
end

function Registry:get(name) return self.entries[name] end
function Registry:names()
    local out = {}
    for i, n in ipairs(self.order) do out[i] = n end
    return out
end

-- visible(name) -> bool. The single predicate behind both render and cursor.
function Registry:visible(name)
    local e = self.entries[name]
    if not e or not e.open[0] then return false end
    local ok, result = pcall(e.conditions)
    if not ok then
        self.log(('akacross.window: %s conditions error: %s'):format(name, tostring(result)))
        return false
    end
    return result and true or false
end

--[[
    buildSizes() -> registry

    Runs every window's sizer, then reclamps. Call on load and from
    scaleM.onRebuild, so a UI-scale or resolution change recomputes both.
]]
function Registry:buildSizes()
    for _, name in ipairs(self.order) do
        local e = self.entries[name]
        if e.sizer then
            local ok, err = pcall(e.sizer, e.size)
            if not ok then
                self.log(('akacross.window: %s sizer error: %s'):format(name, tostring(err)))
            end
        end
    end
    return self:clamp()
end

--[[
    clamp() -> registry

    Keep saved anchors on-screen. Positions are absolute px persisted across
    sessions, so one saved at a larger resolution - or a window that has since
    grown - can strand a window off-screen with its titlebar unreachable. Uses
    the same box math as the drag clamp so the two agree.
]]
function Registry:clamp()
    local sr = self.screenRes
    for _, name in ipairs(self.order) do
        local e = self.entries[name]
        -- same rect the drag uses, so the two agree on an auto-resize window
        local pos, size, pivot = e.pos, dragRect(e), e.pivot
        if pos and size and pivot then
            local border = (e.borderSize and e.borderSize[0]) or 0
            local w = size.x > 0 and size.x or 0
            local h = size.y > 0 and size.y or 0
            local boxX = pos.x - w * pivot.x
            local boxY = pos.y - h * pivot.y
            local maxX = math.max(border / 2, sr.x - w - border / 2)
            local maxY = math.max(border / 2, sr.y - h - border / 2)
            if boxX < border / 2 then boxX = border / 2 elseif boxX > maxX then boxX = maxX end
            if boxY < border / 2 then boxY = border / 2 elseif boxY > maxY then boxY = maxY end
            pos.x = boxX + w * pivot.x
            pos.y = boxY + h * pivot.y
        end
    end
    return self
end

-- Drag + place one window. Mirrors autobind's setupWindowDraggingAndSize.
function Registry:_placeWindow(name, e)
    local dragging = e.dragging and e.dragging[0]
    local border = (e.borderSize and e.borderSize[0]) or 0
    local titlebar = (e.titlebarHeight and e.titlebarHeight[0]) or -1
    local moved, posX, posY = imgui_funcs.handleWindowDragging(
        name, e.pos, dragRect(e), e.pivot, border,
        self.mousePos, self.screenRes, dragging, titlebar)
    if moved then
        e.pos.x = posX
        e.pos.y = posY
    end
    imgui.SetNextWindowPos(e.pos, imgui.Cond.Always, e.pivot)
    -- A still-zero size means nobody has measured this window: either its
    -- sizer has not run, or it is an AlwaysAutoResize window whose size ImGui
    -- owns. Forcing Always in that case fights the auto-fit, so leave it.
    if e.size.x > 0 or e.size.y > 0 then
        imgui.SetNextWindowSize(e.size, imgui.Cond.Always)
    end
end

--[[
    _reportDrawError(name, err)

    A draw error is almost never a one-off: the window keeps rendering, so the
    same failure repeats every frame. Logging it raw produced ~70 identical
    lines per second in moonloader.log (observed 2026-08-09, a speedometer
    reaching for a font its entry had not built). Report the first occurrence
    immediately, then suppress the identical message and summarise how many
    times it repeated.
]]
function Registry:_reportDrawError(name, err)
    local key = name .. '\0' .. tostring(err)
    local record = self.errorSeen[key]
    if not record then
        self.errorSeen[key] = {count = 1, reported = 1}
        self.log(('akacross.window: %s draw error: %s'):format(name, tostring(err)))
        return
    end

    record.count = record.count + 1
    -- 1, 10, 100, 1000, ... : enough to show it is still happening without
    -- burying everything else in the log
    if record.count >= record.reported * 10 then
        record.reported = record.count
        self.log(('akacross.window: %s draw error (x%d): %s')
            :format(name, record.count, tostring(err)))
    end
end

-- Forget suppressed errors, so a fixed-then-broken-again window reports afresh.
function Registry:clearErrors()
    self.errorSeen = {}
    return self
end

--[[
    render() -> drawnCount

    Call from inside a mimgui OnFrame. Every window that is open and whose
    conditions pass gets styled, placed, begun, drawn, ended and unwound.

    The unwind is unconditional: a draw that throws still gets its End() and
    its style pops, because ImGui state is global to the frame and leaking it
    would corrupt every window drawn after this one.
]]
function Registry:render()
    local drawn = 0
    for _, name in ipairs(self.order) do
        local e = self.entries[name]
        local isVisible = self:visible(name)

        -- Edge detection before anything draws, so onOpen can size or reset
        -- state that this very frame will read.
        if isVisible ~= (e._wasVisible or false) then
            e._wasVisible = isVisible
            local hook = isVisible and e.onOpen or e.onClose
            if hook then
                local ok, err = pcall(hook, name)
                if not ok then
                    self.log(('akacross.window: %s %s hook error: %s')
                        :format(name, isVisible and 'onOpen' or 'onClose', tostring(err)))
                end
            end
        end

        if isVisible then
            local pusher = self.pusher
            pusher.vars, pusher.colors, pusher.fonts = 0, 0, 0

            if e.style then
                local ok, err = pcall(e.style, pusher)
                if not ok then
                    self.log(('akacross.window: %s style error: %s'):format(name, tostring(err)))
                end
            end

            self:_placeWindow(name, e)

            local opened = imgui.Begin(name, e.open, e.flags)

            -- Record what ImGui actually made this window, so an auto-resize
            -- window has a drag box next frame. Valid between Begin and End
            -- whether or not the window is collapsed.
            local actual = imgui.GetWindowSize()
            if not e.measured then
                e.measured = imgui.ImVec2(actual.x, actual.y)
            else
                e.measured.x, e.measured.y = actual.x, actual.y
            end

            if opened then
                if e.overlay and not e.overlay[0] and self.onTitleBar then
                    local title = e.title and e.title() or name
                    pcall(self.onTitleBar, name, title)
                end
                if e.draw then
                    local ok, err = pcall(e.draw)
                    if not ok then
                        if self.onError then
                            pcall(self.onError, name, err)
                        else
                            self:_reportDrawError(name, err)
                        end
                    end
                end
                drawn = drawn + 1
            end
            imgui.End()
            pusher:_unwind()
        end
    end
    return drawn
end

--[[
    attachCursor(cursorM, prefix) -> registry

    Register every window as a cursor/input consumer. The condition is exactly
    the render predicate, so a window can never hold the cursor while invisible.
    `input` is true for all of them because even a pure overlay needs ImGui to
    keep receiving mouse events - that is what dragging reads.
]]
function Registry:attachCursor(cursorM, prefix)
    if not cursorM then return self end
    prefix = prefix or 'window'
    for _, name in ipairs(self.order) do
        local e = self.entries[name]
        cursorM.register(prefix .. ':' .. name, {
            condition = function() return self:visible(name) end,
            cursor = function() return e.allowCursor and e.allowCursor[0] or false end,
            input = true,
            lock = function() return e.lockPlayer and e.lockPlayer[0] or false end,
        })
    end
    return self
end

return window
