script_name("hud")
script_description("Customizable HUD")
script_version("1.4.42")
script_author("akacross")
script_url("https://akacross.net/")

local changelog = {
    ["1.4.42"] = {
        "Fixed every colour picker in the settings menu drawing twice - a second swatch sat under the first, on its own line, on every row that had one",
        "Health now reads correctly on both servers. Both run you on a large internal HP figure - five million on Horizon, three million on Paraiso - and what you are meant to see is the part on top of it, out of 100. That is per server now, so the same number is no longer read as two different amounts of health",
        "The old health handling was a list of figures subtracted in whatever order the list happened to come out in, which could leave you reading two million HP. It had been switched off rather than fixed; it is gone",
    },
    ["1.4.41"] = {
        "Horizon works now. The overrides were never running there at all: the shared server-detection library defaults to the Horizon profile, so detecting Horizon looked to it like nothing had changed and the code that switches the overrides on was never called. It worked on Paraiso for the same reason - Paraiso is not the default",
        "That also means most of the Horizon values were fine. Three were not, and are fixed from a capture off the live server: the turf owner label (drawn at a text size of zero, so it was being skipped), the HP bar (it was being looked for at Paraiso's coordinates), and the three stacked HP bar pieces, two of which sit at exactly the same spot and are now told apart properly",
        "The wristwatch is the one row still unconfirmed - it is not on screen unless you are wearing one, so it was not in the capture",
    },
    ["1.4.40"] = {
        "Correction to 1.4.39: the Horizon support added there does not work. Paraiso is unaffected and still works. (1.4.41 fixed it - the cause turned out to be the detection library, not the values.)",
        "Added /hud td, which dumps every textdraw the server is drawing in the exact form the script matches on. Run it on a server whose overrides do nothing and the output is what is needed to make them work",
        "The script now says on connect when a server's signatures are unverified, instead of reporting the overrides as active and doing nothing",
    },
    ["1.4.39"] = {
        "Groundwork for supporting Horizon alongside Paraiso: the server is a table of signatures now rather than being spelled through the whole script, so a second one is an entry instead of a rewrite. The Horizon entry itself does not work yet - see 1.4.40",
        "Each server keeps its own layout. The two draw these in different places, so one set of positions could never be right on both - your Horizon layout and your Paraiso layout are saved separately and neither overwrites the other",
        "The Server tab has a picker, so you can lay out a server you are not currently on - including from single player, which is where most people set this up",
        "The overrides now stay switched off on a server that is neither of those. Previously the turf line was matched by a size both servers share, so an unrelated server drawing anything at that size had it moved off your screen by a HUD that had never heard of it",
        "Fixed the HP and armour readouts on Paraiso being rewritten at Horizon\'s text size when you toggled them off and on, which resized them and stopped the row responding until the server redrew it",
        "Your existing server settings are carried across to the new per-server layout automatically",
        "The script now lives on GitLab alongside the other akacross mods. Updates, the self-repair and the weapon icons all come from there; nothing needs doing on your side",
    },
    ["1.4.38"] = {
        "Removed a large amount of code that already existed in the shared libraries: the version check, the self-updater, the file downloader, the self-repair, the chat message helper and eight small utilities were each written out here and are now used from one place",
        "The player readings this script owned privately - sprint, breath, ammo in the clip, wanted level, speed conversion, facing and the zone lookup - now live in a shared library, so the other mods can use them too",
        "The settings menu has been rebuilt. It now looks and works like the other akacross mods (driving, wanted, vstorage, fast map) instead of being the odd one out: a proper tab bar, one shared theme, and a window that scales with your screen",
        "The ten-button strip and the column of five unlabelled square buttons are gone. The seven bar tabs and the Other tab are now one Elements tab with a list down the left, and the five side buttons became a status card at the top and Save / Reload / Reset / Close along the bottom",
        "Added a status card that tells you, in one place, whether the HUD is on, which renderer is drawing, how many things are being drawn, and which configuration file you are editing. Clicking it switches the HUD on and off",
        "The confirmation prompts no longer open a second window that could end up behind the first one. They are now dialogs inside the settings window",
        "The configuration file picker was a combo box wedged into the footer; it is now a Files tab, with the update check next to it",
        "Added a Keybinds tab. The menu now has a keyboard shortcut - ALT + J by default - which it never had before",
        "Added an Interface tab with a UI scale slider, so you can make the settings window bigger or smaller without it affecting the HUD itself",
        "The settings window now remembers where you put it",
        "Every control has a tooltip explaining what it does, and the columns on the Anchors and Server tabs are labelled instead of being three unmarked boxes in a row",
        "The menu now lives in lib/hud/ rather than inside hud.lua. If those files are missing after an update, the script downloads them itself and reloads - the same self-repair the other mods have",
        "The script now uses the shared akacross window, theme, keybind and interface libraries instead of its own copies",
        "The dark-red menu theme has been replaced by the shared theme all the akacross mods use",
    },
    ["1.4.37"] = {
        "Rewritten configuration: every drawn thing - each bar, icon, star row and line of text - now has its own settings instead of being spread across a dozen parallel lists",
        "Configuration files now carry a schema version, and one from before this release is set aside (renamed to .v1.bak) rather than half-read - the old format cannot be read back correctly, so it is not guessed at",
        "You will need to re-position your HUD once after updating",
        "Each element now keeps its own position, size, font, alignment, flags and colours together, so the settings menu shows one row per thing rather than one row per index",
        "Elements can now be given any anchor, and anchors can be renamed, added and removed without the elements losing track of them",
        "Fixed bars drifting by their border width every time you dragged them",
        "The Radar section has been removed: it edited values nothing ever drew",
        "Configuration files are now read and written through the shared akacross libraries",
        "Removed a large amount of code that nothing called any more",
        "Fonts now go through the shared akacross.render layer, which reference-counts them",
        "Everything drawn on screen now goes through one swappable renderer layer, so a second renderer can be added without touching the HUD itself",
        "Added an ImGui renderer, switchable from the Screen tab: the bars, the weapon icon and the wanted stars are drawn with smoothed edges and proper transparency instead of the game's own renderer",
        "The ImGui renderer now draws the text too, so the whole HUD comes from one renderer instead of two",
        "Font names are matched against the fonts actually installed on your system. 'Aerial' - which is what the default configuration has always said - resolves to Arial, which is what Windows had been quietly substituting anyway",
        "Bold and italic now use the real bold and italic font files. Border, shadow, underline and strikeout are drawn by the script",
        "Text may sit a pixel or two differently under the ImGui renderer - it measures text differently from the game does, so centred and right-aligned lines shift slightly",
        "The ImGui renderer now measures its own text against the game's and corrects the difference, so text comes out the same size even when your font name is one the game has to substitute for",
        "Fixed text under the ImGui renderer coming out about 40% too small: the size in your configuration is not a pixel measurement, and it is now translated through the game's own font layer so both renderers produce the same size of text",
        "Fixed a small coloured nub left at the left end of any bar sitting at zero under the ImGui renderer",
        "Fixed transparency under the ImGui renderer: a bar's Fade colour now blends over the game as it always did, instead of over a solid border, and a faded text colour now fades its border and shadow with it",
        "Added /hud render, which reports which renderer is drawing, which font file each text element actually got, and which font names had to be substituted. A summary goes to chat and the detail to moonloader.log",
        "A font name that is not installed is now mentioned in the log once, instead of being silently swapped for another one",
        "The bars can now have rounded corners, on the Screen tab next to the renderer toggle. The setting appears only while the ImGui renderer is on, because the game's own renderer cannot draw a rounded corner",
        "A weapon icon whose image file is missing now draws nothing instead of erroring on every frame the weapon was held",
        "Fixed a font leak: every flag checkbox, font name change and size button click created a new font and abandoned the old one, and Reload Configuration abandoned all seventeen",
        "Identical font settings now share one font instead of one each",
        "Text is measured when its value changes instead of once or three times per frame per element, which mostly matters with the settings window open",
        "Rebuilt the settings menu: an open window now allocates essentially nothing per frame, where it used to rebuild every widget buffer, colour conversion, widget id and button closure sixty times a second",
        "The settings menu no longer re-scans the configurations folder sixty times a second - it rescans when a file changes and at most once a second otherwise",
        "Each settings tab is its own function behind a registry, instead of a ten-branch chain sitting four hundred lines away from the buttons that select it",
        "The tab strip, the side buttons, the server-textdraw rows and the confirmation prompts are one implementation each instead of ten, five, five and six copies",
        "The font row takes an element and a row number instead of ten hand-written indices",
        "The settings menu now scales with your screen resolution instead of staying a fixed 1080p size - unchanged at 1920x1080, larger above it",
        "Dependencies now load through the shared akacross.deps, so a missing module is reported by name instead of surfacing as an unrelated error later",
        "The server textdraw handling no longer scans 4001 pool slots per pass - it scans the 2304 that can exist, once, and then remembers where they are",
        "Dragging a server-textdraw position or colour slider used to re-scan the whole textdraw pool on every frame of the drag; it now writes straight to the draws it already found",
        "The turf colour check ran a 3001-slot pool scan on every HUD tick, and on a server with no turf textdraw it never stopped early; it is now a single lookup, reconciled twice a second",
        "The cursor is now shared with the other akacross scripts instead of each deciding on its own",
        "Colour handling and the custom buttons now come from the shared akacross libraries instead of private copies",
        "Updating the script now downloads to a temporary file and checks it parses before replacing your copy - a failed or truncated download used to overwrite the live script",
        "Fixed the HP Bar's third colour picker, which raised an error instead of refreshing the textdraws",
        "Removing a position group no longer skips the next one in the list",
    },
    ["1.4.36"] = {
        "fixed the removal of the HP Bar",
    },
    ["1.4.35"] = {
        "Fixed issue where you could not move any text elements, ids 1 through 5 were using the wrong index for the value table",
    },
    ["1.4.34"] = {
        "Added changelog functionality to show the latest changes in the script and show the changelog after an update is finished",
        "Rewritten the dependency manager to improve module loading and error handling",
        "Enhanced error handling for the dependency manager to provide detailed error messages",
        "Reorganized and refactored various sections of the script for better readability and maintainability",
        "Also fixed spectate mode not working for admins using this modification (Worked fine but some values did not fetch correctly)"
    },
    ["1.4.33"] = {
        "Implemented a new HUD update system using coroutines for improved performance",
        "The script now checks for updates asynchronously, improving startup time and overall performance",
        "Optimized HUD update logic to reduce unnecessary updates, only refreshing when changes occur",
        "Added error handling for the update coroutine to catch and report any issues",
        "Added nil check functionality to improve performance and stability by setting unused values to nil",
        "Created resetValues() function to reset the HUD to nil values when the HUD is hidden or turned off",
        "No longer requires the `asyncHttpRequest` function to check for updates",
        "Removed dependency on the `requests` and `effil` libraries for update checking",
        "Added a new `update.txt` file to the configuration folder for update checks",
        "Using getGxtText to retrieve the full names of Zones and Vehicles directly from the game, eliminating the need to store them within the script"
    },
    ["1.4.32"] = {
        "Sprint bar now has a \"Stay On\" checkbox to prevent it from always being active when not in use"
    },
    ["1.4.31"] = {
        "Numerous improvements have been made to the entire script",
        "Enhanced loading and saving of the configuration file with added error handling and fixes for blank or corrupt config files",
        "Implemented a function to add parts of the table for future modifications, ensuring seamless upgrades and preserving user settings",
        "The new function also removes any values in the table that do not exist in the default settings, except for `hud.pos` and `hud.serverhp`",
        "Support for creating multiple configuration files. You can now create, rename, delete, and copy configurations",
        "Reverted back to using `sampGetPlayerHealth` and `sampGetPlayerArmor` due to reports of incorrect HP/armor values with the previous method (previously using CHUD textdraws)"
    },
    ["1.4.30 and earlier"] = {
        "Initial beta release and updates (details not provided)"
    }
}

-- Script Information
local thisScriptRef = thisScript()
local scriptPath    = thisScriptRef.path
local scriptName    = thisScriptRef.name
local scriptVersion = thisScriptRef.version
local shortName     = "hud"

-- Exit gate. Set true in onScriptTerminate so the OnFrame draw callback stops
-- before the D3D teardown. docs/CRASH_ANALYSIS.md step 0 (the #7/#8/#9 family):
-- the fault fires on a plain /q quit, drawing into a device that is being
-- released, so a renderer that keeps running through teardown is the exposure.
-- carbCrosshair.lua:824 is the reference implementation.
local terminating = false

--[[
    Dependencies.

    This was a hand-written loader: a manifest, a pcall(require) loop, an
    `_G[var] = module` pass and an extras pass - the same shape that had grown
    up independently in autobind, reports and autofps, and that
    docs/SHARED_RUNTIME.md exists to collapse into one implementation. The rule
    it sets is that `deps` earns its place from about three dependencies up, or
    as soon as a script has an optional dependency or an `extras` case. This
    one has fourteen, both of the others, and now a REQUIRED set whose absence
    used to surface as a nil index a thousand lines later instead of a sentence
    saying which file is missing.

    `globals = true` because the body of this script reads its modules as bare
    globals (`imgui`, `sampev`, `renderM`), which is what the old loader's
    `_G[var] = module` pass provided.
]]
local DEPENDENCIES = {
    -- font_flag is no longer pulled in: akacross.render owns the flag bits now.
    {name = 'moonloader',           var = 'moonloader', extras = {dlstatus = 'download_status'}},
    {name = 'ffi',                  var = 'ffi'},
    {name = 'lfs',                  var = 'lfs'},
    {name = 'memory',               var = 'mem'},
    {name = 'windows.message',      var = 'wm'},
    {name = 'game.keys',            var = 'gkeys'},
    {name = 'mimgui',               var = 'imgui'},
    {name = 'encoding',             var = 'encoding'},
    {name = 'samp.events',          var = 'sampev'},
    {name = 'game.weapons',         var = 'weapons'},
    -- Optional: every icon in the menu goes through icon(), which falls back
    -- to '?' rather than indexing a nil table.
    {name = 'fAwesome6',            var = 'fa', required = false},
    -- The shared D3D font layer: refcounted font handles, the measurement and
    -- the alignment convention this script used to own three private copies
    -- of. See lib/akacross/render.lua.
    {name = 'akacross.render',      var = 'renderM'},
    --[[
        The DRAWING SURFACE, behind a swappable backend. Every box, texture and
        line of text this script puts on screen goes through `drawM`; the
        native MoonLoader renderer is what sits behind it today, and an
        ImDrawList one is the reason the seam exists.

        The split with `renderM` above is not an accident and not a leftover:

          drawM   draws.       Backend-specific. box, texture, font handles,
                               measurement, text.
          renderM describes.   Backend-independent. `flags()` reads the config's
                               bold/italics/border checkboxes, `ALIGN` maps a
                               name to a factor. Both backends read the same
                               config, so both read it the same way.

        Aliasing the second through the first would give two names for one
        function, which is worse than two requires.
    ]]
    {name = 'akacross.draw',        var = 'drawM'},
    --[[
        The ImDrawList backend. OPTIONAL, and required only for the side
        effect: loading it registers a renderer called `imgui` with `drawM`,
        which is what makes the Screen tab's toggle do anything. Without it
        the toggle says so and the native renderer is the only one there is.
    ]]
    {name = 'akacross.draw_imgui',  var = 'drawImguiM', required = false},
    -- ARGB packing/unpacking, which this script had its own convertColor and
    -- joinARGB for. Same maths, one implementation.
    {name = 'akacross.colors',      var = 'colorsM'},
    -- CustomButton and friends, which were monkey-patched onto the imgui
    -- table here. Note the shared one takes a TEXT colour before the size.
    {name = 'akacross.imgui_funcs', var = 'imguiFuncs'},
    -- The SA-MP textdraw pool reader. It knows the pool's real size (2048
    -- server draws + 256 player draws) and it pcall-guards every native, which
    -- is what the two sweeps in this script needed and did not have.
    {name = 'akacross.textdraw',    var = 'textdrawM'},
    -- Resolution-aware sizing. The menu is drawn from fixed 1080p pixel
    -- constants, so on a bigger display it was a postage stamp in a corner.
    {name = 'akacross.scale',       var = 'scaleM'},
    -- The refcounted cursor owner, shared with autobind, autologin and
    -- reports. OPTIONAL: without it the frames fall back to mimgui's own
    -- handling, which is what this script did before.
    {name = 'akacross.cursor',      var = 'cursorM', required = false},
    -- The config registry, and the JSON layer under it. REQUIRED: without them
    -- nothing loads or persists, and a HUD that silently forgets where you put
    -- everything is worse than one that says why.
    {name = 'carbJsonConfig',       var = 'cjc'},
    {name = 'akacross.config',      var = 'configM'},
    --[[
        THE SHARED UI RUNTIME. Every other mod split out of autobind already
        draws through these; this script was the last one still hand-placing
        children with SetCursorPos and carrying its own theme.

        `window` is the registry: drag, clamp, style push/pop with counted
        pops, and the cursor predicate. `style` is the theme and the
        section/labelled/toggle helpers. `keybinds` is the click-then-press
        editor. `interface` is the UI-scale tab, which is literally the same
        tab in six mods now.
    ]]
    {name = 'akacross.window',      var = 'windowM'},
    {name = 'akacross.style',       var = 'styleM'},
    {name = 'akacross.keybinds',    var = 'keybindsM'},
    {name = 'akacross.interface',   var = 'interfaceM'},
    -- keycheck and checkChatDialogScoreboardConsolePause, published into _G by
    -- install_globals() below. The keybind poll cannot run without them.
    {name = 'akacross.functions',   var = 'extra_funcs'},
    --[[
        The player-state readers this script used to own privately: sprint,
        breath, ammo-in-clip, wanted level, speed conversion, facing and the
        zone lookup. Every one of them answers "what is the player doing right
        now", which is not a HUD question - see lib/akacross/player.lua.
    ]]
    {name = 'akacross.player',      var = 'playerM'},
    --[[
        WHICH SERVER THIS IS. The server-textdraw overrides below are matched
        by letter-size signatures that differ per server, so the script has to
        know which one it is on before it touches anything. rp answers that
        from the server NAME, which is the one signal that does not depend on
        the very draws being identified - and it is the same answer autobind,
        wanted and vstorage already act on.
    ]]
    {name = 'akacross.rp',          var = 'rpM'},
    -- The version check and the staged self-update, which hud and reports had
    -- each grown a subtly different copy of.
    {name = 'akacross.updater',     var = 'updaterM'},
    -- vkeys is akacross.keybinds' own dependency, listed so a missing copy is
    -- reported here by name rather than surfacing inside that module.
    {name = 'vkeys'},
    -- This script's own menu. Split out in 1.4.38: the entry was one Lua
    -- function within a few names of the 200-locals ceiling, and the menu was
    -- 1200 of its lines.
    {name = 'hud.widgets',          var = 'hudWidgetsM'},
    {name = 'hud.settings',         var = 'hudSettingsM'},
    {name = 'hud.files',            var = 'hudFilesM'},
}

--[[
    SELF-HEAL, and why it runs before a single require().

    An install missing part of lib/ used to be terminal: deps.load() named the
    modules it could not find and the mod refused to start, with no way back
    except reinstalling. That is exactly what a partial extraction produces -
    drop in the entry, miss lib/akacross, and every shared module is gone. It
    became a live concern in 1.4.38, when this script stopped being a single
    file: the updater fetches hud.lua, so an existing install that takes the
    update has the new entry and none of lib/hud.

    So: check the files first, fetch what is absent, reload once.

    This runs BEFORE require() of anything, because the point is to repair the
    very files require() is about to look for, and it uses nothing but
    MoonLoader natives - reaching for akacross.deps here would make the healer
    depend on a file it exists to restore.

    Reload rather than continue: the entry builds its config tables, its window
    registry and its keybinds at load time, so there is no seam to resume from
    once files arrive.

    LOOP GUARD: a reload after a download that fixed nothing would cycle
    forever. The marker records what was attempted; if the same files are still
    missing next pass, the mod reports and stays down.

    Only files that are ours to serve. Third-party libraries (mimgui, vkeys,
    fAwesome6, samp.events, carbJsonConfig) are excluded: not ours to
    redistribute from this repo, and a missing one is a broken install rather
    than a missing update.
]]
local LIB_URL = ("https://gitlab.com/akacross/%s/-/raw/main/lib/"):format(scriptName)
local OWN_FILES = {
    'akacross/colors.lua', 'akacross/config.lua', 'akacross/cursor.lua',
    'akacross/deps.lua', 'akacross/draw.lua', 'akacross/draw_imgui.lua',
    'akacross/fonts.lua', 'akacross/functions.lua', 'akacross/imgui_funcs.lua',
    'akacross/interface.lua', 'akacross/keybinds.lua', 'akacross/player.lua',
    'akacross/render.lua', 'akacross/rp.lua', 'akacross/scale.lua',
    'akacross/style.lua', 'akacross/textdraw.lua', 'akacross/updater.lua',
    'akacross/window.lua',
    'hud/files.lua', 'hud/settings.lua', 'hud/widgets.lua',
}

