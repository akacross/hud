--[[
    akacross.cursor - one owner for the mouse cursor, ImGui input capture and
    the player/camera lock, shared by every akacross mimgui script.

    WHY THIS EXISTS
    ---------------
    Scripts used to flip mimgui's per-subscription `HideCursor` field on window
    open/close edges. That is edge-driven state with no notion of "how many
    windows still need this", so closing one window stole the cursor from
    another that was still open, and any missed edge (Escape, a window closed
    by its own conditions, an error mid-frame) left the cursor or the player
    lock stuck until reload.

    This module replaces those edges with a per-frame *derived reference
    count*: every window registers once as a consumer, and the cursor/input/
    lock state is recomputed from the live set of consumers each frame. There
    is no counter to leak - an unbalanced acquire is impossible, because the
    count is re-derived rather than incremented.

    THREE SEPARATE CAPABILITIES
    ---------------------------
    A consumer asks for any subset of:
      cursor  visible mouse pointer (mimgui -> MoonLoader showCursor)
      input   ImGui receives mouse + keyboard (mimgui.DisableInput)
      lock    player movement locked (mimgui -> MoonLoader lockPlayerControl)
    Each is counted independently, so an always-on overlay can keep `input`
    (it uses imgui.IsMouseClicked for dragging) without ever asking for a
    cursor, and a window can lock the player without a cursor, etc.

    Guards suppress per-capability too (see `scope` below): when something else
    already owns a pointer - SA-MP chat input, a SA-MP dialog, the scoreboard,
    the SAMPFUNCS console - only OUR cursor is dropped. The windows keep
    rendering and keep taking input, so the menus stay usable and there is
    nothing for two cursors to flicker over. Only the states where the game is
    not interactive either (pause, alt-tab, no world) take input away too.

    WHO ACTUALLY CALLS showCursor()
    ------------------------------
    mimgui does, and deliberately so - we only feed it a correct decision by
    writing `HideCursor` / `LockPlayer` on the subscriptions handed to
    attach(). mimgui's ShowCursor/LockPlayer already (a) re-assert every frame
    while wanted and (b) only release when *this* Lua state was the one that
    took them. Keeping it as the single actuator therefore buys us cross-script
    safety for free: two scripts running this module cannot strand each other,
    because a release by one is re-asserted by the other on its next frame,
    and neither ever releases something it did not take. It also keeps the
    global isCursorActive() accurate (mimgui polyfills it on ML 026).

    IMPORTANT: attach() EVERY OnFrame SUBSCRIPTION IN THE SCRIPT.
    mimgui folds HideCursor with AND across all *rendering* subscriptions, so
    an unattached subscription (default HideCursor = false) would force the
    cursor on for as long as it renders.

    USAGE
    -----
        local cursorM = require('akacross.cursor')

        cursorM.setup({ guards = { spawned = false } })   -- optional

        local frame = imgui.OnFrame(cond, draw)
        cursorM.attach(frame)

        cursorM.register('mywindow', {
            condition = function() return window[0] end,
            cursor = true,          -- bool or function
            input  = true,
            lock   = false,
        })

    Nothing else in the script may call showCursor / lockPlayerControl or
    write HideCursor / LockPlayer / mimgui.DisableInput.

    The cursor's screen position is deliberately NOT saved or restored. Wherever
    the game, the SAMPFUNCS console, chat input or the scoreboard leaves the
    pointer is where it belongs; second-guessing that just fought with them.
]]

local M = { _VERSION = '0.2.2' }

local imgui = require 'mimgui'
local bit   = require 'bit'

-- tunables (safe to change from setup())
M.manageInput    = true  -- drive mimgui.DisableInput from the input count
M.softwareCursor = false -- see "who draws the pointer" below
M.debug          = false
M.log            = print

local MAX_GUARD_FAILS = 10 -- a guard that throws this often is dropped for good

local function log(fmt, ...)
    if M.debug and type(M.log) == 'function' then
        M.log('[cursor] ' .. (select('#', ...) > 0 and fmt:format(...) or fmt))
    end
