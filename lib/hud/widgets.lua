--[[
    hud.widgets - the allocation-free widget layer for the HUD settings menu.

    WHY THIS IS A MODULE AND NOT INLINE
    -----------------------------------
    It used to be inline, in hud.lua, and that was the constraint rather than
    the design: the updater fetched one file, so there was nowhere else for it
    to go. hud.lua now self-heals its lib/ directory exactly as driving,
    wanted, vstorage and fastmap do, which removes that constraint - and it had
    to be removed, because the entry was within a few names of Lua 5.1's
    200-locals-per-function ceiling and the main chunk IS one function.

    WHAT IT IS
    ----------
    Every widget in this menu used to allocate its own buffer, inline, per
    frame:

        imgui.Checkbox(u8'Bar', new.bool(hud.tog[mid][1]))   -- the v1 config

    which is a fresh cdata object AND a fresh u8 conversion on every frame the
    window is open. The Other tab draws eleven of those plus eleven font rows,
    and each font row built two tables, eight concatenated widget ids, three
    more cdata buffers and a colour conversion - on the order of 150
    allocations a frame, for a panel whose contents only change when the user
    clicks something.

    So the buffers live here instead.

    A SCRATCH buffer is enough for anything that round-trips through the config
    within one frame - a checkbox, a drag, a colour edit: the value is copied
    in, the widget runs, whatever it changed is copied back out, and nothing
    has to survive to the next frame. That is exactly what the inline
    `new.bool(...)` was doing, minus the allocation, so the behaviour is
    identical.

    TEXT FIELDS ARE THE EXCEPTION and get a persistent buffer each, because a
    half-typed string has to live somewhere between frames. They are re-seeded
    from the config only when the config value actually changes, so a config
    reload updates the box while typing in it does not fight the user.

    COLOUR EDITORS keep a buffer too, re-converted only when the stored ARGB
    changes - and the value written back is remembered, so dragging in the
    picker does not re-convert what it just produced.

    SELF-SUFFICIENT. Everything here is either a mimgui call or a shared
    akacross helper, so the module requires what it needs and takes no
    injection at all. That is what lets the settings tabs treat it as a
    vocabulary rather than as a thing to be wired up.
]]

local M = { _VERSION = '0.1.0' }

local imgui  = require('mimgui')
local scaleM = require('akacross.scale')
local colorsM = require('akacross.colors')
local imguiFuncs = require('akacross.imgui_funcs')
local encoding = require('encoding')

local ffi = require('ffi')
local new, str, copy, fill = imgui.new, ffi.string, ffi.copy, ffi.fill
local u8 = encoding.UTF8

-- ---------------------------------------------------------------------------
-- Scaling
-- ---------------------------------------------------------------------------
--[[
    Every number in this menu - child rectangles, button sizes, cursor
    positions, item widths - is a pixel constant chosen at 1920x1080. On a
    larger display the whole window was a postage stamp in the corner.

    akacross.scale anchors at 1920x1080 => 1.0 and is GROW-ONLY, so at the
    design resolution every number below is unchanged and nothing moves; only a
    bigger screen sees a difference. That anchoring is what makes it safe to
    apply wholesale.

    f() is scalar and allocates nothing, so positions and item widths pass
    through it inline at render time.
]]
function M.sf(v)
    return scaleM.f(v)
end

-- One scratch vector for every SetCursorPos in the menu; each of those used to
-- build an ImVec2 per call per frame.
local scratchVec = imgui.ImVec2(0, 0)

--- Takes DESIGN pixels: the scaling happens here, so every call site is
--- covered by this one function.
function M.setCursor(x, y)
    scratchVec.x, scratchVec.y = scaleM.f(x), scaleM.f(y)
    imgui.SetCursorPos(scratchVec)
end

