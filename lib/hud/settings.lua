--[[
    hud.settings - the HUD settings window, tab by tab.

    WHAT CHANGED, AND WHY
    ---------------------
    The panel this replaces was a 460x76 strip of TEN hand-placed buttons over
    a fixed 376x289 child, with a 85x392 column of five square icon buttons
    down the left and a 376x36 footer - every one of those a literal pixel
    offset passed to SetCursorPos. It worked, and it was the only thing in the
    akacross set that still looked like that: driving, wanted, vstorage and
    fastmap all draw a horizontal tab bar over a measured body with a footer,
    themed by akacross.style.

    So this is that shape, and the ten tabs collapse to seven:

        Elements   the seven bars/icons/stars AND the eleven text rows, behind
                   one list. Eight tabs became one, which is most of why the
                   strip could go.
        Anchors    was "Move"
        Server     the server's own textdraws, was half of "Screen"
        Renderer   the drawing backend, was the other half
        Files      the configuration picker, promoted out of the footer combo
        Keybinds   new - the menu had no keybind at all, only /hud
        Interface  new - the shared UI-scale tab every other mod carries

    The five side buttons are gone as buttons: Power is a state the header card
    reports and toggles, Save / Reload / Reset are the footer every other mod
    has, and Update lives on the Files tab next to the thing it updates.

    THE HEADER CARD is autofps's, and it earns its place for the same reason it
    does there: this window configures something that is drawing right now, and
    the two facts that decide whether anything appears on screen at all - is
    the HUD on, and which renderer is drawing - were previously a green button
    with no caption and a checkbox three tabs away.

    NO GLOBALS. The entry owns `hud`, `settings` and every callback below and
    hands them over in setup(); this module reads nothing out of _G. That is
    the rule the autobind de-globalization pass settled on for new modules, and
    it is also simply forced here - the entry holds both tables as locals.
]]

local M = { _VERSION = '0.1.0' }

local imgui   = require('mimgui')
local scaleM  = require('akacross.scale')
local style   = require('akacross.style')
local ifaceM  = require('akacross.interface')
local W       = require('hud.widgets')

local sf, idFor, idFor2, intLabel = W.sf, W.idFor, W.idFor2, W.intLabel
local checkbox, drag1, drag2, drag4 = W.checkbox, W.drag1, W.drag2, W.drag4
local colorEdit, colorRow, tooltip, help = W.colorEdit, W.colorRow, W.tooltip, W.help
local textBuf, releaseTextBuf, textValue = W.textBuf, W.releaseTextBuf, W.textValue
local TEXT_LEN = W.TEXT_LEN

-- ---------------------------------------------------------------------------
-- Context
-- ---------------------------------------------------------------------------
--[[
    Everything the entry owns. Captured once: `hud` and `settings` are mutated
    in place by the config layer (applyDefaults overwrites fields, it does not
    replace the table), so holding the reference is safe across a reload and a
    reset alike. Anything that CAN be replaced is taken as a function instead.
]]
local ctx = {}

function M.setup(c)
    ctx = c
    return M
end

local function icon(name)
    return ctx.icon and ctx.icon(name) or ''
end

-- ---------------------------------------------------------------------------
-- Labels
-- ---------------------------------------------------------------------------
-- ImGui reads min >= max as "unbounded", which is what v1's
-- `12 * 2000.0, 12 * 2000.0` meant; offsets get a real range.
local OFF_MIN, OFF_MAX = -40000, 40000
local FREE_MIN, FREE_MAX = -24000, 24000

local ALIGN_CHOICES = {'left', 'center', 'right'}
local ALIGN_LABELS = {left = 'Left', center = 'Center', right = 'Right'}
local ALIGN_ITEMS = {'Left##1', 'Center##2', 'Right##3'}
local FLAG_FIELDS = {'bold', 'italics', 'border', 'shadow'}
local FLAG_LABELS = {'Bold', 'Italics', 'Border', 'Shadow'}

local L = {
    leftRight = 'Left/Right', upDown = 'Up/Down',
    width = 'Width', height = 'Height',
    border = 'Border', spacing = 'Spacing',
    maxValue = 'Max',
}

