# hud

The customisable on-screen HUD: bars, the weapon icon, the wanted stars and
eleven lines of text, each positioned, sized, coloured and faced by the user.

This document covers the **1.4.38 menu rebuild** and the **1.4.39 server
split**. The drawing side - the element/part model, the renderer seam and the
font layer - is unchanged and is described in [API.md](API.md) under
`akacross.draw`, `akacross.draw_imgui`, `akacross.render` and `akacross.fonts`.

The repository is `gitlab.com/akacross/hud` as of 1.4.39. It was the last mod
here on GitHub.

---

## What changed, and why

hud was the last mimgui mod in this set still drawing its own menu by hand.

The panel it replaced was a 460x76 strip of ten buttons over a fixed 376x289
child, with an 85x392 column of five *unlabelled* square icon buttons down the
left and a 376x36 footer - every one of those a literal pixel offset handed to
`SetCursorPos`. Alongside it sat a **second top-level window** whose entire job
was to ask "are you sure?". Its theme was a dark red nothing else wore.

Meanwhile driving, wanted, vstorage, fastmap and reports had all converged on
the same shape: a titled window from `akacross.window`, a horizontal tab bar
over a *measured* body, a Save/Reset/Close footer, `akacross.style`'s theme, and
prompts as modal popups inside the window that raised them.

So hud is that now. Nothing about what the mod *does* changed.

### Two things forced the split into `lib/hud/`

1. **The 200-locals ceiling.** The entry is one Lua function, and the menu was
   1,200 of its lines. It was within a few names of the limit; the comment in
   the file it replaced said as much and grouped constants into tables to buy
   room.
2. **It stopped being true that it could not split.** The reason it was one
   file was that the updater downloads `hud.lua` and nothing else. Every other
   mod here solved that years ago with a self-heal block, and hud has one now:
   the entry checks its `lib/` files before its first `require()`, fetches
   whatever is absent from the release repo, and reloads once.

---

## Layout

```
hud.lua                    entry: config, state, drawing, textdraws, updater,
                           the window registration and the keybind poll
lib/hud/widgets.lua        the allocation-free widget layer
lib/hud/settings.lua       the tabs
lib/hud/files.lua          the configuration picker and its six prompts
```

| File | ~Lines | Owns |
|---|---|---|
| `lib/hud/widgets.lua` | ~280 | Scratch and persistent buffers, interned widget ids and labels, `checkbox` / `drag1,2,4` / `colorEdit` / `tooltip` / `help`. Requires only shared modules and takes no injection, so the tabs treat it as a vocabulary. |
| `lib/hud/settings.lua` | ~640 | The Elements, Anchors, Renderer, Server and Interface tabs, plus the header card. Takes everything the entry owns through `setup(ctx)`. |
| `lib/hud/files.lua` | ~330 | The Files tab, the throttled directory scan, and the six confirmation prompts as one spec-driven modal. |

**No globals.** The tab modules read nothing out of `_G`; the entry hands them
`hud`, `settings` and every callback in `setup()`. That is the rule the autobind
de-globalization pass settled on for new modules, and here it is forced anyway -
the entry holds both config tables as locals.

Both tables are safe to capture once: the config layer mutates them in place
(`applyDefaults` overwrites fields, it never replaces the table), so the
reference survives a reload and a reset alike.

---

## The tabs

Ten became seven.

| Tab | Was |
|---|---|
| **Elements** | The seven bar/icon/star tabs **and** the Other tab - eighteen entries behind one list. Eight tabs became one, which is most of why the strip could go. |
| **Anchors** | "Move" |
| **Renderer** | Half of "Screen" |
| **Server** | The other half: the server's own textdraws, now per server (below) |
| **Files** | The combo wedged into the footer |
| **Keybinds** | *New.* The menu had no keyboard shortcut at all, only `/hud`. |
| **Interface** | *New.* The shared UI-scale tab every other mod carries. |

The five side buttons are gone as buttons: **Power** is a state the header card
reports and toggles, **Save / Reload / Reset** are the footer, and **Update**
lives on the Files tab next to the thing it updates.