-- BOOTSTRAP: fetch the healer itself, if the healer is what is missing.
-- deps.selfHeal repairs lib/, and it lives in lib/akacross/deps.lua, so it is
-- the one file it cannot restore - and it is exactly the file a partial
-- extraction drops. Twelve lines of natives, then reload. This is the only
-- part that cannot be shared, because it is what makes the shared thing
-- loadable. See lib/akacross/deps.lua.
local function bootstrapDeps()
    if type(lua_thread) ~= 'table' or type(downloadUrlToFile) ~= 'function' then
        return false
    end
    local path = getWorkingDirectory() .. '\\lib\\akacross\\deps.lua'
    local probe = io.open(path, 'rb')
    if probe then
        local head = probe:read(16)
        probe:close()
        if head and #head > 0 then return false end
    end

    print('[' .. 'HUD' .. '] lib/akacross/deps.lua is missing - fetching it, then repairing the rest')
    createDirectory(getWorkingDirectory() .. '\\lib')
    createDirectory(getWorkingDirectory() .. '\\lib\\akacross')
    downloadUrlToFile(LIB_URL .. 'akacross/deps.lua', path, function(_, status)
        -- Reload rather than continue: everything below this point has already
        -- decided deps is absent.
        if status == 6 then
            lua_thread.create(function()
                wait(750)   -- settle: status 6 fires before the handle closes
                if loadfile(path) then thisScriptRef:reload() end
            end)
        end
    end)
    return true
end

if bootstrapDeps() then
    function main() wait(-1) end
    return
end

--[[
    SELF-HEAL, through akacross.deps.

    This was ~90 lines here, and the same ~90 lines in four other entries. The
    implementation is deps.selfHeal now; what stays is the only part that was
    ever per-mod - which files, from where, and where to put the loop-guard
    marker.

    SOFT-REQUIRED, and it has to be: deps.lua is itself one of the files a
    broken install may be missing, so a healer that cannot be loaded simply
    does not run. That is the honest answer rather than a fallback copy, which
    is what the five copies were.
]]
local function selfHeal()
    local okHeal, healer = pcall(require, 'akacross.deps')
    if not (okHeal and type(healer) == 'table' and healer.selfHeal) then return false end
    return healer.selfHeal{
        label        = 'HUD',
        files        = OWN_FILES,
        baseUrl      = LIB_URL,
        markerDir    = getWorkingDirectory() .. '\\config\\' .. scriptName,
        reinstallUrl = 'https://gitlab.com/akacross/hud/-/releases',
        reload       = function() thisScriptRef:reload() end,
    }
end
if selfHeal() then
    function main() wait(-1) end
    return
end

--[[
    akacross.deps is OPTIONAL, and that is a hard requirement of the shared
    runtime: deleting lib/akacross/deps.lua must never stop a script from
    loading. So it is soft-required, and the fallback below resolves the same
    manifest with the plain loop this script used before - which is why the
    manifest is data in a local rather than control flow inline.

    The guard tests `deps.load`, not just the pcall: a truncated deps.lua that
    still parses would otherwise get as far as a nil call.
]]
local okDeps, deps = pcall(require, 'akacross.deps')
local hasDeps = okDeps and type(deps) == 'table' and deps.load
local depReport
--[[
    The resolved modules, KEPT rather than discarded.

    This used to be `_, depReport = deps.load(...)`: the body of this script
    reads its modules as bare globals, so the table had no reader. New code
    binds `local x = modules.x` instead - the convention every other mod in
    this set follows, and the one the audit in lib/akacross/test/check.sh
    checks for - so the table is now worth holding, and the fallback loop below
    fills the same one.
]]
local modules

if hasDeps then
    modules, depReport = deps.load(DEPENDENCIES, {label = 'HUD', globals = true})
