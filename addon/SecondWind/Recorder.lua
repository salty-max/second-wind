-- The recorder: each fight, from its first blow to its end, as it went, and a
-- debrief kept for one that left me below the threshold (Settings.lua) or
-- dead. Nothing is shown during a fight; the debrief is written once it is
-- over.
--
-- A fight begins with combat (PLAYER_REGEN_DISABLED) or the first harm out of
-- it (a fall, the water), and ends with combat (PLAYER_REGEN_ENABLED), a
-- death (PLAYER_DEAD), or, out of combat, QUIET seconds without harm. What it
-- keeps, from the combat log where the client gives it (Classic; Forever
-- keeps it from addons) and the game's own events:
--   the foes, by GUID: name, npc id, when each first hit, hits, misses,
--     damage; level, rank and kind when the game can tell (a unit token)
--   the last WINDOW seconds of the log that concern me (hits, misses,
--     heals, debuffs), copied at each new low point: the run-up to it
--   my health in percent over the fight (where the game doesn't keep it
--     secret: Forever, in a fight), its lowest point
--   my casts (UNIT_SPELLCAST_SUCCEEDED: Forever too)
--   what was ready when my health first fell below half (ns.readyTools,
--     Tools.lua), and at the end what of it went unused (ns.unusedOf)
-- A death takes the game's recap too (C_DeathRecap: every client), read a
-- moment after it. A duel (a fight against players only, while one was on)
-- and a battleground are no danger: never kept.
--
--   debriefs[i] = { kind = "close" | "death", at, length, zone, sub, level,
--     grouped, hardcore, startPct, lowPct, lowT, env, ready, readyT, unused
--     (tools: Tools.lua), killer = { name, spell,
--     amount, overkill }, foes = { { name, npc, first, hits, misses, damage,
--     level, rank, type, player } }, heals = { { name, amount } }, casts = {
--     { t, id, name } }, events = { { t, k, src, spell, id,
--     amount, over, crit, school, what } }, samples = { { t, pct } }, recap =
--     { { t, amount, overkill, hp, src, school, spell } } }
--   (times t: seconds from the fight's start, or before the death for the
--   recap; k: hit, miss, heal, debuff)
local _, ns = ...

local WINDOW = 20 -- seconds of the log kept before a low point
local QUIET = 3 -- seconds without harm that end a fight out of combat
local KEEP = 100 -- debriefs kept per character (a death always)
local SAMPLES = 60 -- health points kept per debrief
local ROWS = 60 -- log rows kept per debrief
local READY_BELOW = 50 -- health (percent) at which what was ready is noted
local DUEL_FORGET = 180 -- seconds after which a duel never finished is forgotten

local fight, buffer = nil, {}
local duelAt -- when a duel was asked for or offered (GetTime), until it ends

local function round(x) return x and math.floor(x + 0.5) or nil end
local function tenth(x) return x and math.floor(x * 10 + 0.5) / 10 or nil end

-- My health in percent; nil where the game keeps it secret (Forever, in a fight).
local function pct()
  local h, max = UnitHealth("player"), UnitHealthMax("player")
  if ns.secret(h) or ns.secret(max) or not max or max == 0 then return nil end
  return h / max * 100
end

local function pvp()
  local inside, kind = IsInInstance()
  return inside and (kind == "pvp" or kind == "arena")
end

local function spellName(id)
  if not id or ns.secret(id) then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- ── a fight ──────────────────────────────────────────────────────────────────
