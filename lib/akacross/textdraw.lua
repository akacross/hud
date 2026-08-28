--[[
    akacross.textdraw - reading the SA-MP textdraw pool.

    WHY THIS IS SHARED

    Three scripts in this family already read textdraws, and all three wrote
    their own version of the same two mechanics:

      admintools.lua      sweeps 0..3000 on every call, looking for the turf
                          owner draw by position and box size
      reports.lua         matches the server's report textdraw by position to
                          zero its letter size and hide it
      lib/wanted/state.lua  string-matches the object-streaming notice, colour
                          codes and all

    None of them is about the same feature, which is what makes this runtime
    work rather than mod work (docs/WANTED_SOURCES.md). A fourth is coming:
    Paraiso publishes its wanted list as a textdraw, with no command behind it.

    TWO MECHANICS, AND NEITHER IS COMPLETE ALONE

    1. `sampev.onShowTextDraw` is free - it is an RPC hook, so it costs nothing
       until the server sends one. But it only ever sees textdraws created
       WHILE IT IS LISTENING. Anything the server drew before the script
       loaded, or before the player became a cop, is invisible to it forever.

    2. A pool sweep sees everything, and cannot run per frame: 2304 native
       calls is not something to do 60 times a second for a value that changes
       every few seconds.

    So `watch` runs the hook as the primary signal and the sweep as a slow
    reconcile behind it. That pairing is the whole reason this module exists;
    either half alone is a bug that only shows up in one specific order of
    events, which is the kind nobody reproduces on purpose.

    NATIVES ARE INJECTED. Defaults come from _G when the module is loaded into
    a game, so a caller normally passes nothing; the tests pass a fake pool.
]]

local M = { _VERSION = '0.2.0' }

--[[
    The pool is 2048 server textdraws plus 256 player textdraws. admintools
    sweeps to 3000, which is harmless but is ~700 native calls per pass spent
    on slots that cannot exist.
]]
M.MAX_ID = 2303

--[[
    The natives this module uses, as an explicit LIST.

    Not `pairs(natives)` over a table declared with nil values: `{exists = nil,
    ...}` is an EMPTY table in Lua, so pairs() yields nothing and both rebind()
    and setup() would silently assign nothing at all. Everything then reads as
    "the pool is empty", which looks exactly like a server that drew no
    textdraws.
]]
local NATIVE_KEYS = {'exists', 'getString', 'getPos', 'getLetter', 'getBox',
                     'setLetter', 'setBox'}

local natives = {}

--[[
    A PLAIN INDEX, not rawget.

    The natives are not necessarily keys on the script's own globals table -
    anything that fronts _G with a metatable (moondev does exactly this: each
    script env delegates reads to the real global table through __index) puts
    them one hop away, and rawget skips that hop. The result was every read
    returning nil, which reads as "the pool is empty" and is indistinguishable
    from a server that drew no textdraws.

    There is nothing to protect against here - a missing native simply is not a
    function, and `fallback` covers it.
]]
local function bind(name, fallback)
    local ok, fn = pcall(function() return _G[name] end)
    if ok and type(fn) == 'function' then return fn end
    return fallback
end

--- Re-read the natives out of _G. Called at load, and again by setup(), so a
--- test can install fakes before or after requiring the module.
function M.rebind()
    natives.exists    = bind('sampTextdrawIsExists')
    natives.getString = bind('sampTextdrawGetString')
    natives.getPos    = bind('sampTextdrawGetPos')
    natives.getLetter = bind('sampTextdrawGetLetterSizeAndColor')
    natives.getBox    = bind('sampTextdrawGetBoxEnabledColorAndSize')
    natives.setLetter = bind('sampTextdrawSetLetterSizeAndColor')
    natives.setBox    = bind('sampTextdrawSetBoxColorAndSize')
    return M
end
M.rebind()

--- setup{exists =, getString =, getPos =, ...} - override any native. Anything
--- omitted keeps whatever _G had. This is the test seam.
function M.setup(opts)
    for _, key in ipairs(NATIVE_KEYS) do
        if opts and opts[key] then natives[key] = opts[key] end
    end
    return M
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------
--[[
    SA-MP text formatting is `~x~` tokens: colours (~r~ ~g~ ~b~ ~w~ ~y~ ~p~
    ~l~), a line break (~n~), the size modifier (~h~), and key names
    (~k~~VEHICLE_ENTER_EXIT~). Stripping them is what turns a textdraw into
    something a pattern can be written against WITHOUT the pattern also having
    to know the server's colour choices - which are the first thing to change
    and the last thing anyone remembers to update.
]]
local TOKEN = '~[^~]*~'

--- Drop every formatting token. `~n~` goes too - use lines() to keep it.
function M.strip(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub(TOKEN, ''))
end

