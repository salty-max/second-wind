# Second Wind

A World of Warcraft addon: after a fight that nearly killed you, or did, a
debrief written once the fight is over: how it went, the hits that mattered,
what you had ready and didn't use, a lesson or two by rule, and over time what
your close calls share. For Classic Era (Hardcore above all), TBC Anniversary
and World of Warcraft: Forever. The fourth of a family (Hearthtale, Lorekeeper's
Codex, Yonder: same look, kit and release tooling), standalone
(salty-max/second-wind). Read the family's CLAUDE.md (`../CLAUDE.md`) first.

## Where things are

| What | Where |
|---|---|
| The addon file by file: Core, Settings, Tools, Forever, Recorder, Debrief, Patterns, Pull, the creatures, languages, Page, Book; the tests; the daily game data | `docs/architecture.md` |
| The plan, its research and its decisions ("Forever, what is verified") | `PLAN.md` |
| The store page | `addon/CURSEFORGE.md` |
| The words to translate, the creatures' names | `i18n/<locale>/` (`words.json`, `meta.json`, `creatures.json`, `items.json`, `subzones.json`) |

`docs/` is ignored locally (`.git/info/exclude`): the docs above are
force-added, anything else there is a local note, absent from a worktree.

## Commands

```bash
bun run check        # languages, game tables, lint, the simulation on both games, every language's test, TOCs
bun scripts/root.ts --run addon-kit/q.ts check -- bun run check   # the same, quiet, stamping the tree for the push
bun run package      # dist/SecondWind-<version>.zip (git describe), for a test in the game
bun run format:lua   # StyLua (stylua.toml); selene (selene.toml, the game's globals in wow.yml) runs in check
bun run kit:sync     # after a change to the kit (Kit.lua, Media, scripts/root.ts)
bun run creatures    # the creatures' portraits again (scripts/creatures.ts); game.ts, creature_names.ts <locale> likewise
scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md   # check, tag, push; Actions publish
```

## Hard rules

- Nothing in combat: no window, no alert; a debrief waits for the fight's end.
- Facts only from what was recorded; a lesson is a rule over those facts,
  never invented, never a lecture.
- Forever: never compare or print a secret value (`ns.secret`); a game
  function is checked before use only where the clients differ.
- The tests replay fights as the game sends them: a new behaviour comes with
  its replay in sim.lua.
- The saved file keeps ids, never names (a player's name aside): places,
  spells, tools, creatures and their types, named again in the client's
  language at each login. An old report's type label is turned back into an
  id first, never translated by matching English.
- The game's data comes from wow-data only (scripts/, through
  `scripts/root.ts`); `Creatures_*.lua`, `Game_*.lua` and the name files
  are generated, never edited, kept out of StyLua and selene. A new
  generator goes into `game-data.yml` too.
- Every language the game has, through `L` (French, German and Spanish
  translated, the others English until they are); no semicolons in any
  language. A new game function goes into `wow.yml`.
- `Kit.lua` and `scripts/root.ts` are the kit's copies: edit addon-kit,
  then `bun run kit:sync`.
- Conventional Commits, lowercase subjects, no AI trailers. Commit locally;
  ask before any push, release or deploy. The pre-push hook wants a check
  stamp on the tree (q), which `release.sh` makes after the version bump.
