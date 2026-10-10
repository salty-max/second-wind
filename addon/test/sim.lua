-- The addon in a fake game (game.lua): every check of this file, on Classic
-- Era or on Forever (FOREVER=1).
--   luajit addon/test/sim.lua; FOREVER=1 luajit addon/test/sim.lua
local G = dofile("addon/test/game.lua")
local ns = G.ns
local passed = 0
-- (print is the game's here, kept in G.printed: the checks write to stdout)
local function check(cond, msg)
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

-- ── the login ────────────────────────────────────────────────────────────────
G.login()
local record = ns.record()
check(record and record.guid == G.state.guid and #record.debriefs == 0, "a new character: an empty record of its own")
table.insert(record.debriefs, { at = 1 })
G.reload()
check(ns.record() == record and #ns.record().debriefs == 1, "a reload keeps the record")
G.state.guid = "Player-6113-0FFFFFFF"
G.reload()
check(ns.record() ~= record and #ns.record().debriefs == 0, "another character of the same name: a record of its own")

-- ── settings ─────────────────────────────────────────────────────────────────
check(ns.option("threshold") == 15 and ns.option("chat") and ns.option("toast"), "the defaults: below 15%, chat, alert")
check(
  ns.option("openAfterDeath") and not ns.option("minimapHidden"),
  "the defaults: a death's debrief opens, the button shows"
)
check(ns.profiles:export() == "SW1:p15:c1:t1:d1:h0:a250", "the settings as a code")
check(ns.profiles:import("SW1:p20:c0"), "a code taken")
check(ns.option("threshold") == 20 and not ns.option("chat"), "… its choices this character's")
check(not ns.profiles:import("FJ1:c1"), "another addon's code refused")
check(G.panel.name == "Second Wind" and G.panel.settings.SECONDWIND_THRESHOLD, "the Options page, the threshold on it")
local thresholds = {}
for _, o in ipairs(G.panel.settings.SECONDWIND_THRESHOLD.options()) do
  table.insert(thresholds, o.value)
end
check(table.concat(thresholds, ",") == "10,15,20,25", "… offered at 10, 15, 20 and 25%")

-- ── the welcome ──────────────────────────────────────────────────────────────
G.state.guid = "Player-6113-0AAAAAAA"
G.state.name = "Pippa"
G.reload()
G.offer("PLAYER_ENTERING_WORLD", true, false)
G.wait(5)
check(
  ns.welcome.frame and ns.welcome.frame:IsShown(),
  "a new character: the welcome page, a few seconds after its login"
)
ns.welcome.frame:Hide()
G.reload()
G.offer("PLAYER_ENTERING_WORLD", true, false)
G.wait(5)
check(not ns.welcome.frame:IsShown(), "… once only")

-- ── the book and the commands ────────────────────────────────────────────────
G.slash("")
local book = ns.window()
check(book:IsShown(), "/wind opens the book")
check(book.empty:GetText():find("below 15%%"), "… which says what it will hold, at this character's threshold")
G.slash("")
check(not book:IsShown(), "/wind again closes it")
G.slash("settings")
check(G.panel.opened == 42, "/wind settings opens the Options page")
G.slash("minimap")
check(ns.option("minimapHidden"), "/wind minimap hides the button")
table.insert(ns.record().debriefs, { at = 1 })
G.slash("reset")
check(#ns.record().debriefs == 1 and said("reset yes"), "/wind reset asks first")
G.slash("reset yes")
check(#ns.record().debriefs == 0, "/wind reset yes forgets the debriefs")
G.slash("import SW1:p10")
check(ns.option("threshold") == 10 and said("settings imported"), "/wind import CODE")
G.slash("what")
check(said("/wind settings"), "an unknown word: the commands")

-- ── the recorder ─────────────────────────────────────────────────────────────
-- A fresh life (full health, alive), its own record, the default threshold.
local lives = 0
local function life()
  lives = lives + 1
  G.state.guid = ("Player-6113-1%07X"):format(lives)
  G.state.health, G.state.dead, G.state.instance = G.state.maxHealth, false, nil
  G.reload()
  ns.setOption("threshold", 15)
  ns.setOption("chat", true)
  return ns.record().debriefs
end
local function only(list, kind) return #list == 1 and list[1].kind == kind and list[1] end

local debriefs = life()
local readyTools = ns.readyTools
ns.readyTools = function() return { "ready" } end
G.sight("Rockjaw Trogg", { level = 9, type = "Humanoid" })
G.pull()
G.wait(1)
G.hit({ from = "Ragged Young Wolf", amount = 50 })
G.wait(2)
G.hit({ from = "Rockjaw Trogg", amount = 60, spell = { 9053, "Fireball", 4 }, crit = true })
G.wait(1)
G.miss({ from = "Ragged Young Wolf", what = "DODGE" })
G.debuff({ from = "Rockjaw Trogg", spell = { 6136, "Chilled" } })
G.hit({ from = "Ragged Young Wolf", amount = 50 })
G.cast({ 20230, "Retaliation" })
G.heal({ from = "Brother Paxton", amount = 60, spell = { 2061, "Flash Heal" } })
G.wait(2)
G.leave()
ns.readyTools = readyTools
if G.FOREVER then
  check(#debriefs == 0, "Forever: no close call while the game keeps my health secret in a fight")
else
  local d = only(debriefs, "close")
  check(d and d.lowPct == 11 and d.startPct == 100, "a fight survived at 11%: a close call, from full health")
  check(
    d.zone == "Dun Morogh" and d.sub == "Coldridge Valley" and d.level == 8 and d.length == 6,
    "… where, my level, how long"
  )
  local wolf, trogg = d.foes[1], d.foes[2]
  check(
    wolf.name == "Ragged Young Wolf" and wolf.first == 1 and trogg.first == 3,
    "… the foes in the order they came, and when"
  )
  check(
    wolf.hits == 2 and wolf.misses == 1 and wolf.damage == 100 and wolf.npc,
    "… what each did: hits, misses, damage"
  )
  check(
    trogg.level == 9 and trogg.type == "Humanoid" and not wolf.level,
    "… a foe's level and kind when the game could tell"
  )
  check(d.heals[1].name == "Brother Paxton" and d.heals[1].amount == 60, "… the heals, by whom")
  check(d.casts[1].name == "Retaliation" and d.casts[1].t == 4, "… my casts")
  check(d.ready and d.ready[1] == "ready" and d.readyT == 3, "… what was ready when my health first fell below half")
  local crit
  for _, r in ipairs(d.events) do
    if r.spell == "Fireball" then crit = r end
  end
  check(
    crit and crit.crit and crit.amount == 60 and crit.school == 4,
    "… the log's run-up to the low point: a critical Fireball"
  )
  local kinds = {}
  for _, r in ipairs(d.events) do
    kinds[r.k] = true
  end
  check(
    kinds.miss and kinds.debuff and not kinds.heal,
    "… with the miss and the debuff, not the heal after the low point"
  )
  check(d.samples[1].pct == 100 and d.samples[#d.samples].pct >= 11, "… my health over the fight")
  check(
    said("Close call, 11%% in Coldridge Valley, Dun Morogh %(Ragged Young Wolf, Rockjaw Trogg%)"),
    "… and a line in chat"
  )
end

debriefs = life()
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 100 })
G.leave()
check(#debriefs == 0, "a fight survived at 44%: no debrief")

debriefs = life()
ns.setOption("threshold", 20)
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 147 })
G.leave()
check(G.FOREVER and #debriefs == 0 or only(debriefs, "close"), "at 18%, with a threshold of 20%: a close call")

if not G.FOREVER then
  debriefs = life()
  G.pull()
  G.hit({ from = "Frostmane Seer", amount = 160, spell = { 20793, "Fireball", 4 } })
  for _ = 1, 25 do
    G.wait(1)
    G.heal({ amount = 4, spell = { 2050, "Lesser Heal" } })
    G.hit({ from = "Frostmane Seer", amount = 4 })
  end
  G.leave()
  local d = only(debriefs, "close")
  check(
    d and d.events[1].spell == "Fireball" and d.lowT == 0,
    "a low point early in a long fight: its run-up kept, not the end's"
  )

  debriefs = life()
  G.env("Falling", 165)
  G.wait(1)
  check(#debriefs == 0, "a fall: nothing written while it might go on")
  G.wait(3)
  d = only(debriefs, "close")
  check(d and d.env == "Falling" and d.lowPct == 8 and #d.foes == 0, "… then a close call: a fall, to 8%")
end

debriefs = life()
G.duel()
G.pull()
G.hit({ from = "Kyle", player = true, amount = 170 })
G.leave()
G.duelOver()
check(#debriefs == 0, "a duel: never a close call")

debriefs = life()
G.state.instance = "pvp"
G.pull()
G.hit({ from = "Kyle", player = true, amount = 170 })
G.leave()
check(#debriefs == 0, "a battleground: no part of it")

debriefs = life()
G.state.hardcore = true
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 90 })
G.wait(1)
G.hit({ from = "Rockjaw Trogg", amount = 120, spell = { 9053, "Fireball", 4 } })
G.die()
local d = only(debriefs, "death")
check(
  d and d.lowPct == 0 and d.hardcore == (not G.FOREVER or nil),
  "a death: its debrief, Hardcore where the game says so"
)
check(said("Death in Coldridge Valley"), "… and a line in chat")
check(not d.recap, "… the game's recap read a moment later")
G.wait(1.5)
check(
  d.recap and d.recap[1].src == "Rockjaw Trogg" and d.recap[1].spell == nil and d.recap[1].hp == 0,
  "… the recap, the killing blow first"
)
check(d.killer and d.killer.name == "Rockjaw Trogg" and d.killer.overkill == 30, "… the killer, and by how much")
if G.FOREVER then
  check(
    #d.foes == 2 and d.foes[1].name == "Ragged Young Wolf" and d.foes[2].damage == 120,
    "Forever: the foes from the recap"
  )
else
  check(d.killer.spell == "Fireball" and #d.foes == 2, "… the foes from the log")
end

debriefs = life()
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 170 })
G.state.inCombat = false
G.offer("PLAYER_REGEN_ENABLED")
G.state.dead, G.state.health = true, 0
G.offer("PLAYER_DEAD")
G.wait(1.5)
check(#debriefs == 1 and debriefs[1].kind == "death", "the end of combat told before the death: one debrief, the death")

if not G.FOREVER then
  debriefs = life()
  G.state.health = 60
  ns.readyTools = function() return { "ready" } end
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 40 })
  G.leave()
  ns.readyTools = readyTools
  local d = only(debriefs, "close")
  check(d and d.startPct == 33 and d.readyT == 0, "a fight begun below half health: what was ready, from its start")
end

debriefs = life()
table.insert(debriefs, { kind = "death", at = 1, foes = {} })
for i = 2, 100 do
  table.insert(debriefs, { kind = "close", at = i, foes = {} })
end
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 170 })
G.leave()
if not G.FOREVER then
  check(
    #debriefs == 100 and debriefs[1].kind == "death" and debriefs[2].at == 3,
    "a hundred kept: the oldest close call goes, a death stays"
  )
end

local function lessons(d) return table.concat(ns.lessonsOf(d), " | ") end

-- ── what I had ───────────────────────────────────────────────────────────────
debriefs = life()
G.state.book = {
  ["Shield Wall"] = {},
  ["Retaliation"] = { ready = GetTime() + 600 },
  ["Intimidating Shout"] = { usable = false },
  ["Disarm"] = { ready = GetTime() + 1 },
}
G.state.bags = { [929] = { count = 2 }, [1710] = { count = 1, usable = false }, [1251] = { count = 5 } }
G.state.auras = { [11196] = true }
local function named(tools)
  local out = {}
  for _, t in ipairs(tools or {}) do
    table.insert(out, t.n)
  end
  return table.concat(out, ", ")
end
check(
  named(ns.readyTools()) == "Shield Wall, Disarm, Healing Potion",
  "what is ready: known, off cooldown (the global one aside), usable; a bandage not just after one"
)
local potion = ns.readyTools()[3]
check(
  potion.item == 929 and potion.spell == 441 and potion.count == 2 and potion.k == "heal",
  "… a potion by its item, the spell it casts, how many"
)
if not G.FOREVER then
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 100 })
  G.use(929, 441, "Healing Potion")
  G.hit({ from = "Ragged Young Wolf", amount = 70 })
  G.leave()
  local d = only(debriefs, "close")
  check(d and named(d.ready) == "Shield Wall, Disarm, Healing Potion", "a close call: what was ready below half health")
  check(named(d.unused) == "Shield Wall, Disarm", "… and what went unused: the potion was drunk")
  check(lessons(d) == "Shield Wall was ready and went unused. | Disarm was ready too.", "… its lessons")
end
G.state.book, G.state.bags, G.state.auras = {}, {}, {}

-- ── facts and lessons ────────────────────────────────────────────────────────
local base =
  { kind = "close", lowPct = 11, level = 8, maxHealth = 180, foes = { { name = "Ragged Young Wolf", first = 0 } } }
local function with(t)
  local d = {}
  for k, v in pairs(base) do
    d[k] = v
  end
  for k, v in pairs(t) do
    d[k] = v
  end
  return d
end
check(lessons(with({})) == "", "a plain close call: no lesson to force")
check(
  lessons(
    with({ startPct = 48, unused = { { n = "Healing Potion", k = "heal" }, { n = "Shield Wall", k = "guard" } } })
  ) == "You went in at 48% health. | A Healing Potion was in your bags, ready.",
  "the two weightiest: went in hurt, a potion ready"
)
check(
  lessons(with({
    unused = { { n = "Shield Wall", k = "guard" }, { n = "Last Stand", k = "guard" }, { n = "Disarm", k = "stop" } },
  })) == "Shield Wall and Last Stand were ready and went unused. | Disarm was ready too.",
  "guards ready and unused, then what holds a foe"
)
check(lessons(with({
  foes = {
    { name = "Defias Thug", first = 0 },
    { name = "Defias Thug", first = 0 },
    { name = "Defias Bandit", first = 6 },
  },
})) == "Three foes at once. | Defias Bandit joined six seconds in.", "three at once, one late")
check(
  lessons(with({
    events = { { k = "hit", t = 2, src = "Rockjaw Trogg", spell = "Fireball", amount = 70, crit = true, school = 4 } },
  })) == "A critical Fireball took a third of your health at once. | Most of the harm was magic (Fireball).",
  "a critical that took a third, the harm mostly magic"
)
check(
  lessons(with({ foes = {}, env = "Falling", startPct = 100, lowPct = 8 })) == "A fall took 92% of your health.",
  "a fall: its own lesson"
)
check(lessons(with({
  foes = { { name = "Gibblewilt", rank = "elite", first = 0 }, { name = "Kobold Miner", level = 10, first = 0 } },
})) == "Gibblewilt was an elite.", "an elite before a foe above my level")
check(
  lessons(with({ foes = { { name = "Kobold Miner", level = 10, first = 0 } } }))
    == "Kobold Miner was two levels above you.",
  "… a foe two levels above"
)
check(
  lessons(with({ lowT = 5, samples = { { t = 0, pct = 100 }, { t = 4, pct = 60 }, { t = 5, pct = 11 } } }))
    == "From half your health to 11% in a second.",
  "from half health to the low point, fast"
)
local f = ns.factsOf(with({
  events = {
    { k = "hit", t = 1, src = "Ragged Young Wolf", amount = 20 },
    { k = "hit", t = 2, src = "Rockjaw Trogg", spell = "Fireball", amount = 70, crit = true },
    { k = "heal", t = 3, src = "you", amount = 30 },
    { k = "hit", t = 4, src = "Ragged Young Wolf", amount = 40 },
    { k = "hit", t = 5, src = "Ragged Young Wolf", amount = 10 },
    { k = "hit", t = 6, src = "Ragged Young Wolf", amount = 5 },
  },
  lowT = 6,
  ready = { { n = "Shield Wall", k = "guard" }, { n = "Healing Potion", k = "heal" } },
  unused = { { n = "Shield Wall", k = "guard" } },
}))
check(
  f.title == "Close call: 11% health" and #f.hits == 3 and f.hits[1].amount == 70 and f.hits[1].before == 4,
  "the facts: the three largest hits, how long before the low point"
)
check(
  #f.used == 1 and f.used[1].n == "Healing Potion" and f.unused[1].n == "Shield Wall",
  "… what was used and what wasn't"
)

-- ── the card ─────────────────────────────────────────────────────────────────
local function headings(c)
  local out = {}
  for _, sec in ipairs(c.sections) do
    table.insert(out, sec.heading)
  end
  return table.concat(out, ", ")
end
local function lastLink()
  for i = #G.printed, 1, -1 do
    local l = G.printed[i]:match("(|Hsecondwind:[^|]+|h%[[^]]+%]|h)")
    if l then return l end
  end
end
local book = ns.window()
book:Hide()
if not G.FOREVER then
  debriefs = life()
  G.state.book = { ["Shield Wall"] = {} }
  G.sight("Rockjaw Trogg", { level = 9, type = "Humanoid" })
  G.pull()
  G.wait(1)
  G.hit({ from = "Ragged Young Wolf", amount = 50 })
  G.wait(2)
  G.hit({ from = "Rockjaw Trogg", amount = 60, spell = { 9053, "Fireball", 4 }, crit = true })
  G.hit({ from = "Ragged Young Wolf", amount = 50 })
  G.heal({ from = "Brother Paxton", amount = 60, spell = { 2061, "Flash Heal" } })
  G.leave()
  G.state.book = {}
  local d = only(debriefs, "close")
  local c = ns.cardOf(d)
  check(
    c.title == "Close call: 11% health" and c.sub:find("^Coldridge Valley, Dun Morogh · level 8 · 3 seconds · "),
    "the card: its title and the line under it"
  )
  check(headings(c) == "Foes, The hits that mattered, Heals, What you had", "… its sections")
  check(
    c.sections[1].lines[2] == "Rockjaw Trogg (level 9, humanoid): 3 seconds in, 1 hit for 60",
    "… a foe: what the game told of it, when it came, what it did"
  )
  check(
    c.sections[2].lines[1] == "60: Fireball, critical, from Rockjaw Trogg, at the low point",
    "… the hits that mattered"
  )
  check(
    c.sections[4].lines[1] == "Ready, unused: Shield Wall" and c.lessons[1] == "Shield Wall was ready and went unused.",
    "… what you had, and the lesson"
  )
  local link = lastLink()
  check(link and link:find("|Hsecondwind:debrief:" .. d.at .. "|h%[Debrief%]"), "the chat line links to the debrief")
  check(not book:IsShown(), "a close call: the book stays closed")
  G.click(link)
  check(
    book:IsShown() and book.open == d.at and book.cardShown.title == "Close call: 11% health",
    "… the link opens it at the card"
  )
  local t = G.toasted[#G.toasted]
  check(
    t and t.Title:GetText() == "Close call: 11%" and t.Name:GetText() == "Coldridge Valley",
    "the game's alert: the close call and where"
  )
  book:Hide()
  t.scripts.OnClick(t, "LeftButton")
  check(book:IsShown() and book.open == d.at, "… a click on it opens the card")
  book:Hide()
end

debriefs = life()
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 60 })
G.wait(1)
G.hit({ from = "Rockjaw Trogg", amount = 150, spell = { 9053, "Fireball", 4 } })
G.die()
G.wait(1.5)
local death = only(debriefs, "death")
check(book:IsShown() and book.open == death.at, "a death: the book opens at its debrief on its own")
check(
  book.cardShown.title == "Death" and book.cardShown.sections[1].heading == "The killing blow",
  "… the card: the killing blow first"
)
check(
  book.cardShown.sections[1].lines[1]
    == "Rockjaw Trogg" .. (G.FOREVER and "" or "'s Fireball") .. ", 150 (30 more than you had)",
  "… by whom, with what, by how much"
)
book:Hide()
ns.setOption("openAfterDeath", false)
G.state.dead, G.state.health = false, G.state.maxHealth
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 200 })
G.die()
check(not book:IsShown(), "… not with the setting off")
ns.setOption("openAfterDeath", true)
ns.openDebrief(death.at)
check(book.rows[1]:IsShown() and book.rows[2]:IsShown() and book.rows[1].at ~= death.at, "the list: the newest first")
book.rows[2].scripts.OnClick(book.rows[2])
check(book.open == death.at and book.cardShown.title == "Death", "… a row clicked: its card")
book:Hide()