-- ---------------------------------------------------------------------------
-- Interned strings
-- ---------------------------------------------------------------------------
-- Widget ids that used to be concatenated per widget per frame ('##x' .. k).
local idCache = {}
function M.idFor(prefix, n)
    local byPrefix = idCache[prefix]
    if not byPrefix then byPrefix = {}; idCache[prefix] = byPrefix end
    local id = byPrefix[n]
    if not id then id = prefix .. n; byPrefix[n] = id end
    return id
end

--[[
    idFor2(prefix, a, b) - the same, for an id built from TWO parts.

    `idFor('##box_', key .. partName)` looks interned and is not: the
    concatenation happens BEFORE idFor can look anything up, so it allocates a
    string on every widget on every frame. Nesting the cache one level deeper
    means the composite key is never built at all - which is worth doing
    because the element pane draws up to nine of these per frame and the host
    suite holds a settings tab to 0.05 KB/frame.
]]
local idCache2 = {}
function M.idFor2(prefix, a, b)
    local byPrefix = idCache2[prefix]
    if not byPrefix then byPrefix = {}; idCache2[prefix] = byPrefix end
    local byA = byPrefix[a]
    if not byA then byA = {}; byPrefix[a] = byA end
    local id = byA[b]
    if not id then id = prefix .. a .. b; byA[b] = id end
    return id
end

-- Small integers rendered as text (font sizes), interned once.
local intLabels = {}
function M.intLabel(n)
    local label = intLabels[n]
    if not label then label = tostring(n); intLabels[n] = label end
    return label
end

-- ---------------------------------------------------------------------------
-- Buffers
-- ---------------------------------------------------------------------------
local scratchBool = new.bool(false)
local scratchF1, scratchF2, scratchF3, scratchF4 =
    new.float[1](), new.float[2](), new.float[3](), new.float[4]()

--- Exposed because the Screen tab drives one checkbox from a value that is not
--- a plain table field (the pending renderer), and re-implementing the scratch
--- dance there would mean a second buffer for one widget.
M.scratchBool = scratchBool

local TEXT_LEN = 30
M.TEXT_LEN = TEXT_LEN

local textBuffers = {}

--- A persistent char buffer per widget id. `seed` is the value it should show
--- when it is not being edited; pass nil for a field that starts empty and is
--- only cleared explicitly (the new-file and rename prompts).
function M.textBuf(id, seed)
    local slot = textBuffers[id]
    if not slot then
        slot = {buf = new.char[TEXT_LEN](), last = false}
        textBuffers[id] = slot
        if seed == nil then slot.last = nil end
    end
    if seed ~= nil and slot.last ~= seed then
        slot.last = seed
        fill(slot.buf, TEXT_LEN, 0)
        if #seed > 0 then copy(slot.buf, seed, math.min(#seed, TEXT_LEN - 1)) end
    end
    return slot.buf
end

--[[
    Call right after an InputText.

    While the buffer was rebuilt every frame, typing a font name and then
    clicking away WITHOUT pressing Enter left the box showing the config's
    value again, because the config is what seeded it. A persistent buffer
    keeps the abandoned text instead - the box would read "Aria" while the font
    is still "Arial". Forgetting the seed the moment the field stops being
    edited restores the old behaviour.
]]
function M.releaseTextBuf(id)
    if not imgui.IsItemActive() then
        local slot = textBuffers[id]
        if slot then slot.last = false end
    end
end

function M.clearTextBuf(id)
    local slot = textBuffers[id]
    if slot then
        fill(slot.buf, TEXT_LEN, 0)
        slot.last = nil
    end
end

--- The edited string, decoded back out of a buffer.
function M.textValue(buf)
    return u8:decode(str(buf))
end

-- ---------------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------------
--- A checkbox over a plain Lua boolean at t[k]. True when it changed.
function M.checkbox(label, t, k)
    scratchBool[0] = t[k] and true or false
    if imgui.Checkbox(label, scratchBool) then
        t[k] = scratchBool[0]
        return true
    end
    return false
end

--- DragFloat over loose numbers. The caller writes the results back, because a
--- part keeps its offsets and its sizes as separate fields. Returns nothing
--- when the widget was not touched.
function M.drag1(label, speed, min, max, v)
    scratchF1[0] = v
    if imgui.DragFloat(label, scratchF1, speed, min, max, "%.1f") then
        return scratchF1[0]
    end
