local imgui_funcs = {}
imgui_funcs._VERSION = '0.2.0'
imgui_funcs.__index = imgui_funcs

local imgui = require("mimgui")

local tempOffset = imgui.ImVec2(0, 0)
local currentlyDragging = nil

local offset = imgui.ImVec2(0, 0)
local boxPos = imgui.ImVec2(0, 0)
local newBoxPos = imgui.ImVec2(0, 0)

function imgui_funcs.handleWindowDragging(menuId, pos, size, pivot, borderSize, mousePos, screenRes, dragging, titlebarHeight)
    if not dragging then
        return false, pos.x, pos.y
    end

    offset.x = size.x * pivot.x
    offset.y = size.y * pivot.y
    boxPos.x = pos.x - offset.x
    boxPos.y = pos.y - offset.y

    local inDragZone = mousePos.x >= boxPos.x and mousePos.x <= boxPos.x + size.x and
                       mousePos.y >= boxPos.y and mousePos.y <= boxPos.y + (titlebarHeight == -1 and size.y or titlebarHeight)

    if inDragZone then
        if imgui.IsMouseClicked(0) and not imgui.IsAnyItemHovered() then
            currentlyDragging = menuId
            tempOffset.x = mousePos.x - boxPos.x
            tempOffset.y = mousePos.y - boxPos.y
        end
    end

    if currentlyDragging == menuId then
        if imgui.IsMouseReleased(0) then
            tempOffset.x = 0
            tempOffset.y = 0
            currentlyDragging = nil
        else
            newBoxPos.x = mousePos.x - tempOffset.x
            newBoxPos.y = mousePos.y - tempOffset.y

            newBoxPos.x = math.max(borderSize / 2, math.min(newBoxPos.x, screenRes.x - size.x - borderSize / 2 + 0.5))
            newBoxPos.y = math.max(borderSize / 2, math.min(newBoxPos.y, screenRes.y - size.y - borderSize / 2 + 0.5))

            return true, newBoxPos.x + offset.x, newBoxPos.y + offset.y
        end
    end

    return false, pos.x, pos.y
end

function imgui_funcs.resetCurrentWindowDragging()
    currentlyDragging = nil
    tempOffset.x = 0
    tempOffset.y = 0
end

function imgui_funcs.calcTextSize(text)
    local processedText = text:gsub("{%x+}", "")
    return imgui.CalcTextSize(processedText)
end

function imgui_funcs.calculateWindowSize(lines, padding)
    local totalHeight = 0
    local maxWidth = 0
    local lineSpacing = imgui.GetTextLineHeightWithSpacing() - imgui.GetTextLineHeight()

    for _, text in ipairs(lines) do
        local textSize = imgui_funcs.calcTextSize(text)
        totalHeight = totalHeight + textSize.y + lineSpacing
        if textSize.x > maxWidth then
            maxWidth = textSize.x
        end
    end
    totalHeight = totalHeight - lineSpacing

    return maxWidth + padding.x * 2, totalHeight + padding.y * 2
end

-- ---- colored-text pipeline (hot path) -----------------------------------
-- TextColoredRGB runs for every colored label and every tooltip, almost
-- always with the SAME string as last frame. Parsing ({RRGGBB[AA]} tokens)
-- is therefore cached per unique string (segment colors as ready ImVec4s;
-- `false` = "use the style text color at draw time"), and plain strings
-- take a token-free fast path.

local BLACK_OUTLINE = imgui.ImVec4(0, 0, 0, 1)
local outlinePos = imgui.ImVec2(0, 0)

