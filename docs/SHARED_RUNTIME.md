# Shared Runtime: dependency manager + cross-mod coordination

Design for two things the split makes urgent:

1. **Slimming the dependency-manager footprint** so each extracted mod does not
   carry a copy of autobind's bootstrap.
2. **Letting the mods communicate** so that N independent MoonLoader scripts do
   not fight over the files, keybinds, textures and game state they share.

Companion to [MANIFEST.md](MANIFEST.md). Design only - nothing here is
implemented yet.

---

## 1. Measured footprint today

### 1.1 autobind's dependency manager

| Region | Lines | What |
|---|---:|---|
| [autobind.lua:140-198](../autobind.lua#L140) | 59 | branch URL rewriting, `safeRequire` |
| [autobind.lua:199-326](../autobind.lua#L199) | 128 | the `dependencies` manifest (26 entries, some with `localFiles` lists) |
| [autobind.lua:327-407](../autobind.lua#L327) | 81 | `validateDownloadedFile`, `installStagedFile`, `fileMissingOrEmpty` |
| [autobind.lua:408-535](../autobind.lua#L408) | 128 | `downloadFiles`, `checkAndDownloadDependencies` |
| [autobind.lua:536-660](../autobind.lua#L536) | 125 | `main()` bootstrap gate + `drawBootstrapWindow` |
| [autobind.lua:775-900](../autobind.lua#L775) | 126 | version pin table + `depsync.json` self-heal |
| **Total** | **~647** | **15.5% of autobind.lua** |

Plus [lib/akacross/downloads.lua](../lib/akacross/downloads.lua), 606 lines -
the actual transfer engine, already a shared module.

So the bootstrap is ~1250 lines, of which roughly half sits inline in the entry
script and would be duplicated into every extracted mod.

### 1.2 The same drift as window dragging

Three independent implementations of the *same* `{name, var, required}`
manifest-plus-pcall-loop already exist:

| Script | Lines | Manifest | Downloads | Version pins | Self-heal |
|---|---:|---|---|---|---|
| [autobind.lua:199](../autobind.lua#L199) | ~647 | 26 entries | yes | yes | yes |
| ~~[reports.lua:76](../reports.lua#L76)~~ | ~~100~~ -> 30 | 15 entries | validated via `deps` tier 1 | no | no |
| [autofps.lua:25](../autofps.lua#L25) | ~35 | 9 entries | no | no | no |

`sprint`, `admintools`, `fixes`, `adminchatcolour` have none and call `require`
bare - fine while their deps are guaranteed present, fatal on a fresh install.
(`badge` was in this list until 0.4.0 put it on `deps`; see migration step 2.)

The three are recognisably the same code with different amounts of feature
sanded off, exactly like the `handleWindowDragging` forks. Extracting FastMap
without fixing this makes it four.

---

## 2. What MoonLoader actually gives us for cross-state communication

Verified against [moonloader_reference.lua:1899-1903](../moonloader_reference.lua#L1899)
and the live scripts. **Every MoonLoader script runs in its own Lua state.** A
module required by two scripts is instantiated twice. There are no shared
tables.

**Available:**

| Primitive | What it gives | Cost |
|---|---|---|
| `script.find(name)`, `script.list()`, `script.get(id)` | Presence and identity: name, version, filename, authors, id. | free, synchronous |
| `onScriptLoad`, `onScriptTerminate` | Join/leave events for every script. | free, event-driven |
| `print()` -> `onScriptMessage(msg, script)` | **A real broadcast channel.** A `print` in one state fires `onScriptMessage` in every other loaded state, tagged with the sender's script object. | writes to moonloader.log; low rate only |
| Files under `config/` | Durable, arbitrary payload, survives reload. | needs a read trigger |
| ffi + Windows named file-mapping / mutex | True shared memory, works under Proton. | heavy; only if a fast path is ever needed |

**Not available:** there is no `exports` field on `LuaScript` and no
value-passing API. `script.find` returns a handle you can inspect and terminate,
not one you can read Lua values out of.

**The design consequence:** discovery is synchronous and cheap; payload transfer
is not. So the protocol below puts *state in files* and uses *`onScriptMessage`
purely as a wakeup*, which removes polling without inventing an RPC layer.

### 2.1 The pattern that already works

[lib/akacross/cursor.lua](../lib/akacross/cursor.lua) already solves a
cross-script conflict (two mimgui scripts fighting over the cursor) and it does
so **without any IPC**. Its header states the mechanism: mimgui is left as the
single actuator, and because mimgui re-asserts every frame while wanted and only
releases what its own state took, "two scripts running this module cannot strand
each other."

That is the model to generalise:

> **Per-frame re-derivation from a live consumer set, funnelled through one
> actuator, beats message-passing.** There is no counter to leak because the
> count is re-derived rather than incremented.

Conflicts that can be expressed this way need no bus at all. Only conflicts over
*durable* resources - files on disk, download slots, version numbers - need the
file-plus-wakeup protocol.

---

## 3. Proposed: `akacross.deps`

One shared module replacing all three loaders. Tiered, so a 88-line script like
`sprint.lua` pays almost nothing and `autobind` still gets self-heal.

### 3.1 Tier 0 - resolve only  [IMPLEMENTED]

[lib/akacross/deps.lua](../lib/akacross/deps.lua) `_VERSION 0.1.0`, 165 lines.

```lua
local deps = require('akacross.deps')

local M, report = deps.load({
    {name = 'moonloader', var = 'moonloader'},
    {name = 'mimgui',     var = 'imgui'},
    {name = 'fAwesome5',  var = 'fa', required = false},
}, {label = 'AFPS'})

if not report.ok then return end
```

The manifest keeps the exact `{name =, var =, required =, extras =}` shape all
three existing loaders already used, rather than the shorter positional form
first sketched here. One shape, no translation layer, and the ports are close to
a pure deletion.

`required` defaults to **true** - a dependency nobody thought about is one the
script cannot run without. `extras` publishes fields out of a constants-bag
module (`moonloader`'s `download_status`, `font_flag`) alongside it. `globals`
mirrors everything into `_G` for scripts whose bodies reference modules as bare
globals. `abortOnMissing = false` preserves a carry-on-regardless script.

**Why the caller returns.** A module cannot abort the chunk that required it.
`load` prints the reason and installs a `main()` that surfaces it in chat once
SA-MP is up, but the caller still has to `return` - and must, or it registers
hooks from a half-initialised state.

**`deps` is optional, and that is a hard requirement.** Deleting
`lib/akacross/deps.lua` must never stop a script from loading. Every consumer
therefore soft-requires it and carries a ~20-line fallback that resolves the
same manifest with a plain `pcall(require)` loop - exactly what the script did
before `deps` existed. The manifest is lifted out into a `DEPENDENCIES` local so
both paths read the same data.

The guard is `okDeps and type(deps) == 'table' and deps.load`, not just `okDeps`,
so a truncated or half-written `deps.lua` that still loads falls back rather than
crashing on a nil call.

This is the cost of optionality and it is worth naming: `autofps`'s block is 41
lines against 44 before, so tier 0 buys it almost nothing in size. What it buys
is one canonical implementation, a documented degradation path, and a manifest
that is now data rather than control flow. The size win only arrives at tier 1
scale.

This supersedes open question 1: no bootstrap stub, no hard prerequisite, and no
self-redownload either - a user who deletes `deps.lua` has decided something, and
healing it behind their back would be fighting them.

### 3.2 Tier 1 - fetch, validate, install, version-heal  [IMPLEMENTED]

Free functions plus an injectable installer. No mod-specific knowledge, no
module-level state, and the only globals touched are the MoonLoader natives that
cannot be avoided (`downloadUrlToFile`, `doesFileExist`, `createDirectory`,
`lua_thread`).

```lua
local inst = deps.newInstaller{
    libDir = Paths.libraries, libUrl = Urls.libraries,
    resourceDir = Paths.resource, resourceUrl = Urls.resource,
    stateFile = Paths.settings .. 'depsync.json',
    encodeJson = encodeJson, decodeJson = decodeJson,
    compareVersions = utils.compareVersions,   -- optional
    log = startupStage,                        -- optional
    onProgress = function(p) startup.progress = p end,
}

local missing = inst:scan(DEPENDENCIES)
inst:download(missing, function(ok, invalid) ... end)

local stale, satisfied = inst:versionCheck(PINS)
local fetch, changed, state = inst:versionsToFetch(stale, satisfied)
```

Also exported standalone: `deps.validate`, `deps.installFile`,
`deps.missingOrEmpty`, `deps.compareVersions`.

The logic is autobind's, carried over rather than rewritten, because it encodes
bugs that were paid for once already:

- `installFile` falls back to a byte copy because `os.rename` fails under
  Wine/Windows while any handle is still attached to either file.
- `download` counts the batch **before** starting, so a synchronous callback on
  a cached file cannot zero the counter while later files are unqueued.
- `download` validates **outside** the download callbacks, after a settle wait,
  because MoonLoader fires status 6 before flushing and closing the file - and
  the `os.remove` on that open handle fails silently, which is why a manual
  reload used to appear to fix it.
- `versionsToFetch` is the loop guard: the state record remembers the version
  last *attempted* per file, so a repo that still serves the old lib cannot spin
  download/reload forever. A file that reaches its pin clears its own record, so
  a later pin bump retries cleanly.

Everything the caller must decide stays with the caller: `versionsToFetch`
returns the state table but does not write it, because that write has to happen
once, after the caller has committed to acting.

### 3.3 Tier 2 - bootstrap UI

`drawBootstrapWindow` stays autobind-private for now. It is the least shared and
most opinionated part, and no other mod currently blocks on downloads at
startup.

### 3.3a What tier 1 can and cannot take from autobind

The "~647 lines out of autobind" figure in the original estimate does not
survive contact with the code. Breaking the region down:

| Part | Lines | Portable? |
|---|---:|---|
| `validateDownloadedFile`, `installStagedFile`, `fileMissingOrEmpty` | ~53 | **yes**, pure |
| `downloadFiles` | ~75 | **yes**, once progress is a callback |
| `checkAndDownloadDependencies` | ~44 | **yes**, once paths/URLs are injected |
| version pins + `depsync.json` | ~130 | **yes**, once the comparator is injected |
| `startup` barrier, bootstrap `main()`, `drawBootstrapWindow` | ~180 | **no** |
| the `dependencies` manifest itself | ~128 | no - it is autobind's data |

The bootstrap half is not portable and should not be. It is welded to autobind's
own shape: it asserts on `Files.trebucbd`, draws a window captioned "autobind -
preparing", and - the real obstacle - [autobind.lua:653](../autobind.lua#L653)
wraps **the entire remaining 3,500 lines of the script** in the dependency
callback. That is a control-flow inversion around the whole file, not a module
boundary.

So tier 1 absorbs roughly 300 portable lines, not 647.

**And optionality cuts into even that.** If autobind delegates its downloader to
`deps`, then deleting `deps.lua` costs autobind its ability to heal a missing
library. Restoring that under deletion would mean autobind carrying a full
fallback copy - two implementations instead of one, which is worse than not
moving it at all. The available options are therefore:

1. **Leave autobind's bootstrap alone.** Tier 1 exists for FastMap and future
   mods, which get it from day one and never grow a second copy. Autobind sheds
   nothing. Zero risk.
2. **Autobind delegates, with a degraded fallback** (~15 lines: resolve what is
   present, report what is not, no downloading). Sheds ~300 lines. Cost: with
   `deps.lua` deleted, a fresh or broken install cannot self-heal and instead
   says so.

Option 1 is the default until decided otherwise. Note that option 2's cost only
bites in the combination *deps deleted* **and** *a library missing* - a working
install that deletes `deps.lua` keeps working either way.

### 3.3b Admin mods are out of scope, permanently

`admintools` and `adminchatcolour` do not route through `deps` and are not to be
migrated. `admintools` is additionally a protected build whose header forbids
editing the artifact at all.

### 3.4 The version-pin coupling survives

Bumping a module's `_VERSION` without bumping its pin means existing installs
never redownload it. That coupling is a property of the self-heal design, not of
where the code lives, and it moves into `deps` unchanged - now with the pin
table *adjacent* to the manifest instead of 500 lines away from it, which is the
one real improvement to make while moving it.

### 3.5 Expected footprint change

| | Now | After | Status |
|---|---:|---:|---|
| autofps.lua inline | 44 | 21 | **done**, -23 |
| reports.lua inline | ~100 | 30 | **done** (0.2.0) |
| autobind.lua inline | ~647 | ~90 (manifest + pins only) | tier 1 |
| fastmap (projected) | ~647 | ~20 | after tier 1 |
| `lib/akacross/deps.lua` | 0 | 171 (tier 0) | **done** |

The small scripts (`sprint`, `badge`, `dialogrestore`, `adminchatcolour`,
`admintools`) are deliberately not in this table - see migration step 2.

Net once tier 1 lands: roughly 700 lines out of the entry scripts, one
implementation instead of three-going-on-four.

---

## 4. Coordination: the conflict classes

Enumerated from what the split actually creates. Each gets the cheapest
mechanism that closes it.

| # | Conflict | Mechanism |
|---|---|---|
| 1 | Two mods downloading the same shared lib concurrently -> torn file | **Lock file** `config/akacross/locks/<file>.lock` holding pid+script name+timestamp, stale after 60s. Loser waits for the winner's install, then re-requires. |
| 2 | Version skew: autobind pins `imgui_funcs` 0.2.0, fastmap needs 0.2.2, whoever runs last downgrades | **Shared registry** `config/akacross/registry.json`: each mod publishes `{mod, version, requires:{file: minVersion}}` on load. `deps` resolves each shared file to the **highest** requirement across live mods, never installs lower. |
| 3 | Reload storms: three mods each self-heal and each call reload at startup | **Reload token** in the registry. One mod at a time holds it; the others defer their reload until it is free. |
| 4 | Duplicate chat commands (`sampRegisterChatCommand` silently shadows) | **Claims**, section 5. |
| 5 | Duplicate keybind: autobind's `FastMap` bind on VK_M and a standalone fastmap both firing | **Claims**, section 5. |
| 6 | Both mods drawing the map in `onD3DPresent` -> double-draw | **Claims**, section 5. Must gate the *render hook*, not just the config flag. |
| 7 | Cursor / input / player-lock | **Already solved** by `akacross.cursor`. No change. |
| 8 | Two mods loading the same 20 MB texture atlas twice | **Owner-of-record** claim + the loser reads through `script.find`-gated lazy load, or simply accepts the cost. Measure before optimising. |
| 9 | `config/signature_cache.lua` written by whichever script inits the scanner first | Out of scope - belongs to `lib/signature_scanner`, flagged in MANIFEST section 7. |

Note that 4, 5, 6 and 8 are all the same shape: *exactly one live script should
own resource X*. That is one mechanism, not four.

---

## 5. `akacross.claims`

A claim is a named, singleton, cross-script resource with a deterministic owner.

```lua
local claims = require('akacross.claims')

-- fastmap.lua
claims.claim('map.render',   { priority = 100 })
claims.claim('keybind.VK_M', { priority = 100 })

-- autobind.lua, with its internal fastmap flagged off
if claims.owns('map.render') then drawMap() end
```

**Resolution without a bus.** Ownership is derived, not negotiated:

1. Every participating script publishes its claims to
   `config/akacross/registry.json` on load and clears them on
   `onScriptTerminate`.
2. Owner of a claim = the live claimant with the highest priority; ties broken
   by script name, so every state computes the *same* answer independently.
3. Liveness comes from `script.find(name)` - synchronous, free, and always
   current. A crashed script's stale registry entry is ignored the moment
   `script.find` returns nil, so there is no lease to expire.
4. `onScriptLoad` / `onScriptTerminate` invalidate the cache. `onScriptMessage`
   is the wakeup for mid-session claim changes.

No script asks another script for permission, and there is no leader election.
Each state re-derives the same total order from data every state can see. Same
property `akacross.cursor` relies on, applied to durable resources.

**This is what makes the FastMap side-by-side verification safe.** During the
overlap window both autobind and fastmap are loaded and both want
`map.render`; the standalone one claims higher priority and autobind's copy goes
quiet, with no code deleted and no flag to forget to flip back.

---

## 6. Migration order

Each step verifiable in-game before the next, per the working rules.

1. ~~`lib/akacross/deps.lua` at tier 0. Port `autofps`.~~ **Done.**
   ~~`reports` deliberately left alone for now~~ - **`reports` is ported too,
   in 0.2.0.** It exercises `extras` (moonloader's `download_status`) and an
   optional dependency (`fAwesome5`); it does NOT need `globals`, because the
   port made every module a named local instead. Its self-updater uses tier 1's
   `deps.validate` / `deps.installFile` rather than trusting a download, which
   answers open question 5: staging and validation belong in `deps`, the
   version check and the prompt stay with the mod.
2. ~~Port `sprint`, `badge`, `admintools`, `dialogrestore`, `adminchatcolour`.~~
   **Decided against.** These were tried and reverted. A script with one
   dependency does not benefit from acquiring a second one to guard the first:
   `sprint` (1 dep) and `dialogrestore` (1 dep, on the universally-present
   `samp.events`) would each end up with a strictly larger release file set and
   a new failure mode, to report on something that essentially cannot be
   missing. `admintools` is a protected build whose header forbids editing the
   artifact, and `adminchatcolour` is excluded by the same reasoning as
   `dialogrestore`.

   **The rule this establishes:** `deps` earns its place from about three
   dependencies up, or as soon as a script has an optional dependency, an
   `extras` case, or a self-heal need. Below that, a bare `require` is the
   smaller and more honest thing.

   **`hud` is ported (1.4.37)** under exactly that rule: fourteen
   dependencies, an optional one (`fAwesome6`) and an `extras` case
   (`moonloader.download_status`). It uses `globals = true`, because a
   single-file script with hundreds of use sites consumes its modules as bare
   globals - which is what its hand-written `_G[dep.var] = module` pass did.
   The port also changed a behaviour worth naming: the old loader recorded a
   missing module and carried on into a script that could not work, so a
   missing `mimgui` surfaced as "attempt to index a nil value" near the menu
   rather than as its own name.

   Its self-updater takes tier 1's `deps.validate` / `deps.installFile`, the
   same way `reports` does. It used to download straight over the live
   `hud.lua`, so a truncated transfer or a 404 page replaced a working install
   with rubbish and the reload then failed on a file the user had no copy of.
   It stages to a `.new`, checks the bytes PARSE, and only then installs.

   It also takes `akacross.textdraw`, `akacross.scale` and `akacross.cursor`.
   The textdraw one is the largest single win in that script, and worth
   recording as that module's second real customer: `hud` swept **0..4000** to
   re-apply its HZG overrides and **0..3000** to read the turf colour, the
   second of those on every HUD tick with a `break` that never fires on a
   server with no turf textdraw. Bounding both to `MAX_ID` and remembering the
   matched slots took a settings-slider drag from ~4,001 existence checks per
   frame to 2, and the per-tick turf scan from up to 3,001 to one.

   **What `hud` deliberately does NOT take:** `downloads` (it is built on
   `lanes`, and pulling `lanes.lua` + `core.dll` into a script that uses the
   plain `downloadUrlToFile` native for a one-shot icon fetch costs more than
   the 29 lines it would replace); `style` (its theme is a different design,
   not a copy that drifted); `window` (its two windows are plain `imgui.Begin`
   with no custom chrome, so the registry would be a redesign, not a port);
   `config` (it switches between arbitrary config FILES at runtime, which the
   named-registry model does not express); and `claims` (a `badge.render`
   claim would correctly stop hud's Badge row drawing whenever `badge.lua` is
   loaded - but that silently removes a row the user configured, so it wants
   asking about rather than assuming).

   *Most of that list has since been taken:* `style`, `window`, `keybinds`,
   `interface`, `functions`, `player` and `updater` in 1.4.38, `config` in
   1.4.37 (see below), and `rp` in 1.4.39. What still stands is `downloads`
   and `claims`, for the reasons above.

   **`rp` 0.2.2 fires on the defaulted->known transition.** `state.profile`
   is seeded with `profiles.hrp` so accessors have something to read before
   detection, which meant detecting Horizon handed `setProfile` the table it
   already held, `changed` was false, and `onProfile` never fired. Any mod
   driven purely by that listener was live on Paraiso and inert on Horizon;
   `wanted` and `vstorage` escaped only because they also select at load and
   treat `onProfile` as a correction. hud did not, and shipped a Horizon
   profile that never ran (1.4.39-1.4.40). Going from defaulted to KNOWN is a
   real event and is reported as one, `wasKnown` keeping it to a single fire.

   **`rp` (1.4.39) is the one taken for an answer rather than for code.** hud
   needs "which server is this" because its server-textdraw overrides are
   matched by letter-size signatures that differ per server, and the one signal
   that does not depend on the draws being identified is the server NAME. It
   takes `attach`/`onProfile`/`profileId` and nothing else - explicitly passing
   `claims = false` so it does not take the `rp.stats` claim it would never
   use. See [HUD.md](HUD.md#the-server-textdraws-1439).

   **`config` was on that list and came off it (1.4.37).** The objection was
   that `hud` picks its config FILE at runtime while a Set maps one name to one
   filename - which is true, and the answer is to re-open the Set on a switch
   rather than to keep a private JSON layer. Two things did NOT move and are
   worth naming, because they are the parts a registry cannot own:

   - **Reset.** cjc snapshots a table on first load to implement
     `cfg("reset")`, so after a file switch its idea of "the defaults" is the
     previous file's contents. The mod keeps its own defaults table and writes
     from that.
   - **Pruning.** cjc MERGES, which is right for adding a field in a later
     version and wrong for removing one. The mod's `applyDefaults` drops keys
     the defaults no longer have, which is what lets a converted v1 file's dead
     arrays disappear instead of living in the table forever.

   The clear hook earned its keep immediately: `anchors` is a LIST, and a saved
   three-entry list merged over a six-entry default leaves the last three
   defaults behind, so deleting an anchor would never stick.

   **cjc CANNOT READ A FILE IT DID NOT WRITE, and that is worth knowing before
   the next mod moves onto `config`.** cjc encodes every scalar as
   `["number", 2]` / `["boolean", true]`. Handed a plain JSON file - which is
   what a hand-written saver produces - its merge skips every bare scalar with
   `CarboneumJsonConfig(load): weird shit happens..` (144 of those in one hud
   load), and for a bare ARRAY it assigns element **[2]**, so
   `"sizex":[130,130,130,130,130,115,22]` arrives as the number `130` and
   `"pos":[{...},{...}]` arrives as a list of empty tables. It does not fail;
   it quietly produces wrong data.

   So **a move onto `config` is not a migration path for the old file** - the
   old data is destroyed on the way in. `hud` gates on a schema `version` read
   from the RAW BYTES before cjc sees them, and renames anything older to
   `.v1.bak`. A mod that wants to carry its old config forward has to read it
   with a plain JSON decoder FIRST, convert, and only then hand the result to
   the Set.

   The version has to come off the file, not the table: `hud`'s first attempt
   applied its defaults (which carry the current version) and then merged the
   file over them, so the check read its own answer and the migration never
   ran once.

   **`badge` crossed that line in 0.4.0 and is now ported.** Moving its menu to
   mimgui took it from two dependencies to twelve - `config`, `scale`, `style`,
   `window`, `cursor`, `interface`, `imgui_funcs` on top of mimgui itself - plus
   the optional-`deps` fallback every ported script carries. That is the rule
   being applied, not overturned: the port followed the dependency count, it did
   not lead it.
3. Lift autobind's download/stage/validate/self-heal into `deps` tier 1. Point
   autobind at it. Biggest single diff; behaviour must not change.
4. `lib/akacross/claims.lua` + the registry. Port the cursor conflict? **No** -
   cursor already works, leave it. Start with chat commands and keybinds, where
   the failure today is silent shadowing.
5. Extract FastMap (MANIFEST section 10) on top of both, with `deps` tier 1 and
   a `map.render` claim from day one.

Steps 1-2 are independently useful even if the FastMap split never happens.

---

## 7. Open questions

1. `deps` becomes a dependency of every mod, and it is the thing that downloads
   dependencies. Bootstrap ordering: does each mod ship a ~20-line inline stub
   that can fetch `deps` itself, or is `deps` a hard install prerequisite?
2. Is `config/akacross/` the right home for cross-mod state, given `config/` is
   git-ignored and user-owned? A registry is machine state, not user config.
3. `onScriptMessage` as wakeup writes to `moonloader.log`. Acceptable noise, or
   use a `--` prefixed convention that a log filter can drop?
4. Priority numbers in claims are a magic constant. Better: explicit
   `supersedes = {'autobind'}` on the claiming mod?
5. Does `reports.lua`'s self-updater (it downloads its own script and reloads)
   belong in `deps` too, or stay separate from dependency healing?
