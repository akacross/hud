--[[
    akacross.rp - the roleplay facts every mod split out of autobind needs.

    THE PROBLEM
    -----------
    Seven of autobind's feature modules ask "am I muted?" before sending a
    command, and most of them ask "who am I, what org am I in, am I a lawyer"
    to decide whether to run at all. Today those live in entry-owned globals
    (`timers.Muted`, `CurrentPlayerInfo`, `Settings.mode`, `Faction`, `wanted.
    lawyer`) that a separate script cannot reach: MoonLoader gives every script
    its own Lua state, so there is no shared table and no import.

    THE KEY OBSERVATION
    -------------------
    Every state receives every server message. `sampev.onServerMessage` is a
    per-state hook on the same incoming packet, so all of these facts are
    DERIVABLE INDEPENDENTLY in each mod from a stream it already sees. Nothing
    has to be transported between scripts, and there is no producer to keep
    alive, no staleness window and no serialisation format to agree on.

    What is NOT derivable is the ASKING. `/stats` has to be sent for the reply
    to exist, and five mods each sending it would mean five commands and five
    attempts to hide the output. So this module coordinates the REQUEST (one
    owner, via akacross.claims) and lets every state parse the ANSWER.

        fact  -> derived locally, per state, no coordination
        action -> owned by exactly one state, via claims

    That split is the whole design. It is the same "derive, never negotiate"
    property akacross.cursor and akacross.claims already rely on.

    WHAT IS AND IS NOT IN HERE
    --------------------------
    Only facts more than one mod needs: mute, name/id, org kind and name, the
    RP mode that follows from them, and lawyer/LEO status. Per-feature state
    (vest cooldowns, wanted lists, locker kits) stays with its feature, and the
    stats lines carrying wealth/crimes/materials stay in autobind - those are
    one mod's data, not a shared fact.

    SERVER PATTERNS ARE DATA
    ------------------------
    Every pattern lives in a profile, so pointing this at another server is a
    table, not a code change (see docs/SPLIT_RP.md and PEMENU_PORTING.md - the
    chat layer is the single biggest cost of a port).

    USAGE
    -----
        local rp = require('akacross.rp')

        rp.setup{script = 'leo', profile = rp.profiles.hrp}

        function sampev.onServerMessage(color, text)
            rp.feed(color, text)      -- never suppresses; that is yours
            ...
        end

        if not rp.muted() then sampSendChat('/wanted') end
        local me = rp.identity()
        if me.lawyer then ... end

        -- one state does the asking, everyone parses the reply
        if rp.needsStats() and rp.ownsStats() then
            sampSendChat(rp.statsCommand())
            rp.statsRequested()
        end
]]

local rp = {}
rp._VERSION = '0.2.2'

local CLAIM = 'rp.stats'

-- ---------------------------------------------------------------- profiles
rp.profiles = {}

rp.profiles.hrp = {
    id = 'hrp',
    name = 'Horizon Roleplay',
    -- The substring detect() looks for in sampGetCurrentServerName(). Plain
    -- text, not a pattern: a server name is decorated with punctuation and
    -- colour tags that a pattern would have to escape.
    match = 'Horizon',
    statsCommand = '/stats',
    muted = {
        pattern = '^You have been muted automatically for spamming%. Please wait 10 seconds and try again%.$',
        -- The server says 10; autobind has always waited 13, because the mute
        -- lands a beat after the line and a command sent at t+10 gets eaten.
        seconds = 13,
    },
    welcome = {pattern = '^Welcome to Horizon Roleplay, (.-)%.$'},
    -- The org/rank stats line: (Faction: X) - (Rank: Y) - (Division) - (Job: ...) - (Job 2: ...)
    orgLine = {
        pattern = '^%((.-)%)%s*-%s*%(Rank%:%s*(.-)%)%s*-%s*%((.-)%)%s*-%s*%(Job%:%s*(.-)%)%s*-%s*%(Job%s*2:%s*(.-)%)?$',
        factionNone = '^Faction%:%s*None$',
        faction = '^Faction%:%s*(.-)$',
        family = '^Family%:%s*(.-)$',
        lawyerJob = '^Lawyer %[lvl%: (.-)%]$',
    },
}

