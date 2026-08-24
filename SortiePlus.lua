_addon.name = 'SortiePlus'
_addon.author = 'Mirdain; Modified by Cypan (Bahamut)'
_addon.version = '3.0 Windower'
_addon_description = 'Comprehensive Sortie objective tracker with completion detection'
_addon.commands = {'sortie','sort'}

packets = require 'packets'
config = require 'config'
res = require 'resources'
texts = require 'texts'

require 'tables'
require 'strings'
require 'pack'
local bit = require 'bit'

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
default = {
    debug = false,
    show_boss_info = true,
    show_obj = true,
    show_loot = true,
    hide_all = false,
    Tracking_Box = {
        text = {size=10, font='Consolas', red=255, green=255, blue=255, alpha=255},
        pos  = {x=1313, y=623},
        bg   = {visible=true, red=0, green=0, blue=0, alpha=102},
    },
    Floor = {
        text = {size=13, font='Consolas', red=255, green=255, blue=255, alpha=255},
        pos  = {x=1313, y=595},
        bg   = {visible=true, red=0, green=0, blue=0, alpha=102},
    },
}

settings = config.load(default)
mob_tracking = {}
interval = .25
enabled = false
UpdateTime = os.clock()
location = "A"

gears = {'|','/','-','\\\\'}
gear = 1

tracking_window = texts.new("", settings.Tracking_Box)
floor_window    = texts.new("[A] [B] [C] [D] [E] [F] [G] [H]", settings.Floor)

----------------------------------------------------------------------
-- Objective completion tracking
----------------------------------------------------------------------
objectives_done = {A=0, B=0, C=0, D=0, E=0, F=0, G=0, H=0}
aurum_done = {F1=false, F2=false} -- #?: 1/1 per floor
aurum_progress = {F1_cur=0, F1_max=1, F2_cur=0, F2_max=2}
nm_dead = {}
upstairs_nms_killed = {A=false, B=false, C=false, D=false}
-- Tracks obtained temp items: items_got["shard_A"] = true, items_got["key_B"] = true, etc.
items_got = {}
-- Bitzer zone-wide scan: stores {x=, y=, z=, name=} per index
bitzer_pos = {}
bitzer_scanning = {}  -- bitzer_scanning[index] = true while waiting for 0x0E response

----------------------------------------------------------------------
-- Chest ID mapping (PRIMARY DETECTION SOURCE)
--
-- Source: derived from in-game log analysis (2026-07-28). Confirmed by
-- direct observation of the game's targeting output. Chest entity IDs
-- and indices are stable within Ra'Kaznar and only change with SE dev
-- updates to Sortie itself.
--
-- Pattern: id = 21000192 + idx. Upstairs chests grouped by objective
-- number across sectors:
--   idx 1-4   = Chest #A1..#D1
--   idx 5-8   = Chest #A2..#D2
--   idx 9-12  = Chest #A5..#D5   (note: X5 before X3/X4)
--   idx 13-16 = Chest #A3..#D3
--   idx 17-20 = Chest #A4..#D4
--   idx 21-24 = Chest #E..#H     (single basement chest per sector)
--   idx 26-37 = Caskets/Coffers for A-D (3 slots per sector)
--   idx 38    = Aurum Coffer
--   idx 39-50 = Caskets/Coffers for E-H (3 slots per sector)
--
-- [C] = confirmed from log, [I] = inferred from consistent pattern
----------------------------------------------------------------------
local CHEST_BASE_ID = 21000192

-- Maps idx to {name, sector, obj_id, type, confirmed}
-- obj_id matches the id field in sector_objectives[sector].objs entries
local chest_map = {
    -- Upstairs Chest #X1 group [C: none directly - inferred pattern from A1=1]
    [1]  = {name="Chest #A1", sector="A", obj_id="A1", type="chest", confirmed=true},   -- [C]
    [2]  = {name="Chest #B1", sector="B", obj_id="B1", type="chest", confirmed=false},  -- [I]
    [3]  = {name="Chest #C1", sector="C", obj_id="C1", type="chest", confirmed=false},  -- [I]
    [4]  = {name="Chest #D1", sector="D", obj_id="D1", type="chest", confirmed=false},  -- [I]
    -- Upstairs Chest #X2 group
    [5]  = {name="Chest #A2", sector="A", obj_id="A2", type="chest", confirmed=true},   -- [C]
    [6]  = {name="Chest #B2", sector="B", obj_id="B2", type="chest", confirmed=true},   -- [C]
    [7]  = {name="Chest #C2", sector="C", obj_id="C2", type="chest", confirmed=true},   -- [C]
    [8]  = {name="Chest #D2", sector="D", obj_id="D2", type="chest", confirmed=true},   -- [C]
    -- Upstairs Chest #X5 group (out of numeric order)
    [9]  = {name="Chest #A5", sector="A", obj_id="A5", type="chest", confirmed=true},   -- [C]
    [10] = {name="Chest #B5", sector="B", obj_id="B5", type="chest", confirmed=false},  -- [I]
    [11] = {name="Chest #C5", sector="C", obj_id="C5", type="chest", confirmed=false},  -- [I]
    [12] = {name="Chest #D5", sector="D", obj_id="D5", type="chest", confirmed=false},  -- [I]
    -- Upstairs Chest #X3 group
    [13] = {name="Chest #A3", sector="A", obj_id="A3", type="chest", confirmed=true},   -- [C]
    [14] = {name="Chest #B3", sector="B", obj_id="B3", type="chest", confirmed=true},   -- [C]
    [15] = {name="Chest #C3", sector="C", obj_id="C3", type="chest", confirmed=true},   -- [C]
    [16] = {name="Chest #D3", sector="D", obj_id="D3", type="chest", confirmed=false},  -- [I]
    -- Upstairs Chest #X4 group
    [17] = {name="Chest #A4", sector="A", obj_id="A4", type="chest", confirmed=true},   -- [C]
    [18] = {name="Chest #B4", sector="B", obj_id="B4", type="chest", confirmed=false},  -- [I]
    [19] = {name="Chest #C4", sector="C", obj_id="C4", type="chest", confirmed=true},   -- [C]
    [20] = {name="Chest #D4", sector="D", obj_id="D4", type="chest", confirmed=false},  -- [I]
    -- Basement Chest (single per sector, sector letter matches)
    [21] = {name="Chest #E",  sector="E", obj_id="E1", type="chest", confirmed=true},   -- [C]
    [22] = {name="Chest #F",  sector="F", obj_id="F1", type="chest", confirmed=false},  -- [I]
    [23] = {name="Chest #G",  sector="G", obj_id="G1", type="chest", confirmed=false},  -- [I]
    [24] = {name="Chest #H",  sector="H", obj_id="H1", type="chest", confirmed=false},  -- [I]
    -- idx 25 skipped (gap in observed data)
    -- Upstairs Caskets + Coffers, 3 slots per sector (A-D)
    [26] = {name="Casket #A1", sector="A", obj_id="A6", type="casket", confirmed=true}, -- [C]
    [27] = {name="Casket #A2", sector="A", obj_id="A7", type="casket", confirmed=true}, -- [C]
    [28] = {name="Coffer #A",  sector="A", obj_id="A8", type="coffer", confirmed=true}, -- [C]
    [29] = {name="Casket #B1", sector="B", obj_id="B6", type="casket", confirmed=true}, -- [C]
    [30] = {name="Casket #B2", sector="B", obj_id="B7", type="casket", confirmed=true}, -- [C]
    [31] = {name="Coffer #B",  sector="B", obj_id="B8", type="coffer", confirmed=true}, -- [C]
    [32] = {name="Casket #C1", sector="C", obj_id="C6", type="casket", confirmed=false},-- [I]
    [33] = {name="Casket #C2", sector="C", obj_id="C7", type="casket", confirmed=false},-- [I]
    [34] = {name="Coffer #C",  sector="C", obj_id="C8", type="coffer", confirmed=true}, -- [C]
    [35] = {name="Casket #D1", sector="D", obj_id="D6", type="casket", confirmed=false},-- [I]
    [36] = {name="Casket #D2", sector="D", obj_id="D7", type="casket", confirmed=false},-- [I]
    [37] = {name="Coffer #D",  sector="D", obj_id="D8", type="coffer", confirmed=true}, -- [C 07/29]
    -- Aurum Coffer (shared, tracked via chest presence + status report)
    [38] = {name="Aurum Coffer", sector="_AURUM", obj_id=nil, type="aurum", confirmed=true}, -- [C]
    -- Basement Caskets + Coffers, 3 slots per sector (E-H)
    [39] = {name="Casket #E1", sector="E", obj_id="E2", type="casket", confirmed=false},-- [I]
    [40] = {name="Casket #E2", sector="E", obj_id="E3", type="casket", confirmed=false},-- [I]
    [41] = {name="Coffer #E",  sector="E", obj_id="E4", type="coffer", confirmed=false},-- [I]
    [42] = {name="Casket #F1", sector="F", obj_id="F2", type="casket", confirmed=false},-- [I]
    [43] = {name="Casket #F2", sector="F", obj_id="F3", type="casket", confirmed=false},-- [I]
    [44] = {name="Coffer #F",  sector="F", obj_id="F4", type="coffer", confirmed=false},-- [I]
    [45] = {name="Casket #G1", sector="G", obj_id="G2", type="casket", confirmed=true}, -- [C]
    [46] = {name="Casket #G2", sector="G", obj_id="G3", type="casket", confirmed=false},-- [I]
    [47] = {name="Coffer #G",  sector="G", obj_id="G4", type="coffer", confirmed=false},-- [I]
    [48] = {name="Casket #H1", sector="H", obj_id="H2", type="casket", confirmed=false},-- [I]
    [49] = {name="Casket #H2", sector="H", obj_id="H3", type="casket", confirmed=false},-- [I]
    [50] = {name="Coffer #H",  sector="H", obj_id="H4", type="coffer", confirmed=false},-- [I]
}

