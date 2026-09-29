# SortiePlus

A Windower 4 addon for Final Fantasy XI that tracks Sortie objectives, NMs, bosses
and loot — and switches its sector display for you as you move through the zone.

Forked from **Sortie v3.0 by Mirdain**. See [Credits and licensing](#credits-and-licensing).

## What's new in 1.1

- **Shard tracker.** One always-visible line — even in minimal mode — showing the
  A–D Ra'Kaznar shards for the current run:

  ```
   Shards: A:X B:o C:_ D:_
  ```

  Green `X` = shard in hand, yellow `o` = its chest (#A3–#D3) has spawned but you
  haven't looted it yet, `_` = not earned. Resets when you re-enter Sortie.
- **Boss order line.** `//sort order dhabcm` sets your kill order (a–h, `m` =
  Aminon); the window shows `Order: D > H > A > B > C > Aminon` with defeated
  bosses red, the current target green, the rest blue. Boss kills are detected
  from chat. `//sort order clear` clears it; `//sort save` makes it your default.
- **Integrated floor bar.** The clickable `[A]–[H]` selector is now the first line
  of the main window instead of a separate window. The click map follows your font
  size, and a drag (when unlocked) is never mistaken for a click.
- **Lock/unlock.** `//sort lock` pins the window; `//sort unlock` lets you drag it.
- **Darker default background** (alpha 102 → 180). A saved 1.0 default is bumped
  once automatically; any custom alpha you set is kept.

## What "Plus" adds

**Auto-sector on NM target.** Target a sector's NM and the display flips to that
sector. Running A → B → C needs no commands at all — the addon follows you.

It recognises the eight sector bosses (Ghatjot, Leshonn, Skomora, Degei, Dhartok,
Gartell, Triboulex, Aita), Aminon, and the eight roaming widescan NMs. Switching
this way does everything a manual switch does: re-requests widescan tracking on
that sector's NM, resets the boss timer and element counter, and scans for Bitzers
in the basement sectors. It fires only on an actual change of sector, so
re-targeting the NM you are already on is silent.

```
Sortie: Sector C <- Skomora
```

Toggle with `//sort auto` (on by default). Under the hood every path that changes
sector — the commands, the floor-bar click, SuperWarp arrival, and now targeting —
routes through one `set_sector()`, so they cannot drift apart.

## Features

- **Complete objective data** for all 8 sectors (A-H) sourced from bg-wiki, FFXIclopedia, and FFXIAH community research
- **Chest type labels**: [Brn] = Brown (temp items), [Blu] = Blue Casket (earrings/sapphires), [Red] = Red Coffer (better drops)
- **Reward display**: Brown chests show what temp item they grant (Key, Plate, Shard, Metal, Sheet)
- **NM tracking** via widescan packets with distance display and death detection
- **Auto-sector on NM target** — see above
- **Bitzer tracking** for basement sectors (E-H)
- **Objective progress counter** parsed from in-game status reports (X/8 or X/4)
- **Aurum Coffer tracker**: Shows which of the 4 upstairs NMs have been killed
- **Boss info**: Weakness, element procs, and Metal effects per sector (toggleable)
- **Proc echo**: on D (Degei) / H (Aita), every boss TP move fires a game `/echo`
  in the form `Flaming Kick >> [Water]`. Repeats are always echoed — a second use of
  the same move opens a fresh proc window even when the element is unchanged.
  Vivisection echoes `Vivisection >> [NONE]` (absorb cleared). Toggle: `//sort echo`.
- **Reive info**: Spawn conditions and Naakual kill orders for basement sectors
- **Basement boss drops**: Shows which Fragment each boss drops for Aminon access
- **Shard tracker**: always-visible A–D shard checkboxes (in hand / chest up / not earned)
- **Boss order display**: your planned kill order, colored by progress
- **Clickable floor selector** (first line of the window) and keyboard commands

## Requirements

Windower 4. No external dependencies — everything it uses (`packets`, `config`,
`resources`, `texts`) ships with Windower.

## Installing

1. Copy `SortiePlus.lua` into `Windower/addons/SortiePlus/`.
2. `//lua load sortieplus` (or add it to your `init.txt`).

Two things to know if you are coming from the original Sortie:

- **Unload the original first.** SortiePlus keeps `//sortie` and `//sort` as
  aliases so it is a drop-in replacement. Running both addons at once means two
  handlers answering the same command — pick one.
- **Window positions do not carry over.** Windower stores settings per addon name,
  so SortiePlus starts at the default position. Either drag the window where
  you want it (`//sort unlock` first) and `//sortieplus save`, or copy your old
  `Windower/addons/Sortie/data/settings.xml` into `Windower/addons/SortiePlus/data/`
  before first load.

Upgrading from SortiePlus 1.0: the separate floor-selector window is gone — the
bar is now the first line of the main window. A leftover `<Floor>` block in your
saved `settings.xml` is harmless, and a saved background alpha of 102 (the old
default) is bumped to the new darker default once; any other value is kept.

## Commands

All three prefixes work: `//sortieplus`, `//sortie`, `//sort`.

| Command | Description |
|---------|-------------|
| `//sort [a-h]` | Switch sector display |
| `//sort auto` | Toggle sector auto-switch on NM target (default on) |
| `//sort on/off` | Toggle addon |
| `//sort boss` | Toggle boss info panel |
| `//sort obj` | Toggle objectives display |
| `//sort loot` | Toggle loot/galli display |
| `//sort all` | Minimal mode (NM + Bitzer + Order + Shards only) |
| `//sort echo` | Toggle boss proc `/echo` on D/H (default on) |
| `//sort order xyz` | Set boss kill order (a–h, `m` = Aminon; `clear` to clear) |
| `//sort lock` / `unlock` | Lock window / unlock for dragging |
| `//sort bscan` | Scan Bitzers zone-wide |
| `//sort save` | Save settings + order as default |
| `//sort track #` | Track mob by widescan index |
| `//sort scan #` | Query mob info by index |
| `//sort debug` | Toggle debug output |
| `//sort zone` | Show current zone ID |
| `//sort help` | Show command list in-game |

## How it works

The display auto-activates when entering Outer Ra'Kaznar (Zone 133/189).

Sector selection has four paths, all equivalent: click [A]-[H] in the floor bar,
type `//sort a` through `//sort h`, target that sector's NM, or arrive via
SuperWarp.

NM tracking uses widescan packets — you must be on the correct floor (A-D upstairs,
E-H requires entering the basement).

Bitzers are not mobs and can only be tracked within ~50 yalms.

The addon parses incoming chat for objective completion status reports and NM death
messages.

## Sector quick reference

- **A-D** (Ground Floor): 8 objectives each (5 Brown + 2 Blue + 1 Red)
- **E-H** (Basement): 4 objectives each (1 Brown + 2 Blue + 1 Red)
- **Aurum Coffer (F1)**: Kill all 4 upstairs NMs (Obdella, Porxie, Bhoot, Deleterious)
- **Aminon**: Requires Fragments 1-4 from basement bosses (Dhartok, Gartell, Triboulex, Aita)

## Data sources

Objective data compiled from:
- [bg-wiki Category:Sortie](https://www.bg-wiki.com/ffxi/Category:Sortie)
- [FFXIclopedia Sortie](https://ffxiclopedia.fandom.com/wiki/Category:Sortie)
- [FFXIAH Sortie Guide](https://www.ffxiah.com/node/469)
- [bg-wiki Sortie Strategies](https://www.bg-wiki.com/ffxi/Sortie_Strategies)

Objectives marked with `(?)` are community-speculated but not fully confirmed.

## Note on windowed mode

If clicking the floor selector doesn't work, you're likely in windowed mode. The
window taskbar (50px) and title bar (25px) offset mouse coordinates. Adjust your
game resolution settings accordingly.

## Credits and licensing

- Original **Sortie** addon by **Mirdain**.
- Objective, chest and boss data expanded in v3.0 from the community sources listed above.
- Chest ID mapping derived from Cypan's 2026-07-28 Sortie log analysis.
- **SortiePlus** fork, auto-sector feature and single-owner sector refactor by
  **Cypan (Bahamut)**.

> **No licence file is included.** The upstream Sortie addon shipped without a
> licence, so the terms this derivative may be redistributed under are not
> established. If you are Mirdain, or know the original terms, please open an
> issue and a matching licence will be added.