end

--=========================================================================
-- 1. Game-state guards
--=========================================================================
-- A guard returns TRUE when something must be SUPPRESSED, and `scope` says
-- what: omit it to suppress everything, or list only the capabilities that
-- genuinely conflict.
--
--   ALL         nothing of ours may be active: alt-tabbed, paused, or there is
--               no world to point at. In these states the game itself is not
--               interactive either, so taking input away costs nothing.
--   CURSOR_ONLY something else already owns a pointer, so drop ours and let it
--               drive. The window stays up and STAYS CLICKABLE - that matters:
--               overlays such as VehicleStorage never request a cursor of their
--               own (allowCursor = false), they are meant to be clicked with
--               whatever cursor is already on screen. Taking input away from
--               them would silently kill their buttons.
--
-- Guards marked `samp` are skipped while SA-MP is not up, so this module is
-- usable from the main menu and during load (autologin needs exactly that).
--
-- A guard is enabled per script in M.guards; an individual consumer may only
-- *relax* one (opts.guards = { spawned = false }).

local ALL         = nil -- (absent scope == every capability)
local CURSOR_ONLY = { cursor = true }

local focused = true -- maintained by the onWindowMessage handler below

local guardDefs = {
    -- window focus: alt-tabbed away, nothing of ours may hold the mouse
    focus = { needs = {}, samp = false, scope = ALL,
        fn = function() return not focused end },

    -- game pause menu / ESC menu
    pause = { needs = { 'isPauseMenuActive' }, samp = false, scope = ALL,
        fn = function() return isPauseMenuActive() end },

    -- game not in play: loading, cutscene, no ped yet
    playing = { needs = { 'isPlayerPlaying' }, samp = false, scope = ALL,
        fn = function()
            if playerHandle == nil then return false end
            return not isPlayerPlaying(playerHandle)
        end },

    -- Typing in SA-MP chat. Cursor only, and deliberately so: chat input comes
    -- with SA-MP's own pointer, and windows like VehicleStorage exist to be
    -- clicked *while* you have a cursor from somewhere else - they never ask for
    -- one themselves (allowCursor = false). Suppressing input here killed their
    -- buttons (lock/unlock, spawn/unspawn, enter/exit) the moment chat opened.
    --
    -- Leaving input on is safe in practice because mimgui only swallows keys
    -- when io.WantCaptureKeyboard is true, i.e. when an ImGui text field is
    -- actually focused. If one is, it keeps your typing - press Escape or click
    -- off the field first. That matches the behaviour before this module.
    chatInput = { needs = { 'sampIsChatInputActive' }, samp = true, scope = CURSOR_ONLY,
        fn = function() return sampIsChatInputActive() end },

    -- not spawned yet (class selection, login screen). autobind and autologin
    -- both relax this one - their menus are used before spawning - but it stays
    -- available for windows that only make sense in-world.
    spawned = { needs = { 'sampIsLocalPlayerSpawned' }, samp = true, scope = ALL,
        fn = function() return not sampIsLocalPlayerSpawned() end },

    -- The rest are "someone else already has a pointer" cases: cursor only, so
    -- the menus keep working underneath them.
    console = { needs = { 'isSampfuncsConsoleActive' }, samp = false, scope = CURSOR_ONLY,
        fn = function() return isSampfuncsConsoleActive() end },

    dialog = { needs = { 'sampIsDialogActive' }, samp = true, scope = CURSOR_ONLY,
        fn = function() return sampIsDialogActive() end },

    scoreboard = { needs = { 'sampIsScoreboardOpen' }, samp = true, scope = CURSOR_ONLY,
        fn = function() return sampIsScoreboardOpen() end },

    -- SA-MP's own cursor (textdraw selection, anything sampSetCursorMode did).
    --
    -- The naive form of this guard - `return sampIsCursorActive()` - is a trap
    -- and cost us a debugging round: on ML 026 with SA-MP loaded, showCursor()
    -- routes through SA-MP's cursor, so sampIsCursorActive() reads true
    -- *because our own cursor is up*. Used directly it suppresses the very
    -- cursor it is observing, which either kills the pointer outright or
    -- flickers it at frame rate.
    --
    -- So we attribute ownership instead: a SA-MP cursor only counts as
    -- somebody else's if it is up while ours is NOT. That is stable in both
    -- directions - if ours is off it stays off (guard keeps firing), and if
    -- ours is on the reading is our own reflection and is ignored. The case it
    -- cannot see (a dialog appearing while our cursor is already up) is exactly
    -- what the `dialog` guard above covers.
    sampCursor = { needs = { 'sampIsCursorActive' }, samp = true, scope = CURSOR_ONLY,
        fn = function() return sampIsCursorActive() and not M.cursorWanted() end },
}

