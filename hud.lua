script_name("Hud")
script_author("akacross")
script_url("https://akacross.net/")

local script_version = 0.5

if getMoonloaderVersion() >= 27 then
	require 'libstd.deps' {
	   'fyp:mimgui',
	   'fyp:samp-lua', 
	   'fyp:fa-icons-4',
	   'donhomka:extensions-lite'
	}
end

require"lib.moonloader"
require"lib.sampfuncs"
require 'extensions-lite'

local imgui, ffi = require 'mimgui', require 'ffi'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local ped, h = playerPed, playerHandle
local vk = require 'vkeys'
local wm = require 'lib.windows.message'
local keys  = require 'game.keys'
local weapons = require'game.weapons'
local sampev = require 'lib.samp.events'
local mem = require 'memory'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local mimgui_addons = require 'mimgui_addons'
local flag = require ('moonloader').font_flag
local faicons = require 'fa-icons'
local ti = require 'tabler_icons'
local dlstatus = require('moonloader').download_status
local https = require 'ssl.https'
local path = getWorkingDirectory() .. '/config/' 
local iconspath = getWorkingDirectory() .. '/resource/icons/' 
local cfg = path .. 'hud.ini' 
local script_path = thisScript().path
local script_url = "https://raw.githubusercontent.com/akacross/hud/main/hud.lua"
local update_url = "https://raw.githubusercontent.com/akacross/hud/main/hud.txt"
local icons_url = "https://raw.githubusercontent.com/akacross/hud/main/resource/icons/"

ffi.cdef
[[
    void *malloc(size_t size);
    void free(void *ptr);
]]

local mainc = imgui.ImVec4(0.92, 0.27, 0.92, 1.0)
local menu = new.bool(false)
local mid = 1
local move = false
local update = false

local value = {
	{0},{0},{0},{0},{0},{0,0,0},{0,0},{0,0,0,0,0,0,0,0,0,0,0}
}

local spec = {
	playerid = -1, 
	state = false
}

local debug_tog = false

local blank = {}
local hud = {
	toggle = true,
	autosave = false,
	autoupdate = false,
	tog = {
		{true,true,false},
		{true,true,true},
		{true,true},
		{true,true,true,true},
		{true,true,true},
		{true,true,true,true,true},
		{true,true,true,true},
		{{true,false},{true,true},{true},{true,true},{true,true},{true,true},{true},{true},{true},{true},{true}}
	},
	pos = {
		{
			name = 'Hud',
			x = 525,
			y = 234,
			move = false
		},
		{
			name = 'Misc',
			x = 500,
			y = 500,
			move = false
		},
	},
	move = {
		{1,1},{1,1},{1,1},{1,1},{1,1},{1,1,1},{1,1},{2,2,2,2,2,2,2,2,2,2,2}
	},
	offx = {
		{120,183},{120,183},{120,183},{120,183},{120,183},{-1.5,97,56.4},{115,248.6},{0,0,0,0,0,0,0,0,0,0,0}
	},
	offy = {
		{80,82},{60,62},{40,42},{20,22},{-0,2},{-8.5,73.5,101.5},{118.8,95.7},{0.0,17.0,33.8,52.0,71.5,90.0,110.0,129.0,146.0,167.0,186.0}
	},
	sizex = {130,130,130,130,130,115,22},
	sizey = {17,17,17,17,17,115,22},
	border = {1,1,1,1,1},
	color = {
		{{-65536,	1677721600,	-16777216},	-1},
		{{-1,		1677721600,	-16777216},	-1},
		{{-1536,	1677721600,	-16777216},	-1},
		{{-16711931,1677721600,	-16777216, -1536, -65536},	-1},
		{{-16711687,1677721600,	-16777216},	-1},
		{{-1, -16777216}, -1, -1},
		{{-13568}, -14689241},
		{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}
	},
	spacing = -3,
	maxvalue = {100,100,100,1000,100},
	serverhp = {8000000,5000000},
	font = {{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial","Aerial"},{"Aerial"},{"Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial"}},
	fontsize = {{8},{8},{8},{8},{8},{8,10},{16},{10,10,10,10,10,10,10,10,10,10,10}},
	fontflag = {
		{{true,true,true,true}},
		{{true,true,true,true}},
		{{true,true,true,true}},
		{{true,true,true,true}},
		{{true,true,true,true}},
		{{true,true,true,true},{true,true,true,true}},
		{{true,false,true,true}},
		{{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true},{true,true,true,true}}
	},
	alignfont = {
		{2},{2},{2},{2},{2},{1,2},{1},{3,3,3,3,3,3,3,3,3,3,3}
	},
	radar = {
		pos = {10,99}, 
		size = {90,90}, 
		color = -16777216,
		compass = false
	},
	hzgsettings = {
		turf = false,
		turfowner = false,
		wristwatch = false,
		hzglogo = false
	}
}

local assets = {
	temp_pos = {x = 0, y = 0},
	wid = {},
	fid = {
		{0},{0},{0},{0},{0},{0,0},{0},{0,0,0,0,0,0,0,0,0,0,0}
	}, 
	vehid = {427,528,601},
	mnames = {'Health','Armor','Sprint','Vehicle','Breath','Weapon','Stars/Cash','Other','Radar','Groups'},
	fnames = {'Name','Local-Time','Server-Time','Ping','FPS','Direction','Location','Turf','Vehicle Speed','Vehicle Name','Badge'},
	compass = {},
	badge = {
		{-1, 		'No Badge'},
		{-14269954, 'LSPD'},
		{-7500289, 	'FBI'},
		{-14911565, 'ARES'},
		{-4276546, 	'GOV'},
		{-3368653, 	'SASD'},
		{-32126, 	'LSFMD'},
		{-16475023, 'SANEWS'},
		{-7684107, 	'DD'}
	}
}

local fps = 0
local fps_counter = 0

local inuse = false
local selected = {
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false,false,false,false,false,false,false,false,false,false}
}

function apply_custom_style()
   local style = imgui.GetStyle()
   local colors = style.Colors
   local clr = imgui.Col
   local ImVec4 = imgui.ImVec4
   style.WindowRounding = 1.5
   style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
   style.FrameRounding = 1.0
   style.ItemSpacing = imgui.ImVec2(4.0, 4.0)
   style.ScrollbarSize = 13.0
   style.ScrollbarRounding = 0
   style.GrabMinSize = 8.0
   style.GrabRounding = 1.0
   style.WindowBorderSize = 0.0
   style.WindowPadding = imgui.ImVec2(4.0, 4.0)
   style.FramePadding = imgui.ImVec2(2.5, 3.5)
   style.ButtonTextAlign = imgui.ImVec2(0.5, 0.35)
 
   colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
   colors[clr.TextDisabled]           = ImVec4(0.7, 0.7, 0.7, 1.0)
   colors[clr.WindowBg]               = ImVec4(0.07, 0.07, 0.07, 1.0)
   colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
   colors[clr.Border]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
   colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
   colors[clr.FrameBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 0.7)
   colors[clr.FrameBgHovered]         = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
   colors[clr.FrameBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.9)
   colors[clr.TitleBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.TitleBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.TitleBgCollapsed]       = ImVec4(mainc.x, mainc.y, mainc.z, 0.79)
   colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
   colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
   colors[clr.ScrollbarGrab]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
   colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
   colors[clr.CheckMark]              = ImVec4(mainc.x + 0.13, mainc.y + 0.13, mainc.z + 0.13, 1.00)
   colors[clr.SliderGrab]             = ImVec4(0.28, 0.28, 0.28, 1.00)
   colors[clr.SliderGrabActive]       = ImVec4(0.35, 0.35, 0.35, 1.00)
   colors[clr.Button]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ButtonHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
   colors[clr.ButtonActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.Header]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.6)
   colors[clr.HeaderHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.43)
   colors[clr.HeaderActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.Separator]              = colors[clr.Border]
   colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
   colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
   colors[clr.ResizeGrip]             = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
   colors[clr.ResizeGripHovered]      = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
   colors[clr.ResizeGripActive]       = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
   colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
   colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
   colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
   colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
   colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
 end

imgui.OnInitialize(function()
	apply_custom_style() -- apply custom style
	local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
	imgui.GetIO().Fonts:Clear() -- clear the fonts
	local font_config = imgui.ImFontConfig() -- each font has its own config
	font_config.SizePixels = 14.0;
	font_config.GlyphExtraSpacing.x = 0.1
	-- main font
	local def = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arialbd.ttf', font_config.SizePixels, font_config, defGlyph)
   
	local config = imgui.ImFontConfig()
	config.MergeMode = true
	config.PixelSnapH = true
	config.FontDataOwnedByAtlas = false
	config.GlyphOffset.y = 1.0 -- offset 1 pixel from down
	local fa_glyph_ranges = new.ImWchar[3]({ faicons.min_range, faicons.max_range, 0 })
	local iconRanges = imgui.new.ImWchar[3](ti.min_range, ti.max_range, 0)
	-- icons
	local faicon = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85(), font_config.SizePixels, config, fa_glyph_ranges)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(ti.get_font_data_base85(), font_config.SizePixels, config, iconRanges)

	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	imgui.GetIO().IniFilename = nil
end)


