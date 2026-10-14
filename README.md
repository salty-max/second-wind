# Second Wind

Second Wind gives you a debrief after a close call or death in World of
Warcraft. Once the fight is over, see the hits that hurt most, how your
health fell, and which potions or abilities were ready but went unused.
After a few debriefs, you can compare what your dangerous fights have in
common.

For Classic Era, Hardcore, Season of Discovery, TBC Anniversary and World of
Warcraft: Forever, in English and French. Nothing pops up during combat.
Duels and battlegrounds are excluded.

Get it from [CurseForge](https://www.curseforge.com/projects/1739380),
[Wago](https://addons.wago.io/addons/XKqEjbKy) or
[GitHub releases](https://github.com/salty-max/second-wind/releases).
One download covers all of them.

## In game

Type `/secondwind` or `/wind`, or click the minimap button to open the book.
By default, surviving below 15% health counts as a close call. The threshold
can also be set to 10%, 20% or 25%.

The **Debriefs** tab shows individual fights, with a health graph, enemies,
large hits, healing, stuns and fears, and the tools you used or left ready.
**Patterns** compares close calls after your third debrief. **Lifelines**
shows the emergency supplies you carry now and their cooldowns.

Debriefs are saved across your account, separately for each game. A fallen
Hardcore character's last fight remains available from your next character.
Optional chat reminders before a pull use what happened in earlier fights.

Forever limits the health and combat information addons can read. Second
Wind reconstructs health estimates from damage, healing and the game's
low-health warning or death recap. Keep that warning enabled under
**Options > Combat**. The debrief shows when a health value is an estimate.

- `/wind copy` opens a text version of the debrief for you to copy.
- `/wind lifelines` opens your emergency supplies.
- `/wind probe` reports what the game let the addon read after your next fight.
- `/wind settings` opens settings for thresholds, alerts and reminders.
- `/wind welcome` reopens the welcome page.
- `/wind minimap` shows or hides the minimap button.
- `/wind export` and `/wind import CODE` transfer settings.
- `/wind reset` clears this character's debriefs after confirmation.

Second Wind shares its book style with Hearthtale, Lorekeeper's Codex and
Yonder. Each addon works independently. Keyring can gather
their minimap buttons.

The full store description is in [addon/CURSEFORGE.md](addon/CURSEFORGE.md).
[PLAN.md](PLAN.md) records the design decisions.

## Development

```bash
bun run check      # Check the translations, Lua, both game simulations (and a French client) and the TOCs
bun run locales    # Write addon/SecondWind/Text_<locale>.lua from i18n/
bun run creatures  # Write the creatures' portraits from wow-data's databases
bun run package    # Create dist/SecondWind-<version>.zip
scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md
```

The release script tags and pushes. GitHub Actions publishes the addon on
GitHub, CurseForge and Wago. The shared kit is copied to
`addon/SecondWind/Kit.lua` from `../addon-kit`.

## License

[MIT](LICENSE). Not affiliated with Blizzard Entertainment.
