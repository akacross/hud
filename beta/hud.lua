script_name("hud")
script_author("akacross")
script_url("https://akacross.net/")

local scriptName = thisScript().name
local scriptVersion = "1.4.23"

-- Requirements
require 'lib.moonloader'
local ffi = require 'ffi'
local effil = require 'effil'
local lfs = require 'lfs'
local mem = require 'memory'
local wm = require 'lib.windows.message'
local imgui = require 'mimgui'
local encoding = require 'encoding'
local sampev = require 'lib.samp.events'
local weapons = require 'game.weapons'
local flag = require 'moonloader'.font_flag
local fa = require 'fAwesome6'
local requests = require 'requests'
local dlstatus = require 'moonloader'.download_status

-- Encoding
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Paths
local scriptPath = thisScript().path
local workingDir = getWorkingDirectory()
local configDir = workingDir .. '\\config\\'
local resourceDir = workingDir .. '\\resource\\'
local cfgPath = configDir .. scriptName .. '\\'
local cfgFolder = cfgPath .. 'configs\\'
local settingsFile = cfgPath .. 'settings.json'
local resourcePath = resourceDir .. scriptName .. '\\'
local iconsPath = resourcePath .. 'weapons\\'

-- URLs
local url = "https://raw.githubusercontent.com/akacross/hud/main/"
local scriptUrl = url .. "hud.lua"
local updateUrl = url .. "hud.txt"
local scriptUrlBeta = url .. "beta/hud.lua"
local updateUrlBeta = url .. "beta/hud.txt"
local iconsUrl = url .. "resource/hud/weapons/"

-- Libs
local ped, h = playerPed, playerHandle
local configsDir = {}
local configExtensions = {json = true, ini = true}
local update_in_process = false
local confirmData = {
    [1] = { id = 'open', name = '', status = false },
    [2] = { id = 'rename', name = '', status = false },
    [3] = { id = 'addNew', name = 'new.json', useCurrent = false, status = false },
    [4] = { id = 'copy', selectedFile = nil, status = false },
    [5] = { id = 'delete', status = false },
    [6] = { id = 'update', status = false }
}

local settings = {}
local settings_defaultSettings = {
    JsonFile = 'hud.json',
    autoupdate = false,
    autosave = false,
    beta = true,
	turftext = '',
	wwtext = ''
}

local hud = {}
local hud_defaultSettings = {
	toggle = true,
	defaulthud = false,
	tog = {
		{true,true,false}, {true,true,true}, {true,true}, {true,true,true,true}, {true,true,true}, {true,true,true,true,true},
		{true,true,true,true}, {{true,false},{true,true},{true},{true,true},{true,true},{true,true},{true},{true},{true,true},{true},{true}}
	},
	groups = {{1,1},{1,1},{1,1},{1,1},{1,1},{1,1,1},{1,1},{6,3,3,4,4,2,2,2,5,5,2}},
	pos = {
		{x = 525, y = 234, name = "Hud", move = false},
		{x = 525, y = 234, name = "Radar", move = false},
		{x = 525, y = 234, name = "Time", move = false},
		{x = 525, y = 234, name = "FPS/Ping", move = false},
		{x = 525, y = 234, name = "Vehicle", move = false},
		{x = 525, y = 234, name = "Name", move = false}
	},
	offx = {{120,183},{120,183},{120,183},{120,183},{120,183},{-1.5,97,56.4},{115,248.6},{0,0,0,0,0,0,0,0,0,0,0}},
	offy = {{80,82},{60,62},{40,42},{20,22},{-0,2},{-8.5,73.5,101.5},{118.8,95.7},{0.0,17.0,33.8,52.0,71.5,90.0,110.0,129.0,146.0,167.0,186.0}},
	sizex = {130,130,130,130,130,115,22},
	sizey = {17,17,17,17,17,115,22},
	border = {1,1,1,1,1},
	spacing = -3,
	font = {
		{"Aerial"}, {"Aerial"}, {"Aerial"}, {"Aerial"}, {"Aerial"},
		{"Aerial","Aerial"}, {"Aerial"},
		{"Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial","Aerial"}
	},
	fontsize = {
		{8},{8},{8},{8},{8},{8,10},{16},{10,10,10,10,10,10,10,10,10,10,10}
	},
	alignfont = {{2},{2},{2},{2},{2},{1,2},{1},{3,3,3,3,3,3,3,3,3,3,3}},
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
	maxvalue = {100,100,100,1000,100},
	serverhp = {5000000,8000000},
	radar = { pos = {10,99}, size = {90,90}, color = -16777216, compass = false },
	hzgsettings = {
		turf = { toggle = {false}, pos = {86, 434} },
		turfowner = { toggle = {false}, pos = {86, 423}, color = 4294967295 },
		wristwatch = { toggle = {false}, pos = {577, 24}, color = 4294967295 },
		hzglogo = { toggle = {true,false}, pos = {562, 3}, color = 4294967295, customstring = 'akacross.net' },
		hpbar = { toggle = {false}, color1 = 4278190080, color2 = 4284091408, color3 = 4290058273 },
		hptext = { toggle = {false}, color = 4294967295 },
		armortext = { toggle = {false}, color = 4294967295 }
	}
}