else
    modules = {}
    depReport = {ok = true, loaded = {}, failed = {}, missing = {}}
    for _, dep in ipairs(DEPENDENCIES) do
        local ok, result = pcall(require, dep.name)
        if ok and result then
            if dep.var then modules[dep.var] = result; _G[dep.var] = result end
            if dep.extras and type(result) == 'table' then
                for alias, field in pairs(dep.extras) do _G[alias] = result[field] end
            end
            depReport.loaded[#depReport.loaded + 1] = dep.name
        else
            depReport.failed[#depReport.failed + 1] =
                ('%s (%s)'):format(dep.name, tostring(result))
            if dep.required ~= false then
                depReport.ok = false
                depReport.missing[#depReport.missing + 1] = dep.name
            end
        end
    end
    print(('Loaded modules: %s'):format(table.concat(depReport.loaded, ', ')))
    if #depReport.failed > 0 then
        print(('Failed to load modules: %s'):format(table.concat(depReport.failed, ', ')))
    end
    if not depReport.ok then
        print(('[HUD] cannot start - missing required module(s): %s')
            :format(table.concat(depReport.missing, ', ')))
    end
end

--[[
    The caller has to return; a module cannot abort the chunk that required it.
    deps.load has already installed a main() that says why in chat once SA-MP
    is up, and the fallback path has already printed it.

    This is a BEHAVIOUR CHANGE from the old loader, which recorded the failure
    and carried on into a script that could not work - so a missing mimgui
    surfaced as "attempt to index a nil value" somewhere around the menu rather
    than as its own name.
]]
if not depReport.ok then return end

-- Dynamically set script dependencies based on loaded modules
script_dependencies(table.unpack(depReport.loaded))

--[[
    THE SHARED UI RUNTIME, BOUND TO LOCALS - and every one of them here, at the
    top of the chunk, rather than beside the menu that mostly uses them.

    Two reasons, and the second is a bug this fixed rather than a preference.

    The manifest above loads with `globals = true`, which is what the body of
    this script has always read its modules as. New code should not add to that
    (docs/SHARED_RUNTIME.md, and the de-globalization pass in autobind), so
    these are locals.

    They are at the TOP because a local is only visible to code BELOW it, and
    Lua resolves anything above as a global. `onWindowMessage` sits several
    hundred lines above the settings window and calls into the keybind editor;
    with these bound down there it read `keybindsM` as a nil global and the
    rebind capture silently never fired.
]]
local playerM     = modules.playerM
local updaterM    = modules.updaterM
local windowM     = modules.windowM
local styleM      = modules.styleM
local keybindsM   = modules.keybindsM
local interfaceM  = modules.interfaceM
local extra_funcs = modules.extra_funcs
local hudWidgetsM  = modules.hudWidgetsM
local hudSettingsM = modules.hudSettingsM
local hudFilesM    = modules.hudFilesM

-- Encoding
encoding.default = 'CP1251'
local u8 = encoding.UTF8

--[[
    akacross.functions does setfenv(1, extra_funcs), so everything that LOOKS
    like a global definition in that file (keycheck,
    checkChatDialogScoreboardConsolePause, PressTypes, ...) actually lands on
    the module table. Requiring it is not enough; THIS call is what publishes
    the helpers into _G.

    Without it `keycheck` is nil and the keybind poll dies on the first press -
    and that stays invisible until a bind has keys at all, because the poll
    short-circuits on `#bind.Keys > 0` first.
]]
extra_funcs.install_globals()

--[[
    Defined HERE, not down with the other helpers, because the settings and
    confirmation window titles are built once at load time now and both call
    it. A global function is only assigned when the chunk reaches its
    definition, so anything the top level uses has to be above the top-level
    code that uses it.

    The parentheses matter: gsub returns the string AND a count, and without
    them the second value leaks into whatever this is an argument to.
]]
--[[
    firstToUpper, compareVersions, formatNumber, contains, findPlayer,
    getZoneName, getSubZoneName and getVehicleName used to be defined in this
    file. Every one of them already existed in the shared runtime:

        firstToUpper     -> string:upperFirst()   (akacross.functions)
        formatNumber     -> formatNumber          (akacross.functions)
        contains         -> table.contains        (akacross.functions)
        findPlayer       -> findPlayer            (akacross.functions)
        getZoneName      -> getZoneName           (akacross.functions)
        getSubZoneName   -> getSubZoneName        (akacross.functions)
        getVehicleName   -> getVehicleName        (akacross.functions)
        compareVersions  -> deps.compareVersions  (akacross.deps)

    They are deleted rather than aliased. An alias is a second name for one
    function, which is how a codebase ends up with two `formattedAddChatMessage`
    that do different things - see the note on that one in
    lib/akacross/functions.lua.
]]

-- Get path
local function getPath(type)
    local config = getWorkingDirectory() .. '\\config\\'
    local resource = getWorkingDirectory() .. '\\resource\\'
    local settings = config .. scriptName .. '\\'
    local resources = resource .. scriptName .. '\\'

    local paths = {
        config = config,
        settings = settings,
        configs = settings .. 'configs\\',
        resource = resource,
        resources = resources,
        icons = resources .. 'weapons\\'
    }
    return type and (paths[type] or error("Invalid path type")) or paths
end

-- Get file paths
local function getFile(type)
    local files = {
        settings = getPath('settings') .. 'settings.json',
        update = getPath('settings') .. 'update.txt',
    }
    return files[type] or error("Invalid file type")
end

--[[
    Fetch URLs.

    THE REPOSITORY MOVED TO GITLAB in 1.4.39, alongside every other mod here -
    it was the only one left on GitHub, which meant a second account to keep
    current and a release flow that did not match any of the others.

    Beta is a BRANCH now rather than a `beta/` subdirectory of main, which is
    what autobind has always done and what GitLab's raw URLs are shaped for.
    The icons deliberately ignore it: they are the same 46 files on both
    branches, and pointing them at a branch that may not carry them is how a
    beta build ends up with no weapon icons.
]]
local function fetchUrls(type, isBeta)
    local branch = isBeta and "beta" or "main"
    local baseUrl = ("https://gitlab.com/akacross/%s/-/raw/%s/"):format(scriptName, branch)
    local mainUrl = ("https://gitlab.com/akacross/%s/-/raw/main/"):format(scriptName)
    local paths = {
        script = baseUrl .. scriptName .. ".lua",
        update = baseUrl .. scriptName .. ".txt",
        icons = mainUrl .. "resource/" .. scriptName .. "/weapons/"
    }
    return paths[type] or error("Invalid URL type")
end

-- Global Variables
local ped, h = playerPed, playerHandle
local new, str, copy, fill = imgui.new, ffi.string, ffi.copy, ffi.fill

-- Configuration Directories and Extensions
local configsDir = {}
local configExtensions = {json = true, ini = true}

-- Confirmation state used to live here, as six tables carrying a `status`
-- flag that the second window polled. lib/hud/files.lua owns it now, because
-- nothing outside the prompts ever read it.

--[[
    THE CONFIG SCHEMA VERSION.

    Stamped into every file this script writes, and checked against the raw
    bytes of every file it reads. A config without it predates the per-element
    layout and is not loaded - see the Config block for why guessing at one is
    not on the table.
]]
local SCHEMA_VERSION = 2

-- Settings and HUD Configuration
local settings = {}
local settings_defaultSettings = {
    -- Every config this script writes carries its schema version, and the
    -- loader refuses anything that does not. See the Config block.
    version = SCHEMA_VERSION,
    JsonFile = 'hud.json',
    checkForUpdates = false,
    updateInProgress = false,
    lastVersion = "Unknown",
    autosave = false,
    beta = false,
    -- Which of akacross.draw's backends draws the HUD. A NAME rather than a
    -- boolean: `drawM.list()` is what is actually installed, and a third
    -- renderer should not need this key to change shape.
    renderer = 'native',
    --[[
        The settings window's own scale multiplier, on top of the automatic
        resolution factor akacross.scale derives. 1.0 means "auto only".

        Here rather than in the HUD config on purpose: it is a preference about
        this window, and it must survive switching which HUD configuration is
        being edited. The HUD itself is positioned in screen pixels by the user
        and deliberately does NOT follow it - see the note on the Interface tab.
    ]]
    uiScale = 1.0,
    -- Where the settings window sits, for the same reason. Plain numbers, not
    -- a nested table: settings.json is flat and there is no reason for these
    -- two to be the thing that changes that.
    windowX = -1,
    windowY = -1,
}

-- =========================================================================
-- HUD configuration
-- =========================================================================
--[[
    THE SCHEMA, AND WHY IT CHANGED IN 1.4.37.

    v1 stored the HUD as a dozen PARALLEL ARRAYS indexed by element number and
    then by slot:

        hud.tog[6][5]        the weapon element's fifth boolean
        hud.offx[6][3]       the weapon name's x offset
        hud.color[6][1][2]   the weapon frame's colour
        hud.fontsize[6][2]   the weapon name's size

    Nothing in those names says what any of it is. Worse, the two index spaces
    disagreed: `offx`/`offy`/`groups`/`color` counted the BAR as slot 1, while
    `font`/`fontsize`/`alignfont`/`fontflag` counted only the text rows - so the
    weapon name was offset index 3 and font index 2, and every call site had to
    know that. `createFontMenu` took ten positional indices for exactly this
    reason.

    v2 gives every RENDERED THING its own table with its own fields:

        hud.elements.weapon.icon  = {enabled, anchor, offx, offy, sizex, sizey, color, frameColor}
        hud.elements.weapon.ammo  = {enabled, anchor, offx, offy, font, size, align, flags, color}
        hud.elements.weapon.name  = {enabled, anchor, offx, offy, font, size, align, flags, color}

    A part is a part whether it is a bar, an icon, a row of stars or a line of
    text, so the drawing, the drag hit-testing and the settings row all take a
    part table and stop caring which element it came from.

    WHAT IS CONFIG AND WHAT IS CODE. Only user-editable values live in the
    saved table. Which elements exist, what they are called, what icon the tab
    carries and which parts they have are facts about the script, so they live
    in ELEMENTS below and can never be corrupted by a config file.
]]

-- Alignment is stored as a WORD now, not 1/2/3: akacross.render.ALIGN keys on
-- exactly these, and a config that says "center" survives a reader that does
-- not share this file's numbering.

--[[
    THE ELEMENT REGISTRY - code, not config.

    `kind` picks the renderer. `misc = true` marks the eleven text-only rows
    that share the Other tab; everything else gets a tab of its own, in this
    order.
]]
local ELEMENTS = {
    {key = 'health',  label = 'Health',     icon = 'HEART',          kind = 'bar'},
    {key = 'armor',   label = 'Armor',      icon = 'SHIELD',         kind = 'bar'},
    {key = 'sprint',  label = 'Sprint',     icon = 'PERSON_RUNNING', kind = 'bar'},
    {key = 'vehicle', label = 'Vehicle',    icon = 'CAR',            kind = 'bar'},
    {key = 'breath',  label = 'Breath',     icon = 'MASK_SNORKEL',   kind = 'bar'},
    {key = 'weapon',  label = 'Weapon',     icon = 'GUN',            kind = 'weapon'},
    {key = 'money',   label = 'Stars/Cash', icon = nil,              kind = 'stars'},

    {key = 'name',        label = 'Name',          kind = 'text', misc = true},
    {key = 'localTime',   label = 'Local-Time',    kind = 'text', misc = true},
    {key = 'serverTime',  label = 'Server-Time',   kind = 'text', misc = true},
    {key = 'ping',        label = 'Ping',          kind = 'text', misc = true},
    {key = 'fps',         label = 'FPS',           kind = 'text', misc = true},
    {key = 'direction',   label = 'Direction',     kind = 'text', misc = true},
    {key = 'location',    label = 'Location',      kind = 'text', misc = true},
    {key = 'turf',        label = 'Turf',          kind = 'text', misc = true},
    {key = 'speed',       label = 'Vehicle Speed', kind = 'text', misc = true},
    {key = 'vehicleName', label = 'Vehicle Name',  kind = 'text', misc = true},
    {key = 'badge',       label = 'Badge',         kind = 'text', misc = true},
}

local Spec = {list = ELEMENTS, byKey = {}, misc = {}, tabs = {}}
for i = 1, #ELEMENTS do
    local spec = ELEMENTS[i]
    spec.index = i
    Spec.byKey[spec.key] = spec
    local bucket = spec.misc and Spec.misc or Spec.tabs
    bucket[#bucket + 1] = spec.key
end

--[[
    Which parts each kind has, in DRAW ORDER, and what each is called in the
    settings menu. The renderers, the drag hit-test and the font manager all
    walk this rather than switching on the element.
]]
Spec.parts = {
    bar    = {{name = 'bar',   label = 'Bar',    text = false},
              {name = 'text',  label = 'Text',   text = true}},
    weapon = {{name = 'icon',  label = 'Icon',   text = false},
              {name = 'ammo',  label = 'Ammo',   text = true},
              {name = 'name',  label = 'Name',   text = true}},
    stars  = {{name = 'stars', label = 'Stars',  text = false},
              {name = 'text',  label = 'Cash',   text = true}},
    text   = {{name = 'text',  label = 'Text',   text = true}},
}

local function defaultElements()
    --- A text part, with the defaults every one of them shares.
    local function textPart(anchor, offx, offy, size, align, color, flags)
        return {
            enabled = true, anchor = anchor, offx = offx, offy = offy,
            font = 'Arial', size = size, align = align, color = color,
            flags = flags or {bold = true, italics = true, border = true, shadow = true},
        }
    end

    --- A bar part: the filled rectangle, its border and the fade behind it.
    local function barPart(offx, offy, color)
        return {
            enabled = true, anchor = 1, offx = offx, offy = offy,
            sizex = 130, sizey = 17, border = 1,
            color = color, fade = 1677721600, outline = -16777216,
        }
    end

    -- The misc rows' anchors and vertical offsets, the only two things that
    -- differ between them.
    local MISC_LAYOUT = {
        name        = {anchor = 6, offy = 0.0},
        localTime   = {anchor = 3, offy = 17.0},
        serverTime  = {anchor = 3, offy = 33.8},
        ping        = {anchor = 4, offy = 52.0},
        fps         = {anchor = 4, offy = 71.5},
        direction   = {anchor = 2, offy = 90.0},
        location    = {anchor = 2, offy = 110.0},
        turf        = {anchor = 2, offy = 129.0},
        speed       = {anchor = 5, offy = 146.0},
        vehicleName = {anchor = 5, offy = 167.0},
        badge       = {anchor = 2, offy = 186.0},
    }

    local e = {
        health  = {max = 100,  extended = false, bar = barPart(120, 80, -65536),
                   text = textPart(1, 183, 82, 8, 'center', -1)},
        armor   = {max = 100,  stayOn = true,    bar = barPart(120, 60, -1),
                   text = textPart(1, 183, 62, 8, 'center', -1)},
        sprint  = {max = 100,  stayOn = false,   bar = barPart(120, 40, -1536),
                   text = textPart(1, 183, 42, 8, 'center', -1)},
        vehicle = {max = 1000, stayOn = true, bigVehicles = true,
                   bar = barPart(120, 20, -16711931),
                   text = textPart(1, 183, 22, 8, 'center', -1)},
        breath  = {max = 100,  stayOn = true,    bar = barPart(120, -0, -16711687),
                   text = textPart(1, 183, 2, 8, 'center', -1)},

        weapon  = {
            frame = true, splitAmmo = true,
            icon = {enabled = true, anchor = 1, offx = -1.5, offy = -8.5,
                    sizex = 115, sizey = 115, color = -1, frameColor = -16777216},
            ammo = textPart(1, 97, 73.5, 8, 'right', -1),
            name = textPart(1, 56.4, 101.5, 10, 'center', -1),
        },
        money = {
            dollar = true, comma = true,
            stars = {enabled = true, anchor = 1, offx = 115, offy = 118.8,
                     sizex = 22, sizey = 22, spacing = -3, color = -13568},
            text = textPart(1, 248.6, 95.7, 16, 'right', -14689241,
                            {bold = true, italics = false, border = true, shadow = true}),
        },
    }

    -- The vehicle bar recolours itself as the engine takes damage.
    e.vehicle.bar.damageMid = -1536
    e.vehicle.bar.damageLow = -65536
    -- The weapon icon's frame is drawn behind it in its own colour.

    for i = 1, #Spec.misc do
        local key = Spec.misc[i]
        local layout = MISC_LAYOUT[key]
        e[key] = {text = textPart(layout.anchor, 0, layout.offy, 10, 'right', -1)}
    end
    e.localTime.twelveHour = true
    e.ping.showLabel = true
    e.fps.showLabel = true
    e.direction.useCamera = true
    e.speed.mph = true

    return e
end

local hud = {}
local hud_defaultSettings = {
    version = SCHEMA_VERSION,

    toggle = true,
    defaultHud = false,

    --[[
        Corner rounding for the bars, in pixels.

        Only the ImGui renderer can do this - renderDrawBox has no argument for
        it - so the Screen tab offers the control only while that renderer is
        active, and the native one ignores the number rather than pretending.
        Defaulted to 3 rather than 0 because the whole visible difference
        between the two renderers is this: every other shape here is an
        axis-aligned rectangle, which looks identical either way.
    ]]
    rounding = 3,

    -- The named anchors elements hang off. `move` was persisted in v1 and is a
    -- transient UI state, so it is not stored any more.
    anchors = {
        {name = 'Hud',      x = 525, y = 234},
        {name = 'Radar',    x = 525, y = 234},
        {name = 'Time',     x = 525, y = 234},
        {name = 'FPS/Ping', x = 525, y = 234},
        {name = 'Vehicle',  x = 525, y = 234},
        {name = 'Name',     x = 525, y = 234},
    },

    elements = defaultElements(),

    --[[
        The server-side textdraws this script repositions and recolours, per
        server.

        ONE TABLE PER SERVER, not one shared table, and that is deliberate.
        The two servers draw the same seven things in different PLACES, so a
        single set of coordinates cannot be right on both - a logo x of 635.7
        is the top-right corner on Paraiso and past the edge of Horizon's.
        Sharing them would mean re-dragging every row each time you switch
        servers, and losing the other server's layout when you did.

        Which one is live follows akacross.rp's detected profile; see SERVERS.
    ]]
    hrp = {
        turf      = {enabled = false, x = 86,  y = 434},
        turfOwner = {enabled = false, x = 86,  y = 423, color = 4294967295},
        wristwatch = {enabled = false, x = 577, y = 24, color = 4294967295},
        logo      = {enabled = true, custom = false, text = 'akacross.net',
                     x = 562.0, y = 3.0, color = 4294967295},
        hpBar     = {enabled = false, color1 = 4278190080,
                     color2 = 4284091408, color3 = 4290058273},
        hpText    = {enabled = false, color = 4294967295},
        armorText = {enabled = false, color = 4294967295},
    },
    prp = {
        turf      = {enabled = false, x = 86,  y = 434},
        turfOwner = {enabled = false, x = 86,  y = 423, color = 4294967295},
        wristwatch = {enabled = false, x = 577, y = 24, color = 4294967295},
        logo      = {enabled = true, custom = false, text = 'akacross.net',
                     x = 635.7, y = 3.0, color = 4294967295},
        hpBar     = {enabled = false, color1 = 4278190080,
                     color2 = 4284091408, color3 = 4290058273},
        hpText    = {enabled = false, color = 4294967295},
        armorText = {enabled = false, color = 4294967295},
    },
}

--[[
    WHY THERE IS NO v1 MIGRATION.

    There was one. It read each v1 index into the v2 field it became, and a
    test proved it converted the v1 defaults into the v2 defaults field for
    field. It could never run, for two reasons that only showed up against a
    real install:

    1. THE VERSION CAME FROM THE DEFAULTS, NOT THE FILE. The load applied the
       defaults first - which stamp `version = 2` - and then merged the file
       over them. A v1 file has no version key, so nothing changed it, and the
       migration's `already v2?` guard saw its own default and skipped. The
       test fed it a bare v1 table directly and never went through the load
       path, so it verified the mapping and not the trigger.

    2. cjc CANNOT READ A v1 FILE AT ALL. carbJsonConfig encodes every scalar
       as ["number", 2] / ["boolean", true]; the hand-written saver this
       script used before 1.4.37 wrote them bare. cjc's merge skips a bare
       scalar entirely ("CarboneumJsonConfig(load): weird shit happens.." -
       144 of those in one load), and for a bare ARRAY it takes element [2],
       so `"sizex":[130,130,130,130,130,115,22]` arrives as the number 130.
       The v1 arrays are destroyed on the way in. There was nothing left to
       migrate FROM.

    So the schema version is the gate now, it is read from the RAW FILE before
    cjc touches it, and a config that predates it is set aside rather than
    guessed at. Nothing is deleted: the old file is renamed, so it is still
    there if it is ever worth writing a plain-JSON reader for.
]]

--[[
    CONFIG PERSISTENCE - akacross.config over carbJsonConfig.

    This replaces ~140 lines of hand-written JSON handling: handleConfigFile,
    ensureDefaults, loadConfig, saveConfig and saveConfigWithErrorHandling. All
    of it was doing what the shared registry already does - create the
    directory, merge a file over the in-memory defaults, write it back when it
    does not exist, and report rather than throw when it is corrupt.

    TWO SETS, because this script has two kinds of config:

      settings.json      one file, always the same path
      configs/<file>     the HUD itself, and the FILE is chosen at runtime

    The second is why the hud set is re-opened on a switch rather than
    registered once: a Set maps one name to one filename.

    RESET IS OURS, NOT cjc's. cjc snapshots a table's contents on first load to
    implement `cfg("reset")`, so after switching config files its idea of "the
    defaults" would be whatever the previous file held. Config.reset writes
    from hud_defaultSettings instead, which is also what lets it PRUNE - cjc
    merges, so a key the defaults no longer have would otherwise sit in the
    table forever.

    ONE TABLE, not a dozen locals: Lua 5.1 allows 200 per function and this
    script's main chunk is one function. See the note on CLR/SZ/SERVERS.
]]
local Config = {}
do
    local okConfig, configM = pcall(require, 'akacross.config')
    if not (okConfig and type(configM) == 'table' and configM.open) then configM = nil end
    Config.available = configM ~= nil

    local settingsSet, hudSet

    local function deepCopy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for k, v in pairs(value) do out[k] = deepCopy(v) end
        return out
    end

    --[[
        Overwrite `target` from `defaults`, and DROP anything the defaults no
        longer have. `keep` names top-level keys that are the user's to decide
        and must survive a reset (which config file is being edited).
    ]]
    local function applyDefaults(target, defaults, keep)
        for key in pairs(target) do
            if not (keep and keep[key]) and defaults[key] == nil then
                target[key] = nil
            end
        end
        for key, value in pairs(defaults) do
            if not (keep and keep[key]) then
                target[key] = deepCopy(value)
            end
        end
        return target
    end

    --[[
        cjc MERGES a file into the table, which is right for a record and wrong
        for a LIST: a saved `anchors` of three entries merged over a six-entry
        default leaves the last three defaults behind, so deleting an anchor
        would never stick. The hook empties the list first - but only when the
        file actually contains one, or a fresh install would persist the
        emptied list as its starting config. That guard is the whole reason the
        hook takes the raw file text; see akacross.config's load().
    ]]
    local function clearHudLists(t, raw)
        if raw:find('"anchors"', 1, true) then t.anchors = {} end
    end

    local function report(msg) print('[hud] ' .. tostring(msg)) end

    --[[
        THE SCHEMA GATE.

        Read straight off the raw file, BEFORE cjc merges anything, because
        that is the only moment the file's own version is visible: the load
        applies the defaults first, and those carry the current version, so a
        check made afterwards is reading its own answer.

        Both encodings are matched. cjc writes `"version":["number",2]`; the
        hand-written saver this script used before 1.4.37 wrote scalars bare,
        and although such a file can never pass the gate, matching its shape
        means a bare `"version":2` from any other writer is still understood.
    ]]
    local function fileSchemaVersion(raw)
        if type(raw) ~= 'string' then return nil end
        local value = raw:match('"version"%s*:%s*%[%s*"number"%s*,%s*(%-?%d+)')
                   or raw:match('"version"%s*:%s*(%-?%d+)')
        return tonumber(value)
    end

    local function readRaw(path)
        local f = io.open(path, 'r')
        if not f then f = io.open((path:gsub('\\', '/')), 'r') end
        if not f then return nil end
        local content = f:read('*a')
        f:close()
        return content
    end

    --[[
        Set a pre-schema config aside instead of loading it.

        NOT deleted - renamed. The data in it is not readable by this loader
        (see the note above migrateConfig's grave), but it is the user's, and
        an unreadable file is a different thing from a file worth destroying.
    ]]
    local function quarantine(path, file, found)
        local backup = path .. '.v1.bak'
        os.remove(backup)
        local moved = os.rename(path, backup)
        report(('%s is from before the per-element layout (%s); starting from the defaults%s')
            :format(tostring(file),
                    found and ('schema ' .. tostring(found)) or 'no schema version',
                    moved and (', old file kept as ' .. file .. '.v1.bak') or ''))
    end

    --[[
        Drop top-level keys the defaults do not have.

        cjc MERGES, so anything an older layout left in the file comes back
        every load and is written out again - which is how a half-converted
        file ends up carrying both layouts at once. Only the top level is
        swept: that is where a schema change puts its dead keys, and going
        deeper would start deleting the tail of user-grown LISTS like anchors.
    ]]
    --[[
        `hzg`/`pgaming` -> `hrp`/`prp`.

        The rows themselves are unchanged - same seven, same fields - so this
        is a key rename and not a schema change, which is why the schema
        version stays where it is. cjc has already decoded the file by the time
        this runs, so the values are plain Lua and copying them is safe; that
        is exactly what was NOT true of the v1 migration this file buried (see
        the note above the defaults).

        Only fields present in the destination defaults are copied. The source
        key is cleared afterwards so pruneUnknown does not report it as stale
        and so it is not written back out.
    ]]
    local SERVER_KEY_RENAMES = {hzg = 'hrp', pgaming = 'prp'}

    local function migrateServerKeys(target)
        local moved
        for old, new in pairs(SERVER_KEY_RENAMES) do
            local from, to = target[old], target[new]
            if type(from) == 'table' and type(to) == 'table' then
                for row, values in pairs(from) do
                    if type(values) == 'table' and type(to[row]) == 'table' then
                        for field, value in pairs(values) do
                            if to[row][field] ~= nil then to[row][field] = value end
                        end
                    end
                end
                target[old] = nil
                moved = moved or {}
                moved[#moved + 1] = old
            end
        end
        return moved
    end

    local function pruneUnknown(target, defaults)
        local dropped
        for key in pairs(target) do
            if defaults[key] == nil then
                target[key] = nil
                dropped = (dropped or 0) + 1
            end
        end
        return dropped
    end

    local function openHudSet()
        if not configM then return nil end
        hudSet = configM.open('hud', {dir = getPath('configs'), log = report})
        hudSet:register('hud', hud, {file = settings.JsonFile, clear = clearHudLists})
        return hudSet
    end

    --- settings.json. Registered once; the path never changes. Same gate: the
    --- pre-1.4.37 file was written bare and cjc reads none of it.
    function Config.loadSettings()
        applyDefaults(settings, settings_defaultSettings)
        if not configM then return false end

        settingsSet = configM.open('hud', {log = report})
        settingsSet:register('settings', settings)
        --[[
            A SET OF ITS OWN, not a key inside `settings`.

            The binds carry cdata (`Toggle = new.bool(true)`), and `settings` is
            a plain-Lua table walked by applyDefaults and deepCopy - which
            copies a cdata object by REFERENCE, so the defaults table and the
            live table would end up sharing one and "reset" would be a no-op
            for the toggles.

            The clear hook is the one every mod here uses: lists must REPLACE,
            not merge, or a rebound key accumulates - but clear only the binds
            the file actually names, or a bind added in a later version loads
            with no keys at all.
        ]]
        settingsSet:register('keybinds', Keybinds, {
            clear = function(t, raw)
                for name, bind in pairs(t) do
                    if type(bind) == 'table' and raw:find('"' .. name .. '"', 1, true) then
                        bind.Keys, bind.Types = {}, {}
                    end
                end
            end
        })

        local path = settingsSet:path('settings')
        local raw = readRaw(path)
        if raw and #raw > 0 then
            local found = fileSchemaVersion(raw)
            if not found or found < SCHEMA_VERSION then
                quarantine(path, 'settings.json', found)
                settingsSet:save('settings')
                return true
            end
        end

        settingsSet:load('settings')
        settingsSet:load('keybinds')
        pruneUnknown(settings, settings_defaultSettings)
        return true
    end

    function Config.saveSettings()
        if not settingsSet then return end
        settingsSet:save('settings')
        settingsSet:save('keybinds')
    end

    --- Exposed so the entry can persist a keybind repair on its own, without
    --- also writing out a settings table the user may be mid-edit on.
    function Config.saveKeybinds()
        if settingsSet then settingsSet:save('keybinds') end
    end

    --[[
        The HUD config from the selected file.

        The gate runs against the raw bytes first; only a file of this schema
        is handed to cjc at all. Anything older is set aside and the defaults
        stand, which is also what happens for a file that has never existed.
    ]]
    function Config.loadHud()
        applyDefaults(hud, hud_defaultSettings)
        if not configM then return false end

        local path = getPath('configs') .. tostring(settings.JsonFile)
        local raw = readRaw(path)
        if raw and #raw > 0 then
            local found = fileSchemaVersion(raw)
            if not found or found < SCHEMA_VERSION then
                quarantine(path, settings.JsonFile, found)
                if not openHudSet() then return false end
                hudSet:save('hud')      -- write the defaults out under the name
                return true
            end
        end

        if not openHudSet() then return false end
        hudSet:load('hud')

        -- The server rows were named after the servers themselves - `hzg`
        -- until 1.4.37, `pgaming` after it. They are keyed by rp's profile id
        -- now, so this carries a file written under either old name across
        -- before pruneUnknown drops it as unknown. Field by field, and only
        -- fields the defaults still have, so a renamed row cannot smuggle a
        -- dead key back in.
        local renamed = migrateServerKeys(hud)
        if renamed then
            report(('moved %s to the server-profile layout'):format(table.concat(renamed, ' and ')))
        end

        -- A file written by a half-way version can still be carrying keys from
        -- the old layout; they go here rather than being written out again.
        local dropped = pruneUnknown(hud, hud_defaultSettings)
        if dropped then
            report(('dropped %d stale key(s) from %s'):format(dropped, tostring(settings.JsonFile)))
            hudSet:save('hud')
        end
        return true
    end

    function Config.saveHud()
        if hudSet then hudSet:save('hud') end
    end

    --[[
        Write a config out under another name, without making it the active
        one. Used by the copy and new-file prompts.

        STRAIGHT TO cjc, NOT THROUGH THE SET, and a COPY of the source.

        A Set only saves what it has loaded, and loading is the one thing that
        must not happen here: cjc MERGES a file into the table it is given, so
        copying onto an existing file would pull that file's contents into the
        live config - or, for "new file from defaults", into the defaults
        table itself, permanently. The deep copy is the second half of that
        guard: cjc also attaches its __call metamethod to whatever it is
        handed, and the defaults table should not acquire one.
    ]]
    function Config.saveHudAs(file, source)
        if not cjc then return false end
        local ok, err = pcall(cjc.save, getPath('configs') .. file, deepCopy(source))
        if not ok then
            report(('failed to write %s: %s'):format(tostring(file), tostring(err)))
            return false
        end
        return true
    end

    --- Back to the shipped defaults, keeping which file the user is editing.
    function Config.resetHud()
        applyDefaults(hud, hud_defaultSettings)
        Config.saveHud()
    end

    Config.applyDefaults = applyDefaults
end

-- Value Data
local healthValues = {nil}
local armorValues = {nil}
local sprintValues = {nil}
local vehicleValues = {nil}
local weaponValues = {nil, nil, nil}
local breathValues = {nil}
local moneyWantedValues = {nil, nil}
local miscValues = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}

-- Assets Configuration
local assets = {
    tempPos = {x = 0, y = 0},
    weapTextures = nil,
    -- Vehicles whose health tops out at 2500 rather than 1000.
    maxVehHPIds = {427, 528, 601},
    badgeNames = {
        {-1, 'No Badge'}, {-14269954, 'LSPD'}, {-7500289, 'FBI'}, {-14911565, 'ARES'}, {-4276546, 'GOV'}, {-3368653, 'SASD'}, 
        {-32126, 'LSFMD'}, {-16475023, 'SANEWS'}, {-7684107, 'DD'}
    }
}

local cachedWeaponTextures = {}

-- Menu Configuration
--
-- One window now. `confirm` was a SECOND top-level window whose whole job was
-- to ask "are you sure?"; the six prompts are modal popups inside the settings
-- window itself (lib/hud/files.lua), which is what the other mods do and what
-- removes the "prompt outlives its parent" cleanup the old one needed.
local menu = {
    settings = new.bool(false),
}

-- State Variables
-- `dragging`, `move`, `inuse`, `selectedbox` and `selected` used to live here.
-- The drag state belongs to hudMove now and is declared next to it; the rest
-- were the v1 per-element selection bookkeeping, which the part model replaced.
-- `mid` - which strip button was pressed - went with the strip: the element
-- list owns its own selection now (lib/hud/settings.lua).

-- Other Configurations
local hudUpdateThread
local fps = 0
local fps_counter = 0

-- Game Data
local subZones = {
    GAN1 = 'Grove Street', GAN2 = "Apartments", IWD1 = 'Freeway', IWD2 = 'Drug Den', IWD3A = 'Gas Station', IWD3B = 'Maximus Club',
    IWD4 = 'Ghetto Area', IWD5 = 'Pizza', LMEX1A = "South", LMEX1B = "North", ELS1A = "Crack Lab", ELS1B = "Pig Pen", ELS2 = "Apartments", 
    ELS3A = "The Court", ELS3C = "Alleyway", ELS4 = "Carwash", ELCO1 = "Unity Station", ELCO2 = "Apartments", LIND1A = "West", LIND2A = "South", LIND2B = "South", LIND3 = "East"
}

local customZones = {
    ["Castille Island"] = {3138.7588, -2248.6106, -63.2630, 3530.0903, -1922.0083, 343.3367},
    ["ARES Garage"] = {2204.1096, 2411.6570, -13.5870, 2329.5793, 2512.3259, 0.4885},
    ["FBI Garage"] = {248.1156, -1549.7271, 22.9225, 370.9664, -1456.6969, 30.3469}
}

--[[
    Registered with akacross.player rather than read by it. The module cannot
    know a server's own districts, so the zone set is the mod's to supply -
    which is also what lets a second mod on a different server register a
    different one without either of them fighting over a global.
]]
playerM.setCustomZones(customZones)

--[[
    hud's own compass, in the game's heading order (counter-clockwise, so 23-67
    is north-WEST). Long names, which is what this HUD has always drawn.
]]
local directionData = {
    {min = 0, max = 22, name = "North"},
    {min = 23, max = 67, name = "Northwest"},
    {min = 68, max = 112, name = "West"},
    {min = 113, max = 157, name = "Southwest"},
    {min = 158, max = 202, name = "South"},
    {min = 203, max = 247, name = "Southeast"},
    {min = 248, max = 292, name = "East"},
    {min = 293, max = 329, name = "Northeast"},
    {min = 330, max = 360, name = "North"}
}
playerM.setCompass(directionData)

local spectateData = {
	id = -1,
	state = false
}

local function checkForUpdates()
    if settings.updateInProgress then
        formattedAddChatMessage(string.format("You have successfully upgraded from Version: %s to %s", settings.lastVersion, scriptVersion), -1)
        displayChangelog()
        settings.updateInProgress = false

        Config.saveSettings()
    else
        if settings.checkForUpdates then 
            checkForUpdate() 
        end
    end
end

--[[
    Forward-declared: switching renderers means releasing every font and
    texture on the one being left and rebuilding them on the one being joined,
    so it cannot be written until the font cache and the texture loader exist -
    several hundred lines below both of its callers, initialisation here and
    the Screen tab's toggle.
]]
local applyRenderer

--[[
    Forward-declared for the same reason as applyRenderer: it reads the font
    slots, which are built several hundred lines below the chat command that
    prints them.
]]
local renderReport

--[[
    The renderer the Screen tab asked for, applied on the next present.

    NOT applied where the checkbox is ticked, and this is not tidiness. That
    checkbox is drawn from inside mimgui's frame, and switching renderers there
    releases D3D textures that the frame's draw list is still holding pointers
    to - they would be rendered at EndFrame, after being freed. (The first
    version of this also mutated mimgui's own subscription list from inside the
    `ipairs` walking it, which faulted in lua51.dll outright.)

    onD3DPresent is a different handler from mimgui's, so it runs either before
    NewFrame or after EndFrame. Both are outside the frame, which is the only
    thing this needs to be.
]]
local pendingRenderer = nil

-- HUD Initialization
local function initializeHud()
    displayHud(hud.defaultHud)
    -- The renderer the user chose, BEFORE the first font or texture is made:
    -- see applyRenderer for why the order matters.
    applyRenderer(settings.renderer)
    loadFonts()
    loadTextures()
    -- One sweep for all seven rows. This was `for i = 0, 6 do srvTextDraws(i) end`,
    -- and every one of those seven calls walked the pool from scratch.
    srvTextDraws()
end

-- Update Thread
local function createUpdateThread()
    if not hudUpdateThread or coroutine.status(hudUpdateThread) == "dead" then
        hudUpdateThread = coroutine.create(function()
            local fpsUpdateTime = os.clock() + 1
            while true do wait(5)
                playerM.feedSprint(isButtonPressed(h, gkeys.player.SPRINT))
                hudValues()
                if os.clock() >= fpsUpdateTime then
                    fps = fps_counter
                    fps_counter = 0
                    fpsUpdateTime = os.clock() + 1
                end
                coroutine.yield()
            end
        end)
    end
end

-- Resume Update Thread
local function resumeUpdateThread()
    if hudUpdateThread and coroutine.status(hudUpdateThread) == "suspended" then
        local success, errorMsg = coroutine.resume(hudUpdateThread)
        if not success then
            print("Coroutine error: " .. errorMsg)
        end
    end
end

-- OnInitialize
--[[
    SERVER DETECTION, retried until it lands.

    sampGetCurrentServerName is only readable once the gamestate is CONNECTED,
    which is later than this script starts, so attach() is polled rather than
    called once. It stops being called the moment rp reports a profile - by
    then some other mod may have detected it first, and rp shares one answer.

    Guarded on the API existing: akacross.rp gained detection in 0.2.0 and an
    install carrying an older copy must still load and run - without the
    server overrides, but with the whole rest of the HUD.
]]
local DETECT_RETRY = 1.0
local lastDetect = 0

--[[
    Forward declaration. adoptProfile needs the SERVERS table, which is
    declared with the textdraw overrides ~500 lines below; detectServer is
    called from main(), which is defined just under this. Without the
    declaration the call below would resolve as a nil GLOBAL - which is the
    same shape of mistake as the one this whole change is fixing, so it is
    written out rather than left to be noticed.
]]
local adoptProfile

local function detectServer()
    if not (rpM and rpM.attach and rpM.detected) or rpM.detected() then return end
    local now = os.clock()
    if (now - lastDetect) < DETECT_RETRY then return end
    lastDetect = now

    --[[
        ADOPT WHAT attach() RETURNS, rather than trusting the listener alone.

        rp 0.2.2 fixed the case this belts-and-braces against: its default
        profile is hrp, so on Horizon setProfile received the table it already
        held, `changed` was false, and onProfile never fired. Everything here
        stayed inert on one server and worked on the other.

        rp is a file that can be older than this script - the self-heal
        installs it, but an install can be mid-repair - so the entry does not
        depend on that fix having landed. adoptProfile is idempotent, so the
        two paths cannot fight.
    ]]
    local profile = rpM.attach()
    if profile then adoptProfile(profile) end
end

function main()
    local paths = getPath(nil)
    for _, dir in pairs({"config", "settings", "configs", "resource", "resources", "icons"}) do
        createDirectory(paths[dir])
    end

    -- Load Configs
    Config.loadSettings()
    Config.loadHud()

    -- The menu is built at load time, before any of that existed. This is what
    -- points it at the values that were just read.
    applyMenuSettings()

    repeat wait(0) until isSampAvailable()

    -- Check for updates 
    checkForUpdates()

    -- Register Chat Commands
    sampRegisterChatCommand("hud", function(arg)
        if settings.updateInProgress then
            formattedAddChatMessage("Update in progress. Please wait a moment.", -1)
            return
        end
        -- `/hud render` says what is drawing and what it resolved, and
        -- `/hud td [filter]` dumps the server's textdraws in the form the
        -- SERVERS table wants. Everything else is the menu, which is what
        -- /hud has always done.
        if arg and arg:lower():match('^%s*render%s*$') then
            renderReport()
            return
        end
        local tdFilter = arg and arg:match('^%s*td%s*(.-)%s*$')
        if tdFilter then
            textdrawReport(tdFilter ~= '' and tdFilter or nil)
            return
        end
        menu.settings[0] = not menu.settings[0]
    end)

    print(('[HUD] ready - /hud, /hud render, /hud td (menu: %s)')
        :format(keybindsM.bindLabel(Keybinds.Menu)))

    -- Download Icons and Initialize HUD
    downloadFiles(generateIconUrls(), function(result)
        if result then 
            formattedAddChatMessage("All files downloaded successfully!", -1) 
        end
        initializeHud()
    end)

    -- Create Update Thread
    createUpdateThread()

    -- Resume Update Thread
    while true do wait(0)
        resumeUpdateThread()
        pollKeybinds()
        detectServer()
    end
end

-- =========================================================================
-- Rendering
-- =========================================================================
--[[
    A PART IS A PART.

    Every drawn thing - a bar, a weapon icon, a row of stars, a line of text -
    is a table with `enabled`, an `anchor` and an `offx`/`offy`. So placing one
    is a single function, and the renderers below take the part table rather
    than an element number and a slot index.
]]
-- The grab handle drawn at each anchor while the settings window is open.
local ANCHOR_HANDLE = 15

local function partPosition(part)
    local anchor = hud.anchors[part.anchor] or hud.anchors[1]
    return anchor.x + part.offx, anchor.y + part.offy
end

--[[
    The live values, keyed by element so a renderer looks one up the same way
    it looks up its config. These are runtime state, not config: what the HUD
    is showing right now.
]]
local BAR_VALUES = {
    health = healthValues, armor = armorValues, sprint = sprintValues,
    vehicle = vehicleValues, breath = breathValues,
}
local MISC_INDEX = {}
for i = 1, #Spec.misc do MISC_INDEX[Spec.misc[i]] = i end

function renderBar(x, y, bar, value, maxValue)
    value = math.min(value, maxValue)
    local color = bar.color
    -- Only the vehicle bar carries damage colours, and carrying them is what
    -- says it recolours - there is no element number to test any more.
    if bar.damageLow then
        color = (value < 400) and bar.damageLow
             or (value < 700) and bar.damageMid
             or color
    end
    --[[
        The value fill takes the INNER radius, the same one boxBorder gives the
        fade behind it, so the two agree at the left edge. At low values imgui
        clamps the radius to half the width and the fill becomes a lozenge,
        which is what a rounded progress bar should do as it empties.

        `hud.rounding` is one number for every bar rather than a field per bar:
        seven independently rounded bars is a thing nobody wants and seven more
        settings rows to maintain.
    ]]
    local rounding = hud.rounding or 0
    local inner = rounding - bar.border
    if inner < 0 then inner = 0 end

    drawM.boxBorder(x, y, bar.sizex, bar.sizey, bar.fade, bar.border, bar.outline, rounding)
    drawM.box(x + bar.border, y + bar.border,
        (bar.sizex - 2 * bar.border) * value / maxValue,
        bar.sizey - 2 * bar.border, color, inner)
end

function renderWeap(x, y, icon, weaponId, frame)
    if frame then
        drawM.texture(assets.weapTextures[47], x, y, icon.sizex, icon.sizey, 0, icon.frameColor)
    end
    -- An icon png that is not on disk leaves a nil here. drawM.texture draws
    -- nothing rather than raising, which is what this used to do once a frame
    -- for as long as the player held that weapon.
    drawM.texture(assets.weapTextures[weaponId], x, y, icon.sizex, icon.sizey, 0, icon.color)
end

function renderStar(x, y, stars, count)
    for i = 1, count do
        drawM.texture(assets.weapTextures[48],
            x + (stars.sizex + stars.spacing) * i, y,
            stars.sizex, stars.sizey, 0, stars.color)
    end
end

--- Draw a text part, if it is on and has something to say.
local function drawTextPart(key, partName, part, value)
    if not part.enabled or value == nil then return end
    local x, y = partPosition(part)
    renderFont(x, y, key, partName, value, part.color)
end

-- ---- one renderer per kind ----------------------------------------------
local RENDER = {}

function RENDER.bar(key, cfg)
    local value = BAR_VALUES[key][1]
    if value == nil then return end
    if cfg.bar.enabled then
        local x, y = partPosition(cfg.bar)
        renderBar(x, y, cfg.bar, value, cfg.max)
    end
    drawTextPart(key, 'text', cfg.text, value)
end

function RENDER.weapon(key, cfg)
    local weaponId = weaponValues[1]
    if weaponId == nil then return end
    if cfg.icon.enabled then
        local x, y = partPosition(cfg.icon)
        renderWeap(x, y, cfg.icon, weaponId, cfg.frame)
    end
    -- Fists have no ammo, so the ammo line is suppressed rather than reading 0.
    if weaponId ~= 0 then
        drawTextPart(key, 'ammo', cfg.ammo, weaponValues[2])
    end
    drawTextPart(key, 'name', cfg.name, weaponValues[3])
end

function RENDER.stars(key, cfg)
    local wanted = moneyWantedValues[1]
    if wanted ~= nil and cfg.stars.enabled then
        local x, y = partPosition(cfg.stars)
        renderStar(x, y, cfg.stars, wanted)
    end
    drawTextPart(key, 'text', cfg.text, moneyWantedValues[2])
end

function RENDER.text(key, cfg)
    drawTextPart(key, 'text', cfg.text, miscValues[MISC_INDEX[key]])
end

--[[
    When an element is on screen at all, as opposed to whether its parts are
    enabled. `stayOn` is the user saying "show it even when it is not
    relevant"; the settings window forces everything visible so it can be
    placed.
]]
local VISIBLE = {
    armor   = function(cfg) return (armorValues[1] or 0) > 0 or cfg.stayOn end,
    sprint  = function(cfg)
        return (playerM.isSprinting() and not isCharInAnyCar(ped)) or cfg.stayOn or menu.settings[0]
    end,
    vehicle = function(cfg)
        return menu.settings[0] or isCharInAnyCar(ped) or cfg.stayOn or spectateData.state
    end,
    breath  = function(cfg) return menu.settings[0] or isCharInWater(ped) or cfg.stayOn end,
}

local function renderElements()
    if not assets.weapTextures then return end
    local list = Spec.list
    for i = 1, #list do
        local spec = list[i]
        local cfg = hud.elements[spec.key]
        if cfg then
            local visible = VISIBLE[spec.key]
            if not visible or visible(cfg) then
                RENDER[spec.kind](spec.key, cfg)
            end
        end
    end
end

--[[
    WHO DRAWS, AND WHEN.

    Two halves that used to be one function, because they answer to different
    things:

      the STATE half   counting frames, and clearing the values when the HUD is
                       hidden. Has to happen on every present, whatever is on
                       screen and whichever renderer is drawing it.

      the DRAW half    has to happen wherever the ACTIVE BACKEND says. The
                       native renderer draws straight from this present; the
                       ImDrawList one has to append inside imgui's own frame,
                       which is a different moment in the same present.

    So the draw half is handed to `drawM` once, and `drawM.present()` is this
    present being offered to whatever is drawing.
]]
local hudOn = false

--- Whether the HUD belongs on screen. A PREDICATE over a value derived once per
--- present, because mimgui polls its subscription conditions from a worker
--- thread - this is read at moments this script does not choose, and it must
--- not be four natives deep when it is.
local function hudVisible() return hudOn end

-- The generation every font slot was last built at. See createFont.
local fontGeneration = -1

local function hudDrawPass()
    --[[
        ONE comparison a frame, not one per element. When it moves, loadFonts
        walks every text part and createFont rebuilds the ones that need it -
        which for a backend switch is all of them and for an atlas bake is the
        handful that were waiting on it.
    ]]
    local gen = drawM.generation()
    if gen ~= fontGeneration then
        fontGeneration = gen
        loadFonts()
    end

    renderElements()

    if menu.settings[0] then
        local anchors = hud.anchors
        for i = 1, #anchors do
            drawM.box(anchors[i].x, anchors[i].y, ANCHOR_HANDLE, ANCHOR_HANDLE, -1)
        end
        hudMove()
    end
end

drawM.attach(hudDrawPass, hudVisible)

-- OnD3DPresent
function onD3DPresent()
    fps_counter = fps_counter + 1

    -- Outside any imgui frame, which is the whole point of the deferral.
    if pendingRenderer then
        local name = pendingRenderer
        pendingRenderer = nil
        applyRenderer(name)
    end

    hudOn = hud.toggle and not (isPauseMenuActive() or sampIsScoreboardOpen()
        or sampGetChatDisplayMode() == 0 or isKeyDown(VK_F10))
    if not hudOn then resetValues() end
    drawM.present()
end

--[[
    OnWindowMessage.

    Two jobs, and a script gets exactly one of these.

    Escape closes the window, as it always did.

    The second is the rebind editor's key capture. onWindowMessage is the only
    place a press arrives exactly once, with its virtual-key code, before the
    game acts on it - a settings window cannot see raw key messages, and
    polling isKeyDown in a render pass catches the click that armed the rebind.
    The message is CONSUMED while capturing, so binding J does not also toggle
    the menu on the press that bound it.
]]
function onWindowMessage(msg, wparam, lparam)
    if wparam == VK_ESCAPE and menu.settings[0] then
        if msg == wm.WM_KEYDOWN then
            consumeWindowMessage(true, false)
        end
        if msg == wm.WM_KEYUP then
            menu.settings[0] = false
        end
        return
    end

    -- WM_KEYDOWN / WM_SYSKEYDOWN only: KEYUP would bind on release, and CHAR
    -- gives a character rather than a key.
    if msg == 256 or msg == 260 then
        -- Never steal keys destined for chat or a dialog, even mid-rebind: the
        -- capture consumes the message, so arming a rebind and then typing
        -- would swallow the user's text.
        if not checkChatDialogScoreboardConsolePause(true, true, false, true, false) then
            return
        end
        if keybindsM.isCapturing() and keybindsM.captureKey(wparam) then
            consumeWindowMessage(true, false)
        end
    end
end

-- OnServerMessage
function sampev.onServerMessage(color, text)
	if text:find("turns off their wristwatch.") then
        clearGxtEntry("wwText")
	end

	if text:find("You have toggled off turfs on your radar/map.") then
        clearGxtEntry("turfText")
	end
end

-- OnTogglePlayerSpectating
function sampev.onTogglePlayerSpectating(state)
    spectateData.id = state and spectateData.id or -1
    spectateData.state = state
end

-- OnSendCommand
function sampev.onSendCommand(command)
    local cmd = command:match("^/spec (.-)$")
    if cmd then
        local res, id, _ = findPlayer(cmd)
        if res then
            spectateData.id = id
        end
    end
end

--[[
    THE SERVER-SIDE TEXTDRAW OVERRIDES.

    Two servers draw the same seven things - turf, turf owner, wristwatch,
    logo, HP bar, HP text, armour text - and this script repositions,
    recolours or hides them. Everything that DIFFERS between the two is in the
    table below; everything that does not is written once underneath it.

    WHY A TABLE AND NOT TWO COPIES. Until 1.4.37 this file supported Horizon
    and named everything `hzg`; 1.4.37 replaced that wholesale with Paraiso and
    named everything `pgaming`. Both times the server was spelled into forty
    call sites, so adding the second one back meant either a second set of
    forty or this. The identifiers are neutral now (`srv*`), the server-shaped
    facts are data, and a third server is a table entry.

    WHAT ACTUALLY DIFFERS:

      the letter-size signatures    every draw except turf is a different size
      the logo's fallback text      the server's own domain
      the turf string               Paraiso prefixes it "Owner: "
      where HP/armour sit           Horizon puts them on whole pixels;
                                    Paraiso lands on x.25 / x.33 thirds

    WHAT DOES NOT: the HP bar. Both servers stack its three draws at the same
    two positions, so it is matched below rather than per server.

    SIGNATURES ARE COMPARED AS STRINGS. These are floats that arrive over the
    network and never survive an `==` against a literal, so the FORMATTED value
    is what is matched - which is also why they are written out to their full
    printed precision rather than rounded.
]]
--[[
    Which of the three stacked bar draws this is, or nil. `floor` first: the
    server sends these on fractional pixels (546 / 66.699996948242).

    THE THIRD ONE IS THE PROBLEM. Two of the three sit at the SAME position on
    Horizon - 548 / 68.8 for both - so position alone cannot separate them.
    What does is the pool split: SA-MP's ids 0..2047 are global textdraws and
    2048..2303 are per-player ones, and the bar's fill is the per-player one
    because it is the one that changes with your health. Hence the id.

    Paraiso lays its three out at distinct positions and is matched the way it
    always was.
]]
local function hpBarByPos(id, posX, posY, x1, y1, x2, y2, splitById)
    local fx, fy = math.floor(posX), math.floor(posY)
    if fx == x1 and fy == y1 then return 1 end
    if splitById then
        if fx == x2 and fy == y2 then return id >= 2048 and 3 or 2 end
        return nil
    end
    if fx == x2 and fy == y2 then return 2 end
    if fx <= x2 and fy == y2 then return 3 end
    return nil
end

local SERVERS = {
    --[[
        CAPTURED FROM THE LIVE SERVER, 2026-08-28, via `/hud td`.

        Most of what was here before was right. The reason none of it worked
        was not the signatures at all - it was that akacross.rp's default
        profile IS hrp, so detecting Horizon handed back the same table, the
        `changed` test in setProfile was false, and the listener that turns
        these on never ran. rp 0.2.2 fires on the defaulted->known transition
        too. Three rows were genuinely wrong as well, and are fixed below.

        Confirmed against the dump: the turf name (id 2052), the turf owner
        (id 6), the logo (id 7), the HP and armour readouts (ids 2053/2054)
        and all three HP bar draws (ids 0, 1, 2050).

        NOT confirmed: the wristwatch. It is not in the pool unless the player
        is wearing one, so it keeps its historical signature and is the single
        row here still taken on trust.
    ]]
    hrp = {
        id = 'hrp', cfg = 'hrp', label = 'Horizon',
        verified = true,
        logoText = 'hzgaming.net',
        sig = {
            turfW = "0.23999999463558", turfH = "1.2000000476837",
            -- unconfirmed: no wristwatch in the capture
            wwW   = "0.5",              wwH   = "2",
            logoW = "0.3199990093708",  logoH = "1.3999999761581",
            textW = "0.25999900698662", textH = "1.2000000476837",
            turfOwner = "TURF OWNER:",
        },
        -- The size the HP/armour readouts are rewritten at when they are
        -- blanked and restored. It has to be the server's own, or the slot
        -- stops matching its signature and the sweep loses it.
        textSize = {0.25999900698662, 1.2000000476837},
        --- Horizon sends the turf name on its own.
        turfText = function(text) return text end,
        --- Whole-pixel positions, so a plain == is enough. 611 is what the
        --- capture shows; 577 is kept because older captures had it there and
        --- an extra accepted x costs nothing - the y is what picks the role.
        hpArmorRole = function(posX, posY)
            if posX ~= 577 and posX ~= 611 then return nil end
            if posY == 65 then return 'hpText' end
            if posY == 43 then return 'armorText' end
            return nil
        end,
        --[[
            546/66 and 548/68 for both paths. The old profile swept for
            610/68 and 608/70 - Paraiso's laid-out positions, copied across in
            the 1.4.37 rename and never true here. The live pool puts these at
            546 / 66.699996948242 and 548 / 68.800003051758.
        ]]
        hpBarShow  = function(id, x, y) return hpBarByPos(id, x, y, 546, 66, 548, 68, true) end,
        hpBarSweep = function(id, x, y) return hpBarByPos(id, x, y, 546, 66, 548, 68, true) end,
        -- Horizon runs a 5,000,000 pool; 100 is what is left on top of it.
        hpPool = 5000000,
        hpMax  = 100,
    },
    -- Re-derived in 1.4.37 against the live server, and confirmed working.
    prp = {
        id = 'prp', cfg = 'prp', label = 'Paraiso',
        verified = true,
        logoText = 'pgaming.net',
        sig = {
            turfW = "0.23999999463558", turfH = "1.2000000476837",
            wwW   = "0.58999902009964", wwH   = "2.2999980449677",
            logoW = "0.25999999046326", logoH = "1.6200000047684",
            textW = "0.32062301039696", textH = "1.1100000143051",
            turfOwner = "TURF OWNER:",
        },
        textSize = {0.32062301039696, 1.1100000143051},
        --- Paraiso prefixes the owner's name. Parenthesised so gsub's second
        --- return value (the count) does not leak to the caller.
        turfText = function(text) return (text:gsub("Owner: ", "")) end,
        --- Neither coordinate is a whole pixel here, so both are matched as
        --- their printed form. The Y decides the role; the X is checked only
        --- to reject anything that is not this pair of draws.
        hpArmorRole = function(posX, posY)
            local x, y = tostring(posX), tostring(posY)
            if x ~= "622.25" and x ~= "623.125" then return nil end
            if y == "65.33332824707" then return 'hpText' end
            if y == "43.166641235352" then return 'armorText' end
            return nil
        end,
        --- Distinct positions for the three, and different ones before and
        --- after the server lays them out.
        hpBarShow  = function(id, x, y) return hpBarByPos(id, x, y, 546, 66, 548, 68, false) end,
        hpBarSweep = function(id, x, y) return hpBarByPos(id, x, y, 610, 68, 608, 70, false) end,
        -- Paraiso runs a 3,000,000 pool, same 100 on top.
        hpPool = 3000000,
        hpMax  = 100,
    },
}

--- Stable order for the settings picker. A table with two string keys has no
--- order of its own, and a menu that reshuffles itself between loads is worse
--- than a menu with an arbitrary but fixed order.
local SERVER_ORDER = {'hrp', 'prp'}

--[[
    WHICH SERVER IS LIVE.

    From akacross.rp, which already answers "what server is this" for every
    other mod here, and answers it from the server NAME rather than from
    whatever textdraws happen to arrive.

    INERT UNTIL IT IS SURE. Nothing below touches a server textdraw while
    `srvKnown` is false. That is stricter than what this script did before -
    it applied its overrides everywhere, and the turf signature is the one both
    servers share, so a third server drawing anything at that letter size had
    its turf draw moved off screen by a HUD that had never heard of it.
]]
local srvId, srvKnown = 'prp', false

--- The active server descriptor, or nil when the server is not one we know.
local function srv()
    return srvKnown and SERVERS[srvId] or nil
end

--- The active server's config table. Same nil rule as srv().
local function srvCfg()
    return srvKnown and hud[SERVERS[srvId].cfg] or nil
end

--[[
    Adopt a detected profile.

    SERVERS is what this script has overrides for; rp knows more servers than
    that (Lawless, for one), so a profile with no entry here leaves the
    overrides switched off rather than falling back to a guess.

    The slot cache is dropped either way: it holds slots that matched the
    PREVIOUS profile's signatures, which mean nothing under a new one.
]]
local adoptedId = nil

--- Assigned, not declared: the `local` is forward-declared above detectServer.
function adoptProfile(profile)
    -- Idempotent: rp 0.2.2 fires on first detection AND detectServer adopts
    -- what attach() hands back, so this can be reached twice for one server.
    -- Re-adopting would throw away a warm slot cache for nothing.
    if profile and adoptedId == profile.id then return end
    adoptedId = profile and profile.id or nil

    local known = profile and SERVERS[profile.id] ~= nil
    srvId = known and profile.id or srvId
    srvKnown = known
    srvInvalidateSlots()
    if known then
        local entry = SERVERS[profile.id]
        if entry.verified then
            print(('[HUD] server: %s (%s) - server textdraw overrides active')
                :format(profile.name, profile.id))
        else
            -- Said plainly, because the alternative is a user concluding the
            -- feature is broken when what is actually wrong is one table.
            print(('[HUD] server: %s (%s) - the textdraw signatures for this server are UNVERIFIED')
                :format(profile.name, profile.id))
            print('[HUD] run /hud td here and the dump can be turned into a working profile')
        end
        srvTextDraws()
    elseif profile then
        print(('[HUD] server: %s - no textdraw overrides for it, leaving the server HUD alone')
            :format(profile.name))
    end
end

--[[
    CLAIMS ARE EXPLICITLY DECLINED. rp.setup wires itself into akacross.claims
    and takes the `rp.stats` claim when it is given a script name, so that one
    mod does the asking and the rest parse the reply. This script never sends
    /stats and never reads a stats line - it wants the server NAME and nothing
    else - so it opts out rather than competing for a claim it would then sit
    on while a mod that needs it goes without.
]]
if rpM and rpM.setup then
    rpM.setup{script = scriptName, claims = false, log = function(msg) print('[HUD] ' .. tostring(msg)) end}
end

if rpM and rpM.onProfile then
    rpM.onProfile(adoptProfile)
end

-- Handle TextDraws
--[[
    THE OWNER LABEL IS MATCHED BY ITS TEXT, THE NAME BY ITS LETTER SIZE.

    They used to share one letter-size gate, with the text only choosing
    between them. That is wrong on Horizon, where the owner label is drawn at
    letter size 0 / 0 (capture id 6) and so never reached the text test at all.

    "TURF OWNER:" is a distinctive enough string to match on alone, and doing
    so is correct on both servers - Paraiso's owner draw carries that text too.
]]
local function handleTurfTextDraw(id, data)
    local s, cfg = srv(), srvCfg()
    if not s then return false, data end
    local sig = s.sig

    if data.text ~= sig.turfOwner then
        if tostring(data.letterWidth) ~= sig.turfW or tostring(data.letterHeight) ~= sig.turfH then
            return false, data
        end
        setGxtEntry("turfText", s.turfText(data.text))
        if cfg.turf.enabled then
            data.position.x = cfg.turf.x
            data.position.y = cfg.turf.y
        else
            data.position.x = -100
            data.position.y = -100
        end
        return true, {id, data}
    end

    if cfg.turfOwner.enabled then
        data.position.x = cfg.turfOwner.x
        data.position.y = cfg.turfOwner.y
    else
        data.position.x = -100
        data.position.y = -100
    end
    lua_thread.create(function()
        wait(1)
        sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, cfg.turfOwner.color)
    end)
    return true, {id, data}
end

local function handleWristwatchTextDraw(id, data)
    local s, cfg = srv(), srvCfg()
    if not s then return false, data end
    local sig = s.sig
    if tostring(data.letterWidth) ~= sig.wwW or tostring(data.letterHeight) ~= sig.wwH
       or not data.text:match("%W") then
        return false, data
    end

    setGxtEntry("wwText", data.text)
    if cfg.wristwatch.enabled then
        data.position.x = cfg.wristwatch.x
        data.position.y = cfg.wristwatch.y
    else
        data.position.x = -100
        data.position.y = -100
    end
    lua_thread.create(function()
        wait(1)
        sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, cfg.wristwatch.color)
    end)
    return true, {id, data}
end

local function handleLogoTextDraw(id, data)
    local s, cfg = srv(), srvCfg()
    if not s then return false, data end
    local sig = s.sig
    if tostring(data.letterWidth) ~= sig.logoW or tostring(data.letterHeight) ~= sig.logoH then
        return false, data
    end

    if cfg.logo.enabled then
        data.text = cfg.logo.custom and cfg.logo.text or data.text
        data.position.x = cfg.logo.x
        data.position.y = cfg.logo.y
    else
        data.position.x = -100
        data.position.y = -100
    end
    lua_thread.create(function()
        wait(1)
        sampTextdrawSetLetterSizeAndColor(id, data.letterWidth, data.letterHeight, cfg.logo.color)
    end)
    return true, {id, data}
end

-- The real pool: 2048 server textdraws plus 256 player textdraws. The two
-- sweeps here ran to 4000 and 3000, which is 42% and 23% of every pass spent
-- on slots that cannot exist.
local TD_MAX = (textdrawM and textdrawM.MAX_ID) or 2303

--[[
    The HP bar: three draws stacked on each other, matched by POSITION rather
    than letter size, and at the same two positions on both servers - so unlike
    everything above, this is not per server.

    The server's own string is stashed on the way out, because blanking a
    textdraw is not reversible from the client: there is nothing to read it
    back from once it has been overwritten.
]]
local srvHpBarText = {'', '', ''}



local function handleHPBarTextDraw(id, data)
    local s, cfg = srv(), srvCfg()
    if not s then return false, data end

    -- The RPC carries the pre-placement positions, which on Paraiso are not
    -- the ones the pool sweep sees after the server has laid the bar out.
    local bar = s.hpBarShow(id, data.position.x, data.position.y)
    if not bar then return false, data end

    if cfg.hpBar.enabled then
        if srvHpBarText[bar] ~= '' then data.text = srvHpBarText[bar] end
    else
        srvHpBarText[bar] = data.text
        data.text = ''
    end
    local color = cfg.hpBar['color' .. bar]
    -- The box width the three bars are drawn at. Only the first differs.
    local boxWidth = bar == 1 and 543.75 or 545.75
    lua_thread.create(function()
        wait(1)
        sampTextdrawSetBoxColorAndSize(id, 1, color, boxWidth, 0)
    end)
    return true, {id, data}
end

local function handleHPAndArmorTextDraw(id, data)
    local s, cfg = srv(), srvCfg()
    if not s then return false, data end
    local role = s.hpArmorRole(data.position.x, data.position.y)
    if not role then return false, data end

    if not cfg[role].enabled then
        data.text = ''
    end
    return true, {id, data}
end

-- OnShowTextDraw
-- Built once. This table was rebuilt on every ShowTextDraw RPC, and a server
-- sends a burst of them on every spawn and every interior change.
local TEXTDRAW_HANDLERS = {
    handleTurfTextDraw,
    handleWristwatchTextDraw,
    handleLogoTextDraw,
    handleHPBarTextDraw,
    handleHPAndArmorTextDraw
}

function sampev.onShowTextDraw(id, data)
    -- The server is drawing something new, so the remembered slots may be
    -- stale: the next re-apply sweeps instead of trusting them.
    srvInvalidateSlots()

    for i = 1, #TEXTDRAW_HANDLERS do
        local handled, result = TEXTDRAW_HANDLERS[i](id, data)
        if handled then
            return result
        end
    end
end

-- OnTextDrawSetString
function sampev.onTextDrawSetString(id, text)
    local s, cfg = srv(), srvCfg()
    if not s then return end
    local sig = s.sig

    local posX, posY = sampTextdrawGetPos(id)
    local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(id)
    local letW, letH = tostring(letSizeX), tostring(letSizeY)

    if letW == sig.turfW and letH == sig.turfH and text ~= sig.turfOwner then
        setGxtEntry("turfText", s.turfText(text))
        hud.elements.turf.text.color = color
    end

    if letW == sig.wwW and letH == sig.wwH and text:match("%W") then
        setGxtEntry("wwText", text)
    end

    if letW == sig.textW and letH == sig.textH then
        local role = s.hpArmorRole(posX, posY)
        if role then
            if not cfg[role].enabled then text = '' end
            return {id, text}
        end
    end
end

-- OnScriptTerminate
function onScriptTerminate(scr, quitGame)
    if scr ~= thisScriptRef then return end
    -- Close the exit gate FIRST: everything below can yield or fault, and the
    -- renderer must not still be drawing into a device that is being released
    -- while it does. See the note on `terminating` at the top.
    terminating = true
    -- The window's placement is normally recorded when it closes; a terminate
    -- with it still open never fires that edge. Through a function rather than
    -- the vector, because the vector is a local of the menu section BELOW this
    -- one and would resolve here as a nil global.
    pcall(saveMenuPlacement)
    if settings.autosave then
        pcall(Config.saveHud)
    end
    pcall(Config.saveSettings)
end

-- =========================================================================
-- The settings window
-- =========================================================================
--[[
    WHAT THIS SECTION IS NOW, AND WHAT IT REPLACES.

    It used to be ~1200 lines: a 460x76 strip of ten hand-placed buttons, a
    85x392 column of five square icon buttons, a fixed 376x289 body and a
    376x36 footer - every one of those a literal pixel offset handed to
    SetCursorPos - plus a SECOND top-level window whose entire job was to ask
    "are you sure?".

    Every other mod in this set (driving, wanted, vstorage, fastmap) draws a
    titled window with a horizontal tab bar over a MEASURED body and a footer,
    themed by akacross.style, registered with akacross.window, with its prompts
    as modal popups inside the window that raised them. This is that, so the
    six mods are one family rather than five and an exception.

    The tabs themselves live in lib/hud/settings.lua and lib/hud/files.lua.
    What stays here is the wiring, because only the entry can see all of it:
    the config tables, the fonts, the renderer, the anchors and the updater.
]]

--[[
    Forward-declared: both are created further down, but OnInitialize's callback
    closes over them here and only runs once the renderer is up, by which point
    they exist.

    Without the declaration a local defined LATER in the chunk is not visible to
    a closure written EARLIER - Lua resolves the name as a global instead, and
    the attach would silently be handed nil.
]]
local settingsFrame
local windows

--[[
    ONE LIST, and every glyph the menu draws has to be on it.

    The atlas bakes exactly the codepoints named here. ImGui draws its fallback
    character for anything else, which is what puts a '?' where an icon was
    meant to be - so adding an icon to a tab means adding its name here too.
]]
local MENU_ICONS = {
    -- window and tabs
    "GEAR", "LIST", "MAP_PIN", "DISPLAY", "SERVER", "FOLDER_OPEN",
    "KEYBOARD", "SLIDERS",
    -- element list
    "HEART", "SHIELD", "PERSON_RUNNING", "CAR", "MASK_SNORKEL", "GUN",
    -- header card and footer
    "CIRCLE_CHECK", "CIRCLE_XMARK", "FLOPPY_DISK", "ARROW_ROTATE_LEFT", "XMARK",
}

local function icon(name)
    return (fa and fa[name]) or '?'
end

--[[
    akacross.scale and akacross.window both read this global; every other mod in
    the set publishes it the same way.

    Defaulted rather than trusted, as autofps does with its own resolution
    read: the native can come back nil - it does under the host test suite, and
    it can in game if this is reached before the device is up - and every
    window position below is arithmetic on it.
]]
local sx, sy = getScreenResolution()
sx = tonumber(sx) or 1280
sy = tonumber(sy) or 720
screenRes = imgui.ImVec2(sx, sy)

-- ---------------------------------------------------------------------------
-- Keybinds
-- ---------------------------------------------------------------------------
--[[
    The menu had NO keybind - only /hud - which made it the one mod here you
    could not open without typing. Two binds, the same shape every other mod
    uses (autobind's, which akacross.keybinds is written against).

    Registered with the config layer further down, in its own set: the binds
    carry cdata and `settings` is a plain-Lua table walked by applyDefaults and
    deepCopy, which would copy a cdata object by REFERENCE and leave the
    defaults and the live value sharing one.
]]
Keybinds = {
    Menu = {Toggle = new.bool(true), Keys = {VK_MENU, VK_J}, Types = {'KeyDown', 'KeyPressed'}},
    Toggle = {Toggle = new.bool(false), Keys = {}, Types = {}},
}

-- Captured here, before any config machinery has touched the table: the clear
-- hook empties these lists before cjc snapshots them, so cjc's own "default"
-- for a bind is no keys at all. See akacross.keybinds for the full account.
local KEYBIND_DEFAULTS = keybindsM.captureDefaults(Keybinds)
local function restoreDefaultKeybinds()
    keybindsM.restoreDefaults(Keybinds, KEYBIND_DEFAULTS)
end

local KEYBIND_ROWS = {
    {key = 'Menu', label = 'Open Settings', trigger = 'KeyPressed',
     desc = 'Shows or hides this window. Defaults to ALT + J.'},
    {key = 'Toggle', label = 'Toggle HUD', trigger = 'KeyPressed',
     desc = 'Switches the whole HUD on and off. Unbound by default.'},
}

-- ---------------------------------------------------------------------------
-- UI scale
-- ---------------------------------------------------------------------------
--[[
    WHY THIS MOD SCALES ITS MENU WITH FontGlobalScale AND THE OTHERS RE-BAKE.

    driving, wanted, vstorage and fastmap all rebuild the font atlas when the
    UI scale changes: Fonts:Clear(), re-add every face at the new pixel size,
    CreateFontsTexture. Baking at the exact size is sharper than stretching
    one, so where it is available it is the right answer.

    It is not available here. akacross.draw_imgui owns this state's atlas and
    it is APPEND-ONLY by construction (lib/akacross/draw_imgui.lua:48):
    Fonts:Clear() would destroy the faces it has baked for every text element
    on screen, and it has no way to learn that happened. So the menu scales the
    bake it has.

    That costs nothing on the HUD itself, and the reason is worth stating
    because it is not obvious: FontGlobalScale is applied by ImGui's widget
    layer, and draw_imgui draws through ImDrawList::AddText with an EXPLICIT
    font pointer and size (draw_imgui.lua:823). An explicit size is not scaled.
    So this moves the menu and leaves the HUD exactly where the user put it -
    which is also why the Interface tab offers one scale rather than the two
    the overlay mods need.
]]
local uiScale = new.float[1](1.0)
local fontBakedFactor = 1.0
uiScaleDirty = false

local function commitUIScale()
    settings.uiScale = uiScale[0]
    scaleM.recompute(uiScale[0])
    -- Every metric in the shared theme is in scaled pixels, so it has to be
    -- re-applied rather than merely re-read.
    pcall(styleM.apply)
    imgui.GetIO().FontGlobalScale = scaleM.get() / fontBakedFactor
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    -- Seed from the config, then fold in the OS DPI, THEN record what the
    -- atlas is about to bake at. Order matters: the glyph size below reads the
    -- factor AFTER the DPI fold, so recording fontBakedFactor first would
    -- apply DPI twice - once in the baked pixel size and again in
    -- FontGlobalScale.
    uiScale[0] = tonumber(settings.uiScale) or 1.0
    scaleM.recompute(uiScale[0])
    local okDpi, d = pcall(function() return imgui.GetDpiScale() end)
    scaleM.setDpi(okDpi and d or 1.0)
    fontBakedFactor = scaleM.get()
    -- Explicit, not inherited: mimgui's own init sets FontGlobalScale to the
    -- DPI scale under scaling modes 1 and 2, and leaving that in place is what
    -- makes a double-apply possible.
    imgui.GetIO().FontGlobalScale = 1.0

    -- The glyphs are BAKED at this size, which is why it is resolved once from
    -- the scale at startup rather than following the slider: re-baking would
    -- mean clearing an atlas this state does not own. scaleM.font applies a
    -- readability floor the raw factor does not.
    loadFontAwesome6Icons(MENU_ICONS, scaleM.font(14))

    styleM.apply()

    --[[
        The cursor.

        The window previously left mimgui to decide on its own, per Lua state,
        which is exactly the situation akacross.cursor exists for: it is the
        single refcounted owner shared with autobind, autologin and reports,
        and it re-derives the answer from the live consumer set every frame
        rather than tracking edges, so two scripts running it cannot strand
        each other.

        `input` here means "ImGui should receive input" (it drives
        imgui.DisableInput), NOT that the game is blocked - and `lock = false`
        keeps the player free to move, which is the behaviour this script had.

        OPTIONAL, and the fallback is the pre-module behaviour verbatim.
    ]]
    if cursorM and cursorM.setup then
        cursorM.setup({
            guards = {spawned = false, playing = false},
            log = function(msg) print(msg) end
        })
        cursorM.attach(settingsFrame)
        windows:attachCursor(cursorM, scriptName)
    else
        settingsFrame.HideCursor = false
    end
end)

-- ---------------------------------------------------------------------------
-- Module wiring
-- ---------------------------------------------------------------------------
--[[
    Everything the tab modules need, handed over explicitly.

    NOT read out of _G by them, which is the rule the autobind
    de-globalization pass settled on for new modules - and here it is forced
    anyway, because `hud` and `settings` are locals of this chunk. Both tables
    are mutated in place by the config layer (applyDefaults overwrites fields,
    it never replaces the table), so passing the reference once is safe across
    a reload and a reset alike.
]]
local function enabledCount()
    local n = 0
    for key, cfg in pairs(hud.elements) do
        local spec = Spec.byKey[key]
        if spec then
            local parts = Spec.parts[spec.kind]
            for p = 1, #parts do
                local part = cfg[parts[p].name]
                if part and part.enabled then n = n + 1 end
            end
        end
    end
    return n
end

hudSettingsM.setup{
    Spec = Spec,
    hud = hud,
    settings = settings,
    drawM = drawM,
    icon = icon,
    uiScale = uiScale,
    createFont = function(element, part) return createFont(element, part) end,
    srvTextDraws = function(id) return srvTextDraws(id) end,
    -- Which server's rows the Server tab is editing, and the list to choose
    -- from. The tab defaults to the detected one and lets the user pick the
    -- other, so a layout can be set up before ever joining that server.
    servers = function() return SERVER_ORDER end,
    activeServer = function() return srvKnown and srvId or nil end,
    displayHud = function(on) return displayHud(on) end,
    toggleAnchorMove = function(anchor) return toggleAnchorMove(anchor) end,
    isAnchorMoving = function(anchor) return isAnchorMoving(anchor) end,
    pendingRenderer = function() return pendingRenderer end,
    setPendingRenderer = function(name) pendingRenderer = name end,
    activeRenderer = function() return drawM.backend and drawM.backend() or settings.renderer end,
    enabledCount = enabledCount,
    onScaleChanged = function() uiScaleDirty = true end,
}

hudFilesM.setup{
    settings = settings,
    configsDir = configsDir,
    scanConfigs = function() scanGameFolder(getPath("configs"), configsDir) end,
    matchConfigFiles = function(f) return matchConfigFiles(f) end,
    checkForUpdate = function() return checkForUpdate() end,
    updateScript = function() return updateScript() end,
    -- `fromCurrent` rather than a table: the two callers want "these settings"
    -- and "the shipped defaults", and handing the defaults table out is how it
    -- previously acquired cjc's __call metamethod.
    saveHudAs = function(file, fromCurrent)
        Config.saveHudAs(file, fromCurrent and hud or hud_defaultSettings)
    end,
    openConfig = function(name)
        settings.JsonFile = name
        Config.loadHud()
        initializeHud()
        hudSettingsM.resetSelection()
    end,
    renameConfig = function(name)
        local dir = getPath("configs")
        os.rename(dir .. settings.JsonFile, dir .. name)
        settings.JsonFile = name
    end,
    deleteConfig = function()
        os.remove(getPath("configs") .. settings.JsonFile)
        settings.JsonFile = settings_defaultSettings.JsonFile
        Config.loadHud()
        initializeHud()
        hudSettingsM.resetSelection()
    end,
}

-- ---------------------------------------------------------------------------
-- The tab bar
-- ---------------------------------------------------------------------------
--[[
    A table rather than seven copies of the BeginTabItem / BeginChild /
    EndChild / EndTabItem dance, so the draw callback is a loop and adding a
    tab is one entry. Same shape reports and wanted use.

    `pad = false` means the tab draws its own children and must not be wrapped
    in one - the Elements tab is a two-pane split and a wrapping child would
    give it a scrollbar of its own inside the body's.
]]
local TABS = {
    {id = 'elem',  label = 'Elements',  icon = 'LIST',        draw = hudSettingsM.renderElements, split = true},
    {id = 'anch',  label = 'Anchors',   icon = 'MAP_PIN',     draw = hudSettingsM.renderAnchors},
    {id = 'rend',  label = 'Renderer',  icon = 'DISPLAY',     draw = hudSettingsM.renderRenderer},
    {id = 'srv',   label = 'Server',    icon = 'SERVER',      draw = hudSettingsM.renderServer},
    {id = 'files', label = 'Files',     icon = 'FOLDER_OPEN', draw = hudFilesM.renderFiles},
    {id = 'keys',  label = 'Keybinds',  icon = 'KEYBOARD',
     draw = function() keybindsM.render(Keybinds, KEYBIND_ROWS) end},
    {id = 'iface', label = 'Interface', icon = 'SLIDERS',     draw = hudSettingsM.renderInterface},
}

-- Built once. Under the old strip these were concatenated per button per
-- frame.
for i = 1, #TABS do
    TABS[i].caption = ('%s %s'):format(icon(TABS[i].icon), TABS[i].label)
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local SETTINGS_DESIGN = {w = 760, h = 600}
local MENU_TITLE = ('%s %s Settings%s###hudSettings'):format(
    icon('GEAR'), scriptName:upperFirst(),
    (scriptVersion and scriptVersion ~= '') and (' - v' .. scriptVersion) or '')

--[[
    The title carries a ### id, so the version can be in it without ImGui
    treating each new title as a different window and forgetting where the user
    put it.
]]

-- Built once. Under the old side bar these were five square icon buttons with
-- no captions at all, and the tooltip was the only thing that said what they
-- did.
local FOOTER_SAVE   = ('%s Save'):format(icon('FLOPPY_DISK'))
local FOOTER_RELOAD = ('%s Reload'):format(icon('ARROW_ROTATE_LEFT'))
local FOOTER_RESET  = 'Reset to defaults'
local FOOTER_CLOSE  = ('%s Close'):format(icon('XMARK'))

local settingsBody = imgui.ImVec2(0, 0)

--- Height for a tab body: measured, never guessed. GetContentRegionAvail is
--- already past the title and tab bar inside a tab item, so the only thing to
--- reserve is one button row plus the padding under it.
local function bodySize()
    local avail = imgui.GetContentRegionAvail()
    local st = imgui.GetStyle()
    local footer = imgui.GetFrameHeightWithSpacing() + st.ItemSpacing.y + st.WindowPadding.y
    settingsBody.x = 0
    settingsBody.y = math.max(avail.y - footer, scaleM.i(120))
    return settingsBody
end

local mousePos = imgui.ImVec2(0, 0)
windows = windowM.new{screenRes = screenRes, mousePos = mousePos}

-- Window placement lives in settings.json rather than the HUD config, because
-- it is a preference about this window and must survive switching which HUD
-- configuration is being edited.
local settingsPos = imgui.ImVec2(sx / 2, sy / 2)

--[[
    Record where the user left the window. A global function because
    onScriptTerminate is defined several hundred lines above this section and
    cannot see the vector itself.

    `force` is what the close hook passes. Without it this is a no-op while the
    window has never been opened, so a session that never touched the menu
    leaves the -1 sentinel alone rather than baking in the centre of whatever
    resolution happened to be current - which would then be a stale absolute
    position the next time the display changed.
]]
function saveMenuPlacement(force)
    if not (force or menu.settings[0]) then return end
    settings.windowX, settings.windowY = settingsPos.x, settingsPos.y
end

local drawFails = 0

windows:add(MENU_TITLE, {
    open = menu.settings,
    pos = settingsPos,
    pivot = imgui.ImVec2(0.5, 0.5),
    size = imgui.ImVec2(SETTINGS_DESIGN.w, SETTINGS_DESIGN.h),
    flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
        + imgui.WindowFlags.NoSavedSettings,
    borderSize = new.float(1),
    dragging = new.bool(true),
    titlebarHeight = new.int(30),
    overlay = new.bool(false),
    allowCursor = new.bool(true),
    --[[
        Closing the window is where the placement is recorded and the prompts
        are dropped.

        The registry fires this on the EDGE of visibility, which matters here:
        the window can be closed from four places - the chat command, the
        keybind, the footer's Close and ImGui's own titlebar X - and the last
        of those used to slip past every cleanup path there was.
    ]]
    onClose = function()
        saveMenuPlacement(true)
        -- Everything except a pending update: that one is raised by the
        -- background version check rather than by a click, so closing the
        -- window is not an answer to it and dropping it would lose the notice
        -- entirely. The old confirmation window carried the same exception.
        hudFilesM.reset('update')
        keybindsM.cancel()
    end,
    sizer = function(size)
        size.x = scaleM.i(SETTINGS_DESIGN.w)
        size.y = scaleM.i(SETTINGS_DESIGN.h)
        scaleM.clampToScreen(size, 0.92)
    end,
    draw = function()
        --[[
            Guarded, and the guard is inside Begin/End rather than around it.
            An error thrown mid-body must not skip the EndTabBar / EndChild
            that balance it - so the pcall wraps the body and each Begin has
            its End on the outside of it.

            Bounded reporting: a draw that faults faults every frame, and three
            lines is enough to find it in moonloader.log without the log
            becoming the problem.
        ]]
        local ok, err = pcall(function()
            hudSettingsM.renderHeader()

            if imgui.BeginTabBar('##hudTabs') then
                for i = 1, #TABS do
                    local tab = TABS[i]
                    if imgui.BeginTabItem(tab.caption) then
                        --[[
                            The Elements tab draws its own two children and is
                            given the height directly instead of a wrapping
                            child: nesting it would put a scrollbar inside a
                            scrollbar, and the left-hand list would scroll away
                            from the pane it selects.
                        ]]
                        if tab.split then
                            tab.draw(bodySize())
                        else
                            if imgui.BeginChild('##hudBody_' .. tab.id, bodySize(), false) then
                                tab.draw()
                            end
                            imgui.EndChild()
                        end
                        imgui.EndTabItem()
                    end
                end
                imgui.EndTabBar()
            end
        end)
        if not ok then
            drawFails = drawFails + 1
            if drawFails <= 3 then
                print(('[HUD] settings window error: %s'):format(tostring(err)))
            end
        end

        -- Footer outside every child, so it cannot be scrolled away from.
        imgui.Separator()
        if imgui.Button(FOOTER_SAVE) then
            Config.saveHud()
            Config.saveSettings()
            formattedAddChatMessage('Settings saved.', -1)
        end
        hudWidgetsM.tooltip('Write the HUD configuration and the settings file.')

        imgui.SameLine()
        if imgui.Button(FOOTER_RELOAD) then
            Config.loadHud()
            initializeHud()
            hudSettingsM.resetSelection()
            formattedAddChatMessage('Configuration reloaded.', -1)
        end
        hudWidgetsM.tooltip('Re-read the configuration file, discarding unsaved changes.')

        imgui.SameLine()
        if imgui.Button(FOOTER_RESET) then
            Config.resetHud()
            initializeHud()
            -- cjc cannot reset the binds: the clear hook emptied them before
            -- it captured its defaults, so its "default" is no keys at all.
            -- Reset would otherwise be a way to permanently unbind everything.
            restoreDefaultKeybinds()
            keybindsM.cancel()   -- an armed rebind now points at a stale chord
            hudSettingsM.resetSelection()
            hudSettingsM.resync()
            formattedAddChatMessage('Configuration reset to defaults.', -1)
        end
        hudWidgetsM.tooltip('Restore the shipped defaults. This does not save.')

        imgui.SameLine()
        if imgui.Button(FOOTER_CLOSE) then menu.settings[0] = false end

        --[[
            The prompts, LAST and INSIDE this window.

            OpenPopup and BeginPopupModal are scoped to the window they are
            called from; a popup opened outside the window it belongs to never
            appears. This is what replaced the second top-level window the
            confirmations used to have - which could end up behind its parent,
            needed its own cursor consumer, and outlived the window that raised
            it (`if not menu.settings[0] ... resetConfirmData()` existed to
            clean up after exactly that).
        ]]
        hudFilesM.renderModal()
    end,
})

windows:buildSizes()
scaleM.onRebuild(function() windows:buildSizes() end)

--[[
    Seed the window from settings.json.

    Called from main() rather than run here, because this whole section is
    LOAD-time code and the config has not been read yet - Config.loadSettings()
    is the first thing main() does. Everything above therefore starts at its
    default and this is what corrects it.
]]
function applyMenuSettings()
    uiScale[0] = tonumber(settings.uiScale) or 1.0
    hudSettingsM.resync()

    local x, y = tonumber(settings.windowX), tonumber(settings.windowY)
    if x and y and x >= 0 and y >= 0 then
        settingsPos.x, settingsPos.y = x, y
    end
    -- Reclamps as well as re-sizes, so a position saved at a larger resolution
    -- comes back on screen instead of stranding the titlebar off the edge.
    windows:buildSizes()

    --[[
        The keybind repair, and why "all of them" is the discriminator.

        One empty bind is a user who hit Clear in the Keybinds tab and must
        stay cleared. ALL of them empty is not something anyone does by hand -
        it is what an early keybinds.json written before the clear hook was
        fixed looks like - and even a user who did it by hand gets one restore
        and can clear them again. A dead menu key with no way to notice why is
        the worse failure by a distance.
    ]]
    if keybindsM.noneBound(Keybinds) then
        restoreDefaultKeybinds()
        Config.saveKeybinds()   -- so the repair survives even a crash-unload
        print('[HUD] every keybind was empty; restored the defaults')
    end
end

--[[
    THREE arguments: imgui.OnFrame(cond, beforeFrame, draw).

    The scale commit MUST go in the before-frame hook, which runs on the render
    thread BEFORE NewFrame. Doing style work from the draw callback edits state
    the frame ImGui is already building is reading.
]]
--[[
    The registry's cursor consumers are attached from OnInitialize below, not
    here.

    Two reasons. cursorM.setup() configures the guards and it runs there, so
    registering first would briefly install consumers against the default
    guard set. And register() is what starts akacross.cursor's worker thread,
    which needs lua_thread - a MoonLoader native that does not exist at all
    when the host test suite loads this chunk.
]]
settingsFrame = imgui.OnFrame(
    function() return not terminating and menu.settings[0] end,
    function()
        if uiScaleDirty then
            uiScaleDirty = false
            commitUIScale()
        end
        hudFilesM.scanIfDue()
    end,
    function(player)
        -- Do NOT touch player.HideCursor here: attach() above hands the field
        -- to akacross.cursor, which rewrites it every update from the live
        -- consumer set. Setting it in the render callback overwrites that
        -- decision every frame.
        mousePos.x, mousePos.y = getCursorPos()
        windows:render()
    end)


-- ---------------------------------------------------------------------------
-- Keybind polling
-- ---------------------------------------------------------------------------
local keyFunctions = {
    Menu = function()
        menu.settings[0] = not menu.settings[0]
    end,
    Toggle = function()
        hud.toggle = not hud.toggle
        formattedAddChatMessage(('HUD: %s'):format(hud.toggle and 'on' or 'off'), -1)
    end,
}

-- Longest chord first, so ALT + J cannot be shadowed by a bare-J bind.
local bindOrder = {}
for name in pairs(Keybinds) do bindOrder[#bindOrder + 1] = name end
table.sort(bindOrder, function(a, b) return #Keybinds[a].Keys > #Keybinds[b].Keys end)

local BIND_DEBOUNCE = 0.1
local lastFired = {}

function pollKeybinds()
    -- A rebind in progress must not also fire the bind being rebound.
    if keybindsM.isCapturing() then return end
    -- All five guards: typing in chat, a dialog, the scoreboard, the SAMPFUNCS
    -- console and the pause menu all mean the keypress belongs to something
    -- else.
    if not checkChatDialogScoreboardConsolePause(true, true, true, true, true) then
        return
    end
    local now = os.clock()
    for i = 1, #bindOrder do
        local name = bindOrder[i]
        local bind = Keybinds[name]
        if bind.Toggle[0] and #bind.Keys > 0 and #bind.Types > 0 and keycheck(bind) then
            if not lastFired[name] or (now - lastFired[name]) >= BIND_DEBOUNCE then
                local ok, err = pcall(keyFunctions[name])
                if not ok then
                    print(('[HUD] bind %s error: %s'):format(name, tostring(err)))
                end
                lastFired[name] = now
            end
        end
    end
end

--[[
    FONTS, ONE PER TEXT PART.

    Keyed by "<element>.<part>" rather than a pair of integers, which is the
    same change the config made: `fontSlots['weapon.name']` says what it holds
    and `fontSlots[6][2]` did not.

    Each record carries the handle, its line height, and the last value it was
    measured at - so a value that has not changed is not re-measured, and a
    font that HAS changed forgets the measurement it took in the old face.
]]
local fontSlots = {}

local function fontKey(element, part) return element .. '.' .. part end

local function fontRecord(key)
    local rec = fontSlots[key]
    if not rec then
        rec = {font = nil, spec = nil, gen = -1, height = 0, value = nil, text = '', width = 0}
        fontSlots[key] = rec
    end
    return rec
end

--[[
    (Re)build one part's font.

    render.swap acquires the new spec before releasing the old, so an edit that
    changes nothing costs nothing - which matters because the settings menu
    calls this from a text box on every keystroke and from the size buttons on
    every repeat.
]]
function createFont(element, part)
    local cfg = hud.elements[element]
    local partCfg = cfg and cfg[part]
    if not partCfg or not partCfg.font then return nil end
    if not renderM then return nil end

    local flags = renderM.flags(partCfg.flags)
    local spec = partCfg.font .. '\0' .. tostring(partCfg.size) .. '\0' .. flags

    local rec = fontRecord(fontKey(element, part))
    --[[
        The GENERATION as well as the spec. A handle can stop being what it was
        without the config changing a character: the ImGui renderer bakes its
        faces into an atlas a frame or two after they are asked for, and until
        that lands the face has no glyphs, measures zero and has no height. The
        generation is how the drawing layer says "what you are holding changed".
    ]]
    local gen = drawM.generation()
    if rec.font and rec.spec == spec and rec.gen == gen then return rec.font end

    rec.font = drawM.swapFont(rec.font, partCfg.font, partCfg.size, flags)
    rec.spec = rec.font and spec or nil
    rec.gen = gen
    rec.height = drawM.height(rec.font)
    -- The width was measured in the OLD face and the value has not changed, so
    -- nothing else would ever invalidate it.
    rec.value, rec.text, rec.width = nil, '', 0
    return rec.font
end

--- Every text part every element declares. Safe to call repeatedly: createFont
--- only allocates when a spec actually changed.
function loadFonts()
    local list = Spec.list
    for i = 1, #list do
        local spec = list[i]
        local parts = Spec.parts[spec.kind]
        for p = 1, #parts do
            if parts[p].text then createFont(spec.key, parts[p].name) end
        end
    end
end

--[[
    metrics(element, part, value) -> text, width, height, alignOffset

    `value` is whatever the HUD holds - health is a NUMBER, the weapon name is
    a string - so the string form is derived here and cached with the width it
    was measured at. Alignment is read live, because the menu changes it
    without touching the font.
]]
local function fontMetrics(element, part, value)
    local rec = fontSlots[fontKey(element, part)]
    if not rec or not rec.font then return '', 0, 0, 0 end

    if rec.value ~= value then
        rec.value = value
        rec.text = type(value) == 'string' and value or tostring(value)
        -- The RAW string: drawM.measure strips the inline {RRGGBB} tags with
        -- whatever the active backend actually does with them, so the width can
        -- never describe a different string from the one being drawn.
        rec.width = drawM.measure(rec.font, rec.text)
    end

    local partCfg = hud.elements[element][part]
    local factor = renderM.ALIGN[partCfg.align] or 0
    return rec.text, rec.width, rec.height, rec.width * factor
end

function renderFont(x, y, element, part, value, color)
    local rec = fontSlots[fontKey(element, part)]
    if not rec or not rec.font then return end
    local text, _, _, offset = fontMetrics(element, part, value)
    drawM.text(rec.font, text, x - offset, y, color)
end

function loadTextures()
    assets.weapTextures = assets.weapTextures or {}
    for i = 0, 48 do
        local filepath = string.format("%s%d.png", getPath("icons"), i)
        if doesFileExist(filepath) and not assets.weapTextures[i] then
            assets.weapTextures[i] = drawM.loadTexture(filepath)
        end
    end
end

--[[
    /hud render - what is drawing, and what it made of the configuration.

    The full detail goes to moonloader.log and a summary to chat, because the
    interesting part is thirteen font slots and chat is four lines deep. Written
    after two failures that were both invisible: a switch that faulted with
    nothing logged, and a font index that came up empty so every string drew
    nothing while every layer reported success.

    The per-slot lines are the ones that would have shortened the second: a slot
    with NO FONT is a part that cannot draw, and it says so next to the family
    it was asked for.
]]
function renderReport()
    local lines = drawM.report()

    local missing, total = 0, 0
    local list = Spec.list
    for i = 1, #list do
        local spec = list[i]
        local parts = Spec.parts[spec.kind]
        for p = 1, #parts do
            if parts[p].text then
                total = total + 1
                local cfg = hud.elements[spec.key]
                local partCfg = cfg and cfg[parts[p].name]
                local rec = fontSlots[fontKey(spec.key, parts[p].name)]
                local has = rec and rec.font ~= nil
                if not has then missing = missing + 1 end
                lines[#lines + 1] = ('  %-14s %-6s %-12s %2spx  %s'):format(
                    spec.key, parts[p].name,
                    partCfg and tostring(partCfg.font) or '?',
                    partCfg and tostring(partCfg.size) or '?',
                    has and ('h=' .. tostring(rec.height)) or 'NO FONT')
            end
        end
    end

    --[[
        THE SAME STRING, MEASURED BY BOTH RENDERERS.

        "the fonts are way off" is not a thing anyone can act on, and squinting
        at two screenshots is not measurement. Every distinct face the config
        asks for is built with BOTH the native D3D font layer and whatever is
        drawing, and the same reference string measured through each.

        A width that matches and a look that does not is a rasteriser
        difference - stb_truetype does not hint where GDI does, and no setting
        here changes that. A width that does NOT match is a size mapping or a
        different typeface, and both of those are fixable.
    ]]
    local SAMPLE = 'ABCabc0123'
    local seen = {}
    lines[#lines + 1] = ('metrics for %q:'):format(SAMPLE)
    for i = 1, #list do
        local spec = list[i]
        local parts = Spec.parts[spec.kind]
        for p = 1, #parts do
            if parts[p].text then
                local cfg = hud.elements[spec.key]
                local partCfg = cfg and cfg[parts[p].name]
                if partCfg and partCfg.font then
                    local flags = renderM.flags(partCfg.flags)
                    local key = partCfg.font .. '\0' .. tostring(partCfg.size) .. '\0' .. flags
                    if not seen[key] then
                        seen[key] = true

                        -- What is drawing now.
                        local live = drawM.acquireFont(partCfg.font, partCfg.size, flags)
                        local liveW = live and drawM.measure(live, SAMPLE) or 0
                        local liveH = live and drawM.height(live) or 0
                        if live then drawM.releaseFont(live) end

                        -- The native layer, whether or not it is the one drawing.
                        local nat = renderM.acquire(partCfg.font, partCfg.size, flags)
                        local natW = nat and renderM.measure(nat, renderM.plain(SAMPLE)) or 0
                        local natH = nat and renderM.height(nat) or 0
                        if nat then renderM.release(nat) end

                        local drift = (natW > 0) and (liveW / natW) or 0
                        lines[#lines + 1] = ('  %-12s %2spx flags %-2d  %s %5.1fx%-5.1f  native %5.1fx%-5.1f  %s')
                            :format(tostring(partCfg.font), tostring(partCfg.size), flags,
                                    drawM.backend(), liveW, liveH, natW, natH,
                                    drift > 0 and ('%.0f%% wide'):format(drift * 100) or 'no native font')
                    end
                end
            end
        end
    end

    print('---- hud render report ----')
    for i = 1, #lines do print(lines[i]) end
    print('---------------------------')

    formattedAddChatMessage(('renderer: %s   rounding: %s')
        :format(drawM.backend(), tostring(hud.rounding or 0)), -1)
    if missing > 0 then
        formattedAddChatMessage(('%d of %d text parts have NO FONT - see moonloader.log')
            :format(missing, total), -1)
    else
        formattedAddChatMessage(('all %d text parts have a font; detail in moonloader.log')
            :format(total), -1)
    end
end

--[[
    THE TEXTDRAW DUMP - `/hud td [filter]`.

    WHY THIS EXISTS. The overrides below match the server's draws by their
    letter size and position, compared as PRINTED STRINGS. Those values cannot
    be guessed, read off a screenshot, or inferred from another server: they
    have to be captured from the server that sends them.

    That is not a hypothetical. The Horizon profile shipped in 1.4.39 was
    recovered from this file's own history, where it had sat untouched for a
    year - and it matched nothing, because nobody had re-derived it after
    Horizon changed its HUD. Paraiso's values were re-derived in 1.4.37 and
    work. The difference between the two is exactly this command.

    So: it prints every live textdraw in the form the SERVERS table wants, and
    it says how many the ACTIVE profile currently matches - which is the number
    that tells you whether a profile is real or wishful.

    The full dump goes to moonloader.log; the pool is up to 2304 slots and
    chat holds a few lines.
]]
function textdrawReport(filter)
    local s = srv()
    local profileName = 'none detected'
    if rpM and rpM.profile then
        local okP, prof = pcall(rpM.profile)
        if okP and prof then
            profileName = ('%s (%s)'):format(prof.name, prof.id)
        end
    end

    local lines = {}
    lines[#lines + 1] = ('server:  %s'):format(profileName)
    lines[#lines + 1] = ('profile: %s'):format(
        s and ('%s - overrides ACTIVE'):format(s.label) or 'no SERVERS entry - overrides inert')
    if filter then lines[#lines + 1] = ('filter:  %q'):format(filter) end
    lines[#lines + 1] = ''
    lines[#lines + 1] = ('%6s  %-34s  %-34s  %-10s  %s')
        :format('id', 'pos x / y', 'letter w / h', 'color', 'text')

    local shown, total, matched = 0, 0, 0
    local lower = filter and filter:lower() or nil

    for id = 0, TD_MAX do
        if sampTextdrawIsExists(id) then
            total = total + 1
            local okAll, posX, posY, letW, letH, color, text = pcall(function()
                local x, y = sampTextdrawGetPos(id)
                local w, h, c = sampTextdrawGetLetterSizeAndColor(id)
                return x, y, w, h, c, sampTextdrawGetString(id)
            end)
            if okAll then
                text = text or ''
                -- The single-line form, so a multi-line draw does not break
                -- the table. ~n~ is the server's newline token.
                local flat = text:gsub('~n~', ' | ')
                if not lower or flat:lower():find(lower, 1, true) then
                    shown = shown + 1
                    lines[#lines + 1] = ('%6d  %-34s  %-34s  %-10s  %s'):format(
                        id,
                        ('%s / %s'):format(tostring(posX), tostring(posY)),
                        ('%s / %s'):format(tostring(letW), tostring(letH)),
                        ('%08X'):format(color % 0x100000000),
                        flat)
                end
                -- Counted against the ACTIVE profile, unfiltered: this is the
                -- health check, not part of the listing.
                if s and srvSlotMatches(id) then matched = matched + 1 end
            end
        end
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = ('%d textdraw(s) live, %d listed, %d matched by the active profile')
        :format(total, shown, matched)
    if s and matched == 0 and total > 0 then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'NOTHING MATCHED. The signatures for this server are wrong or stale.'
        lines[#lines + 1] = 'Copy the rows above into the SERVERS table in hud.lua - the letter'
        lines[#lines + 1] = 'w / h column is what sig.* holds, as the exact strings printed here.'
    end

    print('---- hud textdraw dump ----')
    for i = 1, #lines do print(lines[i]) end
    print('---------------------------')

    formattedAddChatMessage(('%d textdraw(s) live, %d matched by %s - detail in moonloader.log')
        :format(total, matched, s and s.label or 'no profile'), -1)
end

--- Hand every texture back and forget them, so loadTextures() rebuilds.
local function releaseTextures()
    local textures = assets.weapTextures
    if not textures then return end
    for i = 0, 48 do
        if textures[i] then
            drawM.releaseTexture(textures[i])
            textures[i] = nil
        end
    end
    assets.weapTextures = nil
end

--- The same for the font slots. createFont() rebuilds each one on demand.
local function releaseFonts()
    for _, rec in pairs(fontSlots) do
        if rec.font then drawM.releaseFont(rec.font) end
        rec.font, rec.spec, rec.height = nil, nil, 0
        rec.value, rec.text, rec.width = nil, '', 0
    end
end

--[[
    Switch renderers.

    ORDER IS THE WHOLE FUNCTION. A font handle and a texture belong to the
    backend that created them, and releasing one through a different backend is
    either a leak or a release of something that was never yours - so
    everything is handed back while the OLD renderer is still the active one,
    and only then does the switch happen.

    An unknown or unavailable name falls back to native rather than leaving the
    HUD with nothing drawing it: the config carries this name, and a config
    written by a version that had a renderer this one does not is not a reason
    to show a blank screen.
]]
function applyRenderer(name)
    if not drawM.available(name) then name = 'native' end
    settings.renderer = name
    if drawM.backend() == name then return false end

    releaseFonts()
    releaseTextures()

    drawM.use(name)

    loadFonts()
    loadTextures()
    return true
end


-- Hud value and update functions
local function formatedMoney(n)
    return string.format("%s%s", hud.elements.money.dollar and '$' or '', hud.elements.money.comma and formatNumber(n) or n)
end

local function formatedAmmo(ammo, clip)
    return string.format("%s", hud.elements.weapon.splitAmmo and (string.format("%d-%d", ammo - clip, clip)) or clip)
end

local function formatedFps(fps)
    return string.format("%s%d", hud.elements.fps.showLabel and 'FPS: ' or '', fps)
end

local function formatedPing(ping)
    return string.format("%s%d", hud.elements.ping.showLabel and 'Ping: ' or '', ping)
end

local function formatedLocalTime()
    return os.date(hud.elements.localTime.twelveHour and '%I:%M:%S' or '%H:%M:%S')
end

local function formatedZone(handle)
    local zoneName, subZoneName = playerM.zoneOf(handle)
    return subZoneName and string.format("%s (%s)", zoneName, subZoneName) or zoneName
end

local function formatedTurf()
    return getActiveInterior() == 0 and getGxtText("turfText") or nil
end

local function formatedNickName(id)
    return string.format("%s (%d)", sampGetPlayerNickname(id), id)
end

local function updateValue(table, index, newValue)
    if table[index] ~= newValue or (newValue == nil and table[index] ~= nil) then
        table[index] = newValue
        return true
    end
    return false
end

local function updateVehicleInfo(id)
    local updated = false
    if isCharInAnyCar(id) then
        local vehid = storeCarCharIsInNoSave(id)
        local model = getCarModel(vehid)
        local vehhp = getCarHealth(vehid)
        local carName = getVehicleName(model)
        local speed = string.format("%d %s", playerM.convertSpeed(getCarSpeed(vehid), hud.elements.speed.mph), hud.elements.speed.mph and "MPH" or "KMH")
        local maxvalue = (table.contains(assets.maxVehHPIds, model) and hud.elements.vehicle.bigVehicles) and 2500 or 1000
        
        updated = updateValue(vehicleValues, 1, vehhp) or updated
        updated = updateValue(miscValues, 9, speed) or updated
        updated = updateValue(miscValues, 10, carName) or updated
        
        if hud.elements.vehicle.max ~= maxvalue then
            hud.elements.vehicle.max = maxvalue
            updated = true
        end
    else
        updated = updateValue(vehicleValues, 1, hud.elements.vehicle.stayOn and 0 or nil) or updated
        updated = updateValue(miscValues, 9, nil) or updated
        updated = updateValue(miscValues, 10, nil) or updated
    end
    return updated
end

--[[
    The turf textdraw's colour, which the Turf row of the HUD is drawn in.

    THIS SWEPT 3001 SLOTS ON EVERY hudValues() TICK. The `break` hides that on
    a server where the turf draw exists at a low slot - but where it does not
    exist at all, nothing breaks the loop and the sweep runs to completion
    every tick.

    It is the hook-plus-reconcile shape akacross.textdraw.watch describes:
    sampev.onTextDrawSetString is the live signal and already writes this
    colour, so the sweep is only the reconcile behind it and does not need to
    run per tick at all.

    Steady state is now ONE native call - re-read the slot already held. The
    pool is only walked when that slot stops being the turf draw, and then at
    most twice a second.
]]
local TURF_RECONCILE = 0.5
local turfSlot, turfSweepStamp = nil, -math.huge

--- The colour if `slot` is the turf draw, nil otherwise. Signatures come from
--- the active server, so this finds nothing until one is detected - which is
--- the same gate the overrides are behind.
local function turfColorAt(slot)
    local s = srv()
    if not s then return nil end
    if not sampTextdrawIsExists(slot) then return nil end
    local letSizeX, letSizeY, color = sampTextdrawGetLetterSizeAndColor(slot)
    if tostring(letSizeX) ~= s.sig.turfW or tostring(letSizeY) ~= s.sig.turfH then return nil end
    if sampTextdrawGetString(slot) == s.sig.turfOwner then return nil end
    return color
end

local function findTurfSlot()
    local s = srv()
    if not s then return nil end
    if textdrawM and textdrawM.first then
        -- `pos = false` halves the native calls: the match is on letter size
        -- and text, and the position is not wanted.
        local hit = textdrawM.first(function(id, text)
            if text == s.sig.turfOwner then return false end
            local letSizeX, letSizeY = sampTextdrawGetLetterSizeAndColor(id)
            return tostring(letSizeX) == s.sig.turfW and tostring(letSizeY) == s.sig.turfH
        end, {pos = false})
        return hit and hit.id
    end
    for slot = 0, TD_MAX do
        if turfColorAt(slot) then return slot end
    end
end

local function updateTextDrawColors()
    local color = turfSlot and turfColorAt(turfSlot)

    if not color then
        turfSlot = nil
        local now = os.clock()
        if now - turfSweepStamp < TURF_RECONCILE then return false end
        turfSweepStamp = now
        turfSlot = findTurfSlot()
        color = turfSlot and turfColorAt(turfSlot)
        if not color then return false end
    end

    if hud.elements.turf.text.color == color then return false end
    hud.elements.turf.text.color = color
    return true
end

local function updateBadgeTextAndColor(color)
    -- akacross.colors returns {r =, g =, b =}, not a 1..3 array.
    local rgb = colorsM.convertColor(color, false, false, false)
    local argbColor = colorsM.joinARGB(255, rgb.r, rgb.g, rgb.b, false)
    
    for _, v in pairs(assets.badgeNames) do
        if argbColor == v[1] then
            if hud.elements.badge.text.color ~= v[1] or miscValues[11] ~= v[2] then
                hud.elements.badge.text.color = v[1]
                updateValue(miscValues, 11, v[2])
                return true
            end
            return false
        end
    end
    return updateValue(miscValues, 11, nil)
end

--[[
    THE SERVER'S HEALTH POOL.

    Both servers run the player on a huge internal HP figure so damage has
    finer granularity than 100 steps, and what you are meant to SEE is the
    remainder sitting on top of it. Horizon's pool is 5,000,000 and Paraiso's
    is 3,000,000; on both, the part that means anything tops out at 100 - which
    is already what `hud.elements.health.max` is.

    So `sampGetPlayerHealth` returning 3000050 on Paraiso is 50 HP, and the
    same 3000050 on Horizon is not - which is exactly why the pool is per
    server, read from the profile akacross.rp selected, rather than guessed at.

    THE OLD VERSION GUESSED, AND THE GUESS WAS ORDER-DEPENDENT. It was a flat
    config list, `serverHp = {3000000, 5000000, 8000000}`, subtracted like
    this:

        for _, v in pairs(hud.serverHp) do
            if hp >= v then hp = hp - v end
        end

    `pairs` has no defined order, so on Horizon a run that reached 3,000,000
    first turned 5,000,050 into 2,000,050 and stopped - a plausible-looking
    number, wrong by two million, different between launches. It had been
    commented out rather than fixed. The list is gone from the config with it.

    Anything below the pool is passed through untouched: that is a server not
    using one, or a value read before the pool has been applied, and
    subtracting from it would turn a real 50 into a negative.
]]
local function serverHealth(hp)
    local s = srv()
    if not s or not s.hpPool then return hp end
    if hp < s.hpPool then return hp end
    local shown = hp - s.hpPool
    -- Clamped, because the bar divides by `max` and a value above it would
    -- render as an over-full bar rather than a full one.
    if shown > s.hpMax then shown = s.hpMax end
    return shown
end

local function updatePlayerInfo(id, handle, isSpec)
    local hp = sampGetPlayerHealth(id)
    --[[
        NOT while spectating. The pool is on your own health; another player's
        arrives already reduced through the sync, so subtracting again would
        read every spectated player as 0. That gate predates this change and
        is kept.
    ]]
    if not isSpec then
        hp = serverHealth(hp)
    end

    local updated = false
    updated = updateValue(healthValues, 1, hp) or updated
    updated = updateValue(armorValues, 1, sampGetPlayerArmor(id)) or updated

    if isSpec then
        updated = updateValue(sprintValues, 1, nil) or updated
        updated = updateValue(breathValues, 1, nil) or updated
    else
        updated = updateValue(sprintValues, 1, playerM.sprintLevel()) or updated
        updated = updateValue(breathValues, 1, playerM.waterLevel()) or updated
    end

    local weap = getCurrentCharWeapon(handle)
    updated = updateValue(weaponValues, 1, weap) or updated
    updated = updateValue(weaponValues, 2, formatedAmmo(getAmmoInCharWeapon(handle, weap), playerM.ammoInClip(handle, weap))) or updated
    updated = updateValue(weaponValues, 3, weapons.get_name(weap)) or updated

    if isSpec then
        updated = updateValue(moneyWantedValues, 1, nil) or updated
        updated = updateValue(moneyWantedValues, 2, nil) or updated
    else
        updated = updateValue(moneyWantedValues, 1, playerM.wantedLevel()) or updated
        updated = updateValue(moneyWantedValues, 2, formatedMoney(getPlayerMoney())) or updated
    end
    
    local angle = playerM.direction(isSpec and getCharHeading(handle)
        or hud.elements.direction.useCamera and playerM.cameraHeading()
        or getCharHeading(handle))
    updated = updateValue(miscValues, 1, formatedNickName(id)) or updated
    updated = updateValue(miscValues, 2, formatedLocalTime()) or updated
    updated = updateValue(miscValues, 3, getGxtText("wwText")) or updated
    updated = updateValue(miscValues, 4, formatedPing(sampGetPlayerPing(id))) or updated
    updated = updateValue(miscValues, 5, formatedFps(fps)) or updated
    updated = updateValue(miscValues, 6, angle) or updated
    updated = updateValue(miscValues, 7, formatedZone(handle)) or updated
    updated = updateValue(miscValues, 8, formatedTurf()) or updated

    return updated
end

local function updateDemoValues(id)
    local demoValues = {
        healthValues = {50},
        armorValues = {50},
        sprintValues = {100},
        vehicleValues = {1000},
        breathValues = {100},
        weaponValues = {24, formatedAmmo(50000, 7), 'Desert Eagle'},
        moneyWantedValues = {6, formatedMoney(1000000)},
        miscValues = {
            'Player_Name', 
            'Local-Time', 
            'Server-Time', 
            formatedPing(sampGetPlayerPing(id)), 
            formatedFps(fps), 
            'Direction', 
            'Location', 
            'Turf', 
            'Vehicle Speed', 
            'Vehicle Name', 
            'Badge'
        }
    }
    local updated = false
    for tableName, values in pairs(demoValues) do
        for i, value in ipairs(values) do
            if tableName == "healthValues" then
                updated = updateValue(healthValues, i, value) or updated
            elseif tableName == "armorValues" then
                updated = updateValue(armorValues, i, value) or updated
            elseif tableName == "sprintValues" then
                updated = updateValue(sprintValues, i, value) or updated
            elseif tableName == "vehicleValues" then
                updated = updateValue(vehicleValues, i, value) or updated
            elseif tableName == "breathValues" then
                updated = updateValue(breathValues, i, value) or updated
            elseif tableName == "weaponValues" then
                updated = updateValue(weaponValues, i, value) or updated
            elseif tableName == "moneyWantedValues" then
                updated = updateValue(moneyWantedValues, i, value) or updated
            elseif tableName == "miscValues" then
                updated = updateValue(miscValues, i, value) or updated
            end
        end
    end
    return updated
end

-- Function to update HUD values
function hudValues()
    local res, id = sampGetPlayerIdByCharHandle(ped)
    if not res then 
        return 
    end

    if menu.settings[0] then
        return updateDemoValues(id)
    end

    local updated = false
    updated = updateTextDrawColors() or updated

    if spectateData.state and spectateData.id ~= -1 and sampIsPlayerConnected(spectateData.id) then
        local res, handle = sampGetCharHandleBySampPlayerId(spectateData.id)
        if res then
            updated = updatePlayerInfo(spectateData.id, handle, spectateData.state) or updated
            updated = updateVehicleInfo(handle) or updated
            updated = updateBadgeTextAndColor(sampGetPlayerColor(spectateData.id)) or updated
        end
    else
        updated = updatePlayerInfo(id, ped, false) or updated
        updated = updateVehicleInfo(ped) or updated
        updated = updateBadgeTextAndColor(sampGetPlayerColor(id)) or updated
    end

    return updated
end

function resetValues()
    for i = 1, #healthValues do
        healthValues[i] = nil
    end

    for i = 1, #armorValues do
        armorValues[i] = nil
    end

    for i = 1, #sprintValues do
        sprintValues[i] = nil
    end

    for i = 1, #vehicleValues do
        vehicleValues[i] = nil
    end

    for i = 1, #weaponValues do
        weaponValues[i] = nil
    end

    for i = 1, #breathValues do
        breathValues[i] = nil
    end

    for i = 1, #moneyWantedValues do
        moneyWantedValues[i] = nil
    end

    for i = 1, #miscValues do
        miscValues[i] = nil
    end
end

-- Move Functions
--[[
    DRAGGING, ONE LOOP INSTEAD OF A BRANCH PER ELEMENT.

    v1 hit-tested with a hand-written block per element number, each working
    out its own width, height and alignment - which is why the misc rows lived
    in a nested loop and the weapon needed three. Every part knows its own box
    now, so this walks the same part list the renderer does.

    THE BAR'S BOX NO LONGER DRIFTS. v1 hit-tested a bar at `offx + border` but
    wrote the drag back to `offx`, so every drag moved the bar by the border
    width on top of the mouse movement. The box is the bar's own rectangle
    here, and what is written back is what was hit.
]]
-- What each text part is showing, which is what its hit box has to measure.
local function textPartValue(key, cfg, partName)
    if partName == 'ammo' then return weaponValues[2] end
    if partName == 'name' and key == 'weapon' then return weaponValues[3] end
    if cfg.bar then return BAR_VALUES[key][1] end
    if key == 'money' then return moneyWantedValues[2] end
    return miscValues[MISC_INDEX[key]]
end

--- The screen rectangle a part occupies, plus the alignment offset already
--- folded into its left edge.
local function partHitBox(key, cfg, partName, isText)
    local part = cfg[partName]
    if not part then return nil end
    local x, y = partPosition(part)

    if isText then
        local _, width, height, align = fontMetrics(key, partName, textPartValue(key, cfg, partName) or "")
        if width <= 0 then return nil end
        return x - align, y, width, height, align
    end

    if partName == 'stars' then
        -- The stars grow with the wanted level, so the box does too.
        local count = moneyWantedValues[1] or 0
        return x, y, part.sizex + (part.sizex + part.spacing) * count, part.sizey, 0
    end
    return x, y, part.sizex, part.sizey, 0
end

local dragging = nil        -- {apply = function(x, y)}
local movingAnchor = nil    -- an anchor following the cursor until the next click

--- Put an anchor into follow-the-cursor mode, or take it back out and undo.
function toggleAnchorMove(anchor)
    if movingAnchor and movingAnchor ~= anchor then return false end
    if movingAnchor == anchor then
        anchor.x, anchor.y = assets.tempPos.x, assets.tempPos.y
        movingAnchor = nil
        return false
    end
    assets.tempPos.x, assets.tempPos.y = anchor.x, anchor.y
    movingAnchor = anchor
    return true
end

function isAnchorMoving(anchor)
    return movingAnchor == anchor
end

function hudMove()
    if not menu.settings[0] then
        dragging, movingAnchor = nil, nil
        return
    end

    local mx, my = getCursorPos()
    local pressed = isKeyJustPressed(VK_LBUTTON)

    -- An anchor in move mode follows the cursor and is dropped by a click.
    if movingAnchor then
        if pressed then
            movingAnchor = nil
        else
            movingAnchor.x, movingAnchor.y = mx, my
        end
        return
    end

    if dragging then
        if wasKeyReleased(VK_LBUTTON) then
            dragging = nil
        else
            dragging.apply(mx, my)
        end
        return
    end

    if not pressed then return end

    local function grab(boxX, boxY, apply)
        local dx, dy = mx - boxX, my - boxY
        dragging = {apply = function(px, py) apply(px - dx, py - dy) end}
    end

    -- The anchor handles are drawn on top of everything, so they are hit first.
    local anchors = hud.anchors
    for i = 1, #anchors do
        local anchor = anchors[i]
        if mx >= anchor.x and mx <= anchor.x + ANCHOR_HANDLE
           and my >= anchor.y and my <= anchor.y + ANCHOR_HANDLE then
            grab(anchor.x, anchor.y, function(x, y) anchor.x, anchor.y = x, y end)
            return
        end
    end

    -- Reverse draw order, so an element drawn on top of another is the one
    -- you grab.
    local list = Spec.list
    for i = #list, 1, -1 do
        local spec = list[i]
        local cfg = hud.elements[spec.key]
        local parts = Spec.parts[spec.kind]
        for p = #parts, 1, -1 do
            local partName, isText = parts[p].name, parts[p].text
            local part = cfg and cfg[partName]
            if part and part.enabled then
                local boxX, boxY, width, height, align = partHitBox(spec.key, cfg, partName, isText)
                if boxX and mx >= boxX and mx <= boxX + width
                   and my >= boxY and my <= boxY + height then
                    grab(boxX, boxY, function(x, y)
                        local anchor = hud.anchors[part.anchor] or hud.anchors[1]
                        part.offx = x + align - anchor.x
                        part.offy = y - anchor.y
                    end)
                    return
                end
            end
        end
    end
end

-- ---- writing to the server's textdraws ----------------------------------
--- Move a row to where the config wants it, or off-screen when it is switched
--- off. Takes the server row, which carries both the position and the toggle.
local function setPosition(i, row)
    if row.enabled then
        sampTextdrawSetPos(i, row.x, row.y)
    else
        sampTextdrawSetPos(i, -100, -100)
    end
end

local function setStringAndColor(i, text, letterSizeX, letterSizeY, color)
    sampTextdrawSetLetterSizeAndColor(i, letterSizeX, letterSizeY, color)
    sampTextdrawSetString(i, text)
end

local function setHPBar(i, text, box, sizeX, sizeY, color)
    sampTextdrawSetString(i, text)
    sampTextdrawSetBoxColorAndSize(i, box, color, sizeX, sizeY)
end

--[[
    The HP and armour readouts: blanked rather than moved, because they sit
    inside the server's own HUD block and moving them would leave a hole.

    THE LETTER SIZE IS THE ACTIVE SERVER'S, not a constant. It used to be
    Horizon's two values written out here, which survived the 1.4.37 rename to
    Paraiso unchanged - so on Paraiso, toggling the HP text off and on rewrote
    the draw at Horizon's size. That both resized the readout and took the slot
    out of `sig.textW/textH`, which is what the sweep matches on, so the row
    stopped responding until the server redrew it.
]]
local function setHPAndArmorText(i, text, enabled, color)
    local size = SERVERS[srvId].textSize
    setStringAndColor(i, enabled and text or '', size[1], size[2], color)
end

-- Handle Textdraws
--[[
    The server textdraw overrides, applied by sweeping the pool.

    THE POOL IS 2304 SLOTS, NOT 4001.

    SA-MP has 2048 server textdraws plus 256 player textdraws, so this used to
    spend 1,698 sampTextdrawIsExists calls per pass - 42% of the sweep - on
    slots that cannot exist. akacross.textdraw carries the real bound and
    pcall-guards every native read; MAX_ID is the whole reason its header calls
    out admintools sweeping to 3000.

    THE SWEEP IS THE FALLBACK, NOT THE PATH.

    Every one of these draws is found at a fixed slot and stays there. So the
    slots that matched are remembered, and a re-apply walks those instead of
    the pool - which matters because the settings menu calls this from a
    DragFloat, i.e. once per frame for as long as the user holds the mouse
    down. Under the old code that was a full pool sweep per frame.

    The cache is dropped when the server draws something new
    (sampev.onShowTextDraw), whenever a remembered slot stops matching, and
    when the detected server changes - the third because the signatures it
    matches on are the server's, so slots found under one profile mean nothing
    under another.
]]
local srvSlots = {}          -- slots that matched any row on the last sweep
local srvSlotsValid = false

--- Called when the server draws something new, or when the profile changes:
--- the next re-apply sweeps.
function srvInvalidateSlots()
    srvSlotsValid = false
    for i = #srvSlots, 1, -1 do srvSlots[i] = nil end
end

--[[
    Apply every row that `slot` matches. `only` restricts it to one row
    (0..6); nil means all of them, which is what startup wants - it used to
    call srvTextDraws SEVEN times and sweep the whole pool on each.

    Returns whether the slot is one of ours, which is what builds the cache.

    `only = 'probe'` is the READ-ONLY form: it matches no row number, so every
    write below is skipped and only the return value is produced. That is what
    `/hud td` counts with, and it is a sentinel rather than a second copy of
    the matching precisely because a diagnostic that drifts from the code it
    is diagnosing is worse than no diagnostic.
]]
local function srvApplySlot(slot, only)
    local s, cfg = srv(), srvCfg()
    if not s then return false end
    if not sampTextdrawIsExists(slot) then return false end

    local sig = s.sig
    local posX, posY = sampTextdrawGetPos(slot)
    local letSizeX, letSizeY = sampTextdrawGetLetterSizeAndColor(slot)
    local letW, letH = tostring(letSizeX), tostring(letSizeY)
    local text = sampTextdrawGetString(slot)
    local matched = false

    -- The owner label by TEXT, the turf name by letter size. Horizon draws the
    -- label at letter size 0 / 0, so a shared size gate loses it - see the
    -- note on handleTurfTextDraw.
    if text == sig.turfOwner then
        matched = true
        if only == nil or only == 1 then
            setStringAndColor(slot, text, letSizeX, letSizeY, cfg.turfOwner.color)
            setPosition(slot, cfg.turfOwner)
        end
    elseif letW == sig.turfW and letH == sig.turfH then
        matched = true
        if only == nil or only == 0 then
            setPosition(slot, cfg.turf)
        end
    end

    if letW == sig.wwW and letH == sig.wwH and text:match("%W") then
        matched = true
        if only == nil or only == 2 then
            setStringAndColor(slot, text, letSizeX, letSizeY, cfg.wristwatch.color)
            setPosition(slot, cfg.wristwatch)
        end
    end

    if letW == sig.logoW and letH == sig.logoH then
        matched = true
        if only == nil or only == 3 then
            setStringAndColor(slot,
                cfg.logo.custom and cfg.logo.text or s.logoText,
                letSizeX, letSizeY, cfg.logo.color)
            setPosition(slot, cfg.logo)
        end
    end

    -- The HP bar is matched by POSITION, not letter size, and it is three
    -- separate draws stacked on each other. These are the laid-out positions;
    -- on Paraiso they differ from the ones the ShowTextDraw RPC carries, on
    -- Horizon they do not.
    local bar = s.hpBarSweep(slot, posX, posY)
    if bar then
        matched = true
        if only == nil or only == 4 then
            -- The server's own string is stashed on the way out so switching
            -- the bar back on can restore it; it is not recoverable otherwise.
            local box, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(slot)
            if cfg.hpBar.enabled then
                if srvHpBarText[bar] ~= '' then text = srvHpBarText[bar] end
            else
                srvHpBarText[bar] = text
                text = ''
            end
            setHPBar(slot, text, box, sizeX, sizeY, cfg.hpBar['color' .. bar])
        end
    end

    if letW == sig.textW and letH == sig.textH then
        local role = s.hpArmorRole(posX, posY)
        if role == 'hpText' then
            matched = true
            if only == nil or only == 5 then
                setHPAndArmorText(slot, text, cfg.hpText.enabled, cfg.hpText.color)
            end
        elseif role == 'armorText' then
            matched = true
            if only == nil or only == 6 then
                setHPAndArmorText(slot, text, cfg.armorText.enabled, cfg.armorText.color)
            end
        end
    end

    return matched
end

--- Does this slot match the active profile? No writes. See srvApplySlot's
--- `probe` note. Global because /hud td is defined above this point.
function srvSlotMatches(slot)
    return srvApplySlot(slot, 'probe')
end

function srvTextDraws(id)
    -- Nothing to apply until the server is one we have a profile for.
    if not srv() then return end

    -- Fast path: re-apply to the slots we already found. One existence check
    -- each, and a slot that no longer matches drops the whole cache rather
    -- than being patched around - the ids are meaningless after a reconnect.
    if srvSlotsValid then
        for i = 1, #srvSlots do
            if not srvApplySlot(srvSlots[i], id) then
                srvSlotsValid = false
                break
            end
        end
        if srvSlotsValid then return end
    end

    for i = #srvSlots, 1, -1 do srvSlots[i] = nil end
    for slot = 0, TD_MAX do
        if srvApplySlot(slot, id) then
            srvSlots[#srvSlots + 1] = slot
        end
    end
    srvSlotsValid = true
end

--[[
    THE PLAYER-STATE READERS MOVED TO akacross.player.

    updateSprintStatus, getSprintLevel, getWaterLevel, getAmmoInClip,
    getWantedLevel, convertSpeed, getCustomZoneName, getPlayerZoneName,
    getDirection and getCameraZAngle all used to live here, and nothing outside
    this file could reach any of them - they stayed because hud was a single
    file with nowhere else to put them, not because they are HUD-specific.

    They are not. "Is the player sprinting, how much breath is left, what is in
    the clip, which way are they facing, what is this place called" is the
    question every overlay in this set asks; admintools had already
    reimplemented the sprint read against the same address.

    What moved gained a name for every magic number on the way. `0xB7CDB4` and
    `/ 31.47000244` are unverifiable as literals in a render pass; they are
    `ADDR.SPRINT_ENERGY` and `SPRINT_FULL` now, with the struct field each one
    reads written next to it.

    Two of them changed shape, and both for the better:

      updateSprintStatus  was a void that wrote three file-locals. It is
                          playerM.feedSprint(pressed) -> bool now, so the
                          sampler is not tied to this file's key constant.
      getCustomZoneName   read a `customZones` global. The zone set is
                          per-server, so it is registered with
                          playerM.setCustomZones() instead.
]]


--[[
    THE UPDATER, through akacross.updater.

    checkForUpdate, updateScript and downloadFiles used to be written out here,
    and reports.lua carried its own subtly different copy of all three. The
    differences were not decisions:

      * this script's version pattern was `version: (.+)`, which is greedy to
        end of line and captured the trailing carriage return a Windows-written
        file carries;
      * its batch downloader called back the moment MoonLoader reported
        STATUS_ENDDOWNLOADDATA, which fires BEFORE the handle is flushed and
        closed - so validating in that callback could read zero bytes. reports'
        copy had the settle wait; this one did not.

    The shared implementation takes the safe half of each. See
    lib/akacross/updater.lua.
]]
local updater = updaterM.new{
    label       = 'HUD',
    scriptPath  = scriptPath,
    version     = scriptVersion,
    versionUrl  = function() return fetchUrls('update', settings.beta) end,
    scriptUrl   = function() return fetchUrls('script', settings.beta) end,
    versionFile = getFile('update'),
    reload      = function() thisScriptRef:reload() end,
    say         = formattedAddChatMessage,
    --[[
        The prompt is a modal INSIDE the settings window, so raising it while
        that window is shut would put an update notice somewhere nobody can
        see. Open the window with it - which is what the old second top-level
        window did by existing.
    ]]
    onAvailable = function()
        hudFilesM.prompt('update')
        menu.settings[0] = true
    end,
    -- Persisted only once the download has been proven to parse: setting this
    -- for a 404 page leaves the mod claiming an update is running that never
    -- started.
    onBegin = function()
        settings.updateInProgress = true
        settings.lastVersion = scriptVersion
        Config.saveSettings()
    end,
    onFail = function() settings.updateInProgress = false end,
}

function checkForUpdate(announce) updater:check(announce) end
function updateScript() updater:install() end

--- The asset fetcher, which is the same batch downloader. Kept as a global
--- under its old name because the icon download and the config scan both call
--- it by that name from several places.
function downloadFiles(files, onComplete)
    return updaterM.fetch(files, onComplete)
end

-- Generate Icon Urls
function generateIconUrls()
    local files = {}
    for i = 0, 48 do
        if i < 19 or i > 21 then
            table.insert(files, {
                url = string.format("%s%d.png", fetchUrls("icons"), i),
                path = string.format("%s%d.png", getPath("icons"), i),
                replace = false
            })
        end
    end
    return files
end

-- Update Functions

--[[
    Self-update, through the shared runtime.

    This used to download STRAIGHT OVER scriptPath - the live script - and
    reload. Anything that is not the new script (a truncated transfer, a 404
    page, the repo serving HTML) therefore replaced a working install with
    rubbish, and the reload then failed with a parse error on a file the user
    had no copy of. akacross.downloads records the same class of bug from the
    other direction: "the script updater could then delete the live script and
    rename a file that was never downloaded".

    So it stages to a .new, checks the bytes are a Lua file that PARSES, and
    only then installs - which is what reports.lua does (SHARED_RUNTIME.md open
    question 5: staging and validation belong in deps, the version check and
    the prompt stay with the mod). installFile falls back to a byte copy
    because os.rename fails under Wine while any handle is still on either
    file.

    Without deps.lua there is nothing to validate with, so it takes the old
    direct path rather than pretending to be safe.
]]

-- Utility Functions
--[[
    handleConfigFile, ensureDefaults, loadConfig, saveConfig and
    saveConfigWithErrorHandling used to live here - about 140 lines of JSON
    reading, default-merging, key-pruning and error reporting.

    All of it is akacross.config over carbJsonConfig now; see the Config block
    near the top. The one piece that did NOT move is pruning: cjc merges, so
    Config.applyDefaults still drops keys the defaults no longer have, which is
    what lets a v1 file's dead arrays disappear rather than sit in the table
    forever.
]]


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

--[[
    Version comparison.

    akacross.deps carries the maintained comparator - the same numeric-parts
    walk this had, plus a letter-suffix rule (1.2b sorts below 1.2) that the
    local copy did not. The local one stays as the fallback for an install with
    no deps.lua, which is the same contract the dependency loader above has.
]]



function displayChangelog()
    local versions = {}
    for version in pairs(changelog) do
        table.insert(versions, version)
    end
    
    table.sort(versions, function(a, b)
        return deps.compareVersions(a, b) > 0
    end)
    
    for _, version in ipairs(versions) do
        print("Version " .. version .. ":")
        for _, change in ipairs(changelog[version]) do
            print("- " .. change)
        end
        if version ~= versions[#versions] then
            print("")  -- Empty line between versions
        end
    end
end


--[[
    convertColor, joinARGB, imgui.TextColoredRGB and imgui.CustomButton used to
    live here.

    The first two are akacross.colors now (`colorsM.convertColor` returns
    {r =, g =, b =, a =} rather than a 1..4 array - that is the only difference
    at a call site), and CustomButton is akacross.imgui_funcs, whose signature
    takes a TEXT colour before the size.

    TextColoredRGB was never called by anything in this script. It was a ~60
    line inline-colour-tag parser with a nested closure per segment, kept alive
    only by being a global; it is not carried over. akacross.imgui_funcs has
    the maintained version if it is ever wanted.
]]

function loadFontAwesome6Icons(iconList, fontSize)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    config.GlyphMinAdvanceX = 14
    local builder = imgui.ImFontGlyphRangesBuilder()
    
    for _, icon in ipairs(iconList) do
        builder:AddText(fa(icon))
    end
    
    local glyphRanges = imgui.ImVector_ImWchar()
    builder:BuildRanges(glyphRanges)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85("solid"), fontSize, config, glyphRanges[0].Data)
end

--[[
    apply_custom_style() used to live here: ~70 lines setting ImGui's style
    struct field by field, in a dark-red palette that was this script's alone.

    It is akacross.style now, and the palette went with it. Every mod split out
    of autobind - driving, wanted, vstorage, fastmap, reports - already wore
    that theme; this was the last one that did not, so a user with two of them
    open had two different-looking windows from the same author.

    The move is not only cosmetic. Every metric in the shared theme is in
    SCALED pixels, so it can be re-applied when the UI scale changes; the
    version this replaced hard-coded 1080p pixel values and could not.
]]
