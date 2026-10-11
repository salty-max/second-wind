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
--   the stretches I had lost control (stunned, feared, charmed...): the
--     game's own account where it gives it (C_LossOfControl: what, by which
--     spell), else only that I had (HasFullControl, readable on Forever too)
--   the longest stretch without harm once my health fell below half (time
--     for a bandage, or not)
--   what was ready when my health first fell below half (ns.readyTools,
--     Tools.lua), and at the end what of it went unused (ns.unusedOf)
-- A death takes the game's recap too (C_DeathRecap: every client), read a
-- moment after it. A duel (a fight against players only, while one was on)
-- and a battleground are no danger: never kept.
--
--   debriefs[i] = { kind = "close" | "death", at, length, zone, sub, level,
--     maxHealth, grouped, hardcore, startPct, lowPct, lowT, env, ready, readyT,
--     readyFrom ("start": what was ready as the fight began, my health being
--     hidden), unused, blind (my health hidden in the fight: Forever),
--     lowAtEnd (its low point read at its end), spells (Forever.lua),
--     held = { { t, to, what, spell } } (control lost: what as the game
--     says it, "Stunned"; none where it only said I had lost control),
--     traced (Forever: what went unused told by what a use leaves behind,
--     Tools.lua's ns.tracesOf), untold (the tools whose use leaves none),
--     warned (Forever: when the game's low-health warning showed), below
--     (Forever: the close call is that warning's, below this percent)
-- Forever keeps my health from addons, in a fight and out of it (UnitHealth:
-- SecretReturns, documented as unconditional): no low point is read; the
-- game's own low-health warning (LowHealthFrame, shown by Blizzard's code
-- below 35% from my true health) stands for a close call, where an addon
-- sees it shown. The death recap, my casts and control lost (the player's
-- own: never secret) are read as on Classic.
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
local WARNING = 35 -- percent: where the game's low-health warning shows
local DUEL_FORGET = 180 -- seconds after which a duel never finished is forgotten

local fight, buffer = nil, {}
local lastPct, lastAt -- my health when last readable (Forever hides it in a fight)
local KNOWN_FOR = 10 -- seconds a last readable health stands for the start
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
  local p = pct() or (lastAt and GetTime() - lastAt < KNOWN_FOR and lastPct) or nil
  fight = {
    t0 = GetTime(),
    at = time(),
    zone = zone,
    sub = sub ~= "" and sub ~= zone and sub or nil,
    level = UnitLevel("player"),
    max = UnitHealthMax("player"),
    grouped = IsInGroup and IsInGroup() or nil,
    startPct = p,
    low = p,
    lowT = p and 0 or nil,
    blind = not pct() or nil,
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
  -- (Forever hides my health in a fight: what was ready at its start stands
  -- for what was ready below half, should it never be seen)
  if ns.forever and ns.readyTools then fight.startReady = ns.readyTools() end
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

-- ── control lost ─────────────────────────────────────────────────────────────
-- Stunned, feared, asleep, charmed...: nothing could be used then (the game's
-- kinds of it, as its LOSS_OF_CONTROL events name them). Read at each harm,
-- each change of my health and each of the game's notices, kept as stretches.
local HELD = {
  STUN = true,
  STUN_MECHANIC = true,
  FEAR = true,
  FEAR_MECHANIC = true,
  CONFUSE = true,
  SLEEP = true,
  CHARM = true,
  POSSESS = true,
}

-- The game's account of it, where it gives one: { what, spell, left }.
local function lossOfControl()
  local L = C_LossOfControl
  if not (L and L.GetActiveLossOfControlDataCountByUnit and L.GetActiveLossOfControlDataByUnit) then return nil end
  local n = L.GetActiveLossOfControlDataCountByUnit("player")
  if not n or ns.secret(n) then return nil end
  for i = 1, n do
    local e = L.GetActiveLossOfControlDataByUnit("player", i)
    if e and not ns.secret(e.locType) and HELD[e.locType] then
      local left = e.timeRemaining
      return {
        what = not ns.secret(e.displayText) and e.displayText or nil,
        spell = spellName(e.spellID),
        left = left and not ns.secret(left) and left or nil,
      }
    end
  end
end

local function control(f)
  local now = tenth(GetTime() - f.t0)
  local told = lossOfControl()
  local full = HasFullControl and HasFullControl()
  if ns.secret(full) then full = nil end
  local open = f.held and f.held[#f.held]
  if open and open.to then open = nil end
  if told or full == false then
    if not open then
      open = { t = now }
      f.held = f.held or {}
      table.insert(f.held, open)
    end
    if told then
      open.what, open.spell = open.what or told.what, open.spell or told.spell
      if told.left then open.ends = tenth(now + told.left) end
    end
  elseif open then
    -- (back in control: when the game said it would end, if it said)
    open.to = open.ends and math.min(now, open.ends) or now
    open.ends = nil
  end
end

-- My health changed: a sample, perhaps a new low (the run-up kept), perhaps
-- below half for the first time (what was ready noted).
-- The game's low-health warning seen, in a fight (not the full screen's:
-- the same frame shows over a full-screen panel in a fight).
local function warned()
  local f = fight
  if not f or f.warned or UnitIsDeadOrGhost("player") then return end
  if GetUIPanel and GetUIPanel("fullscreen") then return end
  f.warned = tenth(GetTime() - f.t0)
end
if LowHealthFrame and LowHealthFrame.Show then hooksecurefunc(LowHealthFrame, "Show", warned) end

local function health()
  local f = fight
  if ns.secret(UnitHealth("player")) then
    if f then
      f.blind = true
      -- (shown before this fight began: its Show isn't called again)
      local shown = LowHealthFrame and LowHealthFrame:IsShown()
      if shown and not ns.secret(shown) then warned() end
    end
    return
  end
  local p = pct()
  if p and not f then
    lastPct, lastAt = p, GetTime()
  end
  if not f or not p then return end
  control(f)
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

-- What of the tools ready went unused: my casts told it, or what a use leaves
-- behind (Forever); a tool whose use leaves no trace is never called unused.
local function unusedOf(f)
  if (f.castsHidden and not f.traced) or not ns.unusedOf then return nil end
  local unused = ns.unusedOf(f.ready, f.casts, f.readyT)
  if not unused or not f.untold then return unused end
  local silent = {}
  for _, n in ipairs(f.untold) do
    silent[n] = true
  end
  local out = {}
  for _, t in ipairs(unused) do
    if not silent[t.n] then table.insert(out, t) end
  end
  return out
end

-- Every fight, kept or not, counted by its traits (Debrief.lua's
-- ns.traitsOf): what the close calls share, against what any fight has.
local function tally(d)
  local record = ns.record()
  if not (record and ns.traitsOf) then return end
  local fights = record.fights or { n = 0, since = d.at, traits = {} }
  record.fights = fights
  fights.n = fights.n + 1
  for key in pairs(ns.traitsOf(d)) do
    fights.traits[key] = (fights.traits[key] or 0) + 1
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
    maxHealth = not ns.secret(f.max) and f.max or nil,
    grouped = f.grouped,
    hardcore = hardcore and true or nil,
    startPct = round(f.startPct),
    lowPct = death and 0 or round(f.low),
    lowT = death and tenth(GetTime() - f.t0) or f.lowT or (f.below and f.warned) or nil,
    warned = f.warned,
    below = not death and f.below or nil,
    blind = f.blind or nil,
    castsHidden = f.castsHidden or nil,
    lowAtEnd = not death and f.lowAtEnd or nil,
    env = f.env,
    killer = death and lastHit(buffer) or nil,
    foes = foes,
    heals = heals,
    casts = f.casts,
    ready = f.ready,
    readyT = f.readyT,
    readyFrom = f.readyFrom,
    held = f.held,
    -- (my casts hidden: no telling what went unused)
    unused = unusedOf(f),
    traced = f.traced,
    untold = f.untold and #f.untold > 0 and f.untold or nil,
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
  -- (the damage meter, hidden at the death (still in combat), read now)
  if ns.meterFill then ns.meterFill(d) end
  if ns.refresh then ns.refresh() end
end

-- The fight is over: a debrief if it was a close call, or a death.
-- (a duel: one was on when it began, and only players touched me; with no
-- combat log to tell who did, a duel on is enough)
local function duel(f)
  if not f.duelOn then return false end
  if #f.order == 0 then return not f.env end
  for _, guid in ipairs(f.order) do
    if not f.foes[guid].player then return false end
  end
  return true
end

local function finish(death)
  local f = fight
  fight = nil
  if not f or (not death and duel(f)) then return end
  -- my health hidden in the fight (Forever): its end, readable again, stands
  -- for its low point; what was ready at its start for what was below half
  if f.blind and not death then
    local p = pct()
    if p and (not f.low or p < f.low) then
      f.low, f.lowAtEnd, f.lowT = p, true, tenth(GetTime() - f.t0)
    end
  end
  if f.blind and not f.ready and f.startReady then
    f.ready, f.readyT, f.readyFrom = f.startReady, 0, "start"
  end
  -- (still held at the end: until the end, or when the game said it would end)
  local open = f.held and f.held[#f.held]
  if open and not open.to then
    local now = tenth(GetTime() - f.t0)
    open.to, open.ends = open.ends and math.min(now, open.ends) or now, nil
  end
  -- (the stretch without harm at the end counts while combat was still on;
  -- harm from the world alone: no time for a bandage)
  if f.harmed and f.readyT and f.ended then
    f.lull = math.max(f.lull or 0, f.ended - math.max(f.last, f.t0 + f.readyT))
  end
  if f.env and #f.order == 0 then f.lull = 0 end
  -- (what was ready that counted here: no fire protection against wolves, no
  -- bandage without time to use one)
  if f.ready and ns.relevantTools then
    f.ready = ns.relevantTools(f.ready, { schools = f.schools, env = f.env, lull = f.lull })
  end
  -- (Forever: what a use leaves behind, read now: what my casts didn't tell,
  -- should the game hide them; a use with no trace is untold only then)
  if ns.forever and f.ready and ns.tracesOf then
    local casts, untold = ns.tracesOf(f.ready, f.t0)
    local seen = {}
    for _, c in ipairs(f.casts) do
      if c.name then seen[c.name] = true end
      if c.id then seen[c.id] = true end
    end
    for _, c in ipairs(casts) do
      if not seen[c.name or c.id] then table.insert(f.casts, c) end
    end
    f.traced, f.untold = true, f.castsHidden and untold or nil
  end
  -- (Forever: no low point to read; the game's warning stands for one)
  if f.blind and not death and not f.low and f.warned then f.below = WARNING end
  local d = written(f, death)
  -- (Forever: the foes from the meter, for the tally too)
  if ns.meterFill then ns.meterFill(d) end
  tally(d)
  if not death and not (f.low and f.low < ns.option("threshold")) and not f.below then return end
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
  local now = GetTime()
  -- (the longest stretch without harm since my health fell below half)
  if f.readyT then f.lull = math.max(f.lull or 0, now - math.max(f.last, f.t0 + f.readyT)) end
  f.last, f.harmed = now, true
  control(f)
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
    if row.school and row.school ~= 1 then
      f.schools = f.schools or {}
      f.schools[row.school] = true
    end
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
-- (Forever: told just before combat's restrictions begin, while my health and
-- cooldowns can still be read: the fight begins there)
local COMBAT = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat or 0
local ACTIVATING = Enum and Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Activating or 1
ns.on("ADDON_RESTRICTION_STATE_CHANGED", function(kind, state)
  if kind == COMBAT and state == ACTIVATING then begin() end
end)
-- (the end of combat may come before the death that ended it: a moment's
-- wait, and a death in it is the fight's end instead)
local SETTLE = 0.3
ns.on("PLAYER_REGEN_ENABLED", function()
  local f = fight
  if not f then return end
  f.ended = GetTime()
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
-- (control lost or back: the game's notices)
for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" }) do
  ns.on(e, function()
    if fight then control(fight) end
  end)
end
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, id)
  local f = fight
  if not f then return end
  if ns.secret(id) then
    f.castsHidden = true
    return
  end
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
  local what = d.kind == "death" and "Death" or ("Close call, %s"):format(ns.lowOf and ns.lowOf(d) or "?")
  local by = #names > 0 and (" (" .. table.concat(names, ", ") .. ")") or (d.env and (" (" .. d.env .. ")") or "")
  return ("%s in %s%s"):format(what, place, by)
end