### The header card

`akacross.style.card` - see [API.md](API.md#cardopts---the-status-card). It
reports whether the HUD is on, which renderer is drawing, how many parts are
being drawn and which config file is being edited; clicking the headline is the
master toggle.

Two of those facts were previously an unlabelled green square and a checkbox
three tabs away.

---

## UI scale: why this mod does not re-bake its font atlas

driving, wanted, vstorage and fastmap all rebuild the atlas when the UI scale
changes - `Fonts:Clear()`, re-add every face at the new pixel size,
`CreateFontsTexture`. Baking at the exact size beats stretching one, so where
that is available it is the right answer.

**It is not available here.** `akacross.draw_imgui` owns this state's atlas and
it is append-only by construction: `Fonts:Clear()` would destroy the faces it
has baked for every text element on screen, and it has no way to learn that
happened. So hud's menu scales the bake it has, through `FontGlobalScale`.

That costs the HUD nothing, and the reason is not obvious: `FontGlobalScale` is
applied by ImGui's *widget* layer, and `draw_imgui` draws through
`ImDrawList::AddText` with an **explicit** font pointer and size. An explicit
size is not scaled. So the slider moves the menu and leaves the HUD exactly
where the user put it - which is also why the Interface tab offers one scale
rather than the two the overlay mods need.

---

## Keybinds

Two, in autobind's shape, edited through `akacross.keybinds`:

| Bind | Default | |
|---|---|---|
| `Menu` | ALT + J | Shows or hides the settings window |
| `Toggle` | unbound | Switches the whole HUD on and off |

They are registered as their **own** config set rather than as keys inside
`settings`: the binds carry cdata, and `settings` is a plain-Lua table walked by
`applyDefaults` and `deepCopy` - which copies a cdata object by *reference*, so
the defaults and the live value would end up sharing one and "reset" would be a
no-op for the toggles.

The usual repair applies: if **every** bind is empty on load the defaults are
restored and saved. One empty bind is a user who hit Clear; all of them is a
config written before the clear hook was right, and a dead menu key with no way
to notice why is the worse failure by a distance.

---

## What hud no longer carries

The rebuild's second half was deleting things this file had that the shared
runtime already owned, or that nothing else could reach because they lived here.

**Deleted, because the shared runtime already had them:**

| Was in hud.lua | Lives in |
|---|---|
| `firstToUpper` | `string:upperFirst()` - `akacross.functions` |
| `formatNumber` | `akacross.functions` |
| `contains` | `table.contains` - `akacross.functions` |
| `findPlayer`, `getZoneName`, `getSubZoneName`, `getVehicleName` | `akacross.functions` |
| `compareVersions` | `deps.compareVersions` |
| `formattedAddChatMessage` | `akacross.functions` - see below |
| `checkForUpdate`, `updateScript`, `downloadFiles` | `akacross.updater` |
| ~90 lines of `selfHeal` | `deps.selfHeal` |

Deleted rather than aliased. An alias is a second name for one function, which
is precisely how two different `formattedAddChatMessage` came to exist: five
mods had one that embedded the colour as a `{RRGGBB}` tag, and hud's took the
colour as `sampAddChatMessage`'s own argument - and named its message parameter
`string`, shadowing the standard library inside the function.

**Moved out, because nothing else could reach them:**

`akacross.player` now owns the sprint and breath meters, ammo-in-clip, the
wanted level, speed conversion, the compass, the camera heading and the zone
lookup. They were never HUD facts - they are "what is the player doing right
now", which every overlay in this set asks.

Two changed shape on the way, and the second was a latent bug:

- `updateSprintStatus` was a void writing three file-locals; it is
  `feedSprint(pressed) -> bool`, so the sampler is not tied to one mod's key
  constant.
- `getCustomZoneName` read a `customZones` **global**. The zone set is
  per-server, so it is registered with `setCustomZones()` - which is also what
  lets a second mod on a different server register a different one without the
  two fighting over one name.

Every magic number gained a name in the move: `0xB7CDB4` and `/ 31.47000244`
are `ADDR.SPRINT_ENERGY` and `SPRINT_FULL`, with the struct field each one reads
written beside it.

## The server textdraws (1.4.39)

Both servers this set targets draw seven things of their own that hud
repositions, recolours or hides: the turf name, the turf-owner label, the
wristwatch, the logo, the three-part HP bar, the HP readout and the armour
readout.

> **Status (1.4.41): both work.** Horizon's overrides were never *running* -
> see *The bug underneath* below - and three of its signatures were wrong on
> top of that. Both are fixed from a live `/hud td` capture.

### Why it is a table and not two copies

hud supported **Horizon** until 1.4.37, with `hzg` spelled into forty call
sites. 1.4.37 replaced that wholesale with **Paraiso** and spelled `pgaming`
into the same forty. Restoring the first without losing the second meant either
a third set of forty names or making the server data - so `SERVERS` in
`hud.lua` carries everything that differs and the code carries everything that
does not.

| | Horizon (`hrp`) | Paraiso (`prp`) |
|---|---|---|
| turf signature | `0.23999999463558` / `1.2000000476837` | *the same* |
| wristwatch | `0.5` / `2` | `0.58999902009964` / `2.2999980449677` |
| logo | `0.3199990093708` / `1.3999999761581` | `0.25999999046326` / `1.6200000047684` |
| HP/armour text | `0.25999900698662` / `1.2000000476837` | `0.32062301039696` / `1.1100000143051` |
| logo fallback | `hzgaming.net` | `pgaming.net` |
| turf string | sent as-is | prefixed `Owner: `, stripped |
| HP/armour position | `577` or `611`, y `65`/`43` | `622.25`/`623.125`, y `65.33332824707`/`43.166641235352` |

The **HP bar is not per server**: both stack its three draws at the same two
positions, so it is matched once. The `ShowTextDraw` RPC carries pre-placement
coordinates (`546,66` / `548,68`) and the pool sweep sees the laid-out ones
(`610,68` / `608,70`), which is why `hpBarIndex` takes them as arguments.

**Signatures are compared as strings.** These are floats that arrive over the
network and never survive an `==` against a literal, so the *formatted* value is
what is matched - which is also why they are written to full printed precision
rather than rounded. `hud_test.lua` asserts they still stringify to what the
script matches, so a LuaJIT formatting change cannot make them quietly stop.

### The bug underneath (1.4.41)

Before any of the signatures mattered, **the overrides were not running on
Horizon at all**. The dump said so on its second line:

```
server:  Horizon Roleplay (hrp)
profile: no SERVERS entry - overrides inert
```

`akacross.rp` seeds `state.profile` with `profiles.hrp` so that every accessor
has something to read before detection happens. So detecting Horizon handed
`setProfile` **the table it already held**, its `changed` test was false,
`fireProfile()` was skipped, and the `onProfile` listener that sets `srvKnown`
never ran. Paraiso worked for exactly one reason: it is not the default.

This is a trap for any consumer driven purely by `onProfile`. `wanted` and
`vstorage` escaped it only because they also select a source at load and treat
`onProfile` as a correction. **rp 0.2.2** treats defaulted-to-known as the
transition it is and fires once on it, `wasKnown` keeping it to once - which
fixes every consumer at once. hud additionally adopts whatever `attach()`
returns, with `adoptProfile` made idempotent, so an install carrying an older
`rp` cannot end up inert again.

### Signatures still cannot be recovered, only captured

Three of Horizon's *were* genuinely wrong, and no amount of reading old code
would have said which:

| row | what was wrong |
|---|---|
| turf owner | Horizon draws it at **letter size 0 / 0**, so the shared size gate rejected it before the text test |
| HP bar | swept for `610/68` and `608/70` - **Paraiso's** laid-out positions, copied across in the 1.4.37 rename |
| bar pieces | two of the three sit at **exactly** `548 / 68.8`; position cannot separate them |

The owner label is matched by its text now and the turf *name* by letter size,
which is correct on both servers since Paraiso's label carries that text too.
The third bar draw is identified by the pool split - SA-MP ids `0..2047` are
global textdraws and `2048..2303` per-player, and the fill is the per-player
one because it is what changes with your health.

The rest of the Horizon table was right all along, which is the point: a
profile that never runs looks exactly like a profile with wrong numbers.

Paraiso's work because they were derived **against the live server** in 1.4.37.
That is the only way these are ever obtained. `hud_test.lua` now carries the
Horizon capture verbatim as a fixture - the one assertion in that file that can
say the profile is *right* rather than merely self-consistent, since every
other server assertion builds its pool from the profile.

So a profile carries a `verified` flag, the entry says on connect when a
server's signatures are unverified rather than reporting overrides as active
while doing nothing, and there is a command for producing real ones:

```
/hud td            every live textdraw, in the form SERVERS wants
/hud td turf       filtered by text
```

It prints `id`, position and letter size as the **exact strings** the matchers
compare, plus how many draws the active profile matched - which is the number
that says whether a profile is real. The full dump goes to `moonloader.log`.
The read-only count comes from `srvApplySlot(id, 'probe')`, the same matcher the
overrides use, so the diagnostic cannot drift from the thing it diagnoses.

Both profiles are `verified = true` as of 1.4.41. The wristwatch is the single
row still taken on trust - it is not in the pool unless the player is wearing
one, so it was not in the capture, and the table says so.

### Which server is live

From [`akacross.rp`](API.md), which already answers "what server is this" for
autobind, wanted and vstorage, and answers it from the server **name** rather
than from the very draws being identified. The entry polls `rp.attach()` from
its main loop until a profile lands, and `rp.onProfile` hands it to
`adoptProfile`.

hud **declines the claim**. `rp.setup` takes `rp.stats` when given a script
name, so that one mod does the asking and the rest parse the reply; hud never
sends `/stats` and never reads a stats line, so it passes `claims = false`
rather than sitting on a claim a mod that needs it would then go without.

### Inert until it is sure

Nothing touches a server textdraw while the profile is unknown, or while it is
a server `SERVERS` has no entry for (rp knows Lawless, hud does not).

This is **stricter than before 1.4.39**, and deliberately: the turf signature is
the one both servers share, so any third server drawing anything at that letter
size had its turf draw moved off screen by a HUD that had never heard of it.

### One layout each

The two servers draw these in different places - a logo x of `635.7` is the
top-right corner on Paraiso and past the edge of Horizon's - so a single set of
coordinates cannot be right on both. The config is two tables, `hud.hrp` and
`hud.prp`, keyed by rp's profile id.

The **Server tab picks which one it edits**, defaulting to the detected server
and letting the user choose the other, because you cannot drag Paraiso's logo
into place from Horizon and because the server is unknown in single player -
which is where this actually gets set up. Writes to the live draws are
suppressed while editing the server you are not on; the values still save.

### Migration

The rows were named after the servers themselves: `hzg` before 1.4.37,
`pgaming` from 1.4.37 to 1.4.38. `migrateServerKeys` copies either onto the
profile-keyed table field by field, then clears the old key so `pruneUnknown`
does not report it as stale and drop it.

The schema version does **not** move for this. The rows are unchanged - same
seven, same fields - so it is a key rename, not a schema change, and cjc has
already decoded the file by the time it runs. That is exactly what was not true
of the v1 migration this file buried; see the note above the defaults in
`hud.lua`.

### The bug this found

`setHPAndArmorText` wrote the readouts at `0.25999900698662 / 1.2000000476837`
- Horizon's text size, hardcoded, and left untouched by the 1.4.37 rename. On
Paraiso that both resized the readout and took the slot out of
`sig.textW`/`sig.textH`, which is what the sweep matches on, so the row stopped
responding until the server redrew it. It reads `SERVERS[srvId].textSize` now.

### The health pool

Both servers run the player on a large internal HP figure so damage has finer
granularity than 100 steps, and what is meant to be *shown* is the remainder on
top of it. The pool is per server; the visible maximum is 100 on both, which is
already what `hud.elements.health.max` holds.

| | pool | shown |
|---|---:|---:|
| Horizon | 5,000,000 | 0-100 |
| Paraiso | 3,000,000 | 0-100 |

So `sampGetPlayerHealth` returning `3000050` is 50 HP on Paraiso and something
else entirely on Horizon - which is exactly why it lives in the profile rather
than in a shared list.

It **was** a shared list. `serverHp = {3000000, 5000000, 8000000}` in the
config, subtracted like this:

```lua
for _, v in pairs(hud.serverHp) do
    if hp >= v then hp = hp - v end
end
```

`pairs` has no defined order, so on Horizon a run that reached 3,000,000 first
turned `5000050` into `2000050` and stopped - a plausible-looking number, wrong
by two million, and different between launches. It had been commented out
rather than fixed. The list is gone from the config with it, and
`pruneUnknown` drops the key from existing files.

A value below the pool is passed through untouched: that is a server not using
one, or a read taken before the pool is applied, and subtracting would turn a
real 50 into a negative. The result is clamped to the maximum, because the bar
divides by it. Spectated players are exempt - their health arrives already
reduced through the sync, so subtracting again would read every one of them
as 0.

---

## Self-heal

The implementation is `deps.selfHeal` - one copy for the five mods that had
five. `OWN_FILES` in `hud.lua` lists the files this mod ships and may serve. Third-
party libraries (mimgui, vkeys, fAwesome6, samp.events, carbJsonConfig) are
excluded - not ours to redistribute, and a missing one is a broken install
rather than a missing update.

It runs **before a single `require()`**, because the point is to repair the very
files `require()` is about to look for, and it uses nothing but MoonLoader
natives - reaching for `akacross.deps` would make the healer depend on a file it
exists to restore. A marker file is the loop guard: if the same files are still
missing after a repair attempt, it reports and stays down.

The healer cannot repair the file it lives in, so the entry keeps a ~12-line
bootstrap above it that fetches `lib/akacross/deps.lua` alone and reloads. That
duplication is irreducible: it is what makes the shared thing loadable.

It also bails out when `lua_thread` is not a table. That is a capability check,
not a test hook: the healer needs `lua_thread.create`, and outside the game
(the host suite loads this whole chunk under stubbed natives on Linux) the
backslash paths would report every file missing and the download would have
nowhere to go.

**Deploy note:** the release repo must carry `lib/` as well as `hud.lua`, or
every existing install that takes the update will self-heal, fail, and report.
It must also carry `hud.txt` (the version file the update check reads) and
`resource/hud/weapons/*.png` (the 46 icons the entry downloads on first run) -
both of those were missing from the GitHub repo entirely, so neither the update
check nor the icon download had ever worked from it.

---

## Tests

```bash
./lib/hud/test/check.sh
```

Syntax, the dependency-binding audit, the unresolved-globals audit, the
module-export audit, and the host suite (`lib/hud/test/hud_test.lua`), which
loads the real `hud.lua` chunk under stubbed natives.

The two properties worth knowing about:

- **Every tab and every element renders.** The Elements pane replaced eight
  tabs, so it is driven through all eighteen selections, not just opened.
- **A steady frame allocates nothing.** Both cdata and Lua garbage, held to
  0.05 KB/frame. It is measured as the **minimum of five samples**: what is
  being measured is a floor, noise can only add to it, and a single sample
  against that threshold was a coin flip - three consecutive runs of unchanged
  code gave 0.0088, 0.0261 and 0.0700 KB/frame.

Three real allocations were found by that check during the rebuild and are worth
naming, because all three look free:

- `idFor(prefix, a .. b)` - the concatenation happens *before* the cache can be
  consulted. Hence `idFor2`.
- `style.section(title)` built an `ImVec4` and called `title:upper()` per call.
  Both are hoisted now, in the shared module, for every mod.
- A status line that prepended one cached string to another. The `..` was the
  whole overrun.
