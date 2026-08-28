--[[
    akacross.style - the shared ImGui theme and layout helpers for the mods
    split out of autobind.

    Both extracted mods shipped with stock ImGui: default blue accents, no
    window padding, unlabelled sliders and controls jammed against the left
    edge. This is the theme and the small helpers that fix it, in one place so
    the mods look like one family rather than two strangers.

    Self-contained on purpose. autobind's ui/style.lua does the same job but
    drags in its colour tables, the font atlas and the icon set; this needs a
    palette and about forty style fields.

    Metrics go through akacross.scale so the whole panel grows with the UI
    factor. Fractions (alignment, alpha) are unitless and stay as-is.
]]

local M = { _VERSION = '0.2.0' }

local imgui = require('mimgui')
local scaleM = require('akacross.scale')

local ImVec2, ImVec4 = imgui.ImVec2, imgui.ImVec4

-- Accent is the same purple autobind used for its map borders, so the settings
-- window and the thing it configures read as one mod.
local ACCENT       = {0.62, 0.36, 0.86}
local ACCENT_DIM   = {0.44, 0.26, 0.62}

local function rgba(c, a) return ImVec4(c[1], c[2], c[3], a or 1.0) end
local function grey(v, a) return ImVec4(v, v, v, a or 1.0) end

M.ACCENT = ACCENT

--- Apply the theme. Cheap enough to re-run on a scale change, and it must be:
--- every metric below is in scaled pixels.
function M.apply()
    imgui.SwitchContext()
    local s = imgui.GetStyle()

    -- Metrics. Rounded frames and real padding are most of what separates this
    -- from the stock look.
    s.WindowRounding        = scaleM.f(6)
    s.WindowBorderSize      = scaleM.f(1)
    s.WindowPadding         = scaleM.v2(14, 12)
    s.WindowTitleAlign      = ImVec2(0.5, 0.5)
    s.ChildRounding         = scaleM.f(4)
    s.FrameRounding         = scaleM.f(4)
    s.FramePadding          = scaleM.v2(8, 4)
    s.ItemSpacing           = scaleM.v2(9, 7)
    s.ItemInnerSpacing      = scaleM.v2(7, 5)
    s.IndentSpacing         = scaleM.f(14)
    s.ScrollbarSize         = scaleM.f(12)
    s.ScrollbarRounding     = scaleM.f(6)
    s.GrabMinSize           = scaleM.f(11)
    s.GrabRounding          = scaleM.f(4)
    s.TabRounding           = scaleM.f(4)
    s.PopupRounding         = scaleM.f(4)
    s.ButtonTextAlign       = ImVec2(0.5, 0.5)
    s.AntiAliasedLines      = true
    s.AntiAliasedFill       = true
    s.Alpha                 = 1.0

    local c = s.Colors
    local C = imgui.Col

    c[C.Text]                  = grey(0.90)
    c[C.TextDisabled]          = grey(0.48)
    c[C.WindowBg]              = ImVec4(0.07, 0.07, 0.09, 0.97)
    c[C.ChildBg]               = ImVec4(0.00, 0.00, 0.00, 0.00)
    c[C.PopupBg]               = ImVec4(0.09, 0.09, 0.11, 0.98)
    c[C.Border]                = rgba(ACCENT_DIM, 0.55)
    c[C.BorderShadow]          = ImVec4(0, 0, 0, 0)

    c[C.FrameBg]               = ImVec4(0.16, 0.15, 0.19, 1.00)
    c[C.FrameBgHovered]        = rgba(ACCENT_DIM, 0.55)
    c[C.FrameBgActive]         = rgba(ACCENT_DIM, 0.80)

    c[C.TitleBg]               = ImVec4(0.10, 0.09, 0.12, 1.00)
    c[C.TitleBgActive]         = rgba(ACCENT_DIM, 0.85)
    c[C.TitleBgCollapsed]      = ImVec4(0.10, 0.09, 0.12, 0.75)
    c[C.MenuBarBg]             = ImVec4(0.12, 0.11, 0.14, 1.00)

    c[C.ScrollbarBg]           = ImVec4(0.06, 0.06, 0.08, 0.60)
    c[C.ScrollbarGrab]         = grey(0.28)
    c[C.ScrollbarGrabHovered]  = rgba(ACCENT_DIM, 0.80)
    c[C.ScrollbarGrabActive]   = rgba(ACCENT, 0.90)

    c[C.CheckMark]             = rgba(ACCENT, 1.00)
    c[C.SliderGrab]            = rgba(ACCENT, 0.85)
    c[C.SliderGrabActive]      = rgba(ACCENT, 1.00)

    c[C.Button]                = ImVec4(0.19, 0.18, 0.23, 1.00)
    c[C.ButtonHovered]         = rgba(ACCENT_DIM, 0.90)
    c[C.ButtonActive]          = rgba(ACCENT, 0.95)

    c[C.Header]                = rgba(ACCENT_DIM, 0.65)
    c[C.HeaderHovered]         = rgba(ACCENT_DIM, 0.85)
    c[C.HeaderActive]          = rgba(ACCENT, 0.90)

    c[C.Separator]             = rgba(ACCENT_DIM, 0.40)
    c[C.SeparatorHovered]      = rgba(ACCENT, 0.70)
    c[C.SeparatorActive]       = rgba(ACCENT, 0.95)

    c[C.ResizeGrip]            = ImVec4(0, 0, 0, 0)
    c[C.ResizeGripHovered]     = rgba(ACCENT_DIM, 0.60)
    c[C.ResizeGripActive]      = rgba(ACCENT, 0.80)

    -- Tabs exist in this ImGui build; guarded because the enum moved around
    -- across versions and a nil index here would take the whole theme down.
    pcall(function()
        c[C.Tab]                = ImVec4(0.14, 0.13, 0.17, 1.00)
        c[C.TabHovered]         = rgba(ACCENT_DIM, 0.85)
        c[C.TabActive]          = rgba(ACCENT_DIM, 1.00)
        c[C.TabUnfocused]       = ImVec4(0.12, 0.11, 0.14, 1.00)
        c[C.TabUnfocusedActive] = ImVec4(0.16, 0.15, 0.19, 1.00)
    end)

    c[C.PlotLines]             = rgba(ACCENT, 0.90)
    c[C.PlotLinesHovered]      = rgba(ACCENT, 1.00)
    c[C.PlotHistogram]         = rgba(ACCENT, 0.90)
    c[C.PlotHistogramHovered]  = rgba(ACCENT, 1.00)
    c[C.TextSelectedBg]        = rgba(ACCENT_DIM, 0.55)
