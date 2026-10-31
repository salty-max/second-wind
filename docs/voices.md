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
- **Numbers** (the user's rule, 31 October 2026). A count in a sentence (foes,
  seconds, levels, the "and two more" of a list) is a word to ten and digits
  after: "Three foes at once", "six seconds in", "two levels above you",
  "joined 62 seconds in". Figures are digits wherever they stand:
  percentages ("62%"), damage, the tallies of your fights ("3 of your 5 close
  calls"), labels and tables ("4 of 6"). A sentence never opens on a digit: a
  count that opens one is a word as far as twenty ("Twelve foes at once.";
  past twenty, digits: a crowd that size is rare),
  and a sentence that would open on a tally is turned so it opens on its
  subject ("Rockjaw Trogg was in 3 of your 5 close calls.").
- **Verbless facts.** A lesson may be a fact without a verb, as a log reads
  ("Three foes at once.", "From half your health to 9% in a second."): that
  is the voice. Inside a sentence a fragment is not: what follows a comma is a
  clause ("In 3 of your 5 close calls, an elite or a boss was among them.").
- **Deaths.** A death card says "your death" where a close call says "the low
  point" ("9 s before your death"), and control lost is told with a subject,
  in plain words: "You were stunned for six seconds, until your death (Hammer
  of Justice)." The state ("stunned", "feared") is the game's own word, its
  loss-of-control text, lowercase in an English sentence.
- **One term a thing.** "Foe", never "enemy", in the addon and on its store
  page. "Lifelines" names what you carry for the worst moments in every label
  and command, the paraphrase only as the Lifelines tab's sub. The line before
  a pull is "a word before a pull", never a "reminder" (a reminder promises
  advice).
- **Nothing in combat.** The voice is heard once the fight is over (see
  `CLAUDE.md`): the card, the banner, and the chat line before a pull, which
  states counts and nothing more.
- **Length.** A lesson is one sentence. A card is a title, one line under it,
  the two weightiest lessons, then sections of short rows. A pattern line is
  one sentence with its counts.

## Two real examples

Both are lines the tests (`addon/test/sim.lua`) replay and check word for word.

A debrief's lessons, the two weightiest told, joined here by a bar:

> Shield Wall and Disarm were ready and went unused. | A blow from Ragged Young Wolf took half of your health at once.

The patterns, from five debriefs (counts, never advice, and they start at three):

> 3 of 5: you went in below 60% health | 3 of 5: three foes or more were on you at once |
> 3 of 5: a foe joined after the start | 2 of 5: a healing potion or
> healthstone went unused

The templates behind them (`Debrief.lua`, `Pull.lua`) show the length and the
person: "You went in at %d%% health.", "%s took %s at once.", "%s was an
elite.", "%s was in %d of your %d close calls." Each is one fact.

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
