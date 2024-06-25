script_name("Hud")
script_author("akacross")
script_url("https://akacross.net/")

local script_version = 1.2
local script_version_text = '1.2'

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
local flag = require ('moonloader').font_flag
local faicons = require 'fa-icons'
local ti = require 'tabler_icons'
local fa = require 'fAwesome5'
local dlstatus = require('moonloader').download_status
local https = require 'ssl.https'
local path = getWorkingDirectory() .. '/config/' 
local configpath = getWorkingDirectory() .. '/config/' .. thisScript().name .. '/' 
local resource = getWorkingDirectory() .. '/resource/' 
local resourcepath = getWorkingDirectory() .. '/resource/' .. thisScript().name .. '/' 
local iconspath = getWorkingDirectory() .. '/resource/' .. thisScript().name .. '/Weapons/' 
local cleopath = getGameDirectory() .. '\\cleo'
local cfg_hud = path .. thisScript().name.. '\\' .. thisScript().name..'.ini'
local cfg_autosave = path .. thisScript().name.. '\\' .. 'Autosave'..'.ini'
local script_path = thisScript().path
local script_url = "https://raw.githubusercontent.com/akacross/hud/main/hud.lua"
local update_url = "https://raw.githubusercontent.com/akacross/hud/main/hud.txt"
local icons_url = "https://raw.githubusercontent.com/akacross/hud/main/resource/Hud/Weapons/"
local fixwidth_url = "https://raw.githubusercontent.com/akacross/hud/main/FixWIDTH.cs"

local function loadIconicFont(fromfile, fontSize, min, max, fontdata)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = new.ImWchar[3](min, max, 0)
	if fromfile then
		imgui.GetIO().Fonts:AddFontFromFileTTF(fontdata, fontSize, config, iconRanges)
	else
		imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fontdata, fontSize, config, iconRanges)
	end
end

local blank_autosave = {}
local autosave = {turftext = '', wwtext = ''}

