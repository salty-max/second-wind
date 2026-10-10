-- A fake game for the tests: the WoW API the addon uses, its events, a
-- character to play (state), fights to replay (the combat log, health, casts,
-- a death and the game's recap of it) and the addon loaded into it.
--   local G = dofile("addon/test/game.lua")
-- FOREVER=1 in the environment: Forever's client (no combat log for addons,
-- the player's health a secret value in a fight).
local DIR = "addon/SecondWind/"
local FOREVER = os.getenv("FOREVER") == "1"
function GetBuildInfo() return "1.15.9", "70003", "Oct 1 2026", FOREVER and 16001 or 11509 end
local secrets = {}
if FOREVER then issecretvalue = function(v) return secrets[v] == true end end
-- A secret value: a table only issecretvalue knows (comparing it would throw,
-- as in the game, where arithmetic on one is refused).
local function secret()
  local v = setmetatable({}, {
    __lt = function() error("compared a secret value") end,
    __le = function() error("compared a secret value") end,
    __eq = function() error("compared a secret value") end,
  })
  secrets[v] = true
  return v
end

-- ── a fake game ──────────────────────────────────────────────────────────────
local clock, uptime = 1790900000, 1000
function time() return clock end
function GetTime() return uptime end
date = os.date
local state = {
  guid = "Player-6113-0ABCDEF0",
  name = "Brannok",
  realm = "Nightslayer",
  level = 8,
  race = "Dwarf",
  class = "WARRIOR",
  zone = "Dun Morogh",
  sub = "Coldridge Valley",
  health = 180,
  maxHealth = 180,
  inCombat = false,
  dead = false,
}
local printed = {}
function print(msg) table.insert(printed, msg) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetRealZoneText() return state.zone end
function GetSubZoneText() return state.sub end
function GetRealmName() return state.realm end
function UnitGUID(u) return u == "player" and state.guid or nil end
function UnitName(u) return u == "player" and state.name or nil end
local units = {} -- token = what the game can tell of a creature in sight
function UnitLevel(u)
  if u == "player" then return state.level end
  return units[u] and units[u].level or 1
end
function UnitClassification(u) return units[u] and units[u].rank or "normal" end
function UnitCreatureType(u) return units[u] and units[u].type or nil end
function UnitClass(u) return u == "player" and state.class:sub(1, 1) .. state.class:sub(2):lower(), state.class end
function UnitRace(u) return state.race, state.race end
function UnitHealthMax(u) return u == "player" and state.maxHealth or 0 end
function UnitHealth(u)
  if u ~= "player" then return 0 end
  if FOREVER and state.inCombat then return secret() end
  return state.health
end
function UnitIsDeadOrGhost(u) return u == "player" and state.dead end
function UnitAffectingCombat(u) return u == "player" and state.inCombat end
function IsInInstance() return state.instance ~= nil, state.instance or "none" end
function IsInGroup() return state.grouped == true end
if not FOREVER then C_GameRules = { IsHardcoreActive = function() return state.hardcore == true end } end
function hooksecurefunc(name, fn)
  local original = _G[name]
  _G[name] = function(...)
    local r = original(...)
    fn(...)
    return r
  end
end
function StartDuel() end
local SPELLS = {}
function GetSpellInfo(id) return SPELLS[id] end
function InCombatLockdown() return state.inCombat end

-- Timers: run when the clock passes them (G.wait).
local timers = {}
C_Timer = {
  After = function(seconds, fn) table.insert(timers, { at = uptime + seconds, fn = fn }) end,
}
local function wait(seconds)
  local stop = uptime + seconds
  while true do
    local nextOne, at
    for i, t in ipairs(timers) do
      if t.at <= stop and (not at or t.at < at) then
        nextOne, at = i, t.at
      end
    end
    if not nextOne then break end
    local t = table.remove(timers, nextOne)
    clock, uptime = clock + (t.at - uptime), t.at
    t.fn()
  end
  clock, uptime = clock + (stop - uptime), stop
end

-- UI: any method works and returns something sensible, scripts are kept.
local function ui()
  local o = { shown = false, scripts = {} }
  return setmetatable(o, {
    __index = function(t, k)
      if k == "SetScript" then
        return function(self, name, fn) self.scripts[name] = fn end
      end
      if k == "HookScript" then
        return function(self, name, fn)
          local was = self.scripts[name]
          self.scripts[name] = function(...)
            if was then was(...) end
            fn(...)
          end
        end
      end
      if k == "Show" then
        return function(self)
          -- (OnShow on a showing only, as in the game: not on a shown frame)
          local was = self.shown
          self.shown = true
          if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
        end
      end
      if k == "Hide" then
        return function(self)
          local was = self.shown
          self.shown = false
          if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
      end
      if k == "SetShown" then
        return function(self, v)
          if v then
            self:Show()
          else
            self:Hide()
          end
        end
      end
      if k == "IsShown" then
        return function(self) return self.shown end
      end
      if k == "SetText" then
        return function(self, v) self.text = v end
      end
      if k == "GetText" then
        return function(self) return rawget(self, "text") or "" end
      end
      if k == "SetChecked" then
        return function(self, v) self.checked = v and true or false end
      end
      if k == "GetChecked" then
        return function(self) return rawget(self, "checked") or false end
      end
      if k == "GetStringHeight" then
        return function() return 14 end
      end
      if k == "GetStringWidth" then
        return function(self) return 6 * #(rawget(self, "text") or "") end
      end
      if k == "GetHeight" then
        return function() return 100 end
      end
      if k == "GetWidth" then
        return function() return 140 end
      end
      if k == "GetCenter" then
        return function() return 0, 0 end
      end
      if k == "GetEffectiveScale" or k == "GetFrameLevel" then
        return function() return 1 end
      end
      if k == "CreateFontString" or k == "CreateTexture" then
        return function() return ui() end
      end
      return function() return t end
    end,
  })
end
UIParent, UISpecialFrames = ui(), {}
Minimap, GameTooltip = ui(), ui()
function GetCursorPosition() return 0, 0 end
SlashCmdList = {}
C_XMLUtil = { GetTemplateInfo = function(name) return name ~= "PanelTabButtonTemplate" or nil end }

-- The game's settings panel: keep what the addon registers.
local panel = { settings = {} }
Settings = {
  VarType = { Boolean = "boolean", Number = "number", String = "string" },
  RegisterVerticalLayoutCategory = function(name)
    panel.name = name
    return { GetID = function() return 42 end }
  end,
  RegisterProxySetting = function(_, variable, _, name, default, get, set)
    local s = { variable = variable, name = name, default = default, get = get, set = set }
    panel.settings[variable] = s
    return s
  end,
  CreateCheckbox = function() end,
  CreateDropdown = function(_, setting, options) setting.options = options end,
  CreateControlTextContainer = function()
    local data = {}
    return {
      Add = function(_, value, label) table.insert(data, { value = value, label = label }) end,
      GetData = function() return data end,
    }
  end,
  RegisterAddOnCategory = function() panel.registered = true end,
  OpenToCategory = function(id) panel.opened = id end,
}

-- Frames and events: an event reaches the frames registered for it.
local frames = {}
function CreateFrame(_, name, _, template)
  local f = ui()
  f.shown = true -- (a new frame is shown, as in the game)
  f.registered, f.unitsOf = {}, {}
  if template == "ButtonFrameTemplate" then -- the game's window has its portrait
    local p = ui()
    f.GetPortrait = function() return p end
  end
  function f:RegisterEvent(e)
    if FOREVER and e == "COMBAT_LOG_EVENT_UNFILTERED" then error("COMBAT_LOG_EVENT_UNFILTERED: forbidden") end
    self.registered[e] = true
  end
  function f:UnregisterEvent(e) self.registered[e] = nil end
  -- a unit's event, heard for that unit only
  function f:RegisterUnitEvent(e, ...)
    self:RegisterEvent(e)
    self.unitsOf[e] = {}
    for _, unit in ipairs({ ... }) do
      self.unitsOf[e][unit] = true
    end
  end
  table.insert(frames, f)
  if name then _G[name] = f end
  return f
end
local function hears(f, e, unit)
  return f.registered[e] and f.scripts.OnEvent and not (f.unitsOf[e] and not f.unitsOf[e][unit])
end
-- an event the game sends whether anyone listens or not
local function offer(e, ...)
  for _, f in ipairs(frames) do
    if hears(f, e, ...) then f.scripts.OnEvent(f, e, ...) end
  end
end

-- ── fights ───────────────────────────────────────────────────────────────────
-- Creatures by name: their GUIDs ("Creature-0-...-<npc id>-<spawn>").
local npcs, nextSpawn = {}, 0
local function creature(name, player)
  if not npcs[name] then
    nextSpawn = nextSpawn + 1
    npcs[name] = player and ("Player-6113-%08X"):format(nextSpawn)
      or ("Creature-0-4170-0-12-%d-%08X"):format(1000 + nextSpawn, nextSpawn)
  end
  return npcs[name]
end
-- A creature in sight (a nameplate): its level, rank ("elite", "rare") and kind.
local tokens = {}
function UnitTokenFromGUID(guid) return tokens[guid] end
-- The combat log: its current line (CombatLogGetCurrentEventInfo), each sent
-- as COMBAT_LOG_EVENT_UNFILTERED (Classic only: Forever keeps it from addons).
local line = {}
function CombatLogGetCurrentEventInfo() return unpack(line, 1, line.n) end
local PLAYER_FLAGS, HOSTILE_FLAGS = 0x511, 0xa48
local function log(sub, source, sourceName, dest, destName, ...)
  local sourceFlags = source == state.guid and PLAYER_FLAGS or HOSTILE_FLAGS
  local destFlags = dest == state.guid and PLAYER_FLAGS or HOSTILE_FLAGS
  line = { clock, sub, false, source, sourceName, sourceFlags, 0, dest, destName, destFlags, 0, ... }
  line.n = 11 + select("#", ...)
  if not FOREVER then offer("COMBAT_LOG_EVENT_UNFILTERED") end
end
-- The hits of the fight (for the death recap), newest first.
local recap = {}
local function health(v)
  state.health = math.max(0, math.min(state.maxHealth, v))
  offer("UNIT_HEALTH", "player")
end

local G = {}
function G.sight(name, info)
  local token = "nameplate" .. (#tokens + 1)
  tokens[creature(name)] = token
  units[token] = info
end
-- A fight begins: in combat.
function G.pull()
  recap = {}
  state.inCombat = true
  offer("PLAYER_REGEN_DISABLED")
end
-- A hit on me: { from = name, amount, spell = { id, name, school } (else a
-- melee swing), crit = true }.
function G.hit(h)
  local source = creature(h.from, h.player)
  local overkill = math.max(0, h.amount - state.health)
  if h.spell then
    log(
      "SPELL_DAMAGE",
      source,
      h.from,
      state.guid,
      state.name,
      h.spell[1],
      h.spell[2],
      h.spell[3] or 1,
      h.amount,
      overkill,
      h.spell[3] or 1,
      0,
      0,
      0,
      h.crit or false,
      false,
      false
    )
  else
    log(
      "SWING_DAMAGE",
      source,
      h.from,
      state.guid,
      state.name,
      h.amount,
      overkill,
      1,
      0,
      0,
      0,
      h.crit or false,
      false,
      false
    )
  end
  health(state.health - h.amount)
  table.insert(recap, 1, {
    timestamp = clock,
    amount = h.amount,
    overkill = overkill > 0 and overkill or nil,
    currentHP = state.health,
    sourceName = h.from,
    school = h.spell and h.spell[3] or 1,
    spellId = h.spell and h.spell[1] or nil,
  })
end
-- A heal on me: { from = name (or me), amount, spell = { id, name } }.
function G.heal(h)
  local source = h.from and creature(h.from) or state.guid
  log(
    "SPELL_HEAL",
    source,
    h.from or state.name,
    state.guid,
    state.name,
    h.spell[1],
    h.spell[2],
    2,
    h.amount,
    0,
    0,
    false
  )
  health(state.health + h.amount)
end
-- Harm from the world out of a fight: kind ("Falling", "Drowning", "Lava").
function G.env(kind, amount)
  local overkill = math.max(0, amount - state.health)
  log("ENVIRONMENTAL_DAMAGE", nil, nil, state.guid, state.name, kind, amount, overkill, 1, 0, 0, 0, false, false, false)
  health(state.health - amount)
  table.insert(recap, 1, {
    timestamp = clock,
    amount = amount,
    overkill = overkill > 0 and overkill or nil,
    currentHP = state.health,
    school = 1,
  })
end
-- A blow that missed me: { from, what = "DODGE" | "PARRY" | ... }.
function G.miss(m) log("SWING_MISSED", creature(m.from), m.from, state.guid, state.name, m.what, false, 0) end
-- A debuff on me: { from, spell = { id, name } }.
function G.debuff(d)
  log("SPELL_AURA_APPLIED", creature(d.from), d.from, state.guid, state.name, d.spell[1], d.spell[2], 1, "DEBUFF")
end
-- Time passes (the clock and the timers).
G.wait = wait
-- A duel asked of me, and its end.
function G.duel() offer("DUEL_REQUESTED", "Kyle") end
function G.duelOver() offer("DUEL_FINISHED") end
-- A spell of mine cast: { id, name }.
function G.cast(spell)
  SPELLS[spell[1]] = spell[2]
  log("SPELL_CAST_SUCCESS", state.guid, state.name, nil, nil, spell[1], spell[2], 1)
  offer("UNIT_SPELLCAST_SUCCEEDED", "player", ("Cast-3-4170-0-1-%d-0001"):format(spell[1]), spell[1])
end
-- The fight is over: out of combat, a moment passing.
function G.leave()
  state.inCombat = false
  offer("PLAYER_REGEN_ENABLED")
  wait(0.5)
end
-- I die: the last hit's done it; out of combat, the game's recap kept.
local recaps = {}
function G.die()
  state.dead, state.health = true, 0
  table.insert(recaps, recap)
  offer("PLAYER_DEAD")
  G.leave()
end
-- The game's death recap (C_DeathRecap: the hits before a death, newest first).
C_DeathRecap = {
  HasRecapEvents = function(id) return recaps[id or #recaps] ~= nil end,
  GetRecapEvents = function(id) return recaps[id or #recaps] end,
  GetRecapMaxHealth = function() return state.maxHealth end,
}

-- ── load the addon ───────────────────────────────────────────────────────────
-- The files in the order of the game's own TOC.
local ns = {}
for l in io.lines(DIR .. (FOREVER and "SecondWind_Camelot.toc" or "SecondWind_Vanilla.toc")) do
  local f = l:match("^([%w_]+%.lua)%s*$")
  if f then assert(loadfile(DIR .. f))("SecondWind", ns) end
end

function G.login()
  offer("PLAYER_LOGIN")
  offer("PLAYER_ENTERING_WORLD", true, false)
end
function G.reload()
  offer("PLAYER_LOGOUT")
  offer("PLAYER_LOGIN")
  offer("PLAYER_ENTERING_WORLD", false, true)
end
G.ns, G.state, G.panel, G.printed, G.wait, G.offer, G.FOREVER = ns, state, panel, printed, wait, offer, FOREVER
G.secret = function(v) return secrets[v] == true end
G.line = function() return line end
function G.slash(msg) SlashCmdList.SECONDWIND(msg) end
return G
