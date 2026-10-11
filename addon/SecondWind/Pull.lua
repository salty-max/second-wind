-- The word before a pull: out of a fight, when I target a foe that matches
-- what my close calls share (Patterns.lua's counts: an elite, a foe two
-- levels or more above me, a foe met in two of them or more), or when I am
-- hurt and going in hurt is one of the things they share, a line in chat.
-- Facts and counts, never advice; never in a fight; a foe once, its name
-- not again for AGAIN seconds. Settings: "A word before a pull".
local _, ns = ...

local MIN = 3 -- debriefs before a word is said
local SHARE = 0.3 -- a trait in this share of them (and twice) counts
local AGAIN = 300 -- seconds before the same name is spoken of again
local HURT = 60 -- percent of my health: the patterns' "went in below 60%"
local NEAR = 4 -- levels below mine a foe may be, for a word on my health
local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
local ELITE = { elite = true, rareelite = true, worldboss = true }

local function often(c, key)
  local n = c.traits[key] or 0
  return n >= 2 and n / c.total >= SHARE and n or nil
end
local function list(parts)
  if #parts <= 1 then return parts[1] or "" end
  return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end

-- The word (pure): c, Patterns.lua's counts; foe = { name, level (-1: far
-- above), rank }; me = { level, pct }. Nil when nothing matches.
function ns.wordBefore(c, foe, me)
  if not c or c.total < MIN then return nil end
  local of = c.deaths > 0 and "close calls and deaths" or "close calls"
  local desc, counts = {}, {}
  local elite = ELITE[foe.rank or ""] and often(c, "elite")
  if elite then
    table.insert(desc, "an elite")
    table.insert(counts, ("%d had an elite"):format(elite))
  end
  local up = foe.level and me.level and (foe.level == -1 and 10 or foe.level - me.level) or 0
  local above = up >= 2 and often(c, "above")
  if above then
    table.insert(desc, foe.level == -1 and "far above you" or ((WORDS[up] or up) .. " levels above you"))
    table.insert(counts, ("%d had a foe two levels or more above you"):format(above))
  end
  local met = foe.name and c.foes[foe.name] or 0
  local named = met >= 2 and ("%d were against %s"):format(met, foe.name) or nil
  local near = foe.level == -1 or (foe.level and me.level and foe.level >= me.level - NEAR)
  local low = near and me.pct and me.pct < HURT and often(c, "low")
  local pct = me.pct and math.floor(me.pct + 0.5)
  local hurt = low and ("you're at %d%% health"):format(pct)
  local out
  if #counts > 0 then
    if named then table.insert(counts, named) end
    out = ("%s, %s. Of your %d %s, %s."):format(foe.name, table.concat(desc, " "), c.total, of, list(counts))
    if hurt then out = out .. (" You're at %d%% health; %d of them began below 60%%."):format(pct, low) end
  elseif named then
    out = ("%d of your %d %s were against %s."):format(met, c.total, of, foe.name)
    if hurt then out = out .. (" You're at %d%% health; %d began below 60%%."):format(pct, low) end
  elseif hurt then
    out = ("%s; %d of your %d %s began below 60%%."):format((hurt:gsub("^%l", string.upper)), low, c.total, of)
  end
  return out
end

-- ── the target ───────────────────────────────────────────────────────────────
local said = {} -- a name (or "hurt") = when it was last spoken of (GetTime)
local lastGuid
local cache = {} -- Patterns.lua's counts, kept while the debriefs are the same

local function counts(debriefs)
  local last = debriefs[#debriefs]
  if cache.n ~= #debriefs or cache.at ~= (last and last.at) then
    cache.n, cache.at, cache.c = #debriefs, last and last.at, ns.countsOf(debriefs)
  end
  return cache.c
end

local function clear(v) return v ~= nil and not ns.secret(v) end

ns.on("PLAYER_TARGET_CHANGED", function()
  if not ns.option("prepull") then return end
  if UnitAffectingCombat("player") or (InCombatLockdown and InCombatLockdown()) then return end
  if not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsPlayer("target") then return end
  if not UnitCanAttack("player", "target") or UnitCreatureType("target") == "Critter" then return end
  local guid, name = UnitGUID("target"), UnitName("target")
  if not (clear(guid) and clear(name)) or guid == lastGuid then return end
  lastGuid = guid
  local record = ns.record()
  if not record or #record.debriefs < MIN then return end
  local level, rank = UnitLevel("target"), UnitClassification("target")
  local health, max = UnitHealth("player"), UnitHealthMax("player")
  local foe = { name = name, level = clear(level) and level or nil, rank = clear(rank) and rank or nil }
  local me = { level = UnitLevel("player") }
  if clear(health) and clear(max) and max > 0 then me.pct = health / max * 100 end
  local word = ns.wordBefore(counts(record.debriefs), foe, me)
  if not word then return end
  local key = word:find("^You're at") and "hurt" or name
  if said[key] and GetTime() - said[key] < AGAIN then return end
  said[key] = GetTime()
  print(ns.PREFIX .. word)
end)