end

-- ---------------------------------------------------------------------------
-- Layout helpers
-- ---------------------------------------------------------------------------

--[[
    section(title)

    A titled divider. The old panels used a bare imgui.Text for headings, which
    rendered identically to the controls under them - so "Fast Map", "Mini Map"
    and "Colors" read as just more label text and the panel had no visible
    structure.
]]
--[[
    Built once, not per call. `rgba(ACCENT, 0.95)` allocated a fresh ImVec4 on
    every heading, and a panel draws several per frame for as long as it is
    open - the hud host suite holds a settings tab to 0.05 KB/frame and this
    alone was three times that.
]]
local SECTION_TEXT = rgba(ACCENT, 0.95)

--[[
    The uppercased captions, interned.

    `title:upper()` allocates a string per heading per frame for text that is
    a literal at every call site in every mod. Keyed on the original, so a
    caller passing a computed title still works - it just pays once per
    distinct string rather than once per frame.
]]
local sectionTitles = setmetatable({}, {__mode = 'k'})

function M.section(title)
    local caption = sectionTitles[title]
    if not caption then
        caption = title:upper()
        sectionTitles[title] = caption
    end
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Text, SECTION_TEXT)
    imgui.Text(caption)
    imgui.PopStyleColor()
    imgui.Separator()
    imgui.Spacing()
end

--[[
    card(opts) - the status card that sits at the top of a settings window.

    WHY IT IS HERE AND NOT IN EACH MOD

    autofps grew this first, and it earned its place there: a settings window
    configures something that is running RIGHT NOW, and the facts that decide
    whether any of it is doing anything - is the feature on, what mode is it
    in, what is stopping it - were otherwise scattered across the controls that
    set them, or not shown at all.

    Every mod in this set has that same problem, so this is the one
    implementation rather than seven. It was copied by hand into two of them
    before this existed, which is precisely how the two versions of the
    Interface tab happened (see akacross.interface).

    opts.title    REQUIRED function -> string. The headline, in the accent
                  colour. Usually the master on/off state.
    opts.onClick  optional. Makes the headline clickable - the card becomes the
                  master toggle, which is what lets a mod drop a separate one.
    opts.tooltip  optional string, shown when the headline is hovered.
    opts.right    optional function -> string. Right-aligned, dim. A secondary
                  fact: which config, which server, which profile.
    opts.status   optional function -> string. Second line, dim. The one thing
                  worth saying about why the feature is or is not working.
    opts.height   optional design px, default CARD_H.

    EVERY CALLBACK RUNS ONCE PER FRAME, so they must return an already-built
    string. Formatting inside them allocates on every frame the window is open,
    which is the whole class of waste the widget layers here exist to avoid -
    cache on the value that decides the text and return the cached string.

    Painted onto the window draw list rather than with PushStyleColor, so there
    is nothing left on ImGui's global style stack if the body below it throws.
]]
local CARD_H, CARD_PAD = 54, 12