local TIP = {
    anchor = 'Which anchor this part hangs off. Move the anchor on the Anchors\n' ..
             'tab and everything attached to it moves together.',
    offsets = 'Offset from the anchor, in screen pixels. Drag, or hold CTRL and\n' ..
              'click to type an exact value.',
    size = 'Width and height of the box, in screen pixels.',
    font = 'A font family installed on your system. Names that are not installed\n' ..
           'are substituted, and /hud render reports what each one resolved to.',
    flags = 'Bold and italics use the real font files. Border and shadow are\n' ..
            'drawn by the script.',
    fontSize = 'Point size, as the game measures it - not pixels. Both renderers\n' ..
               'translate it the same way.',
    max = 'The value the bar reads as full.',
    rounding = 'Rounds the corners of every bar. Only the ImGui renderer can do\n' ..
               'this; the game renderer draws square corners and ignores it.',
    imguiRenderer = 'Draws the bars, icons, stars and text through ImGui instead of the\n' ..
                    'game renderer: smoothed edges and proper transparency.',
    originalHud = "Show the game's own HUD underneath this one. Off is the point of\n" ..
                  'the mod; on is useful while positioning.',
}

-- ---------------------------------------------------------------------------
-- Header card
-- ---------------------------------------------------------------------------
--[[
    autofps's header card, and the reason it is worth carrying across: this
    window configures something that is drawing on screen right now, and the
    two facts that decide whether ANY of it appears - the master toggle and
    which renderer is live - used to be an unlabelled green square and a
    checkbox on another tab.

    Painted onto the window draw list rather than with PushStyleColor, so there
    is nothing on ImGui's style stack to unwind if the body below errors.
]]
local headCache = {onFor = nil, on = '', fileFor = nil, file = '', rendFor = nil, rend = ''}

--[[
    The three strings the card shows, each rebuilt only when the value behind
    it changes. akacross.style.card calls these once per frame, so formatting
    inside them would allocate sixty times a second for text that changes when
    the user clicks something.
]]
local function toggleText()
    local hud = ctx.hud
    if headCache.onFor ~= hud.toggle then
        headCache.onFor = hud.toggle
        headCache.on = ('%s  HUD %s'):format(
            icon(hud.toggle and 'CIRCLE_CHECK' or 'CIRCLE_XMARK'),
            hud.toggle and 'ON' or 'OFF')
    end
    return headCache.on
end

local function fileText()
    local settings = ctx.settings
    if headCache.fileFor ~= settings.JsonFile then
        headCache.fileFor = settings.JsonFile
        headCache.file = tostring(settings.JsonFile)
    end
    return headCache.file
end

local function rendererText()
    local live = ctx.activeRenderer and ctx.activeRenderer() or 'native'
    if headCache.rendFor ~= live then
        headCache.rendFor = live
        headCache.rend = (live == 'imgui') and 'ImGui renderer' or 'Game renderer'
    end
    return headCache.rend
end

--[[
    The line under the toggle. Order matters: the most disabling reason wins,
    so the user is told the one thing actually stopping the HUD appearing
    rather than the first fact that happens to be false.
]]
--[[
    Keyed on BOTH the count and the renderer, and the whole line is built at
    once.

    The first version cached the count clause and prepended the renderer name
    live - `rendererText() .. '  ' .. cached` - which reads as free because
    both halves are already cached, and is not: the concatenation itself
    allocates a string on every frame the window is open. The host suite holds
    this card to 0.05 KB/frame and that one operator was all of it.
]]
local statusCache = {countKey = nil, rendKey = nil, text = ''}

local function statusLine()
    local hud = ctx.hud
    local count = ctx.enabledCount and ctx.enabledCount() or 0
    local countKey = hud.toggle and count or -1
    local rendKey = rendererText()

    if statusCache.countKey ~= countKey or statusCache.rendKey ~= rendKey then
        statusCache.countKey, statusCache.rendKey = countKey, rendKey
        if not hud.toggle then
            statusCache.text = 'Switched off - nothing is being drawn'
        elseif count == 0 then
            statusCache.text = 'Every element is switched off'
        else
            statusCache.text = ('%s  %d element(s) drawing'):format(rendKey, count)
        end
    end
    return statusCache.text
end

local CARD = {
    title   = toggleText,
    right   = fileText,
    status  = statusLine,
    tooltip = 'Click to switch the whole HUD on or off.',
    onClick = function() ctx.hud.toggle = not ctx.hud.toggle end,
}

