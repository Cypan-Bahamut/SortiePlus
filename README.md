# SortiePlus v3.0

Upgraded version of Sortie by Mirdain, modified by Cypan (Bahamut).
Install to `Windower/addons/SortiePlus/` and load with `//lua load sortieplus`.
The `//sort` and `//sortie` commands are unchanged.

Comprehensive Windower addon for tracking Sortie objectives, NMs, and boss info in FFXI.

## Features

- **Complete objective data** for all 8 sectors (A-H) sourced from bg-wiki, FFXIclopedia, and FFXIAH community research
- **Chest type labels**: [Brn] = Brown (temp items), [Blu] = Blue Casket (earrings/sapphires), [Red] = Red Coffer (better drops)
- **Reward display**: Brown chests show what temp item they grant (Key, Plate, Shard, Metal, Sheet)
- **NM tracking** via widescan packets with distance display and death detection
- **Bitzer tracking** for basement sectors (E-H)
- **Objective progress counter** parsed from in-game status reports (X/8 or X/4)
- **Aurum Coffer tracker**: Shows which of the 4 upstairs NMs have been killed
- **Boss info**: Weakness, element procs, and Metal effects per sector (toggleable)
- **Reive info**: Spawn conditions and Naakual kill orders for basement sectors
- **Basement boss drops**: Shows which Fragment each boss drops for Aminon access
- **Clickable floor selector** and keyboard commands

## Commands

| Command | Description |
|---------|-------------|
| `//sort [a-h]` | Switch sector display |
| `//sort on/off` | Toggle addon |
| `//sort boss` | Toggle boss info panel |
| `//sort save` | Save position settings |
| `//sort track #` | Track mob by widescan index |
| `//sort scan #` | Query mob info by index |
| `//sort debug` | Toggle debug output |
| `//sort zone` | Show current zone ID |
| `//sort help` | Show command list in-game |

## How It Works

The display auto-activates when entering Outer Ra'Kaznar (Zone 133/189).

Select your sector by clicking [A]-[H] in the floor bar or typing `//sort a` through `//sort h`.

NM tracking uses widescan packets - you must be on the correct floor (A-D upstairs, E-H requires entering basement).

Bitzers are not mobs and can only be tracked within ~50 yalms.

The addon parses incoming chat for objective completion status reports and NM death messages.

## Sector Quick Reference

- **A-D** (Ground Floor): 8 objectives each (5 Brown + 2 Blue + 1 Red)
- **E-H** (Basement): 4 objectives each (1 Brown + 2 Blue + 1 Red)
- **Aurum Coffer (F1)**: Kill all 4 upstairs NMs (Obdella, Porxie, Bhoot, Deleterious)
- **Aminon**: Requires Fragments 1-4 from basement bosses (Dhartok, Gartell, Triboulex, Aita)

## Data Sources

Objective data compiled from:
- [bg-wiki Category:Sortie](https://www.bg-wiki.com/ffxi/Category:Sortie)
- [FFXIclopedia Sortie](https://ffxiclopedia.fandom.com/wiki/Category:Sortie)
- [FFXIAH Sortie Guide](https://www.ffxiah.com/node/469)
- [bg-wiki Sortie Strategies](https://www.bg-wiki.com/ffxi/Sortie_Strategies)

Objectives marked with `(?)` are community-speculated but not fully confirmed.

## Note on Windowed Mode

If clicking the floor selector doesn't work, you're likely in windowed mode. The window taskbar (50px) and title bar (25px) offset mouse coordinates. Adjust your game resolution settings accordingly.

## Credits

- Original addon by Mirdain
- v3.0 objective data update and feature additions
