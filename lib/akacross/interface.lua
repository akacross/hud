--[[
    akacross.interface - the Interface settings tab, shared by the mods split
    out of autobind.

    fastmap and driving had grown two different versions of the same tab. Same
    job, different behaviour: driving edited a PENDING scale behind Apply and
    Revert, fastmap moved the live cdata under a button that was always enabled;
    driving's slider carried an explanation, fastmap's carried none; fastmap
    printed the resulting factors and a note about what the scale does and does
    not move, driving printed the factors only. Neither difference was a
    decision - they were written weeks apart.

    So the tab is one implementation now and the differences between the two
    mods are data: which independent overlay scale to offer (the mini map, the
    speedometer), what to call the two factors in the readout, and anything
    mod-specific to hang off the end.

    WHY PENDING RATHER THAN LIVE

    Committing a UI scale re-bakes the font atlas, which is a D3D texture
    rebuild. Live-editing means dozens of those a second during a slider drag.
    So the slider edits a scratch value, and Apply is what commits - which also
    gives Revert for free, and lets the tab say plainly whether what you are
    looking at is what is running.

    An overlay scale is different and stays live: it is geometry, not a font, so
    moving it costs a window measurement. `onCommit` fires once when the drag
    ends, for the mods whose overlay does have a baked face of its own (the
    speedometer's readout).

    USAGE

        local ifaceM = require('akacross.interface')

        ifaceM.render{
            uiScale = Settings.uiScale,
            onApply = function() uiScaleDirty = true end,
            overlays = { {label = 'Mini map scale', ...} },
            factors  = { {label = 'Menus', value = ...}, ... },
            notes    = { 'line one', 'line two' },
            extras   = function() ... end,
        }

    After a config reset the caller MUST call resync(uiScale): the pending value
    still holds the pre-reset number, and the tab would otherwise offer to Apply
    it straight back over the defaults.
]]

local M = { _VERSION = '0.1.0' }

local imgui = require('mimgui')
local scaleM = require('akacross.scale')
local imgui_funcs = require('akacross.imgui_funcs')
local style = require('akacross.style')

local new = imgui.new

-- One UI scale per script, so one buffer per Lua state is enough. Seeded on
-- first render rather than at load: this module is required before the entry
-- has called cfg:load(), so at load time the config still holds its defaults.
local pending = new.float[1](1.0)
local seeded = false

local UI_SCALE_MIN, UI_SCALE_MAX = 0.5, 2.0
local EPSILON = 0.001

--- Point the pending value back at the live one. Call after a config reset.
function M.resync(uiScale)
    if uiScale then pending[0] = uiScale[0] end
    seeded = true
end

--- The pending value, for a caller that wants to show it elsewhere.
function M.pendingScale() return pending[0] end

--[[
    render(opts)

    opts.uiScale   REQUIRED cdata float[1] - the mod's persisted UI scale
    opts.onApply   REQUIRED function - raise the mod's uiScaleDirty flag. NOT a
                   direct commit: re-baking the atlas is D3D work and has to
                   happen in the render thread's before-frame hook.
    opts.overlays  list of independent scales, each:
                     {label, id, cdata, min, max, tooltip,
                      onChange  - fired live while dragging (geometry)
                      onCommit  - fired once when the drag ends (font re-bake)}
    opts.factors   list of {label, value} for the readout line; `value` is a
                   function returning a number, evaluated per frame
    opts.notes     list of strings printed dim under the readout
    opts.extras    function drawn last, for anything mod-specific
]]
function M.render(opts)
    local uiScale = opts.uiScale
    if not seeded then
        pending[0] = uiScale[0]
        seeded = true
    end

    style.section("Interface")

    style.labelled("UI scale")
    imgui.SliderFloat("##IfaceUiScale", pending, UI_SCALE_MIN, UI_SCALE_MAX, "%.2fx")
    style.endLabelled()
    imgui_funcs.CustomTooltip(opts.scaleTooltip or
        "Size of this mod's windows, on top of the automatic resolution scaling.\n" ..
        "1.00 is auto only - already larger than design size on a display above 1080p.")

    -- Apply and Revert appear together and only when there is something to
    -- apply, so the tab always says whether what you see is what is running.
    imgui.SameLine()
    if math.abs(pending[0] - uiScale[0]) > EPSILON then
        if imgui.Button("Apply##IfaceUiScale") then
            uiScale[0] = pending[0]
            opts.onApply()
        end
        imgui_funcs.CustomTooltip("Rebuilds the font atlas at the new size.")
        imgui.SameLine()
        if imgui.Button("Revert##IfaceUiScale") then
            pending[0] = uiScale[0]
        end
    else
        imgui.TextDisabled("applied")
    end

    for _, ov in ipairs(opts.overlays or {}) do
        style.labelled(ov.label)
        if imgui.SliderFloat(("##Iface%s"):format(ov.id), ov.cdata,
                             ov.min or 0.4, ov.max or 3.0, "%.2fx") then
            if ov.onChange then ov.onChange() end
        end
        -- Drag-end only: an overlay with its own baked font needs one re-bake,
        -- not one per frame of the drag.
        if ov.onCommit and imgui.IsItemDeactivatedAfterEdit() then ov.onCommit() end
        style.endLabelled()
        if ov.tooltip then imgui_funcs.CustomTooltip(ov.tooltip) end
    end

    if opts.factors and #opts.factors > 0 then
        imgui.Spacing()
        local parts = {}
        for _, f in ipairs(opts.factors) do
            local ok, v = pcall(f.value)
            parts[#parts + 1] = ("%s: %.2fx"):format(f.label, (ok and v) or 0)
        end
        imgui.Text(table.concat(parts, "    "))
    end

    for _, line in ipairs(opts.notes or {}) do
        imgui.TextDisabled(line)
    end

    if opts.extras then
        local ok, err = pcall(opts.extras)
        if not ok then imgui.TextDisabled("extras failed: " .. tostring(err)) end
    end
end

return M