function M.renderHeader()
    style.card(CARD)
end

-- ---------------------------------------------------------------------------
-- Shared rows
-- ---------------------------------------------------------------------------
--[[
    THE EXTRA TOGGLES an element carries beyond its parts being on or off.

    `altLabel` is for the ones whose caption IS the state - "12 Hour" against
    "24 Hour". The label doubles as the imgui id, so it changing with the value
    is deliberate and is how v1 behaved.
]]
local ELEMENT_EXTRAS = {
    health    = {{field = 'extended', label = '160 HP',
                  onChange = function(cfg) cfg.max = cfg.extended and 160 or 100 end}},
    armor     = {{field = 'stayOn', label = 'Stay On'}},
    sprint    = {{field = 'stayOn', label = 'Stay On'}},
    vehicle   = {{field = 'stayOn', label = 'Stay On'},
                 {field = 'bigVehicles', label = '2500 HP Vehicles'}},
    breath    = {{field = 'stayOn', label = 'Stay On'}},
    weapon    = {{field = 'frame', label = 'Frame'}, {field = 'splitAmmo', label = 'Split Ammo'}},
    money     = {{field = 'dollar', label = '($)'}, {field = 'comma', label = 'Comma'}},
    localTime = {{field = 'twelveHour', label = '12 Hour', altLabel = '24 Hour'}},
    ping      = {{field = 'showLabel', label = '(Ping:)'}},
    fps       = {{field = 'showLabel', label = '(FPS:)'}},
    direction = {{field = 'useCamera', label = 'Camera', altLabel = 'Heading'}},
    speed     = {{field = 'mph', label = 'MPH', altLabel = 'KMH'}},
}

-- Which colour fields each box part has, and what to call them. A field the
-- part does not carry is simply skipped, which is how the vehicle bar is the
-- only one showing its two damage colours.
local BOX_COLORS = {
    bar   = {{'color', 'Color'}, {'outline', 'Border'}, {'fade', 'Fade'},
             {'damageMid', '400-700'}, {'damageLow', '0-400'}},
    icon  = {{'color', 'Color'}, {'frameColor', 'Frame'}},
    stars = {{'color', 'Color'}},
}

--- The anchor this part hangs off. The Selectable label carries the anchor's
--- NAME, which the user can edit, so it is the one string here that cannot be
--- interned - and it is only built while the combo is open.
local function anchorCombo(id, part)
    local anchors = ctx.hud.anchors
    local current = anchors[part.anchor] or anchors[1]
    imgui.PushItemWidth(sf(95))
    if imgui.BeginCombo(id, current and current.name or '?') then
        for i = 1, #anchors do
            if imgui.Selectable(anchors[i].name .. idFor('##', i), part.anchor == i) then
                part.anchor = i
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()
end

local function positionHeadings(withSize)
    imgui.TextDisabled(L.leftRight)
    imgui.SameLine(sf(90))
    imgui.TextDisabled(L.upDown)
    if withSize then
        imgui.SameLine(sf(180))
        imgui.TextDisabled(L.width)
        imgui.SameLine(sf(260))
        imgui.TextDisabled(L.height)
    end
end

--[[
    A BOX PART: the bar, the weapon icon, the row of stars.

    One row of offsets and sizes, its anchor, and whatever colours it carries.
]]
local function boxPartRow(key, cfg, partName, label)
    local part = cfg[partName]
    style.section(label)

    positionHeadings(true)
    imgui.PushItemWidth(sf(330))
    local x, y, w, h = drag4(idFor2('##box_', key, partName), 0.1, OFF_MIN, OFF_MAX,
        part.offx, part.offy, part.sizex, part.sizey)
    if x then
        part.offx, part.offy, part.sizex, part.sizey = x, y, w, h
    end
    imgui.PopItemWidth()
    help(TIP.offsets .. '\n\n' .. TIP.size)

    imgui.PushItemWidth(sf(70))
    if imgui.BeginCombo(idFor2('##boxcolors_', key, partName), 'Colors') then
        local fields = BOX_COLORS[partName] or {}
        for i = 1, #fields do
            local field, caption = fields[i][1], fields[i][2]
            if part[field] ~= nil then
                local value = colorRow(idFor2('##boxcolor_', key .. partName, field),
                    part[field], caption, true)
                if value then part[field] = value end
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    if part.border ~= nil then
        imgui.SameLine()
        imgui.PushItemWidth(sf(40))
        local border = drag1(L.border, 0.1, 0, 20, part.border)
        if border then part.border = border end
        imgui.PopItemWidth()
    end
    if part.spacing ~= nil then
        imgui.SameLine()
        imgui.PushItemWidth(sf(50))
        local spacing = drag1(L.spacing, 0.1, -100, 100, part.spacing)
        if spacing then part.spacing = spacing end
        imgui.PopItemWidth()
    end

    imgui.SameLine()
    anchorCombo(idFor2('##boxanchor_', key, partName), part)
    tooltip(TIP.anchor)