imgui.OnFrame(function() return menu[0] end,
function()
	local center = imgui.ImVec2(imgui.GetIO().DisplaySize.x / 2, imgui.GetIO().DisplaySize.y / 2)
	imgui.SetNextWindowPos(center, imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin(ti.ICON_SETTINGS .. string.format("%s Settings - %s[%d] - Version: %s", script.this.name, assets.mnames[mid], mid, script_version), menu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.MenuBar)
	
		imgui.BeginMenuBar()
			if imgui.BeginMenu('Elements') then
				for i = 1, 7 do 
					if imgui.MenuItemBool(string.format("%s[%d]", assets.mnames[i], i)) then
						mid = i 
					end
				end
				imgui.EndMenu()
			end
			for i = 8, 10 do 
				if imgui.MenuItemBool(u8(assets.mnames[i])) then
					mid = i 
				end
			end
		imgui.EndMenuBar()
		
		if imgui.Checkbox(u8(script.this.name), new.bool(hud.toggle)) then hud.toggle = not hud.toggle end 
		imgui.SameLine() 
		if imgui.Checkbox(u8'Autosave', new.bool(hud.autosave)) then hud.autosave = not hud.autosave saveIni() end  
		
		imgui.SameLine() 
		imgui.BeginGroup()
			if imgui.Button(u8'Reset') then blankIni() createfonts() hztextdraws() end 
			imgui.SameLine()
			if imgui.Button(u8'Save') then saveIni() end 
			imgui.SameLine()
			if imgui.Button(u8'Reload') then loadIni() end
			imgui.SameLine()
			if imgui.Button(ti.ICON_REFRESH .. 'Update') then
				update_script()
			end 
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Update the script')
			end
			imgui.SameLine()
			if imgui.Checkbox('##autoupdate', new.bool(hud.autoupdate)) then 
				hud.autoupdate = not hud.autoupdate 
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Auto-Update')
			end
		imgui.EndGroup()
	
		if mid >= 1 and mid <= 7 then 
			imgui.BeginChild("##bgTwo", imgui.ImVec2(345, 160), false)
				if imgui.Checkbox(u8'Bar', new.bool(hud.tog[mid][1])) then hud.tog[mid][1] = not hud.tog[mid][1] end 
				imgui.SameLine() 
				if imgui.Checkbox(u8'Text', new.bool(hud.tog[mid][2])) then hud.tog[mid][2] = not hud.tog[mid][2] end 
				if mid == 1 then imgui.SameLine() if imgui.Checkbox(u8'160 HP', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] setmaxhp() end end
				if mid == 4 then imgui.SameLine() if imgui.Checkbox(u8'2500 HP Vehicles', new.bool(hud.tog[mid][4])) then hud.tog[mid][4] = not hud.tog[mid][4] end end
				if mid == 2 or mid == 4 or mid == 5 then imgui.SameLine() if imgui.Checkbox(u8'Stay On', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] end end
				if mid == 6 then 
					imgui.SameLine() if imgui.Checkbox(u8'Name', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] end 
					imgui.SameLine() if imgui.Checkbox(u8'Frame', new.bool(hud.tog[mid][4])) then hud.tog[mid][4] = not hud.tog[mid][4] end
					imgui.SameLine() if imgui.Checkbox(u8'Ammo', new.bool(hud.tog[mid][5])) then hud.tog[mid][5] = not hud.tog[mid][5] end
				end
				if mid == 7 then 
					imgui.SameLine() 
					if imgui.Checkbox(u8'($)', new.bool(hud.tog[mid][3])) then 
						hud.tog[mid][3] = not hud.tog[mid][3] 
					end 
					imgui.SameLine()
					if imgui.Checkbox(u8'Comma', new.bool(hud.tog[mid][4])) then 
						hud.tog[mid][4] = not hud.tog[mid][4] 
					end 
				end
				
				imgui.NewLine() 
				imgui.SameLine(2) 
				imgui.Text(u8'Left/Right') 
				imgui.SameLine(90) 
				imgui.Text(u8'Up/Down') 
				imgui.SameLine(180) 
				imgui.Text(u8'Width') 
				imgui.SameLine(270) 
				imgui.Text(u8'Height') 
				
				imgui.PushItemWidth(330) 
				off = new.float[4](hud.offx[mid][1], hud.offy[mid][1], hud.sizex[mid], hud.sizey[mid])
				if imgui.DragFloat4('##movement', off, 0.1, 20 * -2000, 20 * 2000, "%.1f") then 
					hud.offx[mid][1] = off[0] 
					hud.offy[mid][1] = off[1] 
					hud.sizex[mid] = off[2] 
					hud.sizey[mid] = off[3] 
				end 
				imgui.PopItemWidth()
				
				
				imgui.PushItemWidth(70)
				if imgui.BeginCombo("##Colors", 'Colors') then
					color = new.float[3](hex2rgb(hud.color[mid][1][1]))
					if imgui.ColorEdit3('##color', color, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						hud.color[mid][1][1] = join_argb(255, color[0] * 255, color[1] * 255, color[2] * 255) 
					end
					imgui.SameLine()
					imgui.Text('Color')
					
					if mid == 4 then
						local dcolor = new.float[4](hex2rgba(hud.color[mid][1][4]))
						if imgui.ColorEdit4('##damage1', dcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							hud.color[mid][1][4] = join_argb(dcolor[3] * 255, dcolor[0] * 255, dcolor[1] * 255, dcolor[2] * 255) 
						end 
						imgui.SameLine()
						imgui.Text('400-700')
							
						local dcolor2 = new.float[4](hex2rgba(hud.color[mid][1][5]))
						if imgui.ColorEdit4('##damage2', dcolor2, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							hud.color[mid][1][5] = join_argb(dcolor2[3] * 255, dcolor2[0] * 255, dcolor2[1] * 255, dcolor2[2] * 255) 
						end 
						imgui.SameLine()
						imgui.Text('0-400')
					end
					
					if mid >= 1 and mid <= 5 then
						bcolor = new.float[3](hex2rgb(hud.color[mid][1][3]))
						if imgui.ColorEdit3('##border', bcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							hud.color[mid][1][3] = join_argb(255, bcolor[0] * 255, bcolor[1] * 255, bcolor[2] * 255) 
						end
						imgui.SameLine()
						imgui.Text('Border')
						
						fcolor = new.float[4](hex2rgba(hud.color[mid][1][2]))
						if imgui.ColorEdit4('##fade', fcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							hud.color[mid][1][2] = join_argb(fcolor[3] * 255, fcolor[0] * 255, fcolor[1] * 255, fcolor[2] * 255) 
						end 
						imgui.SameLine()
						imgui.Text('Fade')
						
					elseif mid == 6 then
						fcolor = new.float[3](hex2rgb(hud.color[mid][1][2])) 
						if imgui.ColorEdit3('##frame', fcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
							hud.color[mid][1][2] = join_argb(255, fcolor[0] * 255, fcolor[1] * 255, fcolor[2] * 255) 
						end
						imgui.SameLine()
						imgui.Text('Frame')
					end
					imgui.EndCombo()
				end
				imgui.PopItemWidth()
				imgui.SameLine() 
				
				if mid >= 1 and mid <= 5 then
					imgui.SameLine() 
					imgui.PushItemWidth(40)
					border = new.float[1](hud.border[mid])
					if imgui.DragFloat(u8'Border', border, 0.1, 0, 20, "%.1f") then hud.border[mid] = border[0] end 
					imgui.PopItemWidth()
				elseif mid == 7 then 
					imgui.PushItemWidth(50)
					spc = new.float[1](hud.spacing) 
					if imgui.DragFloat(u8"Spacing", spc, 0.1, -100, 100, "%.1f") then hud.spacing = spc[0] end 
					imgui.PopItemWidth()
				end
				
				imgui.SameLine()
				imgui.PushItemWidth(95)
				if imgui.BeginCombo("##1", (hud.pos[hud.move[mid][1]] ~= nil and hud.pos[hud.move[mid][1]].name or hud.pos[1].name)) then
					for i = 1, #hud.pos do
						if imgui.Selectable(hud.pos[i].name..'##'..i, hud.move[mid][1] == i) then
							hud.move[mid][1] = i
						end
					end
					imgui.EndCombo()
				end
				imgui.PopItemWidth()
				
				font_gui('Text:', mid, 2, 1, 1, 2, 2, 1, 1, 2) 
				if mid == 6 then 
					font_gui('Name:', mid, 3, 2, 2, 3, 3, 2, 2, 3) 
				end
			imgui.EndChild()
		elseif mid == 8 then
			imgui.BeginChild("##bgTwo", imgui.ImVec2(345, 190), false)
				for i = 1, 11 do 
					font_gui(assets.fnames[i]..':', mid, i, i, i, i, i, i, i, i)
					if imgui.Checkbox(assets.fnames[i]..'##'..i, new.bool(hud.tog[mid][i][1])) then hud.tog[mid][i][1] = not hud.tog[mid][i][1] end 
					if i == 2 then
						imgui.SameLine()
						if imgui.Checkbox(hud.tog[mid][2][2] and '12 Hour' or '24 Hour', new.bool(hud.tog[mid][2][2])) then  hud.tog[mid][2][2] = not hud.tog[mid][2][2] end 
					elseif i == 4 then
						imgui.SameLine()
						if imgui.Checkbox('(Ping:)', new.bool(hud.tog[mid][4][2])) then hud.tog[mid][4][2] = not hud.tog[mid][4][2] end 
					elseif i == 5 then
						imgui.SameLine()
						if imgui.Checkbox('(FPS:)', new.bool(hud.tog[mid][5][2])) then hud.tog[mid][5][2] = not hud.tog[mid][5][2] end 
							
					elseif i == 6 then
						imgui.SameLine()
						if imgui.Checkbox(hud.tog[8][6][2] and 'Camera' or 'Heading', new.bool(hud.tog[mid][6][2])) then hud.tog[mid][6][2] = not hud.tog[mid][6][2] end 	
					end
				end
			imgui.EndChild()
		elseif mid == 9 then	
			imgui.BeginChild("##bgTwo", imgui.ImVec2(345, 140), false)
				imgui.PushItemWidth(115) 
				color = new.float[3](hex2rgb(hud.radar.color))
				if imgui.ColorEdit3('##color', color, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.radar.color = join_argb(255, color[0] * 255, color[1] * 255, color[2] * 255) 
				end
				imgui.SameLine() 
				imgui.Text(u8'Radar Color') 
				imgui.PopItemWidth()
				imgui.SameLine() 
				if imgui.Checkbox('Compass', new.bool(hud.radar.compass)) then 
					if hud.radar.compass then
						for i = 1, 4 do
							removeBlip(assets.compass[i])
						end
						hud.radar.compass = false
					else
						assets.compass[1] = addSpriteBlipForCoord(0.0, 999999.0, 23.0, 24) --  N
						assets.compass[2] = addSpriteBlipForCoord(999999.0, 0.0, 23.0, 34) -- S
						assets.compass[3] = addSpriteBlipForCoord(-999999.0, 0.0, 23.0, 46) -- W
						assets.compass[4] = addSpriteBlipForCoord(0.0, -999999.0, 23.0, 38) -- E
						hud.radar.compass = true
					end
				end
					
				imgui.NewLine() 
				imgui.SameLine(3) 
				imgui.Text(u8'Left/Right') 
				imgui.SameLine(90) 
				imgui.Text(u8'Up/Down') 
				imgui.SameLine(180) 
				imgui.Text(u8'Width') 
				imgui.SameLine(250) 
				imgui.Text(u8'Height') 
			
				imgui.PushItemWidth(160) 
				local radarpos = new.float[2](hud.radar.pos[1], hud.radar.pos[2])
				if imgui.DragFloat2('##move2', radarpos, 0.1, 20 * -2000.0, 20 * 2000.0, "%.1f") then 
					hud.radar.pos[1] = radarpos[0] 
					hud.radar.pos[2] = radarpos[1] 
				end 
				imgui.SameLine()
				local radarsize = new.float[2](hud.radar.size[1], hud.radar.size[2])
				if imgui.DragFloat2('##move3', radarsize, 0.1, 20 * -2000.0, 20 * 2000.0, "%.1f") then 
					hud.radar.size[1] = radarsize[0] 
					hud.radar.size[2] = radarsize[1] 
				end 
				imgui.PopItemWidth()
			
				imgui.NewLine() 
				imgui.SameLine(3) 
				imgui.Text(u8'HZG Settings:') 
					
				if imgui.Checkbox('Turf', new.bool(hud.hzgsettings.turf)) then 
					hud.hzgsettings.turf = not hud.hzgsettings.turf
					for i = 1, 3000 do
						if sampTextdrawIsExists(i) then
							local posX, posY = sampTextdrawGetPos(i)					
							local _, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(i)
							local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
							local text = sampTextdrawGetString (i)
							if posX == 86 and sizeX == 1280 and sizeY == 1280 then
								if hud.hzgsettings.turf then
									sampTextdrawSetLetterSizeAndColor (i, 0.23999999463558, 1.2000000476837, color)
								else
									sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
								end
							end
							
							if text == 'TURF OWNER:' then -- activates with above (check if on/off)
								if hud.hzgsettings.turfowner then
									sampTextdrawSetLetterSizeAndColor (i, 0.23999999463558, 1.2000000476837, color)
								else
									sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
								end
							end
							
						end
					end		
				end
				imgui.SameLine() 
				if imgui.Checkbox('WW', new.bool(hud.hzgsettings.wristwatch)) then 
					hud.hzgsettings.wristwatch = not hud.hzgsettings.wristwatch
					for i = 1, 3000 do
						if sampTextdrawIsExists(i) then
							local posX, posY = sampTextdrawGetPos(i)
							local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
							if posX == 577 and posY == 24 then
								if hud.hzgsettings.wristwatch then
									sampTextdrawSetLetterSizeAndColor (i, 0.5, 2, color)
								else
									sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
								end
							end
						end
					end
				end
				imgui.SameLine() 
				if imgui.Checkbox('HZG Logo', new.bool(hud.hzgsettings.hzglogo)) then 
					hud.hzgsettings.hzglogo = not hud.hzgsettings.hzglogo
					for i = 1, 3000 do
						if sampTextdrawIsExists(i) then
							local text = sampTextdrawGetString(i)
							local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
							if text == 'hzgaming.net' then
								if hud.hzgsettings.hzglogo then
									sampTextdrawSetLetterSizeAndColor (i, 0.3199990093708, 1.3999999761581, color)
								else
									sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
								end
							end
						end
					end
				end
				imgui.SameLine() 
				if imgui.Checkbox('Turf Owner', new.bool(hud.hzgsettings.turfowner)) then 
					hud.hzgsettings.turfowner = not hud.hzgsettings.turfowner
					for i = 1, 3000 do
						if sampTextdrawIsExists(i) then
							local text = sampTextdrawGetString (i)
							local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
							if text == 'TURF OWNER:' then
								if hud.hzgsettings.turfowner then
									sampTextdrawSetLetterSizeAndColor (i, 0.23999999463558, 1.2000000476837, color)
								else
									sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
								end
							end
						end
					end
				end
			imgui.EndChild()
		elseif mid == 10 then
			imgui.BeginChild("##bgTwo", imgui.ImVec2(345, 140), false)
				for k, v in ipairs(hud.pos) do
					imgui.PushItemWidth(95) 
					text = new.char[30](v.name)
					if imgui.InputText('##input'..k, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
						v.name = u8:decode(str(text))
					end
					imgui.PopItemWidth()
						
						
					imgui.SameLine()
					
					imgui.PushItemWidth(110)
					local pos = new.float[2](v.x, v.y)
					if imgui.DragFloat2('##'..k, pos, 0.1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
						v.x = pos[0] 
						v.y = pos[1] 
					end 
					imgui.PopItemWidth()
					
					imgui.SameLine()
					if imgui.Button(v.move and u8"Undo##"..k or u8"Move##"..k) then
						v.move = not v.move
						if v.move then
							sampAddChatMessage(string.format('%s: Press {FF0000}%s {FFFFFF}to save the pos.', script.this.name, vk.id_to_name(VK_LBUTTON)), -1) 
							assets.temp_pos.x = v.x
							assets.temp_pos.y = v.y
							if debug_tog then
								print(assets.temp_pos.x.. assets.temp_pos.y)
							end
							move = true
						else
							v.x = assets.temp_pos.x
							v.y = assets.temp_pos.y
							if debug_tog then
								print(assets.temp_pos.x.. assets.temp_pos.y)
							end
							move = false
						end
					end
					
					imgui.SameLine()
					if k ~= 1 then
						if imgui.Button(u8"x##"..k) then
							if debug_tog then
								print('k')
							end
							table.remove(hud.pos, k)
						end
					else
						if imgui.Button(u8"+") then
							hud.pos[#hud.pos + 1] = {
								x = 500,
								y = 500,
								name = 'new',
								move = false
							}
							for k, v in ipairs(hud.pos) do
								local id = table.maxn(hud.pos)
								if k == id then
									if debug_tog then
										print(k..' - '..table.maxn(hud.pos))
									end
								end
							end
						end
					end
				end
			imgui.EndChild()
		end
	imgui.End()
end)

function update_script()
	update_text = https.request(update_url)
	update_version = update_text:match("version: (.+)")
	if tonumber(update_version) > script_version then
		sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} New version found! The update is in progress..", script.this.name), -1)
		downloadUrlToFile(script_url, script_path, function(id, status)
			if status == dlstatus.STATUS_ENDDOWNLOADDATA then
				sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} The update was successful!", script.this.name), -1)
				blankIni()
				update = true
			end
		end)
	end
end

function icons_script()
	for i = 0, 48 do
		if not doesFileExist(iconspath .. i..'.png') then
			downloadUrlToFile(icons_url .. i..'.png', iconspath .. i..'.png', function(id, status)
				if status == dlstatus.STATUS_ENDDOWNLOADDATA then
					print(i..'.png' .. ' Downloaded')
				end
			end)
		end
	end
end

function main() 
	blank = table.deepcopy(hud)
	if not doesDirectoryExist(path) then createDirectory(path) end
	if doesFileExist(cfg) then loadIni() else blankIni() end
	
	createfonts()
	icons_script()
	displayHud(false) 
	for i = 0, 48 do assets.wid[i] = renderLoadTextureFromFile(iconspath..i..'.png') end 

	repeat wait(0) until isSampAvailable()
	
	if hud.autoupdate then
		update_script()
	end

	if hud.radar.compass then
		assets.compass[1] = addSpriteBlipForCoord(0.0, 999999.0, 23.0, 24) --  N
		assets.compass[2] = addSpriteBlipForCoord(999999.0, 0.0, 23.0, 34) -- S
		assets.compass[3] = addSpriteBlipForCoord(-999999.0, 0.0, 23.0, 46) -- W
		assets.compass[4] = addSpriteBlipForCoord(0.0, -999999.0, 23.0, 38) -- E
	end

	sampRegisterChatCommand("hud", function() menu[0] = not menu[0] end)
	sampfuncsLog("(Hud: /hud)")
	
	setmaxhp()
	hztextdraws()
	
	lua_thread.create(function() 
		while true do wait(1000) 
			fps = fps_counter 
			fps_counter = 0 
		end 
	end)
	
	lua_thread.create(function()
		while true do wait(15)
			_, id = sampGetPlayerIdByCharHandle(ped)
			local hp, weap, color, vehhp, turfname, localtime, servertime, speed, carName, badge = sampGetPlayerHealth(id), getCurrentCharWeapon(ped), sampGetPlayerColor(id), 0, '', '', '', '', '', ''

			for k, v in pairs(hud.serverhp) do if hp >= v then hp = hp - v end end 
			
			if isCharInAnyCar(ped) then 
				local vehid = storeCarCharIsInNoSave(ped) 
				local model = getCarModel(vehid)
				vehhp = getCarHealth(vehid) 
				if has_value(assets.vehid, getCarModel(vehid)) and hud.tog[4][4] then 
					hud.maxvalue[4] = 2500 
				else 
					hud.maxvalue[4] = 1000 
				end
				carName = getVehicleName(model)
				speed = math.ceil(getCarSpeed(vehid)*2.98) .." MPH"
			end
			
			showfps = (hud.tog[8][5][2] and 'FPS: ' or '')..fps
			localtime = os.date(hud.tog[8][2][2] and '%I:%M:%S'or '%H:%M:%S')
			
			local r, g, b = hex2rgb(color)
			color = join_argb_int(255, r, g, b)
			for k, v in pairs(assets.badge) do 
				if color == v[1] then 
					hud.color[8][11] = v[1]
					badge = v[2]
				end 
			end
			
			for i = 1, 3000 do
				if sampTextdrawIsExists(i) then
					local posX, posY = sampTextdrawGetPos(i)					
					local _, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(i)
					if posX == 577 and posY == 24 then
						servertime = sampTextdrawGetString(i)
					elseif posX == 86 and sizeX == 1280 and sizeY == 1280 then
						turfname = sampTextdrawGetString(i)
						local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
						hud.color[8][8] = color
					end
				end
			end
			
			if menu[0] then 
				value = {{100},{50},{100},{1000},{100},{24,formatammo(50000,7),'Desert Eagle'},{6,formatmoney(1000000)},{'Player_Name', 'Local-Time', 'Server-Time', 'Ping', showfps, 'Direction', 'Location', 'Turf', 'Vehicle Speed', 'Vehicle Name', 'Badge'}}
			else 
				if spec.state and spec.playerid ~= -1 and sampIsPlayerConnected(spec.playerid) then
					res, pid = sampGetCharHandleBySampPlayerId (spec.playerid)
					if res then
						local vehhp, weap, color, speed, carName, badge = 0, getCurrentCharWeapon(pid), sampGetPlayerColor(spec.playerid), '', '', ''
						if isCharInAnyCar(pid) then 
							local vehid = storeCarCharIsInNoSave(pid) 
							local model = getCarModel(vehid)
							vehhp = getCarHealth(vehid) 
							if has_value(assets.vehid, getCarModel(vehid)) and hud.tog[4][4] then 
								hud.maxvalue[4] = 2500 
							else 
								hud.maxvalue[4] = 1000 
							end
							carName = getVehicleName(model)
							speed = math.ceil(getCarSpeed(vehid)*2.98) .." MPH"
						end
						
						local r, g, b = hex2rgb(color)
						color = join_argb_int(255, r, g, b)
						for k, v in pairs(assets.badge) do 
							if color == v[1] then 
								hud.color[8][11] = v[1]
								badge = v[2]
							end 
						end
						
						value = {
							{sampGetPlayerHealth(spec.playerid)},
							{sampGetPlayerArmor(spec.playerid)},
							{0},
							{vehhp},
							{0},
							{weap, formatammo(getAmmoInCharWeapon(pid, weap), getAmmoInClip(pid, weap)),weapons.names[weap]},
							{0,''},
							{
								string.format("%s (%d)", sampGetPlayerNickname(spec.playerid), spec.playerid),
								localtime,
								servertime,
								(hud.tog[8][4][2] and 'Ping: ' or '')..sampGetPlayerPing(spec.playerid),
								showfps,
								getdirection(pid),
								getPlayerZoneName(), 
								turfname, 
								speed,
								carName,
								badge
							}
						}
					end	
				else
					value = {
						{hp},
						{sampGetPlayerArmor(id)},
						{getSprintLevel()},
						{vehhp},
						{getWaterLevel()},
						{
							weap,
							formatammo(
								getAmmoInCharWeapon(ped, weap), 
								getAmmoInClip(ped, weap)
							),
							weapons.names[weap]
						},
						{
							getWantedLevel(),
							formatmoney(getPlayerMoney(h))
						},
						{
							string.format("%s (%d)", sampGetPlayerNickname(id), id),
							localtime,
							servertime,
							(hud.tog[8][4][2] and 'Ping: ' or '')..sampGetPlayerPing(id),
							showfps,
							getdirection(ped),
							getPlayerZoneName(), 
							turfname, 
							speed, 
							carName, 
							badge
						}
					}
				end
			end
		end
	end)
	
	while true do wait(1)		
		hudmove()
		changeRadarPosAndSize(hud.radar.pos[1], hud.radar.pos[2], hud.radar.size[1], hud.radar.size[2])
        changeRadarColor(hud.radar.color)
	end
end

function onWindowMessage(msg, wparam, lparam)
    if wparam == VK_ESCAPE and menu[0] then
        if msg == wm.WM_KEYDOWN then
            consumeWindowMessage(true, false)
        end
        if msg == wm.WM_KEYUP then
            menu[0] = false
        end
    end
end

function onD3DPresent()	
	fps_counter = fps_counter + 1
	if not isPauseMenuActive() and not sampIsScoreboardOpen() and sampGetChatDisplayMode() > 0 and not isKeyDown(VK_F10) and hud.toggle then 
		for i = 1, 8 do
			if i == 1 or i == 2 and (value[i][1] > 0 or hud.tog[i][3]) or i == 3 or i == 4 and (menu[0] or isCharInAnyCar(ped) or hud.tog[i][3] or spec.state) or i == 5 and (menu[0] or isCharInWater(ped) or hud.tog[i][3]) then
				if hud.tog[i][1] then 
					renderbar(
						i,
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1], 
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1], 
						hud.sizex[i], 
						hud.sizey[i], 
						value[i][1], 
						hud.maxvalue[i], 
						hud.border[i], 
						hud.color[i][1][1], 
						hud.color[i][1][2],
						hud.color[i][1][3]
					) 
				end
				if hud.tog[i][2] then 
					renderfont(
						i,
						2,
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2], 
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2], 
						assets.fid[i][1], 
						value[i][1], 
						hud.alignfont[i][1], 
						hud.color[i][2]
					) 
				end
			elseif i == 6 then
				if hud.tog[i][1] then 
					renderweap(
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1], 
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1], 
						hud.sizex[i], 
						hud.sizey[i], 
						value[i][1], 
						hud.color[i][1][1], 
						hud.color[i][1][2]
					) 
				end
				if hud.tog[i][2] and value[i][1] ~= 0 then 
					renderfont(
						i,
						2,
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2], 
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2],   
						assets.fid[i][1], 
						value[i][2], 
						hud.alignfont[i][1], 
						hud.color[i][2]
					)
				end
				if hud.tog[i][3] then 
					renderfont(
						i,
						3,
						(hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].x or hud.pos[1].x) + hud.offx[i][3], 
						(hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].y or hud.pos[1].y) + hud.offy[i][3], 
						assets.fid[i][2], 
						value[i][3], 
						hud.alignfont[i][2], 
						hud.color[i][3]
					) 
				end
			elseif i == 7 then
				if hud.tog[i][1] then 
					renderstar(
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1], 
						(hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1], 
						hud.sizex[i], 
						hud.sizey[i], 
						value[i][1], 
						hud.spacing, 
						hud.color[i][1][1]
					)
				end
				if hud.tog[i][2] then 
					renderfont(
						i,
						2,
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2],
						(hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2],
						assets.fid[i][1], 
						value[i][2], 
						hud.alignfont[i][1],
						hud.color[i][2]
					) 
				end
			elseif i == 8 then			
				for v = 1, 11 do
					if hud.tog[i][v][1] then 
						renderfont(
							i,
							v,
							(hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].x or hud.pos[1].x) + hud.offx[i][v], 
							(hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].y or hud.pos[1].y) + hud.offy[i][v], 
							assets.fid[i][v], 
							value[i][v], 
							hud.alignfont[i][v], 
							hud.color[i][v]
						)
					end
				end
			end
		end
	end
