# Second Wind: Close Call & Death Debrief

<!-- Project description for curseforge.com (paste as the project's description).
The project's title on CurseForge: "Second Wind: Close Call & Death Debrief" (the
addon's own name stays Second Wind). -->

<!-- Summary (the project's summary on CurseForge and Wago, and the TOCs' Notes):
A debrief after each close call and death: how the fight went, what you had ready and didn't use, and what your close calls share. -->

**A debrief after each close call and death.** When a fight leaves you on your last breath and you live, or ends you, Second Wind writes it down once the fight is over: how it went, the hits that mattered, what you had ready and didn't use, and a lesson or two to take from it. Over time, the book shows what your close calls have in common.

Nothing shows during a fight: no frames, no alerts, no sounds. On Hardcore, the debrief of a death is the life's last page.

For Classic Era (Hardcore, Season of Discovery), TBC Anniversary and World of Warcraft: Forever. A sibling of [Hearthtale](https://www.curseforge.com/wow/addons/hearthtale), [Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex) and [Explorer's Field Journal](https://www.curseforge.com/wow/addons/explorers-field-journal), in the same look (each in its own colours), but it stands alone.

## The debrief

A fight you survive below 15% health (or 10, 20, 25: your choice) is a close call; a fight that kills you is a death. Each gets a card:

- **The lessons**: one or two, by rule over what was recorded, never invented: *"A Major Healing Potion was in your bags, ready."* *"Three foes at once."* *"Defias Pillager joined six seconds in."* *"From half your health to 9% in two seconds."*
- **The killing blow**, from the game's own death recap: who, with what, and how much more than you had.
- **The foes**: when each came in, their hits and misses, their level and rank where the game tells.
- **The hits that mattered**: the three largest, and how long before your lowest point each landed.
- **Your health over the fight**, drawn against your threshold.
- **The heals**, yours and others'.
- **Out of your control**: when a stun or a fear held you, how long and by what. Held the whole way down, what you had is shown as out of reach, never as a lesson.
- **What you had**: what was ready when your health first fell below half, what you used, and what went unused.

## What you had ready

Every class's and people's emergency spells (every rank: Divine Shield, Ice Block, Vanish, Feign Death, Frost Nova, Intimidating Shout, Last Stand, Escape Artist, Will of the Forsaken, Stoneform...) and 172 items players carry for the worst moments, read from the Hardcore guides:

- **Heals and bandages**: potions, healthstones, Whipper Root Tubers, Night Dragon's Breath; a bandage only when the blows paused long enough to use one, and not while Recently Bandaged.
- **Cures**: Anti-Venom, Elixir of Poison Resistance, Restorative Potion..., counted only while what they cure is on you.
- **Guards**: Free Action, Limited Invulnerability, Living Action, the protection potions, counted only when harm of their school came.
- **Holds**: grenades, nets, target dummies, Magic Dust.
- **Ways out**: Swiftness Potion, Noggenfogger, Rocket Boots, the Gnomish Cloaking Device, Insignias; swimming and slow-fall ones only in the water or a fall.
- **Worn ones** (helms, boots, trinkets) only when worn; anything on cooldown isn't counted.

## The patterns

From your third debrief on, a second page counts what your close calls share: *"In 4 of your 6 close calls, you went in below 60% health."* The traits that come back, the places, the foes met more than once, and the tools left unused most often. Counts, never advice.

## Every game, one download

The same file for Classic Era (Hardcore, Season of Discovery), TBC Anniversary and World of Warcraft: Forever: each game loads its own part.

World of Warcraft: Forever closes the combat log to addons and hides your health and casts during a fight. Second Wind reads what the game still allows: the fight's foes and its harm by spell from the game's damage meter once the fight is over, your health at its end for its lowest point, what you had ready as it began, and when you lost control. So on Forever, a close call is seen by your health when the fight ends: one you recover from before then goes unseen. Deaths are always debriefed. A card says what the game hid, and with your casts hidden, nothing is called used or unused. `/wind probe` reports, after your next fight, what the game let it read.

Duels and battlegrounds are never debriefed.

## Settings

The first time each character logs in with Second Wind, a welcome page introduces it and offers its choices (`/wind welcome` shows it again). After that: Options → AddOns → Second Wind (or `/wind settings`, or right-click the minimap button): the close call's threshold, a line in chat with a link to the debrief, the game's alert, the debrief opened on its own after a death, the minimap button.

Settings are each character's own, as in most interface addons. A character can take another's: choose one of your characters of the same game from a list (on the welcome page or the Options page), or bring them from anywhere with a code: `/wind export` on one character, `/wind import CODE` on the other.

Other commands: `/secondwind` or `/wind` opens the book; `/wind reset` clears a character's debriefs (it asks first); `/wind minimap` shows or hides the button.

## Siblings

The same look, each in its own colours, and each stands alone:

- **[Hearthtale](https://www.curseforge.com/wow/addons/hearthtale)** ([Wago](https://addons.wago.io/addons/E6gzPnN1)). Your character's own journal, written as you play: a diary entry in their voice at each rest, and an epitaph if a Hardcore life ends.
- **[Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex)** ([Wago](https://addons.wago.io/addons/j6jAL0NR)). The lore of Azeroth, written for you as you explore: each zone, figure of legend, people and quest you meet adds a page to your codex.
- **[Explorer's Field Journal](https://www.curseforge.com/wow/addons/explorers-field-journal)** ([Wago](https://addons.wago.io/addons/ZKbq5y61)). A bestiary, an atlas and a record of your fish and herbs, filled in as you travel, with an Explorers' League naturalist's notes.

## Source

MIT licensed: [github.com/salty-max/second-wind](https://github.com/salty-max/second-wind). Items and spells resolved from the CMaNGOS project's Classic database and the TBC Anniversary client's tables. Not affiliated with Blizzard Entertainment.
