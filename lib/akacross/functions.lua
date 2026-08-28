local extra_funcs = {}
extra_funcs._VERSION = '0.1.0'
extra_funcs.__index = extra_funcs

setmetatable(extra_funcs, { __index = _G })
setfenv(1, extra_funcs)

function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    setmetatable(copy, getmetatable(original))
    return copy
end

function deepCopyCdata(original)
    local function cloneCdata(v)
        local okType, ctype = pcall(ffi.typeof, v)
        if not okType then return v end
        local tstr = tostring(ctype)

        if tstr:find("ImVec2", 1, true) then
            local okFields = pcall(function() return v.x, v.y end)
            if okFields then
                return imgui.ImVec2(v.x, v.y)
            end
            local okIdx = pcall(function() return v[0].x, v[0].y end)
            if okIdx then
                return imgui.ImVec2(v[0].x, v[0].y)
            end
            return imgui.ImVec2(0, 0)

        elseif tstr:find("ImVec4", 1, true) then
            local okFields = pcall(function() return v.x, v.y, v.z, v.w end)
            if okFields then
                return imgui.ImVec4(v.x, v.y, v.z, v.w)
            end
            local okIdx = pcall(function() return v[0].x, v[0].y, v[0].z, v[0].w end)
            if okIdx then
                return imgui.ImVec4(v[0].x, v[0].y, v[0].z, v[0].w)
            end
            return imgui.ImVec4(0, 0, 0, 0)
        end

        local okGeneric, cloned = pcall(function()
            local ct = ctype
            local obj = ffi.new(ct)
            ffi.copy(obj, v, ffi.sizeof(ct))
            return obj
        end)
        if okGeneric then
            return cloned
        end

        print("Unknown type: " .. tstr, tostring(v))

        return v
    end

    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopyCdata(v)
        elseif type(v) == "cdata" then
            copy[k] = cloneCdata(v)
        else
            copy[k] = v
        end
    end
    setmetatable(copy, getmetatable(original))
    return copy
end

function checkChatDialogScoreboardConsolePause(chat, dialog, scoreboard, console, pause)
	return (not chat or not sampIsChatInputActive()) and 
	       (not dialog or not sampIsDialogActive()) and 
	       (not scoreboard or not sampIsScoreboardOpen()) and 
	       (not console or not isSampfuncsConsoleActive()) and 
	       (not pause or not isPauseMenuActive())
end

