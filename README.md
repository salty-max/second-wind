# Second Wind

A World of Warcraft addon: after a fight that nearly killed you, or did, a
debrief once the fight is over: how it went, the hits that mattered, what you
had ready and didn't use, and over time what your close calls share. For
Classic Era (Hardcore), TBC Anniversary and World of Warcraft: Forever.

Releases: [GitHub](https://github.com/salty-max/second-wind/releases), one zip for
every game (unzip it into `Interface/AddOns`). The plan and its decisions:
[PLAN.md](PLAN.md).

## Use

- `/secondwind` or `/wind` (or the button by the minimap) opens the book.
- `/wind settings`, `/wind minimap`, `/wind welcome`, `/wind export`,
  `/wind import CODE`, `/wind reset`.

## Develop

```bash
bun run check      # lint, the simulation on Classic Era and Forever, the TOCs
bun run package    # dist/SecondWind.zip: one package for every game
```

## License

MIT (see LICENSE). Not affiliated with Blizzard Entertainment.
