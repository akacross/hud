--[[
    hud.files - the configuration file picker and its confirmation prompts.

    WHAT THIS WAS
    -------------
    A combo jammed into a 376x36 footer strip next to two checkboxes, plus a
    SECOND top-level ImGui window - its own OnFrame subscription, its own
    centring, its own title - that existed only to ask "are you sure?".

    A whole extra window for a yes/no is what the mods split out of autobind
    stopped doing: driving, wanted and vstorage put a modal popup inside the
    window that raised it, so the prompt cannot end up behind its parent, does
    not need a second cursor consumer, and disappears with the window rather
    than surviving it (which the old one did - `if not menu.settings[0] ...
    resetConfirmData()` was there to clean up after exactly that).

    So: a real tab for the file list, and imgui.OpenPopup/BeginPopupModal for
    the six prompts.

    THE SIX PROMPTS were six copies of the same shape: a line of text, an
    optional subject, an optional field, a Confirm and a Cancel. One renderer
    over a spec now - which is also what makes it obvious that four of them
    have to mark the config list dirty, since four of them change what is in
    the folder.

    `body` draws whatever sits between the subject and the buttons; `confirm`
    is what the Confirm button does. Cancel always just clears the prompt,
    which is why no spec carries one.
]]

local M = { _VERSION = '0.1.0' }

local imgui  = require('mimgui')
local scaleM = require('akacross.scale')
local style  = require('akacross.style')
local W      = require('hud.widgets')
local encoding = require('encoding')

local u8 = encoding.UTF8
local sf = W.sf
local checkbox, tooltip = W.checkbox, W.tooltip
local textBuf, clearTextBuf, textValue = W.textBuf, W.clearTextBuf, W.textValue
local TEXT_LEN = W.TEXT_LEN

local ctx = {}

function M.setup(c)
    ctx = c
    return M
end

-- ---------------------------------------------------------------------------
-- Prompt state
-- ---------------------------------------------------------------------------
--[[
    One table per prompt, exactly as the entry used to hold in `confirmData`.
    It lives here now because nothing outside this module reads it any more -
    the second window that did is gone.
]]
local prompts = {
    open   = {name = ''},
    rename = {name = ''},
    add    = {name = 'new.json', useCurrent = false},
    copy   = {selectedFile = nil},
    delete = {},
    update = {},
}

local ORDER = {'add', 'open', 'copy', 'rename', 'delete', 'update'}

-- Which prompt the modal should show. nil means no modal.
local active = nil
-- Raised for one frame so the draw pass can call OpenPopup, which may only be
-- called inside a frame and inside the window the popup belongs to.
local openRequested = false

--- Raise a prompt. Called from this module's own rows and, for `update`, from
--- the entry's update check.
function M.prompt(key, fields)
    local t = prompts[key]
    if not t then return end
    if fields then
        for k, v in pairs(fields) do t[k] = v end
    end
    active = key
    openRequested = true
end

function M.isPrompting() return active ~= nil end

local function clearPrompt(key)
    local t = prompts[key]
    if not t then return end
    if t.name ~= nil then t.name = (key == 'add') and 'new.json' or '' end
    if t.useCurrent ~= nil then t.useCurrent = false end
    t.selectedFile = nil
    -- The filename box is shared by the add and rename prompts, and it is
    -- persistent: without this it would still be holding what was typed the
    -- last time either of them was open.
    clearTextBuf('confirm.filename')
end

--[[
    Every prompt back to its resting state, and the modal closed. The entry
    calls this when the settings window closes.

    `except` names one prompt to leave standing. The update prompt is raised by
    the background version check rather than by a click, so closing the window
    is not an answer to it - dropping it would lose the notice, and it would
    not come back until the next launch.
]]
function M.reset(except)
    for i = 1, #ORDER do
        if ORDER[i] ~= except then clearPrompt(ORDER[i]) end
    end
    if active ~= except then
        active, openRequested = nil, false
    else
        -- Still pending, and it has to re-arm: OpenPopup was consumed by the
        -- frame that closed, so without this the modal never reappears.
        openRequested = true
    end
end

-- ---------------------------------------------------------------------------
-- The directory scan
-- ---------------------------------------------------------------------------
--[[
    This runs in the BEFORE-FRAME hook, which mimgui calls on every frame the
    window is open. The scan is an lfs.dir over the configs folder plus a
    linear filesExist() per entry, so it was a full directory enumeration sixty
    times a second for a list that only changes when a file is added, renamed,
    copied or deleted.

    Those four places mark it dirty. The one-second floor is what still catches
    a file dropped into the folder from outside the game, which is the only
    reason to keep polling at all.
]]
local SCAN_INTERVAL = 1.0
local scanStamp = -math.huge
local dirty = true

function M.markDirty() dirty = true end

function M.scanIfDue()
    local now = os.clock()
    if not dirty and (now - scanStamp) < SCAN_INTERVAL then return end
    dirty = false
    scanStamp = now
    ctx.scanConfigs()
end

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------
-- Only one prompt is ever on screen, so one slot is enough to keep the
-- 'File: "..."' line from being concatenated afresh every frame.
local subjectCache = {value = false, text = ''}
local function subjectLine(value)
    if subjectCache.value ~= value then
        subjectCache.value = value
        subjectCache.text = 'File: "' .. tostring(value) .. '"'
    end
    return subjectCache.text
end

local function filenameField(t)
    imgui.PushItemWidth(sf(160))
    local buf = textBuf('confirm.filename')
    if imgui.InputText('Filename', buf, TEXT_LEN) then
        t.name = textValue(buf) .. '.json'
    end
    imgui.PopItemWidth()
    tooltip('Do not add ".json" to the end.')