function formatNumber(num)
    local isNegative = num < 0
    num = tostring(math.abs(num))

    local formatted = num:reverse():gsub("...","%0,",math.floor((#num-1)/3)):reverse()

    return isNegative and "-" .. formatted or formatted
end

function getDownKeys(usingImgui)
    local keyslist = nil
    local bool = false
    for k, v in pairs(vk) do
        if wasKeyPressed(v) then
            keyslist = v
            bool = true
            break
        end
    end

    if usingImgui then
        local mouseButtons = {
            [0] = VK_LBUTTON,
            [1] = VK_RBUTTON,
            [2] = VK_MBUTTON,
            [3] = VK_XBUTTON1,
            [4] = VK_XBUTTON2
        }
        for id, button in pairs(mouseButtons) do
            if imgui.IsMouseClicked(id, false) then
                keyslist = button
                bool = true
                break
            end
        end
    end

    return keyslist, bool
end

PressTypes = {
    KeyDown = isKeyDown,
    KeyJustPressed = isKeyJustPressed,
    KeyPressed = wasKeyPressed,
    KeyReleased = wasKeyReleased
}
function keycheck(bind)
    if not bind.Types or not bind.Keys or #bind.Keys == 0 then
        return false
    end

    -- runs every frame: bail on the first miss, and never index PressTypes
    -- with a missing/unknown type (a bind edited to more keys than types
    -- would otherwise crash the keybind loop every frame)
    for i = 1, #bind.Keys do
        local press = PressTypes[bind.Types[i]]
        if not press or not press(bind.Keys[i]) then
            return false
        end
    end
    return true
end

function table.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function toggleRadio(bool)
    local radioAddr = 0x4EB9A0
    local disableAddr = 0x8BE98B55
    local enableAddr = 0x8B0004C2
	mem.write(radioAddr, bool and disableAddr or enableAddr, 4, false)
end

function toggleSun(bool)
    local sunAddress = 0x53C136
    if bool then
        local oldProtect = mem.unprotect(sunAddress, 5)
        mem.hex2bin("E865041C00", sunAddress, 5)
        mem.protect(sunAddress, 5, oldProtect)
    else
        mem.fill(sunAddress, 0x90, 5, true)
    end
end

function reloadWeapon()
	if not sampIsCursorActive() and isPlayerPlaying(h) and isCharOnFoot(ped) then
        local charPointer = getCharPointer(ped)
        local weaponSlot = mem.read(charPointer + 1816, 1, false)
        local weaponAddress = charPointer + 1440 + weaponSlot * 28 + 4
        mem.write(weaponAddress, 2, 4, true)
	end
end

function findPlayer(target, includeLocalPlayer)
    if not target then return false end

    local result, playerId = sampGetPlayerIdByCharHandle(ped)
    if not result then
        return false
    end

    local targetId = tonumber(target)
    if targetId and (sampIsPlayerConnected(targetId) or (includeLocalPlayer and playerId == targetId)) then
        return true, targetId, sampGetPlayerNickname(targetId)
    end

    local escapedTarget = target:gsub("([^%w])", "%%%1")
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) or (includeLocalPlayer and playerId == i) then
            local name = sampGetPlayerNickname(i)
            if name:lower():find("^" .. escapedTarget:lower()) then
                return true, i, name
            end
        end
    end

    return false
end

function sampGetPlayerIdByNickname(nick)
	nick = tostring(nick)
	local okId, myid = sampGetPlayerIdByCharHandle(ped)
	if okId and nick == sampGetPlayerNickname(myid) then return myid end
	for i = 0, sampGetMaxPlayerId(false) do
		if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == nick then
			return i
		end
	end
    return -1
end

local subZones = {
    GAN1 = 'Grove Street', GAN2 = "Apartments", IWD1 = 'Freeway', IWD2 = 'Drug Den', IWD3A = 'Gas Station', IWD3B = 'Maximus Club',
    IWD4 = 'Ghetto Area', IWD5 = 'Pizza', LMEX1A = "South", LMEX1B = "North", ELS1A = "Crack Lab", ELS1B = "Pig Pen", ELS2 = "Apartments", 
    ELS3A = "The Court", ELS3C = "Alleyway", ELS4 = "Carwash", ELCO1 = "Unity Station", ELCO2 = "Apartments", LIND1A = "West", LIND2A = "South", LIND2B = "South", LIND3 = "East"
}

function getZoneName(x, y, z)
	return getGxtText(getNameOfZone(x, y, z))
end

function getSubZoneName(x, y, z)
    return subZones[getNameOfInfoZone(x, y, z)] or nil
end

function getVehicleName(modelId)
    return getGxtText(getNameOfVehicleModel(modelId))
end

function removeHexBrackets(text)
    return text:gsub("{%x+}", "")
end

function string:upperFirst()
    return (self:gsub("^%l", string.upper))
end

function string:trim()
    return self:match("^%s*(.-)%s*$")
end

function formatTimeSeconds(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60

    local timeString = ""
    if hours > 0 then
        timeString = timeString .. ("%d hr%s, "):format(hours, hours > 1 and "s" or "")
    end
    if minutes > 0 then
        timeString = timeString .. ("%d min%s"):format(minutes, minutes > 1 and "s" or "")
    end
    if timeString == "" then
        timeString = ("%d sec%s"):format(seconds, seconds == 1 and "" or "s") -- was "" for anything under a minute
    end

    return timeString
end

function parseDateString(dateStr)
    local month, day, year, hour, min = tostring(dateStr):match("(%d+)/(%d+)/(%d+)%s*(%d*):?(%d*)")
    if not year then
        return nil -- caller must guard: malformed date crashed here before
    end
    year = tonumber(year)
    if year < 100 then year = 2000 + year end
    return {
        year = year,
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour) or 0,
        min = tonumber(min) or 0,
        sec = 0,
    }
end

function timeAgoString(pastTime)
    local now = os.time()
    local diff = os.difftime(now, pastTime)
    -- A future timestamp used to fall through to the "%d secs ago" branch and
    -- render as "-21600 secs ago". Reachable from a timezone-less update.json
    -- (see the note at its consumer in ui/menus) and from a client clock that
    -- is simply behind, so clamp rather than trusting the input.
    if diff < 0 then
        return "just now"
    end
    if diff < 60 then
        return string.format("%d secs ago", diff)
    elseif diff < 3600 then
        return string.format("%d mins ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d hours ago", math.floor(diff / 3600))
    else
        return string.format("%d days ago", math.floor(diff / 86400))
    end
end

function setTime(hour, minute)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, hour)
    raknetBitStreamWriteInt8(bs, minute)
    raknetEmulRpcReceiveBitStream(29, bs)
    raknetDeleteBitStream(bs)
end

function setWeather(weatherId)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, weatherId)
    raknetEmulRpcReceiveBitStream(152, bs)
    raknetDeleteBitStream(bs)