local blank_hud = {}
local hud = {
	toggle = true,
	autosave = false,
	autoupdate = false,
	defaulthud = false,
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
		{x = 525, y = 234, name = "Hud", move = false},
		{x = 525, y = 234, name = "Radar", move = false},
		{x = 525, y = 234, name = "Time", move = false},
		{x = 525, y = 234, name = "FPS/Ping", move = false},
		{x = 525, y = 234, name = "Vehicle", move = false},
		{x = 525, y = 234, name = "Name", move = false}
	},
	move = {
		{1,1},{1,1},{1,1},{1,1},{1,1},{1,1,1},{1,1},{6,3,3,4,4,2,2,2,5,5,2}
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
	font = {{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial"},{"Aerial","Aerial"},{"Aerial"},{"Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial"},{'Aerial'}},
	fontsize = {
		{8},{8},{8},{8},{8},{8,10},{16},{10,10,10,10,10,10,10,10,10,10,10}
	},
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
		turf = {
			toggle = {false},
			pos = {86, 434}
		},
		turfowner = {
			toggle = {false},
			pos = {86, 423},
			color = 4294967295
		},
		wristwatch = {
			toggle = {false},
			pos = {577, 24},
			color = 4294967295
		},
		hzglogo = {
			toggle = {true,false},
			pos = {562, 3},
			color = 4294967295,
			customstring = 'akacross.net'
		},
		hpbar = {
			toggle = {false},
			color1 = 4278190080,
			color2 = 4284091408,
			color3 = 4290058273
		},
		hptext = {
			toggle = {false},
			color = 4294967295
		},
		armortext = {
			toggle = {false},
			color = 4294967295
		}
	}
}

local menu = new.bool(false)
local mid = 1
local move = false
local update = false
local debug_tog = false
local textdrawbool = {false,false,false,false,false,false,false,false,false}
local servermessagebool = false
local blankini = false

local value = {
	{0},{0},{0},{0},{0},{0,0,'Weapon Name'},{0,0},{'Name','Local-Time','Server-Time','Ping','FPS','Direction','Location','Turf','Vehicle Speed','Vehicle Name','Badge'}
}

local spec = {
	playerid = -1, 
	state = false
}

local assets = {
	temp_pos = {x = 0, y = 0},
	temp_pos_radar = {x = 0, y = 0},
	wid = {},
	fid = {
		{0},{0},{0},{0},{0},{0,0},{0},{0,0,0,0,0,0,0,0,0,0,0},{0}
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
local inusemove = {}
local selected = {
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false},
	{false,false,false,false,false,false,false,false,false,false,false},
	{false}
}
local selectedbox = {}

 ffi.cdef
[[
    void *malloc(size_t size);
    void free(void *ptr);
	
	struct stKillEntry
	{
		char					szKiller[25];
		char					szVictim[25];
		uint32_t				clKillerColor; // D3DCOLOR
		uint32_t				clVictimColor; // D3DCOLOR
		uint8_t					byteType;
	} __attribute__ ((packed));

	struct stKillInfo
	{
		int						iEnabled;
		struct stKillEntry		killEntry[5];
		int 					iLongestNickLength;
		int 					iOffsetX;
		int 					iOffsetY;
		void			    	*pD3DFont; // ID3DXFont
		void		    		*pWeaponFont1; // ID3DXFont
		void		   	    	*pWeaponFont2; // ID3DXFont
		void					*pSprite;
		void					*pD3DDevice;
		int 					iAuxFontInited;
		void 		    		*pAuxFont1; // ID3DXFont
		void 			    	*pAuxFont2; // ID3DXFont
	} __attribute__ ((packed));
]]

local function NumberString
(Number)
	local String = ''
	repeat
		local Remainder = Number % 2
		String = Remainder .. String
		Number = (Number - Remainder) / 2
	until Number == 0
	return String
end

function FromBinary(String)
	if (#String % 8 ~= 0)
	then
		print('Malformed binary sequence')
	end
	local Result = ''
	for i = 1, (#String), 8 do
		Result = Result..string.char(tonumber(String:sub(i, i + 7), 2))
	end
	return Result
end

function ToBinary(String)
	if (#String > 0)
	then
		local Result = ''
		for i = 1, (#String)
		do
			Result  = Result .. string.format('%08d', NumberString(string.byte(string.sub(String, i, i))))
		end
		return Result
	else
		return nil
	end
end

function main() 
	blank_hud = table.deepcopy(hud)
	blank_autosave = table.deepcopy(autosave)
	if not doesDirectoryExist(path) then createDirectory(path) end
	if not doesDirectoryExist(configpath) then createDirectory(configpath) end
	if not doesDirectoryExist(resource) then createDirectory(resource) end
	if not doesDirectoryExist(resourcepath) then createDirectory(resourcepath) end
	if not doesDirectoryExist(iconspath) then createDirectory(iconspath) end
	
	if doesFileExist(cfg_hud) then loadIni_hud() else blankIni_hud() end
	if doesFileExist(cfg_autosave) then loadIni_autosave() else blankIni_autosave() end
	
	if not hud.hzgsettings.turf or hud.hzgsettings.turf == true then
		hud.hzgsettings.turf = {}
	end
	if not hud.hzgsettings.turfowner or hud.hzgsettings.turfowner == true then
		hud.hzgsettings.turfowner = {}
	end
	if not hud.hzgsettings.wristwatch or hud.hzgsettings.wristwatch == true then
		hud.hzgsettings.wristwatch = {}
	end
	if not hud.hzgsettings.hzglogo or hud.hzgsettings.hzglogo == true then
		hud.hzgsettings.hzglogo = {}
	end
	if not hud.hzgsettings.hpbar or hud.hzgsettings.hpbar == true then
		hud.hzgsettings.hpbar = {}
	end
	if not hud.hzgsettings.hptext or hud.hzgsettings.hptext == true then
		hud.hzgsettings.hptext = {}
	end
	if not hud.hzgsettings.armortext or hud.hzgsettings.armortext == true then
		hud.hzgsettings.armortext = {}
	end
	
	hud = table.assocMerge(blank_hud, hud)
	autosave = table.assocMerge(autosave, blank_autosave)
	
	displayHud(hud.defaulthud) 
	createfonts()
	load_textures()
	icons_script()
	fixwidth()

	repeat wait(0) until isSampAvailable()
	
	for i = 0, 6 do
		hztextdraws(i)
	end
	local hptext_res, hptext = getSampfuncsGlobalVar("hptext")
	local armortext_res, armortext = getSampfuncsGlobalVar("armortext")
	if not hptext_res then
		setSampfuncsGlobalVar("hptext", 100)
	end
	if not armortext_res then
		setSampfuncsGlobalVar("armortext", 100)
	end
	
	if hud.autoupdate then
		update_script()
	end

	if hud.radar.compass then
		assets.compass[1] = addSpriteBlipForCoord(0.0, 999999.0, 23.0, 24) --  N
		assets.compass[2] = addSpriteBlipForCoord(999999.0, 0.0, 23.0, 34) -- S
		assets.compass[3] = addSpriteBlipForCoord(-999999.0, 0.0, 23.0, 46) -- W
		assets.compass[4] = addSpriteBlipForCoord(0.0, -999999.0, 23.0, 38) -- E
	end

	sampRegisterChatCommand("hud", function() 
		if not update then
			menu[0] = not menu[0] 
		else
			sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} The update is in progress.. Please wait..", script.this.name), -1)
		end
	end)
	sampAddChatMessage("["..script.this.name..'] '.. "{FF1A74}(/hud) Authors: " .. table.concat(thisScript().authors, ", "), -1)
	
	setmaxhp()
	
	lua_thread.create(function() 
		while true do wait(1000) 
			fps = fps_counter 
			fps_counter = 0 
		end 
	end)
	
	lua_thread.create(function()
		while true do wait(15)
		
			if not sampTextdrawIsExists(2053) then
				if 2053 ~= 0 then
					setSampfuncsGlobalVar("armortext", 0)
				end
			end
		
			for i = 0, 3000 do
				if sampTextdrawIsExists(i) then
					local textdraw1_res, textdraw1 = getSampfuncsGlobalVar("textdraw1")
					if i == textdraw1 and textdraw1_res then
						local _, _, color = sampTextdrawGetLetterSizeAndColor(i)
						hud.color[8][8] = color
					end
				end
			end
		
			hudmove()
			changeRadarPosAndSize(hud.radar.pos[1], hud.radar.pos[2], hud.radar.size[1], hud.radar.size[2])
			changeRadarColor(hud.radar.color)
		
			local hptext_res, hptext = getSampfuncsGlobalVar("hptext")
			local armortext_res, armortext = getSampfuncsGlobalVar("armortext")
			local res, id = sampGetPlayerIdByCharHandle(ped)
			if res then
				local weap, color, vehhp, turfname, localtime, servertime, speed, carName, badge = getCurrentCharWeapon(ped), sampGetPlayerColor(id), 0, '', '', '', '', '', ''
				
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
				
				if menu[0] then 
					value = {{50},{50},{100},{1000},{100},{24,formatammo(50000,7),'Desert Eagle'},{6,formatmoney(1000000)},{'Player_Name', 'Local-Time', 'Server-Time', 'Ping', showfps, 'Direction', 'Location', 'Turf', 'Vehicle Speed', 'Vehicle Name', 'Badge'}}
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
									autosave.wwtext,
									(hud.tog[8][4][2] and 'Ping: ' or '')..sampGetPlayerPing(spec.playerid),
									showfps,
									getdirection(pid),
									getPlayerZoneName(), 
									autosave.turftext, 
									speed,
									carName,
									badge
								}
							}
						end	
					else
						value = {
							{hptext},
							{armortext},
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
								autosave.wwtext,
								(hud.tog[8][4][2] and 'Ping: ' or '')..sampGetPlayerPing(id),
								showfps,
								getdirection(ped),
								getPlayerZoneName(), 
								autosave.turftext, 
								speed, 
								carName, 
								badge
							}
						}
					end
				end
			end
		end
	end)
	
	while true do wait(0)
		if update then
			menu[0] = false
			lua_thread.create(function() 
				hud.autosave = false
				os.remove(cfg_hud)
				wait(20000) 
				thisScript():reload()
				update = false
			end)
		end
	end
end

imgui.OnInitialize(function()
	apply_custom_style()

	loadIconicFont(false, 14.0, faicons.min_range, faicons.max_range, faicons.get_font_data_base85())
	loadIconicFont(true, 14.0, fa.min_range, fa.max_range, 'moonloader/resource/fonts/fa-solid-900.ttf')
	loadIconicFont(false, 14.0, ti.min_range, ti.max_range, ti.get_font_data_base85())

	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(function() return menu[0] end,
function()
	local center = imgui.ImVec2(imgui.GetIO().DisplaySize.x / 2, imgui.GetIO().DisplaySize.y / 2)
	imgui.SetNextWindowPos(center, imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin(ti.ICON_SETTINGS .. string.format("%s Settings - Version: %s", script.this.name, script_version), menu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		
		imgui.SetCursorPos(imgui.ImVec2(5, 25))

		imgui.BeginChild("##2", imgui.ImVec2(460, 76), false)
			
			imgui.SetCursorPos(imgui.ImVec2(81,5))
			if imgui.CustomButton(fa.ICON_FA_HEART .. ' Health',
				mid == 1 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 1
			end
			
			imgui.SetCursorPos(imgui.ImVec2(81,31))
			if imgui.CustomButton(faicons.ICON_SHIELD .. ' Armor',
				mid == 2 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 2
			end
			
			imgui.SetCursorPos(imgui.ImVec2(157,5))
			if imgui.CustomButton(fa.ICON_FA_RUNNING .. ' Sprint',
				mid == 3 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 3
			end
			
			imgui.SetCursorPos(imgui.ImVec2(157,31))
			if imgui.CustomButton(fa.ICON_FA_CAR  .. ' Vehicle',
				mid == 4 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 4
			end
			
			imgui.SetCursorPos(imgui.ImVec2(233,5))
			if imgui.CustomButton(ti.ICON_SCUBA_MASK .. ' Breath',
				mid == 5 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 5
			end
			
			imgui.SetCursorPos(imgui.ImVec2(233,31))
			if imgui.CustomButton(ti.ICON_FOCUS_2 .. ' Weapon',
				mid == 6 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 6
			end
			
			imgui.SetCursorPos(imgui.ImVec2(309,5))
			if imgui.CustomButton('Stars/Cash',
				mid == 7 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 7
			end
			
			imgui.SetCursorPos(imgui.ImVec2(309,31))
			if imgui.CustomButton(faicons.ICON_COGS .. ' Other',
				mid == 8 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 8
			end
			
			imgui.SetCursorPos(imgui.ImVec2(385,5))
			if imgui.CustomButton(ti.ICON_GPS .. ' Screen',
				mid == 9 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 9
			end
			
			imgui.SetCursorPos(imgui.ImVec2(385,31))
			if imgui.CustomButton(fa.ICON_FA_OBJECT_GROUP .. ' Move',
				mid == 10 and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9),
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 25)) then
				mid = 10
			end
			
		imgui.EndChild()
		
		imgui.SetCursorPos(imgui.ImVec2(5, 25))
		
		imgui.BeginChild("##1", imgui.ImVec2(85, 392), false)
			
			imgui.SetCursorPos(imgui.ImVec2(5, 5))
      
			if imgui.CustomButton(
				faicons.ICON_POWER_OFF, 
				hud.toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.7) or imgui.ImVec4(1, 0.19, 0.19, 0.5), 
				hud.toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.5) or imgui.ImVec4(1, 0.19, 0.19, 0.3), 
				hud.toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.4) or imgui.ImVec4(1, 0.19, 0.19, 0.2), 
				imgui.ImVec2(75, 75)) then
				hud.toggle = not hud.toggle
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Toggles Hud')
			end
		
			imgui.SetCursorPos(imgui.ImVec2(5, 81))

			if imgui.CustomButton(
				faicons.ICON_FLOPPY_O,
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				saveIni_hud()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Save the INI')
			end
      
			imgui.SetCursorPos(imgui.ImVec2(5, 157))

			if imgui.CustomButton(
				faicons.ICON_REPEAT, 
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				loadIni_hud()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Reload the INI')
			end

			imgui.SetCursorPos(imgui.ImVec2(5, 233))

			if imgui.CustomButton(
				faicons.ICON_ERASER, 
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1), 
				imgui.ImVec2(75, 75)) then
				blankIni_hud()
				createfonts() 
				for i = 0, 6 do
					hztextdraws(i)
				end
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Reset the INI to default settings')
			end

			imgui.SetCursorPos(imgui.ImVec2(5, 309))

			if imgui.CustomButton(
				faicons.ICON_RETWEET .. ' Update',
				imgui.ImVec4(0.16, 0.16, 0.16, 0.9), 
				imgui.ImVec4(0.40, 0.12, 0.12, 1), 
				imgui.ImVec4(0.30, 0.08, 0.08, 1),  
				imgui.ImVec2(75, 75)) then
				update_script()
			end
			if imgui.IsItemHovered() then
				imgui.SetTooltip('Update the script')
			end
      
		imgui.EndChild()
	
		imgui.SetCursorPos(imgui.ImVec2(89, 85))

		imgui.BeginChild("##3", imgui.ImVec2(376, 289), true)
		
			if mid >= 1 and mid <= 7 then 
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
	
				imgui.Text(u8'Left/Right') 
				imgui.SameLine(90) 
				imgui.Text(u8'Up/Down') 
				imgui.SameLine(180) 
				imgui.Text(u8'Width') 
				imgui.SameLine(260) 
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
				if imgui.BeginCombo("Groups##1", (hud.pos[hud.move[mid][1]] ~= nil and hud.pos[hud.move[mid][1]].name or hud.pos[1].name)) then
					for i = 1, #hud.pos do
						if imgui.Selectable(hud.pos[i].name..'##'..i, hud.move[mid][1] == i) then
							hud.move[mid][1] = i
						end
					end
					imgui.EndCombo()
				end
				imgui.PopItemWidth()
				
				imgui.NewLine()
				font_gui('Text:', mid, 2, 1, 1, 2, 2, 1, 1, 2) 
				if mid == 6 then 
					imgui.NewLine()
					font_gui('Name:', mid, 3, 2, 2, 3, 3, 2, 2, 3) 
				end
			elseif mid == 8 then
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
					imgui.NewLine()
				end
			elseif mid == 9 then
				local color = new.float[3](hex2rgb(hud.radar.color))
				if imgui.ColorEdit3('##color', color, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.radar.color = join_argb(255, color[0] * 255, color[1] * 255, color[2] * 255) 
				end
				imgui.SameLine() 
				imgui.Text(u8'Radar Color') 
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
				imgui.SameLine() 
				if imgui.Checkbox('Default Hud', new.bool(hud.defaulthud)) then 
					hud.defaulthud = not hud.defaulthud
					if hud.defaulthud then
						displayHud(hud.defaulthud)
					else
						displayHud(hud.defaulthud)
					end
				end
					
				imgui.NewLine()
				imgui.Text(u8'Radar Position and Size') 
					
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
				imgui.Text(u8'HZG Settings:') 
				
				--turf
				if imgui.Checkbox('Turf', new.bool(hud.hzgsettings.turf.toggle[1])) then 
					hud.hzgsettings.turf.toggle[1] = not hud.hzgsettings.turf.toggle[1]
					hztextdraws(0)
				end
				imgui.SameLine() 
				
				imgui.PushItemWidth(68)
				local pos = new.float[1](hud.hzgsettings.turf.pos[1])
				if imgui.DragFloat('##turf1', pos, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.turf.pos[1] = pos[0] 
					hztextdraws(0)
				end 
				imgui.SameLine()
				local pos2 = new.float[1](hud.hzgsettings.turf.pos[2])
				if imgui.DragFloat('##turf2', pos2, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.turf.pos[2] = pos2[0] 
					hztextdraws(0)
				end 
				imgui.PopItemWidth()
				
				--turfowner
				if imgui.Checkbox('Turf Owner', new.bool(hud.hzgsettings.turfowner.toggle[1])) then 
					hud.hzgsettings.turfowner.toggle[1] = not hud.hzgsettings.turfowner.toggle[1]
					hztextdraws(1)
				end
				imgui.SameLine() 
				
				local colorturf = new.float[3](hex2rgb(hud.hzgsettings.turfowner.color))
				if imgui.ColorEdit3('##colorturfowner', colorturf, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.turfowner.color = join_argb(255, colorturf[0] * 255, colorturf[1] * 255, colorturf[2] * 255) 
					hztextdraws(1)
				end
				imgui.SameLine()
				
				imgui.PushItemWidth(68)
				local pos = new.float[1](hud.hzgsettings.turfowner.pos[1])
				if imgui.DragFloat('##turfowner1', pos, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.turfowner.pos[1] = pos[0] 
					hztextdraws(1)
				end 
				imgui.SameLine()
				local pos2 = new.float[1](hud.hzgsettings.turfowner.pos[2])
				if imgui.DragFloat('##turfowner2', pos2, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.turfowner.pos[2] = pos2[0] 
					hztextdraws(1)
				end 
				imgui.PopItemWidth()
					
				--wristwatch
				if imgui.Checkbox('WW', new.bool(hud.hzgsettings.wristwatch.toggle[1])) then 
					hud.hzgsettings.wristwatch.toggle[1] = not hud.hzgsettings.wristwatch.toggle[1]
					hztextdraws(2)
				end
				
				imgui.SameLine()
				local colorturf = new.float[3](hex2rgb(hud.hzgsettings.wristwatch.color))
				if imgui.ColorEdit3('##colorWW', colorturf, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.wristwatch.color = join_argb(255, colorturf[0] * 255, colorturf[1] * 255, colorturf[2] * 255) 
					hztextdraws(2)
				end
				imgui.SameLine()
				
				imgui.PushItemWidth(68)
				local pos = new.float[1](hud.hzgsettings.wristwatch.pos[1])
				if imgui.DragFloat('##WW1', pos, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.wristwatch.pos[1] = pos[0] 
					hztextdraws(2)
				end 
				imgui.SameLine()
				local pos2 = new.float[1](hud.hzgsettings.wristwatch.pos[2])
				if imgui.DragFloat('##WW2', pos2, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.wristwatch.pos[2] = pos2[0] 
					hztextdraws(2)
				end 
				imgui.PopItemWidth()
					
				--hzglogo
				if imgui.Checkbox('Logo', new.bool(hud.hzgsettings.hzglogo.toggle[1])) then 
					hud.hzgsettings.hzglogo.toggle[1] = not hud.hzgsettings.hzglogo.toggle[1]
					hztextdraws(3)
				end
				imgui.SameLine() 
				if imgui.Checkbox('Custom Logo', new.bool(hud.hzgsettings.hzglogo.toggle[2])) then 
					hud.hzgsettings.hzglogo.toggle[2] = not hud.hzgsettings.hzglogo.toggle[2]
					hztextdraws(3)
				end
				imgui.SameLine()
				imgui.PushItemWidth(95) 
				local text = new.char[30](hud.hzgsettings.hzglogo.customstring)
				if imgui.InputText('##logochangehzglogo', text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
					hud.hzgsettings.hzglogo.customstring = u8:decode(str(text))
					hztextdraws(3)		
				end
				imgui.PopItemWidth()
					
				local color2 = new.float[3](hex2rgb(hud.hzgsettings.hzglogo.color))
				if imgui.ColorEdit3('##colorhzglogo', color2, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.hzglogo.color = join_argb(255, color2[0] * 255, color2[1] * 255, color2[2] * 255) 
					hztextdraws(3)
				end
				imgui.SameLine()
				imgui.PushItemWidth(68)
				local pos = new.float[1](hud.hzgsettings.hzglogo.pos[1])
				if imgui.DragFloat('##hzglogo1', pos, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.hzglogo.pos[1] = pos[0] 
					hztextdraws(3)
				end 
				imgui.SameLine()
				local pos2 = new.float[1](hud.hzgsettings.hzglogo.pos[2])
				if imgui.DragFloat('##hzglogo2', pos2, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
					hud.hzgsettings.hzglogo.pos[2] = pos2[0] 
					hztextdraws(3)
				end 
				imgui.PopItemWidth()
					
				--hpbar
				if imgui.Checkbox('HP Bar', new.bool(hud.hzgsettings.hpbar.toggle[1])) then 
					hud.hzgsettings.hpbar.toggle[1] = not hud.hzgsettings.hpbar.toggle[1]
					hztextdraws(4)
				end
				
				imgui.SameLine()
				local color4 = new.float[3](hex2rgb(hud.hzgsettings.hpbar.color1))
				if imgui.ColorEdit3('##colorhpbar1', color4, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.hpbar.color1 = join_argb(255, color4[0] * 255, color4[1] * 255, color4[2] * 255) 
					hztextdraws(4)
				end
					
				imgui.SameLine()
				local color5 = new.float[3](hex2rgb(hud.hzgsettings.hpbar.color2))
				if imgui.ColorEdit3('##colorhpbar2', color5, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.hpbar.color2 = join_argb(255, color5[0] * 255, color5[1] * 255, color5[2] * 255) 
					hztextdraws(4)
				end
					
				imgui.SameLine()
				local color6 = new.float[3](hex2rgb(hud.hzgsettings.hpbar.color3))
				if imgui.ColorEdit3('##colorhpbar3', color6, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
					hud.hzgsettings.hpbar.color3 = join_argb(255, color6[0] * 255, color6[1] * 255, color6[2] * 255) 
					hztextdraws(4)
				end
				
				--hptext
				if imgui.Checkbox('HP Text', new.bool(hud.hzgsettings.hptext.toggle[1])) then 
					hud.hzgsettings.hptext.toggle[1] = not hud.hzgsettings.hptext.toggle[1]
					hztextdraws(5)
				end
				
				--armortext
				if imgui.Checkbox('Armor Text', new.bool(hud.hzgsettings.armortext.toggle[1])) then 
					hud.hzgsettings.armortext.toggle[1] = not hud.hzgsettings.armortext.toggle[1]
					hztextdraws(6)
				end
			elseif mid == 10 then
					for k, v in ipairs(hud.pos) do
						imgui.PushItemWidth(120) 
						text = new.char[30](v.name)
						if imgui.InputText('##input'..k, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
							v.name = u8:decode(str(text))
						end
						imgui.PopItemWidth()
							
							
						imgui.SameLine()
						
						imgui.PushItemWidth(75)
						local pos = new.float[1](v.x)
						if imgui.DragFloat('##'..k, pos, 0.1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
							v.x = pos[0] 
						end 
						imgui.PopItemWidth()
						
						imgui.SameLine()
						
						imgui.PushItemWidth(75)
						local pos2 = new.float[1](v.y)
						if imgui.DragFloat('##'..k, pos2, 0.1, 12 * 2000.0, 12 * 2000.0, "%.1f") then 
							v.y = pos2[0] 
						end 
						imgui.PopItemWidth()
						
						imgui.SameLine()
						if imgui.Button(v.move and u8"Undo##"..k or u8"Move##"..k) then
							if not move or v.move then
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
			end
		imgui.EndChild()
		
		imgui.SetCursorPos(imgui.ImVec2(89, 373))
		
		imgui.BeginChild("##5", imgui.ImVec2(376, 36), true)
		
			imgui.BeginGroup()
				if imgui.Checkbox('Auto-save', new.bool(hud.autosave)) then 
					hud.autosave = not hud.autosave 
					saveIni_hud() 
				end
				if imgui.IsItemHovered() then
					imgui.SetTooltip('Auto-save')
				end
				
				imgui.SameLine()
				if imgui.Checkbox('Auto-update', new.bool(hud.autoupdate)) then 
					hud.autoupdate = not hud.autoupdate 
				end
				if imgui.IsItemHovered() then
					imgui.SetTooltip('Auto-Update')
				end
			imgui.EndGroup()
		imgui.EndChild()
	imgui.End()
end)

function onD3DPresent()	
	fps_counter = fps_counter + 1
	if not isPauseMenuActive() and not sampIsScoreboardOpen() and sampGetChatDisplayMode() > 0 and not isKeyDown(VK_F10) and hud.toggle then
		
		for k, v in ipairs(hud.pos) do
			if menu[0] then
				renderDrawBox(v.x, v.y, 15, 15, -1)
			end
		end
		
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

function load_textures()
	for i = 0, 48 do
		if doesFileExist(iconspath..i..'.png') then
			assets.wid[i] = renderLoadTextureFromFile(iconspath..i..'.png') 
		end
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

function sampev.onSendSpawn()
	if blankini then
		chud()
		blankini = false
	end
end

function chud()
	sampSendChat("/chud 1")
	lua_thread.create(function() 
		servermessagebool = true
		local result, playerid = sampGetPlayerIdByCharHandle(ped) 
		if result then
			servermessagebool = true
			wait(200 + sampGetPlayerPing(playerid))
			servermessagebool = false
		end
	end)
end

function sampev.onServerMessage(color, text)
	if text:find("turns off their wristwatch.") then
		autosave.wwtext = ''
	end
	if text:find("You have toggled off turfs on your radar/map.") then
		setSampfuncsGlobalVar("turftext", '')
		autosave.turftext = ''
	end

	if text:find("You have set your custom HUD style to ") then
		textdrawbool[8] = false
		textdrawbool[9] = false
	end
	
	if text:find("You have set your custom HUD style to 1.") then
		if servermessagebool then
			return false
		end
	end
	
	if text:find("You have disabled your custom HUD.") then
		sampAddChatMessage('You cannot disable custom HUD.', -1)
		chud()
		return false
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
	--print(data.position.x ..' | '.. data.position.y ..' | '.. data.text ..' | '.. id)
	if data.position.x == 86 and (data.position.y == 434 or math.floor(data.position.y) == 424) and not textdrawbool[1] then
		setSampfuncsGlobalVar("textdraw1", id)
		textdrawbool[1] = true
	end
	if data.position.x == 86 and data.position.y == 423 and not textdrawbool[2] then
		setSampfuncsGlobalVar("textdraw2", id)
		textdrawbool[2] = true
	end
	if data.position.x == 577 and data.position.y == 24 and not textdrawbool[3] then
		setSampfuncsGlobalVar("textdraw3", id)
		textdrawbool[3] = true
	end
	if data.position.x == 562 and data.position.y == 3 and not textdrawbool[4] then
		setSampfuncsGlobalVar("textdraw4", id)
		textdrawbool[4] = true
	end
	if (data.position.x == 577 or data.position.x == 611) and data.position.y == 65 and not textdrawbool[8] then 
		setSampfuncsGlobalVar("textdraw8", id)
		textdrawbool[8] = true
	end
	if (data.position.x == 577 or data.position.x == 611) and data.position.y == 43 and not textdrawbool[9] then 
		setSampfuncsGlobalVar("textdraw9", id)
		print(id)
		textdrawbool[9] = true
	end
	
	local textdraw1_res, textdraw1 = getSampfuncsGlobalVar("textdraw1")
	if id == textdraw1 and textdraw1_res then
		if hud.hzgsettings.turf.toggle[1] then
			autosave.turftext = data.text
			data.text = data.text
		else
			autosave.turftext = data.text
			data.text = ''
		end
		data.position.x = hud.hzgsettings.turf.pos[1]
		data.position.y = hud.hzgsettings.turf.pos[2]
		return {id, data}
	end

	local textdraw2_res, textdraw2 = getSampfuncsGlobalVar("textdraw2")
	if id == textdraw2 and textdraw2_res then
		data.position.x = hud.hzgsettings.turfowner.pos[1]
		data.position.y = hud.hzgsettings.turfowner.pos[2]
		if hud.hzgsettings.turfowner.toggle[1] then
			data.text = 'TURF OWNER:'
		else
			data.text = ''
			
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.turfowner.color)
		end)
		return {id, data}
	end

	local textdraw3_res, textdraw3 = getSampfuncsGlobalVar("textdraw3")
	if id == textdraw3 and textdraw3_res then
		data.position.x = hud.hzgsettings.wristwatch.pos[1]
		data.position.y = hud.hzgsettings.wristwatch.pos[2]
		if hud.hzgsettings.wristwatch.toggle[1] then
			autosave.wwtext = data.text
			data.text = data.text
		else
			autosave.wwtext = data.text
			data.text = ''
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.wristwatch.color)
		end)
		return {id, data}
	end

	local textdraw4_res, textdraw4 = getSampfuncsGlobalVar("textdraw4")
	if id == textdraw4 and textdraw4_res then
		if hud.hzgsettings.hzglogo.toggle[1] then
			data.text = hud.hzgsettings.hzglogo.toggle[2] and hud.hzgsettings.hzglogo.customstring or 'hzgaming.net'
		else
			data.text = ''
		end
		data.position.x = hud.hzgsettings.hzglogo.pos[1]
		data.position.y = hud.hzgsettings.hzglogo.pos[2]
		
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.hzglogo.color)
		end)
		return {id, data}
	end

	if math.floor(data.position.x) == 610 and math.floor(data.position.y) == 68 then
		if hud.hzgsettings.hpbar.toggle[1] then
			data.text = ''
		else
			data.text = ''
		end
		
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color1, 543.75, 0)
		end)
		return {id, data}
	end

	if math.floor(data.position.x) == 608 and math.floor(data.position.y) == 70 then 
		if hud.hzgsettings.hpbar.toggle[1] then
			data.text = ''
		else
			data.text = ''
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color2, 545.75, 0)
		end)
		return {id, data}
	end

	if math.floor(data.position.x) <= 608 and math.floor(data.position.y) == 70 then
		if hud.hzgsettings.hpbar.toggle[1] then
			data.text = ''
		else
			data.text = ''
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color3, 545.75, 0)
		end)
		return {id, data}
	end
	
	local textdraw8_res, textdraw8 = getSampfuncsGlobalVar("textdraw8")
	if id == textdraw8 and textdraw8_res then
		if hud.hzgsettings.hptext.toggle[1] then
			setSampfuncsGlobalVar("hptext", data.text)
		else
			setSampfuncsGlobalVar("hptext", data.text)
			data.text = ''
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.hptext.color)
		end)
		return {id, data}
	end
	
	local textdraw9_res, textdraw9 = getSampfuncsGlobalVar("textdraw9")
	if id == (textdraw9 or 2053) and textdraw9_res then
		if hud.hzgsettings.armortext.toggle[1] then
			setSampfuncsGlobalVar("armortext", data.text)
		else
			setSampfuncsGlobalVar("armortext", data.text)
			data.text = ''
		end
		lua_thread.create(function() 
			wait(1)
			sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.armortext.color)
		end)
		return {id, data}
	end
end

function sampev.onTextDrawSetString(id, text)
	local posX, posY = sampTextdrawGetPos(id)
	if posX == 86 and (posY == 434 or math.floor(posY) == 424) and not textdrawbool[1] then
		setSampfuncsGlobalVar("textdraw1", id)
		textdrawbool[1] = true
	end
	
	if posX == 577 and posY == 24 and not textdrawbool[3] then
		setSampfuncsGlobalVar("textdraw3", id)
		textdrawbool[3] = true
	end

	if (posX == 577 or posX == 611) and posY == 65 and not textdrawbool[8] then 
		setSampfuncsGlobalVar("textdraw8", id)
		textdrawbool[8] = true
	end
	if (posX == 577 or posX == 611) and posY == 43 and not textdrawbool[9] then 
		setSampfuncsGlobalVar("textdraw9", id)
		textdrawbool[9] = true
	end

	local textdraw1_res, textdraw1 = getSampfuncsGlobalVar("textdraw1")
	if id == textdraw1 and textdraw1_res then
		if hud.hzgsettings.turf.toggle[1] then
			setSampfuncsGlobalVar("turftext", text)
			autosave.turftext = text
			text = text
		else	
			setSampfuncsGlobalVar("turftext", text)
			autosave.turftext = text
			text = ''
		end
		return {id, text}
	end
	
	local textdraw3_res, textdraw3 = getSampfuncsGlobalVar("textdraw3")
	if id == textdraw3 and textdraw3_res then
		if hud.hzgsettings.wristwatch.toggle[1] then
			autosave.wwtext = text
			text = text
		else
			autosave.wwtext = text
			text = ''
		end
		return {id, text}
	end
	
	local textdraw8_res, textdraw8 = getSampfuncsGlobalVar("textdraw8")
	if id == textdraw8 and textdraw8_res then
		if hud.hzgsettings.hptext.toggle[1] then
			setSampfuncsGlobalVar("hptext", text)
		else
			setSampfuncsGlobalVar("hptext", text)
			text = ''
		end
		return {id, text}
	end
	
	local textdraw9_res, textdraw9 = getSampfuncsGlobalVar("textdraw9")
	if id == (textdraw9 or 2053) and textdraw9_res then
		if hud.hzgsettings.armortext.toggle[1] then
			setSampfuncsGlobalVar("armortext", text)
		else
			setSampfuncsGlobalVar("armortext", text)
			text = ''
		end
		return {id, text}
	end
end

function hztextdraws(id)
	for i = 0, 4000 do
		if sampTextdrawIsExists(i) then
			local posX, posY = sampTextdrawGetPos(i)	
			local box, bcolor, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(i)
			local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(i)
			local text = sampTextdrawGetString(i)
			local textdraw1_res, textdraw1 = getSampfuncsGlobalVar("textdraw1")
			if i == textdraw1 and textdraw1_res and id == 0 then
				sampTextdrawSetPos(i, hud.hzgsettings.turf.pos[1], hud.hzgsettings.turf.pos[2])
				if hud.hzgsettings.turf.toggle[1] then
					sampTextdrawSetString(i, autosave.turftext)
				else
					sampTextdrawSetString(i, '')
				end
			end
			local textdraw2_res, textdraw2 = getSampfuncsGlobalVar("textdraw2")
			if i == textdraw2 and textdraw2_res and id == 1 then
				sampTextdrawSetPos(i, hud.hzgsettings.turfowner.pos[1], hud.hzgsettings.turfowner.pos[2])
				sampTextdrawSetLetterSizeAndColor(i, letSizeX, letSizeY, hud.hzgsettings.turfowner.color)
				if hud.hzgsettings.turfowner.toggle[1] then
					sampTextdrawSetString(i, 'TURF OWNER:')
				else	
					sampTextdrawSetString(i, '')
				end
			end
			local textdraw3_res, textdraw3 = getSampfuncsGlobalVar("textdraw3")
			if i == textdraw3 and textdraw3_res and id == 2 then
				sampTextdrawSetPos(i, hud.hzgsettings.wristwatch.pos[1], hud.hzgsettings.wristwatch.pos[2])
				sampTextdrawSetLetterSizeAndColor(i, letSizeX, letSizeY, hud.hzgsettings.wristwatch.color)
				if hud.hzgsettings.wristwatch.toggle[1] then
					sampTextdrawSetString(i, autosave.wwtext)
				else
					sampTextdrawSetString(i, '')
				end
			end
			local textdraw4_res, textdraw4 = getSampfuncsGlobalVar("textdraw4")
			if i == textdraw4 and textdraw4_res and id == 3 then
				sampTextdrawSetPos(i, hud.hzgsettings.hzglogo.pos[1], hud.hzgsettings.hzglogo.pos[2])
				sampTextdrawSetLetterSizeAndColor(i, letSizeX, letSizeY, hud.hzgsettings.hzglogo.color)
				if hud.hzgsettings.hzglogo.toggle[1] then
					sampTextdrawSetString(i, hud.hzgsettings.hzglogo.toggle[2] and hud.hzgsettings.hzglogo.customstring or 'hzgaming.net')
				else
					sampTextdrawSetString(i, '')
				end
			end
			
			if math.floor(posX) == 610 and math.floor(posY) == 68 and id == 4 then
				sampTextdrawSetBoxColorAndSize(i, box, hud.hzgsettings.hpbar.color1, sizeX, sizeY)
				if hud.hzgsettings.hpbar.toggle[1] then
					sampTextdrawSetString(i, '')
				else
					sampTextdrawSetString(i, '')
				end
			end
			if math.floor(posX) == 608 and math.floor(posY) == 70 and id == 4 then 
				sampTextdrawSetBoxColorAndSize(i, box, hud.hzgsettings.hpbar.color2, sizeX, sizeY)
				if hud.hzgsettings.hpbar.toggle[1] then
					sampTextdrawSetString(i, '')
				else
					sampTextdrawSetString(i, '')
				end
			end
			if math.floor(posX) <= 608 and math.floor(posY) == 70 and id == 4 then 
				sampTextdrawSetBoxColorAndSize(i, box, hud.hzgsettings.hpbar.color3, sizeX, sizeY)
				if hud.hzgsettings.hpbar.toggle[1] then
					sampTextdrawSetString(i, '')
				else
					sampTextdrawSetString(i, '')
				end
			end
			
			local textdraw8_res, textdraw8 = getSampfuncsGlobalVar("textdraw8")
			if i == textdraw8 and textdraw8_res and id == 5 then
				sampTextdrawSetLetterSizeAndColor(i, letSizeX, letSizeY, hud.hzgsettings.hptext.color)
				if hud.hzgsettings.hptext.toggle[1] then
					local hptext_res, hptext = getSampfuncsGlobalVar("hptext")
					if hptext_res then
						sampTextdrawSetString(i, hptext)
					end
				else
					sampTextdrawSetString(i, '')
				end
			end
			
			local textdraw9_res, textdraw9 = getSampfuncsGlobalVar("textdraw9")
			if i == (textdraw9 or 2053) and textdraw9_res and id == 6 then
				sampTextdrawSetLetterSizeAndColor(i, letSizeX, letSizeY, hud.hzgsettings.armortext.color)
				if not text then
					sampTextdrawSetString(i, 0)
				end
				if hud.hzgsettings.armortext.toggle[1] then
					local armortext_res, armortext = getSampfuncsGlobalVar("armortext")
					if armortext_res then
						sampTextdrawSetString(i, armortext)
					end
				else
					sampTextdrawSetString(i, '')
				end
			end
		end
	end
end

function onScriptTerminate(scr, quitGame) 
	if scr == script.this then 
		for i = 1, 4 do
			removeBlip(assets.compass[i])
		end
		showCursor(false)
		if hud.autosave then saveIni_hud() end 
		saveIni_autosave()
	end
end

function blankIni_hud()
	blankini = true
	hud = table.deepcopy(blank_hud)
	saveIni_hud()
	loadIni_hud()
end

function loadIni_hud() 
	local f = io.open(cfg_hud, "r") 
	if f then 
		hud = decodeJson(f:read("*all")) 
		f:close() 
	end
end

function saveIni_hud()
	if type(hud) == "table" then 
		local f = io.open(cfg_hud, "w") 
		f:close() 
		if f then 
			local f = io.open(cfg_hud, "r+") 
			f:write(encodeJson(hud,false)) 
			f:close() 
		end 
	end 
end

function blankIni_autosave()
	autosave = table.deepcopy(blank_autosave)
	saveIni_autosave()
	loadIni_autosave()
end

function loadIni_autosave() 
	local f = io.open(cfg_autosave, "r") 
	if f then 
		autosave = decodeJson(f:read("*all")) 
		f:close() 
	end
end

function saveIni_autosave()
	if type(autosave) == "table" then 
		local f = io.open(cfg_autosave, "w") 
		f:close() 
		if f then 
			local f = io.open(cfg_autosave, "r+") 
			f:write(encodeJson(autosave,false)) 
			f:close() 
		end 
	end 
end

function update_script()
	downloadUrlToFile(update_url, getWorkingDirectory()..'/'..string.lower(script.this.name)..'.txt', function(id, status)
		if status == dlstatus.STATUS_ENDDOWNLOADDATA then
			update_text = https.request(update_url)
			update_version = update_text:match("version: (.+)")
			if tonumber(update_version) > script_version then
				sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} New version found! The update is in progress..", script.this.name), -1)
				downloadUrlToFile(script_url, script_path, function(id, status)
					if status == dlstatus.STATUS_ENDDOWNLOADDATA then
						sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} The update was successful!", script.this.name), -1)
						update = true
					end
				end)
			end
		end
	end)
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

function hudmove()
	if menu[0] then 
		x, y = getCursorPos()
		if move then	
			for k, v in ipairs(hud.pos) do
				if v.move then
					if isKeyJustPressed(VK_LBUTTON) then 
						inuse = false
						move = false
						v.move = false 
					else 
						v.x = x 
						v.y = y
					end
				end
			end
		else
			for k, v in ipairs(hud.pos) do
				if x >= v.x and x <= v.x + 15 and y >= v.y and y <= v.y + 15 then 
					if isKeyJustPressed(VK_LBUTTON) and not inuse then 
						inuse = true 
						selectedbox[k] = true 
					end
				end
				if selectedbox[k] then
					if wasKeyReleased(VK_LBUTTON) then
						inuse = false 
						selectedbox[k] = false
					else
						v.x = x
						v.y = y
					end
				end
			end
			
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
	imgui.Text(title) 
	
	imgui.SameLine(155) 
	imgui.Text('Font') 
	
	imgui.SameLine(255) 
	imgui.Text('Groups') 
	
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
		createfont(i, 1) 
		if i == 6 then 
			createfont(i, 2) 
		end
		if i == 8 then 
			for v = 2, 11 do 
				createfont(i, v) 
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

function fixwidth()
	if getMoonloaderVersion() <= 26 then
		if not doesFileExist(cleopath .. '\\FixWIDTH.cs') then 
			downloadUrlToFile(fixwidth_url, cleopath .. '\\FixWIDTH.cs', function(id, status)
				if status == dlstatus.STATUS_ENDDOWNLOADDATA then
					print(string.format("{ABB2B9}[%s]{FFFFFF} FixWIDTH Downloaded!", script.this.name))
					runSampfuncsConsoleCommand("cs fixWIDTH.cs")
				end
			end)
		end
	end
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
	else
		writeMemory(8751632, 4, representFloatAsInt(posX), true);
		writeMemory(8809328, 4, representFloatAsInt(posY), true);
		writeMemory(8809332, 4, representFloatAsInt(sizeX), true);
		writeMemory(8809336, 4, representFloatAsInt(sizeY), true);
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
		{"Fire Truck", "FIRETRK"},
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
		{"Landstalker", "LANDSTK"},
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

-- IMGUI_API bool          CustomButton(const char* label, const ImVec4& col, const ImVec4& col_focus, const ImVec4& col_click, const ImVec2& size = ImVec2(0,0));
function imgui.CustomButton(name, color, colorHovered, colorActive, size)
    local clr = imgui.Col
    imgui.PushStyleColor(clr.Button, color)
    imgui.PushStyleColor(clr.ButtonHovered, colorHovered)
    imgui.PushStyleColor(clr.ButtonActive, colorActive)
    if not size then size = imgui.ImVec2(0, 0) end
    local result = imgui.Button(name, size)
    imgui.PopStyleColor(3)
    return result
end

function apply_custom_style()
	imgui.SwitchContext()
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2
	local style = imgui.GetStyle()
	style.WindowRounding = 0
	style.WindowPadding = ImVec2(8, 8)
	style.WindowTitleAlign = ImVec2(0.5, 0.5)
	--style.ChildWindowRounding = 0
	style.FrameRounding = 0
	style.ItemSpacing = ImVec2(8, 4)
	style.ScrollbarSize = 10
	style.ScrollbarRounding = 3
	style.GrabMinSize = 10
	style.GrabRounding = 0
	style.Alpha = 1
	style.FramePadding = ImVec2(4, 3)
	style.ItemInnerSpacing = ImVec2(4, 4)
	style.TouchExtraPadding = ImVec2(0, 0)
	style.IndentSpacing = 21
	style.ColumnsMinSpacing = 6
	style.ButtonTextAlign = ImVec2(0.5, 0.5)
	style.DisplayWindowPadding = ImVec2(22, 22)
	style.DisplaySafeAreaPadding = ImVec2(4, 4)
	style.AntiAliasedLines = true
	--style.AntiAliasedShapes = true
	style.CurveTessellationTol = 1.25
	local colors = style.Colors
	local clr = imgui.Col
	colors[clr.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
	colors[clr.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
	colors[clr.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
	colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
	colors[clr.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
	colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[clr.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.SliderGrab]             = ImVec4(0.88, 0.26, 0.24, 1.00)
	colors[clr.SliderGrabActive]       = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
	colors[clr.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
	colors[clr.Header]                 = ImVec4(0.98, 0.26, 0.26, 0.31)
	colors[clr.HeaderHovered]          = ImVec4(0.98, 0.26, 0.26, 0.80)
	colors[clr.HeaderActive]           = ImVec4(0.98, 0.26, 0.26, 1.00)
	colors[clr.Separator]              = colors[clr.Border]
	colors[clr.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
	colors[clr.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
	colors[clr.ResizeGrip]             = ImVec4(0.98, 0.26, 0.26, 0.25)
	colors[clr.ResizeGripHovered]      = ImVec4(0.98, 0.26, 0.26, 0.67)
	colors[clr.ResizeGripActive]       = ImVec4(0.98, 0.26, 0.26, 0.95)
	colors[clr.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
	colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
	--colors[clr.ChildWindowBg]          = ImVec4(1.00, 1.00, 1.00, 0.00)
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	--colors[clr.ComboBg]                = colors[clr.PopupBg]
	colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	--colors[clr.CloseButton]            = ImVec4(0.41, 0.41, 0.41, 0.50)
	--colors[clr.CloseButtonHovered]     = ImVec4(0.98, 0.39, 0.36, 1.00)
	--colors[clr.CloseButtonActive]      = ImVec4(0.98, 0.39, 0.36, 1.00)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
	--colors[clr.ModalWindowDarkening]   = ImVec4(0.80, 0.80, 0.80, 0.35)
end