# hud

A fully customisable on-screen HUD for SA-MP: health, armour, sprint, breath
and vehicle bars, the weapon icon, the wanted stars, and eleven lines of text -
each one positioned, sized, coloured, aligned and given its own font.

Everything is dragged into place in game. Anchors can be renamed, added and
removed, and every element hangs off the anchor you give it.

## Install

Drop the contents of the zip into your `moonloader` folder, keeping the tree.
Everything it needs is in `lib/` and `resource/`.

If a file under `lib/akacross/` or `lib/hud/` is missing or truncated, the
script repairs it from this repository on the next load and reloads itself.

## Commands

| | |
|---|---|
| `/hud` | the settings window |
| `/hud render` | which renderer is drawing, and which font each text row actually got |
| `/hud td [filter]` | dump the server's textdraws, and how many this script matches |

The menu also has a keybind, rebindable on the Keybinds tab.

## Two renderers

The bars, icons and text can be drawn by the game's own renderer or by an
ImGui draw list, switchable on the Renderer tab. The ImGui one gives smoothed
edges, real transparency and optional rounded corners on the bars; it measures
its own text against the game's and corrects the difference, so a row comes out
the same size either way.

## The server's own textdraws

Two servers are supported - **Horizon** and **Paraiso** - and the right one is
picked from the server you join.

Each draws seven things of its own that this can reposition, recolour or hide:
the turf name, the turf owner label, the wristwatch, the logo, the HP bar, and
the HP and armour readouts. They sit in different places on the two servers, so
each server keeps its own layout and neither overwrites the other. The Server
tab has a picker, so a layout can be built for a server you are not currently
on - including from single player.

On any other server these stay switched off rather than guessing.

## Configuration

Configs live in `config/hud/` and you can keep as many as you like, switching
between them on the Files tab. Each file carries a schema version; one written
before the per-element layout is set aside rather than half-read.

## Notes

`docs/HUD.md` documents the menu, the renderer seam, the server textdraw
profiles and the self-repair, for anyone wanting to add a third server.
