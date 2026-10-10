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
  - `Book.lua`: the theme (frost steel) and the window, its tabs (Debriefs,
    Patterns).
  - `Welcome.lua`: the kit's welcome page, once per character.
  - `Minimap.lua`: the button.
- `addon/test/game.lua`: the fake game: the API the addon calls, its events,
  a character, and fights to replay (`G.pull`, `G.hit`, `G.heal`, `G.cast`,
  `G.leave`, `G.die`): the combat log as `COMBAT_LOG_EVENT_UNFILTERED` on
  Classic only, the health with it (a secret value in a fight on Forever),
  the game's death recap (`C_DeathRecap`, killing blow first), timers run by
  `G.wait`. `addon/test/sim.lua`: the checks, on both games.
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
