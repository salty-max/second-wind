-- What I had for a bad moment: the tools of every class and people, by name
-- as the spellbook knows them (every rank), and the bag's, by item with the
-- spell its use casts (from the game's own tables: cmangos classic-db, and
-- the TBC Anniversary client's ItemSparse and ItemEffect on wago.tools, read
-- 11 October 2026). The recorder (Recorder.lua) asks ns.readyTools() when my
-- health first falls below half; at the fight's end ns.unusedOf() says which
-- of them were not used after.
--   a tool: { n = name, k = guard | stop | away | heal | bandage | potion,
--     item, spell (an item's: what its use casts), count }
--   guard: lessens the harm or heals; stop: holds a foe; away: gets me out
local _, ns = ...

local SPELLS = {
  -- warrior
  { "Shield Wall", "guard" },
  { "Last Stand", "guard" },
  { "Retaliation", "guard" },
  { "Spell Reflection", "guard" },
  { "Berserker Rage", "guard" },
  { "Intimidating Shout", "stop" },
  { "Disarm", "stop" },
  -- rogue
  { "Evasion", "guard" },
  { "Cloak of Shadows", "guard" },
  { "Gouge", "stop" },
  { "Blind", "stop" },
  { "Kidney Shot", "stop" },
  { "Vanish", "away" },
  { "Sprint", "away" },
  -- mage
  { "Ice Block", "guard" },
  { "Ice Barrier", "guard" },
  { "Mana Shield", "guard" },
  { "Frost Nova", "stop" },
  { "Polymorph", "stop" },
  { "Blink", "away" },
  { "Invisibility", "away" },
  -- priest
  { "Power Word: Shield", "guard" },
  { "Desperate Prayer", "guard" },
  { "Pain Suppression", "guard" },
  { "Psychic Scream", "stop" },
  { "Fade", "away" },
  -- paladin
  { "Divine Shield", "guard" },
  { "Divine Protection", "guard" },
  { "Blessing of Protection", "guard" },
  { "Lay on Hands", "guard" },
  { "Hammer of Justice", "stop" },
  -- hunter
  { "Deterrence", "guard" },
  { "Freezing Trap", "stop" },
  { "Scatter Shot", "stop" },
  { "Intimidation", "stop" },
  { "Feign Death", "away" },
  { "Aspect of the Cheetah", "away" },
  -- warlock
  { "Death Coil", "stop" },
  { "Howl of Terror", "stop" },
  { "Fear", "stop" },
  -- shaman (and druid: Nature's Swiftness)
  { "Nature's Swiftness", "guard" },
  { "Earthbind Totem", "stop" },
  { "Ghost Wolf", "away" },
  -- druid
  { "Barkskin", "guard" },
  { "Frenzied Regeneration", "guard" },
  { "Entangling Roots", "stop" },
  { "Dash", "away" },
  -- peoples
  { "Stoneform", "guard" },
  { "War Stomp", "stop" },
  { "Will of the Forsaken", "away" },
  { "Escape Artist", "away" },
}

-- { item, the spell its use casts, kind, its name }
local ITEMS = {
  { 118, 439, "heal", "Minor Healing Potion" },
  { 858, 440, "heal", "Lesser Healing Potion" },
  { 4596, 440, "heal", "Discolored Healing Potion" },
  { 929, 441, "heal", "Healing Potion" },
  { 1710, 2024, "heal", "Greater Healing Potion" },
  { 3928, 4042, "heal", "Superior Healing Potion" },
  { 18839, 4042, "heal", "Combat Healing Potion" },
  { 13446, 17534, "heal", "Major Healing Potion" },
  { 22829, 28495, "heal", "Super Healing Potion" },
  { 23822, 28495, "heal", "Healing Potion Injector" },
  { 31676, 38908, "heal", "Fel Regeneration Potion" },
  { 11951, 15700, "heal", "Whipper Root Tuber" },
  { 11952, 15701, "heal", "Night Dragon's Breath" },
  { 5512, 6262, "heal", "Minor Healthstone" },
  { 19004, 23468, "heal", "Minor Healthstone" },
  { 19005, 23469, "heal", "Minor Healthstone" },
  { 5511, 6263, "heal", "Lesser Healthstone" },
  { 19006, 23470, "heal", "Lesser Healthstone" },
  { 19007, 23471, "heal", "Lesser Healthstone" },
  { 5509, 5720, "heal", "Healthstone" },
  { 19008, 23472, "heal", "Healthstone" },
  { 19009, 23473, "heal", "Healthstone" },
  { 5510, 5723, "heal", "Greater Healthstone" },
  { 19010, 23474, "heal", "Greater Healthstone" },
  { 19011, 23475, "heal", "Greater Healthstone" },
  { 9421, 11732, "heal", "Major Healthstone" },
  { 19012, 23476, "heal", "Major Healthstone" },
  { 19013, 23477, "heal", "Major Healthstone" },
  { 22103, 27235, "heal", "Master Healthstone" },
  { 22104, 27236, "heal", "Master Healthstone" },
  { 22105, 27237, "heal", "Master Healthstone" },
  { 1251, 746, "bandage", "Linen Bandage" },
  { 2581, 1159, "bandage", "Heavy Linen Bandage" },
  { 3530, 3267, "bandage", "Wool Bandage" },
  { 3531, 3268, "bandage", "Heavy Wool Bandage" },
  { 6450, 7926, "bandage", "Silk Bandage" },
  { 6451, 7927, "bandage", "Heavy Silk Bandage" },
  { 8544, 10838, "bandage", "Mageweave Bandage" },
  { 8545, 10839, "bandage", "Heavy Mageweave Bandage" },
  { 14529, 18608, "bandage", "Runecloth Bandage" },
  { 14530, 18610, "bandage", "Heavy Runecloth Bandage" },
  { 21990, 27030, "bandage", "Netherweave Bandage" },
  { 21991, 27031, "bandage", "Heavy Netherweave Bandage" },
  { 2459, 2379, "potion", "Swiftness Potion" },
  { 5634, 6615, "potion", "Free Action Potion" },
  { 20008, 24364, "potion", "Living Action Potion" },
  { 3387, 3169, "potion", "Limited Invulnerability Potion" },
  { 9030, 11359, "potion", "Restorative Potion" },
  { 22849, 28515, "potion", "Ironshield Potion" },
}
local RECENTLY_BANDAGED = 11196
local GCD = 1.6 -- seconds: a cooldown this close to its end is no cooldown

-- The game's answers, through whichever functions this client has (Forever's
-- C_ ones, Classic's older ones); a secret answer is no answer.
local function clear(...)
  for i = 1, select("#", ...) do
    if ns.secret((select(i, ...))) then return false end
  end
  return true
end
local function known(name)
  if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) ~= nil end
  return GetSpellInfo and GetSpellInfo(name) ~= nil
end
local function readyAfter(start, duration, enabled)
  if not clear(start, duration, enabled) or enabled == false or enabled == 0 then return false end
  return not start or start == 0 or start + duration - GetTime() <= GCD
end
local function spellReady(name)
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(name)
    return cd ~= nil and readyAfter(cd.startTime, cd.duration, cd.isEnabled)
  end
  return GetSpellCooldown ~= nil and readyAfter(GetSpellCooldown(name))
end
local function spellUsable(name)
  local usable = (C_Spell and C_Spell.IsSpellUsable or IsUsableSpell)(name)
  return clear(usable) and usable and true or false
end
local function count(item)
  local n = (C_Item and C_Item.GetItemCount or GetItemCount)(item)
  return clear(n) and n or 0
end
local function itemReady(item)
  local cooldown = C_Container and C_Container.GetItemCooldown or GetItemCooldown
  return readyAfter(cooldown(item))
end
local function itemUsable(item)
  local usable = (C_Item and C_Item.IsUsableItem or IsUsableItem)(item)
  return clear(usable) and usable and true or false
end
local function bandaged()
  return C_UnitAuras ~= nil
    and C_UnitAuras.GetPlayerAuraBySpellID ~= nil
    and C_UnitAuras.GetPlayerAuraBySpellID(RECENTLY_BANDAGED) ~= nil
end

-- The tools ready now: known, off cooldown and usable (an item in my bags,
-- usable at my level; a bandage unless I was bandaged a moment ago).
function ns.readyTools()
  local ready = {}
  for _, t in ipairs(SPELLS) do
    if known(t[1]) and spellReady(t[1]) and spellUsable(t[1]) then table.insert(ready, { n = t[1], k = t[2] }) end
  end
  local wrapped = bandaged()
  for _, it in ipairs(ITEMS) do
    local n = count(it[1])
    if n > 0 and not (it[3] == "bandage" and wrapped) and itemUsable(it[1]) and itemReady(it[1]) then
      table.insert(ready, { n = it[4], k = it[3], item = it[1], spell = it[2], count = n })
    end
  end
  return ready
end

-- Of the tools ready at a moment (since: seconds into the fight), those not
-- used after it: no cast of the spell by its name, of the item by its spell.
function ns.unusedOf(ready, casts, since)
  if not ready then return nil end
  local names, ids = {}, {}
  for _, c in ipairs(casts or {}) do
    if (c.t or 0) >= (since or 0) then
      if c.name then names[c.name] = true end
      if c.id then ids[c.id] = true end
    end
  end
  local unused = {}
  for _, t in ipairs(ready) do
    local used = t.item and ids[t.spell] or (not t.item and names[t.n])
    if not used then table.insert(unused, t) end
  end
  return unused
end