end

--[[
    A TEXT PART: alignment, flags, face, anchor, offsets, size and colour.

    v1's equivalent took TEN positional indices, because the config kept the
    same part's fields spread across four arrays in two different index spaces.
    There is one table now, so there is one argument.
]]
local function textPartRow(key, cfg, partName, label)
    local part = cfg[partName]
    local widgetId = key .. partName
    if label then style.section(label) end

    imgui.PushItemWidth(sf(68))
    if imgui.BeginCombo(idFor('##align_', widgetId), ALIGN_LABELS[part.align] or part.align) then
        for i = 1, #ALIGN_CHOICES do
            if imgui.Selectable(ALIGN_ITEMS[i], part.align == ALIGN_CHOICES[i]) then
                part.align = ALIGN_CHOICES[i]
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    imgui.PushItemWidth(sf(60))
    if imgui.BeginCombo(idFor('##flags_', widgetId), 'Flags') then
        for i = 1, #FLAG_FIELDS do
            if checkbox(FLAG_LABELS[i], part.flags, FLAG_FIELDS[i]) then
                ctx.createFont(key, partName)
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()
    tooltip(TIP.flags)

    imgui.SameLine()
    imgui.PushItemWidth(sf(95))
    local faceId = idFor('##face_', widgetId)
    local buf = textBuf(faceId, part.font)
    if imgui.InputText(faceId, buf, TEXT_LEN, imgui.InputTextFlags.EnterReturnsTrue) then
        part.font = textValue(buf)
        ctx.createFont(key, partName)
    end
    releaseTextBuf(faceId)
    imgui.PopItemWidth()
    tooltip(TIP.font)

    imgui.SameLine()
    anchorCombo(idFor('##textanchor_', widgetId), part)
    tooltip(TIP.anchor)

    imgui.PushItemWidth(sf(170))
    local x, y = drag2(idFor('##textpos_', widgetId), 0.1, OFF_MIN, OFF_MAX, part.offx, part.offy)
    if x then part.offx, part.offy = x, y end
    imgui.PopItemWidth()
    tooltip(TIP.offsets)

    imgui.SameLine()
    imgui.BeginGroup()
    if imgui.Button(idFor('+##', widgetId)) and part.size < 72 then
        part.size = part.size + 1
        ctx.createFont(key, partName)
    end
    imgui.SameLine()
    imgui.Text(intLabel(part.size))
    imgui.SameLine()
    if imgui.Button(idFor('-##', widgetId)) and part.size > 4 then
        part.size = part.size - 1
        ctx.createFont(key, partName)
    end
    imgui.EndGroup()
    tooltip(TIP.fontSize)

    imgui.SameLine()
    imgui.PushItemWidth(sf(95))
    local color = colorRow(idFor('##textcolor_', widgetId), part.color, 'Color', true)
    if color then part.color = color end
    imgui.PopItemWidth()
end

--- The toggles across the top of an element: one per part, then its extras.
local function elementToggles(key, cfg, parts)
    for p = 1, #parts do
        if p > 1 then imgui.SameLine() end
        -- The part labels are unique within an element (Bar/Text, Icon/Ammo/
        -- Name, Stars/Cash) and only one element draws at a time, so the label
        -- is its own imgui id.
        checkbox(parts[p].label, cfg[parts[p].name], 'enabled')
    end
    local extras = ELEMENT_EXTRAS[key]
    if not extras then return end
    for i = 1, #extras do
        local extra = extras[i]
        imgui.SameLine()
        local label = extra.altLabel and (cfg[extra.field] and extra.label or extra.altLabel)
                      or extra.label
        if checkbox(label, cfg, extra.field) and extra.onChange then
            extra.onChange(cfg)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Tab: Elements
