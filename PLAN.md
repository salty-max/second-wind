# Second Wind

A World of Warcraft addon that teaches you from your close calls. After a fight
that nearly killed you, or did, a short debrief: how it happened, what you had
ready and didn't use, and what your close calls have in common. For Classic Era
(Hardcore above all), TBC Anniversary and World of Warcraft: Forever, standalone,
in the family's look (the shared kit, ~/code/wow-addons/addon-kit) and released like its
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

## Step 3, the debrief (11 October 2026)

Done as planned, in three parts: the tools (`Tools.lua`: every class's and
people's emergency spells by name, the bag's healing, bandage and escape
items by id with the spell their use casts, checked against classic-db and
the TBC Anniversary client's tables), the facts and lessons (`Debrief.lua`:
pure, the two weightiest lessons told), and the card in the book with its
chat link and the game's alert.

## Step 4, the patterns (11 October 2026)

Done as planned: from three debriefs on, the Patterns tab counts what comes
back (the lessons' own tests, as traits), where, the foes met more than once
and the tools left unused most often; the commonest trait is said above in a
sentence of counts ("In 3 of your 5 close calls, you went in below 60%
health.") once it marks half of them. The warning before a pull waits, as
decided.

## Step 5, Forever (11 October 2026)

Forever's own documentation (its interface code, 1.60.1) says what it hides:
an addon's restrictions are active while the player affects combat, in an
encounter or a PvP match; `UnitHealth` is secret then, a cast's spell may be
(`SecretWhenUnitSpellCastRestricted`), the damage meter is secret in combat
and readable after; `UnitHealthPercent` through a curve stays secret (for
display only); a notice comes just before the restrictions begin
(`ADDON_RESTRICTION_STATE_CHANGED`, Activating), while values are readable.

So, on Forever: the fight begins at that notice (my health, my ready tools);
its low point is my health at its end when it was hidden (a close call
healed back during the fight is missed, said on the card); what was ready
at its start stands for what was ready below half; a hidden cast means
nothing is called unused; the damage meter, after the fight, gives the foes
and the harm by spell. `/wind probe` checks it all in the Forever client:
the user's test, before 0.1.0.

## What players carry (11 October 2026, the user's ask)

The bag held potions, healthstones and bandages only; Hardcore players carry
much more for the worst moments. From the guides and lists (Wowhead's
Hardcore tips, Warcraft Tavern's PvP consumables list on barrens.chat, the
Hardcore consumables and professions guides): quest rewards (Magic Dust,
Slumber Sand, Really Sticky Glue, Bag of Marbles, Restoring Balm, Light of
Elune), engineering (Target Dummies, Iron and Thorium Grenades, the
Net-o-Matic, Rocket Boots, the Cloaking Device, the Rocket Helmet, the Mind
Control Cap, the Shrink Ray, dragonlings, the reflectors), alchemy (the
protection potions, Stoneshield, Magic Resistance, Purification, Major
Rejuvenation, Flask of Petrification, Swim Speed, Noggenfogger), First Aid's
anti-venoms, and trinkets (Nifty Stopwatch, Skull of Impending Doom, Tidal
Charm, Linken's Boomerang, the Insignias and TBC's Medallions). 172 items in
all, each resolved by name in the game's own tables, with the spell its use
casts. A tool counts only where it could have helped: a cure with what it
cures on me (the spell data says what each removes), a protection against
harm of its school, a slow fall in a fall, a worn item worn.

## Decided (11 October 2026)

The user took the four recommendations: a close call below 15% by default; the
card opens on its own after a death, on a click after a close call; the
pre-pull warning later, not in 0.1.0; frost steel for its colour.

## A review (11 October 2026, after 0.1.0)

Another model read the code and the page. Its points, and what was done:

- On Forever, with the casts hidden, the card listed every ready tool as
  "Used" (the used ones were taken as the ready less the unused, and nothing
  was unused): fixed, the card says "Ready" alone there.
- "Ready" is evidence, "would have saved you" isn't; above all when the
  player couldn't act. The recorder now keeps the stretches control was lost
  (stunned, feared, charmed...: `C_LossOfControl` on every client, its
  account hidden in a fight on Forever; `HasFullControl` else, readable on
  Forever): a lesson says it ("Stunned the whole way down to 11% (Cheap
  Shot).") and, held the whole way, nothing ready is a lesson, the card shows
  it as out of reach, the patterns don't count it as left unused.
- A bandage under blow after blow is noise: it counts only with three
  seconds without harm below half health.
- Forever misses a close call recovered from before the fight's end: the
  welcome (on Forever) and the page say so.

Next, from the same review, once real fights have been read: the health
graph marked with the hits that mattered, the foes' arrivals and what I used;
the patterns against every fight's (how many fights in all had three foes,
not only the close calls), so a count says something of danger.

## Forever, and its Hardcore (11 October 2026)

The user: Second Wind is far more use on Classic Era than on Forever, and a
Hardcore realm on Forever would make that a problem. What Forever's own
interface documentation (1.60.1) says:

- My health is secret in any fight (`UnitHealth`: SecretReturns; the Combat
  restriction is "the player is actively affecting combat", open world
  included; no predicate lets my own health through), my casts while it
  lasts, the combat log closed to addons. (Corrected below, "Forever, what
  is verified": my own casts are not secret; out of a fight my health most
  likely reads.) So a close call I recover from
  before the fight ends can't be seen as such, only its end.
- What it gives: my health before (the notice before the restrictions) and
  after; the damage meter once out of combat (the harm by spell, each marked
  `isAvoidable` and `isDeadly`; healing done, by spell, each naming a unit);
  losing control (`HasFullControl`); the death recap.
- And maybe: the game's own low-health warning (`LowHealthFrame`, the red
  edge) is Blizzard's code comparing my true health to 35% and showing a
  frame; whether an addon sees it shown in a fight, only the game can say.

