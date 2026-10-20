-- Second Wind on a French client: its own language file (Text_frFR.lua), a
-- close call written in French, the spells found by the client's own names
-- (by their ids), the lifelines, the word before a pull, a foe's type and a
-- foe Forever's meter names in French.
--   luajit addon/test/french.lua; FOREVER=1 luajit addon/test/french.lua
LOCALE = "frFR"
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
local function said(pattern)
  for _, l in ipairs(G.printed) do
    if l:find(pattern) then return true end
  end
  return false
end

G.login()
check(ns.locale == "frFR" and L["Debriefs"] == "Bilans", "the French language file, loaded by the client's own name")
check(L["A word Second Wind never says"] == "A word Second Wind never says", "… a word it lacks stays English")
check(
  ns.fmt(L["%s's %s"], "Mage défias", "Boule de feu") == "Boule de feu de Mage défias",
  "… a sentence in its own order"
)
check(ns.tenths(2.5) == "2,5", "… numbers with a decimal comma")

-- The spells, by the client's own names (read by their ids).
G.spellNamed(871, "Mur protecteur")
G.state.book = { ["Mur protecteur"] = { id = 871, cd = 1800 } }
local ready = ns.readyTools()
check(#ready == 1 and ready[1].n == "Mur protecteur" and ready[1].k == "guard", "Shield Wall found as Mur protecteur")

-- A close call, its card and its lessons in French.
G.state.health = G.state.maxHealth
ns.setOption("threshold", 15)
G.sight("Trogg Rochemâchoire", { level = 11, type = "Humanoïde" })
G.pull()
G.wait(1)
G.hit({ from = "Trogg Rochemâchoire", amount = 90 })
G.wait(1)
G.hit({ from = "Trogg Rochemâchoire", amount = 70, spell = { 9053, "Boule de feu", 4 }, crit = true })
G.wait(2)
G.leave()
local d = ns.record().debriefs[#ns.record().debriefs]
check(d and d.kind == "close", "a close call recorded")
local card = ns.cardOf(d)
check(card.title:find("^Mort frôlée : ") and card.title:find("de santé$"), "its title in French", card.title)
local headings = {}
for _, s in ipairs(card.sections) do
  headings[s.heading] = true
end
check(headings["Ennemis"] and headings["Les coups décisifs"], "… its sections' headings")
local lessons = table.concat(card.lessons, " | ")
check(lessons:find("Mur protecteur était disponible et n'a pas servi%."), "… a lesson: the guard unused", lessons)
check(not lessons:find("[A-Z][a-z]+ was "), "… no English sentence among them", lessons)
local text = ns.textOf(d)
check(text:find("Ennemis :") and text:find("Ce que vous aviez :"), "… the card as text, French headings")
check(said("Mort frôlée, ") and said("|Hsecondwind:debrief:%d+|h%[Bilan%]"), "… its line in chat, its link")

-- The lifelines, in French.
local page = ns.carryPage(ns.carried())
check(page.title == "Vos recours", "the lifelines page")
check(
  page.sections[1].heading == "Protections" and page.sections[1].lines[1] == "Mur protecteur : disponible",
  "… a guard, ready",
  page.sections[1].lines[1]
)

-- The creature types: the game's French word, its id; the id, its word.
check(
  ns.typeIdOf("Bestiole") == ns.CRITTER and ns.typeIdOf("Bête") == 1 and ns.typeName(1) == "Bête",
  "a creature type's French word: its id, and back"
)
-- (Forever's meter names a foe only: its creature by its French name; the
-- same names on Classic)
check(ns.creatureIdOf("Vermine kobold") == 6, "a foe's French name finds its creature")
if G.FOREVER then
  -- (what wow-data's build leaves out of Forever, Season of Discovery's: a
  -- saved debrief's foe named by its id, its name never finding it: Elaine
  -- Compton, 213077 left out, 256391 Forever's own)
  check(
    ns.creatureNameOf(213077) == "Elaine Compton" and ns.creatureIdOf("Elaine Compton") == 256391,
    "a foe wow-data leaves out: named by its id, never found by its name"
  )
end
do
  -- (a debrief written on an English client reads in French, by its creatures' ids)
  local list = ns.record().debriefs
  table.insert(list, {
    kind = "death",
    at = 7,
    killer = { name = "Snow Leopard" },
    recap = { { src = "Snow Leopard", amount = 9 } },
    spells = { { src = "Snow Leopard", amount = 9 } },
    foes = { { name = "Snow Leopard", npc = 1201, hits = 1, damage = 9 }, { name = "Kyle", player = true, hits = 1 } },
  })
  G.reload()
  local old = list[#list]
  check(
    old.foes[1].name == "Léopard des neiges"
      and old.killer.name == "Léopard des neiges"
      and old.recap[1].src == "Léopard des neiges"
      and old.spells[1].src == "Léopard des neiges"
      and old.foes[2].name == "Kyle",
    "a debrief written in English reads in French, its creatures by their ids (a player's name kept)",
    old.foes[1].name
  )
end
-- (a debrief written on an English client, its place, spells, tools and
-- types by their ids, reads in French; one with no id, its English name kept)
G.spellNamed(78, "Frappe héroïque")
G.spellNamed(20594, "Forme de pierre")
local list = ns.record().debriefs
table.insert(list, {
  kind = "close",
  at = 8,
  zone = "Dun Morogh",
  zoneArea = 1,
  sub = "Coldridge Valley",
  subArea = 132,
  casts = { { id = 78, t = 1, name = "Heroic Strike" } },
  ready = { { n = "Stoneform", k = "guard", sid = 20594 } },
  unused = { { n = "Stoneform", k = "guard", sid = 20594 } },
  foes = {
    { name = "Grrr", type = "Beast", hits = 1 },
    { name = "Trrr", typeKey = "Undead", type = "Undead", hits = 1 },
  },
})
table.insert(list, { kind = "close", at = 9, zone = "Westfall", sub = "Moonbrook", foes = {} })
-- (inside a building, no area id: by its building area's, the language's list)
table.insert(list, { kind = "close", at = 10, zone = "Ironforge", sub = "The Library", subInside = 15660, foes = {} })
table.insert(list, { kind = "close", at = 11, zone = "Ironforge", sub = "La Bibliothèque", foes = {} })
G.reload()
local library, here = list[#list - 1], list[#list]
check(
  library.sub == "La Bibliothèque" and here.subInside == 15660 and here.sub == "La Bibliothèque",
  "a place inside a building, kept by its building area's id: read in French, found from the French"
)
table.remove(list)
table.remove(list)
local was, plain = list[#list - 1], list[#list]
check(
  was.sub == "Vallée des Frigères"
    and was.zone == "Dun Morogh"
    and was.casts[1].name == "Frappe héroïque"
    and was.ready[1].n == "Forme de pierre"
    and was.unused[1].n == "Forme de pierre"
    and was.foes[1].type == "Bête"
    and was.foes[1].typeId == 1
    and was.foes[2].typeId == 6
    and was.foes[2].typeKey == nil
    and was.foes[2].type == "Mort-vivant",
  "a debrief written in English reads in French: its place, spells, tools and types by their ids",
  was.sub
)
check(
  plain.subArea == 20 and plain.zoneArea == 40 and plain.sub == "Moonbrook",
  "… one kept by its English names finds its ids on a French client too (a name the client can't give stays)"
)

-- The word before a pull, in French.
local counts = { total = 4, deaths = 0, traits = { elite = 3 }, foes = {} }
local word = ns.wordBefore(counts, { name = "Garde défias", rank = "elite", level = 12 }, { level = 12 })
check(
  word == "Garde défias, une créature d'élite. Sur vos 4 morts frôlées, 3 comptaient une créature d'élite.",
  "the word before a pull",
  word
)

io.stdout:write(("%s, French: %d checks passed\n"):format(G.FOREVER and "Forever" or "Classic Era", passed))