end

function gameModeRestart()
    local bs = raknetNewBitStream()
    raknetEmulRpcReceiveBitStream(40, bs)
    raknetDeleteBitStream(bs)
end

threadstatus = function(thread, statusList)
    if thread and table.contains(statusList, thread:status()) then
        return true
    end
    return false
end

-- Reconnect system ---------------------------------------------------------
-- One worker thread driven off the SA-MP gamestate. The old version fired
-- sampConnectToServer the instant a disconnect event arrived, which is far
-- too fast for closed/kicked/banned: the client is still tearing the session
-- down, the server still holds the slot, and the request is simply dropped.
-- Every attempt now waits for the client to settle, dials, then waits for
-- GAMESTATE_CONNECTED before deciding whether it worked.

GAMESTATE = {
    NONE = 0,
    WAIT_CONNECT = 1,
    AWAIT_JOIN = 2,
    CONNECTED = 3,
    RESTARTING = 4,
    DISCONNECTED = 5
}

local GAMESTATE_NAMES = {
    [0] = "none",
    [1] = "wait_connect",
    [2] = "await_join",
    [3] = "connected",
    [4] = "restarting",
    [5] = "disconnected"
}

function gamestateName(gs)
    gs = gs or sampGetGamestate()
    return GAMESTATE_NAMES[gs] or ("unknown(" .. tostring(gs) .. ")")
end

-- All durations are milliseconds. Anything in `config` can be overridden per
-- reason profile, and a profile field can be overridden per call via the opts
-- argument of reconnectToServer.
reconnect = {
    config = {
        delay = 5000,           -- wait before the first attempt
        settle = 2000,          -- extra wait after the client is disconnected
        connectTimeout = 25000, -- how long a single dial may take to reach CONNECTED
        pollInterval = 250,
        backoff = 1.5,          -- multiplies delay per attempt within a burst
        maxDelay = 120000,
        maxAttempts = 5,        -- attempts per burst (<= 0 means never give up)
        cooldown = 30000,       -- pause once a burst is exhausted
        maxBursts = 0,          -- <= 0 means keep retrying forever
        announce = true
    },
    -- per-reason profiles; the key is what callers pass to reconnectToServer
    reasons = {
        manual   = {label = "Manual reconnect",              delay = 500,   settle = 1000},
        lost     = {label = "Lost connection",               delay = 4000},
        closed   = {label = "Server closed the connection",  delay = 8000,  settle = 3000},
        kicked   = {label = "Kicked from the server",        delay = 12000, settle = 4000},
        banned   = {label = "Banned from the server",        delay = 60000, settle = 5000, maxAttempts = 2, cooldown = 120000},
        password = {label = "Wrong server password",         delay = 15000, maxAttempts = 2},
        rejected = {label = "Connection rejected",           delay = 15000, maxAttempts = 3},
        failed   = {label = "Connection attempt failed",     delay = 8000},
        noslot   = {label = "Server is full",                delay = 20000, maxAttempts = 0},
        restart  = {label = "Server restarting",             delay = 10000}
    },
    state = {
        thread = nil,
        generation = 0,
        active = false,
        reason = nil,
        label = nil,
        attempt = 0,
        burst = 0,
        overrides = nil,
        selfDisconnect = false, -- we are the ones tearing the session down
        dialed = false,         -- this run has issued at least one connect
        lastAddress = nil
    }
}

