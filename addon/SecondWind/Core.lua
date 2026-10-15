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
--     seen[name] = { npc, level, rank, type, at }  creatures in sight, the
--       last 400 (a foe the fight named only: its portrait, what it was)
--   SecondWindChar (SavedVariablesPerCharacter): the record before 0.1.3,
--     moved into the account's at the login
local _, ns = ...
local L = ns.kit.L
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

-- ── creatures seen ───────────────────────────────────────────────────────────
-- What the game told of a creature in sight (my target, under the mouse, a
-- nameplate): its npc id, kind, rank and level, by name, account-wide
-- (SecondWindAccount.seen), the last SEEN names kept. For a foe a fight named
-- only (Forever's meter) or met out of sight: its portrait and what it was.
local SEEN = 400
local function clear(v) return v ~= nil and not ns.secret(v) end
function ns.see(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
  local guid, name = UnitGUID(unit), UnitName(unit)
  if not (clear(guid) and clear(name)) then return end
  local npc = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or "")
  if not npc then return end
  local level, rank, kind = UnitLevel(unit), UnitClassification(unit), UnitCreatureType(unit)
  local acc = account()
  acc.seen = acc.seen or {}
  acc.seen[name] = {
    npc = npc,
    level = clear(level) and level > 0 and level or nil,
    rank = clear(rank) and rank ~= "normal" and rank or nil,
    type = clear(kind) and kind or nil,
    at = time(),
  }
end
function ns.seenNamed(name)
  local seen = type(SecondWindAccount) == "table" and SecondWindAccount.seen
  return seen and name and seen[name] or nil
end
-- A foe made whole from what was seen of its name (its npc id, its kind and
-- rank where the fight didn't tell them; its level the fight's own), else
-- from the creatures of the original world (Creatures.lua: its npc id).
function ns.knownFoe(foe)
  if foe.npc or foe.player or not foe.name then return foe end
  local s = ns.seenNamed(foe.name)
  if s then
    foe.npc = s.npc
    foe.type = foe.type or s.type
    foe.rank = foe.rank or s.rank
  else
    foe.npc = ns.creatures and ns.creatures.names[foe.name] or nil
  end
  return foe
end
-- A creature's own name from one the game's death recap gave: Forever's adds
-- a word to each unit's ("Snow Leopard Nub", "Crag Boar Mcnugg": the same word
-- on every blow of one unit, no player's, seen on 15 October 2026 with no one
-- near), which no table knows and which splits one kind of foe into many. The
-- name itself where it is known, else the longest known name it begins with
-- ("Snow Leopard"); known: the fight's own meter names (`also`), the
-- creatures seen, the game's (Creatures_<game>.lua, in the client's language).
function ns.ownName(name, also)
  if type(name) ~= "string" then return name end
  local function known(n)
    return (also and also[n]) or ns.seenNamed(n) or (ns.creatures and ns.creatures.names and ns.creatures.names[n])
  end
  if known(name) then return name end
  local cut = name:match("^(.+) %S+$")
  while cut do
    if known(cut) then return cut end
    cut = cut:match("^(.+) %S+$")
  end
  return name
end
-- A debrief's recap, killer and foes by their own names (ns.ownName), the
-- foes of one name one foe, as the combat log's are: at a death's recap, and
-- at the login for debriefs saved before.
function ns.ownNames(d)
  local also = {}
  for _, sp in ipairs(d.spells or {}) do
    if sp.src then also[sp.src] = true end
  end
  for _, r in ipairs(d.recap or {}) do
    r.src = ns.ownName(r.src, also)
  end
  if d.killer then d.killer.name = ns.ownName(d.killer.name, also) end
  local foes, byName = {}, {}
  for _, foe in ipairs(d.foes or {}) do
    if not foe.player then foe.name = ns.ownName(foe.name, also) end
    local same = foe.name and not foe.player and byName[foe.name]
    if same then
      same.hits = (same.hits or 0) + (foe.hits or 0)
      same.damage = (same.damage or 0) + (foe.damage or 0)
      if foe.misses then same.misses = (same.misses or 0) + foe.misses end
      if foe.first and (not same.first or foe.first < same.first) then same.first = foe.first end
    else
      table.insert(foes, foe)
      if foe.name and not foe.player then byName[foe.name] = foe end
    end
  end
  d.foes = foes
