# Second Wind's architecture

The addon file by file (moved from CLAUDE.md on 20 October 2026; the map
stays there). The plan, its research and its decisions: `PLAN.md`.

## The files

- `addon/SecondWind/`: one folder for every game, installable as is: each game
  loads its own TOC (`SecondWind_Vanilla.toc`: Classic Era, 11509; `_TBC.toc`:
  TBC Anniversary, 20506; `_Camelot.toc`: Forever, 16001), the same but for
  the interface (`scripts/package.ts` checks).
  - `Kit.lua`: a copy of the kit shared with the siblings (~/code/wow-addons/addon-kit:
    the look, the window's pieces, the figures, the banners): never edit the copy; `bun run kit:sync` after changing the kit, `bun run
    kit:check` to verify.
  - `Core.lua`: every character's record of this game, account-wide
    (`SecondWindAccount.characters[guid]`: who (a class by its token), level, fallen, debriefs,
    fights: every fight's tally; a fallen Hardcore life's kept, read from the
    next; the per-character `SecondWindChar` of before 0.1.3 moved in at the
    login), `ns.record()` this character's, `ns.debriefsOf(every)`,
    `ns.whose(d)`, `ns.fightsOf(every)`; the creatures seen (my target, under
    the mouse, a nameplate: `SecondWindAccount.seen[name]` = npc id, type id,
    rank, the last 400), `ns.knownFoe(foe)` making whole a foe a fight named
    only (Forever's meter: its portrait, its kind); `ns.ownNames(d)`: a
    death recap's names the creatures' own (Forever's adds a word after
    each unit's, "Snow Leopard Nub"), the units of one name one foe;
    `ns.localize(d)`: a debrief keeps ids beside the names of its day (the
    places' area ids, found by name with `C_Map.GetAreaInfo` (an older
    debrief's English names by `Game_<game>.lua`'s, on any client), a place inside
    a building its building area's, `subInside`, by the language's list in
    its Text file, `i18n/<locale>/subzones.json`, the kit's; spells, tool
    spells, creatures, creature types by their ids) and every name with an
    id is written again in the client's language, at each login and for each
    debrief written; the saved file keeps the ids alone (`ns.forSave` at the
    logout: every name an id gives back exactly let go, a foe's sources and
    killer by its creature's id, `srcNpc`, `npc`; a player's name and a name
    no id gives kept), `ns.localize` naming them again at the login (the
    family's rule: ids, never names);
    the events (`ns.on`, `ns.onUnit` for one
    unit's), the login, `/secondwind` and `/wind` (`/sw` is the game's
    stopwatch; `/wind copy`, `/wind lifelines` (or `carry`, `kit`)).
  - `Settings.lua`: each character's settings (the kit's profiles, code
    `SW1:p15:t1:d1:w1:h0:a250`): the close call's threshold (10, 15, 20,
    25%), the alert after a death (the line in chat has no setting: always), the debrief after a death, the word
    before a pull, the minimap button; the Options page.
  - `Tools.lua`: what I had for a bad moment: every class's and people's
    emergency spells by name, each with its ids (any rank's: the client
    names it in its own language, `GetSpellInfo(id)`, so every rank and
    every language is found; guard, stop, away) and 172 items
    players carry for the worst moments (the Hardcore guides and lists read
    11 October 2026), each by id with the spell its use casts, resolved by
    name in classic-db and the TBC Anniversary client's ItemSparse/ItemEffect:
    heals, bandages, cures (counted only while what they cure is on me),
    guards (a protection potion counted only if harm of its school came),
    holds (grenades, nets, dummies, Magic Dust...), ways out (rocket boots,
    the cloaking device, Insignias...; swim and slow-fall ones only in the
    water or a fall); worn ones (head, feet, trinkets) counted only worn.
    `ns.readyTools()` (known, off cooldown but for the global one, usable;
    a bandage not while Recently Bandaged), `ns.relevantTools(ready, fight)`
    (a bandage only with LULL seconds without harm below half health),
    a tool known by its key, never its name (`ns.toolKey`: "i<item>",
    "s<the first id its entry lists>"; a cast by its spell's id, any rank's:
    `Game_<game>.lua`, `bun scripts/game.ts`, from wow-data's
    SkillLineAbility; `ns.castKey`), an item's name the language's
    (`i18n/<locale>/items.json`, every tool's item, TBC Anniversary's own
    from wow-data's frozen TBC client names),
    `ns.unusedOf(ready, casts, since)`, `ns.tracesOf(ready, t0)` (Forever:
    what a use left, read after the fight: one fewer in my
    bags, a cooldown begun, its start the moment; a spell without a cooldown
    leaves none, `untold`), `ns.toolOfCast(c)`; what I carry now,
    `ns.carried()` and its page, the Lifelines, `ns.carryPage(list)` (by kind, ready or how
    long until, the kinds I carry none of).
  - `Debrief.lua`'s `ns.lowOf(d)`: how low, in words ("11%", "below 35%").
  - `Forever.lua`: where the combat log tells nothing (Forever): the game's
    damage meter (`C_DamageMeter`, readable once out of combat) for the foes
    and the harm by spell (`ns.meterFill`, never for a fall); `/wind probe`,
    which says after the next fight what the game let the addon read (the
    combat log, my health and casts, the notice before combat's
    restrictions, the meter: the harm marked avoidable, my healing and whom
    it names; losing control; the game's own low-health warning at 35%,
    `LowHealthFrame`, shown by Blizzard's code from my true health), each
    report kept with the rows it was drawn from (each hit and heal as
    `UNIT_COMBAT` gave it, each cast, each control event, the warning's
    moment, the meter's spells; a secret as the word "secret") in
    `SecondWindSettings.probes`, the account's saved file (the last ten): the
    user hands over the file, not a paste. A death's recap names the fields
    Forever kept secret (`recapHidden`).
  - `Recorder.lua`: each fight as it went (its start: combat or the first
    harm; its end: combat's, a moment later so a death wins, or QUIET seconds
    after a fall), the foes (when each came, hits, misses, damage, level and
    rank where the game can tell), the log's last 20 seconds copied at each
    new low point, my health over it, my casts, what was ready when my health
    first fell below half (`ns.readyTools`, the card's), the stretches I had
    lost control (`held`: stunned, feared, charmed...: the game's account,
    `C_LossOfControl`, where it gives it, else `HasFullControl`, readable on
    Forever), the longest stretch without harm below half (a bandage's
    time); a debrief kept for a close call (below the threshold) or a death
    (with the game's recap, read a moment later), never for a duel or a
    battleground; a hundred kept, a death always; every fight, kept or not,
    tallied by its traits (`record.fights`). Its schema in its header.
    `ns.summaryOf(d)`: a line. Forever (its 1.60.1 docs and the wiki's
    secret predicates, 11 October 2026; PLAN.md, "Forever, what is
    verified"): my health secret, in a fight and out of it (measured at
    rest on builds 69977 and 70009: Apotheca's probe; `state.healthReadable`
    replays a build that would let it read out of a fight: `lowAtEnd`, "11%
    or lower", `endPct`): my health rebuilt (`rebuilt`: "warning", "death",
    "end") from each blow and heal `UNIT_COMBAT` tells (`told`: amounts plain,
    measured), counted from the game's own low-health warning
    (`LowHealthFrame`, shown by Blizzard's code below 35% of my true health,
    its Show hooked: between 35% less the blow that crossed it and 35%, no
    more than a full start allows, which is then the likeliest: `lowRange`),
    back from a death (the killing blow's overkill off, from the recap) or
    from a readable end; the samples, the low point, the blows for the card
    (one foe the meter names dealt them all), the heals in all; a close call
    when its lowest could be below the threshold; without blows told, none
    (the warning alone is no close call). The
    fight begins at the notice before combat's restrictions (cooldowns still
    readable: `readyFrom` "start");
    my own casts and control lost are the player's, never secret; what a use
    leaves (`ns.tracesOf`) adds what the casts didn't tell (`traced`), a use
    with no trace `untold` only should the casts be hidden.
  - `Debrief.lua`: a debrief read, pure: `ns.factsOf(d)` (its title, place,
    the three largest hits and how long before the low point, the fall from
    half health, what was used and what wasn't), `ns.lessonsOf(d)` (rules
    over the facts, weighed, the two weightiest told: harm from the world,
    went in hurt, a potion ready, a guard unused, three foes or more, one
    late, a hold or a way out unused, a blow that took a third, half health
    to the low in three seconds, an elite or a foe two levels up, mostly
    magic, control lost on the way down; held all of it (`ns.helpless`),
    nothing ready is a lesson); `ns.cardOf(d)`: the card's text (title, the
    line under it, the lessons, sections: the killing blow, foes, the hits
    that mattered, out of your control, heals, what you had: used and unused
    where my casts or their traces tell it); `ns.traitsOf(d)`: a fight's
    traits, the lessons' tests as yes or no, for the patterns;
    `ns.marksOf(d)`: the graph's marks (the hits that mattered, a foe
    joining, what I used, control lost); `ns.textOf(d)`: the card as text.
  - `Patterns.lua`: what the close calls share, pure:
    `ns.patternsOf(debriefs, fights)` from three debriefs on (counts, never
    advice): the commonest trait said above when it marks half of them, the
    traits marking a third and twice or more (each set against every
    fight's tally once twenty are counted: "(4 of your 40 fights)"), the
    places, the foes met more than once, the tools left unused most often;
    `ns.countsOf(debriefs)`, the counts, for the word before a pull.
  - `Pull.lua`: the word before a pull (every character's close calls of this
    game counting: a past life's lessons): out of a fight, at a target like the
    foes of my close calls (an elite, two levels up, one met in two of them)
    or when I'm hurt and they mostly began so, a line in chat with the
    counts; never in a fight, a name not again for five minutes, never at a
    critter. `ns.wordBefore(counts, foe, me)`, pure.
  - `Creatures_Classic.lua` and `Creatures_Forever.lua` (each game's TOC
    loads its own; generated by `bun run creatures`, scripts/creatures.ts,
    from wow-data's databases, `../wow-data`: every creature that can be a
    foe, not critters, totems, pets or the databases' helpers; committed,
    never edited, kept out of StyLua and selene): each creature's display id
    (its portrait) by its id (Forever's own creatures have none: their
    portrait found in the game). Their names are each language's.
  - `Locale.lua` and `Text_<locale>.lua`: the reader's language. Every word
    goes through `L["..."]` (the kit's `K.L`, English by default; plurals
    through `K.plural(n, "one", "many")`), each sentence whole, as a
    language orders its own (`ns.fmt` reads a translation's numbered blanks,
    "%2$s de %1$s", which LuaJIT's format can't), a number with a decimal
    by `ns.tenths`, a date by `ns.date` (the kit's month names). The TOCs
    load `Text_[TextLocale].lua` after Locale.lua: the client loads its own.
    `scripts/locales.ts` (`bun run locales`, its `--check` in `bun run
    check`) writes them for the game's twelve languages from
    `i18n/<locale>/` (`words.json`; `meta.json`: plural rule, decimal,
    flagged; `creatures.json`: every foe's name in the language by its id,
    each game's, complete, for every language, English one of them (enGB
    takes enUS's), from wow-data's databases, `bun
    scripts/creature_names.ts <locale>`, loaded by `ns.names`:
    `ns.creatureNameOf(id)`, `ns.creatureIdOf(name)` for a foe Forever's
    meter names only; no English fallback; its `foreverLeftOut`, the
    `creaturesLeftOut` of the Text file: what wow-data's build leaves out of
    Forever, Season of Discovery's `left_out`, by name alone, behind
    Forever's own (`__index`), so a saved debrief's id is named and no name
    finds it, `creatureIdOf` going through `pairs`); `--keys` writes
    `i18n/words.json`, every word to translate. A creature type is kept by
    its id (`ns.typeIdOf`, from the game's word through `C_CreatureInfo`),
    its word the game's (`ns.typeName`), its icon and the critter test by
    the id. No semicolons in any
    language. French done 14 October 2026, German (flagged: a first translation) the same day.
    Spanish added 16 October 2026, flagged until native review: esMX borrows
    esES prose but keeps its own names and metadata (decimal point, not comma).
    Spanish uses tú, informe, combate casi mortal and recursos de emergencia.
    Older reports can store a creature type in any previous client language.
    Game_<game>.lua keeps unambiguous legacyTypeIds from wow-data's localized
    creature_type names, generated by scripts/game.ts. Recover the id before
    asking the current client for the display label. Never translate an old
    label by matching only English and the current language.
    Keep unknown usage separate from unused tools and control loss from a
    missed opportunity. Test complete assembled sentences in both regions.
  - `Page.lua`: the theme (frost steel) and the pages' renderer
    (`ns.newPage`, `page:draw(c, d, keep)`): a header (a round portrait: the
    foe that did the most harm, `ns.faceOf`; the title, the line under it, a
    rule), its figures (`c.figures`: the kit's strip, `K.figures`; the
    Patterns' and the Lifelines'), the lessons (an accent bar beside each), the chart for a card
    (`Page.newGraph`, under a heading, "Your health", in a box of the page's
    width (a shade, an edge in the rule's colour), room inside it: a dark plot, 100% and 50% lines, the threshold a red
    danger zone tinting the fill, my health a stepped line (red below the
    threshold) over an opaque fill on whole pixels, the low point a dot and
    `ns.lowOf`, a death a skull; a lane under it of `ns.marksOf`: tools'
    slots (the kit's), joining foes' faces, hits' red ticks, control lost's
    purple bars; the time; a legend under it, a swatch for each abstract mark
    shown (the threshold, the hits, control lost), drawn as the chart draws
    it; its words on a frame above the plot;
    hovered: the moment's health and marks),
    then sections, each line drawn by its row (`sections[i].rows`, beside the
    `lines` the copy and the tests read); the rows with a picture are the
    kit's card rows (`K.cardRow`, as every book's: a foe's face round, a
    spell or an item in a square slot), the icon strips the kit's slots
    (`K.slot`, as the game draws its own; a kind I carry none of, an empty
    slot): `foe` (the creature's still
    portrait, `SetPortraitTextureFromCreatureDisplayID`, its display
    Creatures_<game>.lua's, else found once by a hidden
    model and kept on the foe; a
    player's class crest; else its kind's icon; its ring by rank, its name
    in the colour of its level against mine), `blow` (a spell's icon by id,
    a heal's, the world's; its amount; a bar of the share), `held`, `tools`
    (a strip of slots under its label, the state in the label; untold greyed),
    `tool` (a lifeline: its state, dimmed while not ready; an empty slot for
    a kind I carry none of), `share` (a bar, every fight's rate a mark),
    `text`; a `note` section small. Icons hovered: the game's tooltip.
  - `Book.lua`: the window, its tabs: the
    Debriefs (the list, newest first, this character's or every character's
    at the select above, `book.every`, each row and card then naming whose it
    is; the open one's card, my health over
    the fight by time against the threshold, marked (`ns.marksOf`, their
    words under it), "Copy as text" (`ns.showCopy`: a box to copy from)),
    the Patterns (the whole sheet), the Lifelines (Tools.lua's page, drawn
    again as bags and cooldowns change); a tab with nothing yet, a page of
    its own all the same (what it will hold). A debrief written
    (`ns.debriefed`): a line in chat with its weightiest lesson and a link
    (`|Hsecondwind:debrief:<at>|h`), every close call; after a death only, a
    banner (the kit's, among the game's alerts) and the book opened at it
    (`ns.openDebrief(at)`; settings).
  - `Welcome.lua`: the kit's welcome page, once per character.
  - `Minimap.lua`: the button.
- The opt-in that shares what the game tells of the world (the kit's
  `K.collect`: quests' texts, creatures' facts, NPCs' lines, loot by source;
  off until the player ticks it on the welcome page or the Options page)
  keeps it account-wide in `SecondWindCollect`, which Ravenpost sends to the
  addons' database.
- `addon/test/game.lua`: the fake game: the API the addon calls, its events,
  a character, and fights to replay (`G.pull`, `G.hit`, `G.miss`, `G.heal`,
  `G.debuff`, `G.cast` (a spell's cooldown begun, by its `cd`), `G.use`,
  `G.env` (a fall, the water), `G.stun` (control lost: the game's account
  readable on Forever: the player's own), `G.leave`, `G.die`; `G.target`,
  `G.sight` a creature the game can name, `G.duel`, `state.instance`,
  `state.castsSecret`, `state.cvars`; `G.shown`: every text the pages set;
  `LowHealthFrame` shown at 35%; the meter's healing done): the combat log
  as `COMBAT_LOG_EVENT_UNFILTERED` on
  Classic only, the health with it (a secret value on Forever, always),
  Forever's notices around combat, the damage meter (secret in combat on
  Forever), the game's death recap (`C_DeathRecap`, killing blow first),
  timers run by `G.wait`. `addon/test/sim.lua`: the checks, on both games.
  `addon/test/french.lua`: a French client (`LOCALE = "frFR"` before
  game.lua: its own language file, French spell names by id with
  `G.spellNamed`), a close call's card and lessons, the lifelines, the word
  before a pull.
- `addon/test/spanish.lua`: both Spanish clients, on both games: complete
  debriefs, uncertainty, control loss, patterns, regional names and decimal
  separators, and saved reports re-localized by id.
- `addon/CURSEFORGE.md`: the project page (its summary in a comment, the TOCs'
  Notes), the siblings linked on CurseForge and Wago.

## The daily game data

- `.github/workflows/game-data.yml`: daily and by hand, wow-data's
  `addon-data.yml` builds the game data again from wow-data's pins (the creatures' portraits, every foe's name and every building area's in every language, then the language files);
  a pull request when a generated file changes, the checks run on it, then
  rebased onto main by itself and told to the owner's phone in words
  (Ravenpost's inbox). The generators' list lives there: a new one goes in too.