rp.profiles.prp = {
    id = 'prp',
    name = 'Paraiso Roleplay',
    -- The welcome line says "Paraiso Gaming" while the server name says
    -- "Paraiso Roleplay"; the shared word is what detect() matches on.
    match = 'Paraiso',
    statsCommand = '/stats',
    muted = rp.profiles.hrp.muted, -- same pattern and wait time.
    welcome = {pattern = '^Welcome to Paraiso Gaming, (.-)%.$'},
    orgLine = rp.profiles.hrp.orgLine,
}

--[[
    Lawless is DETECTION ONLY - deliberately no patterns.

    autobind has a handler table for it, so something has to be able to say
    "this is Lawless"; but its mute line, its welcome and its stats format have
    never been captured, and inheriting Horizon's would be a guess that fails
    silently (a welcome that never matches means /stats is never asked for,
    which is the exact bug detection was added to fix).

    feed() reads every pattern group behind an `if`, so a profile with none
    simply derives nothing until someone captures them. That is honest: no
    identity is better than a wrong one.
]]
rp.profiles.lrp = {
    id = 'lrp',
    name = 'Lawless Roleplay',
    match = 'Lawless',
    statsCommand = '/stats',
    --[[
        The one pattern that IS carried over, and only because autobind had it
        before this profile existed: with no lrp profile, Lawless ran Horizon's,
        so it had mute detection. The wording is SA-MP boilerplate that Paraiso
        shares verbatim, so keeping it preserves what worked and costs nothing
        if Lawless words it differently - an unmatched pattern is the same as
        no pattern.

        `welcome` and `orgLine` are deliberately NOT carried: those are
        server-specific formats, and inheriting Horizon's risked the worse
        failure of matching and producing a WRONG identity.
    ]]
    muted = rp.profiles.hrp.muted,
}

--[[
    Detection order. A list, not `pairs(rp.profiles)`, for two reasons: hash
    order is not stable between runs, so an overlapping pair of `match` strings
    would resolve differently on different launches; and the order is a
    decision (most specific first) that a table cannot express.

    Appending a profile here is what makes it detectable - `rp.profiles.x`
    alone only makes it selectable by hand.
]]
rp.profileOrder = {rp.profiles.hrp, rp.profiles.prp, rp.profiles.lrp}

-- ------------------------------------------------------------------- state
local state = {
    script = nil,
    profile = rp.profiles.hrp,
    log = print,
    clock = os.clock,
    claims = nil,          -- akacross.claims, when available
    mutedUntil = 0,
    wantStats = false,     -- a welcome was seen and no identity has followed
    statsSentAt = nil,
    identity = {
        name = nil, id = nil,
        mode = 'Civilian',   -- Civilian | Faction | Family, derived from the org line
        org = nil,           -- faction or family name
        orgKind = nil,       -- 'faction' | 'family' | nil
        rank = nil,
        lawyer = false,
        at = nil,            -- clock stamp of the last identity update
    },
    listeners = {},
    profileListeners = {},
    -- false until something has actually DECIDED the profile - a detect() that
    -- matched, or an explicit setup{profile = ...}. The default above is a
    -- fallback, not an answer, and onProfile has to be able to tell them apart.
    profileKnown = false,
    attachReported = false,
}