local value = nil
local fps = 0
local fps_counter = 0
local currentRadarPosX, currentRadarPosY, currentRadarSizeX, currentRadarSizeY = nil, nil, nil, nil
local currentRadarColor = nil
local assets = {
    temp_pos = {x = 0, y = 0},
	weapTextures = nil,
	fontId = nil,
	maxVehHPIds = {427,528,601},
	miscNames = {'Name','Local-Time','Server-Time','Ping','FPS','Direction','Location','Turf','Vehicle Speed','Vehicle Name','Badge'},
	compassId = {},
	badgeNames = {
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

local spec = {
	playerid = -1,
	state = false
}

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local menu = {
    settings = new.bool(false),
    confirm = new.bool(false)
}
local mid = 1
local dragging = {}
local move = false
local inuse = false
local selectedbox = {}
local selected = {}

local compassData = {
    {x = 0.0, y = 999999.0, z = 23.0, id = 24}, --  N
    {x = 999999.0, y = 0.0, z = 23.0, id = 34}, -- S
    {x = -999999.0, y = 0.0, z = 23.0, id = 46}, -- W
    {x = 0.0, y = -999999.0, z = 23.0, id = 38} -- E
}

local directionData = {
    {min = 0, max = 22, direction = "North"},
    {min = 23, max = 67, direction = "Northwest"},
    {min = 68, max = 112, direction = "West"},
    {min = 113, max = 157, direction = "Southwest"},
    {min = 158, max = 202, direction = "South"},
    {min = 203, max = 247, direction = "Southeast"},
    {min = 248, max = 292, direction = "East"},
    {min = 293, max = 329, direction = "Northeast"},
    {min = 330, max = 360, direction = "North"}
}

local zones = {
    names = {
        {'IWD','Idlewood'}, {'JEF','Jefferson'}, {'GAN','Ganton'}, {'GANTB','Gant Bridge'}, {'LIND','Willowfield'},
        {'LMEX','Little Mexico'}, {'COM','Commerce'}, {'VERO','Verona Beach'}, {'MKT','Market'}, {'MARKST','Market Station'},
        {'CONF','Conference Center'}, {'BLUF','Verdant Bluffs'}, {'LAIR','Los Santos International'}, {'LA','Los Santos'},
        {'ELCO','El Corona'}, {'PER1','Pershing Square'}, {'MAR','Marina'}, {'VIN','Vinewood'}, {'ROD','Rodeo'},
        {'RIH','Richman'}, {'SMB','Santa Maria Beach'}, {'LDT','Downtown Los Santos'}, {'GLN','Glen Park'}, {'VISA','The Visage'},
        {'HGP','Harry Gold Parkway'}, {'FRED','Frederick Bridge'}, {'RED','Red County'}, {'FISH','Fisher\'s Lagoon'},
        {'MONT','Montgomery'}, {'MONINT','Montgomery Intersection'}, {'MUL','Mulholland'}, {'MULINT','Mulholland Intersection'},
        {'SUN','Temple'}, {'ELS','East Los Santos'}, {'CHC','Las Colinas'}, {'LDOC','Ocean Docks'}, {'DILLI','Dillimore'},
        {'TOPFA','Hilltop Farm'}, {'FARM','The Farm'}, {'FLINTR','Flint Range'}, {'FLINW','Flint Water'}, {'FLINTC','Flint County'},
        {'FLINTI','Flint Intersection'}, {'LEAFY','Leafy Hollow'}, {'BACKO','Back O Beyond'}, {'WHET','Whetstone'}, {'CREEK','Shady Creeks'},
        {'MTCHI','Mount Chiliad'}, {'ANGPI','Angel Pine'}, {'LSINL','Los Santos Inlet'}, {'SAN_AND','San Andreas'},
        {'BLUEB','Blueberry'}, {'BLUAC','Blueberry Acres'}, {'PANOP','The Panopticon'}, {'EBAY','Easter Bay Chemicals'},
        {'FERN','Fern Ridge'}, {'PALO','Palomino Creek'}, {'HANKY','Hankypanky Point'}, {'SASO','San Andreas Sound'},
        {'HAUL','Fallen Tree'}, {'SF','San Fierro'}, {'VE','Las Venturas'}, {'SFAIR','Easter Bay Airport'}, {'ETUNN','Easter Tunnel'},
        {'SILLY','Foster Valley'}, {'HILLP','Missionary Hill'}, {'CUNTC','Avispa Country Club'}, {'OCEAF','Ocean Flats'},
        {'HASH','Hashbury'}, {'GARC','Garcia'}, {'DOH','Doherty'}, {'CRANB','Cranberry Station'}, {'EASB','Easter Basin'},
        {'SFDWT','Downtown'}, {'THEA','King\'s'}, {'WESTP','Queens'}, {'CITYS','City Hall'}, {'BAYV','Palisades'},
        {'CIVI','Santa Flora'}, {'JUNIHI','Juniper Hill'}, {'JUNIHO','Juniper Hollow'}, {'ESPN','Esplanade North'},
        {'ESPE','Esplanade East'}, {'KINC','Kincaid Bridge'}, {'GARV','Garver Bridge'}, {'BATTP','Battery Point'},
        {'GANTB','Gant Bridge'}, {'CALT','Calton Heights'}, {'FINA','Financial'}, {'CHINA','Chinatown'}, {'PARA','Paradiso'},
        {'MAKO','The Mako Span'}, {'RIE','Randolph Industrial Estate'}, {'JTS','Julius Thruway South'}, {'JTE','Julius Thruway East'},
        {'JTW','Julius Thruway West'}, {'JTN','Julius Thruway North'}, {'RSE','Rockshore East'}, {'RSW','Rockshore West'},
        {'LDM','Last Dime Motel'}, {'BFLD','Blackfield'}, {'BINT','Blackfield Intersection'}, {'BFC','Blackfield Chapel'},
        {'DRAG','The Four Dragons Casino'}, {'SRY','Sobell Rail Yards'}, {'LST','Linden Station'}, {'LINDEN','Linden Station'},
        {'QUARY','Hunter Quarry'}, {'FALLO','Fallow Bridge'}, {'LDS','Linden Side'}, {'CAM','The Camel\'s Toe'},
        {'LOT','Come-A-Lot'}, {'STRIP','The Strip'}, {'HIGH','The High Roller'}, {'PINK','The Pink Swan'}, {'ROY','Royal Casino'},
        {'CALI','Caligula\'s Palace'}, {'PILL','Pilgrim'}, {'STAR','Starfish Casino'}, {'OVS','Old Venturas Strip'},
        {'RING','The Clown\'s Pocket'}, {'CREE','Creek'}, {'ROCE','Roca Escalante'}, {'ISLE','The Emerald Isle'},
        {'REDE','Redsands East'}, {'REDW','Redsands West'}, {'GGC','Greenglass College'}, {'KACC','K.A.C.C. Military Fuels'},
        {'ELCA','El Castillo Del Diablo'}, {'PAYAS','Las Payasadas'}, {'ROBAD','Tierra Robada'}, {'BYTUN','Bayside Tunnel'},
        {'REST','Area 69'}, {'WWE','Whitewood Estates'}, {'VAIR','Las Venturas Airport'}, {'SPIN','Spinybed'},
        {'PRP','Prickle Pine'}, {'PALMS','Green Palms'}, {'OCTAN','Octane Springs'}, {'PROBE','Lil\' Probe Inn'},
        {'CARSO','Fort Carson'}, {'BIGE','The Big Ear'}, {'TOM','Regular Tom'}, {'BRUJA','Las Brujas'},
        {'ARCO','Arco Del Oeste'}, {'DAM','The Sherman Dam'}, {'SHERR','Sherman Reservoir'}, {'BARRA','Las Barrancas'},
        {'MART','Martin Bridge'}, {'ROBINT','Robada Intersection'}, {'ELQUE','El Quebrados'}, {'ALDEA','Aldea Malvada'},
        {'SUNMA','Bayside Marina'}, {'SUNNN','Bayside'}, {'SANB','San Fierro Bay'}, {'YBELL','Yellow Bell Golf Course'},
        {'PINT','Pilson Intersection'}, {'PIRA','Pirates In Men\'s Pants'}, {'LVA','LVA Freight Depot'}, {'BONE','Bone County'},
        {'MEAD','Verdant Meadows'}, {'PLS','Playa Del Seville'}, {'EBE','East Beach'}, {'LFL','Los Flores'},
        {'NROCK','North Rock'}, {'UNITY','Unity Station'}
    },
    custom = {
        ["Castille Island"] = {3138.7588, -2248.6106, -63.2630, 3530.0903, -1922.0083, 343.3367},
        ["ARES Garage"] = {2204.1096, 2411.6570, -13.5870, 2329.5793, 2512.3259, 0.4885},
        ["FBI Garage"] = {248.1156,-1549.7271,22.9225, 370.9664, -1456.6969, 30.3469}
    }
}

local vehNames = {
    "Landstalker", "Bravura", "Buffalo", "Linerunner", "Perrenial", "Sentinel", "Dumper", "Firetruck", "Trashmaster", "Stretch", "Manana", "Infernus",
    "Voodoo", "Pony", "Mule", "Cheetah", "Ambulance", "Leviathan", "Moonbeam", "Esperanto", "Taxi", "Washington", "Bobcat", "Whoopee", "BFInjection", "Hunter",
    "Premier", "Enforcer", "Securicar", "Banshee", "Predator", "Bus", "Rhino", "Barracks", "Hotknife", "Trailer", "Previon", "Coach", "Cabbie", "Stallion", "Rumpo",
    "RCBandit", "Romero","Packer", "Monster", "Admiral", "Squalo", "Seasparrow", "Pizzaboy", "Tram", "Trailer", "Turismo", "Speeder", "Reefer", "Tropic", "Flatbed",
    "Yankee", "Caddy", "Solair", "Berkley'sRCVan", "Skimmer", "PCJ-600", "Faggio", "Freeway", "RCBaron", "RCRaider", "Glendale", "Oceanic", "Sanchez", "Sparrow",
    "Patriot", "Quad", "Coastguard", "Dinghy", "Hermes", "Sabre", "Rustler", "ZR-350", "Walton", "Regina", "Comet", "BMX", "Burrito", "Camper", "Marquis", "Baggage",
    "Dozer", "Maverick", "NewsChopper", "Rancher", "FBIRancher", "Virgo", "Greenwood", "Jetmax", "Hotring", "Sandking", "BlistaCompact", "PoliceMaverick",
    "Boxvillde", "Benson", "Mesa", "RCGoblin", "HotringRacerA", "HotringRacerB", "BloodringBanger", "Rancher", "SuperGT", "Elegant", "Journey", "Bike",
    "MountainBike", "Beagle", "Cropduster", "Stunt", "Tanker", "Roadtrain", "Nebula", "Majestic", "Buccaneer", "Shamal", "hydra", "FCR-900", "NRG-500", "HPV1000",
    "CementTruck", "TowTruck", "Fortune", "Cadrona", "FBITruck", "Willard", "Forklift", "Tractor", "Combine", "Feltzer", "Remington", "Slamvan", "Blade", "Freight",
    "Streak", "Vortex", "Vincent", "Bullet", "Clover", "Sadler", "Firetruck", "Hustler", "Intruder", "Primo", "Cargobob", "Tampa", "Sunrise", "Merit", "Utility", "Nevada",
    "Yosemite", "Windsor", "Monster", "Monster", "Uranus", "Jester", "Sultan", "Stratum", "Elegy", "Raindance", "RCTiger", "Flash", "Tahoma", "Savanna", "Bandito",
    "FreightFlat", "StreakCarriage", "Kart", "Mower", "Dune", "Sweeper", "Broadway", "Tornado", "AT-400", "DFT-30", "Huntley", "Stafford", "BF-400", "NewsVan",
    "Tug", "Trailer", "Emperor", "Wayfarer", "Euros", "Hotdog", "Club", "FreightBox", "Trailer", "Andromada", "Dodo", "RCCam", "Launch", "PoliceCar", "PoliceCar",
    "PoliceCar", "PoliceRanger", "Picador", "S.W.A.T", "Alpha", "Phoenix", "GlendaleShit", "SadlerShit", "Luggage A", "Luggage B", "Stairs", "Boxville", "Tiller",
    "UtilityTrailer"
}

 ffi.cdef
[[
    void *malloc(size_t size);
]]

local function handleConfigFile(path, defaults, configVar)
    if doesFileExist(path) then
        local config, err = loadConfig(path)
        if not config then
            print("Error loading config: " .. err)

            local newpath = path:gsub("%.[^%.]+$", ".bak")
            local success, err2 = os.rename(path, newpath)
            if not success then
                print("Error renaming config: " .. err2)
                os.remove(path)
            end
            handleConfigFile(path, defaults, configVar)
        else
            local result = ensureDefaults(config, defaults, false, {"pos", "serverhp"})
            if result then
                local success, err3 = saveConfig(path, config)
                if not success then
                    print("Error saving config: " .. err3)
                end
            end
            return config
        end
    else
        local result = ensureDefaults(configVar, defaults, true)
        if result then
            local success, err = saveConfig(path, configVar)
            if not success then
                print("Error saving config: " .. err)
            end
        end
    end
    return configVar
end

local function createHudUpdateThread()
    lua_thread.create(function()
        while true do wait(15)
            changeRadarPosAndSize(hud.radar.pos[1], hud.radar.pos[2], hud.radar.size[1], hud.radar.size[2])
            changeRadarColor(hud.radar.color)
            hudValues()
            hudMove()
        end
    end)
end

local function createFpsUpdateThread()
    lua_thread.create(function()
        while true do wait(1000)
            fps = fps_counter
            fps_counter = 0
        end
    end)
end

local function initializeHud()
    displayHud(hud.defaulthud)
    loadFonts()
    loadTextures()
    setMaxHP(hud.tog[1][3])
    setRadarCompass(hud.radar.compass)
    for i = 0, 6 do hztextdraws(i) end
end

function main()
    for _, dir in ipairs({configDir, resourceDir, cfgPath, cfgFolder, resourcePath, iconsPath}) do createDirectory(dir) end
    settings = handleConfigFile(settingsFile, settings_defaultSettings, settings)
    hud = handleConfigFile(cfgFolder .. settings.JsonFile, hud_defaultSettings, hud)

    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("hud", function()
        if update_in_process then
            formattedAddChatMessage("Update in progress. Please wait a moment.", -1)
            return
        end
        menu.settings[0] = not menu.settings[0]
    end)

    hudWidthFix()

    local files = {}
    for i = 0, 48 do
        if i < 19 or i > 21 then
            table.insert(files, {url = iconsUrl .. i .. ".png", path = iconsPath .. i .. ".png", replace = false})
        end
    end
    downloadFiles(files, function(result)
        if result then
            formattedAddChatMessage("All files downloaded successfully!", -1)
        end
        initializeHud()
    end)

    createHudUpdateThread()
    createFpsUpdateThread()

    if settings.autoupdate then checkForUpdate() end
    wait(-1)
end

local function getRenderPosition(i, index)
    local pos = hud.pos[hud.groups[i][index]]
    if not pos then pos = hud.pos[1] end
    local posX = pos.x + hud.offx[i][index]
    local posY = pos.y + hud.offy[i][index]
    return posX, posY
end

local function renderHudElement(i)
    if not value then return end
    if hud.tog[i][1] and value[i][1] then
        if not assets.weapTextures then return end
        local x, y = getRenderPosition(i, 1)
        if i <= 5 then
            renderBar(i, x, y, hud.sizex[i], hud.sizey[i], value[i][1], hud.maxvalue[i], hud.border[i], hud.color[i][1][1], hud.color[i][1][2], hud.color[i][1][3])
        elseif i == 6 then
            renderWeap(x, y, hud.sizex[i], hud.sizey[i], value[i][1], hud.color[i][1][1], hud.color[i][1][2])
        elseif i == 7 then
            renderStar(x, y, hud.sizex[i], hud.sizey[i], value[i][1], hud.spacing, hud.color[i][1][1])
        end
    end

    if assets.fontId then
        if hud.tog[i][2] and value[i][(i == 6 or i == 7) and 2 or 1] and assets.fontId[i][1] then
            local x, y = getRenderPosition(i, 2)
            renderFont(x, y, assets.fontId[i][1], value[i][(i == 6 or i == 7) and 2 or 1], hud.alignfont[i][1], hud.color[i][2])
        end

        if i == 6 and hud.tog[i][3] and value[i][3] and assets.fontId[i][2] then
            local x, y = getRenderPosition(i, 3)
            renderFont(x, y, assets.fontId[i][2], value[i][3], hud.alignfont[i][2], hud.color[i][3])
        end
    end
end

local function renderDynamicHudElements(i)
    if not value then return end
    for v = 1, 11 do
        if hud.tog[i][v][1] and assets.fontId and value[i][v] then
            local x, y = getRenderPosition(i, v)
            renderFont(x, y, assets.fontId[i][v], value[i][v], hud.alignfont[i][v], hud.color[i][v])
        end
    end
end

local function shouldRenderElement(i)
    if not value then return end
    return i == 1
		or i == 2 and (value[i][1] > 0 or hud.tog[i][3])
        or i == 3
        or i == 4 and (menu.settings[0] or isCharInAnyCar(ped) or hud.tog[i][3] or spec.state)
        or i == 5 and (menu.settings[0] or isCharInWater(ped) or hud.tog[i][3])
        or i == 6 or i == 7
end

function onD3DPresent()
    fps_counter = fps_counter + 1
    if isPauseMenuActive() or sampIsScoreboardOpen() or sampGetChatDisplayMode() == 0 or isKeyDown(VK_F10) or not hud.toggle then return end

    for i = 1, 8 do
        if shouldRenderElement(i) then
            renderHudElement(i)
        elseif i == 8 then
            renderDynamicHudElements(i)
        end
    end

    if menu.settings[0] then
        for _, v in ipairs(hud.pos) do
            renderDrawBox(v.x, v.y, 15, 15, -1)
        end
    end
end

function onWindowMessage(msg, wparam, lparam)
    if wparam == VK_ESCAPE and menu.settings[0] then
        if msg == wm.WM_KEYDOWN then
            consumeWindowMessage(true, false)
        end
        if msg == wm.WM_KEYUP then
            menu.settings[0] = false
        end
    end
end

function sampev.onServerMessage(color, text)
	if text:find("turns off their wristwatch.") then
		settings.wwtext = ''
	end

	if text:find("You have toggled off turfs on your radar/map.") then
		settings.turftext = ''
	end
end

function sampev.onTogglePlayerSpectating(state)
    if not state then
        spec.playerid = -1
    end
    spec.state = state
end

function sampev.onSendCommand(command)
    local cmd = command:match("^/spec (.-)$")
    if cmd and string.len(cmd) >= 1 then
        if cmd:find('^%d+') then
            spec.playerid = tonumber(cmd)
        else
            local res, id, _ = getTarget(cmd)
            if res then
                spec.playerid = id
            end
        end
    end
end

local function handleTurfTextDraw(id, data)
    if tostring(data.letterWidth) == "0.23999999463558" and tostring(data.letterHeight) == "1.2000000476837" and data.text ~= "TURF OWNER:" then
        if hud.hzgsettings.turf.toggle[1] then
            settings.turftext = data.text
            data.position.x = hud.hzgsettings.turf.pos[1]
            data.position.y = hud.hzgsettings.turf.pos[2]
        else
            settings.turftext = data.text
            data.position.x = -100
            data.position.y = -100
        end
        return true, {id, data}
    elseif tostring(data.letterWidth) == "0.23999999463558" and tostring(data.letterHeight) == "1.2000000476837" and data.text == "TURF OWNER:" then
        if hud.hzgsettings.turfowner.toggle[1] then
            data.position.x = hud.hzgsettings.turfowner.pos[1]
            data.position.y = hud.hzgsettings.turfowner.pos[2]
        else
            data.position.x = -100
            data.position.y = -100
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.turfowner.color)
        end)
        return true, {id, data}
    end
    return false, data