local pA, pB = ImVec2(0, 0), ImVec2(0, 0)
local clickSize = ImVec2(0, 0)

local function fillRect(dl, x1, y1, x2, y2, col, rounding)
    pA.x, pA.y = x1, y1
    pB.x, pB.y = x2, y2
    dl:AddRectFilled(pA, pB, col, rounding or 0, 15)
end

-- Draw-list colours are packed 0xAABBGGRR, not the 0xAARRGGBB every other
-- colour in this file uses. Derived from the palette above so the card cannot
-- drift away from the theme it sits inside.
local function abgr(c, a)
    return math.floor((a or 1.0) * 255) * 0x1000000
         + math.floor(c[3] * 255) * 0x10000
         + math.floor(c[2] * 255) * 0x100
         + math.floor(c[1] * 255)
end

local CARD_BG   = abgr({0.11, 0.10, 0.14})
local CARD_EDGE = abgr(ACCENT)
local CARD_TEXT = rgba(ACCENT, 1.0)

function M.card(opts)
    local dl    = imgui.GetWindowDrawList()
    local org   = imgui.GetCursorScreenPos()
    local x0    = imgui.GetCursorPosX()
    local avail = imgui.GetContentRegionAvail().x
    local pad   = scaleM.f(CARD_PAD)
    local h     = scaleM.f(opts.height or CARD_H)

    fillRect(dl, org.x, org.y, org.x + avail, org.y + h, CARD_BG, scaleM.f(6))
    -- The accent bar down the left edge. Inset top and bottom so it reads as a
    -- marker rather than as a border the card is missing three sides of.
    fillRect(dl, org.x, org.y + scaleM.f(7), org.x + scaleM.f(3),
             org.y + h - scaleM.f(7), CARD_EDGE, scaleM.f(1.5))

    imgui.SetCursorPosY(imgui.GetCursorPosY() + scaleM.f(8))

    local title = opts.title()
    imgui.SetCursorPosX(x0 + pad)
    imgui.PushStyleColor(imgui.Col.Text, CARD_TEXT)
    if opts.onClick then
        -- Sized to the text: a full-width Selectable would make the whole card
        -- a click target, including the right-hand fact, which is not a button.
        clickSize.x, clickSize.y = imgui.CalcTextSize(title).x, 0
        if imgui.Selectable(title, false, 0, clickSize) then opts.onClick() end
    else
        imgui.Text(title)
    end
    imgui.PopStyleColor()
    if opts.tooltip and imgui.IsItemHovered() then imgui.SetTooltip(opts.tooltip) end

    if opts.right then
        local text = opts.right()
        imgui.SameLine()
        imgui.SetCursorPosX(x0 + avail - imgui.CalcTextSize(text).x - pad)
        imgui.TextDisabled(text)
    end

    if opts.status then
        imgui.SetCursorPosX(x0 + pad)
        imgui.TextDisabled(opts.status())
    end

    imgui.SetCursorPosY(imgui.GetCursorPosY() + scaleM.f(10))
end

--- Label in a fixed-width gutter, then the control. Keeps every slider and
--- combo starting at the same x instead of each one setting its own width.
local LABEL_W = 150
function M.labelled(text, tooltipFn)
    imgui.Text(text)
    if tooltipFn then tooltipFn() end
    imgui.SameLine(scaleM.f(LABEL_W))
    imgui.PushItemWidth(scaleM.f(210))
end

function M.endLabelled()
    imgui.PopItemWidth()
end

--- Checkbox whose caption carries its own state, laid out on a grid so a row
--- of them lines up. autobind's convention was "Enable On" / "Enable Off";
--- kept, because reading the state without hunting for the tick is useful.
function M.toggle(label, id, cdata, column)
    if column and column > 1 then imgui.SameLine(scaleM.f(20 + (column - 1) * 175)) end
    imgui.Checkbox(("%s %s##%s"):format(label, cdata[0] and "On" or "Off", id), cdata)
end

return M
