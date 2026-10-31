# Second Wind

Second Wind gives you a debrief after a close call or death in World of
Warcraft. Once the fight is over, it shows the hits that hurt most, how
your health fell, and which potions or abilities were ready but went unused.
After a few debriefs, you can compare what your dangerous fights have in
common.

For Classic Era, Hardcore, Season of Discovery and World of
Warcraft: Forever, in English, French, German and Spanish. Nothing pops up
during combat. Duels and battlegrounds are excluded.

Get it from [CurseForge](https://www.curseforge.com/projects/1739380),
[Wago](https://addons.wago.io/addons/XKqEjbKy) or
[GitHub releases](https://github.com/salty-max/second-wind/releases).
One download covers all of them.

## In game

Type `/secondwind` or `/wind`, or click the minimap button to open the book.
By default, surviving below 15% health counts as a close call. The threshold
can also be set to 10%, 20% or 25%.

The **Debriefs** tab shows individual fights, with a health graph, foes,
large hits, healing, stuns and fears, and the tools you used or left ready.
**Patterns** compares close calls after your third debrief. **Lifelines**
shows the emergency supplies you carry now and their cooldowns.

Debriefs are saved across your account, separately for each game. A fallen
Hardcore character's last fight remains available from your next character.
An optional word before a pull gives, in chat, the counts of your close calls
against foes like the one you target.

Forever limits the health and combat information addons can read. Second
Wind reconstructs health estimates from damage, healing and the game's
low-health warning or death recap. That warning must stay on
(**Options > Combat**). The debrief shows when a health value is an estimate.

Second Wind reads in English, French, German and Spanish. German and Spanish
are first translations, with corrections welcome. Both Spanish clients share
the interface translation, with their own game names and decimal separator.
Other clients get English, with the game's own names for your foes, spells,
items and places in their language. Debriefs keep them by the game's ids, so
they follow your client's language, even after you switch.

- `/wind copy` opens a text version of the debrief for you to copy.
- `/wind lifelines` opens the Lifelines tab.
- `/wind probe` reports what the game let the addon read after your next fight.
- `/wind settings` opens settings for thresholds, alerts and the word before a pull.
- `/wind welcome` reopens the welcome page.
- `/wind minimap` shows or hides the minimap button.
- `/wind export` and `/wind import CODE` transfer settings.
- `/wind reset` clears this character's debriefs after confirmation.

Second Wind shares its book style with the other addons of the family. Each
works independently, and Keyring can gather their minimap buttons behind one button.

The full store description is in [addon/CURSEFORGE.md](addon/CURSEFORGE.md).
[docs/forever.md](docs/forever.md) records what Forever lets an addon see.

## Development

```bash
bun run check      # Translations, Lua, game and locale simulations, TOCs
bun run locales    # Write addon/SecondWind/Text_<locale>.lua from i18n/
bun run creatures  # Write the creatures' portraits from wow-data's databases
bun run package    # Create dist/SecondWind-<version>.zip
scripts/release.sh --version X.Y.Z [--hold] NOTES.md
```

The release script tags and pushes. GitHub Actions publishes the addon on
GitHub, CurseForge and Wago. The shared kit is copied to
`addon/SecondWind/Kit.lua` from `../addon-kit`.

## License

[MIT](LICENSE). Not affiliated with Blizzard Entertainment.