end

function sampev.onTogglePlayerSpectating(state)
    if not state then
        spec.playerid = -1
    end
    spec.state = state
end

function sampev.onSendCommand(command)
	if string.find(command, '/spec') and command ~= '/spec' then
		cmd = split(command, " ")
		
		if cmd[2] ~= nil then
		
			if cmd[2]:find('^%d+') then
				spec.playerid = tonumber(cmd[2])
			else
				local result, playerid, name = getTarget(cmd[2])
				if result then
					spec.playerid = playerid
				end
			end
		end
	end
end


function sampev.onShowTextDraw(id, data)
	if debug_tog then
		print(string.format("ID:%d - X:%f Y:%f - Text:%s", id, data.position.x, data.position.y, data.text))
		print(id..'#lineHeight '..data.text..' | '..data.lineHeight)
		print(id..'#lineWidth '..data.text..' | '..data.lineWidth)
		print(id..'#flags '..data.text..' | '..data.flags)
		print(id..'#letterColor '..data.text..' | '..data.letterColor)
		print(id..'#boxColor '..data.text..' | '..data.boxColor)
		print(id..'#shadow '..data.text..' | '..data.shadow)
		print(id..'#backgroundColor '..data.text..' | '..data.backgroundColor)
		print(id..'#style '..data.text..' | '..data.style)
		print(id..'#modelId '..data.text..' | '..data.modelId)
		print(id..'#zoom '..data.text..' | '..data.zoom)
	end
	
	if data.position.x == 86 and data.lineHeight == 1280 and data.lineWidth == 1280 and not hud.hzgsettings.turf then -- hz turf
		data.letterWidth = 0
		data.letterHeight = 0
		return {id, data}
	end
	
	if data.position.x == 577 and data.position.y == 24 and not hud.hzgsettings.wristwatch then -- hz ww
		data.letterWidth = 0
		data.letterHeight = 0
		return {id, data}
	end
	
	if data.text == 'hzgaming.net' and not hud.hzgsettings.hzglogo then 
		data.letterWidth = 0
		data.letterHeight = 0
		return {id, data}
	end
	
	if data.text == 'TURF OWNER:' and not hud.hzgsettings.turfowner then 
		data.letterWidth = 0
		data.letterHeight = 0
		return {id, data}
	end
	
	if math.floor(data.position.x) == 610 and math.floor(data.position.y) == 68 and data.boxColor == -16777216 then 
		data.flags = 0
		return {id, data}
	end
	
	if math.floor(data.position.x) == 608 and math.floor(data.position.y) == 70 and data.boxColor == -15725478 then 
		data.flags = 0
		return {id, data}
	end
	
	if math.floor(data.position.x) <= 608 and math.floor(data.position.y) == 70 and data.boxColor == -14608203 then 
		data.flags = 0
		return {id, data}
	end
