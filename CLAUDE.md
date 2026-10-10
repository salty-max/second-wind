# Second Wind

A World of Warcraft addon: after a fight that nearly killed you, or did, a
debrief written once the fight is over: how it went, the hits that mattered,
what you had ready and didn't use, a lesson or two by rule, and over time what
your close calls share. For Classic Era (Hardcore above all), TBC Anniversary
and World of Warcraft: Forever. The fourth of a family (Hearthtale, Lorekeeper's
Codex, Explorer's Field Journal: same look, kit and release tooling), standalone.
The plan, its research and its decisions: PLAN.md.

## Layout

- `addon/SecondWind/`: one folder for every game, installable as is: each game
  loads its own TOC (`SecondWind_Vanilla.toc`: Classic Era, 11509; `_TBC.toc`:
  TBC Anniversary, 20506; `_Camelot.toc`: Forever, 16001), the same but for
  the interface (`scripts/package.ts` checks).
  - `Kit.lua`: a copy of the kit shared with the siblings (~/code/addon-kit):
    never edit the copy; `bun run kit:sync` after changing the kit, `bun run
    kit:check` to verify.
  - `Core.lua`: the character's record (`SecondWindChar`: guid, debriefs), the
    events (`ns.on`, `ns.onUnit` for one unit's), the login, `/secondwind`
    and `/wind` (`/sw` is the game's stopwatch).
  - `Settings.lua`: each character's settings (the kit's profiles, code
    `SW1:p15:c1:t1:d1:h0:a250`): the close call's threshold (10, 15, 20,
    25%), a line in chat, the alert, the debrief after a death, the minimap
    button; the Options page.
  - `Tools.lua`: what I had for a bad moment: every class's and people's
    emergency spells by name (every rank; guard, stop, away) and 172 items
    players carry for the worst moments (the Hardcore guides and lists read
    11 October 2026), each by id with the spell its use casts, resolved by
    name in classic-db and the TBC Anniversary client's ItemSparse/ItemEffect:
    heals, bandages, cures (counted only while what they cure is on me),
    guards (a protection potion counted only if harm of its school came),
    holds (grenades, nets, dummies, Magic Dust...), ways out (rocket boots,
    the cloaking device, Insignias...; swim and slow-fall ones only in the
    water or a fall); worn ones (head, feet, trinkets) counted only worn.
    `ns.readyTools()` (known, off cooldown but for the global one, usable;
    a bandage not while Recently Bandaged), `ns.relevantTools(ready, fight)`,
    `ns.unusedOf(ready, casts, since)`.
  - `Forever.lua`: where the combat log tells nothing (Forever): the game's
    damage meter (`C_DamageMeter`, readable once out of combat) for the foes
    and the harm by spell (`ns.meterFill`, never for a fall); `/wind probe`,
    which says after the next fight what the game let the addon read (the
    combat log, my health and casts, the notice before combat's
    restrictions, the meter).
  - `Recorder.lua`: each fight as it went (its start: combat or the first
    harm; its end: combat's, a moment later so a death wins, or QUIET seconds
    after a fall), the foes (when each came, hits, misses, damage, level and
    rank where the game can tell), the log's last 20 seconds copied at each
    new low point, my health over it, my casts, what was ready when my health
    first fell below half (`ns.readyTools`, the card's); a debrief kept for a
    close call (below the threshold) or a death (with the game's recap, read
    a moment later), never for a duel or a battleground; a hundred kept, a
    death always. Its schema in its header. `ns.summaryOf(d)`: a line.
    Forever: the fight begins at the notice before combat's restrictions
    (`ADDON_RESTRICTION_STATE_CHANGED`, Activating: my health and cooldowns
    still readable); my health hidden in it, its low point is read at its
    end (`lowAtEnd`) and what was ready at its start stands in (`readyFrom`);
    my casts hidden, nothing is called unused (`castsHidden`).
  - `Debrief.lua`: a debrief read, pure: `ns.factsOf(d)` (its title, place,
    the three largest hits and how long before the low point, the fall from
    half health, what was used and what wasn't), `ns.lessonsOf(d)` (rules
    over the facts, weighed, the two weightiest told: harm from the world,
    went in hurt, a potion ready, a guard unused, three foes or more, one
    late, a hold or a way out unused, a blow that took a third, half health
    to the low in three seconds, an elite or a foe two levels up, mostly
    magic); `ns.cardOf(d)`: the card's text (title, the line under it, the
    lessons, sections: the killing blow, foes, the hits that mattered,
    heals, what you had); `ns.traitsOf(d)`: a fight's traits, the lessons'
    tests as yes or no, for the patterns.
  - `Patterns.lua`: what the close calls share, pure: `ns.patternsOf(debriefs)`
    from three debriefs on (counts, never advice): the commonest trait said
    above when it marks half of them, the traits marking a third and twice
    or more, the places, the foes met more than once, the tools left unused
    most often.
  - `Book.lua`: the theme (frost steel) and the window, its tabs: the
    Debriefs (the list, newest first; the open one's card, my health drawn
    as bars against the threshold), the Patterns (the whole sheet). Pages
    are drawn by one renderer (`drawPage`: title, the line under it,
    lessons, the graph for a card, sections). A debrief written
    (`ns.debriefed`): a line in chat with a link (`|Hsecondwind:debrief:<at>|h`),
    the game's alert (the new recipe's), the book opened at a death's
    (`ns.openDebrief(at)`; settings).
  - `Welcome.lua`: the kit's welcome page, once per character.
  - `Minimap.lua`: the button.
- `addon/test/game.lua`: the fake game: the API the addon calls, its events,
  a character, and fights to replay (`G.pull`, `G.hit`, `G.miss`, `G.heal`,
  `G.debuff`, `G.cast`, `G.env` (a fall, the water), `G.leave`, `G.die`;
  `G.sight` a creature the game can name, `G.duel`, `state.instance`,
  `state.castsSecret`): the combat log as `COMBAT_LOG_EVENT_UNFILTERED` on
  Classic only, the health with it (a secret value in a fight on Forever),
  Forever's notices around combat, the damage meter (secret in combat on
  Forever), the game's death recap (`C_DeathRecap`, killing blow first),
  timers run by `G.wait`. `addon/test/sim.lua`: the checks, on both games.
- `addon/CURSEFORGE.md` (to come): the project page.

## Rules

- Nothing in combat: no window, no alert; a debrief waits for the fight's end.
- Facts only from what was recorded; a lesson is a rule over those facts,
  never invented, never a lecture.
- Forever: never compare or print a secret value (`ns.secret`); a game
  function is checked before use only where the clients differ.
- The tests replay fights as the game sends them: a new behaviour comes with
  its replay in sim.lua.

## Commands

```bash
bun run check        # lint, the simulation on both games, the TOCs
bun run package      # dist/SecondWind.zip, for a test in the game
bun run format:lua
bun run kit:sync     # after changing ~/code/addon-kit
scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md   # tag, push; Actions publish
```

## Conventions

- Conventional Commits, lowercase subjects; commit locally, ask before any
  push, release or deploy.
- English game clients only, as the siblings.
- Lua: StyLua (`stylua.toml`) and selene (`selene.toml`, the game's globals
  in `wow.yml`: add one when the addon calls a new game function).