-- Build reverse lookup: obj_id -> chest idx (for obj_is_done)
local obj_to_chest_idx = {}
for idx, entry in pairs(chest_map) do
    if entry.obj_id then
        obj_to_chest_idx[entry.obj_id] = idx
    end
end

-- Runtime chest state:
--   chest_seen_this_run[idx] = true → this chest's 0x05B spawn packet was
--     seen (chest became VISIBLE = objective completed). Reset per run.
-- NOTE (07/29 log): chest entities pre-exist in the entity table as hidden
-- objects BEFORE their objective is earned, so get_mob_by_index polling
-- false-positives. Detection uses 0x05B spawn packets instead (the packet
-- fires only when the chest becomes visible) — technique from v6/SortieHUD,
-- IDs from logged in-game targeting data.
chest_seen_this_run = {}

----------------------------------------------------------------------
-- Gallimaufry + Sortie loot counters (restored from Sortie v6)
-- galli_total = latest "...for a total of N"; galli_session = sum gained
-- since addon load. Persist across zones (intentionally NOT reset in
-- initialize()).
----------------------------------------------------------------------
galli_total = 0
galli_session = 0

-- Sortie loot drops since addon load (also not reset per run).
loot_count = {sapphire = 0, starstone = 0, old_case = 0, old_case_p1 = 0, old_case_p2 = 0,
              eikondrite = 0, octahedrite = 0, hexahedrite = 0, mesosiderite = 0}

----------------------------------------------------------------------
-- Boss element tracking (D=Degei, H=Aita)
-- Both share the same 5 elemental TP moves + Vivisection
----------------------------------------------------------------------
boss_counter = nil  -- current counter element: "Fire","Water","Thunder","Ice","Earth","Wind", or nil

-- TP move name → counter element
local tp_to_counter = {
    ['Flaming Kick']    = 'Water',    -- Fire move → Water counter
    ['Flashflood']      = 'Thunder',  -- Water move → Thunder counter
    ['Icy Grasp']       = 'Fire',     -- Ice move → Fire counter
    ['Eroding Flesh']   = 'Wind',     -- Earth move → Wind counter
    ['Fulminous Smash'] = 'Earth',    -- Thunder move → Earth counter
}

-- Element → display color (r,g,b)
local element_colors = {
    Fire    = {255, 80, 40},
    Water   = {40, 120, 255},
    Thunder = {200, 160, 255},
    Ice     = {150, 220, 255},
    Earth   = {210, 180, 100},
    Wind    = {100, 255, 100},
}

----------------------------------------------------------------------
-- Boss nuke timer (C/D/G/H have repeating AoE on a fixed interval)
----------------------------------------------------------------------
boss_timer_start = nil  -- os.clock() when timer began
boss_timer_active = false

-- Sector → {ability name, interval in seconds, boss name}
local boss_nuke_info = {
    C = {ability='Setting the Stage', interval=180, boss='Skomora'},
    D = {ability='Vivisection',       interval=180, boss='Degei'},
    G = {ability='Setting the Stage', interval=180, boss='Triboulex'},
    H = {ability='Vivisection',       interval=185, boss='Aita'},
}

-- All TP move names for C/G bosses (Defiant family) to detect first combat
local defiant_tp_moves = {
    'Cruel Joke', 'Feast of Arrows', 'Last Laugh',
    'Regurgitated Swarm', 'Setting the Stage', 'Curtain Call',
}