end

local SPECS = {
    add = {
        title = 'New configuration',
        heading = 'Create a new configuration file.',
        body = function(t)
            filenameField(t)
            checkbox('Copy current settings?', t, 'useCurrent')
            tooltip('Off starts the new file from the shipped defaults.')
        end,
        confirm = function(t)
            ctx.saveHudAs(t.name, t.useCurrent)
            M.markDirty()
        end,
    },
    open = {
        title = 'Open configuration',
        heading = 'Do you want to open this file?',
        subject = function(t) return t.name end,
        confirm = function(t) ctx.openConfig(t.name) end,
    },
    copy = {
        title = 'Copy configuration',
        heading = 'Copy the current configuration over another file.',
        subject = function() return ctx.settings.JsonFile end,
        body = function(t)
            if imgui.BeginCombo('##hudCopyTarget', t.selectedFile or 'Select a file') then
                local list = ctx.configsDir
                for i = 1, #list do
                    local entry = list[i]
                    if entry.File ~= ctx.settings.JsonFile then
                        if imgui.Selectable(u8(entry.File), false) then
                            t.selectedFile = entry.File
                        end
                    end
                end
                imgui.EndCombo()
            end
        end,
        confirm = function(t)
            if not t.selectedFile then return end
            ctx.saveHudAs(t.selectedFile, true)
            M.markDirty()
        end,
    },
    rename = {
        title = 'Rename configuration',
        heading = 'Do you want to rename this file?',
        subject = function() return ctx.settings.JsonFile end,
        body = filenameField,
        confirm = function(t)
            if t.name == '' or t.name == '.json' then return end
            ctx.renameConfig(t.name)
            M.markDirty()
        end,
    },
    delete = {
        title = 'Delete configuration',
        heading = 'Do you want to delete this file?',
        subject = function() return ctx.settings.JsonFile end,
        confirm = function()
            ctx.deleteConfig()
            M.markDirty()
        end,
    },
    update = {
        title = 'Update',
        heading = 'Do you want to update this script?',
        confirmLabel = 'Update',
        confirm = function() ctx.updateScript() end,
    },
}

--[[
    The modal.

    MUST be called from inside the settings window's Begin/End pair: OpenPopup
    and BeginPopupModal are scoped to the current window, and a popup opened
    outside the window it belongs to never appears.
]]
function M.renderModal()
    if not active then return end
    local spec = SPECS[active]
    if not spec then active = nil return end

    if openRequested then
        openRequested = false
        imgui.OpenPopup(spec.title)
    end

    -- AlwaysAutoResize: the prompts differ in height by a field or two and a
    -- fixed size would leave the shortest one mostly empty.
    if imgui.BeginPopupModal(spec.title, nil,
            imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoSavedSettings) then
        local t = prompts[active]

        imgui.Text(spec.heading)
        if spec.subject then
            imgui.TextDisabled(subjectLine(spec.subject(t)))
        end
        if spec.body then
            imgui.Spacing()
            spec.body(t)
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if imgui.Button(spec.confirmLabel or 'Confirm', imgui.ImVec2(sf(110), 0)) then
            -- The prompt is cleared BEFORE the action runs for `open` and
            -- `delete`, both of which reload the config - and a reload can
            -- replace what the prompt is pointing at.
            local key = active
            spec.confirm(t)
            clearPrompt(key)
            active = nil
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button('Cancel', imgui.ImVec2(sf(110), 0)) then
            clearPrompt(active)
            active = nil
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    else
        -- Dismissed by clicking away or pressing Escape. Without this the
        -- prompt stays `active` and re-opens on the next frame.
        if not openRequested then
            clearPrompt(active)
            active = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------
local ACTIONS = {
    {label = 'New',    key = 'add',    tip = 'Create another configuration file.'},
    {label = 'Copy',   key = 'copy',   tip = 'Write these settings over another file.'},
    {label = 'Rename', key = 'rename', tip = 'Rename the file being edited.'},
    {label = 'Delete', key = 'delete', tip = 'Delete the file being edited.'},
}

function M.renderFiles()
    local settings = ctx.settings

    style.section('Configuration file')
    imgui.Text('Editing:')
    imgui.SameLine()
    imgui.TextDisabled(tostring(settings.JsonFile))
    imgui.Spacing()

    for i = 1, #ACTIONS do
        if i > 1 then imgui.SameLine() end
        local action = ACTIONS[i]
        if imgui.Button(action.label, imgui.ImVec2(sf(84), 0)) then
            M.prompt(action.key)
        end
        tooltip(action.tip)
    end

    style.section('Available files')

    local list = ctx.configsDir
    if #list == 0 then
        imgui.TextDisabled('No configuration files found.')
    end
    for i = 1, #list do
        local entry = list[i]
        if ctx.matchConfigFiles(entry.File) then
            local isCurrent = entry.File == settings.JsonFile
            if imgui.Selectable(u8(entry.File) .. '##hudcfg' .. i, isCurrent) and not isCurrent then
                M.prompt('open', {name = entry.File})
            end
        end
    end

    style.section('Startup')
    checkbox('Auto-save on exit', settings, 'autosave')
    tooltip('Writes the configuration when the game closes.')
    imgui.SameLine()
    checkbox('Check for updates', settings, 'checkForUpdates')
    tooltip('Checks for a new version when the game starts.')

    imgui.Spacing()
    if imgui.Button('Check for update now', imgui.ImVec2(sf(180), 0)) then
        ctx.checkForUpdate()
    end
    imgui.SameLine()
    checkbox('Beta channel', settings, 'beta')
    tooltip('Take updates from the beta branch instead of the release branch.')
end

return M
