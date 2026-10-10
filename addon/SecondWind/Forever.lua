-- What a client without the combat log lets an addon read of a fight (Forever,
-- whose combat log is closed to addons and whose health and casts may be
-- secret in a fight): the game's damage meter (C_DamageMeter, readable once
-- the fight is over: SecretWhenInCombat), for the foes and the harm by spell;
-- and /wind probe, which says what the game let it read in the next fight.
-- Every client has the meter; the debriefs ask it only on Forever, where the
-- combat log tells nothing (the probe asks it everywhere).
local _, ns = ...

local DAMAGE_TAKEN = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageTaken or 7
local CURRENT = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
local SPELLS_KEPT = 5

local function clear(v) return v ~= nil and not ns.secret(v) end
local function spellName(id)
  if not clear(id) then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- The meter's account of my damage taken in the last fight, by spell (the
-- largest first): { spell, src, amount, overkill, deadly, avoidable, rank },
-- or nil (no meter, not available, nothing readable).
local function source()
  local me = UnitGUID("player")
  local ok, s = pcall(C_DamageMeter.GetCombatSessionSourceFromType, CURRENT, DAMAGE_TAKEN, me)
  if ok and s and clear(s.combatSpells) and #s.combatSpells > 0 then return s end
  -- (the fight over, its session may be the last one kept)
  local okList, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
  local last = okList and clear(list) and list[#list]
  if not (last and clear(last.sessionID)) then return nil end
  ok, s = pcall(C_DamageMeter.GetCombatSessionSourceFromID, last.sessionID, DAMAGE_TAKEN, me)
  return ok and s or nil
end

function ns.meterTaken()
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType) then return nil end
  local ok, available, why = pcall(C_DamageMeter.IsDamageMeterAvailable)
  if not ok or not available then return nil, ok and why or nil end
  local s = source()
  if not (s and clear(s.combatSpells)) then return nil end
  local out = {}
  for _, sp in ipairs(s.combatSpells) do
    if clear(sp.totalAmount) and sp.totalAmount > 0 then
      local details = clear(sp.combatSpellDetails) and sp.combatSpellDetails or {}
      local who = clear(details.unitName) and details.unitName or (clear(sp.creatureName) and sp.creatureName) or nil
      local rank = clear(details.classification) and details.classification ~= "normal" and details.classification
        or nil
      table.insert(out, {
        spell = spellName(sp.spellID),
        src = who ~= "" and who or nil,
        amount = sp.totalAmount,
        overkill = clear(sp.overkillAmount) and sp.overkillAmount > 0 and sp.overkillAmount or nil,
        deadly = clear(sp.isDeadly) and sp.isDeadly or nil,
        avoidable = clear(sp.isAvoidable) and sp.isAvoidable or nil,
        rank = rank ~= "" and rank or nil,
      })
    end
  end
  table.sort(out, function(a, b) return a.amount > b.amount end)
  return out
end

-- A debrief the combat log told nothing of (Forever): the meter's foes, and
-- the harm by spell. Never where the log told it, nor for harm from the
-- world (no combat: the meter's last session is an older fight's).
function ns.meterFill(d)
  if not ns.forever or d.env then return end
  local taken = ns.meterTaken()
  if not taken or #taken == 0 then return end
  d.spells = {}
  for i = 1, math.min(SPELLS_KEPT, #taken) do
    d.spells[i] = taken[i]
  end
  if #(d.foes or {}) > 0 then return end
  local byName = {}
  d.foes = {}
  for _, sp in ipairs(taken) do
    if sp.src then
      local foe = byName[sp.src]
      if not foe then
        foe = { name = sp.src, hits = 0, damage = 0, rank = sp.rank }
        byName[sp.src] = foe
        table.insert(d.foes, foe)
      end
      foe.damage = foe.damage + sp.amount
    end
  end
end

-- ── /wind probe ──────────────────────────────────────────────────────────────
-- Armed, it watches the next fight and says, once it is over, what the game
-- let an addon read: the combat log, my health and my casts in the fight, the
-- notice before combat's restrictions, the damage meter.
local probe

function ns.probeArm()
  probe = { armed = true, log = 0 }
  print(ns.PREFIX .. "the probe is armed: the next fight is watched. Fight anything, then read the report here.")
end

local function report()
  local p = probe
  probe = nil
  local function said(v, yes, no) return v and yes or no end
  local taken, why = ns.meterTaken()
  local lines = {
    "the combat log: " .. (ns.forever and "closed (Forever)" or ("%d lines heard"):format(p.log)),
    "your health in the fight: " .. (p.healthSecret and "hidden" or said(p.healthRead, "readable", "no change seen")),
    "your casts in the fight: " .. (p.castSecret and "hidden" or said(p.castRead, "readable", "none cast")),
    "the notice before combat's restrictions: " .. said(p.notice, "seen", "not seen"),
    "the damage meter: "
      .. (
        taken and ("%d of the spells that hit you read"):format(#taken)
        or ("nothing read" .. (why and why ~= "" and (" (" .. why .. ")") or ""))
      ),
  }
  print(ns.PREFIX .. "the probe's report:")
  for _, l in ipairs(lines) do
    print("  " .. l)
  end
end

ns.on("ADDON_RESTRICTION_STATE_CHANGED", function()
  if probe then probe.notice = true end
end)
ns.onUnit("UNIT_HEALTH", "player", function()
  if not (probe and probe.inFight) then return end
  if ns.secret(UnitHealth("player")) then
    probe.healthSecret = true
  else
    probe.healthRead = true
  end
end)
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, id)
  if not (probe and probe.inFight) then return end
  if ns.secret(id) then
    probe.castSecret = true
  else
    probe.castRead = true
  end
end)
if not ns.forever then
  ns.on("COMBAT_LOG_EVENT_UNFILTERED", function()
    if probe and probe.inFight then probe.log = probe.log + 1 end
  end)
end
ns.on("PLAYER_REGEN_DISABLED", function()
  if probe then probe.inFight = true end
end)
ns.on("PLAYER_REGEN_ENABLED", function()
  if probe and probe.inFight then C_Timer.After(0.5, function()
    if probe then report() end
  end) end
end)