-- Guards whose MoonLoader/SAMPFUNCS function is missing in this install are
-- dropped at load (autologin can run on RakLua without SAMPFUNCS).
M.guards = {}
for name, def in pairs(guardDefs) do
    local available = true
    for _, needed in ipairs(def.needs) do
        if type(_G[needed]) ~= 'function' then
            available = false
            break
        end
    end
    def.available = available
    def.fails = 0
    M.guards[name] = available
end

local sampCheck = type(isSampLoaded) == 'function' and type(isSampAvailable) == 'function'

-- Evaluated once per frame into this table (reused; no per-frame allocation).
local guardState = {}

local function evaluateGuards()
    local sampReady = sampCheck and isSampLoaded() and isSampAvailable()
    for name, def in pairs(guardDefs) do
        local fired = false
        if def.available and M.guards[name] and (not def.samp or sampReady) then
            local ok, result = pcall(def.fn)
            if ok then
                fired = result and true or false
            else
                def.fails = def.fails + 1
                if def.fails >= MAX_GUARD_FAILS then
                    def.available = false
                    log('guard %q disabled after %d errors: %s', name, def.fails, tostring(result))
                end
            end
        end
        guardState[name] = fired
    end
    return guardState
end

--=========================================================================
-- 2. Consumers
--=========================================================================

local Consumer = {}
Consumer.__index = Consumer

--- True while this consumer is asking for its capabilities. A `condition`
--- function always wins over the imperative flag, so a window's open state
--- stays the single source of truth and a missed edge cannot desync us.
function Consumer:isRequested()
    if self.condition then
        local ok, result = pcall(self.condition)
        if not ok then
            self.condFails = (self.condFails or 0) + 1
            if self.condFails <= 3 then
                log('condition for %q failed: %s', self.name, tostring(result))
            end
            return false
        end
        return result and true or false
    end
    return self._on
end

--- Imperative request, for consumers that have no window bool to poll.
function Consumer:request(on)
    self._on = on and true or false
    return self
end

function Consumer:acquire() return self:request(true) end
function Consumer:release() return self:request(false) end

--- True when this consumer is requesting AND nothing is suppressing its cursor.
function Consumer:isGranted()
    return self:isRequested() and self._blockedBy == nil
end

--- Name of the guard currently suppressing this consumer's cursor, or nil.
function Consumer:blockedBy() return self._blockedBy end

--- Name of the guard currently suppressing this consumer's input, or nil.
function Consumer:inputBlockedBy() return self._blockedInput end

--- Change capabilities after registration (bool or function per capability).
function Consumer:setCaps(caps)
    if caps.cursor ~= nil then self.cursor = caps.cursor end
    if caps.input  ~= nil then self.input  = caps.input  end
    if caps.lock   ~= nil then self.lock   = caps.lock   end
    return self
end

local consumers = {} -- name -> Consumer
local order = {}     -- stable iteration order (pairs() order is not stable)

local function capOn(cap)
    if type(cap) == 'function' then
        local ok, result = pcall(cap)
        return ok and result and true or false
    end
    return cap and true or false
end