end

function onScriptTerminate(scr, quitGame) 
	if scr == script.this then 
		for i = 1, 4 do
			removeBlip(assets.compass[i])
		end
		showCursor(false) 
		if hud.autosave then saveIni() end 
	end
end

function blankIni()	
	hud = table.deepcopy(blank)
	saveIni()
	loadIni()
end

function loadIni() 
	local f = io.open(cfg, "r") 
	if f then 
		hud = decodeJson(f:read("*all")) 
		f:close() 
	end
end

function saveIni() 
	if type(hud) == "table" then 
		local f = io.open(cfg, "w") 
		f:close() 
		if f then 
			local f = io.open(cfg, "r+") 
			f:write(encodeJson(hud,true)) 
			f:close() 
		end 
	end 
end

function hudmove()
	if menu[0] then 
		x, y = getCursorPos()
		if move then	
			for k, v in ipairs(hud.pos) do
				if v.move then
					if isKeyJustPressed(VK_LBUTTON) then 
						move = false
						v.move = false 
					else 
						v.x = x 
						v.y = y
					end
				end
			end
		else	
			for i = 1, 8 do
				if i >= 1 and i <= 5 then
					width_text, height_text = renderGetFontDrawTextLength(assets.fid[i][1], value[i][1]), renderGetFontDrawHeight (assets.fid[i][1])
					if x >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][1], hud.alignfont[i][1]) and 
					   x <= ((hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][1], hud.alignfont[i][1])) + width_text and 
					   y >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] and 
					   y <= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] + height_text then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][2] = true end
					end
					if selected[i][2] then
						if wasKeyReleased(VK_LBUTTON) then
							inuse = false selected[i][2] = false
						else
							hud.offx[i][2] = x - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + (aligntext(assets.fid[i][1], value[i][1], hud.alignfont[i][1]) - width_text / 2)
							hud.offy[i][2] = y - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) - (height_text / 2)
						end
					end
						
					if x >= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] + hud.border[i] and 
					   x <= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] + hud.sizex[i] - hud.border[i] and 
					   y >= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] + hud.border[i] and 
					   y <= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] + hud.sizey[i] - hud.border[i] then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][1] = true end
					end
					if selected[i][1] then
						if wasKeyReleased(VK_LBUTTON) then 
							inuse = false selected[i][1] = false 
						else 
							hud.offx[i][1] = x - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) - (hud.sizex[i] / 2)
							hud.offy[i][1] = y - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) - (hud.sizey[i] / 2)
						end
					end
				elseif i == 6 then
					width_clip, height_clip = renderGetFontDrawTextLength(assets.fid[i][1], value[i][2]), renderGetFontDrawHeight (assets.fid[i][1])
					if x >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1]) and 
					   x <= ((hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1])) + width_clip and 
					   y >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] and 
					   y <= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] + height_clip then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][2] = true end
					end
					if selected[i][2] then
						if wasKeyReleased(VK_LBUTTON) then
							inuse = false selected[i][2] = false
						else
							hud.offx[i][2] = x - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + (aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1]) - width_clip / 2) + 1 
							hud.offy[i][2] = y - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) - (height_clip / 2) + 1
						end
					end
					width_weapname, height_weapname =  renderGetFontDrawTextLength(assets.fid[i][2], value[i][3]), renderGetFontDrawHeight (assets.fid[i][2])
					if x >= (hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].x or hud.pos[1].x) + hud.offx[i][3] - aligntext(assets.fid[i][2], value[i][3], hud.alignfont[i][2]) and 
					   x <= ((hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].x or hud.pos[1].x) + hud.offx[i][3] - aligntext(assets.fid[i][2], value[i][3], hud.alignfont[i][2])) + width_weapname and 
					   y >= (hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].y or hud.pos[1].y) + hud.offy[i][3] and 
					   y <= (hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].y or hud.pos[1].y) + hud.offy[i][3] + height_weapname then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][3] = true end
					end
					if selected[i][3] then
						if wasKeyReleased(VK_LBUTTON) then
							inuse = false selected[i][3] = false
						else
							hud.offx[i][3] = x - (hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].x or hud.pos[1].x) + (aligntext(assets.fid[i][2], value[i][3], hud.alignfont[i][2]) - width_weapname / 2) + 1 
							hud.offy[i][3] = y - (hud.pos[hud.move[i][3]] ~= nil and hud.pos[hud.move[i][3]].y or hud.pos[1].y) - (height_weapname / 2) + 1
						end
					end
					if x >= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] and 
					   x <= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] + hud.sizex[i] and 
					   y >= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] and 
					   y <= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] + hud.sizey[i] then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][1] = true end
					end
					if selected[i][1] then
						if wasKeyReleased(VK_LBUTTON) then
							inuse = false selected[i][1] = false
						else
							hud.offx[i][1] = x - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) - (hud.sizex[i] / 2) + 1
							hud.offy[i][1] = y - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) - (hud.sizey[i] / 2) + 1
						end
					end
				elseif i == 7 then
					width_money, height_money = renderGetFontDrawTextLength(assets.fid[i][1], value[i][2]), renderGetFontDrawHeight (assets.fid[i][1])
					if x >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1]) and 
					   x <= ((hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + hud.offx[i][2] - aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1])) + width_money and 
					   y >= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] and 
					   y <= (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) + hud.offy[i][2] + height_money then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][2] = true end
					end
					if selected[i][2] then
						if wasKeyReleased(VK_LBUTTON) then
							inuse = false selected[i][2] = false
						else
							hud.offx[i][2] = x - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].x or hud.pos[1].x) + (aligntext(assets.fid[i][1], value[i][2], hud.alignfont[i][1]) - width_money / 2) + 1 
							hud.offy[i][2] = y - (hud.pos[hud.move[i][2]] ~= nil and hud.pos[hud.move[i][2]].y or hud.pos[1].y) - (height_money / 2) + 1
						end
					end
					if x >= hud.sizex[i] + (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] and 
					   x <= hud.sizex[i] + (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) + hud.offx[i][1] + (hud.sizex[i] + hud.spacing) * value[i][1] and 
					   y >= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] and 
					   y <= (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) + hud.offy[i][1] + hud.sizey[i] then
						if isKeyJustPressed(VK_LBUTTON) and not inuse then 
							inuse = true 
							selected[i][1] = true 
						end
					end
					if selected[i][1] then
						if wasKeyReleased(VK_LBUTTON) then
						inuse = false selected[i][1] = false
						else
							hud.offx[i][1] = x - hud.sizex[i] - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].x or hud.pos[1].x) - (hud.sizex[i] / 2) * value[i][1] + 1 
							hud.offy[i][1] = y - (hud.pos[hud.move[i][1]] ~= nil and hud.pos[hud.move[i][1]].y or hud.pos[1].y) - (hud.sizey[i] / 2) + 1
						end
					end
				elseif i == 8 then
					for v = 1, 11 do
						width, height = renderGetFontDrawTextLength(assets.fid[i][v], value[i][v]), renderGetFontDrawHeight (assets.fid[i][v])
						if x >= (hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].x or hud.pos[1].x) + hud.offx[i][v] - aligntext(assets.fid[i][v], value[i][v], hud.alignfont[i][v]) and 
						   x <= ((hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].x or hud.pos[1].x) + hud.offx[i][v] - aligntext(assets.fid[i][v], value[i][v], hud.alignfont[i][v])) + width and 
						   y >= (hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].y or hud.pos[1].y) + hud.offy[i][v] and 
						   y <= (hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].y or hud.pos[1].y) + hud.offy[i][v] + height then
							if isKeyJustPressed(VK_LBUTTON) and not inuse then inuse = true selected[i][v] = true end
						end
						if selected[i][v] then
							if wasKeyReleased(VK_LBUTTON) then
								inuse = false selected[i][v] = false
							else
								hud.offx[i][v] = x - (hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].x or hud.pos[1].x) + (aligntext(assets.fid[i][v], value[i][v], hud.alignfont[i][v]) - width / 2) + 1 
								hud.offy[i][v] = y - (hud.pos[hud.move[i][v]] ~= nil and hud.pos[hud.move[i][v]].y or hud.pos[1].y) - (height / 2) + 1
							end
						end
					end
				end
			end
		end
	end