end

local function handleWristwatchTextDraw(id, data)
    if tostring(data.letterWidth) == "0.5" and tostring(data.letterHeight) == "2" and data.text:match("%W") then
        if hud.hzgsettings.wristwatch.toggle[1] then
            settings.wwtext = data.text
            data.position.x = hud.hzgsettings.wristwatch.pos[1]
            data.position.y = hud.hzgsettings.wristwatch.pos[2]
        else
            settings.wwtext = data.text
            data.position.x = -100
            data.position.y = -100
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.wristwatch.color)
        end)
        return true, {id, data}
    end
    return false, data
end

local function handleHZGLogoTextDraw(id, data)
    if tostring(data.letterWidth) == "0.3199990093708" and tostring(data.letterHeight) == "1.3999999761581" then
        if hud.hzgsettings.hzglogo.toggle[1] then
            data.text = hud.hzgsettings.hzglogo.toggle[2] and hud.hzgsettings.hzglogo.customstring or 'hzgaming.net'
            data.position.x = hud.hzgsettings.hzglogo.pos[1]
            data.position.y = hud.hzgsettings.hzglogo.pos[2]
        else
            data.position.x = -100
            data.position.y = -100
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.hzglogo.color)
        end)
        return true, {id, data}
    end
    return false, data
end

local function handleHPBarTextDraw(id, data)
    local posX, posY = math.floor(data.position.x), math.floor(data.position.y)
    if posX == 610 and posY == 68 then
        if hud.hzgsettings.hpbar.toggle[1] then
            data.text = ''
        else
            data.text = ''
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color1, 543.75, 0)
        end)
        return true, {id, data}
    elseif posX == 608 and posY == 70 then
        if hud.hzgsettings.hpbar.toggle[1] then
            data.text = ''
        else
            data.text = ''
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color2, 545.75, 0)
        end)
        return true, {id, data}
    elseif posX <= 608 and posY == 70 then
        if hud.hzgsettings.hpbar.toggle[1] then
            data.text = ''
        else
            data.text = ''
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetBoxColorAndSize(id, 1, hud.hzgsettings.hpbar.color3, 545.75, 0)
        end)
        return true, {id, data}
    end
    return false, data
end

local function handleHPAndArmorTextDraw(id, data)
    local posX, posY = data.position.x, data.position.y
    if (posX == 577 or posX == 611) and posY == 65 then
        if not hud.hzgsettings.hptext.toggle[1] then
            data.text = ''
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.hptext.color)
        end)
        return true, {id, data}
    elseif (posX == 577 or posX == 611) and posY == 43 then
        if not hud.hzgsettings.armortext.toggle[1] then
            data.text = ''
        end
        lua_thread.create(function()
            wait(1)
            sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, hud.hzgsettings.armortext.color)
        end)
        return true, {id, data}
    end
    return false, data
end

function sampev.onShowTextDraw(id, data)
    local handlers = {
        handleTurfTextDraw,
        handleWristwatchTextDraw,
        handleHZGLogoTextDraw,
        handleHPBarTextDraw,
        handleHPAndArmorTextDraw
    }

    for _, handler in ipairs(handlers) do
        local handled, result = handler(id, data)
        if handled then
            return result
        end
    end
end

function sampev.onTextDrawSetString(id, text)
    local posX, posY = sampTextdrawGetPos(id)
    local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(id)

    if tostring(letSizeX) == "0.23999999463558" and tostring(letSizeY) == "1.2000000476837" and text ~= "TURF OWNER:" then
        settings.turftext = text
        hud.color[8][8] = color
    end

    if tostring(letSizeX) == "0.5" and tostring(letSizeY) == "2" and text:match("%W") then
        settings.wwtext = text
    end

    if tostring(letSizeX) == "0.25999900698662" and tostring(letSizeY) == "1.2000000476837" and (posX == 577 or posX == 611) and posY == 65 then
        if not hud.hzgsettings.hptext.toggle[1] then
            text = ''
        end
        return {id, text}
    end

    if tostring(letSizeX) == "0.25999900698662" and tostring(letSizeY) == "1.2000000476837" and (posX == 577 or posX == 611) and posY == 43 then
        if not hud.hzgsettings.armortext.toggle[1] then
            text = ''
        end
        return {id, text}
    end
end

function onScriptTerminate(scr, quitGame)
	if scr == script.this then
		setRadarCompass(false)
		showCursor(false)
		if settings.autosave then
            local success, err = saveConfig(cfgFolder .. settings.JsonFile, hud)
            if not success then
                print("Error saving config: " .. err)
            end
        end
		local success, err = saveConfig(settingsFile, settings)
        if not success then
            print("Error saving config: " .. err)
        end
	end
end