----------------------------------------------------------------------
-- NM Data with widescan indices
----------------------------------------------------------------------
function initialize()
    mob_tracking = {
        [1] = {name = 'Abject Obdella',       index = 144, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [2] = {name = 'Biune Porxie',         index = 223, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [3] = {name = 'Cachaemic Bhoot',      index = 285, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [4] = {name = 'Demisang Deleterious', index = 373, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [5] = {name = 'Esurient Botulus',     index = 427, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [6] = {name = 'Fetid Ixion',          index = 498, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [7] = {name = 'Gyvewrapped Naraka',   index = 552, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
        [8] = {name = 'Haughty Tulittia',     index = 622, distance = 0, mob_x = nil, mob_y = nil, last_update = 0},
    }
    objectives_done = {A=0, B=0, C=0, D=0, E=0, F=0, G=0, H=0}
    aurum_done = {F1=false, F2=false}
    aurum_progress = {F1_cur=0, F1_max=1, F2_cur=0, F2_max=2}
    nm_dead = {}
    upstairs_nms_killed = {A=false, B=false, C=false, D=false}
    items_got = {}
    bitzer_pos = {}
    bitzer_scanning = {}
    chest_seen_this_run = {}
    -- galli_* and loot_count intentionally NOT reset (persist since addon load)
    boss_counter = nil
    boss_timer_start = nil
    boss_timer_active = false
    location = "A"
end

----------------------------------------------------------------------
-- Boss info per sector
----------------------------------------------------------------------
local boss_info = {
    A = {name='Ghatjot',   weakness='Absorbs Water/Ice. Stunnable.',                         metal='Blocks Taint (unremovable poison)'},
    B = {name='Leshonn',   weakness='Wind=Ice, Thunder=Earth. Stacking DT. Proc resets.',  metal='Blocks Stun(Thndr)/Gravity(Wind) on autos'},
    C = {name='Skomora',   weakness='Weak Fire. Absorbs Dark/Earth.',                        metal='Converts Haunt to movement-speed Curse'},
    D = {name='Degei',     weakness='Absorbs per last TP move. Nuke opposite element.',      metal='Blocks elemental absorb'},
    E = {name='Dhartok',   weakness='Weak to Stone. WS Wall (10s after full hit).',          metal='Blocks Taint (unremovable poison)'},
    F = {name='Gartell',   weakness='Weak Ice/Stone (per hands). WS Wall.',                  metal='(unverified)'},
    G = {name='Triboulex', weakness='Weak Fire. WS Wall. AoE Bind. Pillar mechanic.',        metal='Blocks Haunt (unremovable curse)'},
    H = {name='Aita',      weakness='Proc like Degei. WS Wall.',                             metal='(unverified)'},
}

----------------------------------------------------------------------
-- Comprehensive objective data per sector
-- Sources: bg-wiki, FFXIclopedia, FFXIAH community guide
-- type: "chest" = Brown, "casket" = Blue, "coffer" = Red
----------------------------------------------------------------------
local sector_objectives = {
    A = {
        title = "Abject (Acuex/Leech/Hecteyes)",
        objs = {
            {id="A1", type="chest",  label="Chest #A1 ", desc="Open any unlocked Gate #A",                    reward="Key A"},
            {id="A2", type="chest",  label="Chest #A2 ", desc="Cast any magic near Device #A",                reward="Plate A"},
            {id="A3", type="chest",  label="Chest #A3 ", desc="Single-target magic kill x3 Abject",           reward="Shard A"},
            {id="A4", type="chest",  label="Chest #A4 ", desc="Single-target magic kill x3 more",             reward="Metal A"},
            {id="A5", type="chest",  label="Chest #A5 ", desc="Touch Bitzer #A while naked",                  reward="Sheet A"},
            {id="A6", type="casket", label="Casket #A1", desc="Kill 5 Abject foes (not Obdella)"},
            {id="A7", type="casket", label="Casket #A2", desc="/heal past Gate #A1 in Leech area"},
            {id="A8", type="coffer", label="Coffer #A ", desc="Kill Abject Obdella"},
        },
    },
    B = {
        title = "Biune (Elementals/Umbrils)",
        objs = {
            {id="B1", type="chest",  label="Chest #B1 ", desc="Open Gates B1-B6 in order",                    reward="Key B"},
            {id="B2", type="chest",  label="Chest #B2 ", desc="/hurray at Device #B",                         reward="Plate B"},
            {id="B3", type="chest",  label="Chest #B3 ", desc="WS on 5 Biune foes before killing them",         reward="Shard B"},
            {id="B4", type="chest",  label="Chest #B4 ", desc="WS on 5 more Biune foes before killing",         reward="Metal B"},
            {id="B5", type="chest",  label="Chest #B5 ", desc="Walk to Bitzer #B (warp=must restart)",            reward="Sheet B"},
            {id="B6", type="casket", label="Casket #B1", desc="Kill 3 Biune within 30s of gaining enmity"},
            {id="B7", type="casket", label="Casket #B2", desc="Open a Locked Gate B"},
            {id="B8", type="coffer", label="Coffer #B ", desc="Kill Porxie (need Casket B1 first)"},
        },
    },
    C = {
        title = "Cachaemic (Ghost/Skeleton/Corse)",
        objs = {
            {id="C1", type="chest",  label="Chest #C1 ", desc="Open C1 or C2 before defeating any in C",            reward="Key C"},
            {id="C2", type="chest",  label="Chest #C2 ", desc="Pull+kill Cachaemic at Device #C",                 reward="Plate C"},
            {id="C3", type="chest",  label="Chest #C3 ", desc="MB x3 Cachaemic before defeating them",            reward="Shard C"},
            {id="C4", type="chest",  label="Chest #C4 ", desc="MB x3 more Cachaemic before defeating",            reward="Metal C"},
            {id="C5", type="chest",  label="Chest #C5 ", desc="Kill mob->Materialize->Bitzer (same player)",      reward="Sheet C"},
            {id="C6", type="casket", label="Casket #C1", desc="Kill 3 Cachaemic within 15s of enmity"},
            {id="C7", type="casket", label="Casket #C2", desc="Full clear all enemies in area C"},
            {id="C8", type="coffer", label="Coffer #C ", desc="Kill Bhoot within ~5 min of entering C"},
        },
    },
    D = {
        title = "Demisang (Fomor: Snd+Sight, no Sleep!)",
        objs = {
            {id="D1", type="chest",  label="Chest #D1 ", desc="Open D2 and D1 within 2 min",                  reward="Key D"},
            {id="D2", type="chest",  label="Chest #D2 ", desc="Drop Obsidian Wing at Device #D",              reward="Plate D"},
            {id="D3", type="chest",  label="Chest #D3 ", desc="4-step SC on 3 Demisang",                      reward="Shard D"},
            {id="D4", type="chest",  label="Chest #D4 ", desc="4-step SC on 3 more Demisang",                 reward="Metal D"},
            {id="D5", type="chest",  label="Chest #D5 ", desc="Kill all Demisang (not NM) -> Bitzer #D",        reward="Sheet D"},
            {id="D6", type="casket", label="Casket #D1", desc="Kill one of each job (6 types)"},
            {id="D7", type="casket", label="Casket #D2", desc="Kill order: WAR>MNK>WHM>BLM>RDM>THF"},
            {id="D8", type="coffer", label="Coffer #D ", desc="Kill Deleterious + 3 more Demisang"},
        },
    },
    E = {
        title = "Esurient (Slime/Slug/Flan)",
        objs = {
            {id="E1", type="chest",  label="Chest #E  ", desc="Kill Botulus: majority dmg from WS behind (no SC)", reward="Metal E"},
            {id="E2", type="casket", label="Casket #E1", desc="Kill 12 Esurient foes in Bitzer room"},
            {id="E3", type="casket", label="Casket #E2", desc="Kill 15 Esurient Flans"},
            {id="E4", type="coffer", label="Coffer #E ", desc="Kill 6 Naakuals (spawn 5 min after entry)"},
        },
        reive  = "5 min after entry (resets if sector evacuated/boss entered)",
        boss_drops = "Fragment #1 (for Aminon)",
    },
    F = {
        title = "Fetid (Pixies/Elementals)",
        objs = {
            {id="F1", type="chest",  label="Chest #F  ", desc="Kill Ixion while horn is broken (cond. unverified)", reward="Metal F"},
            {id="F2", type="casket", label="Casket #F1", desc="5/5 Empy armor (lockstyle) + exit Bitzer"},
            {id="F3", type="casket", label="Casket #F2", desc="Kill all Fetid Veela"},
            {id="F4", type="coffer", label="Coffer #F ", desc="Clear Reive: Naakual (any order)"},
        },
        reive  = "Leave area F and return to spawn Reive",
        boss_drops = "Fragment #2 (for Aminon)",
    },
    G = {
        title = "Gyvewrapped (Hound/Dullahan/Vampyr)",
        objs = {
            {id="G1", type="chest",  label="Chest #G  ", desc="Kill Gyvewrapped Naraka",                      reward="Metal G"},
            {id="G2", type="casket", label="Casket #G1", desc="Stand within 6y of Bitzer, target it, 30s"},
            {id="G3", type="casket", label="Casket #G2", desc="Kill 19 Gyvewrapped Dullahan"},
            {id="G4", type="coffer", label="Coffer #G ", desc="Reive: Bztavian>Rockfin>Gabbrath>Waktza>Yggdreant>Cehuetzi"},
        },
        reive  = "Kill all enemies in both sides of split room",
        boss_drops = "Fragment #3 (for Aminon)",
    },
    H = {
        title = "Haughty (Fomor)",
        objs = {
            {id="H1", type="chest",  label="Chest #H  ", desc="Kill Tulittia: 50%+ HP by indirect AoE",         reward="Metal H"},
            {id="H2", type="casket", label="Casket #H1", desc="Leave H and re-enter"},
            {id="H3", type="casket", label="Casket #H2", desc="Kill all Haughty Paladins"},
            {id="H4", type="coffer", label="Coffer #H ", desc="Reive: Bztavian>Cehuetzi>Gabbrath>Rockfin>Waktza>Yggdreant"},
        },
        reive  = "Spawn: Kill 8 Haughty foes of different jobs",
        boss_drops = "Fragment #4 (for Aminon)",
    },
}

----------------------------------------------------------------------
-- Chat log parsing for objective/NM tracking
-- Formats verified from actual Sortie log:
--   Status:  "#A treasure coffer status report: 1/8 #?: 0/1."
--   Temp:    "You obtain the temporary item: Ra'Kaznar shard #A!"
--   Galli:   "Player received 100 gallimaufry for a total of 404630."
--   Kill:    "Player defeats the Abject Acuex."
--   Death:   "Player was defeated by Ghatjot."
----------------------------------------------------------------------
windower.register_event('incoming text', function(original, modified, original_mode, modified_mode, blocked)
    if not enabled then return end

    -- Status report: "#A treasure coffer status report: 3/8 #?: 0/1."
    -- Upstairs Aurum (F1): #?: X/1 (need 1 kill for completion)
    -- Basement Aurum (F2): #?: X/2 (need 2 kills for completion)
    local sector_letter, count, total, aurum_cur, aurum_max =
        original:match('#([A-H]) treasure coffer status report: (%d+)/(%d+) #%?: (%d+)/(%d+)')
    if sector_letter and count then
        objectives_done[sector_letter] = tonumber(count)
        local cur = tonumber(aurum_cur)
        local max = tonumber(aurum_max)
        -- Track progress numbers for display
        if sector_letter >= 'A' and sector_letter <= 'D' then
            aurum_progress.F1_cur = cur
            aurum_progress.F1_max = max
            if cur >= max then aurum_done.F1 = true end
        else
            aurum_progress.F2_cur = cur
            aurum_progress.F2_max = max
            if cur >= max then aurum_done.F2 = true end
        end
        log('Sector '..sector_letter..': '..count..'/'..total..' Aurum:'..aurum_cur..'/'..aurum_max)
    end

    -- Temp item obtained: "You obtain the temporary item: Ra'Kaznar shard #A!"
    local item_type, item_sector = original:match("Ra'Kaznar (%a+) #([A-H])")
    if item_type and item_sector then
        local key = item_type:lower()..'_'..item_sector
        items_got[key] = true
        log('Temp item: '..key)
    end
    -- Also catch seal (no sector letter)
    if original:find("Ra'Kaznar seal") then
        items_got['seal'] = true
        log('Temp item: seal')
    end

    -- Gallimaufry: "Player received 100 gallimaufry for a total of 404630."
    -- (original v6 pattern: unanchored — the game only renders your own
    -- galli lines, confirmed in the 07/28 log)
    local galli_gain, galli_tot = original:match("received (%d+) gallimaufry for a total of (%d+)")
    if galli_gain then
        galli_session = galli_session + tonumber(galli_gain)
        galli_total = tonumber(galli_tot)
        log('Galli +'..galli_gain..' (session '..galli_session..', total '..galli_total..')')
    end

    -- NM kills: "Player defeats the Abject Obdella."
    -- Format is always "defeats the <NM name>"
    for i = 1, 8 do
        if mob_tracking[i] then
            local nm_name = mob_tracking[i].name
            if original:find('defeats the '..nm_name) then
                nm_dead[nm_name] = true
                mob_tracking[i].distance = 'Dead'
                local sector_map = {[1]='A', [2]='B', [3]='C', [4]='D'}
                if sector_map[i] then
                    upstairs_nms_killed[sector_map[i]] = true
                end
                log(nm_name..' killed!')
            end
        end
    end

    -- Boss element tracking (Degei D / Aita H)
    -- Chat format: "Degei uses Flaming Kick." or "Aita readies Icy Grasp."
    if location == 'D' or location == 'H' then
        for tp_name, counter in pairs(tp_to_counter) do
            if original:find(tp_name) then
                boss_counter = counter
                -- Start timer on first TP move if not already running
                if not boss_timer_active then
                    boss_timer_start = os.clock()
                    boss_timer_active = true
                    log('Boss timer started (first TP)')
                end
                log('Boss TP: '..tp_name..' -> Counter: '..counter)
                break
            end
        end
        if original:find('Vivisection') then
            boss_counter = nil
            -- Reset timer after Vivisection fires
            boss_timer_start = os.clock()
            boss_timer_active = true
            log('Boss TP: Vivisection -> Counter: NONE, timer reset')
        end
    end

    -- Boss nuke timer for C/G (Setting the Stage every 3:00)
    if location == 'C' or location == 'G' then
        -- Detect any Defiant TP move to start timer
        if not boss_timer_active then
            for _, tp_name in ipairs(defiant_tp_moves) do
                if original:find(tp_name) then
                    boss_timer_start = os.clock()
                    boss_timer_active = true
                    log('Boss timer started ('..tp_name..')')
                    break
                end
            end
        end
        -- Reset timer when Setting the Stage fires
        if original:find('Setting the Stage') then
            boss_timer_start = os.clock()
            boss_timer_active = true
            log('Setting the Stage fired, timer reset')
        end
    end

    -- SuperWarp auto-sector detection
    -- Anchored on "Warping via" to prevent party chat false positives.
    --
    -- Two distinct message formats based on SuperWarp's code paths:
    --
    -- 1. Bitzer/Gadget warps (Sortie's custom handler, sortie.lua line 521/656/768):
    --    "Warping via <npc> to Bitzer #X." or "to Gadget #X."
    --    where X is the destination sector letter directly.
    --
    -- 2. Device warps (main superwarp.lua line 519, uses resolve_warp):
    --    "Warping via Diaphanous Device #X to Outer Ra'Kaznar [U2] - N."
    --    where N is the user-input shortcut key (1=A, 2=B, 3=C, 4=D).
    --    Verified against screenshot: "- 3" = sector C.
    if original:find('Warping via') then
        -- Try Bitzer/Gadget pattern first (direct letter)
        local dest_letter = original:match('to Bitzer #([A-H])') or
                            original:match('to Gadget #([A-H])')
        -- Fall back to Device offset format
        if not dest_letter then
            local num = original:match('Diaphanous Device .+%- (%d+)')
            if num then
                local dest_map = {[1]='A', [2]='B', [3]='C', [4]='D'}
                dest_letter = dest_map[tonumber(num)]
            end
        end
        if dest_letter then
            location = dest_letter
            local idx = string.byte(location) - string.byte('A') + 1
            if mob_tracking[idx] then
                track_on(mob_tracking[idx].index)
            end
            -- Reset boss state on sector change
            boss_timer_start = nil
            boss_timer_active = false
            boss_counter = nil
            -- Auto-scan Bitzers when entering basement
            if location >= 'E' and location <= 'H' then
                scan_all_bitzers()
            end
            log('Auto-sector: '..location..' (SuperWarp)')
        end
    end
end)

----------------------------------------------------------------------
-- Prerender
----------------------------------------------------------------------
local BscanTime = 0
local bscan_interval = 2 -- seconds between auto-scan attempts

windower.register_event('prerender', function()
    local now = os.clock()
    if now - UpdateTime > interval and enabled then
        UpdateTime = now
        tracking_box_update()
    end
    -- Auto-scan Bitzers if in basement and not yet found
    if enabled and now - BscanTime > bscan_interval then
        if location >= 'E' and location <= 'H' then
            local bitzer_indices = {E=837, F=838, G=839, H=840}
            local bidx = bitzer_indices[location]
            local bitzer = windower.ffxi.get_mob_by_index(bidx)
            if (not bitzer or bitzer.x == 0) and not bitzer_pos[bidx] then
                scan_bitzer(bidx)
                BscanTime = now
            end
        end
    end
    -- Re-request NM tracking if stale (no update for 5+ seconds)
    if enabled then
        local sector_index = string.byte(location) - string.byte('A') + 1
        local nm = mob_tracking[sector_index]
        if nm and nm.distance ~= 0 and nm.distance ~= 'Dead'
           and nm.last_update > 0 and (now - nm.last_update) > 5 then
            track_on(nm.index)
            nm.last_update = now  -- prevent spamming, wait another 5s
            log('NM track stale, re-requesting ['..nm.name..']')
        end
    end
    -- (Chest detection moved to 0x05B spawn-packet handler — entity polling
    --  false-positives on pre-spawned hidden chests; see 07/29 log finding.)
end)

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------
windower.register_event('addon command', function(input, ...)
    local args = L{...}
    commands(input, args)
end)

----------------------------------------------------------------------
-- Zone change
----------------------------------------------------------------------
windower.register_event('zone change', function()
    local world = windower.ffxi.get_info()
    initialize()
    if world.zone == 133 or world.zone == 189 then
        coroutine.sleep(4)
        show_UI()
        enabled = true
        log("Zoned into Outer Ra'Kaznar [U2]")
    else
        hide_UI()
        enabled = false
    end
end)

----------------------------------------------------------------------
-- Load
----------------------------------------------------------------------
windower.register_event('load', function()
    local world = windower.ffxi.get_info()
    initialize()
    if world.zone == 133 or world.zone == 189 then
        enabled = true
        show_UI()
        log("Loaded in Outer Ra'Kaznar [U2]")
    else
        hide_UI()
        enabled = false
    end
end)

----------------------------------------------------------------------
-- Widescan packets for NM tracking
----------------------------------------------------------------------
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if id == 0x0F4 and enabled then
        local packet = packets.parse('incoming', original)
        local player_f4 = windower.ffxi.get_mob_by_target('me')
        for index, target in ipairs(mob_tracking) do
            if target.index == packet['Index'] then
                if mob_tracking[index].distance ~= 'Dead' then
                    local enemy = windower.ffxi.get_mob_by_index(packet['Index'])
                    if enemy and (enemy.status == 2 or enemy.status == 3) then
                        mob_tracking[index].distance = 'Dead'
                        local sector_map = {[1]='A', [2]='B', [3]='C', [4]='D'}
                        if sector_map[index] then
                            upstairs_nms_killed[sector_map[index]] = true
                        end
                    else
                        local distance = round((packet['X Offset']^2 + packet['Y Offset']^2):sqrt(), 1)
                        local is_first_acquire = (mob_tracking[index].last_update == 0)
                        mob_tracking[index].distance = distance
                        mob_tracking[index].last_update = os.clock()
                        if player_f4 then
                            mob_tracking[index].mob_x = player_f4.x + packet['X Offset']
                            mob_tracking[index].mob_y = player_f4.y + packet['Y Offset']
                        end
                        if is_first_acquire then
                            windower.add_to_chat(8, 'Tracking '..mob_tracking[index].name..' ['..distance..']')
                        end
                        track_on(packet['Index'])
                    end
                end
            end
        end
    elseif id == 0x0F5 and enabled then
        local packet = packets.parse('incoming', original)
        local player = windower.ffxi.get_mob_by_target('me')
        if packet['X'] and packet['Y'] and player then
            local distance = round(((player.x - packet['X'])^2 + (player.y - packet['Y'])^2):sqrt(), 1)
            if packet['Index'] ~= 0 then
                for index, target in pairs(mob_tracking) do
                    if target.index == packet['Index'] then
                        if mob_tracking[index].distance ~= 'Dead' then
                            local enemy = windower.ffxi.get_mob_by_index(packet['Index'])
                            if enemy and (enemy.status == 2 or enemy.status == 3) then
                                mob_tracking[index].distance = 'Dead'
                                local sector_map = {[1]='A', [2]='B', [3]='C', [4]='D'}
                                if sector_map[index] then
                                    upstairs_nms_killed[sector_map[index]] = true
                                end
                            else
                                mob_tracking[index].distance = distance
                                mob_tracking[index].last_update = os.clock()
                                mob_tracking[index].mob_x = packet['X']
                                mob_tracking[index].mob_y = packet['Y']
                            end
                        end
                    end
                end
            end
        end
    elseif id == 0x0E and enabled then
        -- NPC Update: check if this is a Bitzer scan response
        local target_index = original:unpack('h', 0x08 + 1)
        if bitzer_scanning[target_index] then
            bitzer_scanning[target_index] = false
            local updatemask = original:unpack('b', 0x0A + 1)
            if updatemask and bit.band(updatemask, 0x01) == 0x01 then
                local x, z, y = original:unpack('fff', 0x0C + 1)
                if x and y and z then
                    local name = ''
                    if bit.band(updatemask, 0x08) == 0x08 then
                        for i = 1, (#original - 0x34), 1 do
                            local t = original:unpack('c', 0x34 + i)
                            if t == 0 then break end
                            name = name .. string.char(t)
                        end
                    end
                    bitzer_pos[target_index] = {x=x, y=y, z=z, name=name}
                    log('Bitzer ['..target_index..'] at ('..round(x,1)..', '..round(y,1)..') '..name)
                end
            end
        end
    elseif id == 0x05B and enabled then
        -- Chest spawn detection (v6/SortieHUD technique): the server sends
        -- 0x05B when a chest becomes VISIBLE, i.e. its objective was just
        -- completed. Entity-table polling can't be used — chests pre-exist
        -- as hidden objects (07/29 log false positive on Coffer #D at 0/8).
        -- IDs resolved via chest_map: id = CHEST_BASE_ID + idx.
        local packet = packets.parse('incoming', original)
        local oid = packet['ID']
        if oid then
            local cidx = oid - CHEST_BASE_ID
            local entry = chest_map[cidx]
            if entry and not chest_seen_this_run[cidx] then
                chest_seen_this_run[cidx] = true
                log('Objective complete (chest spawned): '..entry.name..' [id '..oid..' idx '..cidx..']')
                -- Aurum Coffer (idx 38) spawning = upstairs Aurum earned
                if cidx == 38 then
                    aurum_done.F1 = true
                end
            end
        end
    elseif id == 0x01F and enabled then
        -- Sortie loot counters via inventory-item update (restored from v6).
        -- Field names (Item/Status/Bag) are from SortieHUD (2022) and
        -- unverified; if wrong, the guards short-circuit on nil and this
        -- branch safely no-ops. Counts +1 per matching packet (same
        -- imprecision as SortieHUD).
        local packet = packets.parse('incoming', original)
        if packet['Item'] and packet['Item'] > 0
           and packet['Status'] == 0 and packet['Bag'] == 0 then
            local item = res.items[packet['Item']]
            if item and item.en then
                if item.en == "Ra'Kaz. Sapphire" then
                    loot_count.sapphire = loot_count.sapphire + 1
                elseif item.en == "Ra'Kaz. Starstone" then
                    loot_count.starstone = loot_count.starstone + 1
                elseif item.en == "Old Case" then
                    loot_count.old_case = loot_count.old_case + 1
                elseif item.en == "Old Case +1" then
                    loot_count.old_case_p1 = loot_count.old_case_p1 + 1
                elseif item.en == "Old Case +2" then
                    loot_count.old_case_p2 = loot_count.old_case_p2 + 1
                elseif item.en == "Eikondrite" then
                    loot_count.eikondrite = loot_count.eikondrite + 1
                elseif item.en == "Octahedrite" then
                    loot_count.octahedrite = loot_count.octahedrite + 1
                elseif item.en == "Hexahedrite" then
                    loot_count.hexahedrite = loot_count.hexahedrite + 1
                elseif item.en == "Mesosiderite" then
                    loot_count.mesosiderite = loot_count.mesosiderite + 1
                end
            end
        end
    end
end)

----------------------------------------------------------------------
-- Widescan helpers
----------------------------------------------------------------------
function track_on(index)
    local packet = packets.new('outgoing', 0x0F5, {
        ['Index'] = index,
        ['_junk1'] = 0,
    })
    packets.inject(packet)
    log('Track request ['..index..']')
end

function track_off()
    local packet = packets.new('outgoing', 0x0F6, {
        ['_junk1'] = 0,
    })
    packets.inject(packet)
    log('Tracking stopped')
end

----------------------------------------------------------------------
-- Bitzer zone-wide scan via 0x016 Update Request
-- Technique from ProjectTako's ScanZone addon:
--   Inject outgoing 0x016 with target index -> server responds
--   with incoming 0x00E (NPC Update) containing position data.
----------------------------------------------------------------------
function scan_bitzer(target_index)
    bitzer_scanning[target_index] = true
    windower.packets.inject_outgoing(0x16,
        string.char(0x16, 0x08, 0x00, 0x00,
            (target_index % 256), math.floor(target_index / 256),
            0x00, 0x00))
    log('Bitzer scan request for index ['..target_index..']')
end

function scan_all_bitzers()
    local bitzer_indices = {837, 838, 839, 840}
    for _, idx in ipairs(bitzer_indices) do
        scan_bitzer(idx)
    end
end

----------------------------------------------------------------------
-- Check if a specific objective is confirmed done
----------------------------------------------------------------------
local function obj_is_done(obj, sector_letter)
    -- PRIMARY: chest ID detection.
    -- In Sortie, a chest SPAWNS when its objective is completed — the chest
    -- appearing IS the completion event, and it spawns near the party (in
    -- render range). So having seen the chest this run means the objective
    -- is done, whether or not it has been looted yet.
    local chest_idx = obj_to_chest_idx[obj.id]
    if chest_idx and chest_seen_this_run[chest_idx] then
        return true
    end
    -- SECONDARY: full sector completion via status report ("8/8" / "4/4").
    -- Covers objectives completed before addon load / out of range.
    local sector = sector_objectives[sector_letter]
    if sector and objectives_done[sector_letter] >= #sector.objs then
        return true
    end
    -- TERTIARY: temp item detection for brown chests.
    if obj.type == "chest" and obj.reward then
        local item_type = obj.reward:match("^(%a+)")
        if item_type then
            if items_got[item_type:lower()..'_'..sector_letter] then
                return true
            end
        end
    end
    -- QUATERNARY: upstairs red coffer = NM kill.
    if obj.type == "coffer" and sector_letter >= 'A' and sector_letter <= 'D' then
        local nm_idx = string.byte(sector_letter) - string.byte('A') + 1
        if mob_tracking[nm_idx] and nm_dead[mob_tracking[nm_idx].name] then
            return true
        end
    end
    return false
end


----------------------------------------------------------------------
-- Chest type labels with color
----------------------------------------------------------------------
local function type_tag(t, done)
    if done then
        -- Green when done
        if t == "chest"  then return '\\cs(0,255,0)[Brn]' end
        if t == "casket" then return '\\cs(0,255,0)[Blu]' end
        if t == "coffer" then return '\\cs(0,255,0)[Red]' end
    else
        -- Default colors by type
        if t == "chest"  then return '\\cs(210,180,140)[Brn]' end
        if t == "casket" then return '\\cs(100,149,237)[Blu]' end
        if t == "coffer" then return '\\cs(220,80,80)[Red]' end
    end
    return '[???]'
end

----------------------------------------------------------------------
-- Main UI update
----------------------------------------------------------------------
function tracking_box_update()
    local lines = T{}
    gear_update()

    local maxWidth = 50
    local sector = sector_objectives[location]
    if not sector then return end

    local player = windower.ffxi.get_mob_by_target('me')
    local sector_index = string.byte(location) - string.byte('A') + 1

    -- Header with objective progress (hidden in minimal mode)
    local minimal = settings.hide_all
    if not minimal then
        local obj_count = objectives_done[location] or 0
        local obj_total = #sector.objs
        lines:insert("  Sector "..location.." ["..obj_count.."/"..obj_total.."]  "..sector.title)
        lines:insert(string.rep('-', maxWidth))
    end

    -- NM tracking
    if mob_tracking[sector_index] then
        local nm = mob_tracking[sector_index]
        if nm.distance == 'Dead' or nm_dead[nm.name] then
            lines:insert(" NM: "..nm.name.."  [\\cs(0,255,0)DEAD\\cr]")
        elseif nm.distance ~= 0 and player then
            -- Try live coords first (render range), then stored widescan coords
            local enemy = windower.ffxi.get_mob_by_index(nm.index)
            local dir = ''
            if enemy and enemy.x ~= 0 then
                dir = ' '..cardinal(player.x, player.y, enemy.x, enemy.y)
            elseif nm.mob_x and nm.mob_y then
                dir = ' '..cardinal(player.x, player.y, nm.mob_x, nm.mob_y)
            end
            lines:insert(" NM: "..nm.name.."  ["..tostring(nm.distance)..dir.."]")
        else
            lines:insert(" NM: "..nm.name.."  ["..tostring(nm.distance).."]")
        end
    end

    -- Bitzer tracking for basement (render range -> scanned fallback)
    if location >= 'E' and location <= 'H' then
        local bitzer_indices = {E=837, F=838, G=839, H=840}
        local bidx = bitzer_indices[location]
        local bitzer = windower.ffxi.get_mob_by_index(bidx)
        if bitzer and player and bitzer.x ~= 0 then
            -- In render range: live distance + direction
            local bd = round(((player.x - bitzer.x)^2 + (player.y - bitzer.y)^2):sqrt(), 1)
            local dir = cardinal(player.x, player.y, bitzer.x, bitzer.y)
            lines:insert(" Bitzer: "..bitzer.name.."  ["..bd.." "..dir.."]")
        elseif bitzer_pos[bidx] and player then
            -- Out of range but scanned: distance + direction from scan data
            local bp = bitzer_pos[bidx]
            local bd = round(((player.x - bp.x)^2 + (player.y - bp.y)^2):sqrt(), 1)
            local dir = cardinal(player.x, player.y, bp.x, bp.y)
            local bname = (bp.name ~= '' and bp.name) or 'Bitzer'
            lines:insert(" Bitzer: "..bname.."  [~"..bd.." "..dir.."] (scanned)")
        else
            lines:insert(" Bitzer: [scanning...]")
        end
    end

    if not minimal and settings.show_obj then lines:insert("") end

    -- Objectives with color coding (green = done) — //sort obj toggles
    if settings.show_obj and not minimal then
    for _, obj in ipairs(sector.objs) do
        local done = obj_is_done(obj, location)
        local tag = type_tag(obj.type, done)
        local reward_str = obj.reward and (" -> "..obj.reward) or ""
        if done then
            lines:insert(" "..tag.." "..obj.label..": "..obj.desc.."\\cr")
            if reward_str ~= "" then
                lines:insert("\\cs(0,255,0)         "..reward_str.."\\cr")
            end
        else
            lines:insert(" "..tag.."\\cr "..obj.label..": "..obj.desc)
            if reward_str ~= "" then
                lines:insert("         "..reward_str)
            end
        end
    end

    -- Reive info
    if sector.reive then
        lines:insert("")
        lines:insert(" Reive: "..sector.reive)
    end

    -- Boss drops for basement
    if sector.boss_drops then
        lines:insert(" Drops: "..sector.boss_drops)
    end
    end -- show_obj gate

    -- Boss info — //sort boss toggles (also covers counter + nuke timer)
    if settings.show_boss_info and not minimal and boss_info[location] then
        local bi = boss_info[location]
        lines:insert("")
        lines:insert(" Boss: "..bi.name)
        lines:insert("  "..bi.weakness)
        lines:insert("  Metal: "..bi.metal)
    end

    -- Boss element counter (D=Degei, H=Aita) — under boss toggle
    if settings.show_boss_info and not minimal and (location == 'D' or location == 'H') then
        if boss_counter then
            local ec = element_colors[boss_counter]
            if ec then
                lines:insert(" Counter: \\cs("..ec[1]..","..ec[2]..","..ec[3]..")"..boss_counter.."\\cr")
            else
                lines:insert(" Counter: "..boss_counter)
            end
        else
            lines:insert(" Counter: \\cs(180,180,180)NONE (Vivisection/waiting)\\cr")
        end
    end

    -- Boss nuke timer (C/D/G/H) — under boss toggle
    local nuke = boss_nuke_info[location]
    if nuke and settings.show_boss_info and not minimal then
        if boss_timer_active and boss_timer_start then
            local elapsed = os.clock() - boss_timer_start
            local remaining = nuke.interval - elapsed
            if remaining < 0 then remaining = 0 end
            local mins = math.floor(remaining / 60)
            local secs = math.floor(remaining % 60)
            local timer_str = string.format('%d:%02d', mins, secs)
            local color = ''
            local color_end = ''
            if remaining <= 0 then
                color = '\\cs(255,50,50)'     -- Red at 0:00
                color_end = '\\cr'
            elseif remaining <= 10 then
                color = '\\cs(255,165,0)'     -- Orange at 0:10
                color_end = '\\cr'
            elseif remaining <= 30 then
                color = '\\cs(255,255,0)'     -- Yellow at 0:30
                color_end = '\\cr'
            end
            lines:insert(" "..nuke.ability..": "..color..timer_str..color_end)
        else
            lines:insert(" "..nuke.ability..": \\cs(180,180,180)waiting\\cr")
        end
    end

    -- Aurum Coffer tracking — under obj toggle
    if settings.show_obj and not minimal and location >= 'A' and location <= 'D' then
        -- F1: 1 Naakual kill required (tracked via upstairs NM kills)
        local aurum_count = 0
        local aurum_parts = {}
        for _, s in ipairs({'A','B','C','D'}) do
            if upstairs_nms_killed[s] then
                aurum_count = aurum_count + 1
                table.insert(aurum_parts, '\\cs(0,255,0)'..s..':X\\cr')
            else
                table.insert(aurum_parts, s..':_')
            end
        end
        local aurum_color = aurum_done.F1 and '\\cs(0,255,0)' or ''
        local aurum_end = aurum_done.F1 and '\\cr' or ''
        local prog = aurum_progress.F1_cur..'/'..aurum_progress.F1_max
        lines:insert("")
        lines:insert(" "..aurum_color.."Aurum (F1): "..prog.."  NMs: "..table.concat(aurum_parts, " ")..aurum_end)
    elseif settings.show_obj and not minimal and location >= 'E' and location <= 'H' then
        -- F2: 2 conditions from status report #?: X/2
        local aurum_color = aurum_done.F2 and '\\cs(0,255,0)' or ''
        local aurum_end = aurum_done.F2 and '\\cr' or ''
        local prog = aurum_progress.F2_cur..'/'..aurum_progress.F2_max
        lines:insert("")
        lines:insert(" "..aurum_color.."Aurum (F2): "..prog..aurum_end)
    end

    -- Gallimaufry + Sortie loot (since addon load) — //sort loot toggles
    if settings.show_loot and not minimal then
        lines:insert("")
        lines:insert(string.format(" Galli: \\cs(0,255,0)%d\\cr  (+%d session)", galli_total, galli_session))
        lines:insert(string.format(" Loot: Sapph \\cs(0,255,0)%d\\cr Star \\cs(0,255,0)%d\\cr Case \\cs(0,255,0)%d\\cr/+1 \\cs(0,255,0)%d\\cr/+2 \\cs(0,255,0)%d\\cr",
            loot_count.sapphire, loot_count.starstone, loot_count.old_case, loot_count.old_case_p1, loot_count.old_case_p2))
        lines:insert(string.format(" Mats: Eik \\cs(0,255,0)%d\\cr Oct \\cs(0,255,0)%d\\cr Hex \\cs(0,255,0)%d\\cr Meso \\cs(0,255,0)%d\\cr",
            loot_count.eikondrite, loot_count.octahedrite, loot_count.hexahedrite, loot_count.mesosiderite))
    end

    lines:insert("")
    lines:insert(' Running....                                ['..gears[gear]..']')

    for i, line in ipairs(lines) do
        lines[i] = lines[i]:rpad(' ', maxWidth)
    end

    tracking_window:text(lines:concat('\n'))

    if settings.debug then
        local test_target = windower.ffxi.get_mob_by_target('t')
        if test_target then
            log("["..test_target.name.."] id["..test_target.id.."] idx["..test_target.index.."]")
        end
    end
end

----------------------------------------------------------------------
-- Commands handler
----------------------------------------------------------------------
function commands(input, args)
    if input == nil then return end
    local cmd = string.lower(input)

    if cmd == 'save' then
        config.save(settings, windower.ffxi.get_player().name:lower())
        windower.add_to_chat(8, 'Sortie: Settings saved.')

    elseif cmd == 'on' then
        show_UI()
        enabled = true
        windower.add_to_chat(8, 'Sortie: ON')

    elseif cmd == 'off' then
        hide_UI()
        enabled = false
        track_off()
        windower.add_to_chat(8, 'Sortie: OFF')

    elseif cmd == 'a' or cmd == 'b' or cmd == 'c' or cmd == 'd' or
           cmd == 'e' or cmd == 'f' or cmd == 'g' or cmd == 'h' then
        location = string.upper(cmd)
        local idx = string.byte(location) - string.byte('A') + 1
        if mob_tracking[idx] then
            track_on(mob_tracking[idx].index)
        end
        -- Reset boss state on any sector switch (per-boss timer/counter)
        boss_counter = nil
        boss_timer_start = nil
        boss_timer_active = false
        -- Auto-scan Bitzers when entering basement
        if location >= 'E' and location <= 'H' then
            scan_all_bitzers()
        end
        windower.add_to_chat(8, 'Sortie: Sector '..location)

    elseif cmd == 'zone' then
        local world = windower.ffxi.get_info()
        windower.add_to_chat(8, 'Sortie: Zone ['..world.zone..']')

    elseif cmd == 'track' then
        if args[1] then
            track_on(tonumber(args[1]))
            windower.add_to_chat(8, 'Sortie: Track ['..args[1]..']')
        end

    elseif cmd == 'scan' then
        if args[1] then
            local test_target = windower.ffxi.get_mob_by_index(tonumber(args[1]))
            if test_target then
                local p = windower.ffxi.get_mob_by_target('me')
                local d = round(((p.x - test_target.x)^2 + (p.y - test_target.y)^2):sqrt(), 1)
                windower.add_to_chat(8, '['..test_target.name..'] idx['..test_target.index..'] id['..test_target.id..'] dist['..d..']')
            else
                windower.add_to_chat(8, 'Sortie: Not found at index '..args[1])
            end
        end

    elseif cmd == 'boss' then
        settings.show_boss_info = not settings.show_boss_info
        windower.add_to_chat(8, 'Sortie: Boss info '..(settings.show_boss_info and 'ON' or 'OFF'))

    elseif cmd == 'obj' then
        settings.show_obj = not settings.show_obj
        windower.add_to_chat(8, 'Sortie: Objectives '..(settings.show_obj and 'ON' or 'OFF'))

    elseif cmd == 'loot' then
        settings.show_loot = not settings.show_loot
        windower.add_to_chat(8, 'Sortie: Loot/Galli '..(settings.show_loot and 'ON' or 'OFF'))

    elseif cmd == 'all' then
        settings.hide_all = not settings.hide_all
        windower.add_to_chat(8, 'Sortie: Minimal mode '..(settings.hide_all and 'ON (NM+Bitzer only)' or 'OFF'))

    elseif cmd == 'debug' then
        settings.debug = not settings.debug
        windower.add_to_chat(8, 'Sortie: Debug '..(settings.debug and 'ON' or 'OFF'))

    elseif cmd == 'bscan' then
        scan_all_bitzers()
        windower.add_to_chat(8, 'Sortie: Scanning all Bitzers zone-wide...')

    elseif cmd == 'help' then
        windower.add_to_chat(8, 'SortiePlus v3.0 Commands:')
        windower.add_to_chat(8, '  //sort [a-h]    - Switch sector display')
        windower.add_to_chat(8, '  //sort on/off    - Toggle addon')
        windower.add_to_chat(8, '  //sort boss      - Toggle boss info display')
        windower.add_to_chat(8, '  //sort obj       - Toggle objectives display')
        windower.add_to_chat(8, '  //sort loot      - Toggle loot/galli display')
        windower.add_to_chat(8, '  //sort all       - Minimal mode (NM+Bitzer only)')
        windower.add_to_chat(8, '  //sort bscan     - Scan Bitzers zone-wide')
        windower.add_to_chat(8, '  //sort save      - Save position settings')
        windower.add_to_chat(8, '  //sort track #   - Track mob by widescan index')
        windower.add_to_chat(8, '  //sort scan #    - Query mob info by index')
        windower.add_to_chat(8, '  //sort debug     - Toggle debug output')
        windower.add_to_chat(8, '  //sort zone      - Show current zone ID')
    end
end

----------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Returns cardinal direction string (N/NE/E/SE/S/SW/W/NW) from player to target.
-- FFXI coords: +X = East, +Y = North
function cardinal(px, py, tx, ty)
    local dx = tx - px
    local dy = ty - py
    local angle = math.atan2(dx, dy)
    local deg = math.deg(angle)
    if deg < 0 then deg = deg + 360 end
    local dirs = {'N','NE','E','SE','S','SW','W','NW'}
    local idx = math.floor((deg + 22.5) / 45) % 8 + 1
    return dirs[idx]
end

function show_UI()
    tracking_window:show()
    floor_window:show()
end

function hide_UI()
    tracking_window:hide()
    floor_window:hide()
end

function log(msg)
    if settings.debug then
        if msg == nil then
            windower.add_to_chat(80, '[Sortie] nil')
        else
            windower.add_to_chat(80, '[Sortie] '..tostring(msg))
        end
    end
end

function gear_update()
    gear = gear + 1
    if gear > 4 then gear = 1 end
end

----------------------------------------------------------------------
-- Mouse click on floor selector
----------------------------------------------------------------------
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if floor_window:hover(x, y) then
        if type == 2 then
            local window_x = tonumber(settings.Floor.pos.x)
            local sectors = {'A','B','C','D','E','F','G','H'}
            for i = 0, 7 do
                if x > window_x + 40*i and x < window_x + 40*(i+1) then
                    location = sectors[i+1]
                    local idx = i + 1
                    if mob_tracking[idx] then
                        windower.add_to_chat(8, 'Sortie: Tracking '..mob_tracking[idx].name)
                        track_on(mob_tracking[idx].index)
                    end
                    -- Reset boss state on any sector switch
                    boss_counter = nil
                    boss_timer_start = nil
                    boss_timer_active = false
                    -- Auto-scan Bitzers when entering basement
                    if location >= 'E' and location <= 'H' then
                        scan_all_bitzers()
                    end
                    return true
                end
            end
        end
    end
end)