--[[
    setup(opts)

    opts.script    this script's name, for claims. Without it the state simply
                   always owns the request - a mod running alone must still ask.
    opts.profile   server profile (defaults to hrp)
    opts.claims    an akacross.claims instance; soft-required when omitted
    opts.log, opts.clock (injectable for tests)
]]
function rp.setup(opts)
    opts = opts or {}
    state.script = opts.script or state.script
    if opts.profile then
        -- An explicit profile is a DECISION and outranks detection, which is
        -- what the tests rely on and what a user override needs.
        state.profile = opts.profile
        state.profileKnown = true
    end
    state.log = opts.log or state.log
    state.clock = opts.clock or state.clock

    if opts.claims ~= nil then
        state.claims = opts.claims or nil
    elseif state.script then
        local ok, claims = pcall(require, 'akacross.claims')
        if ok and claims then
            state.claims = claims
            pcall(claims.setup, {script = state.script})
            pcall(claims.claim, CLAIM)
        end
    end
    return rp
end

function rp.profile() return state.profile end
function rp.statsCommand() return state.profile.statsCommand end
function rp.profileId() return state.profile.id end

--- True once the profile was decided rather than defaulted to.
function rp.detected() return state.profileKnown end

-- --------------------------------------------------------------- detection
--[[
    WHY THIS IS IN THE RUNTIME AND NOT IN EACH MOD

    "Which server am I on" was answered in three places, three ways, before
    this existed: autobind.lua matched "Paraiso" by hand to pick an rp profile,
    lib/autobind/chat.lua matched a longer server list to pick its handler
    tables, and wanted.lua never asked at all - it called setup{} with no
    profile and so ran Horizon's patterns everywhere.

    That last one is not cosmetic. On any other server the hrp welcome pattern
    never matches, so needsStats() never goes true, /stats is never sent, the
    org line is never parsed, and `identity().lawyer` stays false forever -
    which silently holds shut every gate built on it (the wanted overlay's,
    for one). One shared answer fixes every mod at once.
]]

--- Notify the profile listeners. Declared ABOVE setProfile deliberately:
--- Lua resolves a name the compiler has not seen yet as a GLOBAL, so a
--- `local function` written after its caller would be a nil call at runtime,
--- not a load error. (rp's identity `fire()` sits above its callers for the
--- same reason.)
local function fireProfile()
    for _, fn in ipairs(state.profileListeners) do
        local okFire, err = pcall(fn, state.profile)
        if not okFire then
            state.log(('akacross.rp: profile listener failed: %s'):format(tostring(err)))
        end
    end
end

--[[
    detect(serverName) -> profile | nil

    PURE - name in, profile out, no natives touched. That is what lets the
    tests cover the interesting half without a game.

    nil rather than a default on no match: the caller has to be able to tell
    "this is Paraiso" from "I have no idea what this is", because the second
    case should leave whatever profile is already in place alone.
]]
function rp.detect(serverName)
    if type(serverName) ~= 'string' or serverName == '' then return nil end
    for _, profile in ipairs(rp.profileOrder) do
        if profile.match and serverName:find(profile.match, 1, true) then
            return profile
        end
    end
    return nil
end

--[[
    Set the live profile and notify. Returns the profile in force afterwards.

    IT ALSO FIRES ON THE FIRST DETECTION OF THE DEFAULT PROFILE, and that is
    not a nicety - it is a bug fix (0.2.2).

    `state.profile` starts as `profiles.hrp` so that every accessor has
    something to read before detection. Detecting Horizon therefore hands back
    THE SAME TABLE, so a plain `profile ~= state.profile` was false and no
    listener ever ran. A mod driven entirely by `onProfile` was live on Paraiso
    and completely inert on Horizon - which is exactly how hud 1.4.39 shipped a
    Horizon profile that never once ran, and why its signatures looked wrong
    when most of them were right.

    Going from DEFAULTED to KNOWN is a real transition even when the profile
    object does not move, so it is reported. `wasKnown` is what makes this
    fire once rather than on every attach() retry.
]]
function rp.setProfile(profile)
    if not profile then return state.profile end
    local wasKnown = state.profileKnown
    local changed = profile ~= state.profile
    state.profile = profile
    state.profileKnown = true
    if changed or not wasKnown then fireProfile() end
    return profile
end