end
local function forget()
  local seen = type(SecondWindAccount) == "table" and SecondWindAccount.seen
  if not seen then return end
  local names = {}
  for name, s in pairs(seen) do
    table.insert(names, { name = name, at = s.at or 0 })
  end
  if #names <= SEEN then return end
  table.sort(names, function(a, b) return a.at > b.at end)
  for i = SEEN + 1, #names do
    seen[names[i].name] = nil
  end
end

ns.on("PLAYER_TARGET_CHANGED", function() ns.see("target") end)
ns.on("UPDATE_MOUSEOVER_UNIT", function() ns.see("mouseover") end)
ns.on("NAME_PLATE_UNIT_ADDED", function(unit) ns.see(unit) end)

local function newRecord(guid)
  char = { guid = guid, debriefs = {} }
  account().characters[guid] = char
end

-- This character's record (by its GUID: another of the same name is not it),
-- or a new one; a record of before 0.1.3, in the character's own saved file
-- (SecondWindChar), moved into the account's.
function ns.login()
  forget()
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
  -- (debriefs saved before a recap's names were made the creatures' own:
  -- mended, every character's)
  for _, c in pairs(account().characters) do
    for _, d in ipairs(c.debriefs or {}) do
      if d.recap then
        ns.ownNames(d)
        for _, foe in ipairs(d.foes or {}) do
          ns.knownFoe(foe)
        end
      end
    end
  end
  ns.loadProfile()
  ns.collect:start()
  ns.createMinimapButton()
  ns.createSettingsPanel()
end

-- (its level kept up, for the book of every character)
ns.on("PLAYER_LEVEL_UP", function(level)
  if char and level and not ns.secret(level) then char.level = level end
end)

-- ── /secondwind ──────────────────────────────────────────────────────────────
local USAGE =
  L["/secondwind (or /wind) opens the book, /wind settings its settings. /wind minimap shows or hides the button. /wind copy gives the open debrief as text. /wind lifelines shows what you carry for the worst moments. /wind welcome shows the welcome page again. /wind export gives this character's settings as a code, and /wind import CODE takes them. /wind reset forgets this character's debriefs. /wind probe says, after the next fight, what the game let Second Wind read of it."]

SLASH_SECONDWIND1 = "/secondwind"
SLASH_SECONDWIND2 = "/wind"
SlashCmdList.SECONDWIND = function(msg)
  local raw = strtrim(msg or "")
  msg = raw:lower()
  if msg == "" then
    ns.toggle()
  elseif msg == "reset" then
    print(PREFIX .. L["this forgets every debrief of this character. Type /wind reset yes to do it."])
  elseif msg == "reset yes" then
    newRecord(char.guid)
    ns.refresh()
    print(PREFIX .. L["this character's debriefs are forgotten."])
  elseif msg == "welcome" then
    ns.showWelcome()
  elseif msg == "export" then
    ns.showWelcome("export")
  elseif msg:match("^import%s") then
    if ns.profiles:import(raw:match("^%a+%s+(.+)$")) then
      print(PREFIX .. L["settings imported for this character."])
    else
      print(PREFIX .. L["that isn't a Second Wind settings code (/wind export makes one)."])
    end
  elseif msg == "probe" then
    ns.probeArm()
  elseif msg == "copy" then
    if not ns.copyDebrief() then print(PREFIX .. L["no debrief to copy yet."]) end
  elseif msg == "lifelines" or msg == "carry" or msg == "kit" then
    ns.openTab(ns.TAB.carry)
  elseif msg == "minimap" then
    ns.setOption("minimapHidden", not ns.option("minimapHidden"))
  elseif msg == "settings" or msg == "options" then
    if not ns.openSettings() then print(PREFIX .. L["no settings page in this client."]) end
  else
    print(PREFIX .. USAGE)
  end
end
