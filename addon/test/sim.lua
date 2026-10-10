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

-- ── the fights the recorder will hear (the fake game itself) ─────────────────
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