-- ---------------------------------------------------------------------------
--[[
    ONE PANE FOR EVERY ELEMENT.

    v1 had a seven-way branch for the bars, a loop for the misc rows and a
    hand-written block for the weapon and the stars, because the config shape
    differed per element. Every element is a list of parts now, so this is the
    same code whichever one is selected - and that is what let the seven bar
    tabs plus the Other tab become a single list.

    The list is on the left because eighteen entries is more than a tab bar can
    carry legibly, and because the two groups (things with a shape, and lines
    of text) read as groups in a list and did not as a 2x5 button grid.
]]
local selected = 'health'

local LIST_W = 150

local function renderElementBody(key)
    local spec = ctx.Spec.byKey[key]
    local cfg = ctx.hud.elements[key]
    if not (spec and cfg) then
        imgui.TextDisabled('This element is not in the loaded configuration.')
        return
    end
    local parts = ctx.Spec.parts[spec.kind]

    elementToggles(key, cfg, parts)

    if cfg.max then
        imgui.PushItemWidth(sf(70))
        local max = drag1(L.maxValue, 1, 1, 100000, cfg.max)
        if max then cfg.max = max end
        imgui.PopItemWidth()
        tooltip(TIP.max)
    end

    for p = 1, #parts do
        local part = parts[p]
        if part.text then
            textPartRow(key, cfg, part.name, part.label)
        else
            boxPartRow(key, cfg, part.name, part.label)
        end
    end
end

-- Reused every frame: two ImVec2 allocations per frame for a pane whose size
-- only changes with the window is exactly what the widget layer exists to
-- avoid.
local listSize = imgui.ImVec2(0, 0)
local paneSize = imgui.ImVec2(0, 0)

--[[
    `body` is the height the tab bar measured, handed down rather than taken as
    "whatever is left": this tab draws its own two children, so it is given the
    height directly instead of being wrapped in one. Nesting it would put a
    scrollbar inside a scrollbar and let the left-hand list scroll away from
    the pane it selects.
]]
--[[
    The list captions, interned once.

    Built lazily rather than in setup() because icon() cannot answer until the
    glyph font has been merged into the atlas, which happens in the entry's
    OnInitialize - after setup() and before the first draw.

    Not a micro-optimisation: eighteen rows, each concatenating a glyph, a
    label and a '##' id, is thirty-six string allocations on every frame the
    tab is open. The host suite holds this panel to 0.05 KB/frame and that
    alone put it over.
]]
local listLabels = nil

local function buildListLabels()
    if listLabels then return listLabels end
    local Spec = ctx.Spec
    listLabels = {}
    for _, key in ipairs(Spec.tabs) do
        local spec = Spec.byKey[key]
        local glyph = spec.icon and (icon(spec.icon) .. ' ') or '   '
        listLabels[key] = glyph .. spec.label .. '##sel_' .. key
    end
    for _, key in ipairs(Spec.misc) do
        listLabels[key] = '   ' .. Spec.byKey[key].label .. '##sel_' .. key
    end
    return listLabels
end

function M.renderElements(body)
    local Spec = ctx.Spec
    local labels = buildListLabels()
    local h = body and body.y or 0

    listSize.x, listSize.y = sf(LIST_W), h
    paneSize.x, paneSize.y = 0, h

    imgui.BeginChild('##hudElemList', listSize, true)
        imgui.TextDisabled('SHAPES')
        imgui.Separator()
        for i = 1, #Spec.tabs do
            local key = Spec.tabs[i]
            if imgui.Selectable(labels[key], selected == key) then
                selected = key
            end
        end

        imgui.Spacing()
        imgui.TextDisabled('TEXT')
        imgui.Separator()
        for i = 1, #Spec.misc do
            local key = Spec.misc[i]
            if imgui.Selectable(labels[key], selected == key) then
                selected = key
            end
        end
    imgui.EndChild()

    imgui.SameLine()

    imgui.BeginChild('##hudElemBody', paneSize, false)
        renderElementBody(selected)
    imgui.EndChild()
end

