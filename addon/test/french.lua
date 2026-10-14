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

-- The creature types: the game's French word, its English key.
check(
  ns.typeKey("Bestiole") == "Critter" and ns.typeKey("Bête") == "Beast",
  "a creature type's French word: its English one"
)
if G.FOREVER then
  -- (Forever's meter names a foe only: its creature by its French name)
  check(ns.creatures.names["Vermine kobold"] == 6, "Forever: a foe's French name finds its creature")
end

-- The word before a pull, in French.
local counts = { total = 4, deaths = 0, traits = { elite = 3 }, foes = {} }
local word = ns.wordBefore(counts, { name = "Garde défias", rank = "elite", level = 12 }, { level = 12 })
check(
  word == "Garde défias, une créature d'élite. Sur vos 4 morts frôlées, 3 comptaient une créature d'élite.",
  "the word before a pull",
  word
)

io.stdout:write(("%s, French: %d checks passed\n"):format(G.FOREVER and "Forever" or "Classic Era", passed))
