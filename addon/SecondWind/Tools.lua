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

-- The bag's and the body's: { id: the item, spell: what its use casts, k: its
-- kind, n: its name, and what makes it count }. What players carry for the worst moments (the
-- Hardcore guides and lists read 11 October 2026: Wowhead, Warcraft Tavern's
-- (barrens.chat) and others), each resolved by its exact name in the game's
-- tables (cmangos classic-db; for TBC Anniversary, its client's ItemSparse
-- and ItemEffect on wago.tools). Kinds as the spells', and:
--   heal: health at once (potions, healthstones, Restoring Balm...)
--   bandage: First Aid's (not while Recently Bandaged)
--   cure: counts only while one of its cures is on me (anti-venoms...)
-- Conditions: slot (head, feet, trinket: counts only worn), school (counts
-- only if harm of it came: a protection potion), env (counts only in a fall
-- or the water).
local ITEMS = {
  { id = 18839, spell = 4042, k = "heal", n = "Combat Healing Potion" },
  { id = 4596, spell = 440, k = "heal", n = "Discolored Healing Potion" },
  { id = 31676, spell = 38908, k = "heal", n = "Fel Regeneration Potion" },
  { id = 16768, spell = 20631, k = "heal", n = "Furbolg Medicine Pouch" },
  { id = 1710, spell = 2024, k = "heal", n = "Greater Healing Potion" },
  { id = 5510, spell = 5723, k = "heal", n = "Greater Healthstone" },
  { id = 19010, spell = 23474, k = "heal", n = "Greater Healthstone" },
  { id = 19011, spell = 23475, k = "heal", n = "Greater Healthstone" },
  { id = 929, spell = 441, k = "heal", n = "Healing Potion" },
  { id = 23822, spell = 28495, k = "heal", n = "Healing Potion Injector" },
  { id = 5509, spell = 5720, k = "heal", n = "Healthstone" },
  { id = 19008, spell = 23472, k = "heal", n = "Healthstone" },
  { id = 19009, spell = 23473, k = "heal", n = "Healthstone" },
  { id = 858, spell = 440, k = "heal", n = "Lesser Healing Potion" },
  { id = 5511, spell = 6263, k = "heal", n = "Lesser Healthstone" },
  { id = 19006, spell = 23470, k = "heal", n = "Lesser Healthstone" },
  { id = 19007, spell = 23471, k = "heal", n = "Lesser Healthstone" },
  { id = 34440, spell = 45051, k = "heal", n = "Mad Alchemist's Potion" },
  { id = 13446, spell = 17534, k = "heal", n = "Major Healing Potion" },
  { id = 9421, spell = 11732, k = "heal", n = "Major Healthstone" },
  { id = 19012, spell = 23476, k = "heal", n = "Major Healthstone" },
  { id = 19013, spell = 23477, k = "heal", n = "Major Healthstone" },
  { id = 18253, spell = 22729, k = "heal", n = "Major Rejuvenation Potion" },
  { id = 22103, spell = 27235, k = "heal", n = "Master Healthstone" },
  { id = 22104, spell = 27236, k = "heal", n = "Master Healthstone" },
  { id = 22105, spell = 27237, k = "heal", n = "Master Healthstone" },
  { id = 118, spell = 439, k = "heal", n = "Minor Healing Potion" },
  { id = 5512, spell = 6262, k = "heal", n = "Minor Healthstone" },
  { id = 19004, spell = 23468, k = "heal", n = "Minor Healthstone" },
  { id = 19005, spell = 23469, k = "heal", n = "Minor Healthstone" },
  { id = 11952, spell = 15701, k = "heal", n = "Night Dragon's Breath" },
  { id = 1970, spell = 8070, k = "heal", n = "Restoring Balm" },
  { id = 22829, spell = 28495, k = "heal", n = "Super Healing Potion" },
  { id = 22850, spell = 28517, k = "heal", n = "Super Rejuvenation Potion" },
  { id = 3928, spell = 4042, k = "heal", n = "Superior Healing Potion" },
  { id = 11951, spell = 15700, k = "heal", n = "Whipper Root Tuber" },
  { id = 2581, spell = 1159, k = "bandage", n = "Heavy Linen Bandage" },
  { id = 8545, spell = 10839, k = "bandage", n = "Heavy Mageweave Bandage" },
  { id = 21991, spell = 27031, k = "bandage", n = "Heavy Netherweave Bandage" },
  { id = 14530, spell = 18610, k = "bandage", n = "Heavy Runecloth Bandage" },
  { id = 6451, spell = 7927, k = "bandage", n = "Heavy Silk Bandage" },
  { id = 3531, spell = 3268, k = "bandage", n = "Heavy Wool Bandage" },
  { id = 1251, spell = 746, k = "bandage", n = "Linen Bandage" },
  { id = 8544, spell = 10838, k = "bandage", n = "Mageweave Bandage" },
  { id = 21990, spell = 27030, k = "bandage", n = "Netherweave Bandage" },
  { id = 14529, spell = 18608, k = "bandage", n = "Runecloth Bandage" },
  { id = 6450, spell = 7926, k = "bandage", n = "Silk Bandage" },
  { id = 3530, spell = 3267, k = "bandage", n = "Wool Bandage" },
  { id = 6452, spell = 7932, k = "cure", n = "Anti-Venom", cures = { "Poison" } },
  { id = 3386, spell = 26677, k = "cure", n = "Elixir of Poison Resistance", cures = { "Poison" } },
  { id = 2633, spell = 3592, k = "cure", n = "Jungle Remedy", cures = { "Disease", "Poison" } },
  { id = 19440, spell = 23786, k = "cure", n = "Powerful Anti-Venom", cures = { "Poison" } },
  { id = 13462, spell = 17550, k = "cure", n = "Purification Potion", cures = { "Curse", "Disease", "Poison" } },
  { id = 9030, spell = 11359, k = "cure", n = "Restorative Potion", cures = { "Magic", "Curse", "Disease", "Poison" } },
  { id = 6453, spell = 7933, k = "cure", n = "Strong Anti-Venom", cures = { "Poison" } },
  { id = 1191, spell = 5917, k = "guard", n = "Bag of Marbles" },
  { id = 6049, spell = 7233, k = "guard", n = "Fire Protection Potion", school = 4 },
  { id = 13506, spell = 17624, k = "guard", n = "Flask of Petrification" },
  { id = 5634, spell = 6615, k = "guard", n = "Free Action Potion" },
  { id = 6050, spell = 7239, k = "guard", n = "Frost Protection Potion", school = 16 },
  { id = 13461, spell = 17549, k = "guard", n = "Greater Arcane Protection Potion", school = 64 },
  { id = 13457, spell = 17543, k = "guard", n = "Greater Fire Protection Potion", school = 4 },
  { id = 13456, spell = 17544, k = "guard", n = "Greater Frost Protection Potion", school = 16 },
  { id = 13458, spell = 17546, k = "guard", n = "Greater Nature Protection Potion", school = 8 },
  { id = 13459, spell = 17548, k = "guard", n = "Greater Shadow Protection Potion", school = 32 },
  { id = 13455, spell = 17540, k = "guard", n = "Greater Stoneshield Potion" },
  { id = 18634, spell = 23131, k = "guard", n = "Gyrofreeze Ice Reflector", slot = "trinket", school = 16 },
  { id = 6051, spell = 7245, k = "guard", n = "Holy Protection Potion", school = 2 },
  { id = 18638, spell = 23097, k = "guard", n = "Hyper-Radiant Flame Reflector", slot = "trinket", school = 4 },
  { id = 22849, spell = 28515, k = "guard", n = "Ironshield Potion" },
  { id = 4623, spell = 4941, k = "guard", n = "Lesser Stoneshield Potion" },
  { id = 5816, spell = 6724, k = "guard", n = "Light of Elune" },
  { id = 3387, spell = 3169, k = "guard", n = "Limited Invulnerability Potion" },
  { id = 20008, spell = 24364, k = "guard", n = "Living Action Potion" },
  { id = 9036, spell = 11364, k = "guard", n = "Magic Resistance Potion", school = 126 },
  { id = 22845, spell = 28536, k = "guard", n = "Major Arcane Protection Potion", school = 64 },
  { id = 32840, spell = 28536, k = "guard", n = "Major Arcane Protection Potion", school = 64 },
  { id = 22841, spell = 28511, k = "guard", n = "Major Fire Protection Potion", school = 4 },
  { id = 32846, spell = 28511, k = "guard", n = "Major Fire Protection Potion", school = 4 },
  { id = 22842, spell = 28512, k = "guard", n = "Major Frost Protection Potion", school = 16 },
  { id = 32847, spell = 28512, k = "guard", n = "Major Frost Protection Potion", school = 16 },
  { id = 22847, spell = 28538, k = "guard", n = "Major Holy Protection Potion", school = 2 },
  { id = 22844, spell = 28513, k = "guard", n = "Major Nature Protection Potion", school = 8 },
  { id = 32844, spell = 28513, k = "guard", n = "Major Nature Protection Potion", school = 8 },
  { id = 22846, spell = 28537, k = "guard", n = "Major Shadow Protection Potion", school = 32 },
  { id = 32845, spell = 28537, k = "guard", n = "Major Shadow Protection Potion", school = 32 },
  { id = 6052, spell = 7254, k = "guard", n = "Nature Protection Potion", school = 8 },
  { id = 6048, spell = 7242, k = "guard", n = "Shadow Protection Potion", school = 32 },
  { id = 18639, spell = 23132, k = "guard", n = "Ultra-Flash Shadow Reflector", slot = "trinket", school = 32 },
  { id = 23737, spell = 30217, k = "stop", n = "Adamantite Grenade" },
  { id = 4392, spell = 4072, k = "stop", n = "Advanced Target Dummy" },
  { id = 16022, spell = 23074, k = "stop", n = "Arcanite Dragonling", slot = "trinket" },
  { id = 14022, spell = 18307, k = "stop", n = "Barov Peasant Caller", slot = "trinket" },
  { id = 14023, spell = 18308, k = "stop", n = "Barov Peasant Caller", slot = "trinket" },
  { id = 4380, spell = 4067, k = "stop", n = "Big Bronze Bomb" },
  { id = 4394, spell = 4069, k = "stop", n = "Big Iron Bomb" },
  { id = 4388, spell = 4060, k = "stop", n = "Discombobulator Ray" },
  { id = 4384, spell = 4074, k = "stop", n = "Explosive Sheep" },
  { id = 23736, spell = 30216, k = "stop", n = "Fel Iron Bomb" },
  { id = 4852, spell = 5134, k = "stop", n = "Flash Bomb" },
  { id = 10725, spell = 23133, k = "stop", n = "Gnomish Battle Chicken", slot = "trinket" },
  { id = 10726, spell = 13180, k = "stop", n = "Gnomish Mind Control Cap", slot = "head" },
  { id = 10720, spell = 13120, k = "stop", n = "Gnomish Net-o-Matic Projector", slot = "trinket" },
  { id = 23835, spell = 30507, k = "stop", n = "Gnomish Poultryizer", slot = "trinket" },
  { id = 10716, spell = 13006, k = "stop", n = "Gnomish Shrink Ray", slot = "trinket" },
  { id = 10588, spell = 22641, k = "stop", n = "Goblin Rocket Helmet", slot = "head" },
  { id = 23836, spell = 46567, k = "stop", n = "Goblin Rocket Launcher", slot = "trinket" },
  { id = 10646, spell = 13241, k = "stop", n = "Goblin Sapper Charge" },
  { id = 24269, spell = 31368, k = "stop", n = "Heavy Netherweave Net" },
  { id = 4390, spell = 4068, k = "stop", n = "Iron Grenade" },
  { id = 835, spell = 8312, k = "stop", n = "Large Rope Net" },
  { id = 11905, spell = 15712, k = "stop", n = "Linken's Boomerang", slot = "trinket" },
  { id = 2091, spell = 1090, k = "stop", n = "Magic Dust" },
  { id = 16023, spell = 19805, k = "stop", n = "Masterwork Target Dummy" },
  { id = 4396, spell = 23076, k = "stop", n = "Mechanical Dragonling", slot = "trinket" },
  { id = 24268, spell = 31367, k = "stop", n = "Netherweave Net" },
  { id = 4941, spell = 8312, k = "stop", n = "Really Sticky Glue" },
  { id = 3434, spell = 700, k = "stop", n = "Slumber Sand" },
  { id = 23827, spell = 30486, k = "stop", n = "Super Sapper Charge" },
  { id = 4366, spell = 4071, k = "stop", n = "Target Dummy" },
  { id = 15993, spell = 19769, k = "stop", n = "Thorium Grenade" },
  { id = 1404, spell = 835, k = "stop", n = "Tidal Charm", slot = "trinket" },
  { id = 5996, spell = 7178, k = "away", n = "Elixir of Water Breathing", env = { "Drowning" } },
  { id = 4397, spell = 4079, k = "away", n = "Gnomish Cloaking Device", slot = "trinket" },
  { id = 10724, spell = 13141, k = "away", n = "Gnomish Rocket Boots", slot = "feet" },
  { id = 7189, spell = 8892, k = "away", n = "Goblin Rocket Boots", slot = "feet" },
  { id = 18854, spell = 5579, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18856, spell = 5579, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18857, spell = 23273, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18858, spell = 23273, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18859, spell = 23274, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18862, spell = 23276, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18863, spell = 23277, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18864, spell = 23276, k = "away", n = "Insignia of the Alliance", slot = "trinket" },
  { id = 18834, spell = 5579, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18845, spell = 5579, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18846, spell = 5579, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18849, spell = 23273, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18850, spell = 23274, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18851, spell = 23276, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18852, spell = 23273, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 18853, spell = 23277, k = "away", n = "Insignia of the Horde", slot = "trinket" },
  { id = 9172, spell = 11392, k = "away", n = "Invisibility Potion" },
  { id = 3823, spell = 3680, k = "away", n = "Lesser Invisibility Potion" },
  { id = 28234, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 28235, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 28236, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 28237, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 28238, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 30348, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 30349, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 30350, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 30351, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 37864, spell = 42292, k = "away", n = "Medallion of the Alliance", slot = "trinket" },
  { id = 28239, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 28240, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 28241, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 28242, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 28243, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 30343, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 30344, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 30345, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 30346, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 37865, spell = 42292, k = "away", n = "Medallion of the Horde", slot = "trinket" },
  { id = 2820, spell = 14530, k = "away", n = "Nifty Stopwatch", slot = "trinket" },
  { id = 8529, spell = 16589, k = "away", n = "Noggenfogger Elixir", env = { "Falling", "Drowning" } },
  { id = 23824, spell = 51582, k = "away", n = "Rocket Boots Xtreme", slot = "feet" },
  { id = 35581, spell = 51582, k = "away", n = "Rocket Boots Xtreme Lite", slot = "feet" },
  { id = 22871, spell = 28548, k = "away", n = "Shrouding Potion" },
  { id = 4984, spell = 5024, k = "away", n = "Skull of Impending Doom" },
  { id = 2459, spell = 2379, k = "away", n = "Swiftness Potion" },
  { id = 6372, spell = 7840, k = "away", n = "Swim Speed Potion", env = { "Drowning" } },
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
-- Where a worn item is: the inventory slots it can be in.
local SLOTS = { head = { 1 }, feet = { 8 }, trinket = { 13, 14 } }
local function worn(it)
  for _, slot in ipairs(SLOTS[it.slot] or {}) do
    local id = GetInventoryItemID("player", slot)
    if clear(id) and id == it.id then return slot end
  end
end
local function wornReady(slot) return readyAfter(GetInventoryItemCooldown("player", slot)) end

-- What afflicts me now, by kind (Poison, Disease, Curse, Magic): what a cure
-- is for.
local function afflictions()
  local found = {}
  for i = 1, 40 do
    local kind
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
      if not a then break end
      kind = a.dispelName
    elseif UnitDebuff then
      local name, _, _, t = UnitDebuff("player", i)
      if not name then break end
      kind = t
    else
      break
    end
    if clear(kind) and kind ~= "" then found[kind] = true end
  end
  return found
end
local function against(it, on)
  for _, kind in ipairs(it.cures or {}) do
    if on[kind] then return kind end
  end
end

local function bandaged()
  return C_UnitAuras ~= nil
    and C_UnitAuras.GetPlayerAuraBySpellID ~= nil
    and C_UnitAuras.GetPlayerAuraBySpellID(RECENTLY_BANDAGED) ~= nil
end

-- The tools ready now: known, off cooldown and usable (an item in my bags,
-- usable at my level; one worn, in its slot; a bandage unless I was bandaged
-- a moment ago; a cure while what it cures is on me).
function ns.readyTools()
  local ready = {}
  for _, t in ipairs(SPELLS) do
    if known(t[1]) and spellReady(t[1]) and spellUsable(t[1]) then table.insert(ready, { n = t[1], k = t[2] }) end
  end
  local wrapped, on = bandaged(), afflictions()
  local had = {}
  for _, it in ipairs(ITEMS) do
    local tool
    if it.slot then
      local slot = worn(it)
      if slot and wornReady(slot) and itemUsable(it.id) then tool = { count = nil } end
    else
      local n = count(it.id)
      if n > 0 and itemUsable(it.id) and itemReady(it.id) then tool = { count = n } end
    end
    local cured = it.cures and against(it, on)
    if it.k == "bandage" and wrapped then tool = nil end
    if it.cures and not cured then tool = nil end
    if tool and not had[it.id] then
      had[it.id] = true
      tool.n, tool.k, tool.item, tool.spell = it.n, it.k, it.id, it.spell
      tool.against, tool.school, tool.env = cured, it.school, it.env
      table.insert(ready, tool)
    end
  end
  return ready
end

-- Of the tools ready, those that counted in this fight: a protection against
-- a school of harm that came (schools: the ones seen, by their bits; none
-- seen, none of those), what helps in a fall or the water in one.
local function sharesSchool(schools, school)
  for s in pairs(schools or {}) do
    if bit and bit.band then
      if bit.band(s, school) ~= 0 then return true end
    elseif s == school then
      return true
    end
  end
  return false
end
function ns.relevantTools(ready, fight)
  if not ready then return nil end
  local out = {}
  for _, t in ipairs(ready) do
    local fits = true
    if type(t) == "table" and t.school then fits = sharesSchool(fight.schools, t.school) end
    if type(t) == "table" and t.env then
      fits = false
      for _, e in ipairs(t.env) do
        if e == fight.env then fits = true end
      end
    end
    if fits then table.insert(out, t) end
  end
  return out
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