--- Register (or replace) a consumer.
--- opts.condition  function -> bool; polled every frame. Preferred.
--- opts.cursor     bool|function (default true)
--- opts.input      bool|function (default = opts.cursor)
--- opts.lock       bool|function (default false)
--- opts.guards     table of guard-name -> false, to relax specific guards.
function M.register(name, opts)
    assert(type(name) == 'string', 'cursor.register: name must be a string')
    opts = opts or {}

    local cursor = opts.cursor
    if cursor == nil then cursor = true end
    local input = opts.input
    if input == nil then input = cursor end

    local relaxed = {}
    if type(opts.guards) == 'table' then
        for guardName, enabled in pairs(opts.guards) do
            if enabled == false then relaxed[guardName] = true end
        end
    end

    local existing = consumers[name]
    local consumer = setmetatable({
        name         = name,
        condition    = opts.condition,
        cursor       = cursor,
        input        = input,
        lock         = opts.lock or false,
        relaxed      = relaxed,
        _on          = existing and existing._on or false,
        _blockedBy   = nil,
        _blockedInput = nil,
    }, Consumer)

    if not existing then
        order[#order + 1] = name
    end
    consumers[name] = consumer
    M._ensureThread()
    return consumer
end

function M.unregister(name)
    if not consumers[name] then return false end
    consumers[name] = nil
    for i = 1, #order do
        if order[i] == name then
            table.remove(order, i)
            break
        end
    end
    return true
end

function M.get(name) return consumers[name] end

--- Ad-hoc request for code that has no window of its own (a drag mode, a
--- modal flow). Idempotent per tag, so it can never double-count.
function M.request(tag, caps)
    local consumer = consumers[tag] or M.register(tag, caps or {})
    if caps then consumer:setCaps(caps) end
    return consumer:acquire()
end

function M.releaseTag(tag)
    local consumer = consumers[tag]
    if consumer then consumer:release() end
end

--=========================================================================
-- 3. mimgui subscriptions
--=========================================================================

local attached = {}

--- Hand every imgui.OnFrame subscription in the script to the manager. From
--- here on its HideCursor/LockPlayer fields belong to us.
function M.attach(sub)
    assert(type(sub) == 'table' and sub.Condition, 'cursor.attach: expected an imgui.OnFrame subscription')
    for i = 1, #attached do
        if attached[i] == sub then return sub end
    end
    attached[#attached + 1] = sub
    sub.HideCursor = true -- neutral until the first update()
    sub.LockPlayer = false
    M._ensureThread()
    return sub
end

function M.detach(sub)
    for i = 1, #attached do
        if attached[i] == sub then
            table.remove(attached, i)
            return true
        end
    end
    return false
end

--=========================================================================
-- 4. The decision
--=========================================================================

local counts    = { cursor = 0, input = 0, lock = 0 }
local effective = { cursor = false, input = false, lock = false }
local inputDisabled = false -- last value we wrote to imgui.DisableInput
local everCursor, everLock = false, false
local shuttingDown = false

-- ImGui keeps io.MouseDown / io.KeysDown latched while input is disabled: the
-- matching up-event never arrives, because mimgui stops forwarding messages
-- entirely. On the rising edge that would turn the next click into a phantom
-- drag, or leave a modifier stuck. Wipe it once - ImGui re-learns the real
-- state from the very next message.
local function clearStaleInputState()
    if not imgui.IsInitialized or not imgui.IsInitialized() then return end
    pcall(function()
        imgui.SwitchContext()
        local io = imgui.GetIO()
        for i = 0, 4 do io.MouseDown[i] = false end
        io.MouseWheel = 0
        io.MouseWheelH = 0
        for i = 0, 511 do io.KeysDown[i] = false end
        io.KeyCtrl, io.KeyShift, io.KeyAlt, io.KeySuper = false, false, false, false
    end)
end

-- Who draws the pointer.
--
-- ImGui's win32 backend sets the *OS* cursor shape while handling WM_SETCURSOR,
-- and mimgui only consumes that message when io.WantCaptureMouse is true - i.e.
-- only while the pointer is over an ImGui window. Everywhere else GTA's own
-- WndProc gets it and resets the cursor. The two overwrite each other every
-- frame, which is why the pointer used to be invisible or flickering even
-- though clicks landed correctly.
--
-- ImGuiConfigFlags_NoMouseCursorChange takes ImGui out of that fight for good:
-- the backend stops calling SetCursor, and whatever MoonLoader's showCursor()
-- put on screen stays there, stable. This is applied whenever we want a cursor.
--
-- MouseDrawCursor (M.softwareCursor) is the fallback for a MoonLoader that does
-- NOT draw its own pointer: ImGui then renders one into its draw list. It is
-- OFF by default because ML 026 does draw one, and having both gives you two
-- cursors - a white one trailing the ImGui one.
local styleApplied = nil -- nil = never applied, so the first call always writes

local function applyCursorStyle(want)
    local draw = want and M.softwareCursor or false
    local key = (want and 1 or 0) + (draw and 2 or 0)
    if styleApplied == key then return end
    if not imgui.IsInitialized or not imgui.IsInitialized() then return end
    local ok = pcall(function()
        imgui.SwitchContext()
        local io = imgui.GetIO()
        local flag = imgui.ConfigFlags.NoMouseCursorChange
        io.MouseDrawCursor = draw
        if want then
            io.ConfigFlags = bit.bor(io.ConfigFlags, flag)
        else
            io.ConfigFlags = bit.band(io.ConfigFlags, bit.bnot(flag))
        end
    end)
    if ok then
        styleApplied = key
        log('cursor style: os-handoff=%s software=%s', tostring(want), tostring(draw))
    end
end

--- Recompute and apply everything. Called once per frame by the internal
--- thread; safe (and cheap) to call again by hand for a zero-latency update
--- right after something closes a batch of windows.
function M.update()
    if shuttingDown then return end

    local nCursor, nInput, nLock = 0, 0, 0

    -- Skip guard evaluation entirely on the common frame where nothing is
    -- asking for anything.
    local anyRequest = false
    for i = 1, #order do
        local consumer = consumers[order[i]]
        if consumer and consumer:isRequested() then
            anyRequest = true
            break
        end
    end

    if anyRequest then
        local gv = evaluateGuards()
        for i = 1, #order do
            local consumer = consumers[order[i]]
            if consumer then
                if consumer:isRequested() then
                    -- resolve blocking per capability: a CURSOR_ONLY guard must
                    -- not take input away from a window that is still usable
                    local blockCursor, blockInput, blockLock
                    local relaxed = consumer.relaxed
                    for name, fired in pairs(gv) do
                        if fired and not relaxed[name] then
                            local scope = guardDefs[name].scope
                            if not blockCursor and (not scope or scope.cursor) then blockCursor = name end
                            if not blockInput  and (not scope or scope.input)  then blockInput  = name end
                            if not blockLock   and (not scope or scope.lock)   then blockLock   = name end
                        end
                    end
                    consumer._blockedBy    = blockCursor
                    consumer._blockedInput = blockInput

                    if not blockCursor and capOn(consumer.cursor) then nCursor = nCursor + 1 end
                    if not blockInput  and capOn(consumer.input)  then nInput  = nInput  + 1 end
                    if not blockLock   and capOn(consumer.lock)   then nLock   = nLock   + 1 end
                else
                    consumer._blockedBy, consumer._blockedInput = nil, nil
                end
            end
        end
    else
        for i = 1, #order do
            local consumer = consumers[order[i]]
            if consumer then consumer._blockedBy, consumer._blockedInput = nil, nil end
        end
    end

    counts.cursor, counts.input, counts.lock = nCursor, nInput, nLock
    local wantCursor, wantInput, wantLock = nCursor > 0, nInput > 0, nLock > 0

    -- effective.cursor is read by the sampCursor guard (to tell its own
    -- reflection from a real SA-MP cursor), so publish it before anything else
    -- can observe a stale value.
    effective.cursor, effective.input, effective.lock = wantCursor, wantInput, wantLock

    -- "a window asked for the cursor and did not get it" is the one failure mode
    -- that is invisible from the outside and maddening to diagnose, so it is
    -- reported unconditionally (not gated behind debug) - but only when the
    -- reason changes, so it cannot spam the log.
    if not wantCursor and anyRequest then
        local reason, who
        for i = 1, #order do
            local consumer = consumers[order[i]]
            if consumer and consumer._blockedBy and capOn(consumer.cursor) then
                reason, who = consumer._blockedBy, consumer.name
                break
            end
        end
        if reason ~= M._lastBlockReason then
            M._lastBlockReason = reason
            if reason and type(M.log) == 'function' then
                M.log(("[cursor] suppressed by guard %q (first affected: %s) - /ab cursor for detail")
                    :format(reason, who))
            end
        end
    elseif wantCursor then
        M._lastBlockReason = nil
    end

    -- ---- ImGui input capture --------------------------------------------
    if M.manageInput then
        local disable = not wantInput
        if disable ~= inputDisabled then
            inputDisabled = disable
            imgui.DisableInput = disable
            if not disable then clearStaleInputState() end
            log('input capture %s', disable and 'off' or 'on')
        end
    end

    -- ---- who draws the pointer ------------------------------------------
    applyCursorStyle(wantCursor)

    -- ---- hand the decision to mimgui ------------------------------------
    for i = 1, #attached do
        local sub = attached[i]
        sub.HideCursor = not wantCursor
        sub.LockPlayer = wantLock
    end

    if wantCursor then everCursor = true end
    if wantLock then everLock = true end
end

--=========================================================================
-- 5. Frame driver
--=========================================================================
-- wait(0) yields until the next frame - the same pattern (and cost) as
-- mimgui's own updater thread; it is not a busy-wait. work_in_pause keeps it
-- ticking inside the pause menu, which is exactly when the `pause` guard has
-- to take effect.
--
-- The loop exits through its own condition and returns; it never calls
-- terminate() on itself (doing that from inside a running lua_thread
-- misbehaves in MoonLoader).

local thread, running = nil, false
local updateFails = 0

function M._ensureThread()
    if thread or shuttingDown then return end
    running = true
    thread = lua_thread.create(function()
        while running do
            wait(0)
            if not running then return end
            local ok, err = pcall(M.update)
            if not ok then
                updateFails = updateFails + 1
                if updateFails <= 3 and type(M.log) == 'function' then
                    M.log('[cursor] update failed: ' .. tostring(err))
                end
            end
        end
    end)
    thread.work_in_pause = true
end

--=========================================================================
-- 6. Teardown
--=========================================================================
-- Reload, /unload, an unhandled error and game exit all funnel through
-- onScriptTerminate (which MoonLoader fires before onExitScript), so this is
-- the one place that has to be right. mimgui's own terminate handler releases
-- the cursor and the lock it took; we stop asking first, restore anything
-- mimgui does not know about, and then release defensively - but only what we
-- ever actually took, so we cannot unstick another script's lock.

function M.shutdown()
    if shuttingDown then return end
    shuttingDown = true
    running = false

    for i = 1, #order do
        local consumer = consumers[order[i]]
        if consumer then
            consumer.condition = nil
            consumer._on = false
            consumer._blockedBy, consumer._blockedInput = nil, nil
        end
    end
    counts.cursor, counts.input, counts.lock = 0, 0, 0
    effective.cursor, effective.input, effective.lock = false, false, false

    for i = 1, #attached do
        attached[i].HideCursor = true
        attached[i].LockPlayer = false
    end

    if M.manageInput and inputDisabled then
        pcall(function() imgui.DisableInput = false end)
        inputDisabled = false
    end

    -- hand the OS cursor back to the game and stop drawing any of our own
    applyCursorStyle(false)

    if everLock and type(lockPlayerControl) == 'function' then
        pcall(lockPlayerControl, false)
    end
    if everCursor and type(showCursor) == 'function' then
        -- explicit second arg: hide the cursor without touching player control,
        -- which is the whole point of keeping the two concerns apart
        pcall(showCursor, false, false)
    end
end

pcall(addEventHandler, 'onScriptTerminate', function(scr)
    if scr == script.this then M.shutdown() end
end)
pcall(addEventHandler, 'onExitScript', function() M.shutdown() end)

-- `focused` is a latch fed by window messages, and a latch can get stuck: an
-- unpaired WM_KILLFOCUS (they do happen around device resets and alt-tab races)
-- would otherwise suppress the cursor for the rest of the session. So we also
-- self-heal on any message that can only be delivered to a focused window -
-- key-down and button-down. NOT mouse-move, which an unfocused window still
-- receives on hover.
local focusHealMsgs = {
    [0x0100] = true, -- WM_KEYDOWN
    [0x0104] = true, -- WM_SYSKEYDOWN
    [0x0201] = true, -- WM_LBUTTONDOWN
    [0x0204] = true, -- WM_RBUTTONDOWN
    [0x0207] = true, -- WM_MBUTTONDOWN
}

pcall(addEventHandler, 'onWindowMessage', function(msg, wparam)
    if msg == 0x0007 then     -- WM_SETFOCUS
        focused = true
    elseif msg == 0x0008 then -- WM_KILLFOCUS
        focused = false
    elseif msg == 0x001C then -- WM_ACTIVATEAPP
        focused = wparam ~= 0
    elseif focusHealMsgs[msg] then
        focused = true
    end
end)

--=========================================================================
-- 7. Introspection / configuration
--=========================================================================

--- setup({ guards = {...}, manageInput = bool, softwareCursor = bool,
---         debug = bool, log = function })
--- Merges; may be called more than once.
function M.setup(opts)
    opts = opts or {}
    if type(opts.guards) == 'table' then
        for name, enabled in pairs(opts.guards) do
            if guardDefs[name] == nil then
                log('setup: unknown guard %q ignored', name)
            else
                M.guards[name] = enabled and guardDefs[name].available or false
            end
        end
    end
    if opts.manageInput ~= nil then M.manageInput = opts.manageInput and true or false end
    if opts.softwareCursor ~= nil then M.softwareCursor = opts.softwareCursor and true or false end
    if opts.debug ~= nil then M.debug = opts.debug and true or false end
    if type(opts.log) == 'function' then M.log = opts.log end
    M._ensureThread()
    return M
end

--- Live reference counts: how many consumers are granted each capability.
function M.count(capability)
    if capability then return counts[capability] or 0 end
    return counts.cursor, counts.input, counts.lock
end

--- Convenience predicates.
function M.cursorWanted() return effective.cursor end
function M.inputWanted()  return effective.input end
function M.lockWanted()   return effective.lock end
function M.isFocused()    return focused end

--- Full snapshot, for a debug command.
function M.snapshot()
    local rows = {}
    for i = 1, #order do
        local consumer = consumers[order[i]]
        if consumer then
            rows[#rows + 1] = {
                name         = consumer.name,
                requested    = consumer:isRequested(),
                blockedBy    = consumer._blockedBy,
                blockedInput = consumer._blockedInput,
                cursor       = capOn(consumer.cursor),
                input        = capOn(consumer.input),
                lock         = capOn(consumer.lock),
            }
        end
    end
    return {
        counts    = { cursor = counts.cursor, input = counts.input, lock = counts.lock },
        effective = { cursor = effective.cursor, input = effective.input, lock = effective.lock },
        guards    = guardState,
        focused   = focused,
        drawnBy   = (styleApplied or 0) >= 2 and 'imgui (software)'
                    or ((styleApplied or 0) == 1 and 'moonloader (os cursor)' or 'game'),
        inputHeld = M.manageInput and not inputDisabled,
        consumers = rows,
    }
end

return M