--[[
    The black 1px outline, drawn unconditionally.

    This used to be gated on SA-MP's chat display mode (SFAPI's ChatDisplayMode:
    0 OFF, 1 LIGHT = text with no background box, 2 FULL = with the box) and
    tested `== 2`, so the outline appeared in FULL and vanished in LIGHT - two
    modes that are both "chat is on". Cycling chat with F7 restyled every menu
    label and tooltip in the mod, for a reason no player could connect to the
    key they had just pressed.

    The gate is gone rather than corrected, because it was never load-bearing:
    every caller draws inside one of OUR ImGui windows - menu labels, locker
    lists, CustomTooltip - and never over the raw game world, so the player's
    chat setting has no bearing on whether this text is legible. It read as
    something carried forward rather than decided.

    The per-frame chat-mode cache went with it; it existed only to keep this
    branch off sampGetChatDisplayMode on a hot path.

    Cost: 5 text draws per segment instead of 1, now on every segment rather
    than only in FULL mode. That is what it already did for anyone whose chat
    sat in the default mode, so this is not a new worst case - just a consistent
    one. If it ever needs to be optional it should be a style setting, not a
    reading of an unrelated game option.
]]
local function drawTextSegment(str, color)
    local pos = imgui.GetCursorPos()
    outlinePos.x, outlinePos.y = pos.x + 1, pos.y
    imgui.SetCursorPos(outlinePos)
    imgui.TextColored(BLACK_OUTLINE, str)
    outlinePos.x = pos.x - 1
    imgui.SetCursorPos(outlinePos)
    imgui.TextColored(BLACK_OUTLINE, str)
    outlinePos.x, outlinePos.y = pos.x, pos.y + 1
    imgui.SetCursorPos(outlinePos)
    imgui.TextColored(BLACK_OUTLINE, str)
    outlinePos.y = pos.y - 1
    imgui.SetCursorPos(outlinePos)
    imgui.TextColored(BLACK_OUTLINE, str)
    imgui.SetCursorPos(pos)
    imgui.TextColored(color, str)
end

-- cache entry: { segments = {str1, color1, str2, color2, ...} (flat pairs),
--               tail = string|nil, tailColor = ImVec4|false, visible = str }
local textSegmentCache = {}
local textSegmentCount = 0

local function parseColoredText(text)
    local cached = textSegmentCache[text]
    if cached then return cached end

    local norm = text:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')
    local segments = {}
    local color = false
    local start = 1
    local a, b = norm:find('{........}', 1)
    while a do
        local chunk = norm:sub(start, a - 1)
        if #chunk > 0 then
            segments[#segments + 1] = chunk
            segments[#segments + 1] = color
        end
        local token = norm:sub(a + 1, b - 1)
        if token:upper() == 'STANDART' then
            color = false
        else
            local value = tonumber(token, 16)
            if value then
                color = imgui.ImVec4(
                    bit.band(bit.rshift(value, 24), 0xFF) / 255,
                    bit.band(bit.rshift(value, 16), 0xFF) / 255,
                    bit.band(bit.rshift(value, 8), 0xFF) / 255,
                    bit.band(value, 0xFF) / 255
                )
            end
        end
        start = b + 1
        a, b = norm:find('{........}', start)
    end

    cached = {
        segments = segments,
        tail = (#norm >= start) and norm:sub(start) or nil,
        tailColor = color,
        visible = norm:gsub('{........}', '')
    }

    -- bounded: high-cardinality dynamic strings (countdowns in labels)
    -- must not grow the cache forever
    if textSegmentCount >= 512 then
        textSegmentCache = {}
        textSegmentCount = 0
    end
    textSegmentCache[text] = cached
    textSegmentCount = textSegmentCount + 1
    return cached
end

local function applyAlignment(align, visibleText)
    if align and align ~= "left" then
        local textWidth = imgui.CalcTextSize(visibleText).x
        local availWidth = imgui.GetContentRegionAvail().x
        if align == "center" then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max((availWidth - textWidth) * 0.5, 0))
        elseif align == "right" then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(availWidth - textWidth, 0))
        end
    end
end

function imgui_funcs.TextColoredRGB(text, align)
    -- fast path: no color tokens at all
    if not text:find('{', 1, true) then
        applyAlignment(align, text)
        drawTextSegment(text, imgui.GetStyle().Colors[imgui.Col.Text])
        return
    end

    local parsed = parseColoredText(text)
    applyAlignment(align, parsed.visible)

    local styleColor = imgui.GetStyle().Colors[imgui.Col.Text]
    local segments = parsed.segments
    for i = 1, #segments, 2 do
        drawTextSegment(segments[i], segments[i + 1] or styleColor)
        imgui.SameLine(nil, 0)
    end
    if parsed.tail then
        drawTextSegment(parsed.tail, parsed.tailColor or styleColor)
    else
        imgui.NewLine()
    end
end

customSizeButton = imgui.ImVec2(0, 0)
function imgui_funcs.CustomButton(name, color, colorHovered, colorActive, textColor, size)
    local clr = imgui.Col
    imgui.PushStyleColor(clr.Button, color)
    imgui.PushStyleColor(clr.ButtonHovered, colorHovered)
    imgui.PushStyleColor(clr.ButtonActive, colorActive)
    imgui.PushStyleColor(clr.Text, textColor)
    if not size then 
        size = customSizeButton 
    end
    local result = imgui.Button(name, size)
    imgui.PopStyleColor(4)
    return result
end

tooltipPadding = imgui.ImVec2(8, 8)
function imgui_funcs.CustomTooltip(tooltip)
    if imgui.IsItemHovered() and tooltip then
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, tooltipPadding)
        imgui.BeginTooltip()
        imgui_funcs.TextColoredRGB(tooltip)
        imgui.EndTooltip()
        imgui.PopStyleVar()
    end
