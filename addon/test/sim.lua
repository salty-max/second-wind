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
check(ns.option("threshold") == 15 and ns.option("toast"), "the defaults: below 15%, the alert")
check(
  ns.option("openAfterDeath") and not ns.option("minimapHidden"),
  "the defaults: a death's debrief opens, the button shows"
)
check(ns.option("prepull"), "the defaults: a word before a pull")
check(ns.profiles:export() == "SW1:p15:t1:d1:w1:h0:a250", "the settings as a code")
check(ns.profiles:import("SW1:p20:c0:t0"), "a code taken")
check(
  ns.option("threshold") == 20 and not ns.option("toast") and ns.option("prepull"),
  "… its choices this character's (an older code, without the word before a pull, leaves it; its c, the chat line, left out)"
)
ns.setOption("toast", true)
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
local unseen = false
for _, text in ipairs(G.shown) do
  if text:find("rebuilds it from each blow and heal the game tells") then unseen = true end
end
check(unseen == G.FOREVER, "… on Forever, saying what the game keeps from addons, and what stands for it")
ns.welcome.frame:Hide()
G.reload()
G.offer("PLAYER_ENTERING_WORLD", true, false)
G.wait(5)
check(not ns.welcome.frame:IsShown(), "… once only")
-- Its last choice: sharing what the game tells of the world (the kit's
-- collector), off until the player says yes, account-wide in SecondWindCollect.
local share = ns.welcome.rows[#ns.welcome.rows]
check(
  share and not ns.collect:on() and SaltyMaxCollector == nil,
  "… the last choice, sharing what you see, off: nothing kept"
)
ns.collect:set(true)
check(
  ns.collect:on() and SecondWindCollect.share == true and SaltyMaxCollector ~= nil,
  "… on: account-wide, this addon collects"
)
ns.collect:set(false)
check(
  not ns.collect:on() and SecondWindCollect.facts ~= nil and SaltyMaxCollector == nil,
  "… off: nothing more kept, the claim given up (what was kept stays here, never sent while off)"
)
SaltyMaxCollector = nil

-- ── one listener's error ─────────────────────────────────────────────────────
G.state.errors = {}
local heard = false
ns.on("SW_TEST_EVENT", function() error("a listener's fault") end)
ns.on("SW_TEST_EVENT", function() heard = true end)
G.offer("SW_TEST_EVENT")
check(
  heard and G.state.errors[1] and G.state.errors[1]:find("a listener's fault"),
  "a listener's error is reported, the next still runs"
)
G.state.errors = nil

-- ── the book and the commands ────────────────────────────────────────────────
G.slash("")
local book = ns.window()
check(book:IsShown(), "/wind opens the book")
check(
  book.patterns:IsShown()
    and book.patterns.shown.title == "Debriefs"
    and book.patterns.shown.sections[1].lines[1]:find("below 15%%"),
  "… a page, which says what it will hold, at this character's threshold"
)
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
check(ns.option("threshold") == 10 and said("Settings imported"), "/wind import CODE")
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
  local d = only(debriefs, "close")
  check(
    d and d.rebuilt == "warning" and d.lowPct == 11 and d.lowRange[1] == 7 and d.lowRange[2] == 11 and d.warned == 4,
    "Forever: my health secret, rebuilt from each blow and heal the game told, counted from its low-health warning"
  )
  check(said("Close call, about 11%% in Coldridge Valley"), "… and a line in chat")
  check(
    ns.cardOf(d).title == "Close call: about 11% health" and #d.samples == 5,
    "… its card, my health over the fight"
  )
  local hid = false
  for _, sec in ipairs(ns.cardOf(d).sections) do
    if sec.heading == "What the game hid" then hid = true end
  end
  check(not hid, '… the game\'s secrets kept off the card (its lowest point says "about")')
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
    trogg.level == 9 and trogg.typeId == 7 and trogg.type == "Humanoid" and not wolf.level,
    "… a foe's level and kind (by its id) when the game could tell"
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
local d18 = only(debriefs, "close")
check(d18 and d18.lowPct == 18, "at 18%, with a threshold of 20%: a close call")
if G.FOREVER then check(d18.rebuilt == "warning", "Forever: rebuilt, the threshold applying again") end

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
  d.recap and d.recap[1].src == "Rockjaw Trogg" and d.recap[1].spell == "Fireball" and d.recap[1].hp == 0,
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

if G.FOREVER then
  -- (Forever's recap names each unit with a word after its creature's name,
  -- "Snow Leopard Nub", seen on 15 October 2026; the meter names it plainly)
  debriefs = life()
  G.pull()
  G.hit({ from = "Snow Leopard", recapAs = "Snow Leopard Nub", amount = 50 })
  G.wait(1)
  G.hit({ from = "Snow Leopard", recapAs = "Snow Leopard Shimsham", amount = 60 })
  G.hit({ from = "Crag Boar", recapAs = "Crag Boar Mcnugg", amount = 70 })
  G.die()
  G.wait(1.5)
  local d = only(debriefs, "death")
  local function foeNamed(name)
    for _, f in ipairs(d and d.foes or {}) do
      if f.name == name then return f end
    end
  end
  local leopard, boar = foeNamed("Snow Leopard"), foeNamed("Crag Boar")
  check(
    d
      and #d.foes == 2
      and leopard
      and leopard.hits == 2
      and leopard.damage == 110
      and boar
      and d.killer.name == "Crag Boar"
      and d.recap[1].src == "Crag Boar",
    "Forever: the recap's word after a creature's name left out, its units one foe, as the meter names them"
  )
  -- (one saved before, mended at the login; a creature named so stays itself)
  table.insert(debriefs, {
    kind = "death",
    at = 5,
    recap = { { src = "Snow Leopard Nub", amount = 4 } },
    spells = { { src = "Snow Leopard", amount = 9 } },
    killer = { name = "Snow Leopard Nub" },
    foes = {
      { name = "Snow Leopard Nub", hits = 1, damage = 4 },
      { name = "Snow Leopard Altarboy", hits = 2, damage = 5 },
      { name = "Snow Leopard Prowler", hits = 1, damage = 3 },
    },
  })
  G.reload()
  local old = debriefs[#debriefs]
  check(
    #old.foes == 2
      and old.foes[1].name == "Snow Leopard"
      and old.foes[1].hits == 3
      and old.foes[2].name == "Snow Leopard Prowler"
      and old.killer.name == "Snow Leopard",
    "… and a debrief saved before, mended at the login, a real name kept"
  )
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

-- ── what I had: the bag's and the body's ─────────────────────────────────────
debriefs = life()
G.state.bags = {
  [15993] = { count = 5 }, -- Thorium Grenade
  [4397] = { count = 1 }, -- Gnomish Cloaking Device, carried, not worn
  [6452] = { count = 2 }, -- Anti-Venom
  [13457] = { count = 1 }, -- Greater Fire Protection Potion
  [8529] = { count = 1 }, -- Noggenfogger Elixir
}
G.state.equipped = { [13] = { id = 2820 }, [8] = { id = 7189, ready = GetTime() + 600 } }
local now = named(ns.readyTools())
check(
  now:find("Thorium Grenade") and now:find("Nifty Stopwatch"),
  "the bag's and the body's: a grenade, a trinket worn"
)
check(
  not now:find("Gnomish Cloaking Device") and not now:find("Goblin Rocket Boots"),
  "… not a trinket carried, nor boots on cooldown"
)
check(not now:find("Anti%-Venom"), "… a cure only with what it cures on me")
-- (a debuff no cure removes, a Charge's daze or a zone's, has no kind: the
-- 0.4.0 bug, "table index is nil" at the fight's start)
G.state.debuffs = { { name = "Dazed" } }
check(pcall(ns.readyTools), "… a debuff without a kind on me: no error")
G.state.debuffs = { { name = "Dazed" }, { name = "Poison", type = "Poison" } }
local antivenom
for _, t in ipairs(ns.readyTools()) do
  if t.n == "Anti-Venom" then antivenom = t end
end
check(antivenom and antivenom.against == "Poison" and antivenom.count == 2, "… with poison on me, the anti-venom")
if not G.FOREVER then
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 100 })
  G.hit({ from = "Ragged Young Wolf", amount = 70 })
  G.leave()
  local d = only(debriefs, "close")
  check(
    d and not named(d.ready):find("Fire Protection") and not named(d.ready):find("Noggenfogger"),
    "a fight of claws: no fire protection counted, nor what helps in a fall"
  )
  check(
    lessons(d):find("Anti%-Venom was ready, with poison on you%."),
    "… the anti-venom, with the poison on me: a lesson"
  )
  debriefs = life()
  G.pull()
  G.hit({ from = "Frostmane Seer", amount = 170, spell = { 20793, "Fireball", 4 } })
  G.leave()
  d = only(debriefs, "close")
  check(d and named(d.unused):find("Greater Fire Protection Potion"), "a Fireball: the fire protection counts")
  debriefs = life()
  G.env("Falling", 165)
  G.wait(4)
  d = only(debriefs, "close")
  check(d and named(d.ready):find("Noggenfogger Elixir"), "a fall: what slows a fall counts")
end
G.state.bags, G.state.equipped, G.state.debuffs = {}, {}, {}
check(
  lessons(with({
    unused = {
      { n = "Thorium Grenade", k = "stop" },
      { n = "Masterwork Target Dummy", k = "stop" },
      { n = "Nifty Stopwatch", k = "away" },
      { n = "Swiftness Potion", k = "away" },
      { n = "Gnomish Net-o-Matic Projector", k = "stop" },
    },
  })) == "Thorium Grenade, Masterwork Target Dummy, Nifty Stopwatch and 2 more were ready too.",
  "a long list: three named, then how many more"
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
-- A page's block of a kind, as drawn (Page.lua's pools: the i-th shown).
local function drawn(page, kind, i)
  local pool = page.pools[kind]
  return pool and i <= pool.n and pool[i] or nil
end
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
  -- (the card drawn: the foe that did the most harm at its head, each foe in
  -- its row, each blow with its amount and spell, the tools' icons)
  check(
    c.face and c.face.foe and c.face.foe.name == "Ragged Young Wolf",
    "… its face: the foe that did the most harm"
  )
  local foe1, foe2 = drawn(book.card, "foe", 1), drawn(book.card, "foe", 2)
  check(
    foe1 and foe1.name.text == "Ragged Young Wolf" and foe2 and foe2.name.text == "Rockjaw Trogg",
    "… the foes drawn, each in its row"
  )
  check(foe2.about.text == "level 9 · humanoid" and foe2.did.text:find("1 hit for 60"), "… what each was, and did")
  local blow = drawn(book.card, "blow", 1)
  check(
    blow
      and blow.amount.text == "60"
      and blow.title.text == "Fireball, critical"
      and blow.detail.text == "from Rockjaw Trogg, at the low point",
    "… a blow: its amount, its spell, from whom and when"
  )
  local heal = drawn(book.card, "blow", 4)
  check(heal and heal.amount.text == "60" and heal.title.text == "Brother Paxton", "… a heal, as a blow is")
  local tools = drawn(book.card, "tools", 1)
  local icons = 0
  for _, icon in ipairs(tools and tools.icons or {}) do
    if icon:IsShown() then icons = icons + 1 end
  end
  check(tools and tools.label.text == "Ready, unused" and icons == 1, "… what you had: the tools, an icon each")
  check(
    drawn(book.card, "lesson", 1).text.text == "Shield Wall was ready and went unused.",
    "… the lesson, set apart"
  )
  local last = G.toasted[#G.toasted]
  check(not (last and last.kicker:find("^Close call")), "a close call: no banner, its line in chat enough")
  check(
    said("Close call, 11%% in Coldridge Valley, Dun Morogh %(.-%): Shield Wall was ready and went unused%. |c"),
    "… the line carries its main lesson"
  )
  book:Hide()
end

debriefs = life()
if G.banners() then G.banners():clear() end
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
  book.cardShown.sections[1].lines[1] == "Rockjaw Trogg's Fireball, 150 (30 more than you had)",
  "… by whom, with what, by how much"
)
local killing = drawn(book.card, "blow", 1)
check(
  killing
    and killing.amount.text == "150"
    and killing.title.text == "Rockjaw Trogg's Fireball"
    and killing.detail.text == "30 more than you had",
  "… drawn: the blow's amount, by whom, the overkill"
)
local t = G.toasted[#G.toasted]
local card = SecondWindBanner1
check(
  t
    and t.kicker == "Death"
    and t.title == "Coldridge Valley"
    and card:IsShown()
    and card.joined
    and card.title:GetText() == "Coldridge Valley",
  "a death: a banner among the game's alerts, and where"
)
book:Hide()
card.scripts.OnClick(card, "LeftButton")
check(book:IsShown() and book.open == death.at and not card:IsShown(), "… a click on it opens the card")
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

-- ── patterns ─────────────────────────────────────────────────────────────────
local function foes(...)
  local out = {}
  for i, name in ipairs({ ... }) do
    table.insert(out, { name = name, first = i == 3 and 6 or 0 })
  end
  return out
end
local five = {
  {
    kind = "close",
    at = 1000,
    startPct = 40,
    sub = "Coldridge Valley",
    zone = "Dun Morogh",
    foes = foes("Rockjaw Trogg", "Burly Rockjaw Trogg", "Rockjaw Skullthumper"),
    unused = { { n = "Healing Potion", k = "heal" } },
  },
  {
    kind = "close",
    at = 2000,
    startPct = 50,
    sub = "Coldridge Valley",
    zone = "Dun Morogh",
    foes = foes("Rockjaw Trogg", "Frostmane Troll Whelp", "Frostmane Novice"),
    unused = { { n = "Healing Potion", k = "heal" }, { n = "Shield Wall", k = "guard" } },
  },
  { kind = "close", at = 3000, startPct = 90, sub = "Anvilmar", zone = "Dun Morogh", foes = foes("Rockjaw Trogg") },
  {
    kind = "death",
    at = 4000,
    startPct = 30,
    sub = "Shimmer Ridge",
    zone = "Dun Morogh",
    foes = foes("Frostmane Seer", "Frostmane Shadowcaster", "Frostmane Snowstrider"),
  },
  { kind = "close", at = 5000, startPct = 100, lowPct = 8, env = "Falling", zone = "Dun Morogh", foes = {} },
}
check(not ns.patternsOf({ five[1], five[2] }).enough, "patterns: nothing said before three debriefs")
local pat = ns.patternsOf(five)
check(
  pat.enough
    and pat.sub
      == "From 5 debriefs: 4 close calls and a death, since " .. ("%d %s"):format(
        date("*t", 1000).day,
        date("%b", 1000)
      ),
  "… then what they are drawn from"
)
check(
  pat.lessons[1] == "In 3 of your 5 close calls and deaths, you went in below 60% health.",
  "… the commonest trait, said above (the deaths among them named)"
)
check(
  (ns.patternsOf({ five[1], five[2], five[3], five[5] }).lessons[1] or ""):find("^In %d of your 4 close calls, "),
  "… close calls alone, said so"
)
local function section(page, heading)
  for _, sec in ipairs(page.sections) do
    if sec.heading == heading then return table.concat(sec.lines, " | ") end
  end
end
check(
  section(pat, "Most often")
    == "3 of 5: you went in below 60% health | 3 of 5: three foes or more at once | 3 of 5: a foe joined after the start | 2 of 5: a healing potion or healthstone went unused",
  "… the traits that come back, a third of the time or more"
)
check(section(pat, "Where") == "Coldridge Valley, Dun Morogh: 2", "… where, twice or more")
check(section(pat, "Foes met more than once") == "Rockjaw Trogg: in 3", "… the foes met more than once")
check(section(pat, "Left unused most often") == "Healing Potion: 2 times", "… the tools left unused most often")
debriefs = life()
book:Show()
ns.showTab(ns.TAB.patterns)
check(
  book.patterns:IsShown()
    and book.patterns.shown.title == "Patterns"
    and book.patterns.shown.sections[1].lines[1]:find("%(none so far%)"),
  "the Patterns tab: a page, what it will hold, none so far"
)
for _, d in ipairs(five) do
  table.insert(debriefs, d)
end
ns.refresh()
check(
  book.patterns.shown.title == "What your close calls share"
    and book.patterns.strip:IsShown()
    and book.patterns.strip.tiles[1].value:GetText() == tostring(#debriefs),
  "… then the patterns, their figures on top"
)
local share = drawn(book.patterns, "share", 1)
check(share and share.value.text:find("^%d+ of your %d+$"), "… a trait drawn: its bar, how many of the close calls")
check(not book.card:IsShown() and not book.left:IsShown(), "… over the whole page, the list put away")
ns.showTab(ns.TAB.debriefs)
check(book.card:IsShown() and not book.patterns:IsShown(), "back to the debriefs: the card again")
book:Hide()

-- ── control lost, and time for a bandage ─────────────────────────────────────
local function sectionOf(c, heading)
  for _, sec in ipairs(c.sections) do
    if sec.heading == heading then return table.concat(sec.lines, " | ") end
  end
end
if not G.FOREVER then
  debriefs = life()
  G.state.bags = { [929] = { count = 2 } }
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 95 })
  G.stun({ seconds = 3, spell = { 1833, "Cheap Shot" } })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 30 })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 35 })
  G.wait(1.5)
  G.leave()
  local d = only(debriefs, "close")
  check(
    d and #d.held == 1 and d.held[1].what == "Stunned" and d.held[1].spell == "Cheap Shot" and d.held[1].to == 3,
    "control lost: the game's account of it, kept (what, by which spell, until when)"
  )
  check(
    lessons(d):find("^Stunned the whole way down to 11%% %(Cheap Shot%)%.") and not lessons(d):find("Healing Potion"),
    "… held the whole way down: told, and the potion not called a lesson"
  )
  local c = ns.cardOf(d)
  check(
    sectionOf(c, "Out of your control") == "Stunned (Cheap Shot): 3.0 s, from the start"
      and sectionOf(c, "What you had") == "Ready, but you were stunned: Healing Potion (2)",
    "… the card: the stretch held, and what was ready but out of reach"
  )
  check(ns.traitsOf(d).held and ns.helpless(d), "… a trait for the patterns, nothing called left unused")

  debriefs = life()
  G.state.bags = { [929] = { count = 2 } }
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 95 })
  G.wait(2)
  G.hit({ from = "Defias Footpad", amount = 20 })
  G.stun({ seconds = 2, untold = true })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 20 })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 25 })
  G.leave()
  d = only(debriefs, "close")
  check(
    lessons(d)
      == "Out of your control for two seconds on the way down to 11%. | A Healing Potion was in your bags, ready.",
    "control lost for part of the way, the game saying only that: told, and the potion still a lesson"
  )

  debriefs = life()
  G.state.bags = { [1251] = { count = 5 } }
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 95 })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 30 })
  G.wait(1)
  G.hit({ from = "Defias Footpad", amount = 35 })
  G.leave()
  d = only(debriefs, "close")
  check(d and #d.ready == 0, "a bandage under blow after blow: no time to use it, not counted")
  debriefs = life()
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 95 })
  G.wait(4)
  G.hit({ from = "Defias Footpad", amount = 65 })
  G.leave()
  d = only(debriefs, "close")
  check(d and named(d.ready) == "Linen Bandage", "… with four seconds without harm, counted")
  G.state.bags = {}
