-- What a client without the combat log lets an addon read of a fight (Forever,
-- whose combat log is closed to addons and whose health and casts may be
-- secret in a fight): the game's damage meter (C_DamageMeter, readable once
-- the fight is over: SecretWhenInCombat), for the foes and the harm by spell;
-- and /wind probe, which says what the game let it read in the next fight.
-- Every client has the meter; the debriefs ask it only on Forever, where the
-- combat log tells nothing (the probe asks it everywhere).
local _, ns = ...

local DAMAGE_TAKEN = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageTaken or 7
local HEALING_DONE = Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone or 2
local CURRENT = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
local SPELLS_KEPT = 5

local function clear(v) return v ~= nil and not ns.secret(v) end
local function spellName(id)
  if not clear(id) then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- My own line of the meter in the last fight, of a kind (damage taken,
-- healing done), or nil.
local function source(kind)
  local me = UnitGUID("player")
  local ok, s = pcall(C_DamageMeter.GetCombatSessionSourceFromType, CURRENT, kind, me)
  if ok and s and clear(s.combatSpells) and #s.combatSpells > 0 then return s end
  -- (the fight over, its session may be the last one kept)
  local okList, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
  local last = okList and clear(list) and list[#list]
  if not (last and clear(last.sessionID)) then return nil end
  ok, s = pcall(C_DamageMeter.GetCombatSessionSourceFromID, last.sessionID, kind, me)
  return ok and s or nil
end

-- The meter's account of my damage taken in the last fight, by spell (the
-- largest first): { spell, src, amount, overkill, deadly, avoidable, rank },
-- or nil (no meter, not available, nothing readable).

function ns.meterTaken()
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType) then return nil end
  local ok, available, why = pcall(C_DamageMeter.IsDamageMeterAvailable)
  if not ok or not available then return nil, ok and why or nil end
  local s = source(DAMAGE_TAKEN)
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
        id = clear(sp.spellID) and sp.spellID or nil,
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
-- notice before combat's restrictions, the damage meter (the harm, marked
-- avoidable or not; my healing, and whom its spells name), losing control (a
-- stun, a fear: the game's account of it, or only that I had), the game's own
-- low-health warning (shown at 35% by Blizzard's code from my true health:
-- whether an addon may see it in a fight, my health hidden). Each report is
-- kept with what it was drawn from (each hit and heal as UNIT_COMBAT gave it, each
-- cast, each loss of control, the warning's moment, the meter's spells; a
-- secret value as the word "secret") in SecondWindSettings.probes, the
-- account's saved file, written at /reload or logout: the last KEPT.
local probe
local KEPT, ROWS = 10, 80

-- A row of what the probe saw, its time from the fight's start.
local function noted(kind, row)
  if not (probe and probe.inFight) or #probe.rows >= ROWS then return end
  row.t = math.floor((GetTime() - (probe.t0 or GetTime())) * 10 + 0.5) / 10
  row.k = kind
  table.insert(probe.rows, row)
end
local function plain(v)
  if v == nil then return nil end
  if ns.secret(v) then return "secret" end
  return v
end

-- My healing in the last fight by the meter, and the names its spells give.
local function healingRead()
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType) then return nil end
  local s = source(HEALING_DONE)
  if not (s and clear(s.combatSpells)) then return nil end
  local total, names, seen = 0, {}, {}
  for _, sp in ipairs(s.combatSpells) do
    if clear(sp.totalAmount) then total = total + sp.totalAmount end
    local details = clear(sp.combatSpellDetails) and sp.combatSpellDetails or {}
    local who = clear(details.unitName) and details.unitName or nil
    if who and who ~= "" and not seen[who] then
      seen[who] = true
      table.insert(names, who)
    end
  end
  return total, names
end

function ns.probeArm()
  probe = {
    armed = true,
    log = 0,
    combat = 0,
    combatSecret = 0,
    rows = {},
    healthBefore = ns.secret(UnitHealth("player")) and "hidden" or "readable",
  }
  print(ns.PREFIX .. "the probe is armed: the next fight is watched. Fight anything, then read the report here.")
end