Asked of the game first: `/wind probe` reports the warning and the meter's
healing (and whom it names) since 11 October. Then, by what it says:

1. The warning seen: a mark in a blind fight, "below 35%, 6 seconds in",
   on the card and the graph; a fight that went below 35% kept even when it
   ended above the threshold (not called a close call: "your health fell
   below 35%").
2. The harm told as a bound: the meter's harm against my health, and my
   healing: "you took 140% of your health in harm and were healed for 75%:
   at worst, 10%". A fight whose worst could pass the threshold is a
   possible close call, said so, never more.
3. The meter's avoidable marks: a lesson when most of the harm was avoidable
   (on Classic too, should its spells carry the mark).

## More (11 October 2026: built the same night, at the user's ask)

- The health graph marked: the hits that mattered, the foes' arrivals, what
  I used, control lost.
- The patterns against every fight's: a short tally of every fight's traits,
  so "three foes or more: 4 of 6 close calls" stands beside "in 1 of 20
  fights".
- My kit: a page of what I carry now for the worst moments (ready, on
  cooldown, how many) and what kind I carry none of; counts, no advice.
- A debrief as plain text to copy, for a guild's channel or a Discord.
- The warning before a pull (decided for later): out of combat, at a target,
  when it matches what my close calls share, a line, never in a fight.

All five built: the graph by time, marked (`ns.marksOf`); every fight
tallied (`record.fights`) and each trait set against it from twenty on; the
third tab, the Lifelines (`ns.carried`, `ns.carryPage`; first named What you carry); Copy as text
(`ns.textOf`, `/wind copy`); the word before a pull (Pull.lua, on by default,
"A word before a pull" in the settings). And, asked the same evening, what
went unused on Forever: told by what a use leaves behind, read after the
fight (`ns.tracesOf`: one fewer in the bags, a cooldown begun and when; a
spell without a cooldown leaves none, and the card says so). `GetItemCount`
and item cooldowns are never secret on Forever; spell cooldowns and auras
only while combat's restriction lasts.

## Forever, what is verified (11 October 2026)

The user: "do a real thorough research before telling me something is not
possible". Read: Forever 1.60.1's generated API docs (every secrecy flag),
Blizzard's own UI code in the same build, the API lists of the globals
addons see (Ketho's BlizzardInterfaceResources, `forever` branch), the
wiki's "Secret values" page (its predicates, verbatim), Blizzard's Midnight
posts, and a beta test write-up (wowforeverbuilds, build 1.60.1.69913).

| | On Forever | Source | Sure |
|---|---|---|---|
| My health | secret, in a fight and out of it | measured at rest by Apotheca's maintainer (FOREVER-PROBE.md: a Hunter and a Priest, builds 69977 and 70009: "Health and power are secret even out of combat", max readable; a StatusBar read back secret too); `UnitHealth` SecretReturns with no condition. I had argued the other way from the predicates' wording; the measurement settles it | measured; the probe reads it out of a fight |
| The hits on me (`UNIT_COMBAT`) | plain amounts (wound, heal, miss; critical; school), no attacker | no secrecy flag on its payload; a developer measured every amount plain in an open-world fight (forever-addon-kit) | docs + one report; the probe counts them |
| My health through the heal calculator | most likely secret (its health getters lack the ReturnsNeverSecret its other getters carry; `HasSecretValues`) | UnitHealPredictionCalculatorAPI docs | the probe reads it |
| My max health | readable (secret for units not player-controlled) | SecretWhenUnitHealthMaxRestricted | docs |
| A health bar's value read back | secret | StatusBar `GetValue`: SecretReturnsForAspect BarValue | docs |
| The game's low-health warning | Blizzard's code shows `LowHealthFrame` below 35% of my true health (`doNotFlashLowHealthWarning` off, the default); its shown state carries no secret aspect of its own | LowHealthFrame.lua/.xml | unverified: the probe |
| The combat log | closed: its reader moved to the secure-only namespace ("no deprecation is (intentionally) provided"); not among addons' globals; testers report registering the event errors | CombatLogSecure docs, Deprecated_CombatLog.lua, API lists, wowforeverguides | docs + reports |
| My own casts | readable: cast info is secret only "if the unit ... is not the player or their pet" | SecretWhenUnitSpellCastRestricted (wiki) | docs; the probe |
| Control lost (mine) | readable: secret only "if the subject unit is not the active player" | SecretWhenLossOfControlInfoRestricted (wiki) | docs |
| Cooldowns, auras | secret while combat's restriction lasts (a spell may be flagged never secret), readable after | SecretWhenCooldownsRestricted, SecretWhenUnitAuraRestricted | docs |
| Item counts, item cooldowns | never secret | `C_Item.GetItemCount`, `C_Container.GetItemCooldown`: no secret flag | docs |
| The damage meter | secret in combat, readable after; spells marked avoidable, deadly | SecretWhenInCombat | docs |
| The death recap | no secrecy flag on its functions; its event fields undocumented in this build | DeathRecapDocumentation | docs, partly |
| The audio alerts' health | Blizzard's code keeps the last percent on its frame (`lastUnitHealthPercent`), the alerts off by default | Blizzard_CombatAudioAlertManager.lua | unverified, unused |
| Unwrapping a secret | `secretunwrap` closed to addons | FrameScript docs, API lists | docs |

What changed in the addon: on Forever the game's low-health warning, where
an addon sees it shown, is the close call ("Close call: below 35% health"),
recovered from or not; should a build let my health read out of a fight,
its end is read too (said "11% or lower": a dip before may have gone lower);
deaths from the recap; my own casts tell what I used, the traces adding what they don't;
the welcome and the page say so. Hearthtale's close calls (UnitHealth below
10%) can't fire on Forever either: the same warning could stand in there.

### Measured on Forever (11 October 2026, the beta realm, build 1.60.1.70338: the user's paladin, level 20, Loch Modan)

From the character's saved file after a real fight (90 seconds, a Dark Iron
Insurgent):

