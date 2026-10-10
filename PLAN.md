# Second Wind

A World of Warcraft addon that teaches you from your close calls. After a fight
that nearly killed you, or did, a short debrief: how it happened, what you had
ready and didn't use, and what your close calls have in common. For Classic Era
(Hardcore above all), TBC Anniversary and World of Warcraft: Forever, standalone,
in the family's look (the shared kit, ~/code/addon-kit) and released like its
siblings (the BigWigs packager: GitHub, CurseForge, Wago).

## The idea (11 October 2026)

Chosen by the user among three ideas (with a vista hunt and tavern dice), for
the gap it fills.

| Addon | What it does | What it leaves |
|---|---|---|
| Deathlog | Era Hardcore's community death database: heatmaps, the deadliest creatures | Not your own fights |
| Echoes: Hardcore Death History | Your deaths: killer, spell, where, level, falls and drowning | No damage breakdown, no close call ("not a damage meter") |
| Hardcore Recorder, Guild Chronicle | A run's history; a guild's memorial with last words | No fight |
| Deathlapse | A death recap: health over the last ~20 s, damage and heals | TBC Anniversary only, deaths only, the last one only (156 downloads) |
| Details!, Recount | Death logs among a damage meter's tabs | Deaths only, for raids |
| Blizzard's death recap | Retail's window, shipped with Forever | Not in Classic Era's interface; deaths only |

Nobody explains a fight you survived, what you had ready and didn't use, or what
your close calls share. Classic Era has no death recap at all. No addon named
Second Wind on CurseForge (checked 11 October 2026; confirm when the project is
made).

## What the game gives (research, 11 October 2026)

From Blizzard's own code for Classic Era 1.15.9 and Forever 1.60.1
(Gethe/wow-ui-source) and the clients' function lists
(Ketho/BlizzardInterfaceResources):

- **The combat log** (Classic Era, TBC Anniversary): `COMBAT_LOG_EVENT_UNFILTERED`
  with `CombatLogGetCurrentEventInfo` (Hearthtale reads it): every hit, heal,
  miss, cast and aura, with its source, amount, school and critical. The
  player's health (`UnitHealth`), cooldowns (`GetSpellCooldown`,
  `GetItemCooldown`), bags and auras are readable.
- **The death recap** (all three clients): `C_DeathRecap.GetRecapEvents`,
  `GetRecapMaxHealth`, `HasRecapEvents`, `GetRecapLink`. Each hit before a
  death: `timestamp`, `amount`, `overkill`, `absorbed`, `resisted`, `blocked`,
  `currentHP`, `sourceName` (unless `hideCaster`), `school`, `avoidable`,
  `deadly`; the first event is the killing blow (as Blizzard_DeathRecap reads
  it). Blizzard's window ships with Forever, not with Classic Era: the data is
  there on both.
- **Blizzard's damage meter** (all three): `C_DamageMeter`, type `DamageTaken`
  for a combat session, by source (creature id, name, classification) and by
  spell (amount, overkill, `isAvoidable`, `isDeadly`), and `Deaths` with each
  death's `deathRecapID`. On Forever its sessions are secret during combat
  (`SecretWhenInCombat`): readable once the fight is over, when a debrief is
  shown anyway.
- **Forever** closes the combat log to addons, and `UnitHealth` returns secret
  values (Hearthtale skips a close call when they are). There, a death is told
  from the recap and a fight from the damage meter; a close call needs the
  health readable, to test in the Forever client.

## Proposal

| Question | Proposal |
|---|---|
| A close call | Your health below 15% (the default; a setting: 10, 15, 20, 25) in a fight you survived, once a fight; a fall, a drowning, lava too. Not a duel, not a battleground. |
| A death | Every death; on Hardcore, the last debrief of the life. |
| When | Never in combat: when the fight ends, a toast (the kit's) and a chat line with a link, "Close call: 6% in Coldridge Valley"; the card opens on a click. After a death it opens on its own (you aren't playing then; on Hardcore it is the life's last page), a setting. |
| The card | Where, your level, the foes (level, elite or rare, how many and when each joined), how long it lasted; your health over the fight (a line drawn in the window); the hits that mattered (the largest, by source and school, criticals) and the heals you got (by whom, in a group); what you had and didn't use; one or two lessons. |
| What you had | Known, off cooldown and affordable when your health crossed 50%, and not used by the end: healing potions and healthstones (by item, every rank, the shared potion cooldown), bandages (unless Recently Bandaged), each class's emergency spells (Evasion, Vanish, Gouge, Ice Block, Frost Nova, Blink, Divine Shield, Blessing of Protection, Lay on Hands, Shield Wall, Last Stand, Intimidating Shout, Feign Death, Psychic Scream, Power Word: Shield, Fade, Death Coil, Howl of Terror, Barkskin, Bear Form, Frenzied Regeneration...), a curated table by spell, TBC's additions on TBC. |
| Lessons | Rules over the facts, never invented and never a lecture: "You started the fight at 48% health", "three attackers at once", "an add joined six seconds in", "two casters", "a critical took a third of your health", "a healing potion was ready", "two levels above you, elite". At most two, the weightiest first. |
| Patterns | Per character, over its debriefs: what most close calls share (started below 60%, three attackers or more, casters, elites, levels above, a zone, a creature). Shown in the book. A warning before a pull that matches them (a line, never a sound or a block) comes later, once real patterns show it would help. |
| The book | The kit's window: the debriefs by date (place, level, lowest health or death, foes), each opening its card; a tab for the patterns. Kept per character (the last 100, a death always). |
| Forever | Deaths from the recap, fights from the damage meter after combat, what you had from cooldowns and bags (to check they are not secret); close calls if the health is readable. Said plainly on the CurseForge page. |
| Look | The kit: windows, toasts, select, settings per character with codes, the welcome page; frost steel, blue-grey titles on cool panels (the Codex's gold on ink, the Field Journal's sage, Hearthtale's ember). |
| Not | No damage meter, no community database (Deathlog's), no sound by default, nothing in combat, nothing that plays for you. |

## Steps

1. The repository from the siblings' skeleton: the kit, the TOCs per game
   (`_Vanilla`, `_TBC`, `_Camelot`), the packager, CI, the release script; a
   fake game (`addon/test/game.lua`) that replays fights as combat log lines,
   health and casts.
2. The recorder: a rolling buffer of the last 20 seconds of the combat log
   that concerns me, health samples, the fight's start and end, its lowest
   point; the close call and the death (with the recap, where there is one).
3. The debrief: the facts (pure Lua, tested on replayed fights), what I had
   (the tools table, by class and by item), the lessons (rules), the card.
4. The book and the patterns.
5. Forever: the recap and the damage meter in place of the combat log, tried
   in the Forever client by the user.
6. Settings and the welcome page; the CurseForge and Wago projects (the user);
   CURSEFORGE.md with the siblings linked; release 0.1.0.

## Step 2, the recorder (11 October 2026)

Done as planned, with what the build showed:

- A fight ends a moment (0.3 s) after combat ends, so a death the game tells
  after the end of combat is the fight's end, not a close call and an empty
  death.
- A fall or the water out of combat is a fight of its own, over after three
  quiet seconds.
- A duel can't be told by the game for sure: a fight that began within three
  minutes of a duel asked for or offered, against players only, is one.
- On Forever, the player's health is secret in a fight: no close call there
  (step 5 tries the damage meter); a death is told from the game's recap.

## Decided (11 October 2026)

The user took the four recommendations: a close call below 15% by default; the
card opens on its own after a death, on a click after a close call; the
pre-pull warning later, not in 0.1.0; frost steel for its colour.