local function announce(fmt, ...)
    local msg = select('#', ...) > 0 and fmt:format(...) or fmt
    print("[reconnect] " .. msg)
    if reconnect.config.announce and type(formattedAddChatMessage) == 'function' then
        pcall(formattedAddChatMessage, msg)
    end
end

-- profile value lookup: per-call override -> reason profile -> global config
local function opt(name)
    local st = reconnect.state
    local ov = st.overrides
    if ov and ov[name] ~= nil then return ov[name] end
    local profile = reconnect.reasons[st.reason]
    if profile and profile[name] ~= nil then return profile[name] end
    return reconnect.config[name]
end

-- sampGetCurrentServerAddress can come back empty once the session is gone,
-- so the last valid address is cached and reused.
local function currentAddress()
    local ok, ip, port = pcall(sampGetCurrentServerAddress)
    port = tonumber(port)
    if ok and type(ip) == 'string' and #ip > 0 and ip ~= "0.0.0.0" and port and port > 0 then
        reconnect.state.lastAddress = {ip = ip, port = port}
    end
    return reconnect.state.lastAddress
end

-- cancellable sleep: returns false as soon as this run has been superseded
local function sleep(gen, ms)
    local step = reconnect.config.pollInterval
    local elapsed = 0
    while elapsed < ms do
        if reconnect.state.generation ~= gen then return false end
        local slice = math.min(step, ms - elapsed)
        wait(slice)
        elapsed = elapsed + slice
    end
    return reconnect.state.generation == gen
end

local function resetState()
    local st = reconnect.state
    st.active = false
    st.reason = nil
    st.label = nil
    st.attempt = 0
    st.burst = 0
    st.overrides = nil
    st.thread = nil
    st.selfDisconnect = false
    st.dialed = false
end

-- Reasons a run can inflict on itself: dropping the live session, or dialing
-- over a half-open one, makes the client raise its own disconnect event. Those
-- must not be mistaken for the server dropping us or they take over the run
-- that caused them (the manual reconnect announcing twice).
local SELF_INFLICTED = {closed = true, lost = true}

local function attemptLabel()
    local max = opt('maxAttempts')
    if max and max > 0 then
        return ("attempt %d/%d"):format(reconnect.state.attempt, max)
    end
    return ("attempt %d"):format(reconnect.state.attempt)
end

