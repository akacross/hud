--[[
    akacross.keybinds - the click-then-press keybind editor, shared by the mods
    split out of autobind.

    Promoted out of fastmap.settings when `driving` needed the same thing for
    its shift keys. It was already generic - it takes a binds table and a row
    list and knows nothing about maps - so the alternative was a second copy of
    115 lines that would drift the first time either mod fixed a chord bug.

    A bind is autobind's shape, which every mod here uses:

        Keybinds.GearUp = {Toggle = new.bool(true),
                           Keys = {VK_MENU, VK_G},
                           Types = {'KeyDown', 'KeyPressed'}}

    Keys is the chord in press order; Types is per key, 'KeyDown' for the
    modifiers that must be held and the trigger type for the last one.

    WIRING (both halves are required, and the entry owns them)

        -- while the settings window is drawn
        keybindsM.render(Keybinds, ROWS)

        -- and, in the entry, so a press can reach the capture at all
        function onWindowMessage(msg, wparam, lparam)
            if msg == 256 or msg == 260 then
                if keybindsM.isCapturing() and keybindsM.captureKey(wparam) then
                    consumeWindowMessage(true, false)
                end
            end
        end

    The message hook is not optional: a settings window cannot see raw key
    messages, and polling isKeyDown in a render pass catches the click that
    armed the rebind. onWindowMessage is the only place a press arrives once,
    with its virtual-key code, before the game acts on it.

    STATE IS PER LUA STATE, which is what makes this safe to share: every
    MoonLoader script gets its own copy of the module, so two mods with a
    settings window open cannot capture each other's keys.
]]

local M = { _VERSION = '0.1.0' }

local imgui = require('mimgui')
local scaleM = require('akacross.scale')
local imgui_funcs = require('akacross.imgui_funcs')
local style = require('akacross.style')
local vk = require('vkeys')

-- Abbreviations, so a chord reads as "ALT + M" rather than spilling the row.
local KEY_SHORT = {
    ['Left Control'] = 'LCTRL', ['Right Control'] = 'RCTRL',
    ['Left Shift'] = 'LSHIFT',  ['Right Shift'] = 'RSHIFT',
    ['Left Menu'] = 'LALT',     ['Right Menu'] = 'RALT',
    ['Menu'] = 'ALT', ['Control'] = 'CTRL', ['Shift'] = 'SHIFT',
    ['Spacebar'] = 'SPACE', ['Escape'] = 'ESC',
}

local function keyName(id)
    local ok, name = pcall(vk.id_to_name, id)
    if not ok or not name then return ('#%d'):format(tonumber(id) or 0) end
    return KEY_SHORT[name] or name
end