end

function M.drag2(label, speed, min, max, a, b)
    scratchF2[0], scratchF2[1] = a, b
    if imgui.DragFloat2(label, scratchF2, speed, min, max, "%.1f") then
        return scratchF2[0], scratchF2[1]
    end
end

function M.drag4(label, speed, min, max, a, b, c, d)
    scratchF4[0], scratchF4[1], scratchF4[2], scratchF4[3] = a, b, c, d
    if imgui.DragFloat4(label, scratchF4, speed, min, max, "%.1f") then
        return scratchF4[0], scratchF4[1], scratchF4[2], scratchF4[3]
    end
end

local COLOR_FLAGS = imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel

local colorBuffers = {}

--- ARGB in, ARGB out. Returns nothing when the picker was not touched, so a
--- caller can write back only on a real change.
function M.colorEdit(label, argb, withAlpha)
    local slot = colorBuffers[label]
    if not slot then
        slot = {buf = withAlpha and new.float[4]() or new.float[3](), last = nil}
        colorBuffers[label] = slot
    end
    local buf = slot.buf
    if slot.last ~= argb then
        slot.last = argb
        local c = colorsM.convertColor(argb, true, withAlpha, false)
        buf[0], buf[1], buf[2] = c.r, c.g, c.b
        if withAlpha then buf[3] = c.a end
    end

    --[[
        PICK THE FUNCTION, THEN CALL IT ONCE.

        This was `withAlpha and imgui.ColorEdit4(...) or imgui.ColorEdit3(...)`,
        and `a and f() or g()` is only a conditional when f() cannot return
        false. A colour editor returns whether the user CHANGED it, so on every
        frame they were not dragging it the ColorEdit4 call returned false, the
        `or` arm was taken, and ColorEdit3 ran as well - drawing a second
        swatch, on its own line, under the first.

        It looked like a duplicated call site and it was one expression.

        reports.lua found and fixed this in its own copy of this helper, and
        left a comment describing the exact symptom - "two swatches per row,
        the second one wrapping onto the next line". hud's copy kept the bug,
        which is the drift these shared helpers exist to stop: driving,
        fastmap, autobind and akacross.ui all pick the FUNCTION first
        (`useAlpha and imgui.ColorEdit4 or imgui.ColorEdit3`), which is safe
        because a function value is never false. Only this one called through
        the ternary.
    ]]
    local editor = withAlpha and imgui.ColorEdit4 or imgui.ColorEdit3
    local changed = editor(label, buf, COLOR_FLAGS)
    if changed then
        local out = withAlpha and colorsM.joinARGB(buf[3], buf[0], buf[1], buf[2], true)
                              or colorsM.joinARGB(255, buf[0], buf[1], buf[2], true)
        slot.last = out
        return out
    end
end

--- A labelled colour editor: the row every settings tab draws.
function M.colorRow(label, argb, caption, withAlpha)
    local out = M.colorEdit(label, argb, withAlpha)
    imgui.SameLine()
    imgui.Text(caption)
    return out
end

function M.tooltip(text)
    if imgui.IsItemHovered() then imgui.SetTooltip(text) end
end

--[[
    A help marker: a dim (?) that carries a tooltip without spending a whole
    row on it.

    The tooltip body is only built when the marker is actually hovered, which
    is what keeps a panel of thirty of them free.
]]
function M.help(text)
    imgui.SameLine()
    imgui.TextDisabled('(?)')
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(scaleM.f(320))
        imgui.TextUnformatted(text)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

--- The shared CustomButton, with an explicit palette. Kept because the confirm
--- prompts want a fixed-size button and imgui.Button's own sizing argument
--- does not take a scaled vector as conveniently.
function M.button(label, size, idle, hovered, active, text)
    return imguiFuncs.CustomButton(label, idle, hovered, active, text, size)
end

return M