local function worker(gen)
    local st = reconnect.state

    while st.generation == gen do
        st.attempt = st.attempt + 1

        local delay = math.min(opt('delay') * (opt('backoff') ^ (st.attempt - 1)), opt('maxDelay'))
        announce("%s - reconnecting in %d sec (%s)", st.label, math.floor(delay / 1000 + 0.5), attemptLabel())
        if not sleep(gen, delay) then return end

        -- somebody (the user, another script) got us back on a server while we
        -- were waiting: nothing left to do
        if st.reason ~= 'manual' and sampGetGamestate() == GAMESTATE.CONNECTED then
            announce("Already connected again, reconnect cancelled.")
            resetState()
            return
        end

        -- No explicit disconnect here even when still connected: SA-MP already
        -- shuts the netgame down inside sampConnectToServer. Doing both makes
        -- the client restart twice ("The server is restarting.." printed back
        -- to back) for one reconnect.
        if not sleep(gen, opt('settle')) then return end

        local addr = currentAddress()
        if not addr then
            announce("No server address known, reconnect aborted.")
            resetState()
            return
        end

        st.selfDisconnect = true
        st.dialed = true
        sampConnectToServer(addr.ip, addr.port)

        -- dial phase: as soon as the new session starts progressing, any
        -- further disconnect event is the server's doing again, so the
        -- self-inflicted guard is lifted early rather than at the timeout
        local connected = false
        local timeout, step, elapsed = opt('connectTimeout'), reconnect.config.pollInterval, 0
        while st.generation == gen do
            local gs = sampGetGamestate()
            if gs == GAMESTATE.AWAIT_JOIN or gs == GAMESTATE.CONNECTED then
                st.selfDisconnect = false
            end
            if gs == GAMESTATE.CONNECTED then
                connected = true
                break
            end
            if elapsed >= timeout then break end
            wait(step)
            elapsed = elapsed + step
        end
        st.selfDisconnect = false
        if st.generation ~= gen then return end

        if connected then
            announce("Reconnected to %s:%d.", addr.ip, addr.port)
            resetState()
            return
        end

        announce("Attempt %d failed (gamestate: %s).", st.attempt, gamestateName())

        local max = opt('maxAttempts')
        if max and max > 0 and st.attempt >= max then
            st.burst = st.burst + 1
            local maxBursts = opt('maxBursts')
            if maxBursts and maxBursts > 0 and st.burst >= maxBursts then
                announce("Giving up after %d attempts. Use /recon to try again.", st.attempt * st.burst)
                resetState()
                return
            end
            local cooldown = opt('cooldown')
            announce("Failed %d attempts, waiting %d sec before trying again.", st.attempt, math.floor(cooldown / 1000 + 0.5))
            if not sleep(gen, cooldown) then return end
            st.attempt = 0
        end
    end
end

-- Starts (or replaces) a reconnect run.
--   reason: key into reconnect.reasons, defaults to "manual"
--   opts:   optional per-run overrides (label, delay, maxAttempts, ...)
function reconnectToServer(reason, opts)
    local st = reconnect.state
    reason = reconnect.reasons[reason] and reason or 'manual'

    local profile = reconnect.reasons[reason]
    local label = (opts and opts.label) or profile.label or reason

    -- our own teardown echoing back as a disconnect event
    if st.active and st.selfDisconnect and SELF_INFLICTED[reason] then
        print(("[reconnect] ignoring '%s' - caused by our own reconnect (%s)"):format(reason, tostring(st.reason)))
        return false
    end

    if st.active then
        -- a user-triggered reconnect wins over any event-driven run; an event
        -- only takes over when it warrants a longer wait than the run already
        -- in flight (a ban landing mid-retry, for example)
        local takeover = reason == 'manual' and st.reason ~= 'manual'

        -- a repeated manual press only restarts the schedule once the current
        -- run has actually dialed; before that it would just re-announce the
        -- same pending attempt
        if reason == 'manual' and st.reason == 'manual' then
            takeover = st.dialed
        end

        if not takeover and reason ~= st.reason then
            local newDelay = (opts and opts.delay) or profile.delay or reconnect.config.delay
            takeover = newDelay > opt('delay')
        end

        if not takeover then
            print(("[reconnect] ignoring '%s' - already reconnecting (%s, %s)"):format(reason, st.reason, attemptLabel()))
            return false
        end

        -- the new reason starts at its own base delay. Only a strictly longer
        -- delay may take over, so escalation is bounded and cannot loop.
        st.generation = st.generation + 1
        st.attempt = 0
    else
        st.attempt = 0
        st.burst = 0
        st.generation = st.generation + 1
    end

    st.active = true
    st.reason = reason
    st.label = label
    st.overrides = opts
    st.selfDisconnect = false
    st.dialed = false

    currentAddress()

    local gen = st.generation
    st.thread = lua_thread.create(function() worker(gen) end)
    return true
