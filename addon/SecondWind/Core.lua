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
-- nameplate): its npc id, its type's id, rank and level, by its name of the day, account-wide
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
    typeId = clear(kind) and ns.typeIdOf(kind) or nil,
    at = time(),
  }
end
function ns.seenNamed(name)
  local seen = type(SecondWindAccount) == "table" and SecondWindAccount.seen
  return seen and name and seen[name] or nil
end
-- A foe made whole from what was seen of its name (its npc id, its type and
-- rank where the fight didn't tell them; its level the fight's own), else
-- from the game's names in the client's language (its npc id).
function ns.knownFoe(foe)
  if foe.npc or foe.player or not foe.name then return foe end
  local s = ns.seenNamed(foe.name)
  if s then
    foe.npc = s.npc
    foe.typeId = foe.typeId or s.typeId or ns.typeIdOf(s.type)
    foe.type = foe.type or ns.typeName(foe.typeId)
    foe.rank = foe.rank or s.rank
  else
    foe.npc = ns.creatureIdOf(foe.name)
  end
  return foe
end
-- A foe's key across debriefs and languages: its creature's id, else its
-- name (a player's, or a creature the game named only).
function ns.foeKey(foe) return foe and (not foe.player and foe.npc or foe.name) or nil end
-- A creature's id from its GUID ("Creature-0-…-<id>-…"), nil for a player's.
function ns.npcOf(guid)
  local id = type(guid) == "string" and not ns.secret(guid) and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  return id and tonumber(id) or nil
end
-- A creature's own name from one the game's death recap gave: Forever's adds
-- a word to each unit's ("Snow Leopard Nub", "Crag Boar Mcnugg": the same word
-- on every blow of one unit, no player's, seen on 15 October 2026 with no one
-- near), which no table knows and which splits one kind of foe into many. The
-- name itself where it is known, else the longest known name it begins with
-- ("Snow Leopard"); known: the fight's own meter names (`also`), the
-- creatures seen, the game's (its names in the client's language).
function ns.ownName(name, also)
  if type(name) ~= "string" then return name end
  local function known(n) return (also and also[n]) or ns.seenNamed(n) or ns.creatureIdOf(n) end
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
-- An area's id from its name in the client's language: the game's own
-- C_Map.GetAreaInfo over every id once, the reverse kept (no table shipped);
-- nil for a name of another language. And an area's name, by its id.
local areaIds
function ns.areaId(name)
  if type(name) ~= "string" or name == "" or not (C_Map and C_Map.GetAreaInfo) then return nil end
  if not areaIds then
    areaIds = {}
    for id = 1, 20000 do
      local n = C_Map.GetAreaInfo(id)
      if type(n) == "string" and n ~= "" and not areaIds[n] then areaIds[n] = id end
    end
  end
  return areaIds[name]
end
function ns.areaName(id)
  local n = id and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
  return type(n) == "string" and n ~= "" and n or nil
end
-- A spell's name in the client's language, by its id.
function ns.spellNameOf(id)
  if not id or ns.secret(id) then return nil end
  local n
  if C_Spell and C_Spell.GetSpellName then
    n = C_Spell.GetSpellName(id)
  elseif GetSpellInfo then
    n = GetSpellInfo(id)
  end
  return type(n) == "string" and n ~= "" and not ns.secret(n) and n or nil
end

-- A debrief in the client's language of today: a debrief keeps the names of
-- the day it was written (the game's, in that client's language), and its ids
-- where the game gave them. Where an id is missing, today's name finds it
-- (one written in today's language; another's waits for a client of its
-- own); every name with an id is then written again in today's: the places,
-- the creatures (the foes, the killer, the recap, the meter's rows and the
-- blows; a player's name kept), the spells (cast, the meter's, the recap's,
-- the killing blow), the tools, the creature types (by their ids, the game's). At each login, and for
-- each debrief written.
-- The game's own words for a kind of control lost, in the client's language
-- (its global strings; nil on a client without them: the words kept)
local HELD_WORDS = {
  STUN = LOSS_OF_CONTROL_DISPLAY_STUN,
  STUN_MECHANIC = LOSS_OF_CONTROL_DISPLAY_STUN_MECHANIC,
  FEAR = LOSS_OF_CONTROL_DISPLAY_FEAR,
  FEAR_MECHANIC = LOSS_OF_CONTROL_DISPLAY_FEAR_MECHANIC,
  CONFUSE = LOSS_OF_CONTROL_DISPLAY_CONFUSE,
  SLEEP = LOSS_OF_CONTROL_DISPLAY_SLEEP,
  CHARM = LOSS_OF_CONTROL_DISPLAY_CHARM,
  POSSESS = LOSS_OF_CONTROL_DISPLAY_POSSESS,
}
function ns.localize(d)
  d.zoneArea = d.zoneArea or ns.areaId(d.zone)
  d.subArea = d.subArea or ns.areaId(d.sub)
  d.zone = ns.areaName(d.zoneArea) or d.zone
  d.sub = ns.areaName(d.subArea) or d.sub
  local renamed = {}
  for _, foe in ipairs(d.foes or {}) do
    local name = not foe.player and foe.npc and ns.creatureNameOf(foe.npc)
    if name and foe.name and name ~= foe.name then
      renamed[foe.name] = name
      foe.name = name
    end
    if not foe.player and not foe.npc then foe.npc = ns.creatureIdOf(foe.name) end
    -- (a type by its id; an older debrief's English key or word of the day)
    if foe.type or foe.typeKey then
      foe.typeId = foe.typeId or ns.typeIdOf(foe.typeKey) or ns.typeIdOf(foe.type)
      foe.typeKey = nil
    end
    foe.type = ns.typeName(foe.typeId) or foe.type
  end
  if d.killer and renamed[d.killer.name] then d.killer.name = renamed[d.killer.name] end
  if d.killer and d.killer.id then d.killer.spell = ns.spellNameOf(d.killer.id) or d.killer.spell end
  for _, list in ipairs({ d.recap or {}, d.spells or {}, d.events or {}, d.casts or {} }) do
    for _, row in ipairs(list) do
      if row.src and renamed[row.src] then row.src = renamed[row.src] end
      local n = row.id and ns.spellNameOf(row.id)
      if n and row.spell then row.spell = n end
      if n and row.name then row.name = n end
    end
  end
  -- (control lost: its spell by id, the game's words for its kind)
  for _, h in ipairs(d.held or {}) do
    h.spell = ns.spellNameOf(h.sid) or h.spell
    local words = h.loc and HELD_WORDS[h.loc]
    if type(words) == "string" and words ~= "" then h.what = words end
  end
  for _, list in ipairs({ d.ready or {}, d.unused or {} }) do
    for _, t in ipairs(list) do
      -- (a tool, never a bare word)
      if type(t) == "table" and t.item then
        t.n = ns.kit.itemName(t.item, t.n)
      elseif type(t) == "table" then
        t.sid = t.sid or (ns.toolId and ns.toolId(t.n))
        t.n = ns.spellNameOf(t.sid) or t.n
      end
    end
  end
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
  -- (every character's debriefs: a recap's names made the creatures' own,
  -- for those saved before; their creatures named in today's language)
  for _, c in pairs(account().characters) do
    for _, d in ipairs(c.debriefs or {}) do
      if d.recap then ns.ownNames(d) end
      for _, foe in ipairs(d.foes or {}) do
        ns.knownFoe(foe)
      end
      ns.localize(d)
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
