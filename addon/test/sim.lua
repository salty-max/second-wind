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
end
G.state.book, G.state.bags, G.state.auras = {}, {}, {}

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