end

function renderbar(id, x, y, sizex, sizey, value, maxvalue, border, color, color2, color3) 
	if value > maxvalue then
		value = maxvalue
	end
	if id == 4 then
		if value < 700 and value > 400 then
			color = hud.color[id][1][4]
		elseif value < 400 then
			color = hud.color[id][1][5]
		end	
	end
	renderDrawBoxWithBorder(x, y, sizex, sizey, color2, border, color3) 
	renderDrawBox(x + border, y + border, sizex / maxvalue * value - (2 * border), sizey - (2 * border), color)
end

function renderfont(id, id2, x, y, fontid, value, align, color)
	renderFontDrawText(fontid, value, x - aligntext(fontid, value, align), y, color)
end

function renderweap(x, y, sizex, sizey, value, color, color2)
	if hud.tog[6][4] then renderDrawTexture(assets.wid[47], x, y, sizex, sizey, 0, color2) end 
	renderDrawTexture(assets.wid[value], x, y, sizex, sizey, 0, color)
end

function renderstar(x, y, sizex, sizey, value, spacing, color)
	for v = 1, value do 
		renderDrawTexture(assets.wid[48], x + (sizex + spacing) * v, y, sizex, sizey, 0, color) 
	end
end

function createfont(id, slot)
	flags, flagids = {}, {flag.BOLD,flag.ITALICS,flag.BORDER,flag.SHADOW}
	for i = 1, 4 do 
		flags[i] = hud.fontflag[id][slot][i] and flagids[i] or 0 
	end 
	assets.fid[id][slot] = renderCreateFont(hud.font[id][slot], hud.fontsize[id][slot], flags[1] + flags[2] + flags[3] + flags[4])
end

function aligntext(fid, value, align)
	l = renderGetFontDrawTextLength(fid, value) 
	if align == 1 then 
		return l
	elseif align == 2 then 
		return l / 2 
	elseif align == 3 then 
		return 0 
	end
end