else
  debriefs = life()
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 60 })
  G.stun({ seconds = 3, spell = { 1833, "Cheap Shot" } })
  G.wait(3.5)
  G.hit({ from = "Defias Footpad", amount = 100 })
  G.leave()
  local d = only(debriefs, "close")
  check(
    d and #d.held == 1 and d.held[1].what == "Stunned" and d.held[1].spell == "Cheap Shot" and d.held[1].to == 3,
    "Forever: a stun, the game's account of it (the player's own: never secret)"
  )
  check(
    lessons(d):find("^Stunned for three seconds of the fight %(Cheap Shot%)%."),
    "… told by the fight, my health hidden"
  )
end

-- ── Forever: what the game hides, and its damage meter ───────────────────────
if G.FOREVER then
  debriefs = life()
  G.state.book = { ["Shield Wall"] = { id = 871, cd = 1800 } }
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 50 })
  G.hit({ from = "Rockjaw Trogg", amount = 60, spell = { 9053, "Fireball", 4 } })
  G.hit({ from = "Ragged Young Wolf", amount = 50 })
  G.leave()
  local d = only(debriefs, "close")
  check(d and d.rebuilt == "warning" and d.lowPct == 11, "Forever: a close call rebuilt from the blows the game told")
  check(
    #d.foes == 2 and d.foes[1].name == "Ragged Young Wolf" and d.foes[1].damage == 100,
    "… the foes from the game's damage meter"
  )
  local foesSection
  for _, sec in ipairs(ns.cardOf(d).sections) do
    if sec.heading == "Foes" then foesSection = table.concat(sec.lines, " | ") end
  end
  check(
    foesSection == "Ragged Young Wolf: 100 in all | Rockjaw Trogg: 60 in all",
    "… on the card: the harm each did in all (the meter has no blows)"
  )
  check(
    d.spells[1].amount == 100 and d.spells[1].spell == "Attack" and d.spells[2].spell == "Fireball",
    "… the harm by spell"
  )
  check(
    d.readyFrom == "start" and d.traced and named(d.unused) == "Shield Wall",
    "… what was ready at its start, and went unused: no cooldown begun"
  )
  local c = ns.cardOf(d)
  local harm
  for _, sec in ipairs(c.sections) do
    if sec.heading == "The harm, by spell" then harm = sec.lines[1] end
  end
  check(harm == "100 in all: Attack from Ragged Young Wolf", "… and shows the harm by spell")

  debriefs = life()
  G.state.castsSecret = true
  G.state.book = { ["Shield Wall"] = { id = 871, cd = 1800 }, ["Polymorph"] = { id = 118 } }
  G.state.bags = { [929] = { count = 2 }, [1710] = { count = 1 } }
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 100 })
  G.wait(2)
  G.cast({ 871, "Shield Wall" })
  G.wait(1)
  G.use(929, 441, "Healing Potion")
  G.hit({ from = "Ragged Young Wolf", amount = 70 })
  G.leave()
  G.state.castsSecret, G.state.book, G.state.bags = false, {}, {}
  d = only(debriefs, "close")
  check(
    d and d.castsHidden and d.traced and named(d.unused) == "Greater Healing Potion",
    "Forever: my casts hidden, what went unused told by what a use leaves (a cooldown begun, one fewer)"
  )
  local cast = {}
  for _, c in ipairs(d.casts) do
    cast[c.id] = c.t
  end
  check(cast[871] == 2 and cast[441] == 3, "… and when: each cooldown's start, by its spell's id")
  check(d.untold and d.untold[1] == "s118", "… a spell without a cooldown: no trace either way (by its key)")
  local had = sectionOf(ns.cardOf(d), "What you had")
  check(
    had
      == "Ready, unused: Greater Healing Potion | Used: Shield Wall, Healing Potion (2) | Ready, no trace either way: Polymorph",
    "… the card: unused, used, untold"
  )
  check(lessons(d):find("A Greater Healing Potion was in your bags, ready%."), "… a lesson again")

  -- (should a build let my health read out of a fight)
  debriefs = life()
  G.state.healthReadable = true
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 130 })
  G.heal({ from = "Brother Paxton", amount = 60, spell = { 2061, "Flash Heal" } })
  G.leave()
  check(
    #debriefs == 0,
    "Forever, my health readable out of a fight: rebuilt exactly from its end, its lowest 28%: no close call"
  )
  debriefs = life()
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 160 })
  G.leave()
  G.state.healthReadable = nil
  d = only(debriefs, "close")
  check(
    d and d.lowPct == 11 and d.rebuilt == "end" and ns.cardOf(d).title == "Close call: 11% health",
    "… ended low: rebuilt exactly, counted back from its end"
  )

  debriefs = life()
  G.state.book = { ["Shield Wall"] = { id = 871, cd = 1800 }, ["Polymorph"] = { id = 118 } }
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 100 })
  G.wait(2)
  G.cast({ 871, "Shield Wall" })
  G.hit({ from = "Ragged Young Wolf", amount = 70 })
  G.leave()
  G.state.book = {}
  d = only(debriefs, "close")
  local shields = 0
  for _, c in ipairs(d.casts) do
    if c.name == "Shield Wall" then shields = shields + 1 end
  end
  check(
    d and not d.castsHidden and not d.untold and named(d.unused) == "Polymorph" and shields == 1,
    "Forever: my own casts seen (the player's: never secret), the traces adding none twice, nothing untold"
  )

  debriefs = life()
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 60 })
  G.hit({ from = "Rockjaw Trogg", amount = 150, spell = { 9053, "Fireball", 4 } })
  G.die()
  G.wait(1.5)
  d = only(debriefs, "death")
  check(
    d and d.spells and d.spells[1].spell == "Fireball",
    "Forever: a death's harm by spell, read once out of the fight"
  )
  check(
    d.rebuilt == "death" and #d.samples == 3 and d.samples[2].pct == 67 and d.samples[3].pct == 0,
    "… its health rebuilt, counted back from the death (the killing blow's overkill taken off)"
  )

  -- A real fight, as the game told it (Forever's beta: the probe's rows of
  -- the user's paladin, level 20, against a Dark Iron Insurgent), replayed:
  -- the rebuild finds what was worked out by hand.
  local REAL = { -- (t, event, amount): the user's paladin, Forever's beta, 11 October 2026
    { 1.7, "WOUND", 17 },
    { 3.7, "WOUND", 21 },
    { 5.6, "WOUND", 19 },
    { 7.7, "WOUND", 20 },
    { 9.6, "WOUND", 19 },
    { 11.6, "WOUND", 18 },
    { 13.7, "WOUND", 20 },
    { 15.6, "MISS", 0 },
    { 17.7, "WOUND", 17 },
    { 19.7, "WOUND", 22 },
    { 21.6, "WOUND", 20 },
    { 23.7, "MISS", 0 },
    { 28.2, "WOUND", 18 },
    { 30.3, "WOUND", 18 },
    { 32.3, "WOUND", 20 },
    { 34.3, "WOUND", 21 },
    { 36.3, "WOUND", 22 },
    { 38.3, "WOUND", 22 },
    { 40.3, "WOUND", 20 },
    { 42.3, "WOUND", 23 },
    { 44.3, "WOUND", 20 },
    { 46.3, "WOUND", 21 },
    { 48.3, "WOUND", 20 },
    { 50.3, "WOUND", 22 },
    { 52.3, "WOUND", 19 },
    { 54.2, "WOUND", 21 },
    { 56.2, "WOUND", 21 },
    { 58.3, "WOUND", 21 },
    { 59.5, "WOUND", 19 },
    { 61.5, "WOUND", 19 },
    { 63.1, "HEAL", 90 },
    { 63.5, "WOUND", 19 },
    { 65.5, "WOUND", 21 },
    { 67.2, "HEAL", 167 },
    { 67.5, "WOUND", 21 },
    { 69.5, "WOUND", 20 },
    { 71.5, "WOUND", 21 },
    { 73.5, "WOUND", 18 },
    { 75.5, "WOUND", 22 },
    { 76.4, "HEAL", 168 },
    { 77.5, "WOUND", 22 },
    { 79.5, "WOUND", 22 },
  }
  local function replay(threshold)
    debriefs = life()
    ns.setOption("threshold", threshold)
    G.state.maxHealth, G.state.health = 731, 700
    G.pull()
    local now = 0
    for _, r in ipairs(REAL) do
      G.wait(r[1] - now)
      now = r[1]
      if r[2] == "WOUND" then
        G.hit({ from = "Dark Iron Insurgent", amount = r[3] })
      elseif r[2] == "HEAL" then
        G.heal({ amount = r[3], spell = { 635, "Holy Light" } })
      else
        G.miss({ from = "Dark Iron Insurgent", what = r[2] })
      end
    end
    G.leave()
    G.state.maxHealth, G.state.health = 180, 180
  end
  replay(15)
  check(#debriefs == 0, "Forever, a real fight replayed: its lowest point above 15%, no close call")
  -- (the insurgent targeted before the pull, as it's played: what it is, seen)
  G.target({ name = "Dark Iron Insurgent", level = 19, type = "Humanoid" })
  G.target(nil)
  replay(25)
  d = only(debriefs, "close")
  local foe = d and d.foes[1]
  check(
    foe
      and foe.npc
      and foe.typeId == 7
      and foe.type == "Humanoid"
      and ns.seenNamed("Dark Iron Insurgent").npc == foe.npc,
    "Forever: a foe the meter names only, made whole from what was seen of it (its portrait's id, its kind)"
  )
  local older = { name = "Dark Iron Insurgent" }
  check(ns.knownFoe(older).npc == foe.npc, "… and a foe of an older debrief, when the book shows it")
  -- (one never seen: the creatures of the original world, as the Field
  -- Journal's portraits)
  local unseen = ns.knownFoe({ name = "Rockjaw Trogg" })
  check(
    unseen.npc == 707 and ns.creatures.models[707] ~= nil and ns.knownFoe({ name = "Nobody Known" }).npc == nil,
    "… one never seen: its id and portrait from the creatures of the original world"
  )
  check(
    d
      and d.rebuilt == "warning"
      and d.lowRange[1] == 19
      and d.lowRange[2] == 21
      and d.lowPct == 20
      and d.lowT == 61.5
      and foe.name == "Dark Iron Insurgent"
      and foe.hits == 37
      and foe.misses == 2
      and d.heals[1].amount == 425,
    "Forever, a real fight replayed: its lowest point rebuilt at 19-21% (61.5 s), every blow its foe's"
  )

  debriefs = life()
  G.state.recapSecret = true
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 60 })
  G.hit({ from = "Rockjaw Trogg", amount = 150, spell = { 9053, "Fireball", 4 } })
  G.die()
  G.wait(1.5)
  G.state.recapSecret = nil
  d = only(debriefs, "death")
  check(
    d
      and d.recap
      and #d.recap == 2
      and not d.recap[1].hp
      and d.recap[1].amount == 150
      and d.recapHidden
      and table.concat(d.recapHidden, ",") == "currentHP",
    "Forever: a recap's health kept secret: left out, and named (the rest read)"
  )
end

debriefs = life()
G.slash("probe")
check(said("The probe is armed"), "/wind probe: armed for the next fight")
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 30 })
G.hit({ from = "Ragged Young Wolf", amount = 100 })
G.heal({ amount = 20, spell = { 2050, "Lesser Heal" } })
G.stun({ seconds = 1, spell = { 1833, "Cheap Shot" } })
G.wait(1)
G.cast({ 6673, "Battle Shout" })
G.leave()
G.wait(1)
check(said("The probe's report"), "… its report once the fight is over")
check(
  said(G.FOREVER and "The game: 1%.60%.1%.70338, secret values on" or "The game: 1%.15%.9%.70003, secret values off")
    and said("The hits on you %(UNIT_COMBAT%): 3 heard, 0 with a hidden amount"),
  "… the build, its secret values, and the hits the game tells unit by unit"
)
check(said("Losing control: told by the game %(Stunned, Cheap Shot%)"), "… what it could tell of a stun")
local kept = SecondWindSettings.probes and SecondWindSettings.probes[#SecondWindSettings.probes]
local kinds = {}
for _, row in ipairs(kept and kept.rows or {}) do
  kinds[row.k] = (kinds[row.k] or 0) + 1
end
check(
  kept
    and kept.lines[1]:find("^The game: ")
    and kept.healthBefore
    and kinds.combat == 3
    and kinds.cast == 1
    and kinds.control == 2
    and kinds.warning == 1
    and kept.rows[1].k == "combat"
    and kept.rows[1].event == "WOUND"
    and kept.rows[1].amount == 30
    and said("Kept in SecondWind.lua"),
  "… the report kept in the account's saved file, with what it was drawn from (each hit and heal, cast, stun event, the warning)"
)
check(
  said("The meter's healing: yours 20 %(its spells name Pippa%)")
    and said("The game's low%-health warning %(35%%%): seen in the fight")
    and said("read, 0 marked avoidable"),
  "… the harm marked avoidable or not, the meter's healing and whom it names, the game's own low-health warning"
)
if G.FOREVER then
  check(
    said("The combat log: closed")
      and said("Your health in the fight: hidden")
      and said("Your health out of a fight: hidden")
      and said("Your health through the heal calculator: hidden"),
    "… Forever: the log closed, my health hidden in a fight and out of it, the calculator no way round"
  )
  check(
    said("The notice before combat's restrictions: seen") and said("The damage meter: 1 of the spells"),
    "… the notice seen, the meter read"
  )
else
  check(
    said("The combat log: %d+ lines heard") and said("Your health in the fight: readable"),
    "… Classic: the log heard, my health readable"
  )
  check(
    said("Your casts in the fight: readable") and said("The notice before combat's restrictions: not seen"),
    "… my casts readable, no notice"
  )
end

-- ── the graph's marks, the text to copy ──────────────────────────────────────
if not G.FOREVER then
  debriefs = life()
  G.state.book = { ["Shield Wall"] = { id = 871, cd = 1800 } }
  G.state.bags = { [929] = { count = 2 } }
  G.pull()
  G.hit({ from = "Defias Footpad", amount = 60 })
  G.wait(1)
  G.hit({ from = "Defias Pillager", amount = 50, spell = { 133, "Fireball", 4 } })
  G.stun({ seconds = 1.5, spell = { 1833, "Cheap Shot" } })
  G.wait(2)
  G.cast({ 871, "Shield Wall" })
  G.use(929, 441, "Healing Potion")
  G.hit({ from = "Defias Footpad", amount = 55 })
  G.leave()
  G.state.book, G.state.bags = {}, {}
  local d = only(debriefs, "close")
  local kinds = {}
  for _, m in ipairs(ns.marksOf(d)) do
    table.insert(kinds, m.kind .. "@" .. m.t)
  end
  check(
    table.concat(kinds, " ") == "hit@0 foe@1 hit@1 held@1 hit@3 used@3 used@3",
    "the graph's marks: the hits that mattered, a foe joining, control lost, what I used"
  )
  ns.openDebrief(d.at)
  local g = book.card.graph
  local keys = {}
  for _, k in ipairs(g.keys) do
    if k:IsShown() then table.insert(keys, k.text:GetText()) end
  end
  check(
    #g.shownMarks == 7
      and g.legend:IsShown()
      and table.concat(keys, ", ") == "Below 15%, your threshold, Hits that mattered, Out of your control",
    "… drawn on the graph, a swatch and its words for each mark that needs them"
  )
  local shown, texts = 0, {}
  for _, pool in ipairs({ g.slots, g.faces }) do
    for _, f in ipairs(pool) do
      if f:IsShown() then shown = shown + 1 end
    end
  end
  for _, l in ipairs(g.labels) do
    if l:IsShown() then texts[l:GetText()] = true end
  end
  check(shown == 3, "… under it, a lane: the tools used and the foe that joined, by their pictures")
  check(
    texts["100%"] and texts["50%"] and texts["15%"] and texts["8%"] and texts["0 s"] and texts["3 s"],
    "… the scale, the threshold, the lowest point and the time, labelled"
  )
  local text = ns.textOf(d)
  check(
    text:find("^Second Wind: Close call: 8%% health\n")
      and text:find("\nWhat you had:\n  Used: Shield Wall, Healing Potion %(2%)"),
    "the debrief as text: its title, its lessons, its sections"
  )
  G.slash("copy")
  check(
    SecondWindCopy and SecondWindCopy:IsShown() and SecondWindCopy.box:GetText() == text,
    "… /wind copy: in a box to copy"
  )
  SecondWindCopy:Hide()
  book:Hide()
end

-- ── what I carry ─────────────────────────────────────────────────────────────
debriefs = life()
G.state.book = {
  ["Shield Wall"] = { id = 871, cd = 1800 },
  ["Retaliation"] = { id = 20230, cd = 1800, ready = GetTime() + 600 },
}
G.state.bags = {
  [929] = { count = 2 },
  [5509] = { count = 1 },
  [19008] = { count = 1 },
  [1251] = { count = 5 },
  [6049] = { count = 1 },
}
G.state.auras = { [11196] = GetTime() + 40 }
local carry = ns.carryPage(ns.carried())
local function carried(heading)
  for _, sec in ipairs(carry.sections) do
    if sec.heading == heading then return table.concat(sec.lines, " | ") end
  end
end
check(
  carried("Heals") == "Healing Potion (2): ready | Healthstone (2): ready",
  "what I carry: the heals, a healthstone's ranks together"
)
check(carried("Bandages") == "Linen Bandage (5): Recently Bandaged, 40 s", "… a bandage, not while Recently Bandaged")
check(
  carried("Guards") == "Shield Wall: ready | Retaliation: ready in 10 min | Fire Protection Potion: ready, against fire",
  "… the guards: ready, or how long until; what a potion is against"
)
check(
  carried("None of these") == "A cure: an anti-venom, a restorative potion | Anything that holds a foe or gets you out",
  "… and the kinds I carry none of"
)
-- (drawn: a row a tool, its state; the kinds I carry none of, an empty slot)
ns.openTab(ns.TAB.carry)
local first = drawn(book.carry, "tool", 1)
check(first and first.title.text == "Healing Potion" and first.value.text == "ready", "… drawn: a tool, its state")
check(first.icon.count.text == "2", "… its count on its icon")
book:Hide()
G.slash("lifelines")
check(book:IsShown() and book.carry.shown.title == "Your lifelines", "/wind lifelines: the book at that page")
check(
  book.carry.strip:IsShown()
    and book.carry.strip.tiles[1].label:GetText():find("carried$")
    and book.carry.strip.tiles[2].label:GetText() == "ready now",
  "… its figures on top: what you carry, what is ready"
)
book:Hide()
G.state.book, G.state.bags, G.state.auras = {}, {}, {}

-- ── every fight, and the patterns against it ─────────────────────────────────
debriefs = life()
for _ = 1, 2 do
  G.pull()
  G.hit({ from = "Ragged Young Wolf", amount = 30 })
  G.leave()
  G.state.health = G.state.maxHealth
end
check(ns.record().fights.n == 2 and #debriefs == 0, "every fight counted by its traits, kept or not")
local against = ns.patternsOf(five, { n = 40, since = 1000, traits = { low = 4, many = 6, late = 3 } })
check(
  section(against, "Most often"):find("^3 of 5: you went in below 60%% health %(4 of your 40 fights%) | "),
  "the patterns against every fight's, once twenty are counted"
)
check(
  not section(ns.patternsOf(five, { n = 10, traits = { low = 4 } }), "Most often"):find("fights%)"),
  "… not before"
)

-- ── a word before a pull ─────────────────────────────────────────────────────
local counted = ns.countsOf(five)
-- (one creature written in two languages: one foe, by its id, shown by the
-- newest debrief's name; a place by its areas the same)
local mixed = ns.countsOf({
  {
    kind = "close",
    sub = "Das Coldridgetal",
    subArea = 132,
    zone = "Dun Morogh",
    zoneArea = 1,
    foes = { { name = "Schneeleopard", npc = 1201 } },
  },
  {
    kind = "close",
    sub = "Coldridge Valley",
    subArea = 132,
    zone = "Dun Morogh",
    zoneArea = 1,
    foes = { { name = "Snow Leopard", npc = 1201 } },
  },
})
check(
  mixed.foes[1201] == 2
    and mixed.label[1201] == "Schneeleopard"
    and mixed.places["132|1"] == 2
    and mixed.keyOf["Snow Leopard"] == 1201,
  "a creature and a place written in two languages: each counted once, by its ids"
)
check(
  ns.wordBefore(counted, { name = "Rockjaw Trogg", level = 7 }, { level = 8, pct = 100 })
    == "3 of your 5 close calls and deaths were against Rockjaw Trogg.",
  "a word before a pull: a foe met in close calls before"
)
check(
  ns.wordBefore(counted, { name = "Frostmane Seer", level = 8 }, { level = 8, pct = 45 })
    == "You're at 45% health, and 3 of your 5 close calls and deaths began below 60%.",
  "… going in hurt, as most of them began"
)
check(
  ns.wordBefore(
    { total = 4, deaths = 0, traits = { elite = 2, above = 3 }, foes = {} },
    { name = "Defias Pillager", level = 12, rank = "elite" },
    { level = 9, pct = 100 }
  )
    == "Defias Pillager, an elite three levels above you. Of your 4 close calls, 2 had an elite and 3 had a foe two levels or more above you.",
  "… an elite, levels above: what they had"
)
check(
  ns.wordBefore(counted, { name = "Ragged Young Wolf", level = 3 }, { level = 8, pct = 45 }) == nil,
  "… nothing for a foe like none of them, nor for my health against a foe far below"
)
SecondWindAccount = nil -- (a fresh account: every character's close calls are counted)
debriefs = life()
for _, d in ipairs(five) do
  table.insert(debriefs, d)
end
local before = #G.printed
G.target({ name = "Rockjaw Trogg", level = 7 })
check(said("were against Rockjaw Trogg") and #G.printed == before + 1, "… said in chat when I target one")
G.target({ name = "Rockjaw Trogg", level = 7, guid = "Creature-0-4170-0-12-1999-00000999" })
check(#G.printed == before + 1, "… a name not again for a while")
G.state.inCombat = true
G.target({ name = "Burly Rockjaw Trogg", level = 7, rank = "elite" })
G.state.inCombat = false
ns.setOption("prepull", false)
G.target({ name = "Frostmane Seer", level = 8 })
ns.setOption("prepull", true)
check(#G.printed == before + 1, "… never in a fight, never when the setting is off")
G.state.health = 80
G.target({ name = "Rabbit", level = 8, type = "Critter" })
check(#G.printed == before + 1, "… nor at a critter")
G.target({ name = "Frostmane Snowstrider", level = 8 })
if G.FOREVER then
  check(#G.printed == before + 1, "… Forever: my health secret, no word on it")
else
  check(
    said("You're at 44%% health, and 3 of your 5 close calls and deaths began below 60%%%."),
    "… my health, before a foe near my level"
  )
end
G.state.health = G.state.maxHealth
G.target(nil)

-- ── every character's ────────────────────────────────────────────────────────
-- (a record of before 0.1.3, in the character's own file: moved in)
SecondWindAccount = nil
SecondWindChar =
  { guid = "Player-6113-0000OLD1", debriefs = { { kind = "close", at = 77, lowPct = 9, zone = "Elwynn Forest" } } }
G.state.guid, G.state.name = "Player-6113-0000OLD1", "Aldric"
G.reload()
check(
  ns.record().debriefs[1]
    and ns.record().debriefs[1].at == 77
    and SecondWindChar == nil
    and SecondWindAccount.characters["Player-6113-0000OLD1"].name == "Aldric",
  "a record of before 0.1.3 moved into the account's, with whose it is"
)
-- (a Hardcore life ends; the next character reads it)
SecondWindAccount = nil
G.state.guid, G.state.name, G.state.hardcore = "Player-6113-0000HELL", "Hellefie", true
G.state.health, G.state.dead = G.state.maxHealth, false
G.reload()
ns.setOption("threshold", 15)
G.pull()
G.hit({ from = "Defias Pillager", amount = 100 })
G.hit({ from = "Defias Pillager", amount = 100 })
G.die()
G.wait(1.5)
G.state.hardcore = nil
local fallen = SecondWindAccount.characters["Player-6113-0000HELL"]
check(not G.FOREVER or fallen.fallen == nil, "(Forever: no Hardcore told)")
if not G.FOREVER then check(fallen.fallen, "a Hardcore death: the character's record kept, marked fallen") end
G.state.guid, G.state.name = "Player-6113-0000MAX1", "Max"
G.state.health, G.state.dead = G.state.maxHealth, false
G.reload()
ns.setOption("threshold", 15)
G.pull()
G.hit({ from = "Ragged Young Wolf", amount = 80 })
G.hit({ from = "Ragged Young Wolf", amount = 75 })
G.leave()
book:Hide()
ns.window():Show()
ns.showTab(ns.TAB.debriefs)
check(#ns.debriefsOf(false) == 1 and book.count:GetText() == "1 debrief", "the book: this character's debriefs")
book.scope.onChange("every")
check(
  #ns.debriefsOf(true) == 2 and book.count:GetText() == "2 debriefs, 2 characters",
  "… or every character's of this game, at a choice"
)
local subs = {}
for _, r in ipairs(book.rows) do
  if r:IsShown() then table.insert(subs, r.sub:GetText()) end
end
check(subs[2] and subs[2]:find("^Hellefie · "), "… each row naming whose it is")
book.open = ns.debriefsOf(true)[1].at
ns.refresh()
check(
  book.cardShown.sub:find(G.FOREVER and "^Hellefie %(warrior%) · " or "^Hellefie %(warrior, fallen%) · "),
  "… another's card: whose, and fallen"
)
book.scope.onChange("mine")
book:Hide()
-- (the word before a pull: a past life's close calls count)
SecondWindAccount = nil
G.state.guid, G.state.name = "Player-6113-0000PAST", "Past"
G.reload()
for i = 1, 3 do
  table.insert(
    ns.record().debriefs,
    { kind = "close", at = 100 + i, zone = "Dun Morogh", foes = { { name = "Rockjaw Ambusher" } } }
  )
end
G.state.guid, G.state.name = "Player-6113-0000NEXT", "Next"
G.reload()
local printedBefore = #G.printed
G.target({ name = "Rockjaw Ambusher", level = 7 })
check(
  #ns.record().debriefs == 0
    and #G.printed == printedBefore + 1
    and said("3 of your 3 close calls were against Rockjaw Ambusher"),
  "the word before a pull: a past life's close calls count for the next character"
)
G.target(nil)

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
check(
  (G.FOREVER and G.secret(UnitHealth("player")) or UnitHealth("player") == 0) and not InCombatLockdown(),
  "… out of the fight, dead (Forever: my health secret out of it too)"
)

-- The saved file keeps ids, not the names they give: at the logout every name
-- an id gives back is let go (a place's, a creature's, a type's, a spell's, a
-- tool's), the login names them again; a name no id gives stays.
do
  local list = ns.record().debriefs
  table.insert(list, {
    kind = "close",
    at = 77,
    zone = "Dun Morogh",
    zoneArea = 1,
    sub = "Coldridge Valley",
    subArea = 132,
    foes = {
      { name = ns.creatureNameOf(6), npc = 6, typeId = 7, type = "Humanoid", hits = 1, damage = 9 },
      { name = "Kyle", player = true, hits = 1 },
    },
    killer = { name = ns.creatureNameOf(6), spell = "Shield Wall", id = 871 },
    recap = {
      { src = ns.creatureNameOf(6), spell = "Shield Wall", id = 871, amount = 9 },
      { src = "Kyle", amount = 3 },
    },
    casts = { { t = 1, id = 871, name = "Shield Wall" } },
    ready = { { n = "Shield Wall", k = "guard", sid = 871 } },
    unused = {},
  })
  G.spellNamed(871, "Shield Wall")
  G.reload()
  local saved
  for _, c in pairs(G.saved().characters) do
    for _, d in ipairs(c.debriefs or {}) do
      if d.at == 77 then saved = d end
    end
  end
  check(
    saved
      and saved.zone == nil
      and saved.sub == nil
      and saved.zoneArea == 1
      and saved.foes[1].name == nil
      and saved.foes[1].npc == 6
      and saved.foes[1].type == nil
      and saved.foes[2].name == "Kyle"
      and saved.killer.name == nil
      and saved.killer.npc == 6
      and saved.killer.spell == nil
      and saved.recap[1].src == nil
      and saved.recap[1].srcNpc == 6
      and saved.recap[1].spell == nil
      and saved.recap[2].src == "Kyle"
      and saved.casts[1].name == nil
      and saved.ready[1].n == nil,
    "the saved file keeps a debrief's ids, never the names they give (a player's name kept)"
  )
  local d = list[#list]
  check(
    d.zone == "Dun Morogh"
      and d.sub == "Coldridge Valley"
      and d.foes[1].name == ns.creatureNameOf(6)
      and d.foes[1].type == "Humanoid"
      and d.killer.name == ns.creatureNameOf(6)
      and d.killer.spell == "Shield Wall"
      and d.recap[1].src == ns.creatureNameOf(6)
      and d.casts[1].name == "Shield Wall"
      and d.ready[1].n == "Shield Wall",
    "… and the login names them again"
  )
  table.remove(list)
end

io.stdout:write(("all good%s: %d checks\n"):format(G.FOREVER and " (Forever)" or "", passed))