local function sample(f, p)
  local t = GetTime() - f.t0
  local last = f.samples[#f.samples]
  if last and last.t == tenth(t) then
    last.pct = math.min(last.pct, round(p))
  else
    table.insert(f.samples, { t = tenth(t), pct = round(p) })
  end
end

local function begin()
  if fight or UnitIsDeadOrGhost("player") or pvp() then return fight end
  local zone, sub = GetRealZoneText(), GetSubZoneText()
  local p = pct()
  fight = {
    t0 = GetTime(),
    at = time(),
    zone = zone,
    sub = sub ~= "" and sub ~= zone and sub or nil,
    level = UnitLevel("player"),
    grouped = IsInGroup and IsInGroup() or nil,
    startPct = p,
    low = p,
    lowT = p and 0 or nil,
    foes = {},
    order = {},
    heals = {},
    casts = {},
    samples = {},
    last = GetTime(),
    duelOn = duelAt and GetTime() - duelAt < DUEL_FORGET or nil,
  }
  buffer = {}
  if p then sample(fight, p) end
  if p and p < READY_BELOW then
    fight.readyT, fight.ready = 0, ns.readyTools and ns.readyTools() or nil
  end
  return fight
end

-- A foe, the first time it touches me: what the game can tell of it.
local function foeOf(f, guid, name)
  local foe = f.foes[guid]
  if foe then return foe end
  foe = { name = name, first = tenth(GetTime() - f.t0), hits = 0, misses = 0, damage = 0 }
  if guid:find("^Player") then
    foe.player = true
  else
    foe.npc = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
  end
  local token = UnitTokenFromGUID and UnitTokenFromGUID(guid)
  if token and not ns.secret(token) then
    local level, rank, kind = UnitLevel(token), UnitClassification(token), UnitCreatureType(token)
    if not ns.secret(level) then foe.level = level end
    if not ns.secret(rank) and rank ~= "normal" then foe.rank = rank end
    if not ns.secret(kind) then foe.type = kind end
  end
  f.foes[guid] = foe
  table.insert(f.order, guid)
  return foe
end

-- A line of the log that concerns me, kept for WINDOW seconds.
local function keep(row)
  local t = GetTime()
  row.t = tenth(t - fight.t0)
  row.at = t
  table.insert(buffer, row)
  while buffer[1] and buffer[1].at < t - WINDOW do
    table.remove(buffer, 1)
  end
end

local function copy(rows)
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = r
  end
  return out
end

-- My health changed: a sample, perhaps a new low (the run-up kept), perhaps
-- below half for the first time (what was ready noted).
local function health()
  local f = fight
  local p = pct()
  if not f or not p then return end
  sample(f, p)
  if not f.low or p < f.low then
    f.low, f.lowT = p, tenth(GetTime() - f.t0)
    f.window = copy(buffer)
  end
  if p < READY_BELOW and f.readyT == nil then
    f.readyT = tenth(GetTime() - f.t0)
    f.ready = ns.readyTools and ns.readyTools() or nil
  end
end

-- ── the debrief ──────────────────────────────────────────────────────────────
local function thin(samples)
  if #samples <= SAMPLES then return samples end
  -- in SAMPLES buckets, each one's lowest point (the fight's low is kept)
  local out, size = {}, #samples / SAMPLES
  for b = 0, SAMPLES - 1 do
    local low
    for i = math.floor(b * size) + 1, math.min(#samples, math.floor((b + 1) * size)) do
      if not low or samples[i].pct < low.pct then low = samples[i] end
    end
    if low then table.insert(out, low) end
  end
  return out
end

local function rows(list)
  local out = {}
  for i = math.max(1, #list - ROWS + 1), #list do
    local r = {}
    for k, v in pairs(list[i]) do
      if k ~= "at" then r[k] = v end
    end
    table.insert(out, r)
  end
  return out
end

local function lastHit(list)
  for i = #list, 1, -1 do
    local r = list[i]
    if r.k == "hit" then return { name = r.src, spell = r.spell, amount = r.amount, overkill = r.over } end
  end
end

local function written(f, death)
  local foes = {}
  for _, guid in ipairs(f.order) do
    table.insert(foes, f.foes[guid])
  end
  local heals = {}
  for name, amount in pairs(f.heals) do
    if amount > 0 then table.insert(heals, { name = name, amount = amount }) end
  end
  table.sort(heals, function(a, b) return a.amount > b.amount end)
  local hardcore = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or nil
  return {
    kind = death and "death" or "close",
    at = time(),
    length = round(GetTime() - f.t0),
    zone = f.zone,
    sub = f.sub,
    level = f.level,
    grouped = f.grouped,
    hardcore = hardcore and true or nil,
    startPct = round(f.startPct),
    lowPct = death and 0 or round(f.low),
    lowT = death and tenth(GetTime() - f.t0) or f.lowT,
    env = f.env,
    killer = death and lastHit(buffer) or nil,
    foes = foes,
    heals = heals,
    casts = f.casts,
    ready = f.ready,
    readyT = f.readyT,
    unused = ns.unusedOf and ns.unusedOf(f.ready, f.casts, f.readyT) or nil,
    events = rows(death and buffer or f.window or buffer),
    samples = thin(f.samples),
  }
end

-- Kept, the oldest close call going first past KEEP (a death stays).
local function store(d)
  local list = ns.record().debriefs
  table.insert(list, d)
  local over = #list - KEEP
  local i = 1
  while over > 0 and i <= #list do
    if list[i].kind ~= "death" then
      table.remove(list, i)
      over = over - 1
    else
      i = i + 1
    end
  end
end

-- The game's recap of a death (every client): what killed me, from it where
-- the combat log gave nothing (Forever).
local function recapOf(d)
  if not (C_DeathRecap and C_DeathRecap.HasRecapEvents and C_DeathRecap.HasRecapEvents()) then return end
  local events = C_DeathRecap.GetRecapEvents() or {}
  local max = C_DeathRecap.GetRecapMaxHealth and C_DeathRecap.GetRecapMaxHealth() or nil
  local last = events[1] and events[1].timestamp or 0
  local recap = {}
  for _, e in ipairs(events) do
    local hp = e.currentHP and max and max > 0 and not ns.secret(e.currentHP) and round(e.currentHP / max * 100) or nil
    table.insert(recap, {
      t = tenth(last - (e.timestamp or last)),
      amount = e.amount,
      overkill = e.overkill,
      hp = hp,
      src = not e.hideCaster and e.sourceName or nil,
      school = e.school,
      spell = spellName(e.spellId),
    })
  end
  d.recap = recap
  if not d.killer and recap[1] then
    d.killer = { name = recap[1].src, spell = recap[1].spell, amount = recap[1].amount, overkill = recap[1].overkill }
  end
  if #d.foes == 0 then
    local byName = {}
    for i = #recap, 1, -1 do
      local src = recap[i].src
      if src then
        local foe = byName[src]
        if not foe then
          foe = { name = src, hits = 0, damage = 0 }
          byName[src] = foe
          table.insert(d.foes, foe)
        end
        foe.hits, foe.damage = foe.hits + 1, foe.damage + (recap[i].amount or 0)
      end
    end
  end
  if ns.refresh then ns.refresh() end
end

-- The fight is over: a debrief if it was a close call, or a death.
-- (a duel: one was on when it began, and only players touched me)
local function duel(f)
  if not f.duelOn or #f.order == 0 then return false end
  for _, guid in ipairs(f.order) do
    if not f.foes[guid].player then return false end
  end
  return true
end

local function finish(death)
  local f = fight
  fight = nil
  if not f or (not death and duel(f)) then return end
  if not death and not (f.low and f.low < ns.option("threshold")) then return end
  local d = written(f, death)
  store(d)
  if death then C_Timer.After(1, function() recapOf(d) end) end
  if ns.debriefed then ns.debriefed(d) end
  if ns.refresh then ns.refresh() end
end

-- Out of combat (a fall, the water): over after QUIET seconds without harm.
local function quietly(f)
  C_Timer.After(QUIET, function()
    if fight == f and not UnitAffectingCombat("player") and GetTime() - f.last >= QUIET - 0.01 then finish() end
  end)
end

local function harmed(f)
  f.last = GetTime()
  if not UnitAffectingCombat("player") then quietly(f) end
end

-- ── the combat log (Classic) ─────────────────────────────────────────────────
local HIT = { SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }
local MISS = { SWING_MISSED = true, RANGE_MISSED = true, SPELL_MISSED = true, SPELL_PERIODIC_MISSED = true }
local HEAL = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function logged()
  local _, sub, _, source, sourceName, _, _, dest, _, _, _, a1, a2, a3, a4, a5, _, _, a8, _, a10 =
    CombatLogGetCurrentEventInfo()
  local me = UnitGUID("player")
  if dest ~= me then return end
  if HIT[sub] or sub == "ENVIRONMENTAL_DAMAGE" then
    local f = fight or begin()
    if not f then return end
    local row = { k = "hit" }
    if sub == "ENVIRONMENTAL_DAMAGE" then
      row.what, row.amount, row.over, row.school, row.crit = a1, a2, a3, a4, a8 or nil
      f.env = f.env or a1
    else
      if sub == "SWING_DAMAGE" then
        row.amount, row.over, row.school, row.crit = a1, a2, a3, select(18, CombatLogGetCurrentEventInfo())
      else
        row.id, row.spell, row.school, row.amount, row.over, row.crit = a1, a2, a3, a4, a5, a10
      end
      row.src = sourceName
      if source then
        local foe = foeOf(f, source, sourceName)
        foe.hits, foe.damage = foe.hits + 1, foe.damage + (row.amount or 0)
      end
    end
    if not row.over or row.over <= 0 then row.over = nil end
    row.crit = row.crit or nil
    keep(row)
    harmed(f)
  elseif MISS[sub] then
    local f = fight
    if not f then return end
    local row = { k = "miss", src = sourceName }
    if sub == "SWING_MISSED" then
      row.what = a1
    else
      row.id, row.spell, row.what = a1, a2, a4
    end
    if source then
      local foe = foeOf(f, source, sourceName)
      foe.misses = foe.misses + 1
    end
    keep(row)
  elseif HEAL[sub] then
    local f = fight
    if not f then return end
    local name = source == me and "you" or sourceName or "?"
    local over = a5 and a5 > 0 and a5 or nil
    keep({ k = "heal", src = name, id = a1, spell = a2, amount = a4, over = over })
    f.heals[name] = (f.heals[name] or 0) + (a4 or 0) - (over or 0)
  elseif sub == "SPELL_AURA_APPLIED" and a4 == "DEBUFF" then
    local f = fight
    if f and source ~= me then keep({ k = "debuff", src = sourceName, id = a1, spell = a2 }) end
  end
end

-- ── the events ───────────────────────────────────────────────────────────────
ns.on("PLAYER_REGEN_DISABLED", begin)
-- (the end of combat may come before the death that ended it: a moment's
-- wait, and a death in it is the fight's end instead)
local SETTLE = 0.3
ns.on("PLAYER_REGEN_ENABLED", function()
  local f = fight
  if not f then return end
  C_Timer.After(SETTLE, function()
    if fight == f and not UnitIsDeadOrGhost("player") then finish() end
  end)
end)
ns.on("PLAYER_DEAD", function()
  local f = fight or begin()
  if f then
    f.low = 0
    finish(true)
  end
end)
ns.onUnit("UNIT_HEALTH", "player", health)
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, id)
  local f = fight
  if not f or ns.secret(id) then return end
  table.insert(f.casts, { t = tenth(GetTime() - f.t0), id = id, name = spellName(id) })
end)
if not ns.forever then ns.on("COMBAT_LOG_EVENT_UNFILTERED", logged) end

-- Duels: asked for, offered, over (a fight that began while one was on,
-- against players only, is a duel).
ns.on("DUEL_REQUESTED", function() duelAt = GetTime() end)
ns.on("DUEL_FINISHED", function() duelAt = nil end)
if StartDuel then hooksecurefunc("StartDuel", function() duelAt = GetTime() end) end
-- A debrief in a line: when, where, how low or dead, the foes.
function ns.summaryOf(d)
  local names = {}
  for i, foe in ipairs(d.foes or {}) do
    if i > 3 then
      table.insert(names, ("%d more"):format(#d.foes - 3))
      break
    end
    table.insert(names, foe.name)
  end
  local place = d.sub and (d.sub .. ", " .. d.zone) or d.zone or "?"
  local what = d.kind == "death" and "Death" or ("Close call, %d%%"):format(d.lowPct or 0)
  local by = #names > 0 and (" (" .. table.concat(names, ", ") .. ")") or (d.env and (" (" .. d.env .. ")") or "")
  return ("%s in %s%s"):format(what, place, by)
end
