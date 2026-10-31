# Second Wind's voice

Second Wind has one voice, the debrief's, and it is not a character: it is a
careful friend who was watching the fight and tells you what happened. This is
written from the shipped text (`addon/SecondWind/Debrief.lua`, `Patterns.lua`,
`Pull.lua`, and the English keys in `i18n/words.json` and each language's `i18n/<locale>/words.json`), not invented.
The hard rule behind it is in `CLAUDE.md`: facts only from what was recorded,
a lesson is a rule over those facts, never invented, never a lecture.

## The voice

- **Person.** The second person, to the player: "You went in at 41% health."
  The fight is told in the past tense, the standing of things now ("You're at
  62% health") in the present. Never "I" and never "we", the addon does not
  speak of itself.
- **Counts, never advice.** A debrief says what happened and what was ready,
  and the patterns say how often ("In 3 of your 5 close calls and deaths, you went in
  below 60% health"). It never says what to do: no imperative, no "you
  should", no "try", no "next time", no praise and no blame. The lesson is the
  fact set beside the habit, and the player draws the conclusion.
- **Plain, short, flat.** One fact a sentence, usually under 15 words, the
  subject first, a number where there is one. No adjectives for drama ("a
  brutal blow" is out, "A critical blow from <foe> took a third of your
  health at once" is the shape), no exclamation marks, no jokes, no second guessing.
  The tone of a log read aloud by someone who is on your side.
- **Words for numbers.** Counts of foes and seconds are words in a sentence
  ("Three foes at once", "six seconds in", "two levels above you"), digits in labels and tables ("62%",
  "4 of 6").
- **Nothing in combat.** The voice is heard once the fight is over (see
  `CLAUDE.md`): the card, the banner, and the chat line before a pull, which
  states counts and nothing more.
- **Length.** A lesson is one sentence. A card is a title, one line under it,
  the two weightiest lessons, then sections of short rows. A pattern line is
  one sentence with its counts.

## Two real examples

Both are lines the tests (`addon/test/sim.lua`) replay and check word for word.

A debrief's lessons, the two weightiest told, joined here by a bar:

> Shield Wall and Last Stand were ready and went unused. | Disarm was ready too.

The patterns, from five debriefs (counts, never advice, and they start at three):

> 3 of 5: you went in below 60% health | 3 of 5: three foes or more at once |
> 3 of 5: a foe joined after the start | 2 of 5: a healing potion or
> healthstone went unused

The templates behind them (`Debrief.lua`, `Pull.lua`) show the length and the
person: "You went in at %d%% health.", "%s took %s at once.", "%s was an
elite.", "%d of your %d close calls were against %s." Each is one fact.

## What it never does

- Invents a cause the log does not show: a lesson's rule needs its facts in
  the record (`Debrief.lua`'s rules), and "no trace either way" is said when
  it is.
- Lectures, scolds or encourages. A death is a death. (The welcome page says
  "On Hardcore, the debrief of a death is the life's last page", the only
  gravity the addon allows itself, and not in a debrief.)
- Switches register: a debrief speaks to the player as the interface does, in
  English "you", French vous (nothing agreeing with the player), German du,
  Spanish tú (the family's table in `addon-kit/skills/wow-translating`).
