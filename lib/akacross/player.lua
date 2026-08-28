--[[
    akacross.player - the local player's live state, read from the game.

    WHY IT EXISTS
    -------------
    hud.lua had all of this and nothing else could reach it. They are not
    HUD-specific facts - they are "what is the player doing right now", which
    is the question autobind's automation, admintools' hacks, the speedometer
    and any future overlay all ask.

    They stayed in hud only because hud was a single file with nowhere to put
    them.

    WHAT IS AND IS NOT HERE
    -----------------------
    Here: reads that need a hardcoded address, a pointer walk, or a piece of
    arithmetic nobody remembers the constant for.

    NOT here: the one-line wrappers that already live in akacross.functions
    (`getZoneName`, `getSubZoneName`, `getVehicleName`, `findPlayer`,
    `formatNumber`). hud had its own copies of all five; they are deleted
    rather than moved, because a second home for a function that already has
    one is how the two versions of `formattedAddChatMessage` happened.

    EVERY ADDRESS IS NAMED AND SOURCED. A bare 0xB7CDB4 in a mod is a number
    nobody can verify; the constant table below is the whole point of the
    module being a module.

    GUARDED, because these are pointer reads. A `memory` module that failed to
    load, or a pointer that is null because the player is not streamed in,
    must return a sane zero rather than fault the render pass that asked.
]]

local M = { _VERSION = '0.1.0' }

local okMem, mem = pcall(require, 'memory')
if not okMem then mem = nil end

-- ---------------------------------------------------------------------------
-- Addresses
-- ---------------------------------------------------------------------------
--[[
    gta_sa.exe 1.0 US. Every one of these was a bare literal in hud.lua.

      SPRINT_ENERGY   CPlayerInfo::m_nSprintEnergy, a float that runs 0..31.47
                      rather than 0..100 - hence the divisor rather than a
                      percentage.
      BREATH          CPlayerInfo::m_fBreath, 0..39.97 on the same footing.
      WANTED_LEVEL    CWanted::m_nWantedLevel, one byte.
      PED_WEAPON_SLOT CPed::m_aWeapons - the weapon array on the ped struct.
                      Ammo-in-clip sits at +0x8 of the slot, and a slot is
                      0x1C wide.
]]
M.ADDR = {
    SPRINT_ENERGY = 0xB7CDB4,
    BREATH        = 0xB7CDE0,
    WANTED_LEVEL  = 0x58DB60,
}

-- The two scale factors the raw floats above need. Named, because
-- `/ 31.47000244` in a render pass is unreadable and unverifiable.
local SPRINT_FULL = 31.47000244
local BREATH_FULL = 39.97000244

-- CPed weapon array geometry.
local PED_WEAPONS_OFFSET = 0x5A0
local WEAPON_SLOT_SIZE   = 0x1C
local WEAPON_AMMO_CLIP   = 0x8

-- ---------------------------------------------------------------------------
-- Meters
-- ---------------------------------------------------------------------------
--- Sprint energy as 0..100. Floor, not round: a bar that reads 100 while the
--- player is a hair short of full is the more annoying error.
function M.sprintLevel()
    if not mem then return 0 end
    local ok, v = pcall(mem.getfloat, M.ADDR.SPRINT_ENERGY)
    if not ok or type(v) ~= 'number' then return 0 end
    return math.floor(v / SPRINT_FULL)
end

--- Remaining breath as 0..100.
function M.waterLevel()
    if not mem then return 0 end
    local ok, v = pcall(mem.getfloat, M.ADDR.BREATH)
    if not ok or type(v) ~= 'number' then return 0 end
    return math.floor(v / BREATH_FULL)
end

--- The star count, 0..6.
function M.wantedLevel()
    if not mem then return 0 end
    local ok, v = pcall(mem.getuint8, M.ADDR.WANTED_LEVEL)
    return (ok and type(v) == 'number') and v or 0
end

--[[
    Ammo in the CLIP for a weapon the given ped is carrying, which is not what
    getAmmoInCharWeapon returns - that is the total. The difference is the
    whole point of a "17 / 102" ammo readout.

    Walks CPed -> m_aWeapons[slot].ammoInClip. A null char pointer (not
    streamed in) reads as zero rather than faulting.
]]
function M.ammoInClip(ped, weapon)
    if not mem then return 0 end
    local okPtr, ptr = pcall(getCharPointer, ped)
    if not okPtr or not ptr or ptr == 0 then return 0 end
    local okSlot, slot = pcall(getWeapontypeSlot, weapon)
    if not okSlot or type(slot) ~= 'number' then return 0 end
    local ok, v = pcall(mem.getint32,
        ptr + PED_WEAPONS_OFFSET + slot * WEAPON_SLOT_SIZE + WEAPON_AMMO_CLIP)
    return (ok and type(v) == 'number') and v or 0
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------
--[[
    getCarSpeed returns a per-frame velocity, not km/h. These are the two
    factors that turn it into something a human reads.

    4.80 and 2.98 rather than a derived constant because they are what the
    server's own speedometer uses, and a readout that disagrees with the one
    the game shows is worse than one that is a per-cent off in absolute terms.
]]
M.KMH_FACTOR = 4.80
M.MPH_FACTOR = 2.98

