-- Second Wind: this character's record, the events every file listens to
-- (ns.on, ns.onUnit) and /secondwind. The fights are recorded by the recorder
-- (to come: PLAN.md, step 2) and shown in the book (Book.lua).
--
--   SecondWindChar (SavedVariablesPerCharacter), whose record: guid
--     debriefs = { ... }   the close calls and the deaths, newest last
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

-- ── events ───────────────────────────────────────────────────────────────────
-- Every file listens through ns.on (an event a client doesn't know is never
-- heard), unit events through ns.onUnit (for one unit only: UNIT_HEALTH fires
-- for every unit in sight). Nothing is heard before the login.
local frame = CreateFrame("Frame")
local listeners = {}

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then ns.login() end
  if not char then return end
  for _, fn in ipairs(listeners[event] or {}) do
    fn(...)
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
        listener(...)
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
local function newRecord(guid)
  char = { guid = guid, debriefs = {} }
  SecondWindChar = char
end

-- This character's record, or a new one (a record saved by another character
-- of the same name is not theirs).
function ns.login()
  local guid = UnitGUID("player")
  local before = type(SecondWindChar) == "table" and SecondWindChar.guid == guid
  if before then
    char = SecondWindChar
    char.debriefs = char.debriefs or {}
  else
    newRecord(guid)
  end
  ns.loadProfile()
  ns.createMinimapButton()
  ns.createSettingsPanel()
end

-- ── /secondwind ──────────────────────────────────────────────────────────────
local USAGE = "/secondwind (or /wind) opens the book; /wind settings; /wind minimap shows or hides the button; "
  .. "/wind welcome shows the welcome page again; /wind export gives this character's settings as a code, "
  .. "/wind import CODE takes them; /wind reset forgets this character's debriefs."

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
  elseif msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
  elseif msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. "no settings page in this client.") end
  else
    print(PREFIX .. USAGE)
  end
end
