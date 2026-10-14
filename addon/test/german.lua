-- Second Wind on a German client: its own language file (Text_deDE.lua, a
-- first translation), a close call written in German, the spells found by
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
  ns.typeKey("Tier") == "Critter" and ns.typeKey("Wildtier") == "Beast",
  "a creature type's German word: its English one"
)

local counts = { total = 4, deaths = 0, traits = { elite = 3 }, foes = {} }
local word = ns.wordBefore(counts, { name = "Defiaswache", rank = "elite", level = 12 }, { level = 12 })
check(
  word == "Defiaswache, ein Elitegegner. Von deinen 4 Beinahe-Toden: 3 hatten einen Elitegegner.",
  "the word before a pull",
  word
)

io.stdout:write(("%s, German: %d checks passed\n"):format(G.FOREVER and "Forever" or "Classic Era", passed))