-- ── the fake game itself: fights as the game sends them ──────────────────────
life()
local seen = {}
local listener = CreateFrame("Frame")
local logged = pcall(listener.RegisterEvent, listener, "COMBAT_LOG_EVENT_UNFILTERED")
listener:RegisterUnitEvent("UNIT_HEALTH", "player")
listener:SetScript("OnEvent", function(_, e)
  if e == "COMBAT_LOG_EVENT_UNFILTERED" then table.insert(seen, (select(2, CombatLogGetCurrentEventInfo()))) end
end)
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 40 })
G.hit({ from = "Rockjaw Trogg", amount = 60, spell = { 11, "Frostbolt", 16 }, crit = true })
G.heal({ amount = 30, spell = { 2050, "Lesser Heal" } })
if G.FOREVER then
  check(not logged and #seen == 0, "Forever: no combat log for addons")
  check(G.secret(UnitHealth("player")), "Forever: the player's health a secret in a fight")
else
  check(
    logged and table.concat(seen, ",") == "SWING_DAMAGE,SPELL_DAMAGE,SPELL_HEAL",
    "a fight replayed as the combat log"
  )
  check(UnitHealth("player") == 110, "… the health with it")
end
G.hit({ from = "Ragged Young Wolf", amount = 200 })
G.die()
local events = C_DeathRecap.GetRecapEvents()
check(
  #events == 3 and events[1].sourceName == "Ragged Young Wolf" and events[1].overkill == 90,
  "a death: the game's recap, the killing blow first"
)
check(UnitHealth("player") == 0 and not InCombatLockdown(), "… out of the fight, dead")

io.stdout:write(("all good%s: %d checks\n"):format(G.FOREVER and " (Forever)" or "", passed))