--- "ALT + M", or "unbound".
local function bindLabel(bind)
    if not bind or #bind.Keys == 0 then return "unbound" end
    local parts = {}
    for _, id in ipairs(bind.Keys) do parts[#parts + 1] = keyName(id) end
    return table.concat(parts, " + ")
end

M.keyName = keyName
M.bindLabel = bindLabel

--[[
    DEFAULT CHORDS - why these three exist rather than cjc's reset

    akacross.config configs implement "reset to defaults" through cjc, which
    snapshots the table during its first load. A keybinds config always has a
    `clear` hook, because bind lists must REPLACE on load and not merge, and
    that hook runs BEFORE the snapshot. So by the time cjc looks, every bind the
    saved file mentions has already had its Keys and Types emptied, and cjc
    records "no keys" as the default. Reset then unbinds instead of restoring.

    The fix is to capture the chords in the entry, straight after the Keybinds
    table is written and before any config machinery has touched it.

        local DEFAULTS = keybindsM.captureDefaults(Keybinds)   -- before cfg:load()
        ...
        cfg:load()
        if keybindsM.noneBound(Keybinds) then                  -- legacy repair
            keybindsM.restoreDefaults(Keybinds, DEFAULTS)
            cfg:save('keybinds')
        end

    A plain Lua copy is enough - Keys are numbers, Types are strings. Toggle is
    cdata and is deliberately NOT captured or restored: giving a bind its keys
    back should not also re-enable one the user switched off.
]]

--- Snapshot the chords as they ship. Call BEFORE the config set loads.
function M.captureDefaults(binds)
    local out = {}
    for name, bind in pairs(binds) do
        if type(bind) == 'table' and bind.Keys and bind.Types then
            local keys, types = {}, {}
            for i, v in ipairs(bind.Keys) do keys[i] = v end
            for i, v in ipairs(bind.Types) do types[i] = v end
            out[name] = {Keys = keys, Types = types}
        end
    end
    return out
end

--- Put every captured bind back to its shipped chord.
function M.restoreDefaults(binds, defaults)
    for name, def in pairs(defaults) do
        local bind = binds[name]
        if bind then
            bind.Keys, bind.Types = {}, {}
            for i, v in ipairs(def.Keys) do bind.Keys[i] = v end
            for i, v in ipairs(def.Types) do bind.Types[i] = v end
        end
    end
end

--- True when NOT ONE bind has a key. The signature of a config written by a
--- build whose clear hook wiped every bind and then saved the emptied table -
--- a state that reloads itself forever, because the empty file keeps restoring
--- the empty lists. One cleared bind is a user's choice; all of them is damage.
function M.noneBound(binds)
    for _, bind in pairs(binds) do
        if type(bind) == 'table' and bind.Keys and #bind.Keys > 0 then
            return false
        end
    end
    return true
end

-- Which bind is currently capturing, or nil.
local capturing = nil
local capturePressed = {}

local MODIFIERS = {[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,
                   [162]=true,[163]=true,[164]=true,[165]=true}

--- captureKey(vkey) -> consumed
--- Called from the entry's onWindowMessage while a rebind is armed. Returns
--- true when the key was taken, so the caller can swallow the message and stop
--- it reaching the game.
function M.captureKey(vkey)
    if not capturing then return false end

    -- ESC abandons rather than binding: a bind that fired on ESC would be
    -- nearly impossible to undo from inside the game.
    if vkey == 27 then
        capturing, capturePressed = nil, {}
        return true
    end

    -- Modifiers accumulate; the first non-modifier ends the chord. That is what
    -- makes ALT+G expressible without a separate "add key" button.
    for _, id in ipairs(capturePressed) do
        if id == vkey then return true end -- already in the chord
    end
    capturePressed[#capturePressed + 1] = vkey

    if not MODIFIERS[vkey] then
        local bind = capturing.bind
        bind.Keys, bind.Types = {}, {}
        for i, id in ipairs(capturePressed) do
            bind.Keys[i] = id
            -- every key but the last is a hold; the last is the trigger
            bind.Types[i] = (i < #capturePressed) and 'KeyDown' or capturing.trigger
        end
        capturing, capturePressed = nil, {}
    end
    return true
end

function M.isCapturing() return capturing ~= nil end

--- Abandon an armed rebind. For a window that is being closed out from under
--- the editor, which would otherwise leave it eating keys.
function M.cancel() capturing, capturePressed = nil, {} end

--[[
    render(binds, rows, extras)

    binds: the mod's Keybinds table
    rows:  { {key = 'GearUp', label = 'Shift Up', desc = '...',
              trigger = 'KeyPressed'}, ... }
           `trigger` is the Type given to the LAST key of the chord and is the
           whole hold-vs-tap decision: 'KeyPressed' fires once per press,
           'KeyDown' re-fires every frame the key is held (the clutch).
    extras: optional function drawn under the rows, for per-bind options that
            are not themselves keys. Keeps those widgets out of the entry.

    A row whose key is missing from `binds` is skipped rather than erroring, so
    a shared row list can name a bind a given mod does not have.
]]
function M.render(binds, rows, extras)
    style.section("Keybinds")

    for _, row in ipairs(rows) do
        local bind = binds[row.key]
        if bind then
            imgui.Checkbox(("##%s_on"):format(row.key), bind.Toggle)
            imgui_funcs.CustomTooltip("Enable or disable this bind without clearing it.")
            imgui.SameLine()
            imgui.Text(row.label)
            imgui.SameLine(scaleM.f(180))

            local armed = capturing and capturing.bind == bind
            local caption = armed and "press a key..." or bindLabel(bind)
            if imgui.Button(("%s##%s_key"):format(caption, row.key), imgui.ImVec2(scaleM.f(170), 0)) then
                if armed then
                    capturing, capturePressed = nil, {}
                else
                    capturing = {bind = bind, trigger = row.trigger or 'KeyPressed'}
                    capturePressed = {}
                end
            end
            imgui_funcs.CustomTooltip(armed
                and "Press the key or chord to bind. ESC cancels."
                or "Click, then press the key or chord. Hold modifiers first (ALT, CTRL, SHIFT).")

            imgui.SameLine()
            if imgui.Button(("Clear##%s_clr"):format(row.key)) then
                bind.Keys, bind.Types = {}, {}
                if armed then capturing, capturePressed = nil, {} end
            end

            if row.desc then
                imgui.TextDisabled(row.desc)
            end
            imgui.Spacing()
        end
    end

    if extras then
        style.section("Options")
        local ok, err = pcall(extras)
        if not ok then imgui.TextDisabled("options failed: " .. tostring(err)) end
    end
end

return M