function font_gui(title, id, color, fontsize, font, off1, off2, align, fontflag, move)
	imgui.NewLine()	
	imgui.SameLine(4) 
	imgui.Text(title) 
	
	
	imgui.SameLine(140) 
	imgui.Text('Font') 
	
	imgui.SameLine(240) 
	imgui.Text('Group') 
	
	local choices = {'Left', 'Center', 'Right'}
	imgui.PushItemWidth(68)
	if imgui.BeginCombo("##align"..align, choices[hud.alignfont[id][align]]) then
		for i = 1, #choices do
			if imgui.Selectable(choices[i]..'##'..i, hud.alignfont[id][align] == i) then
				hud.alignfont[id][align] = i
			end
		end
		imgui.EndCombo()
	end
	imgui.PopItemWidth()
	
	imgui.SameLine()
	
	
	local choices2 = {'Bold', 'Italics', 'Border', 'Shadow'}
	imgui.PushItemWidth(60)
	if imgui.BeginCombo("##flags"..fontflag, 'Flags') then
		for i = 1, #choices2 do
			if imgui.Checkbox(choices2[i], new.bool(hud.fontflag[id][fontflag][i])) then
				hud.fontflag[id][fontflag][i] = not hud.fontflag[id][fontflag][i] 
				createfont(id, fontflag) 
			end
		end
		imgui.EndCombo()
	end
	imgui.PopItemWidth()
	
	imgui.SameLine()
	imgui.PushItemWidth(95) 
	text = new.char[30](hud.font[id][font])
	if imgui.InputText('##font', text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
		hud.font[id][font] = u8:decode(str(text))
		createfont(id, font) 
	end
	imgui.PopItemWidth()
	
	imgui.SameLine()
	imgui.PushItemWidth(95)
	if imgui.BeginCombo("##group"..move, (hud.pos[hud.move[mid][move]] ~= nil and hud.pos[hud.move[mid][move]].name or hud.pos[1].name)) then
		for i = 1, #hud.pos do
			if imgui.Selectable(hud.pos[i].name..'##'..i, hud.move[mid][move] == i) then
				hud.move[mid][move] = i
			end
		end
		imgui.EndCombo()
	end
	imgui.PopItemWidth()
	
	
	imgui.PushItemWidth(170) 
	font_xy = imgui.new.float[2](hud.offx[id][off1], hud.offy[id][off2])
	if imgui.DragFloat2('##movement_font'..font, font_xy, 0.1, 20 * -2000, 20 * 2000, "%.1f") then 
		hud.offx[id][off1] = font_xy[0] 
		hud.offy[id][off2] = font_xy[1] 
	end
	imgui.PopItemWidth()
	
	imgui.SameLine()
	imgui.BeginGroup()
		fsize = new.int()
		if imgui.Button('+##'..fontsize) and hud.fontsize[id][fontsize] < 72 then 
			hud.fontsize[id][fontsize] = hud.fontsize[id][fontsize] + 1 
			createfont(id, fontsize)
		end
		
		imgui.SameLine()
		imgui.Text(tostring(hud.fontsize[id][fontsize]))
		imgui.SameLine()
		
		if imgui.Button('-##'..fontsize) and hud.fontsize[id][fontsize] > 4 then 
			hud.fontsize[id][fontsize] = hud.fontsize[id][fontsize] - 1 
			createfont(id, fontsize)
		end
	imgui.EndGroup()
	
	imgui.SameLine()	
	imgui.PushItemWidth(95) 
	tcolor = new.float[3](hex2rgb(hud.color[id][color]))
	if imgui.ColorEdit3('##color'..font, tcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
		hud.color[id][color] = join_argb(255, tcolor[0] * 255, tcolor[1] * 255, tcolor[2] * 255) 
	end 
	imgui.PopItemWidth()
	imgui.SameLine()
	imgui.Text('Color')
end


function createfonts()
	for i = 1, 8 do 
		if i >= 1 and i <= 8 then 
			createfont(i, 1) 
			if i == 6 then 
				createfont(i, 2) 
			elseif i == 8 then 
				for v = 2, 11 do 
					createfont(i, v) 
				end 
			end 
		end 
	end
end

function setmaxhp()
	if hud.tog[1][3] then 
		hud.maxvalue[1] = 160 
	else 
		hud.maxvalue[1] = 100 
	end 
end

function hztextdraws()
	for i = 1, 3000 do
		if sampTextdrawIsExists(i) then
			local posX, posY = sampTextdrawGetPos(i)	
			local _, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(i)
			local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
			local text = sampTextdrawGetString(i)
			if posX == 86 and sizeX == 1280 and sizeY == 1280 then
				if hud.hzgsettings.turf then
					sampTextdrawSetLetterSizeAndColor(i, 0.23999999463558, 1.2000000476837, color)
				else
					sampTextdrawSetLetterSizeAndColor(i, 0, 0, color)
				end
			end
			if posX == 577 and posY == 24 then
				if hud.hzgsettings.wristwatch then
					sampTextdrawSetLetterSizeAndColor (i, 0.5, 2, color)
				else
					sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
				end
			end
			if text == 'hzgaming.net' then
				if hud.hzgsettings.hzglogo then
					sampTextdrawSetLetterSizeAndColor (i, 0.3199990093708, 1.3999999761581, color)
				else
					sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
				end
			end
			if text == 'TURF OWNER:' then
				if hud.hzgsettings.turfowner then
					sampTextdrawSetLetterSizeAndColor (i, 0.23999999463558, 1.2000000476837, color)
				else	
					sampTextdrawSetLetterSizeAndColor (i, 0, 0, color)
				end
			end
		end
	end
end

function formatmoney(n)
	return (hud.tog[7][3] and '$' or '')..(hud.tog[7][4] and formatNumber(n) or n)
end

function formatammo(ammo, clip)
	return hud.tog[6][5] and ammo - clip..'-'..clip or clip
end 

function getSprintLevel() 
	return math.floor(mem.getfloat(0xB7CDB4) / 31.47000244) 
end

function getWaterLevel() 
	return math.floor(mem.getfloat(0xB7CDE0) / 39.97000244) 
end

function getAmmoInClip(playerid, weapon) 
	return mem.getint32(getCharPointer(playerid) + 0x5A0 + getWeapontypeSlot(weapon) * 0x1C + 0x8) 
end

function getWantedLevel() 
	return mem.getuint8(0x58DB60) 
end

function formatNumber(n)
    n = tostring(n)
    return n:reverse():gsub("...","%0,",math.floor((#n-1)/3)):reverse()
end

function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function hex2rgba(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r / 255, g / 255, b / 255, a / 255
end

function hex2rgba_int(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r, g, b, a
end

function hex2rgb(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r / 255, g / 255, b / 255
end

function hex2rgb_int(rgba)
	local a = bit.band(bit.rshift(rgba, 24),	0xFF)
	local r = bit.band(bit.rshift(rgba, 16),	0xFF)
	local g = bit.band(bit.rshift(rgba, 8),		0xFF)
	local b = bit.band(rgba, 0xFF)
	return r, g, b
end

function join_argb(a, r, g, b)
	local argb = b  -- b
	argb = bit.bor(argb, bit.lshift(g, 8))  -- g
	argb = bit.bor(argb, bit.lshift(r, 16)) -- r
	argb = bit.bor(argb, bit.lshift(a, 24)) -- a
	return argb
end

function join_argb_int(a, r, g, b)
	local argb = b * 255
    argb = bit.bor(argb, bit.lshift(g * 255, 8))
    argb = bit.bor(argb, bit.lshift(r * 255, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function changeRadarPosAndSize(posX, posY, sizeX, sizeY)
	if getMoonloaderVersion() >= 27 then
		local radarX = ffi.cast('float*', ffi.C.malloc(4))
		local radarY = ffi.cast('float*', ffi.C.malloc(4))
		local radarWidth = ffi.cast('float*', ffi.C.malloc(4))
		local radarHeight = ffi.cast('float*', ffi.C.malloc(4))
		radarWidth[0] = sizeX
		radarHeight[0] = sizeY
		radarX[0] = posX
		radarY[0] = posY
		ffi.cast('float**', 0x58A79B)[0] = radarX
		ffi.cast('float**', 0x5834D4)[0] = radarX
		ffi.cast('float**', 0x58A836)[0] = radarX
		ffi.cast('float**', 0x58A8E9)[0] = radarX
		ffi.cast('float**', 0x58A98A)[0] = radarX
		ffi.cast('float**', 0x58A469)[0] = radarX
		ffi.cast('float**', 0x58A5E2)[0] = radarX
		ffi.cast('float**', 0x58A6E6)[0] = radarX
		ffi.cast('float**', 0x58A7C7)[0] = radarY
		ffi.cast('float**', 0x58A868)[0] = radarY
		ffi.cast('float**', 0x58A913)[0] = radarY
		ffi.cast('float**', 0x58A9C7)[0] = radarY
		ffi.cast('float**', 0x583500)[0] = radarY
		ffi.cast('float**', 0x58A499)[0] = radarY
		ffi.cast('float**', 0x58A60E)[0] = radarY
		ffi.cast('float**', 0x58A71E)[0] = radarY
		ffi.cast('float**', 0x58A47D)[0] = radarHeight
		ffi.cast('float**', 0x58A632)[0] = radarHeight 
		ffi.cast('float**', 0x58A6AB)[0] = radarHeight 
		ffi.cast('float**', 0x58A70E)[0] = radarHeight 
		ffi.cast('float**', 0x58A801)[0] = radarHeight 
		ffi.cast('float**', 0x58A8AB)[0] = radarHeight 
		ffi.cast('float**', 0x58A921)[0] = radarHeight 
		ffi.cast('float**', 0x58A9D5)[0] = radarHeight 
		ffi.cast('float**', 0x5834F6)[0] = radarHeight 
		ffi.cast('float**', 0x5834C2)[0] = radarWidth
		ffi.cast('float**', 0x58A449)[0] = radarWidth 
		ffi.cast('float**', 0x58A7E9)[0] = radarWidth 
		ffi.cast('float**', 0x58A840)[0] = radarWidth 
		ffi.cast('float**', 0x58A943)[0] = radarWidth 
		ffi.cast('float**', 0x58A99D)[0] = radarWidth 
	end
end

function changeRadarColor(color)
	local r, g, b, a = hex2rgba_int(color)
    mem.write(0x58A798, r, 1, true)
    mem.write(0x58A89A, r, 1, true)
    mem.write(0x58A8EE, r, 1, true)
    mem.write(0x58A9A2, r, 1, true)
    mem.write(0x58A790, g, 1, true)
    mem.write(0x58A896, g, 1, true)
    mem.write(0x58A8E6, g, 1, true)
    mem.write(0x58A99A, g, 1, true)
    mem.write(0x58A78E, b, 1, true)
    mem.write(0x58A894, b, 1, true)
    mem.write(0x58A8DE, b, 1, true)
    mem.write(0x58A996, b, 1, true)
    mem.write(0x58A789, a, 1, true)
    mem.write(0x58A88F, a, 1, true)
    mem.write(0x58A8D9, a, 1, true)
    mem.write(0x58A98F, a, 1, true)
end

function getdirection(id) -- fix
	local angel = 0
	if spec.state and spec.playerid ~= -1 then
		angel = math.floor(getCharHeading(id))
	else
		angel = math.floor(hud.tog[8][6][2] and getCameraZAngle() or getCharHeading(id))
	end
	
	if (angel >= 0 and angel <= 22) or (angel <= 360 and angel >= 330) then return "North"
	elseif (angel >= 293 and angel <= 329) then return "Northeast"
	elseif (angel >= 248 and angel <= 292) then return "East"
	elseif (angel >= 203 and angel <= 247) then return "Southeast"
	elseif (angel >= 158 and angel <= 202) then return "South"
	elseif (angel >= 113 and angel <= 157) then return "Southwest"
	elseif (angel >= 68 and angel <= 112) then return "West"
	elseif (angel >= 23 and angel <= 67) then return "Northwest" end
end

function split(str, delim, plain)
    local tokens, pos, plain = {}, 1, not (plain == false) --[[ delimiter is plain text by default ]]
    repeat
        local npos, epos = string.find(str, delim, pos, plain)
        table.insert(tokens, string.sub(str, pos, npos and npos - 1))
        pos = epos and epos + 1
    until not pos
    return tokens
end

function getCameraZAngle()
	local cx, cy, _ = getActiveCameraCoordinates()
	local tx, ty, _ = getActiveCameraPointAt()
	return getHeadingFromVector2d(tx-cx, ty-cy)
end

function getTarget(str)
	if str ~= nil then
		local maxplayerid, players = sampGetMaxPlayerId(false), {}
		for i = 0, maxplayerid do
			if sampIsPlayerConnected(i) then
				players[i] = sampGetPlayerNickname(i)
			end
		end
		for k, v in pairs(players) do
			if v:lower():find("^"..str:lower()) or string.match(k, str) then 
				target = split((players[k] .. " " .. k), " ")
				return true, target[2]
			elseif k == maxplayerid then
				return false
			end
		end
	end
end

function getVehicleName(model)
	local vehname, vehNames = '', {
		{"Admiral", "ADMIRAL"},
		{"Alpha", "ALPHA"},
		{"Ambulance", "AMBULAN"},
		{"Andromada", "ANDROM"},
		{"ARTICT1", "ARTICT1"},
		{"ARTICT2", "ARTICT2"},
		{"ARTICT3", "ARTICT3"},
		{"AT-400", "AT400"},
		{"BAGBOXA", "BAGBOXA"},
		{"BAGBOXB", "BAGBOXB"},
		{"Baggage", "BAGGAGE"},
		{"Bandito", "BANDITO"},
		{"Banshee", "BANSHEE"},
		{"Barracks", "BARRCKS"},
		{"Beagle", "BEAGLE"},
		{"Benson", "BENSON"},
		{"Berkleys RC Van", "TOPGUN"},
		{"BF Injection", "BFINJC"},
		{"BF-400", "BF400"},
		{"Bike", "BIKE"},
		{"Blade", "BLADE"},
		{"Blista Compact", "BLISTAC"},
		{"Bloodring Banger", "BLOODRA"},
		{"BMX", "BMX"},
		{"Bobcat", "BOBCAT"},
		{"Boxville", "BOXVILL"},
		{"Boxville", "BOXBURG"},
		{"Bravura", "BRAVURA"},
		{"Broadway", "BROADWY"},
		{"Brown Streak", "STREAK"},
		{"Brown Streak", "STREAKC"},
		{"Buccaneer", "BUCCANE"},
		{"Buffalo", "BUFFALO"},
		{"Bullet", "BULLET"},
		{"Burrito", "BURRITO"},
		{"Bus", "BUS"},
		{"Cabbie", "CABBIE"},
		{"Caddy", "CADDY"},
		{"Cadrona", "CADRONA"},
		{"Camper", "CAMPER"},
		{"Cargobob", "CARGOBB"},
		{"Cement Truck", "CEMENT"},
		{"Cheetah", "CHEETAH"},
		{"Clover", "CLOVER"},
		{"Club", "CLUB"},
		{"Coach", "COACH"},
		{"Coastguard", "COASTG"},
		{"Combine Harvester", "COMBINE"},
		{"Comet", "COMET"},
		{"Cropduster", "CROPDST"},
		{"DFT-30", "DFT30"},
		{"Dinghy", "DINGHY"},
		{"Dodo", "DODO"},
		{"Dozer", "DOZER"},
		{"Dumper", "DUMPER"},
		{"Duneride", "DUNE"},
		{"Elegant", "ELEGANT"},
		{"Elegy", "ELEGY"},
		{"Emperor", "EMPEROR"},
		{"Enforcer", "ENFORCR"},
		{"Esperanto", "ESPERAN"},
		{"Euros", "EUROS"},
		{"Faggio", "FAGGIO"},
		{"FARMTR1", "FARMTR1"},
		{"FBI Rancher", "FBIRANC"},
		{"FBI Truck", "FBITRUK"},
		{"FCR-900", "FCR900"},
		{"Feltzer", "FELTZER"},
		{"Fire Truck", "FRETRK"},
		{"Fire Truck", "FIRELA"},
		{"Flash", "FLASH"},
		{"Flatbed", "FLATBED"},
		{"Forklift", "FORKLFT"},
		{"Fortune", "FORTUNE"},
		{"FRBOX", "FRBOX"},
		{"Freeway", "FREEWAY"},
		{"Freight", "FREIGHT"},
		{"Freight", "FRFLAT"},
		{"Glendale", "GLENDAL"},
		{"Glendale Shit", "GLENSHI"},
		{"Greenwood", "GREENWO"},
		{"Hermes", "HERMES"},
		{"Hotdog", "HOTDOG"},
		{"Hotknife", "HOTKNIF"},
		{"Hotring Racer", "HOTRING"},
		{"Hotring Racer", "HOTRINA"},
		{"Hotring Racer", "HOTRINB"},
		{"HPV-1000", "HPV1000"},
		{"Hunter", "HUNTER"},
		{"Huntley", "HUNTLEY"},
		{"Hustler", "HUSTLER"},
		{"Hydra", "HYDRA"},
		{"Infernus", "INFERNU"},
		{"Intruder", "INTRUDR"},
		{"Jester", "JESTER"},
		{"Jetmax", "JETMAX"},
		{"Journey", "JOURNEY"},
		{"Kart", "KART"},
		{"Launch", "LAUNCH"},
		{"Leviathan", "LEVIATH"},
		{"Lunerunner", "LINERUN"},
		{"Majestic", "MAJESTC"},
		{"Manana", "MANANA"},
		{"Marquis", "MARQUIS"},
		{"Maverick", "MAVERIC"},
		{"Merit", "MERIT"},
		{"Mesa", "MESAA"},
		{"Monster", "MONSTER"},
		{"Monster", "MONSTA"},
		{"Monster", "MONSTB"},
		{"Moonbeam", "MOONBM"},
		{"Mountain Bike", "MTBIKE"},
		{"Mower", "MOWER"},
		{"Mr. Whoopee", "WHOOPEE"},
		{"Mule", "MULE"},
		{"Nebula", "NEBULA"},
		{"Nevada", "NEVADA"},
		{"News Maverick", "SANMAV"},
		{"Newsvan", "NEWSVAN"},
		{"NRG-500", "NRG500"},
		{"Oceanic", "OCEANIC"},
		{"Packer", "PACKER"},
		{"Patriot", "PATRIOT"},
		{"PCJ-600", "PCJ600"},
		{"Perennial", "PEREN"},
		{"Petrol Truck", "PETROTR"},
		{"Phoenix", "PHOENIX"},
		{"Picador", "PICADOR"},
		{"Pizzaboy", "PIZZABO"},
		{"Police Cruiser", "POLICAR"},
		{"Police Maverick", "POLMAV"},
		{"Pony", "PONY"},
		{"Predator", "PREDATR"},
		{"Premier", "PREMIER"},
		{"Previon", "PREVION"},
		{"Primo", "PRIMO"},
		{"Quad", "QUAD"},
		{"Raindance", "RAINDNC"},
		{"Rancher", "RANCHER"},
		{"Ranger", "RANGER"},
		{"RC Bandit", "RCBANDIT"},
		{"RC Baron", "RCBARON"},
		{"RC Cam", "RCCAM"},
		{"RC Goblin", "RCGOBLI"},
		{"RC Raider", "RCRAIDE"},
		{"RC Tiger", "RCTIGER"},
		{"Reefer", "REEFER"},
		{"Regina", "REGINA"},
		{"Remington", "REMING"},
		{"Rhino", "RHINO"},
		{"Roadtrain", "RDTRAIN"},
		{"Romero", "ROMERO"},
		{"Rumpo", "RUMPO"},
		{"Rustler", "RUSTLER"},
		{"S.W.A.T.", "SWATVAN"},
		{"Saber", "SABRE"},
		{"Sadler", "SADLER"},
		{"Sadler Shit", "SADLSHI"},
		{"Sanchez", "SANCHEZ"},
		{"Sandking", "SANDKIN"},
		{"Savanna", "SAVANNA"},
		{"Seasparrow", "SEASPAR"},
		{"Securicar", "SECURI"},
		{"Sentinel", "SENTINL"},
		{"Shamal", "SHAMAL"},
		{"Skimmer", "SKIMMER"},
		{"Slamvan", "SLAMVAN"},
		{"Solair", "SOLAIR"},
		{"Sparrow", "SPARROW"},
		{"Speeder", "SPEEDER"},
		{"Squalo", "SQUALO"},
		{"Stafford", "STAFFRD"},
		{"Stallion", "STALION"},
		{"Stratum", "STRATUM"},
		{"Stretch", "STRETCH"},
		{"Stuntplane", "STUNT"},
		{"Sultan", "SULTAN"},
		{"Sunrise", "SUNRISE"},
		{"Super GT", "SUPERGT"},
		{"Sweeper", "SWEEPER"},
		{"Tahoma", "TAHOMA"},
		{"Tampa", "TAMPA"},
		{"Tanker", "PETROL"},
		{"Taxi", "TAXI"},
		{"Tornado", "TORNADO"},
		{"Towtruck", "TOWTRUK"},
		{"Tractor", "TRACTOR"},
		{"Tram", "TRAM"},
		{"Trashmaster", "TRASHM"},
		{"Tropic", "TROPIC"},
		{"Tug", "TUG"},
		{"TUGSTAI", "TUGSTAI"},
		{"Turismo", "TURISMO"},
		{"Uranus", "URANUS"},
		{"Utility Van", "UTILITY"},
		{"UTILTR1", "UTILTR1"},
		{"Vincent", "VINCENT"},
		{"Virgo", "VIRGO"},
		{"Voodoo", "VOODOO"},
		{"Vortex", "VORTEX"},
		{"Walton", "WALTON"},
		{"Washington", "WASHING"},
		{"Wayfarer", "WAYFARE"},
		{"Willard", "WILLARD"},
		{"Windsor", "WINDSOR"},
		{"Yankee", "YANKEE"},
		{"Yosemite", "YOSEMIT"},
		{"ZR-350", "ZR350"},
	}

	for k, v in ipairs(vehNames) do
		if v[2] == getNameOfVehicleModel(model) then
            vehname = v[1]
        end
    end
	return vehname
end

function getPlayerZoneName()
	local zonename, zonenames, customzonenames = 'Unknown', {
		{'IWD','Idlewood'},
		{'JEF','Jefferson'},
		{'GAN','Ganton'},
		{'GANTB','Gant Bridge'},
		{'LIND','Willowfield'},
		{'LMEX','Little Mexico'},
		{'COM','Commerce'},
		{'VERO','Verona Beach'},
		{'MKT','Market'},
		{'MARKST','Market Station'},
		{'CONF','Conference Center'},
		{'BLUF','Verdant Bluffs'},
		{'LAIR','Los Santos International'},
		{'LA','Los Santos'},
		{'ELCO','El Corona'},
		{'PER1','Pershing Square'},
		{'MAR','Marina'},
		{'VIN','Vinewood'},
		{'ROD','Rodeo'},
		{'RIH','Richman'},
		{'SMB','Santa Maria Beach'},
		{'LDT','Downtown Los Santos'},
		{'GLN','Glen Park'},
		{'VISA','The Visage'},
		{'HGP','Harry Gold Parkway'},
		{'FRED','Frederick Bridge'},
		{'RED','Red County'},
		{'FISH','Fisher\'s Lagoon'},
		{'MONT','Montgomery'},
		{'MONINT','Montgomery Intersection'},
		{'MUL','Mulholland'},
		{'MULINT','Mulholland Intersection'},
		{'SUN','Temple'},
		{'ELS','East Los Santos'},
		{'CHC','Las Colinas'},
		{'LDOC','Ocean Docks'},
		{'DILLI','Dillimore'},
		{'TOPFA','Hilltop Farm'},
		{'FARM','The Farm'},
		{'FLINTR','Flint Range'},
		{'FLINW','Flint Water'},
		{'FLINTC','Flint County'},
		{'FLINTI','Flint Intersection'},
		{'LEAFY','Leafy Hollow'},
		{'BACKO','Back O Beyond'},
		{'WHET','Whetstone'},
		{'CREEK','Shady Creeks'},
		{'MTCHI','Mount Chiliad'},
		{'ANGPI','Angel Pine'},
		{'LSINL','Los Santos Inlet'},
		{'SAN_AND','San Andreas'},
		{'BLUEB','Blueberry'},
		{'BLUAC','Blueberry Acres'},
		{'PANOP','The Panopticon'},
		{'EBAY','Easter Bay Chemicals'},
		{'FERN','Fern Ridge'},
		{'PALO','Palomino Creek'},
		{'HANKY','Hankypanky Point'},
		{'SASO','San Andreas Sound'},
		{'HAUL','Fallen Tree'},
		{'SF','San Fierro'},
		{'VE','Las Venturas'},
		{'SFAIR','Easter Bay Airport'},
		{'ETUNN','Easter Tunnel'},
		{'SILLY','Foster Valley'},
		{'HILLP','Missionary Hill'},
		{'CUNTC','Avispa Country Club'},
		{'OCEAF','Ocean Flats'},
		{'HASH','Hashbury'},
		{'GARC','Garcia'},
		{'DOH','Doherty'},
		{'CRANB','Cranberry Station'},
		{'EASB','Easter Basin'},
		{'SFDWT','Downtown'},
		{'THEA','King\'s'},
		{'WESTP','Queens'},
		{'CITYS','City Hall'},
		{'BAYV','Palisades'},
		{'CIVI','Santa Flora'},
		{'JUNIHI','Juniper Hill'},
		{'JUNIHO','Juniper Hollow'},
		{'ESPN','Esplanade North'},
		{'ESPE','Esplanade East'},
		{'KINC','Kincaid Bridge'},
		{'GARV','Garver Bridge'},
		{'BATTP','Battery Point'},
		{'GANTB','Gant Bridge'},
		{'CALT','Calton Heights'},
		{'FINA','Financial'},
		{'CHINA','Chinatown'},
		{'PARA','Paradiso'},
		{'MAKO','The Mako Span'},
		{'RIE','Randolph Industrial Estate'},
		{'JTS','Julius Thruway South'},
		{'JTE','Julius Thruway East'},
		{'JTW','Julius Thruway West'},
		{'JTN','Julius Thruway North'},
		{'RSE','Rockshore East'},
		{'RSW','Rockshore West'},
		{'LDM','Last Dime Motel'},
		{'BFLD','Blackfield'},
		{'BINT','Blackfield Intersection'},
		{'BFC','Blackfield Chapel'},
		{'DRAG','The Four Dragons Casino'},
		{'SRY','Sobell Rail Yards'},
		{'LST','Linden Station'},
		{'LINDEN','Linden Station'},
		{'QUARY','Hunter Quarry'},
		{'FALLO','Fallow Bridge'},
		{'LDS','Linden Side'},
		{'CAM','The Camel\'s Toe'},
		{'LOT','Come-A-Lot'},
		{'STRIP','The Strip'},
		{'HIGH','The High Roller'},
		{'PINK','The Pink Swan'},
		{'ROY','Royal Casino'},
		{'CALI','Caligula\'s Palace'},
		{'PILL','Pilgrim'},
		{'STAR','Starfish Casino'},
		{'OVS','Old Venturas Strip'},
		{'RING','The Clown\'s Pocket'},
		{'CREE','Creek'},
		{'ROCE','Roca Escalante'},
		{'ISLE','The Emerald Isle'},
		{'REDE','Redsands East'},
		{'REDW','Redsands West'},
		{'GGC','Greenglass College'},
		{'KACC','K.A.C.C. Military Fuels'},
		{'ELCA','El Castillo Del Diablo'},
		{'PAYAS','Las Payasadas'},
		{'ROBAD','Tierra Robada'},
		{'BYTUN','Bayside Tunnel'},
		{'REST','Area 69'},
		{'WWE','Whitewood Estates'},
		{'VAIR','Las Venturas Airport'},
		{'SPIN','Spinybed'},
		{'PRP','Prickle Pine'},
		{'PALMS','Green Palms'},
		{'OCTAN','Octane Springs'},
		{'PROBE','Lil\' Probe Inn'},
		{'CARSO','Fort Carson'},
		{'BIGE','The Big Ear'},
		{'TOM','Regular Tom'},
		{'BRUJA','Las Brujas'},
		{'ARCO','Arco Del Oeste'},
		{'DAM','The Sherman Dam'},
		{'SHERR','Sherman Reservoir'},
		{'BARRA','Las Barrancas'},
		{'MART','Martin Bridge'},
		{'ROBINT','Robada Intersection'},
		{'ELQUE','El Quebrados'},
		{'ALDEA','Aldea Malvada'},
		{'SUNMA','Bayside Marina'},
		{'SUNNN','Bayside'},
		{'SANB','San Fierro Bay'},
		{'YBELL','Yellow Bell Golf Course'},
		{'PINT','Pilson Intersection'},
		{'PIRA','Pirates In Men\'s Pants'},
		{'LVA','LVA Freight Depot'},
		{'BONE','Bone County'},
		{'MEAD','Verdant Meadows'},
		{'PLS','Playa Del Seville'},
		{'EBE','East Beach'},
		{'LFL','Los Flores'},
		{'NROCK','North Rock'},
		{'UNITY','Unity Station'}
	},
	{
		{"Castille Island", 3138.7588, -2248.6106, -63.2630, 3530.0903, -1922.0083, 343.3367},
		{"ARES Garage", 2204.1096, 2411.6570, -13.5870, 2329.5793,2512.3259, 0.4885},
		{"FBI Garage", 248.1156,-1549.7271,22.9225, 370.9664,-1456.6969,30.3469}
	}
	x, y, z = getCharCoordinates(ped)
	zonename = getNameOfZone(x, y, z)
	for k, v in pairs(zonenames) do
		if zonename == v[1] and string.find(zonename, v[1]) then
			zonename = v[2]
		end
	end
	if getActiveInterior() ~= 0 then
		zonename = 'Interior'
	end
	for i, v in ipairs(customzonenames) do
        if (x >= v[2]) and (y >= v[3]) and (z >= v[4]) and (x <= v[5]) and (y <= v[6]) and (z <= v[7]) then
            zonename = v[1]
        end
    end
	return zonename
end