end

-- Stops any pending reconnect. The worker exits on its own at its next
-- checkpoint (never terminate a running lua_thread).
function cancelReconnect(silent)
    local st = reconnect.state
    if not st.active then return false end
    st.generation = st.generation + 1
    local reason = st.reason
    resetState()
    if not silent then
        announce("Reconnect cancelled (%s).", tostring(reason))
    end
    return true
end

-- Call this when the connection is confirmed (onConnectionRequestAccepted):
-- it settles the run without waiting for the gamestate poll to catch up.
function reconnectSucceeded()
    local st = reconnect.state
    currentAddress()
    if not st.active then return false end
    st.generation = st.generation + 1
    resetState()
    announce("Connected, reconnect finished.")
    return true
end

function isReconnecting()
    return reconnect.state.active
end

function reconnectStatus()
    local st = reconnect.state
    return {
        active = st.active,
        reason = st.reason,
        label = st.label,
        attempt = st.attempt,
        burst = st.burst,
        address = st.lastAddress,
        gamestate = gamestateName()
    }
end

-- Merge tunables at runtime: configureReconnect{delay = 3000, reasons = {banned = {delay = 90000}}}
function configureReconnect(tbl)
    if type(tbl) ~= 'table' then return reconnect.config end
    for k, v in pairs(tbl) do
        if k == 'reasons' and type(v) == 'table' then
            for reason, fields in pairs(v) do
                reconnect.reasons[reason] = reconnect.reasons[reason] or {}
                for field, value in pairs(fields) do
                    reconnect.reasons[reason][field] = value
                end
            end
        else
            reconnect.config[k] = v
        end
    end
    return reconnect.config
end

--[[
    formattedAddChatMessage(message, color)

    "[<script>] <message>", tagged and coloured, in every mod's own voice.

    SIX COPIES OF THIS EXISTED - driving, wanted, vstorage, fastmap, autofps
    and hud each defined it at the top of the entry, and four were
    byte-identical. hud's was the odd one out and was subtly wrong:

        function formattedAddChatMessage(string, color)
            sampAddChatMessage(string.format("...", firstToUpper(scriptName), string), color)

    The parameter is named `string`, which shadows the standard library inside
    the function. It happens to work - indexing a Lua string with `.format`
    reaches the same function through the string metatable - but it also meant
    hud passed `color` as sampAddChatMessage's colour argument while the other
    five embedded it as a {RRGGBB} tag and always passed -1. Two different
    behaviours from one name.

    The tag form wins, because it is what five of the six did and it survives
    being concatenated into a longer line.

    The script name comes from setChatTag(), called once at startup. Without it
    the tag falls back to the running script's own name, so a mod that forgets
    to call it gets something sensible rather than "[nil]".
]]
local chatTag = nil

function setChatTag(name)
    chatTag = name and tostring(name) or nil
    return chatTag
end

function chatTagName()
    if chatTag then return chatTag end
    local ok, this = pcall(thisScript)
    return (ok and this and this.name) or 'script'
end

function formattedAddChatMessage(message, color)
    -- Guarded: a mod that reports something during startup can reach this
    -- before the chat exists, and sampAddChatMessage faults rather than
    -- no-opping when it does.
    if type(isSampAvailable) == 'function' and not isSampAvailable() then return end
    sampAddChatMessage(
        ("{%06x}[%s]{FFFFFF} %s"):format(color or 0xC8C8C8, chatTagName(), tostring(message)),
        -1)
end

function extra_funcs.install_globals(t)
    t = t or _G
    for k, v in pairs(extra_funcs) do
        if type(v) == 'function' and not tostring(k):match('^_') then
            t[k] = v
        end
    end
    return t
end

return extra_funcs