--[[
    attach(opts) -> profile | nil

    One ATTEMPT to read the server name and select a profile. Returns nil while
    the answer is not available yet, so the caller drives the retry:

        if not rpM.detected() then rpM.attach() end   -- in the main loop

    It has to be retried, and this is the trap the whole call is shaped around:
    sampGetCurrentServerName() returns an empty string until the connection
    completes. A mod that detects once at load sits on the default profile for
    the entire session and looks exactly like a mod with no detection at all.

    Natives are injectable (opts.serverName, opts.gamestate) so the tests need
    no game; both default to the real ones when present.
]]
function rp.attach(opts)
    opts = opts or {}

    local gamestate = opts.gamestate
    if gamestate == nil then gamestate = _G.sampGetGamestate end
    if type(gamestate) == 'function' then
        local okState, value = pcall(gamestate)
        -- 3 is CONNECTED. Anything else and the name is not readable yet.
        if not okState or value ~= 3 then return nil end
    end

    local getName = opts.serverName or _G.sampGetCurrentServerName
    if type(getName) ~= 'function' then return nil end
    local okName, name = pcall(getName)
    if not okName or type(name) ~= 'string' or name == '' then return nil end

    local profile = rp.detect(name)
    if not profile then
        -- Once, not every tick: this runs from a main loop, and an unknown
        -- server would otherwise write a line per frame for the whole session.
        if not state.attachReported then
            state.attachReported = true
            state.log(('akacross.rp: unknown server %q - staying on the %s profile')
                :format(name, state.profile.name))
        end
        return nil
    end
    return rp.setProfile(profile)
end