- **The game's low-health warning is seen by an addon**: the close call was
  written from it (`below` 35, `warned` 53.8 seconds in). Close calls work on
  Forever.
- **My own casts are readable in a fight**: eight, by id and name (Seal of
  Righteousness, Judgement, Holy Light, Holy Strike, Divine Protection), each
  at its moment.
- **My health was read neither as the fight began (at the notice before the
  restrictions) nor once it was over**: no `startPct`, no `endPct`; as
  measured by Apotheca, hidden out of a fight too.
- **The damage meter answers after the fight**: the foe and the harm by spell
  (Attack, 746 in all).
- What the card made of it showed a fault, fixed: a foe the meter names had
  an empty line (no blows counted); it reads "746 in all" now.

The probe's report of the same fight (the account's saved file): 42
`UNIT_COMBAT` events, none with a hidden amount (37 wounds, 746 in all: the
damage meter's sum exactly; 2 misses; 3 heals, 425: the meter's healing);
my health hidden in the fight and out of it; the heal calculator no way
round (hidden); the meter's healing names no one. Counted from the warning
(53.8 seconds, my health then between 32.4% and 35% of 731: within the last
hit's size), the fight began at 95-98%, its lowest point was 18.6-21.2% at
61.5 seconds (before the first Holy Light), its end 51-54%. Each hit's size
and moment, and my health over a fight within about a hit's size, can be
rebuilt on Forever.

Built the same day (the user: "yes build it"): on Forever, each blow and heal
on me is kept as UNIT_COMBAT tells it, and my health rebuilt from the
warning (within the crossing blow, no more than a full start allows), back
from a death (the overkill off, from the recap a second later) or from a
readable end: the graph, the low point ("about 20%", its range on the card),
the hits that mattered, the lessons that need them, the heals in all; the
threshold applies again (a close call when the lowest could be below it).
The user's fight, replayed in the sim from its rows: lowest 19-21% at 61.5
seconds, every blow the Dark Iron Insurgent's; above 15%, no close call.