end

function imgui_funcs.loadFontIcons(fileOrMemory, fontSize, min, max, fontdata)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](min, max, 0)
	if fileOrMemory then
		imgui.GetIO().Fonts:AddFontFromFileTTF(fontdata, fontSize, config, iconRanges)
	else
		imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fontdata, fontSize, config, iconRanges)
	end
end

function imgui_funcs.AnimProgressBar(label, int, int2, duration, size, color, color2)
	-- (rewritten without `then;` empty statements - those are Lua 5.2-only
	-- syntax that happened to parse under MoonLoader's 5.2-compat LuaJIT)
	local function bringFloatTo(from, to, start_time, duration)
		local timer = os.clock() - start_time
		if timer >= 0.00 and timer <= duration then
			local count = timer / (duration / int2)
			return from + (count * (to - from) / int2), timer, false
		end
		return (timer > duration) and to or from, timer, true
	end
    if int > int2 then imgui.TextColored(imgui.ImVec4(1,0,0,0.7),'error func imgui_funcs.AnimProgressBar(*),int > 100') return end
    if IMGUI_ANIM_PROGRESS_BAR == nil then IMGUI_ANIM_PROGRESS_BAR = {} end
    if IMGUI_ANIM_PROGRESS_BAR ~= nil and IMGUI_ANIM_PROGRESS_BAR[label] == nil then
        IMGUI_ANIM_PROGRESS_BAR[label] = {int = (int or 0),clock = 0}
    end
    local mf = math.floor
    local p = IMGUI_ANIM_PROGRESS_BAR[label];
    if (p['int']) ~= (int) then
        if p.clock == 0 then p.clock = os.clock() end
        local d = {bringFloatTo(p.int,int,p.clock,(duration or 2.25))}
        if d[1] > int  then
            if ((d[1])-0.01) < (int) then p.clock = 0; p.int = mf(d[1]-0.01) end
        elseif d[1] < int then
            if ((d[1])+0.01) > (int) then p.clock = 0; p.int = mf(d[1]+0.01) end
        end
        p.int = d[1];
    end
	local clr = imgui.Col
    imgui.PushStyleColor(clr.Text, imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(clr.FrameBg, color) -- background color progress bar
    imgui.PushStyleColor(clr.PlotHistogram, color2) -- fill color progress bar
    imgui.ProgressBar(p.int / int2,size or imgui.ImVec2(-1,15))
    imgui.PopStyleColor(3)
end

return imgui_funcs
