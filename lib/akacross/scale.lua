--[[
    akacross.scale - centralized resolution-aware UI scaling ("UIScale").

    Promoted out of autobind.ui.scale so the mods split off from autobind
    (fastmap/gps, the driving overlays) size their UI through one
    implementation rather than a copy each. autobind.ui.scale is now a
    re-export of this file; see docs/EXTRACTION.md.

    Leaf module: requires only mimgui, so it can be required before every other
    module without introducing a require cycle. See
    docs/RESPONSIVE_UI_PLAN.md for the design rationale.

    Per-state, by design: MoonLoader gives every script its own Lua state, so
    each mod holds its own factor and its own rebuild subscribers. That is
    correct - a mod scales its own windows and nothing else.

    Model: a single "uniform zoom" factor anchored at the design resolution
    (1920x1080 => 1.0), grow-only and clamped, so the UI is pixel-identical at
    1080p and proportionally larger on bigger displays. Positions stay relative
    (callers center via screenRes); only *sizes* pass through here.

    Perf: scalar helpers (f/i) allocate nothing and are safe on render paths;
    vector helpers (v2/size/spacing/padding/pos) allocate an ImVec2 and are for
    load-time constants and explicit rebuilds only.
]]

local M = { _VERSION = '0.1.0' }

local imgui = require('mimgui')

-- Reference resolution the existing pixel constants were designed for. At
-- exactly this resolution the factor is 1.0 (safety anchor: no visual change).
local REF_W, REF_H = 1920.0, 1080.0

-- The AUTO (resolution) factor is grow-only: never shrink the compact 1080p
-- design on smaller screens; only enlarge for bigger displays.
local AUTO_MIN, AUTO_MAX = 1.0, 5.0
-- Absolute bounds on the FINAL factor, so the user slider may go below 1.0
-- (a deliberately compact UI) while the auto x slider x dpi stack still can't
-- blow past a sane maximum. Raised to 5.0 to allow larger UI on big displays /
-- high user scale (the font atlas grows with it - ~8K texels near the ceiling).
local ABS_MIN, ABS_MAX = 0.5, 5.0

-- Readability floor: a baked font glyph never drops below this many physical
-- pixels. Only bites below a 1.0x factor (a sub-1 user scale), and is a no-op
-- at the common factor >= 1.0 (the smallest design font is 8px).
local MIN_FONT_PX = 8

local userMult = 1.0    -- Settings "UI scale" slider (1.0 = auto only)
local dpi      = 1.0    -- OS DPI from mimgui.GetDpiScale(); folded in at init
local factor = nil      -- cached final factor (lazy; nil = needs compute)
local version = 0       -- bumped on every factor change (cache invalidation)
local rebuilds = {}     -- callbacks that recompute scaled constants on change

local floor, ceil, min = math.floor, math.ceil, math.min

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Resolve the screen size. Prefers the entry's screenRes vector (set at load),
-- falls back to the native, then to the reference. Guarded so the plain-luajit
-- smoke (no getScreenResolution native) loads this module without erroring.
local function screenSize()
    local sr = rawget(_G, 'screenRes')
    if sr and sr.x and sr.x > 0 then
        return sr.x, sr.y
    end
    if type(getScreenResolution) == 'function' then
        local ok, w, h = pcall(getScreenResolution)
        if ok and w and w > 0 then
            return w, h
        end
    end
    return REF_W, REF_H
end

local function compute()
    local w, h = screenSize()
    -- resolution factor: min of the two axes (the binding dimension wins, so
    -- ultrawide does not over-scale off the extra width), grow-only.
    local auto = clamp(min(w / REF_W, h / REF_H), AUTO_MIN, AUTO_MAX)
    factor = clamp(auto * userMult * dpi, ABS_MIN, ABS_MAX)
    version = version + 1
    return factor
end