--[[
    onProfile(fn) - called with (profile) whenever the live profile changes.

    Fires IMMEDIATELY on registration if the profile is already known, so a
    listener registered after detection is not left waiting for a change that
    has already happened. It stays quiet while the profile is merely the
    default, so a mod on Paraiso is never handed 'hrp' first and made to undo
    work it should not have done.
]]
function rp.onProfile(fn)
    state.profileListeners[#state.profileListeners + 1] = fn
    if state.profileKnown then
        local okFire, err = pcall(fn, state.profile)
        if not okFire then
            state.log(('akacross.rp: profile listener failed: %s'):format(tostring(err)))
        end
    end
    return rp
end

-- ------------------------------------------------------------------- mute
function rp.muted()
    return state.clock() < state.mutedUntil
end

function rp.muteRemaining()
    local left = state.mutedUntil - state.clock()
    return left > 0 and left or 0
end

-- For a mod that learns it is muted some other way (a command rejected, a
-- server line this profile does not know about).
function rp.setMuted(seconds)
    seconds = seconds or (state.profile.muted and state.profile.muted.seconds) or 13
    state.mutedUntil = state.clock() + seconds
end

-- --------------------------------------------------------------- identity
--- A copy, so a caller cannot mutate the derived facts under everyone else.
function rp.identity()
    local id = state.identity
    return {
        name = id.name, id = id.id, mode = id.mode, org = id.org,
        orgKind = id.orgKind, rank = id.rank, lawyer = id.lawyer, at = id.at,
    }
end

--- Called whenever the org line has been parsed. Receives the identity copy.
function rp.onIdentity(fn)
    state.listeners[#state.listeners + 1] = fn
    return rp
end

--- The player id is a game fact, not a chat one: read it live rather than
--- carrying a stale copy. Injectable so the tests need no natives.
function rp.setPlayerId(id) state.identity.id = id end

local function fire()
    local snapshot = rp.identity()
    for _, fn in ipairs(state.listeners) do
        local ok, err = pcall(fn, snapshot)
        if not ok then
            state.log(('akacross.rp: identity listener failed: %s'):format(tostring(err)))
        end
    end
end

-- ------------------------------------------------------- stats request
--- True once a welcome has been seen and no org line has arrived since.
function rp.needsStats() return state.wantStats end

--[[
    ownsStats() -> bool

    Exactly one live script should send the command. Resolution is claims':
    every state computes the same answer from the same registry, and when the
    registry cannot be read at all claims reports owned - a mod that cannot
    coordinate must still work alone.
]]
function rp.ownsStats()
    if not state.claims then return true end
    local ok, owns = pcall(state.claims.owns, CLAIM)
    if not ok then return true end
    return owns and true or false
end

--- Record that the command went out, so needsStats() stops asking.
function rp.statsRequested()
    state.wantStats = false
    state.statsSentAt = state.clock()
end

-- ------------------------------------------------------------------ feed
--[[
    feed(color, text) -> matched key or nil

    Call from your own onServerMessage. Colour is accepted for callers that
    want to pass it through, but matching is by pattern: colours differ between
    servers and are the first thing to rot on a port, while the text is what
    the player actually reads.

    NEVER suppresses. Whether a line is hidden from chat is the mod's decision
    (autobind hides its own /stats output; a mod that did the same to a stats
    block the user asked for would be a bug), and two mods returning false for
    one line would be indistinguishable from one.
]]
local function feedUnsafe(color, text)
    local p = state.profile

    if p.muted and text:match(p.muted.pattern) then
        rp.setMuted(p.muted.seconds)
        return 'muted'
    end

    if p.welcome then
        local name = text:match(p.welcome.pattern)
        if name then
            state.identity.name = name
            state.wantStats = true
            return 'welcome'
        end
    end

    local org = p.orgLine
    if org then
        local orgField, rank, _division, job, job2 = text:match(org.pattern)
        if orgField then
            local id = state.identity
            id.rank = rank

            local lawyerLevel = (job and job:match(org.lawyerJob))
                or (job2 and job2:match(org.lawyerJob))
            id.lawyer = lawyerLevel ~= nil

            local orgName = orgField:gsub('Faction: ', ''):gsub('Family: ', '')
            if orgField:match(org.factionNone) then
                id.mode, id.org, id.orgKind = 'Civilian', nil, nil
            elseif orgField:match(org.faction) then
                id.mode, id.org, id.orgKind = 'Faction', orgName, 'faction'
                -- every faction member is LEO-adjacent for the purposes the
                -- wanted list cares about; autobind has always set this here
                id.lawyer = true
            elseif orgField:match(org.family) then
                id.mode, id.org, id.orgKind = 'Family', orgName, 'family'
            else
                state.log(('akacross.rp: unrecognised org field %q'):format(tostring(orgField)))
            end

            id.at = state.clock()
            state.wantStats = false
            fire()
            return 'org'
        end
    end

    return nil
end

--[[
    The profile is data, and a malformed pattern in it raises from string.match.
    feed() runs on EVERY chat line in the caller's onServerMessage, so a bad
    pattern that propagated would break chat itself rather than just this
    module's facts. Contain it here instead of asking every caller to wrap the
    call, and report each distinct failure once - it would otherwise repeat for
    every line the player sees.
]]
local reported = {}

function rp.feed(color, text)
    if type(text) ~= 'string' then return nil end
    local ok, result = pcall(feedUnsafe, color, text)
    if ok then return result end
    if not reported[tostring(result)] then
        reported[tostring(result)] = true
        state.log(('akacross.rp: feed failed (reported once): %s'):format(tostring(result)))
    end
    return nil
end

--- Test seam: drop every derived fact and listener.
function rp.reset()
    reported = {}
    state.mutedUntil = 0
    state.wantStats = false
    state.statsSentAt = nil
    state.identity = {mode = 'Civilian', lawyer = false}
    state.listeners = {}
    state.profileListeners = {}
    state.profileKnown = false
    state.attachReported = false
    -- The profile is a derived fact too, and it used to survive reset() purely
    -- because every test re-passed one through setup{}. A test that does not
    -- then inherits the previous test's server, which is the sort of ordering
    -- dependency that only shows up once someone adds a case in the middle.
    state.profile = rp.profiles.hrp
    return rp
end

return rp