-- ---------------------------------------------------------------------------
-- Tab: Anchors
-- ---------------------------------------------------------------------------
function M.renderAnchors()
    local hud = ctx.hud
    local anchors = hud.anchors

    style.section('Anchors')
    imgui.TextDisabled('Every part hangs off an anchor. Move the anchor and everything')
    imgui.TextDisabled('attached to it moves with it.')
    imgui.Spacing()

    -- Three unlabelled boxes in a row is a guess about which one is X; the
    -- headings cost one line and remove it.
    imgui.TextDisabled('Name')
    imgui.SameLine(sf(140))
    imgui.TextDisabled('Left/Right')
    imgui.SameLine(sf(225))
    imgui.TextDisabled('Up/Down')

    for k = 1, #anchors do
        local anchor = anchors[k]

        imgui.PushItemWidth(sf(120))
        local nameId = idFor('##anchorname', k)
        local buf = textBuf(nameId, anchor.name)
        if imgui.InputText(nameId, buf, TEXT_LEN, imgui.InputTextFlags.EnterReturnsTrue) then
            anchor.name = textValue(buf)
        end
        releaseTextBuf(nameId)
        imgui.PopItemWidth()

        imgui.SameLine()
        imgui.PushItemWidth(sf(75))
        local x = drag1(idFor('##anchorx', k), 0.1, FREE_MIN, FREE_MAX, anchor.x)
        if x then anchor.x = x end
        imgui.PopItemWidth()

        imgui.SameLine()
        imgui.PushItemWidth(sf(75))
        local y = drag1(idFor('##anchory', k), 0.1, FREE_MIN, FREE_MAX, anchor.y)
        if y then anchor.y = y end
        imgui.PopItemWidth()

        imgui.SameLine()
        local moving = ctx.isAnchorMoving(anchor)
        if imgui.Button(idFor(moving and 'Undo##' or 'Move##', k)) then
            ctx.toggleAnchorMove(anchor)
        end
        tooltip(moving and 'Cancel the move.'
                       or 'Then click anywhere on screen to place this anchor.')

        imgui.SameLine()
        if k == 1 then
            -- The first anchor is the fallback for any part whose own anchor
            -- has gone, so it is the one that cannot be removed.
            if imgui.Button('+') then
                anchors[#anchors + 1] = {name = 'new', x = 500, y = 500}
            end
            tooltip('Add an anchor.')
        elseif imgui.Button(idFor('x##', k)) then
            table.remove(anchors, k)
            -- Anything pointing past the end falls back to the first anchor.
            for _, cfg in pairs(hud.elements) do
                for _, part in pairs(cfg) do
                    if type(part) == 'table' and part.anchor then
                        if part.anchor == k then part.anchor = 1
                        elseif part.anchor > k then part.anchor = part.anchor - 1 end
                    end
                end
            end
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Tab: Renderer
-- ---------------------------------------------------------------------------
function M.renderRenderer()
    local hud, settings, drawM = ctx.hud, ctx.settings, ctx.drawM

    style.section('Drawing backend')

    --[[
        Offered only when there is a second one to offer: the ImDrawList
        backend is an optional dependency, and a checkbox that silently does
        nothing is worse than a line saying why.
    ]]
    if drawM.available('imgui') then
        -- `pendingRenderer or settings.renderer`: the switch happens on the
        -- next present, and a checkbox that snapped back for one frame in
        -- between would read as the click not having taken.
        local live = ctx.pendingRenderer() or settings.renderer
        W.scratchBool[0] = live == 'imgui'
        if imgui.Checkbox('ImGui renderer', W.scratchBool) then
            ctx.setPendingRenderer(W.scratchBool[0] and 'imgui' or 'native')
        end
        help(TIP.imguiRenderer)

        -- Asked, not assumed: the native renderer cannot round a corner, so
        -- while it is drawing this control must not exist to be set.
        if drawM.can('rounding') then
            style.labelled('Corner rounding')
            local r = drag1('##rounding', 0.1, 0, 12, hud.rounding or 0)
            if r then hud.rounding = r end
            style.endLabelled()
            help(TIP.rounding)
        end
    else
        imgui.TextDisabled('ImGui renderer unavailable (akacross.draw_imgui did not load)')
    end

    style.section("The game's own HUD")
    if checkbox('Original HUD', hud, 'defaultHud') then
        ctx.displayHud(hud.defaultHud)
    end
    help(TIP.originalHud)
end

-- ---------------------------------------------------------------------------
-- Tab: Server
-- ---------------------------------------------------------------------------
--[[
    Five hand-copied blocks in v1 that differed only in which fields they
    carry: a toggle, sometimes a second toggle, sometimes a text field, zero to
    three colours, and sometimes a position pair. Every one of them pushes the
    same textdraw id back to the server-side draws when anything changes.

    The v2 config named those fields, so the spec names them too.
]]
local SERVER_ROWS = {
    {key = 'turf',       draw = 0, label = 'Turf',       pos = true},
    {key = 'turfOwner',  draw = 1, label = 'Turf Owner', pos = true, colors = {'color'}},
    {key = 'wristwatch', draw = 2, label = 'Wristwatch', pos = true, colors = {'color'}},
    {key = 'logo',       draw = 3, label = 'Logo',       pos = true,
     extra = {field = 'custom', label = 'Custom Logo'},
     textField = 'text', colors = {'color'}, colorsOnNewLine = true},
    {key = 'hpBar',      draw = 4, label = 'HP Bar', colors = {'color1', 'color2', 'color3'}},
    {key = 'hpText',     draw = 5, label = 'HP Text'},
    {key = 'armorText',  draw = 6, label = 'Armor Text'},
}

-- Column stops, so the toggles, the colours and the positions line up down the
-- panel instead of each row starting wherever the one before it ended. The
-- rows carry different numbers of controls, which is exactly why they cannot
-- be laid out by SameLine() alone.
local SRV_COL_EXTRA = 150
local SRV_COL_FIELD = 280
local SRV_COL_POS   = 400

--- Which server's rows the tab is editing. Follows the detected server, and
--- the picker below overrides it for the rest of the session - so a layout can
--- be set up for a server you are not currently on.
local editingServer = nil

--- Pushing a row writes it to the LIVE server's draws, so it only means
--- anything while the tab is editing the server we are actually on. Editing
--- the other one's layout still saves; it just has nothing to write to yet.
local function noPush() end

local function renderServerRow(row)
    local cfg = ctx.hud[editingServer]
    cfg = cfg and cfg[row.key]
    if not cfg then return end
    local draw = row.draw
    local live = ctx.activeServer and ctx.activeServer() == editingServer
    local push = live and ctx.srvTextDraws or noPush

    if checkbox(row.label, cfg, 'enabled') then push(draw) end

    if row.extra then
        imgui.SameLine(sf(SRV_COL_EXTRA))
        if checkbox(row.extra.label, cfg, row.extra.field) then push(draw) end
    end

    if row.textField then
        imgui.SameLine(sf(SRV_COL_FIELD))
        imgui.PushItemWidth(sf(95))
        local id = idFor('##srvtext_', row.key)
        local buf = textBuf(id, cfg[row.textField])
        if imgui.InputText(id, buf, TEXT_LEN, imgui.InputTextFlags.EnterReturnsTrue) then
            cfg[row.textField] = textValue(buf)
            push(draw)
        end
        releaseTextBuf(id)
        imgui.PopItemWidth()
    end

    if row.colors then
        for i = 1, #row.colors do
            -- The logo's colour starts a line of its own; every other row keeps
            -- its colours next to the toggle.
            if row.colorsOnNewLine then
                if i > 1 then imgui.SameLine() end
            else
                imgui.SameLine(i == 1 and sf(SRV_COL_EXTRA) or nil)
            end
            local field = row.colors[i]
            local value = colorEdit(idFor2('##srvcolor_', row.key, field), cfg[field], false)
            if value then
                cfg[field] = value
                push(draw)
            end
        end
    end

    if row.pos then
        imgui.PushItemWidth(sf(68))
        -- colorsOnNewLine rows have already broken the line, so their position
        -- pair starts a row of its own rather than being pushed out to the
        -- column the single-line rows use.
        imgui.SameLine(row.colorsOnNewLine and nil or sf(SRV_COL_POS))
        local x = drag1(idFor('##srvx_', row.key), 1, FREE_MIN, FREE_MAX, cfg.x)
        if x then cfg.x = x; push(draw) end
        imgui.SameLine()
        local y = drag1(idFor('##srvy_', row.key), 1, FREE_MIN, FREE_MAX, cfg.y)
        if y then cfg.y = y; push(draw) end
        imgui.PopItemWidth()
    end
end

--[[
    The tab edits ONE server's rows at a time, and says which.

    It follows the detected server, so joining Horizon puts you on Horizon's
    layout with nothing to click. The picker is there because the two layouts
    are separate config tables and you cannot drag Paraiso's logo into place
    from Horizon - and because the server is unknown in single player, which is
    where people set this up.
]]
local SERVER_LABELS = {hrp = 'Horizon', prp = 'Paraiso'}

local function serverPicker()
    local list = ctx.servers and ctx.servers() or {}
    local active = ctx.activeServer and ctx.activeServer() or nil

    -- Follow detection until the user picks for themselves.
    if not editingServer then editingServer = active or list[1] end
    if not editingServer then return false end

    imgui.PushItemWidth(sf(150))
    if imgui.BeginCombo('##srvpick', SERVER_LABELS[editingServer] or editingServer) then
        for i = 1, #list do
            local id = list[i]
            if imgui.Selectable(SERVER_LABELS[id] or id, id == editingServer) then
                editingServer = id
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    if active == editingServer then
        imgui.TextDisabled('- connected, changes apply live')
    elseif active then
        imgui.TextDisabled(('- you are on %s; these are saved for later')
            :format(SERVER_LABELS[active] or active))
    else
        imgui.TextDisabled('- not on a known server; these are saved for later')
    end
    return true
end

function M.renderServer()
    style.section('Server textdraws')
    imgui.TextDisabled("Reposition, recolour or hide the server's own on-screen text.")
    imgui.TextDisabled('Each server is laid out separately, because each one draws these')
    imgui.TextDisabled('in a different place.')
    imgui.Spacing()

    if not serverPicker() then
        imgui.TextDisabled('No server profiles are available.')
        return
    end
    imgui.Spacing()

    imgui.TextDisabled('Draw')
    imgui.SameLine(sf(SRV_COL_EXTRA))
    imgui.TextDisabled('Colour')
    imgui.SameLine(sf(SRV_COL_POS))
    imgui.TextDisabled('Left/Right')
    imgui.SameLine(sf(SRV_COL_POS + 82))
    imgui.TextDisabled('Up/Down')

    for i = 1, #SERVER_ROWS do
        renderServerRow(SERVER_ROWS[i])
    end
end

-- ---------------------------------------------------------------------------
-- Tab: Interface
-- ---------------------------------------------------------------------------
--[[
    The shared UI-scale tab, as data - the same shape reports, driving, wanted
    and fastmap pass, so the mods' Interface tabs are literally the same tab.

    ONE scale, not two: the HUD itself is positioned in screen pixels by the
    user, so a multiplier over it would move everything they placed. Only the
    menu scales.
]]
local INTERFACE_OPTS

local function interfaceOpts()
    if not INTERFACE_OPTS then
        INTERFACE_OPTS = {
            uiScale = ctx.uiScale,
            onApply = function() ctx.onScaleChanged() end,
            scaleTooltip = 'Size of this settings window and every tooltip in it.\n' ..
                'The HUD itself is positioned in screen pixels and is not affected.',
            factors = {
                {label = 'Menu', value = scaleM.get},
            },
            notes = {
                'The HUD is placed in screen pixels, so it does not follow this slider.',
                'Use the Anchors tab to move the HUD itself.',
            },
        }
    end
    -- Re-pointed each frame: a config reset is free to hand back a different
    -- cdata object for the same field.
    INTERFACE_OPTS.uiScale = ctx.uiScale
    return INTERFACE_OPTS
end

function M.renderInterface()
    ifaceM.render(interfaceOpts())
end

--- Re-read the pending UI scale from the config. The entry calls this after a
--- reset, which rewrites the scale cdata underneath us; without it the slider
--- would keep showing the pre-reset value and offer to "Apply" it back.
function M.resync()
    ifaceM.resync(ctx.uiScale)
end

--- Reset the element list selection. A config reload can drop the element that
--- was selected, and a pane pointed at a key that no longer exists would show
--- its "not in the loaded configuration" line forever.
function M.resetSelection()
    if not (ctx.hud and ctx.hud.elements and ctx.hud.elements[selected]) then
        selected = ctx.Spec and ctx.Spec.tabs[1] or 'health'
    end
end

return M
