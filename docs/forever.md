# Forever, what is verified (11 October 2026)

The research behind Second Wind on Forever, moved from `PLAN.md` on 30 October
2026 when the plan (built long ago) was deleted: the design is in the code and
`docs/architecture.md`.

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
