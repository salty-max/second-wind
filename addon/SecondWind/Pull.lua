-- The word before a pull: out of a fight, when I target a foe that matches
-- what my close calls share (Patterns.lua's counts: an elite, a foe two
-- levels or more above me, a foe met in two of them or more), or when I am
-- hurt and going in hurt is one of the things they share, a line in chat.
-- Every character's close calls of this game count (a past life's lessons
-- for this one). Facts and counts, never advice; never in a fight; a foe once, its name
-- not again for AGAIN seconds. Settings: "A word before a pull".
local _, ns = ...
local L = ns.kit.L

local MIN = 3 -- debriefs before a word is said
local SHARE = 0.3 -- a trait in this share of them (and twice) counts
local AGAIN = 300 -- seconds before the same name is spoken of again
local HURT = 60 -- percent of my health: the patterns' "went in below 60%"
local NEAR = 4 -- levels below mine a foe may be, for a word on my health
local WORDS =
  { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"], L["ten"] }
local ELITE = { elite = true, rareelite = true, worldboss = true }
local RANK = {
  elite = { L["an elite"], L["an elite %s"] },
  rareelite = { L["a rare elite"], L["a rare elite %s"] },
  worldboss = { L["a boss"], L["a boss %s"] },
}

local function often(c, key)
  local n = c.traits[key] or 0
  return n >= 2 and n / c.total >= SHARE and n or nil
end
local function list(parts)
  if #parts <= 1 then return parts[1] or "" end
  return L["%s and %s"]:format(table.concat(parts, ", ", 1, #parts - 1), parts[#parts])
end

-- My health now, against how many of the close calls began hurt: one sentence
-- whole, its counts all there.
local function hurt(deaths)
  return deaths and L["You're at %d%% health, and %d of your %d close calls and deaths began below 60%%."]
    or L["You're at %d%% health, and %d of your %d close calls began below 60%%."]
end

-- The word (pure): c, Patterns.lua's counts; foe = { name, level (-1: far
-- above), rank }; me = { level, pct }. Nil when nothing matches; then true
-- when it speaks of my health alone (said again only after a while, whatever
-- I target). Each sentence whole, as a language orders its own.
function ns.wordBefore(c, foe, me)
  if not c or c.total < MIN then return nil end
  local deaths = c.deaths > 0
  local counts = {}
  local elite = ELITE[foe.rank or ""] and often(c, "elite")
  if elite then table.insert(counts, L["%d had an elite"]:format(elite)) end
  local up = foe.level and me.level and (foe.level == -1 and 10 or foe.level - me.level) or 0
  local above = up >= 2 and often(c, "above")
  local high
  if above then
    high = foe.level == -1 and L["far above you"] or L["%s levels above you"]:format(WORDS[up] or up)
    table.insert(counts, L["%d had a foe two levels or more above you"]:format(above))
  end
  -- (the foe by its rank: an elite, a rare elite, a boss)
  local rank = elite and RANK[foe.rank]
  local desc = rank and high and rank[2]:format(high) or rank and rank[1] or high
  -- (by its creature's id, a name only where the game gave none)
  local met = c.foes[ns.foeKey(foe) or ""] or (foe.name and c.foes[(c.keyOf or {})[foe.name] or foe.name]) or 0
  local named = met >= 2 and L["%d were against %s"]:format(met, foe.name) or nil
  local near = foe.level == -1 or (foe.level and me.level and foe.level >= me.level - NEAR)
  local low = near and me.pct and me.pct < HURT and often(c, "low")
  local pct = me.pct and math.floor(me.pct + 0.5)
  if #counts > 0 then
    if named then table.insert(counts, named) end
    local line = deaths and L["%s, %s. Of your %d close calls and deaths, %s."]
      or L["%s, %s. Of your %d close calls, %s."]
    local out = line:format(foe.name, desc, c.total, list(counts))
    if low then out = out .. " " .. hurt(deaths):format(pct, low, c.total) end
    return out
  elseif named then
    local line = deaths and L["%s was in %d of your %d close calls and deaths."]
      or L["%s was in %d of your %d close calls."]
    -- (ns.fmt: a language may put the name last, "%2$d ... %1$s")
    local out = ns.fmt(line, foe.name, met, c.total)
    if low then out = out .. " " .. hurt(deaths):format(pct, low, c.total) end
    return out
  elseif low then
    return hurt(deaths):format(pct, low, c.total), true
  end
  return nil
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
  -- (its type by its id, from the game's word for it)
  if not UnitCanAttack("player", "target") or ns.typeIdOf(UnitCreatureType("target")) == ns.CRITTER then return end
  local guid, name = UnitGUID("target"), UnitName("target")
  if not (clear(guid) and clear(name)) or guid == lastGuid then return end
  lastGuid = guid
  -- (every character's close calls of this game: a past life's lessons for this one)
  local debriefs = ns.debriefsOf(true)
  if #debriefs < MIN then return end
  local level, rank = UnitLevel("target"), UnitClassification("target")
  local health, max = UnitHealth("player"), UnitHealthMax("player")
  local foe =
    { name = name, npc = ns.npcOf(guid), level = clear(level) and level or nil, rank = clear(rank) and rank or nil }
  local me = { level = UnitLevel("player") }
  if clear(health) and clear(max) and max > 0 then me.pct = health / max * 100 end
  local word, hurtAlone = ns.wordBefore(counts(debriefs), foe, me)
  if not word then return end
  local key = hurtAlone and "hurt" or name
  if said[key] and GetTime() - said[key] < AGAIN then return end
  said[key] = GetTime()
  print(ns.PREFIX .. word)
end)
