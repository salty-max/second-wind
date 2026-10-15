-- Second Wind on a German client: its own language file (Text_deDE.lua, a
-- reviewed interface), a close call written in German, the spells found by
-- the client's own names, the creature types, the word before a pull.
--   luajit addon/test/german.lua; FOREVER=1 luajit addon/test/german.lua
LOCALE = "deDE"
local G = dofile("addon/test/game.lua")
local ns = G.ns
local L = ns.kit.L
local passed = 0
local function check(cond, msg, got)
  if not cond and got then msg = msg .. ": got " .. tostring(got) end
  assert(cond, msg)
  passed = passed + 1
  io.stdout:write("✓ ", msg, "\n")
end

G.login()
check(ns.locale == "deDE" and L["Debriefs"] == "Berichte", "the German language file")
check(
  ns.fmt(L["%s's %s"], "Defias-Magier", "Feuerball") == "Feuerball von Defias-Magier",
  "… a sentence in its own order"
)
check(ns.tenths(2.5) == "2,5", "… numbers with a decimal comma")

G.spellNamed(871, "Schildwall")
G.state.book = { ["Schildwall"] = { id = 871, cd = 1800 } }
local ready = ns.readyTools()
check(#ready == 1 and ready[1].n == "Schildwall" and ready[1].k == "guard", "Shield Wall found as Schildwall")

G.state.health = G.state.maxHealth
ns.setOption("threshold", 15)
G.sight("Felsenkiefertrogg", { level = 11, type = "Humanoid" })
G.pull()
G.wait(1)
G.hit({ from = "Felsenkiefertrogg", amount = 90 })
G.wait(1)
G.hit({ from = "Felsenkiefertrogg", amount = 70, spell = { 9053, "Feuerball", 4 }, crit = true })
G.wait(2)
G.leave()
local d = ns.record().debriefs[#ns.record().debriefs]
local card = ns.cardOf(d)
check(
  card.title:find("^Beinahe%-Tod: ") and card.title:find("Gesundheit$"),
  "a close call's title in German",
  card.title
)
local lessons = table.concat(card.lessons, " | ")
check(lessons:find("Schildwall war bereit und blieb ungenutzt%."), "… a lesson: the guard unused", lessons)
check(
  ns.typeIdOf("Tier") == ns.CRITTER and ns.typeIdOf("Wildtier") == 1 and ns.typeName(1) == "Wildtier",
  "a creature type's German word: its id, and back"
)

local counts = { total = 4, deaths = 0, traits = { elite = 3 }, foes = {} }
local word = ns.wordBefore(counts, { name = "Defiaswache", rank = "elite", level = 12 }, { level = 12 })
check(
  word == "Defiaswache, ein Elitegegner. Von deinen 4 Beinahe-Toden: 3 hatten einen Elitegegner.",
  "the word before a pull",
  word
)

-- A ready tool whose use cannot be observed must never be called unused.
local unknown = {
  kind = "close",
  lowPct = 5,
  zone = "Dun Morogh",
  ready = { { n = "Schildwall", k = "guard" } },
  unused = {},
  untold = { "Schildwall" },
}
local function section(page, title)
  for _, s in ipairs(page.sections) do
    if s.heading == title then return s end
  end
end
local facts = ns.factsOf(unknown)
local had = section(ns.cardOf(unknown), L["What you had"])
check(#facts.untold == 1 and #facts.used == 0 and #facts.unused == 0, "unknown use stays separate from used and unused")
check(
  had and had.rows[1].state == "untold" and had.lines[1] == "Bereit, Nutzung nicht feststellbar: Schildwall",
  "the German card preserves that uncertainty"
)
check(#ns.lessonsOf(unknown) == 0, "no unused-tool lesson from an unknown use")

-- Control loss can span all of the descent, part of it, or an unmeasured
-- fight. Both percentages and death must fit the assembled German sentence.
local held = {
  kind = "death",
  lowPct = 0,
  readyT = 0,
  lowT = 5,
  length = 5,
  held = { { t = 0, to = 5 } },
  ready = { { n = "Schildwall", k = "guard" } },
  unused = { { n = "Schildwall", k = "guard" } },
}
local lessonsHeld = ns.lessonsOf(held)
check(
  #lessonsHeld == 1 and lessonsHeld[1] == "Kontrollverlust, durchgehend bis zu deinem Tod.",
  "control lost until death: a complete German endpoint",
  lessonsHeld[1]
)
had = section(ns.cardOf(held), L["What you had"])
check(
  had.rows[1].state == "held" and had.lines[1] == "Bereit, aber du hattest keine Kontrolle: Schildwall",
  "unusable through control loss is not described as a missed opportunity"
)
held.kind, held.lowPct, held.lowT, held.length = "close", 5, 10, 10
held.readyT, held.held = 4, { { t = 5, to = 8, what = "Betäubt" } }
held.unused, held.ready = {}, {}
check(
  ns.lessonsOf(held)[1] == "Betäubt für drei Sekunden bei sinkender Gesundheit, bis 5 %.",
  "partial control loss: German duration and health endpoint"
)
held.blind = true
check(
  ns.lessonsOf(held)[1] == "Betäubt für drei Sekunden des Kampfes.",
  "an unmeasured fight makes no claim about the health descent"
)
check(ns.lowOf({ lowPct = 11, lowAtEnd = true }) == "11 % oder weniger", "end-of-fight health remains an upper bound")
check(ns.lowOf({ lowPct = 20, lowRange = { 15, 25 } }) == "etwa 20 %", "rebuilt health stays approximate")

-- One hit versus several: the damage value is the total, not per hit.
for _, n in ipairs({ 1, 2 }) do
  local cardHits = ns.cardOf({
    kind = "close",
    lowPct = 5,
    foes = { { name = "Felsenkiefertrogg", hits = n, damage = 80 } },
  })
  check(
    section(cardHits, L["Foes"]).lines[1] == ("Felsenkiefertrogg: %d Treffer mit insgesamt 80 Schaden"):format(n),
    n .. " hit(s): German total damage"
  )
end
local bandages = ns.carryPage({ { n = "Leinenverband", k = "bandage", wrapped = 10, left = 0 } })
check(
  section(bandages, L["Bandages"]).lines[1] == "Leinenverband: Kürzlich bandagiert, 10 s"
    and bandages.figures[2][1] == "0",
  "the named bandage lockout still prevents readiness"
)
for _, n in ipairs({ 0, 1, 2 }) do
  check(
    ns.kit.plural(n, "%d debrief", "%d debriefs"):format(n) == ("%d %s"):format(n, n == 1 and "Bericht" or "Berichte"),
    n .. " debrief(s): German plural rule"
  )
end

-- Run the diagnostic through a real replay with no description of the
-- control effect. It knows control was lost, not which effect caused it.
G.state.health = G.state.maxHealth
G.slash("probe")
G.pull()
G.stun({ seconds = 2, untold = true })
G.wait(3)
G.leave()
local probe = SecondWindSettings.probes[#SecondWindSettings.probes]
check(
  table.concat(probe.lines, "\n"):find("Kontrollverlust: festgestellt, ohne Angaben des Spiels", 1, true),
  "the diagnostic fallback names the known fact without inventing a cause"
)

io.stdout:write(("%s, German: %d checks passed\n"):format(G.FOREVER and "Forever" or "Classic Era", passed))