--ImGUI
imgui.OnInitialize(function()
	apply_custom_style() -- apply custom style

	scanGameFolder(cfgFolder, configsDir)

	local config = imgui.ImFontConfig()
	config.MergeMode = true
    config.PixelSnapH = true
    config.GlyphMinAdvanceX = 14
    local builder = imgui.ImFontGlyphRangesBuilder()
    local list = {
		"GEAR",
		"HEART",
		"SHIELD",
		"PERSON_RUNNING",
		"CAR",
		"MASK_SNORKEL",
		"GUN",
		"GEARS",
		"COMPASS",
		"OBJECT_GROUP",
		"POWER_OFF",
		"FLOPPY_DISK",
		"REPEAT",
		"ERASER",
		"RETWEET",
		"CIRCLE_CHECK",
		"CIRCLE_XMARK"
	}
	for _, b in ipairs(list) do
		builder:AddText(fa(b))
	end
	defaultGlyphRanges1 = imgui.ImVector_ImWchar()
	builder:BuildRanges(defaultGlyphRanges1)
	imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85("regular"), 14, config, defaultGlyphRanges1[0].Data)

	imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(function() return menu.settings[0] end, function()
    local io = imgui.GetIO()
    local center = imgui.ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2)
    local title = string.format("%s %s Settings - Version: %s", fa.GEAR, firstToUpper(scriptName), scriptVersion)
    imgui.SetNextWindowPos(center, imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(title, menu.settings, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)

    imgui.SetCursorPos(imgui.ImVec2(5, 25))
    imgui.BeginChild("##2", imgui.ImVec2(460, 76), false)
        local function customButton(icon, label, x, y, id, color)
            imgui.SetCursorPos(imgui.ImVec2(x, y))
            if imgui.CustomButton(icon .. ' ' .. label, mid == id and imgui.ImVec4(0.56, 0.16, 0.16, 1) or imgui.ImVec4(0.16, 0.16, 0.16, 0.9), imgui.ImVec4(0.40, 0.12, 0.12, 1), imgui.ImVec4(0.30, 0.08, 0.08, 1), imgui.ImVec2(75, 25)) then
                mid = id
            end
        end
        customButton(fa.HEART, 'Health', 81, 5, 1)
        customButton(fa.SHIELD, 'Armor', 81, 31, 2)
        customButton(fa.PERSON_RUNNING, 'Sprint', 157, 5, 3)
        customButton(fa.CAR, 'Vehicle', 157, 31, 4)
        customButton(fa.MASK_SNORKEL, 'Breath', 233, 5, 5)
        customButton(fa.GUN, 'Weapon', 233, 31, 6)
        customButton('', 'Stars/Cash', 309, 5, 7)
        customButton(fa.GEARS, 'Other', 309, 31, 8)
        customButton(fa.COMPASS, 'Screen', 385, 5, 9)
        customButton(fa.OBJECT_GROUP, 'Move', 385, 31, 10)
    imgui.EndChild()

    imgui.SetCursorPos(imgui.ImVec2(5, 25))
    imgui.BeginChild("##1", imgui.ImVec2(85, 392), false)
        local function toggleButton(icon, y, toggle, tooltip, action)
            imgui.SetCursorPos(imgui.ImVec2(5, y))
            if imgui.CustomButton(icon, toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.7) or imgui.ImVec4(1, 0.19, 0.19, 0.5), toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.5) or imgui.ImVec4(1, 0.19, 0.19, 0.3), toggle and imgui.ImVec4(0.15, 0.59, 0.18, 0.4) or imgui.ImVec4(1, 0.19, 0.19, 0.2), imgui.ImVec2(75, 75)) then
                action()
            end
            if imgui.IsItemHovered() then imgui.SetTooltip(tooltip) end
        end
        toggleButton(fa.POWER_OFF, 5, hud.toggle, 'Toggle Interface '.. (not hud.toggle and 'ON' or 'OFF'), function() hud.toggle = not hud.toggle end)
        toggleButton(fa.FLOPPY_DISK, 81, false, 'Save configuration', function()
            local success, err = saveConfig(cfgFolder .. settings.JsonFile, hud)
            if not success then
                print("Error saving config: " .. err)
            end
        end)
        toggleButton(fa.REPEAT, 157, false, 'Reload configuration', function()
            hud = handleConfigFile(cfgFolder .. settings.JsonFile, hud_defaultSettings, hud)
            initializeHud()
        end)
        toggleButton(fa.ERASER, 233, false, 'Load default configuration', function()
            local result = ensureDefaults(hud, hud_defaultSettings, true)
            if result then
                initializeHud()
            end
        end)
        toggleButton(fa.RETWEET .. ' Update', 309, false, 'Check for update', function()
            checkForUpdate()
        end)
    imgui.EndChild()

    imgui.SetCursorPos(imgui.ImVec2(89, 85))
    imgui.BeginChild("##3", imgui.ImVec2(376, 289), true)

    if mid >= 1 and mid <= 7 then
        if imgui.Checkbox(u8'Bar', new.bool(hud.tog[mid][1])) then hud.tog[mid][1] = not hud.tog[mid][1] end
        imgui.SameLine()
        if imgui.Checkbox(u8'Text', new.bool(hud.tog[mid][2])) then hud.tog[mid][2] = not hud.tog[mid][2] end
        if mid == 1 then
            imgui.SameLine()
            if imgui.Checkbox(u8'160 HP', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] setMaxHP(hud.tog[1][3]) end
        elseif mid == 2 or mid == 4 or mid == 5 then
            if mid == 4 then
                imgui.SameLine()
                if imgui.Checkbox(u8'2500 HP Vehicles', new.bool(hud.tog[mid][4])) then hud.tog[mid][4] = not hud.tog[mid][4] end
            end
            imgui.SameLine()
            if imgui.Checkbox(u8'Stay On', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] end
        elseif mid == 6 then
            imgui.SameLine()
            if imgui.Checkbox(u8'Name', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] end
            imgui.SameLine()
            if imgui.Checkbox(u8'Frame', new.bool(hud.tog[mid][4])) then hud.tog[mid][4] = not hud.tog[mid][4] end
            imgui.SameLine()
            if imgui.Checkbox(u8'Ammo', new.bool(hud.tog[mid][5])) then hud.tog[mid][5] = not hud.tog[mid][5] end
        elseif mid == 7 then
            imgui.SameLine()
            if imgui.Checkbox(u8'($)', new.bool(hud.tog[mid][3])) then hud.tog[mid][3] = not hud.tog[mid][3] end
            imgui.SameLine()
            if imgui.Checkbox(u8'Comma', new.bool(hud.tog[mid][4])) then hud.tog[mid][4] = not hud.tog[mid][4] end
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
        local off = new.float[4](hud.offx[mid][1], hud.offy[mid][1], hud.sizex[mid], hud.sizey[mid])
        if imgui.DragFloat4('##movement', off, 0.1, 20 * -2000, 20 * 2000, "%.1f") then
            hud.offx[mid][1], hud.offy[mid][1], hud.sizex[mid], hud.sizey[mid] = off[0], off[1], off[2], off[3]
        end
        imgui.PopItemWidth()

        imgui.PushItemWidth(70)
        if imgui.BeginCombo("##Colors", 'Colors') then
            local color = new.float[4](convertHex(hud.color[mid][1][1], true, true))
            if imgui.ColorEdit4('##color', color, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                hud.color[mid][1][1] = joinRGBA(color[3], color[0], color[1], color[2], true)
            end
            imgui.SameLine()
            imgui.Text('Color')

            if mid == 4 then
                local dcolor = new.float[4](convertHex(hud.color[mid][1][4], true, true))
                if imgui.ColorEdit4('##damage1', dcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                    hud.color[mid][1][4] = joinRGBA(dcolor[3], dcolor[0], dcolor[1], dcolor[2], true)
                end
                imgui.SameLine()
                imgui.Text('400-700')

                local dcolor2 = new.float[4](convertHex(hud.color[mid][1][5], true, true))
                if imgui.ColorEdit4('##damage2', dcolor2, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                    hud.color[mid][1][5] = joinRGBA(dcolor2[3], dcolor2[0], dcolor2[1], dcolor2[2], true)
                end
                imgui.SameLine()
                imgui.Text('0-400')
            end

            if mid >= 1 and mid <= 5 then
                local bcolor = new.float[4](convertHex(hud.color[mid][1][3], true, true))
                if imgui.ColorEdit4('##border', bcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                    hud.color[mid][1][3] = joinRGBA(bcolor[3], bcolor[0], bcolor[1], bcolor[2], true)
                end
                imgui.SameLine()
                imgui.Text('Border')

                local fcolor = new.float[4](convertHex(hud.color[mid][1][2], true, true))
                if imgui.ColorEdit4('##fade', fcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                    hud.color[mid][1][2] = joinRGBA(fcolor[3], fcolor[0], fcolor[1], fcolor[2], true)
                end
                imgui.SameLine()
                imgui.Text('Fade')

            elseif mid == 6 then
                local fcolor = new.float[4](convertHex(hud.color[mid][1][2], true, true))
                if imgui.ColorEdit4('##frame', fcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
                    hud.color[mid][1][2] = joinRGBA(fcolor[3], fcolor[0], fcolor[1], fcolor[2], true)
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
            local border = new.float[1](hud.border[mid])
            if imgui.DragFloat(u8'Border', border, 0.1, 0, 20, "%.1f") then hud.border[mid] = border[0] end
            imgui.PopItemWidth()
        elseif mid == 7 then
            imgui.PushItemWidth(50)
            local spc = new.float[1](hud.spacing)
            if imgui.DragFloat(u8"Spacing", spc, 0.1, -100, 100, "%.1f") then hud.spacing = spc[0] end
            imgui.PopItemWidth()
        end

        imgui.SameLine()
        imgui.PushItemWidth(95)
        if imgui.BeginCombo("Groups##1", hud.pos[hud.groups[mid][1]] and hud.pos[hud.groups[mid][1]].name or hud.pos[1].name) then
            for i = 1, #hud.pos do
                if imgui.Selectable(hud.pos[i].name .. '##' .. i, hud.groups[mid][1] == i) then
                    hud.groups[mid][1] = i
                end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()

        imgui.NewLine()
        createFontMenu('Text:', mid, 2, 1, 1, 2, 2, 1, 1, 2)
        if mid == 6 then
            imgui.NewLine()
            createFontMenu('Name:', mid, 3, 2, 2, 3, 3, 2, 2, 3)
        end
    elseif mid == 8 then
        for i = 1, 11 do
            if imgui.Checkbox(assets.miscNames[i] .. '##' .. i, new.bool(hud.tog[mid][i][1])) then hud.tog[mid][i][1] = not hud.tog[mid][i][1] end
            if i == 2 then
                imgui.SameLine()
                if imgui.Checkbox(hud.tog[mid][2][2] and '12 Hour' or '24 Hour', new.bool(hud.tog[mid][2][2])) then hud.tog[mid][2][2] = not hud.tog[mid][2][2] end
            elseif i == 4 then
                imgui.SameLine()
                if imgui.Checkbox('(Ping:)', new.bool(hud.tog[mid][4][2])) then hud.tog[mid][4][2] = not hud.tog[mid][4][2] end
            elseif i == 5 then
                imgui.SameLine()
                if imgui.Checkbox('(FPS:)', new.bool(hud.tog[mid][5][2])) then hud.tog[mid][5][2] = not hud.tog[mid][5][2] end
            elseif i == 6 then
                imgui.SameLine()
                if imgui.Checkbox(hud.tog[8][6][2] and 'Camera' or 'Heading', new.bool(hud.tog[mid][6][2])) then hud.tog[mid][6][2] = not hud.tog[mid][6][2] end
            elseif i == 9 then
                imgui.SameLine()
                if imgui.Checkbox(hud.tog[8][9][2] and 'MPH' or 'KMH', new.bool(hud.tog[mid][9][2])) then hud.tog[mid][9][2] = not hud.tog[mid][9][2] end
            end
            createFontMenu(assets.miscNames[i] .. ':', mid, i, i, i, i, i, i, i, i)
        end
    elseif mid == 9 then
        if imgui.Checkbox(u8'Orignal Hud', new.bool(hud.defaulthud)) then
            hud.defaulthud = not hud.defaulthud
            displayHud(hud.defaulthud)
        end

        imgui.Text(u8'Radar:')

        imgui.Text(u8'Left/Right')
        imgui.SameLine(90)
        imgui.Text(u8'Up/Down')
        imgui.SameLine(180)
        imgui.Text(u8'Width')
        imgui.SameLine(260)
        imgui.Text(u8'Height')

        imgui.PushItemWidth(330)
        local radarData = new.float[4](hud.radar.pos[1], hud.radar.pos[2], hud.radar.size[1], hud.radar.size[2])
        if imgui.DragFloat4('##movement', radarData, 0.1, 20 * -2000, 20 * 2000, "%.1f") then
            hud.radar.pos[1] = radarData[0]
            hud.radar.pos[2] = radarData[1]
            hud.radar.size[1] = radarData[2]
            hud.radar.size[2] = radarData[3]
        end
        imgui.PopItemWidth()

        local color = new.float[4](convertHex(hud.radar.color, true, true))
        if imgui.ColorEdit4('##color', color, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.radar.color = joinRGBA(color[3], color[0], color[1], color[2], true)
        end
        imgui.SameLine()
        imgui.Text(u8'Color')
        imgui.SameLine()
        if imgui.Checkbox(u8'Compass', new.bool(hud.radar.compass)) then
            hud.radar.compass = not hud.radar.compass
            setRadarCompass(hud.radar.compass)
        end

        imgui.NewLine()
        imgui.Text(u8'HZG Settings:')

        local function toggleCheckbox(label, setting, action)
            if imgui.Checkbox(label, new.bool(setting[1])) then
                setting[1] = not setting[1]
                action()
            end
        end

        toggleCheckbox('Turf', hud.hzgsettings.turf.toggle, function() hztextdraws(0) end)
        imgui.SameLine()
        imgui.PushItemWidth(68)
        local pos1 = new.float[1](hud.hzgsettings.turf.pos[1])
        if imgui.DragFloat('##turf1', pos1, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.turf.pos[1] = pos1[0]
            hztextdraws(0)
        end
        imgui.SameLine()
        local pos2 = new.float[1](hud.hzgsettings.turf.pos[2])
        if imgui.DragFloat('##turf2', pos2, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.turf.pos[2] = pos2[0]
            hztextdraws(0)
        end
        imgui.PopItemWidth()

        toggleCheckbox('Turf Owner', hud.hzgsettings.turfowner.toggle, function() hztextdraws(1) end)
        imgui.SameLine()
        local colorturf = new.float[3](convertHex(hud.hzgsettings.turfowner.color, true, false))
        if imgui.ColorEdit3('##colorturfowner', colorturf, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.turfowner.color = joinRGBA(255, colorturf[0], colorturf[1], colorturf[2], true)
            hztextdraws(1)
        end
        imgui.SameLine()
        imgui.PushItemWidth(68)
        local pos3 = new.float[1](hud.hzgsettings.turfowner.pos[1])
        if imgui.DragFloat('##turfowner1', pos3, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.turfowner.pos[1] = pos3[0]
            hztextdraws(1)
        end
        imgui.SameLine()
        local pos4 = new.float[1](hud.hzgsettings.turfowner.pos[2])
        if imgui.DragFloat('##turfowner2', pos4, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.turfowner.pos[2] = pos4[0]
            hztextdraws(1)
        end
        imgui.PopItemWidth()

        toggleCheckbox('WW', hud.hzgsettings.wristwatch.toggle, function() hztextdraws(2) end)
        imgui.SameLine()
        local colorww = new.float[3](convertHex(hud.hzgsettings.wristwatch.color, true, false))
        if imgui.ColorEdit3('##colorWW', colorww, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.wristwatch.color = joinRGBA(255, colorww[0], colorww[1], colorww[2], true)
            hztextdraws(2)
        end
        imgui.SameLine()
        imgui.PushItemWidth(68)
        local pos5 = new.float[1](hud.hzgsettings.wristwatch.pos[1])
        if imgui.DragFloat('##WW1', pos5, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.wristwatch.pos[1] = pos5[0]
            hztextdraws(2)
        end
        imgui.SameLine()
        local pos6 = new.float[1](hud.hzgsettings.wristwatch.pos[2])
        if imgui.DragFloat('##WW2', pos6, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.wristwatch.pos[2] = pos6[0]
            hztextdraws(2)
        end
        imgui.PopItemWidth()

        toggleCheckbox('Logo', hud.hzgsettings.hzglogo.toggle, function() hztextdraws(3) end)
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

        local color2 = new.float[3](convertHex(hud.hzgsettings.hzglogo.color, true, false))
        if imgui.ColorEdit3('##colorhzglogo', color2, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.hzglogo.color = joinRGBA(255, color2[0], color2[1], color2[2], true)
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
        local pos7 = new.float[1](hud.hzgsettings.hzglogo.pos[2])
        if imgui.DragFloat('##hzglogo2', pos7, 1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
            hud.hzgsettings.hzglogo.pos[2] = pos7[0]
            hztextdraws(3)
        end
        imgui.PopItemWidth()

        toggleCheckbox('HP Bar', hud.hzgsettings.hpbar.toggle, function() hztextdraws(4) end)
        imgui.SameLine()
        local color4 = new.float[3](convertHex(hud.hzgsettings.hpbar.color1, true, false))
        if imgui.ColorEdit3('##colorhpbar1', color4, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.hpbar.color1 = joinRGBA(255, color4[0], color4[1], color4[2], true)
            hztextdraws(4)
        end
        imgui.SameLine()
        local color5 = new.float[3](convertHex(hud.hzgsettings.hpbar.color2, true, false))
        if imgui.ColorEdit3('##colorhpbar2', color5, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.hpbar.color2 = joinRGBA(255, color5[0], color5[1], color5[2], true)
            hztextdraws(4)
        end
        imgui.SameLine()
        local color6 = new.float[3](convertHex(hud.hzgsettings.hpbar.color3, true, false))
        if imgui.ColorEdit3('##colorhpbar3', color6, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
            hud.hzgsettings.hpbar.color3 = joinRGBA(255, color6[0], color6[1], color6[2], true)
            hztextdraws(4)
        end

        toggleCheckbox('HP Text', hud.hzgsettings.hptext.toggle, function() hztextdraws(5) end)
        toggleCheckbox('Armor Text', hud.hzgsettings.armortext.toggle, function() hztextdraws(6) end)
    elseif mid == 10 then
        for k, v in ipairs(hud.pos) do
            imgui.PushItemWidth(120)
            local text = new.char[30](v.name)
            if imgui.InputText('##input' .. k, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
                v.name = u8:decode(str(text))
            end
            imgui.PopItemWidth()

            imgui.SameLine()
            imgui.PushItemWidth(75)
            local pos = new.float[1](v.x)
            if imgui.DragFloat('##x' .. k, pos, 0.1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
                v.x = pos[0]
            end
            imgui.PopItemWidth()

            imgui.SameLine()
            imgui.PushItemWidth(75)
            local pos2 = new.float[1](v.y)
            if imgui.DragFloat('##y' .. k, pos2, 0.1, 12 * 2000.0, 12 * 2000.0, "%.1f") then
                v.y = pos2[0]
            end
            imgui.PopItemWidth()

            imgui.SameLine()
            if imgui.Button(v.move and u8"Undo##" .. k or u8"Move##" .. k) then
                if not move or v.move then
					v.move = not v.move
					if v.move then
						assets.temp_pos.x = v.x
						assets.temp_pos.y = v.y
						move = true
					else
						v.x = assets.temp_pos.x
						v.y = assets.temp_pos.y
						move = false
					end
				end
            end

            imgui.SameLine()
            if k ~= 1 then
                if imgui.Button(u8"x##" .. k) then
                    table.remove(hud.pos, k)
                end
            else
                if imgui.Button(u8"+") then
                    table.insert(hud.pos, {x = 500, y = 500, name = 'new', move = false})
                end
            end
        end
    end
    imgui.EndChild()

    imgui.SetCursorPos(imgui.ImVec2(89, 373))
    imgui.BeginChild("##5", imgui.ImVec2(376, 36), true)

        if imgui.Checkbox('Auto-Save', new.bool(settings.autosave)) then
            settings.autosave = not settings.autosave
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Automatically saves the interface on exit.') end

        imgui.SameLine()
        if imgui.Checkbox('Auto-Update', new.bool(settings.autoupdate)) then
            settings.autoupdate = not settings.autoupdate
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Checks for updates at the start of the game.') end

        imgui.SameLine()

        local function createButton(label, data)
            if imgui.CustomButton(label, imgui.ImVec4(0.16, 0.16, 0.16, 0.9), imgui.ImVec4(0.40, 0.12, 0.12, 1), imgui.ImVec4(0.30, 0.08, 0.08, 1), imgui.ImVec2(0, 20)) then
                data.status = true
                menu.confirm[0] = true
            end
            imgui.SameLine()
        end

        imgui.PushItemWidth(165)
        if imgui.BeginCombo("##configurations", settings.JsonFile) then
            imgui.SetCursorPos(imgui.ImVec2(7, 5))
            local buttons = {
                { 'Copy', confirmData[4] },
                { 'Rename', confirmData[2] },
                { 'Delete', confirmData[5] }
            }
            for _, btn in ipairs(buttons) do
                createButton(btn[1], btn[2])
            end
            imgui.Separator()
            imgui.Selectable(u8(settings.JsonFile), true)
            imgui.Separator()
            if imgui.Selectable(u8('New File'), false) then
                confirmData[3].status = true
                menu.confirm[0] = true
            end
            imgui.Separator()
            for _, v in pairs(configsDir) do
                if v.File ~= settings.JsonFile and matchConfigFiles(v.File) then
                    if imgui.Selectable(u8(v.File), false) then
                        confirmData[1].name = v.File
                        confirmData[1].status = true
                        menu.confirm[0] = true
                    end
                end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
    imgui.EndChild()
    imgui.End()
end)

local function resetConfirmData()
    for _, t in ipairs(confirmData) do
        if t.name then
            t.name = (t.id == 'addNew') and 'new.json' or ''
        end
        if t.useCurrent ~= nil then
            t.useCurrent = false
        end
        if t.selectedFile then
            t.selectedFile = nil
        end
        t.status = false
    end
    menu.confirm[0] = false
end

local function handleButton(label, action, width)
    width = width or 85
    if imgui.CustomButton(label, imgui.ImVec4(0.16, 0.16, 0.16, 0.9), imgui.ImVec4(0.40, 0.12, 0.12, 1), imgui.ImVec4(0.30, 0.08, 0.08, 1), imgui.ImVec2(width, 45)) then
        action()
        status = false
        menu.confirm[0] = false
    end
end

local function createFileSelectCombo(label, currentFile, selectedFile, dir, onSelect)
    if imgui.BeginCombo(label, selectedFile or 'Select a file') then
        for _, v in pairs(dir) do
            if v.File ~= currentFile then
                if imgui.Selectable(u8(v.File), false) then
                    onSelect(v.File)
                end
            end
        end
        imgui.EndCombo()
    end
end

imgui.OnFrame(function() return menu.confirm[0] end, function()
    if not menu.settings[0] and not confirmData[6].status then resetConfirmData() end
    local io = imgui.GetIO()
    local center = imgui.ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2)
    imgui.SetNextWindowPos(center, imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('', menu.confirm, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
    if not imgui.IsWindowFocused() then imgui.SetNextWindowFocus() end
    for _, t in ipairs(confirmData) do
        if t.status then
            if t.id == 'addNew' then
                imgui.Text('Create new configuration file.')
                imgui.PushItemWidth(120)
                local text = new.char[30]('')
                if imgui.InputText('Filename', text, sizeof(text)) then
                    t.name = u8:decode(str(text)) .. '.json'
                end
                imgui.PopItemWidth()
                if imgui.IsItemHovered() then
                    imgui.SetTooltip('Do not add ".json" to the end.')
                end
                if imgui.Checkbox('Copy current settings?', new.bool(t.useCurrent)) then
                    t.useCurrent = not t.useCurrent
                end
                handleButton(fa.CIRCLE_CHECK .. ' Confirm', function()
                    local success, err = saveConfig(cfgFolder .. t.name, t.useCurrent and hud or hud_defaultSettings)
                    if not success then print("Error saving config: " .. err) end
                    scanGameFolder(cfgFolder, configsDir)

                    t.status = false
                    t.useCurrent = false
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                    t.useCurrent = false
                end)
            elseif t.id == 'open' then
                imgui.Text('Do you want to open this file?')
                imgui.Text('File: "' .. t.name .. '"')
                handleButton(fa.CIRCLE_CHECK .. ' Confirm', function()
                    settings.JsonFile = t.name
                    hud = handleConfigFile(cfgFolder .. settings.JsonFile, hud_defaultSettings, hud)
                    initializeHud()

                    t.status = false
                    t.name = ''
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                    t.name = ''
                end)
            elseif t.id == 'copy' then
                imgui.Text('Copy the current configuration to another file.')
                imgui.Text('File: "' .. settings.JsonFile .. '"')
                createFileSelectCombo("##configurations2", settings.JsonFile, t.selectedFile, configsDir, function(selectedFile)
                    t.selectedFile = selectedFile
                end)
                handleButton(fa.CIRCLE_CHECK .. ' Confirm', function()
                    local success, err = saveConfig(cfgFolder .. t.selectedFile, hud)
                    if not success then print("Error saving config: " .. err) end
                    scanGameFolder(cfgFolder, configsDir)

                    t.status = false
                    t.selectedFile = nil
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                    t.selectedFile = nil
                end)
            elseif t.id == 'rename' then
                imgui.Text('Do you want to rename this file?')
                imgui.Text('File: "' .. settings.JsonFile .. '"')
                imgui.PushItemWidth(120)
                local text = new.char[30]('')
                if imgui.InputText('Filename', text, sizeof(text)) then
                    t.name = u8:decode(str(text)) .. '.json'
                end
                imgui.PopItemWidth()
                if imgui.IsItemHovered() then
                    imgui.SetTooltip('Do not add ".json" to the end.')
                end
                handleButton(fa.CIRCLE_CHECK .. ' Confirm', function()
                    os.rename(cfgFolder .. settings.JsonFile, cfgFolder .. t.name)
                    settings.JsonFile = t.name
                    scanGameFolder(cfgFolder, configsDir)
                    t.status = false
                    t.name = ''
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                    t.name = ''
                end)
            elseif t.id == 'delete' then
                imgui.Text('Do you want to delete this file?')
                imgui.Text('File: "' .. settings.JsonFile .. '"')
                handleButton(fa.CIRCLE_CHECK .. ' Confirm', function()
                    os.remove(cfgFolder .. settings.JsonFile)
                    settings.JsonFile = settings_defaultSettings.JsonFile
                    hud = handleConfigFile(cfgFolder .. settings.JsonFile, hud_defaultSettings, hud)
                    initializeHud()
                    scanGameFolder(cfgFolder, configsDir)

                    t.status = false
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                end)
            elseif t.id == 'update' then
                imgui.Text('Do you want to update this script?')
                handleButton(fa.CIRCLE_CHECK .. ' Update', function()
                    updateScript()
                    t.status = false
                end)
                imgui.SameLine()
                handleButton(fa.CIRCLE_XMARK .. ' Cancel', function()
                    t.status = false
                end)
            end
        end
    end
    imgui.End()
end)

function createFontMenu(title, id, color, fontsize, font, off1, off2, align, fontflag, group)
    if id >= 1 and id <= 7 then
        imgui.Text(title)
    end

    local choices = {'Left', 'Center', 'Right'}
    imgui.PushItemWidth(68)
    if imgui.BeginCombo("##align" .. align, choices[hud.alignfont[id][align]]) then
        for i = 1, #choices do
            if imgui.Selectable(choices[i] .. '##' .. i, hud.alignfont[id][align] == i) then
                hud.alignfont[id][align] = i
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    local choices2 = {'Bold', 'Italics', 'Border', 'Shadow'}
    imgui.PushItemWidth(60)
    if imgui.BeginCombo("##flags" .. fontflag, 'Flags') then
        for i = 1, #choices2 do
            if imgui.Checkbox(choices2[i], new.bool(hud.fontflag[id][fontflag][i])) then
                hud.fontflag[id][fontflag][i] = not hud.fontflag[id][fontflag][i]
                createFont(id, fontflag)
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    imgui.PushItemWidth(95)
    local text = new.char[30](hud.font[id][font])
    if imgui.InputText('##font' .. fontflag, text, sizeof(text), imgui.InputTextFlags.EnterReturnsTrue) then
        hud.font[id][font] = u8:decode(str(text))
        createFont(id, font)
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    imgui.PushItemWidth(95)
    if imgui.BeginCombo("##group" .. group, hud.pos[hud.groups[mid][group]] and hud.pos[hud.groups[mid][group]].name or hud.pos[1].name) then
        for i = 1, #hud.pos do
            if imgui.Selectable(hud.pos[i].name .. '##' .. i, hud.groups[mid][group] == i) then
                hud.groups[mid][group] = i
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.PushItemWidth(170)
    local font_xy = new.float[2](hud.offx[id][off1], hud.offy[id][off2])
    if imgui.DragFloat2('##movement_font' .. font, font_xy, 0.1, 20 * -2000, 20 * 2000, "%.1f") then
        hud.offx[id][off1], hud.offy[id][off2] = font_xy[0], font_xy[1]
    end
    imgui.PopItemWidth()

    imgui.SameLine()
    imgui.BeginGroup()
    if imgui.Button('+##' .. fontsize) and hud.fontsize[id][fontsize] < 72 then
        hud.fontsize[id][fontsize] = hud.fontsize[id][fontsize] + 1
        createFont(id, fontsize)
    end

    imgui.SameLine()
    imgui.Text(tostring(hud.fontsize[id][fontsize]))
    imgui.SameLine()

    if imgui.Button('-##' .. fontsize) and hud.fontsize[id][fontsize] > 4 then
        hud.fontsize[id][fontsize] = hud.fontsize[id][fontsize] - 1
        createFont(id, fontsize)
    end
    imgui.EndGroup()

    imgui.SameLine()
    imgui.PushItemWidth(95)
    local tcolor = new.float[4](convertHex(hud.color[id][color], true, true))
    if imgui.ColorEdit4('##color' .. font, tcolor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then
        hud.color[id][color] = joinRGBA(tcolor[3], tcolor[0], tcolor[1], tcolor[2], true)
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Text('Color')
end

-- Render Functions
function renderBar(id, x, y, sizex, sizey, value, maxvalue, border, color, color2, color3)
	value = math.min(value, maxvalue)
	if id == 4 then
		color = (value < 400) and hud.color[id][1][5] or (value < 700) and hud.color[id][1][4] or color
	end
	renderDrawBoxWithBorder(x, y, sizex, sizey, color2, border, color3)
	renderDrawBox(x + border, y + border, (sizex - 2 * border) * value / maxvalue, sizey - 2 * border, color)
end

function renderFont(x, y, fontid, value, align, color)
    renderFontDrawText(fontid, value, x - alignText(fontid, value, align), y, color)
end

function renderWeap(x, y, sizex, sizey, value, color, color2)
    if hud.tog[6][4] then renderDrawTexture(assets.weapTextures[47], x, y, sizex, sizey, 0, color2) end
    renderDrawTexture(assets.weapTextures[value], x, y, sizex, sizey, 0, color)
end

function renderStar(x, y, sizex, sizey, value, spacing, color)
    for v = 1, value do
        renderDrawTexture(assets.weapTextures[48], x + (sizex + spacing) * v, y, sizex, sizey, 0, color)
	end
end

function createFont(id, slot)
    if not assets.fontId then assets.fontId = {} end
    if not assets.fontId[id] then assets.fontId[id] = {} end
	local flags = {flag.BOLD, flag.ITALICS, flag.BORDER, flag.SHADOW}
	local flag_sum = 0
	for i, flagid in ipairs(flags) do
		flag_sum = flag_sum + (hud.fontflag[id][slot][i] and flagid or 0)
	end
	assets.fontId[id][slot] = renderCreateFont(hud.font[id][slot], hud.fontsize[id][slot], flag_sum)
end

function loadTextures()
    if not assets.weapTextures then assets.weapTextures = {} end
	for i = 0, 48 do
		local filepath = iconsPath ..i..'.png'
		if doesFileExist(filepath) then
            if not assets.weapTextures[i] then
                assets.weapTextures[i] = renderLoadTextureFromFile(filepath)
            end
		end
	end
end

function loadFonts()
	for i = 1, 8 do
		createFont(i, 1)
		if i == 6 or (i == 8 and loadMultipleFonts(i, 2, 11)) then
			createFont(i, 2)
		end
	end
end

function loadMultipleFonts(id, start_slot, end_slot)
	for slot = start_slot, end_slot do
		createFont(id, slot)
	end
	return false
end

function alignText(fid, value, align)
	local length = renderGetFontDrawTextLength(fid, value)
	return align == 2 and length / 2 or align == 3 and length or 0
end

local function updateVehicleInfo(id)
    if isCharInAnyCar(id) then
        local vehid = storeCarCharIsInNoSave(id)
        local model = getCarModel(vehid)
        local vehhp = getCarHealth(vehid)
        local carName = getVehicleName(model)
        local speed = hud.tog[8][9][2] and getSpeedInMPH(getCarSpeed(vehid)) .. " MPH" or getSpeedInKMH(getCarSpeed(vehid)) .. " KMH"
        local maxvalue = (hasValue(assets.maxVehHPIds, model) and hud.tog[4][4]) and 2500 or 1000
        hud.maxvalue[4] = maxvalue
        return vehhp, carName, speed
    end
    return 0, '', ''
end

local function updateBadgeColor(color)
    local r, g, b = convertHex(color, false, false)
    local argbColor = joinRGBA(255, r, g, b, false)
    for _, v in pairs(assets.badgeNames) do
        if argbColor == v[1] then
            hud.color[8][11] = v[1]
            return v[2]
        end
    end
    return ''
end

local function updateTextDrawColors()
    for i = 0, 3000 do
        if sampTextdrawIsExists(i) then
            local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(i)
            local text = sampTextdrawGetString(i)
            if tostring(letSizeX) == tostring(0.23999999463558) and tostring(letSizeY) == tostring(1.2000000476837) and text ~= "TURF OWNER:" then
                hud.color[8][8] = color
            end
        end
    end
end

local function getPlayerInfo(id, vehhp, carName, speed, badge)
    local angle = hud.tog[8][6][2] and getCameraZAngle() or getCharHeading(ped)
    local ping = (hud.tog[8][4][2] and 'Ping: ' or '') .. sampGetPlayerPing(id)
    local hp = sampGetPlayerHealth(id)
    for _, v in pairs(hud.serverhp) do if hp > v then hp = hp - v end end

    return {
        {hp}, {sampGetPlayerArmor(id)}, {getSprintLevel()}, {vehhp}, {getWaterLevel()},
        {getCurrentCharWeapon(ped), formatammo(getAmmoInCharWeapon(ped, getCurrentCharWeapon(ped)), getAmmoInClip(ped, getCurrentCharWeapon(ped))), weapons.get_name(getCurrentCharWeapon(ped))},
        {getWantedLevel(), formatmoney(getPlayerMoney())},
        {
            string.format("%s (%d)", sampGetPlayerNickname(id), id),
            os.date(hud.tog[8][2][2] and '%I:%M:%S' or '%H:%M:%S'),
            settings.wwtext,
            ping,
            (hud.tog[8][5][2] and 'FPS: ' or '') .. fps,
            getDirection(angle),
            getPlayerZoneName(ped),
            settings.turftext,
            speed,
            carName,
            badge
        }
    }
end

local function getSpecPlayerInfo(localtime, showfps)
    local res, handle = sampGetCharHandleBySampPlayerId(spec.playerid)
    if not res then return nil end

    local vehhp, carName, speed = updateVehicleInfo(handle)
    local weap, color = getCurrentCharWeapon(handle), sampGetPlayerColor(spec.playerid)
    local badge = updateBadgeColor(color)
    local angle = getCharHeading(handle)

    return {
        {sampGetPlayerHealth(spec.playerid)}, {sampGetPlayerArmor(spec.playerid)}, {0}, {vehhp}, {0},
        {weap, formatammo(getAmmoInCharWeapon(handle, weap), getAmmoInClip(handle, weap)), weapons.get_name(weap)},
        {0, ''},
        {
            string.format("%s (%d)", sampGetPlayerNickname(spec.playerid), spec.playerid),
            localtime, settings.wwtext, (hud.tog[8][4][2] and 'Ping: ' or '') .. sampGetPlayerPing(spec.playerid),
            showfps, getDirection(angle), getPlayerZoneName(handle), settings.turftext, speed, carName, badge
        }
    }
end

function hudValues()
    local res, id = sampGetPlayerIdByCharHandle(ped)
    if not res then return end

    if menu.settings[0] then
        value = {
            {50}, {50}, {100}, {1000}, {100},
            {24, formatammo(50000, 7), 'Desert Eagle'},
            {6, formatmoney(1000000)},
            {'Player_Name', 'Local-Time', 'Server-Time', 'Ping', (hud.tog[8][5][2] and 'FPS: ' or '') .. fps, 'Direction', 'Location', 'Turf', 'Vehicle Speed', 'Vehicle Name', 'Badge'}
        }
        return
    end

    updateTextDrawColors()
    if getActiveInterior() ~= 0 then settings.turftext = '' end

    local vehhp, carName, speed = updateVehicleInfo(ped)
    local color = sampGetPlayerColor(id)
    local badge = updateBadgeColor(color)
    local localtime = os.date(hud.tog[8][2][2] and '%I:%M:%S' or '%H:%M:%S')
    local showfps = (hud.tog[8][5][2] and 'FPS: ' or '') .. fps

    if spec.state and spec.playerid ~= -1 and sampIsPlayerConnected(spec.playerid) then
        value = getSpecPlayerInfo(localtime, showfps)
        if value then return end
    end

    value = getPlayerInfo(id, vehhp, carName, speed, badge)
end

function formatmoney(n)
	return (hud.tog[7][3] and '$' or '')..(hud.tog[7][4] and formatNumber(n) or n)
end

function formatammo(ammo, clip)
	return hud.tog[6][5] and ammo - clip..'-'..clip or clip
end

function hudMove()
    if not menu.settings[0] then return end
    x, y = getCursorPos()

    local function handleSelect(k, v)
        if x >= v.x and x <= v.x + 15 and y >= v.y and y <= v.y + 15 then
            if isKeyJustPressed(VK_LBUTTON) and not inuse then
                inuse = true
                selectedbox[k] = true
                dragging[k] = { offsetX = x - v.x, offsetY = y - v.y }
            end
        end
        if selectedbox[k] then
            if wasKeyReleased(VK_LBUTTON) then
                inuse = false
                selectedbox[k] = false
                dragging[k] = nil
            else
                v.x = x - dragging[k].offsetX
                v.y = y - dragging[k].offsetY
            end
        end
    end

    local function handleHudElement(i, v, width, height, offsetX, offsetY, align, select)
        local posX = hud.pos[hud.groups[i][v]] ~= nil and hud.pos[hud.groups[i][v]].x or hud.pos[1].x
        local posY = hud.pos[hud.groups[i][v]] ~= nil and hud.pos[hud.groups[i][v]].y or hud.pos[1].y

        if x >= posX + offsetX - align and x <= posX + offsetX - align + width and y >= posY + offsetY and y <= posY + offsetY + height then
            if isKeyJustPressed(VK_LBUTTON) and not inuse then
                inuse = true
                select = true
                dragging[i .. "-" .. v] = { offsetX = x - (posX + offsetX - align), offsetY = y - (posY + offsetY) }
            end
        end
        if select then
            if wasKeyReleased(VK_LBUTTON) then
                inuse = false
                select = false
                dragging[i .. "-" .. v] = nil
            else
                hud.offx[i][v] = x - posX - dragging[i .. "-" .. v].offsetX + align
                hud.offy[i][v] = y - posY - dragging[i .. "-" .. v].offsetY
            end
        end
        return select
    end

    if move then
        for _, v in ipairs(hud.pos) do
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
        for k, v in ipairs(hud.pos) do handleSelect(k, v) end
        for i = 1, 8 do
            if not selected[i] then selected[i] = {} end
            if i >= 1 and i <= 5 then
                local width_text = renderGetFontDrawTextLength(assets.fontId[i][1], value[i][1])
                local height_text = renderGetFontDrawHeight(assets.fontId[i][1])
                selected[i][2] = handleHudElement(i, 2, width_text, height_text, hud.offx[i][2], hud.offy[i][2], alignText(assets.fontId[i][1], value[i][1], hud.alignfont[i][1]), selected[i][2])
                selected[i][1] = handleHudElement(i, 1, hud.sizex[i], hud.sizey[i], hud.offx[i][1] + hud.border[i], hud.offy[i][1] + hud.border[i], 0, selected[i][1])
            elseif i == 6 then
                local width_clip = renderGetFontDrawTextLength(assets.fontId[i][1], value[i][2])
                local height_clip = renderGetFontDrawHeight(assets.fontId[i][1])
                selected[i][2] = handleHudElement(i, 2, width_clip, height_clip, hud.offx[i][2], hud.offy[i][2], alignText(assets.fontId[i][1], value[i][2], hud.alignfont[i][1]), selected[i][2])

                local width_weapname = renderGetFontDrawTextLength(assets.fontId[i][2], value[i][3])
                local height_weapname = renderGetFontDrawHeight(assets.fontId[i][2])
                selected[i][3] = handleHudElement(i, 3, width_weapname, height_weapname, hud.offx[i][3], hud.offy[i][3], alignText(assets.fontId[i][2], value[i][3], hud.alignfont[i][2]), selected[i][3])
                selected[i][1] = handleHudElement(i, 1, hud.sizex[i], hud.sizey[i], hud.offx[i][1], hud.offy[i][1], 0, selected[i][1])
            elseif i == 7 then
                local width_money = renderGetFontDrawTextLength(assets.fontId[i][1], value[i][2])
                local height_money = renderGetFontDrawHeight(assets.fontId[i][1])
                selected[i][2] = handleHudElement(i, 2, width_money, height_money, hud.offx[i][2], hud.offy[i][2], alignText(assets.fontId[i][1], value[i][2], hud.alignfont[i][1]), selected[i][2])
                selected[i][1] = handleHudElement(i, 1, hud.sizex[i] + (hud.sizex[i] + hud.spacing) * value[i][1], hud.sizey[i], hud.offx[i][1], hud.offy[i][1], 0, selected[i][1])
            elseif i == 8 then
                for v = 1, 11 do
                    local width = renderGetFontDrawTextLength(assets.fontId[i][v], value[i][v])
                    local height = renderGetFontDrawHeight(assets.fontId[i][v])
                    selected[i][v] = handleHudElement(i, v, width, height, hud.offx[i][v], hud.offy[i][v], alignText(assets.fontId[i][v], value[i][v], hud.alignfont[i][v]), selected[i][v])
                end
            end
        end
    end
end

local function setPosition(i, pos, toggle)
    if not toggle then
        pos = {-100, -100}
    end

    sampTextdrawSetPos(i, pos[1], pos[2])
end

local function setStringAndColor(i, text, letterSizeX, letterSizeY, color)
    sampTextdrawSetLetterSizeAndColor(i, letterSizeX, letterSizeY, color)
    sampTextdrawSetString(i, text)
end

local function setHPBar(i, box, sizeX, sizeY, color, toggle)
    sampTextdrawSetString(i, toggle and '' or '')
    sampTextdrawSetBoxColorAndSize(i, box, color, sizeX, sizeY)
end

local function setHPAndArmorText(i, text, toggle, color)
    setStringAndColor(i, toggle and text or '', 0.25999900698662, 1.2000000476837, color)
end

function hztextdraws(id)
    for i = 0, 4000 do
        if sampTextdrawIsExists(i) then
            local posX, posY = sampTextdrawGetPos(i)
            local box, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(i)
            local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(i)
            local text = sampTextdrawGetString(i)

            local letSizeXStr, letSizeYStr = tostring(letSizeX), tostring(letSizeY)

            if letSizeXStr == "0.23999999463558" and letSizeYStr == "1.2000000476837" then
                if text ~= "TURF OWNER:" and id == 0 then
                    setPosition(i, hud.hzgsettings.turf.pos, hud.hzgsettings.turf.toggle[1])
                elseif text == "TURF OWNER:" and id == 1 then
                    setStringAndColor(i, text, letSizeX, letSizeY, hud.hzgsettings.turfowner.color)
                    setPosition(i, hud.hzgsettings.turfowner.pos, hud.hzgsettings.turfowner.toggle[1])
                end
            end

            if letSizeXStr == "0.5" and letSizeYStr == "2" and text:match("%W") and id == 2 then
                setStringAndColor(i, text, letSizeX, letSizeY, hud.hzgsettings.wristwatch.color)
                setPosition(i, hud.hzgsettings.wristwatch.pos, hud.hzgsettings.wristwatch.toggle[1])
            end

            if letSizeXStr == "0.3199990093708" and letSizeYStr == "1.3999999761581" and id == 3 then
                setStringAndColor(i, hud.hzgsettings.hzglogo.toggle[2] and hud.hzgsettings.hzglogo.customstring or 'hzgaming.net', letSizeX, letSizeY, hud.hzgsettings.hzglogo.color)
                setPosition(i, hud.hzgsettings.hzglogo.pos, hud.hzgsettings.hzglogo.toggle[1])
            end

            if id == 4 then
                if math.floor(posX) == 610 and math.floor(posY) == 68 then
                    setHPBar(i, box, sizeX, sizeY, hud.hzgsettings.hpbar.color1, hud.hzgsettings.hpbar.toggle[1])
                elseif math.floor(posX) == 608 and math.floor(posY) == 70 then
                    setHPBar(i, box, sizeX, sizeY, hud.hzgsettings.hpbar.color2, hud.hzgsettings.hpbar.toggle[1])
                elseif math.floor(posX) <= 608 and math.floor(posY) == 70 then
                    setHPBar(i, box, sizeX, sizeY, hud.hzgsettings.hpbar.color3, hud.hzgsettings.hpbar.toggle[1])
                end
            end

            if letSizeXStr == "0.25999900698662" and letSizeYStr == "1.2000000476837" then
                if (posX == 577 or posX == 611) and posY == 65 and id == 5 then
                    setHPAndArmorText(i, text, hud.hzgsettings.hptext.toggle[1], hud.hzgsettings.hptext.color)
                elseif (posX == 577 or posX == 611) and posY == 43 and id == 6 then
                    setHPAndArmorText(i, text, hud.hzgsettings.armortext.toggle[1], hud.hzgsettings.armortext.color)
                end
            end
        end
    end
end

function formattedAddChatMessage(string, color)
    sampAddChatMessage(string.format("{ABB2B9}[%s]{FFFFFF} %s", firstToUpper(scriptName), string), color)
end

function changeRadarPosAndSize(posX, posY, sizeX, sizeY)
    if (posX == currentRadarPosX) and (posY == currentRadarPosY) and (sizeX == currentRadarSizeX) and (sizeY == currentRadarSizeY) then
        return -- No changes needed
    end

    if getMoonloaderVersion() >= 27 then
        local addresses = {
            {allocateAndAssign(posX), {0x58A79B, 0x5834D4, 0x58A836, 0x58A8E9, 0x58A98A, 0x58A469, 0x58A5E2, 0x58A6E6}},
            {allocateAndAssign(posY), {0x58A7C7, 0x58A868, 0x58A913, 0x58A9C7, 0x583500, 0x58A499, 0x58A60E, 0x58A71E}},
            {allocateAndAssign(sizeX), {0x5834C2, 0x58A449, 0x58A7E9, 0x58A840, 0x58A943, 0x58A99D}},
            {allocateAndAssign(sizeY), {0x58A47D, 0x58A632, 0x58A6AB, 0x58A70E, 0x58A801, 0x58A8AB, 0x58A921, 0x58A9D5, 0x5834F6}}
        }

        for _, group in ipairs(addresses) do
            local value, addrs = group[1], group[2]
            for _, addr in ipairs(addrs) do
                ffi.cast('float**', addr)[0] = value
            end
        end
    elseif getMoonloaderVersion() <= 26 then
        local addresses = {
            {8751632, posX}, {8809328, posY}, {8809332, sizeX}, {8809336, sizeY}
        }

        for _, addr in ipairs(addresses) do
            writeMemory(addr[1], 4, representFloatAsInt(addr[2]), true)
        end
    end

    -- Update the current values
    currentRadarPosX, currentRadarPosY, currentRadarSizeX, currentRadarSizeY = posX, posY, sizeX, sizeY
end

function changeRadarColor(color)
    if color == currentRadarColor then
        return -- No changes needed
    end

    local r, g, b, a = convertHex(color, false, true)
    local addresses = {
        {r, {0x58A798, 0x58A89A, 0x58A8EE, 0x58A9A2}},
        {g, {0x58A790, 0x58A896, 0x58A8E6, 0x58A99A}},
        {b, {0x58A78E, 0x58A894, 0x58A8DE, 0x58A996}},
        {a, {0x58A789, 0x58A88F, 0x58A8D9, 0x58A98F}}
    }

    for _, group in ipairs(addresses) do
        local value, addrs = group[1], group[2]
        for _, addr in ipairs(addrs) do
            mem.write(addr, value, 1, true)
        end
    end

    -- Update the current color
    currentRadarColor = color
end

function hudWidthFix()
	if getMoonloaderVersion() <= 26 then
        local addr = {
            0x58EB70, -- Clock Border
            0x58F58D, -- Money Border
            0x866C94, -- Money String Format (Positive)
            0x866C8C  -- Money String Format (Negative)
        }
		mem.write(addr[1], 1, 1, true)
		mem.write(addr[2], 1, 1, true)
		mem.copy(addr[3], mem.strptr("$%d"), 6, true)
		mem.copy(addr[4], mem.strptr("-$%d"), 6, true)
	end
end

function setRadarCompass(bool)
    for k, v in ipairs(compassData) do
        if bool then
            if not assets.compassId[k] then
                assets.compassId[k] = addSpriteBlipForCoord(v.x, v.y, v.z, v.id)
            end
        else
            if assets.compassId[k] then
                removeBlip(assets.compassId[k])
                assets.compassId[k] = nil
            end
        end
    end
end

function setMaxHP(bool)
    hud.maxvalue[1] = bool and 160 or 100
end

function getPlayerZoneName(id)
	if getActiveInterior() ~= 0 then return 'Interior' end
	local x, y, z = getCharCoordinates(id)
	for k, v in pairs(zones.custom) do
        if (x >= v[1]) and (y >= v[2]) and (z >= v[3]) and (x <= v[4]) and (y <= v[5]) and (z <= v[6]) then
            return k
        end
    end
    local name = getNameOfZone(x, y, z)
	for _, v in pairs(zones.names) do
		if string.match(name, v[1]) then
            return v[2]
		end
	end
	return 'Unknown'
end

function getDirection(angle)
    for _, dir in ipairs(directionData) do
        if math.floor(angle) >= dir.min and math.floor(angle) <= dir.max then
            return dir.direction
        end
    end
end

function getCameraZAngle()
	local cx, cy, _ = getActiveCameraCoordinates()
	local tx, ty, _ = getActiveCameraPointAt()
	return getHeadingFromVector2d(tx-cx, ty-cy)
end

function getTarget(nick)
    if not nick then return false end
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) then
            local name = sampGetPlayerNickname(i)
            if name:lower():find("^" .. nick:lower()) then
                return true, i, name
            end
        end
    end
    return false
end

function getVehicleName(model)
	return vehNames[model - 399]
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

function getSpeedInMPH(speed)
    return math.ceil(speed * 2.98)
end

function getSpeedInKMH(speed)
    return math.ceil(speed * 4.80)
end

function checkForUpdate()
	asyncHttpRequest('GET', settings.beta and updateUrlBeta or updateUrl, nil,
		function(response)
            local updateVersion = response.text:match("version: (.+)")
            if updateVersion and compareVersions(scriptVersion, updateVersion) == -1 then
                confirmData[6].status = true
                menu.confirm[0] = true
            end
		end,
		function(err)
            print(err)
		end
	)
end

function updateScript()
    update_in_process = true
    downloadFiles({{url = settings.beta and scriptUrlBeta or scriptUrl, path = scriptPath, replace = true}}, function(result)
        if result then
            formattedAddChatMessage("Update downloaded successfully! Reloading the script now.", -1)
            thisScript():reload()
        end
    end)
end

function downloadFiles(table, onCompleteCallback)
    local downloadsInProgress = 0
    local downloadsStarted = false
    local callbackCalled = false

    local function download_handler(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            downloadsInProgress = downloadsInProgress - 1
        end

        if downloadsInProgress == 0 and onCompleteCallback and not callbackCalled then
            callbackCalled = true
            onCompleteCallback(downloadsStarted)
        end
    end

    for _, file in ipairs(table) do
        if not doesFileExist(file.path) or file.replace then
            downloadsInProgress = downloadsInProgress + 1
            downloadsStarted = true
            downloadUrlToFile(file.url, file.path, download_handler)
        end
    end

    if not downloadsStarted and onCompleteCallback and not callbackCalled then
        callbackCalled = true
        onCompleteCallback(downloadsStarted)
    end
end

function filesExist(tables, filePath, fileName)
    for _, entry in ipairs(tables) do
        if entry.Path == filePath and entry.File == fileName then
            return true
        end
    end
    return false
end

function scanGameFolder(path, tables)
    local existingFiles = {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local file_extension = string.match(file, "([^\\%.]+)$")
            if file_extension then
                existingFiles[file] = true
                if not filesExist(tables, path, file) then
                    table.insert(tables, {Path = path, File = file})
                end
            end
        end
    end

    for i = #tables, 1, -1 do
        local entry = tables[i]
        if entry.Path == path and not existingFiles[entry.File] then
            table.remove(tables, i)
        end
    end
end

function matchConfigFiles(f)
    local ext = f:match("%.([^%.]+)$")
    return ext and configExtensions[ext:lower()] or false
end

function loadConfig(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil, "Could not open file."
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        return nil, "Config file is empty."
    end

    local success, decoded = pcall(decodeJson, content)
    if success then
        if next(decoded) == nil then
            return nil, "JSON format is empty."
        else
            return decoded, nil
        end
    else
        return nil, "Failed to decode JSON: " .. decoded
    end
end

function saveConfig(filePath, config)
    local file = io.open(filePath, "w")
    if not file then
        return false, "Could not save file."
    end
    file:write(encodeJson(config, true))
    file:close()
    return true
end

function ensureDefaults(config, defaults, reset, ignoreKeys)
    ignoreKeys = ignoreKeys or {}
    local status = false

    local function isIgnored(key)
        for _, ignoreKey in ipairs(ignoreKeys) do
            if key == ignoreKey then
                return true
            end
        end
        return false
    end

    local function cleanupConfig(conf, def)
        local localStatus = false
        for k, v in pairs(conf) do
            if isIgnored(k) then
                return
            elseif def[k] == nil then
                conf[k] = nil
                localStatus = true
            elseif type(conf[k]) == "table" and type(def[k]) == "table" then
                localStatus = cleanupConfig(conf[k], def[k]) or localStatus
            end
        end
        return localStatus
    end

    local function applyDefaults(conf, def)
        local localStatus = false
        for k, v in pairs(def) do
            if conf[k] == nil or reset then
                if type(v) == "table" then
                    conf[k] = {}
                    localStatus = applyDefaults(conf[k], v) or localStatus
                else
                    conf[k] = v
                    localStatus = true
                end
            elseif type(v) == "table" and type(conf[k]) == "table" then
                localStatus = applyDefaults(conf[k], v) or localStatus
            end
        end
        return localStatus
    end

    status = applyDefaults(config, defaults)
    status = cleanupConfig(config, defaults) or status
    return status
end

function asyncHttpRequest(method, url, args, resolve, reject)
   local request_thread = effil.thread(function (method, url, args)
      local requests = require 'requests'
      local result, response = pcall(requests.request, method, url, args)
      if result then
         response.json, response.xml = nil, nil
         return true, response
      else
         return false, response
      end
   end)(method, url, args)
   -- Если запрос без функций обработки ответа и ошибок.
   if not resolve then resolve = function() end end
   if not reject then reject = function() end end
   -- Проверка выполнения потока
   lua_thread.create(function()
      local runner = request_thread
      while true do
         local status, err = runner:status()
         if not err then
            if status == 'completed' then
               local result, response = runner:get()
               if result then
                  resolve(response)
               else
                  reject(response)
               end
               return
            elseif status == 'canceled' then
               return reject(status)
            end
         else
            return reject(err)
         end
         wait(0)
      end
   end)
end

function compareVersions(version1, version2)
    local function parseVersion(version)
        local major, minor, patch = version:match("(%d+)%.?(%d*)%.?(%d*)")
        major = tonumber(major) or 0
        minor = tonumber(minor) or 0
        patch = tonumber(patch) or 0
        return major, minor, patch
    end

    local major1, minor1, patch1 = parseVersion(version1)
    local major2, minor2, patch2 = parseVersion(version2)

    if major1 ~= major2 then
        return major1 > major2 and 1 or -1
    elseif minor1 ~= minor2 then
        return minor1 > minor2 and 1 or -1
    elseif patch1 ~= patch2 then
        return patch1 > patch2 and 1 or -1
    else
        return 0
    end
end

function formatNumber(n)
    n = tostring(n)
    return n:reverse():gsub("...","%0,",math.floor((#n-1)/3)):reverse()
end

function firstToUpper(string)
    return (string:gsub("^%l", string.upper))
end

function hasValue(tab, val)
    for _, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

function allocateAndAssign(value)
    local ptr = ffi.cast('float*', ffi.C.malloc(4))
    ptr[0] = value
    return ptr
end

function convertHex(rgba, normalize, includeAlpha)
    local r = bit.band(bit.rshift(rgba, 16), 0xFF)
    local g = bit.band(bit.rshift(rgba, 8), 0xFF)
    local b = bit.band(rgba, 0xFF)
    local a = bit.band(bit.rshift(rgba, 24), 0xFF)

    if normalize then
        r, g, b, a = r / 255, g / 255, b / 255, a / 255
    end

    if includeAlpha then
        return r, g, b, a
    else
        return r, g, b
    end
end

function joinRGBA(a, r, g, b, normalized)
    if normalized then
        a, r, g, b = math.floor(a * 255), math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
    end
    return bit.bor(bit.lshift(a, 24), bit.lshift(r, 16), bit.lshift(g, 8), b)
end

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
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
end
