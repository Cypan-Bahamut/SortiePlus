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
| `//sort debug` | Toggle debug output |
| `//sort zone` | Show current zone ID |
| `//sort help` | Show command list in-game |

## Credits

- Original addon by Mirdain
- v3.0 objective data update and feature additions
