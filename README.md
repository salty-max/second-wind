# Second Wind

A World of Warcraft addon: after a fight that nearly killed you, or did, a
debrief once the fight is over: how it went, the hits that mattered, what you
had ready and didn't use, and over time what your close calls share. For
Classic Era (Hardcore), TBC Anniversary and World of Warcraft: Forever.

On [CurseForge](https://www.curseforge.com/projects/1739380),
[Wago](https://addons.wago.io/addons/XKqEjbKy) and
[GitHub](https://github.com/salty-max/second-wind/releases): one zip for every
game (each loads its own TOC). A sibling of Hearthtale, Lorekeeper's Codex,
Explorer's Field Journal and Keyring, in the same look (the shared kit,
`addon/SecondWind/Kit.lua`). The project page: addon/CURSEFORGE.md; the plan
and its decisions: [PLAN.md](PLAN.md).

## Use

- `/secondwind` or `/wind` (or the button by the minimap) opens the book.
- `/wind copy` (the open debrief as text), `/wind lifelines` (what you carry for
  the worst moments), `/wind probe` (what the game lets Second Wind read).
- `/wind settings`, `/wind minimap`, `/wind welcome`, `/wind export`,
  `/wind import CODE`, `/wind reset`.

## Develop

```bash
bun run check      # lint, the simulation on Classic Era and Forever, the TOCs
bun run package    # dist/SecondWind-<version>.zip: one package for every game
scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md
                   # tag and push; GitHub Actions publish on GitHub, CurseForge and Wago
```

## License

MIT (see LICENSE). Not affiliated with Blizzard Entertainment.
