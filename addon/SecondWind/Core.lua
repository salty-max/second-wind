-- Second Wind: the characters' records, the events every file listens to
-- (ns.on, ns.onUnit) and /secondwind. The fights are recorded by the recorder
-- (Recorder.lua) and shown in the book (Book.lua).
--
--   SecondWindAccount (SavedVariables): every character's record of this game,
--   by GUID, a fallen one's kept (its debriefs read from the next):
--     characters[guid] = { guid, name, realm, class, classFile, level, fallen,
--       debriefs = { ... },  the close calls and the deaths, newest last
--       fights = { n, since, traits = { trait = n } } }  every fight, kept or
--         not, counted by its traits (Recorder.lua): the patterns' measure
--   SecondWindChar (SavedVariablesPerCharacter): the record before 0.1.3,
--     moved into the account's at the login
local _, ns = ...
local PREFIX = "|cffa8c7e0Second Wind:|r "
ns.PREFIX = PREFIX

-- Which game: World of Warcraft: Forever (the original world on the modern
-- client, interface 16xxx) or Classic (Era, TBC Anniversary).
local interface = select(4, GetBuildInfo()) or 0
ns.forever = interface >= 16000 and interface < 20000

-- Forever hides some values from addons ("secret values", in combat or
-- instances): never compare or print one.
ns.secret = issecretvalue or function() return false end

local char
function ns.record() return char end

-- Every character's record of this game (this one's among them), by GUID.
function ns.everyRecord() return type(SecondWindAccount) == "table" and SecondWindAccount.characters or {} end

-- The debriefs to read, oldest first: this character's, or every character's
-- (ns.whose(d): the record each is from).
local whose = setmetatable({}, { __mode = "k" })
function ns.debriefsOf(every)
  if not every then return char and char.debriefs or {} end
  local out = {}
  for _, rec in pairs(ns.everyRecord()) do
    for _, d in ipairs(rec.debriefs or {}) do
      whose[d] = rec
      table.insert(out, d)
    end
  end
  table.sort(out, function(a, b) return (a.at or 0) < (b.at or 0) end)
  return out
end
function ns.whose(d) return whose[d] or char end

-- Every fight's tally (Recorder.lua), this character's or every character's.
function ns.fightsOf(every)
  if not every then return char and char.fights end
  local sum = { n = 0, traits = {} }
  for _, rec in pairs(ns.everyRecord()) do
    local f = rec.fights
    if f then
      sum.n = sum.n + (f.n or 0)
      if f.since and (not sum.since or f.since < sum.since) then sum.since = f.since end
      for k, n in pairs(f.traits or {}) do
        sum.traits[k] = (sum.traits[k] or 0) + n
      end
    end
  end
  return sum
end

-- ── events ───────────────────────────────────────────────────────────────────
-- Every file listens through ns.on (an event a client doesn't know is never
-- heard), unit events through ns.onUnit (for one unit only: UNIT_HEALTH fires
-- for every unit in sight). Nothing is heard before the login.
local frame = CreateFrame("Frame")
local listeners = {}

-- (one listener's error is reported, and the others still hear the event)
local function run(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then geterrorhandler()(err) end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then ns.login() end
  if not char then return end
  for _, fn in ipairs(listeners[event] or {}) do
    run(fn, ...)
  end
end)
frame:RegisterEvent("PLAYER_LOGIN")

function ns.on(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    pcall(frame.RegisterEvent, frame, event)
  end
  table.insert(listeners[event], fn)
end

local units = {} -- unit = its frame, with its own listeners
function ns.onUnit(event, unit, fn)
  local f = units[unit]
  if not f then
    f = CreateFrame("Frame")
    f.listeners = {}
    f:SetScript("OnEvent", function(_, e, ...)
      if not char then return end
      for _, listener in ipairs(f.listeners[e]) do
        run(listener, ...)
      end
    end)
    units[unit] = f
  end
  if not f.listeners[event] then
    f.listeners[event] = {}
    f:RegisterUnitEvent(event, unit)
  end
  table.insert(f.listeners[event], fn)
end

-- Does this client have the event? (registering an unknown one throws, and
-- Forever forbids the combat log to addons)
local probe = CreateFrame("Frame")
function ns.knows(event)
  local ok = pcall(probe.RegisterEvent, probe, event)
  if ok then probe:UnregisterEvent(event) end
  return ok
end

-- ── the login ────────────────────────────────────────────────────────────────
local function account()
  if type(SecondWindAccount) ~= "table" then SecondWindAccount = {} end
  SecondWindAccount.characters = SecondWindAccount.characters or {}
  return SecondWindAccount
end

local function newRecord(guid)
  char = { guid = guid, debriefs = {} }
  account().characters[guid] = char
end

-- This character's record (by its GUID: another of the same name is not it),
-- or a new one; a record of before 0.1.3, in the character's own saved file
-- (SecondWindChar), moved into the account's.
function ns.login()
  local guid = UnitGUID("player")
  char = account().characters[guid]
  if not char then
    local old = type(SecondWindChar) == "table" and SecondWindChar.guid == guid and SecondWindChar or nil
    newRecord(guid)
    if old then
      char.debriefs, char.fights = old.debriefs or {}, old.fights
    end
  end
  SecondWindChar = nil
  char.debriefs = char.debriefs or {}
  -- (who it is, for the book of every character)
  local className, classFile = UnitClass("player")
  char.name, char.realm, char.class, char.classFile = UnitName("player"), GetRealmName(), className, classFile
  char.level = UnitLevel("player")
  ns.loadProfile()
  ns.createMinimapButton()
  ns.createSettingsPanel()
end

-- (its level kept up, for the book of every character)
ns.on("PLAYER_LEVEL_UP", function(level)
  if char and level and not ns.secret(level) then char.level = level end
end)

-- ── /secondwind ──────────────────────────────────────────────────────────────
local USAGE = "/secondwind (or /wind) opens the book; /wind settings; /wind minimap shows or hides the button; "
  .. "/wind copy gives the open debrief as text; /wind carry shows what you carry for the worst moments; "
  .. "/wind welcome shows the welcome page again; /wind export gives this character's settings as a code, "
  .. "/wind import CODE takes them; /wind reset forgets this character's debriefs; /wind probe says, after "
  .. "the next fight, what the game let Second Wind read of it."

SLASH_SECONDWIND1 = "/secondwind"
SLASH_SECONDWIND2 = "/wind"
SlashCmdList.SECONDWIND = function(msg)
  local raw = strtrim(msg or "")
  msg = raw:lower()
  if msg == "" then
    ns.toggle()
  elseif msg == "reset" then
    print(PREFIX .. "this forgets every debrief of this character. Type /wind reset yes to do it.")
  elseif msg == "reset yes" then
    newRecord(char.guid)
    ns.refresh()
    print(PREFIX .. "this character's debriefs are forgotten.")
  elseif msg == "welcome" then
    ns.showWelcome()
  elseif msg == "export" then
    ns.showWelcome("export")
  elseif msg:match("^import%s") then
    if ns.profiles:import(raw:match("^%a+%s+(.+)$")) then
      print(PREFIX .. "settings imported for this character.")
    else
      print(PREFIX .. "that isn't a Second Wind settings code (/wind export makes one).")
    end
  elseif msg == "probe" then
    ns.probeArm()
  elseif msg == "copy" then
    if not ns.copyDebrief() then print(PREFIX .. "no debrief to copy yet.") end
  elseif msg == "carry" or msg == "kit" then
    ns.openTab(ns.TAB.carry)
  elseif msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
  elseif msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. "no settings page in this client.") end
  else
    print(PREFIX .. USAGE)
  end
end