function M.convertSpeed(speed, isMPH)
    return math.ceil(speed * (isMPH and M.MPH_FACTOR or M.KMH_FACTOR))
end

--[[
    Sprint is a KEY STATE, not a game flag, so it has to be sampled and held.

    The game gives no "is sprinting" bit worth reading: the key is pressed in
    bursts and the ped keeps running between them. `hold` is how long a release
    is ignored before the answer flips back, which is what stops a sprint bar
    strobing at the tapping rate.

    Per Lua state, like everything else here - two mods asking are two
    independent samplers, which is correct: they may poll at different rates.
]]
local sprint = {active = false, last = -math.huge, hold = 0.8}

--- Call once per tick with the result of the game's sprint-key test.
function M.feedSprint(pressed, now)
    now = now or os.clock()
    if pressed then
        sprint.active = true
        sprint.last = now
    elseif (now - sprint.last) > sprint.hold then
        sprint.active = false
    end
    return sprint.active
end

function M.isSprinting() return sprint.active end

--- How long a release is ignored before `isSprinting` flips back.
function M.setSprintHold(seconds) sprint.hold = tonumber(seconds) or 0.8 end

-- ---------------------------------------------------------------------------
-- Facing
-- ---------------------------------------------------------------------------
--[[
    The eight compass points, in the order a GTA heading runs.

    NOT the order you would write down. The game's heading increases
    COUNTER-CLOCKWISE, so 23-67 degrees is north-WEST, not north-east. The
    first draft of this module had it the intuitive way round and was simply
    wrong; this table is hud's shipping one, which has been on screen for
    years.

    Two entries for North because the range wraps through 0: a single
    {min = 330, max = 22} would never match anything.

    Long names by default because that is what the only consumer used. A mod
    that wants "NW" passes its own table to setCompass().
]]
local COMPASS = {
    {min = 0,   max = 22,  name = 'North'},
    {min = 23,  max = 67,  name = 'Northwest'},
    {min = 68,  max = 112, name = 'West'},
    {min = 113, max = 157, name = 'Southwest'},
    {min = 158, max = 202, name = 'South'},
    {min = 203, max = 247, name = 'Southeast'},
    {min = 248, max = 292, name = 'East'},
    {min = 293, max = 329, name = 'Northeast'},
    {min = 330, max = 360, name = 'North'},
}

M.COMPASS = COMPASS

--- Swap the point set - for short names, or a localised one.
function M.setCompass(points)
    COMPASS = points or M.COMPASS
end

--- A heading in degrees to a compass point, or nil if it is out of range.
function M.direction(angle)
    local a = math.floor(angle or 0)
    for i = 1, #COMPASS do
        local dir = COMPASS[i]
        if a >= dir.min and a <= dir.max then return dir.name end
    end
    return nil
end

--- Where the CAMERA is looking, which is not where the ped is facing. A
--- direction readout wants this one while the player is free-looking.
function M.cameraHeading()
    local okC, cx, cy = pcall(getActiveCameraCoordinates)
    local okT, tx, ty = pcall(getActiveCameraPointAt)
    if not (okC and okT and cx and tx) then return 0 end
    local ok, h = pcall(getHeadingFromVector2d, tx - cx, ty - cy)
    return (ok and h) or 0
end

-- ---------------------------------------------------------------------------
-- Location
-- ---------------------------------------------------------------------------
--[[
    Custom zones: boxes a mod cares about that the game has no name for
    (a server's own districts, a gang's turf). Registered rather than
    hardcoded, because the set is per-server and this module is not.

    box = {x1, y1, z1, x2, y2, z2}
]]
local customZones = {}

function M.setCustomZones(zones) customZones = zones or {} end

function M.customZoneName(x, y, z)
    for name, box in pairs(customZones) do
        if x >= box[1] and x <= box[4]
           and y >= box[2] and y <= box[5]
           and z >= box[3] and z <= box[6] then
            return name
        end
    end
    return nil
end

--[[
    zoneOf(handle) -> zone, subZone

    The name a human would give the place a ped is standing, and the finer one
    under it if there is one.

    'Interior' wins over both: inside a building the world coordinates are off
    in the interior stack somewhere and the zone they resolve to is nonsense.

    Requires akacross.functions for getZoneName / getSubZoneName rather than
    carrying its own - see the note at the top about second homes.
]]
function M.zoneOf(handle)
    local ok, x, y, z = pcall(getCharCoordinates, handle)
    if not ok or not x then return nil, nil end

    local interior = 0
    local okI, i = pcall(getActiveInterior)
    if okI then interior = i or 0 end

    local zone
    if interior ~= 0 then
        zone = 'Interior'
    else
        zone = M.customZoneName(x, y, z)
        if not zone then
            local okZ, name = pcall(getZoneName, x, y, z)
            zone = okZ and name or nil
        end
    end

    local okS, sub = pcall(getSubZoneName, x, y, z)
    return zone, (okS and sub or nil)
end

return M