-- My health through the heal-prediction calculator (Forever's), read back
-- out of a fight: "readable", "hidden", or nil where the client has none.
local function calculated()
  if not (CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then return nil end
  local ok, h = pcall(function()
    local calc = CreateUnitHealPredictionCalculator()
    UnitGetDetailedHealPrediction("player", nil, calc)
    return calc:GetCurrentHealth()
  end)
  if not ok then return "refused" end
  return ns.secret(h) and "hidden" or "readable"
end

local function report()
  local p = probe
  probe = nil
  local function said(v, yes, no) return v and yes or no end
  local taken, why = ns.meterTaken()
  local avoidable = 0
  for _, t in ipairs(taken or {}) do
    if t.avoidable then avoidable = avoidable + 1 end
  end
  local healed, on = healingRead()
  local lines = {
    "the combat log: " .. (ns.forever and "closed (Forever)" or ("%d lines heard"):format(p.log)),
    "your health in the fight: " .. (p.healthSecret and "hidden" or said(p.healthRead, "readable", "no change seen")),
    "your health out of a fight: " .. (ns.secret(UnitHealth("player")) and "hidden" or "readable"),
    "your casts in the fight: " .. (p.castSecret and "hidden" or said(p.castRead, "readable", "none cast")),
    "the notice before combat's restrictions: " .. said(p.notice, "seen", "not seen"),
    "losing control: "
      .. (
        p.loc and ("told by the game (%s)"):format(p.loc)
        or p.locSecret and "its account hidden" .. said(p.lost, ", but you had lost it", "")
        or p.lost and "only that you had lost it"
        or "not lost in this fight"
      ),
    "the damage meter: " .. (taken and ("%d of the spells that hit you read, %d marked avoidable"):format(
      #taken,
      avoidable
    ) or ("nothing read" .. (why and why ~= "" and (" (" .. why .. ")") or ""))),
    "the meter's healing: " .. (healed and ("yours %d%s"):format(
      healed,
      #on > 0 and (" (its spells name " .. table.concat(on, ", ") .. ")") or ""
    ) or "nothing read"),
    "the game's low-health warning (35%): "
      .. (
        GetCVarBool and GetCVarBool("doNotFlashLowHealthWarning") and "turned off in your settings"
        or said(p.lowWarn, "seen in the fight", "not seen (below 35% in the fight?)")
      ),
  }
  local build, number = GetBuildInfo()
  local restricted = C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions()
  table.insert(lines, 1, ("the game: %s.%s, secret values %s"):format(build, number, restricted and "on" or "off"))
  table.insert(
    lines,
    ("the hits on you (UNIT_COMBAT): %s"):format(
      p.combat == 0 and "none heard" or ("%d heard, %d with a hidden amount"):format(p.combat, p.combatSecret)
    )
  )
  local calc = calculated()
  if calc then table.insert(lines, "your health through the heal calculator: " .. calc) end
  print(ns.PREFIX .. "the probe's report:")
  for _, l in ipairs(lines) do
    print("  " .. l)
  end
  -- (kept, with what it was drawn from, in the account's saved file)
  if type(SecondWindSettings) == "table" then
    SecondWindSettings.probes = SecondWindSettings.probes or {}
    local kept = SecondWindSettings.probes
    table.insert(kept, {
      at = time(),
      date = date("%Y-%m-%d %H:%M"),
      build = ("%s.%s"):format(build, number),
      interface = select(4, GetBuildInfo()),
      healthBefore = p.healthBefore,
      lines = lines,
      rows = p.rows,
      meter = taken,
    })
    while #kept > KEPT do
      table.remove(kept, 1)
    end
    print(
      "  "
        .. "kept in SecondWind.lua, the account's saved file (WTF\\Account\\<account>\\SavedVariables), "
        .. "written at /reload or logout."
    )
  end
end

ns.on("ADDON_RESTRICTION_STATE_CHANGED", function()
  if probe then probe.notice = true end
end)
if LowHealthFrame and LowHealthFrame.Show then
  hooksecurefunc(LowHealthFrame, "Show", function()
    if probe and probe.inFight then
      if not probe.lowWarn then noted("warning", {}) end
      probe.lowWarn = true
    end
  end)
end
-- (control lost: whether the game says what, by which spell; each event noted)
local function controlSeen(event)
  if not (probe and probe.inFight) then return end
  if HasFullControl then
    local full = HasFullControl()
    if not ns.secret(full) and full == false then probe.lost = true end
  end
  local L = C_LossOfControl
  if not (L and L.GetActiveLossOfControlDataByUnit) then return end
  local e = L.GetActiveLossOfControlDataByUnit("player", 1)
  if not e or e.displayText == nil then return end
  noted("control", {
    event = event,
    what = plain(e.displayText),
    type = plain(e.locType),
    spell = plain(e.spellID),
    left = plain(e.timeRemaining),
  })
  if ns.secret(e.displayText) then
    probe.locSecret = true
  else
    probe.loc = e.displayText .. (spellName(e.spellID) and (", " .. spellName(e.spellID)) or "")
  end
end
for _, e in ipairs({ "PLAYER_CONTROL_LOST", "LOSS_OF_CONTROL_ADDED" }) do
  ns.on(e, function() controlSeen(e) end)
end
ns.onUnit("UNIT_COMBAT", "player", function(_, event, flag, amount, school)
  if not (probe and probe.inFight) then return end
  probe.combat = probe.combat + 1
  if ns.secret(amount) then probe.combatSecret = probe.combatSecret + 1 end
  noted("combat", { event = plain(event), flag = plain(flag), amount = plain(amount), school = plain(school) })
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
  noted("cast", { id = plain(id), name = not ns.secret(id) and spellName(id) or nil })
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
  if probe and not probe.inFight then
    probe.inFight, probe.t0 = true, GetTime()
  end
end)
ns.on("PLAYER_REGEN_ENABLED", function()
  if probe and probe.inFight then C_Timer.After(0.5, function()
    if probe then report() end
  end) end
end)