--[[
    Split on `~n~` and strip each piece. Order matters and is the reason this
    is not `strip` plus a split: strip() removes `~n~` along with everything
    else, so stripping first turns a six-line textdraw into one long line with
    the words run together.

    Empty lines are kept - a textdraw's blank line is layout, and dropping it
    would shift every index below it.
]]
function M.lines(s)
    local out = {}
    if type(s) ~= 'string' then return out end
    -- gmatch cannot express "and the tail after the last separator", so walk it
    local from = 1
    while true do
        local a, b = s:find('~n~', from, true)
        if not a then
            out[#out + 1] = M.strip(s:sub(from))
            break
        end
        out[#out + 1] = M.strip(s:sub(from, a - 1))
        from = b + 1
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The pool
-- ---------------------------------------------------------------------------
function M.exists(id)
    if not natives.exists then return false end
    local ok, result = pcall(natives.exists, id)
    return ok and result == true
end

--- The raw string, tokens intact, or nil when the slot is empty. Raw because
--- a caller matching on position may want the codes; strip() is one call away.
function M.get(id)
    if not natives.getString or not M.exists(id) then return nil end
    local ok, text = pcall(natives.getString, id)
    if not ok or type(text) ~= 'string' then return nil end
    return text
end

--- x, y or nil.
function M.pos(id)
    if not natives.getPos then return nil end
    local ok, x, y = pcall(natives.getPos, id)
    if not ok or type(x) ~= 'number' then return nil end
    return x, y
end

--[[
    find(predicate, opts) -> list of {id =, text =, x =, y =}

    predicate(id, text, x, y) -> truthy to collect. `text` is RAW; a predicate
    that wants to match words should call strip() itself, and one matching on
    position should not pay for a strip it will not use.

    opts.from, opts.to   bound the sweep (default 0..MAX_ID)
    opts.limit           stop after this many matches - the common case is
                         looking for ONE textdraw, and there is no reason to
                         walk the remaining two thousand slots after finding it
    opts.pos             pass false to skip reading the position, which halves
                         the native calls when the predicate does not want it
]]
function M.find(predicate, opts)
    opts = opts or {}
    local from  = opts.from or 0
    local to    = opts.to or M.MAX_ID
    local limit = opts.limit
    local wantPos = opts.pos ~= false
    local found = {}

    for id = from, to do
        local text = M.get(id)
        if text then
            local x, y
            if wantPos then x, y = M.pos(id) end
            local ok, hit = pcall(predicate, id, text, x, y)
            if ok and hit then
                found[#found + 1] = {id = id, text = text, x = x, y = y}
                if limit and #found >= limit then return found end
            end
        end
    end
    return found
end

--- The first match, or nil. The shape almost every caller actually wants.
function M.first(predicate, opts)
    opts = opts or {}
    opts.limit = 1
    local found = M.find(predicate, opts)
    return found[1]
end

-- ---------------------------------------------------------------------------
-- Hiding
-- ---------------------------------------------------------------------------
--[[
    Blanking a textdraw a mod has replaced with its own drawing.

    Not deleting it: the string has to stay READABLE. A source that parses a
    textdraw and then deletes it has thrown away its own data feed. Zeroing the
    letter size stops the glyphs rendering and leaves sampTextdrawGetString
    answering exactly as before.

    Text and box are separate. A textdraw with a box draws a filled rectangle
    behind the glyphs, and zeroing the letter size does nothing to it - the
    Paraiso wanted panel is built from one boxed row of text and a 2x91 box
    used as a rule, so hiding only the text would leave a black slab and a
    white line on screen.

    ORIGINALS ARE REMEMBERED so restore() can put them back. Unloading a mod
    must not leave a hole in someone's HUD until they reconnect.
]]
local hidden = {}

function M.isHidden(id) return hidden[id] ~= nil end

--- Everything currently blanked, as {id, ...}.
function M.hiddenIds()
    local out = {}
    for id in pairs(hidden) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function M.hide(id)
    if hidden[id] or not M.exists(id) then return false end
    if not natives.setLetter then return false end

    local okL, lx, ly, colour = pcall(natives.getLetter, id)
    if not okL then return false end
    local okB, box, boxColour, bw, bh = pcall(natives.getBox, id)

    hidden[id] = {lx = lx, ly = ly, colour = colour,
                  box = okB and box or nil, boxColour = boxColour, bw = bw, bh = bh}

    pcall(natives.setLetter, id, 0, 0, colour)
    -- box off, size preserved, so restore only has to flip the flag back
    if okB and box and box ~= 0 and natives.setBox then
        pcall(natives.setBox, id, 0, boxColour, bw, bh)
    end
    return true
end

function M.restore(id)
    local was = hidden[id]
    if not was then return false end
    hidden[id] = nil
    -- The slot may have been recycled to something else entirely by now (ids
    -- are reused within a session), so this is best-effort and never fatal.
    if M.exists(id) and natives.setLetter then
        pcall(natives.setLetter, id, was.lx, was.ly, was.colour)
        if was.box and was.box ~= 0 and natives.setBox then
            pcall(natives.setBox, id, was.box, was.boxColour, was.bw, was.bh)
        end
    end
    return true
end

function M.restoreAll()
    local n = 0
    for _, id in ipairs(M.hiddenIds()) do
        if M.restore(id) then n = n + 1 end
    end
    return n
end

--[[
    blankRpc(data) - blank a textdraw in the ShowTextDraw RPC, before the
    client has created it at all.

    The cleanest moment to hide one: it is never drawn even once, so there is
    no flicker on the frame it appears. `text` is untouched, so the mod can
    still read it back out of the pool afterwards.

    Mutates and returns the table, for `return {id, td.blankRpc(data)}`.
]]
function M.blankRpc(data)
    if type(data) ~= 'table' then return data end
    data.letterWidth, data.letterHeight = 0, 0
    data.boxColor = 0
    data.backgroundColor = 0
    return data
end

-- ---------------------------------------------------------------------------
-- watch
-- ---------------------------------------------------------------------------
--[[
    watch(spec) -> watcher

    spec.match(id, text, x, y)   which textdraw is this about
    spec.onChange(text, id)      fired when the matched TEXT changes, and once
                                 when it is first seen. Not per tick and not
                                 per frame: a textdraw that has not changed is
                                 not news, and a caller that re-parses one
                                 every frame is the cost this module exists to
                                 avoid.
    spec.onLost()                fired when the watched textdraw goes away
    spec.hz                      reconcile sweeps per second (default 2)
    spec.opts                    passed through to find() - `from`/`to`/`pos`

    The caller drives it:

        local w = td.watch{match = ..., onChange = ...}
        function sampev.onShowTextDraw(id, data) w:feed(id, data.text) end
        -- and in the main loop:
        w:tick(os.clock())

    `feed` is the fast path and `tick` is the safety net. Both funnel into the
    same change detection, so a textdraw seen twice by two mechanisms fires
    onChange once.
]]
local Watcher = {}
Watcher.__index = Watcher

function M.watch(spec)
    return setmetatable({
        match    = spec.match or function() return false end,
        onChange = spec.onChange,
        onLost   = spec.onLost,
        interval = 1 / (spec.hz or 2),
        opts     = spec.opts,
        log      = spec.log or print,
        id       = nil,
        text     = nil,
        lastSweep = -math.huge,
    }, Watcher)
end

function Watcher:_announce(id, text)
    if text == self.text and id == self.id then return false end
    self.id, self.text = id, text
    if self.onChange then
        local ok, err = pcall(self.onChange, text, id)
        if not ok then
            self.log(('akacross.textdraw: onChange failed: %s'):format(tostring(err)))
        end
    end
    return true
end

--[[
    feed(id, text) - from sampev.onShowTextDraw.

    Note the text comes from the RPC, not from the pool: at the moment this
    hook fires the textdraw has not been created client-side yet, so
    sampTextdrawGetString(id) would return nothing. Reading the pool here
    instead of trusting the argument is the mistake this comment exists to
    prevent.
]]
--- x and y are OPTIONAL but matter: a watcher matching on POSITION cannot
--- match without them, and the RPC carries the position even though the pool
--- entry does not exist yet. Feeding without them was silently unmatchable,
--- which made the hook dead weight for exactly the watchers that need it most.
function Watcher:feed(id, text, x, y)
    if type(text) ~= 'string' then return false end
    local ok, hit = pcall(self.match, id, text, x, y)
    if not ok or not hit then return false end
    return self:_announce(id, text)
end

--[[
    tick(now) - the reconcile sweep, rate limited.

    Two jobs, and the second is the one the hook cannot do: pick up a textdraw
    that already existed, and notice that the watched one has changed under us
    (a server that updates via sampTextdrawSetString sends no ShowTextDraw RPC
    at all, so the hook is silent while the content changes).
]]
function Watcher:tick(now)
    if (now - self.lastSweep) < self.interval then return false end
    self.lastSweep = now

    -- Re-read the one we already hold before walking the whole pool for it.
    if self.id then
        local text = M.get(self.id)
        if text then
            local ok, hit = pcall(self.match, self.id, text, nil, nil)
            if ok and hit then return self:_announce(self.id, text) end
        end
        -- gone, or no longer a match: fall through to a full sweep
        self.id, self.text = nil, nil
        if self.onLost then pcall(self.onLost) end
    end

    local hit = M.first(self.match, self.opts)
    if not hit then return false end
    return self:_announce(hit.id, hit.text)
end

--- Current text, or nil when nothing is being watched.
function Watcher:current() return self.text end

--- Forget what is held, so the next tick re-finds it. For a reconnect, where
--- every id from the previous session is meaningless.
function Watcher:reset()
    self.id, self.text = nil, nil
    self.lastSweep = -math.huge
    return self
end

return M