-- Fire the registered rebuild callbacks (each recomputes a group of scaled
-- constants from its base literals). pcall-guarded so one bad callback cannot
-- break the others or the render loop. Deliberately NOT called on the initial
-- lazy compute - callbacks are registered later, at each constant's def site.
local function fireRebuilds()
    for i = 1, #rebuilds do
        local ok, err = pcall(rebuilds[i])
        if not ok then print('[uiscale] rebuild callback error: ' .. tostring(err)) end
    end
end

--- Current scale factor (lazy-computed, cached).
function M.get()
    return factor or compute()
end

--- The RESOLUTION factor alone - no user multiplier, no DPI.
--- For elements that should grow with the display but must not follow the UI
--- scale slider, so a mod can offer an independent size control for them (the
--- driving speedometer does exactly this). Cheap: two divides and a clamp, no
--- caching needed.
function M.auto()
    local w, h = screenSize()
    return clamp(min(w / REF_W, h / REF_H), AUTO_MIN, AUTO_MAX)
end

--- Register a callback that rebuilds a group of scaled constants from their
--- base literals. Call at each constant's definition site so registration
--- order == dependency order (window sizes before the child sizes derived
--- from them, etc.). Returns the callback for convenient define-and-register.
function M.onRebuild(fn)
    rebuilds[#rebuilds + 1] = fn
    return fn
end

--- Recompute after the UI-scale slider moves (or a resolution change). Sets the
--- user multiplier, then fires every rebuild callback so the scaled constants
--- pick up the new factor. Returns the new factor.
function M.recompute(mult)
    if mult then userMult = mult end
    compute()
    fireRebuilds()
    return factor
end

--- Fold in the OS DPI scale (mimgui.GetDpiScale()), which is only known once the
--- renderer exists (OnInitialize). Fires rebuilds so constants match the fonts.
function M.setDpi(d)
    dpi = (d and d > 0) and d or 1.0
    compute()
    fireRebuilds()
    return factor
end

--- Current user multiplier - for seeding the slider and persisting to config.
function M.userMult()
    return userMult
end

--- Version counter; increments whenever the factor changes. Cache keys that
--- embed scaled sizes should compare against this.
function M.version()
    if not factor then compute() end
    return version
end

-- Scalar helpers (no allocation - safe to call every frame) -----------------

--- Scaled float.
function M.f(v)
    return v * (factor or compute())
end

--- Scaled and rounded to the nearest integer (crisp pixel edges).
function M.i(v)
    local s = v * (factor or compute())
    if s >= 0 then return floor(s + 0.5) end
    return ceil(s - 0.5)
end

-- Vector helpers (ALLOCATE an ImVec2 - load-time / rebuild only) -------------

--- New ImVec2 scaled on both axes.
function M.v2(x, y)
    local s = factor or compute()
    return imgui.ImVec2(x * s, y * s)
end

-- Semantic aliases: identical math to v2/f, named for intent at call sites so
-- the plan's "helper for scaled <thing>" reads literally in the code.
M.size    = M.v2   -- window / child / widget size
M.spacing = M.v2   -- ItemSpacing / gaps
M.padding = M.v2   -- WindowPadding / FramePadding
M.pos     = M.v2   -- cursor / element offset (relative, not absolute screen)
M.icon    = M.f    -- icon pixel size
M.width   = M.f    -- widget width / column width

--- Font pixel size, with a readability floor (MIN_FONT_PX). Below a 1.0x factor
--- the smallest sizes clamp up (and can collapse together) - readability over
--- strict hierarchy at very small scales; a no-op at factor >= 1.0.
function M.font(px)
    local s = px * (factor or compute())
    if s < MIN_FONT_PX then return MIN_FONT_PX end
    return s
end

--- Clamp a size vector so a window never exceeds `frac` (default 0.95) of the
--- screen on either axis - prevents oversized/off-screen windows. Mutates in
--- place and returns the same vector.
function M.clampToScreen(vec, frac)
    frac = frac or 0.95
    local w, h = screenSize()
    local maxW, maxH = w * frac, h * frac
    if vec.x > maxW then vec.x = maxW end
    if vec.y > maxH then vec.y = maxH end
    return vec
end

return M
