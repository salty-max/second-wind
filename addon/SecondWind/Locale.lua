-- The reader's language. The client loads its own Text_<locale>.lua next (the
-- TOCs name Text_[TextLocale].lua; scripts/locales.ts writes them from
-- i18n/), which hands its words to ns.translate (English stays wherever it
-- says nothing) and the game's names in the language to ns.names. Loaded
-- after the kit and Creatures.lua, before any file reads a word.
local _, ns = ...
local K = ns.kit

-- (is n the "one" form? English, German, Spanish, Italian: 1; French and
-- Brazilian Portuguese: 0 and 1; Russian: 1, 21, 31... but not 11; Korean
-- and Chinese have one form)
local PLURALS = {
  one = function(n) return n == 1 end,
  fr = function(n) return n == 0 or n == 1 end,
  ru = function(n) return n % 10 == 1 and n % 100 ~= 11 end,
  none = function() return false end,
}

-- A sentence's blanks filled in, in the order its language puts them: a
-- translation may number them ("%2$s de %1$s"), which LuaJIT's format can't
-- read (the game's can).
function ns.fmt(s, ...)
  if not s:find("%%%d%$") then return s:format(...) end
  local args, order = { ... }, {}
  local plain = s:gsub("%%(%d)%$", function(i)
    table.insert(order, args[tonumber(i)])
    return "%"
  end)
  return plain:format(unpack(order))
end

-- A number with a decimal, as the language writes it ("2.5", "2,5").
ns.DECIMAL = "."
function ns.tenths(x)
  local s = ("%.1f"):format(x)
  return ns.DECIMAL == "." and s or (s:gsub("%.", ns.DECIMAL))
end

-- A moment as the book writes it, the month in the language's word: "14 Oct",
-- with the time "14 Oct 16:05" (the kit's month names, K.day's).
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function ns.date(at, time)
  local d = date("*t", at or 0)
  local L = K.L
  local day = L["%02d %s"]:format(d.day, L[MONTHS[d.month]])
  return time and L["%s %02d:%02d"]:format(day, d.hour, d.min) or day
end

-- A creature type by its id (the game's, C_CreatureInfo's: a debrief keeps
-- the id, its icon and the critter test by it, its word the client's).
ns.CRITTER = 8
local typeIds
-- (an older debrief's English key, before 15 October 2026)
local ENGLISH_TYPES = {
  Beast = 1,
  Dragonkin = 2,
  Demon = 3,
  Elemental = 4,
  Giant = 5,
  Undead = 6,
  Humanoid = 7,
  Critter = 8,
  Mechanical = 9,
  ["Not specified"] = 10,
  Totem = 11,
  ["Non-combat Pet"] = 12,
  ["Gas Cloud"] = 13,
  ["Wild Pet"] = 14,
}
-- A type's id from the game's current word, an older English key, or a
-- saved report's word in another language. The generated aliases only
-- recover ids: display names still come from the current client's API.
function ns.typeIdOf(word)
  if type(word) ~= "string" or word == "" or ns.secret(word) then return nil end
  if not typeIds then
    typeIds = {}
    local info = C_CreatureInfo or {}
    for _, id in ipairs(info.GetCreatureTypeIDs and info.GetCreatureTypeIDs() or {}) do
      local t = info.GetCreatureTypeInfo(id)
      if t and type(t.name) == "string" and t.name ~= "" then typeIds[t.name] = id end
    end
  end
  return typeIds[word] or ENGLISH_TYPES[word] or (ns.legacyTypeIds and ns.legacyTypeIds[word])
end
-- A type's word in the client's language, by its id.
function ns.typeName(id)
  local t = id and C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo and C_CreatureInfo.GetCreatureTypeInfo(id)
  return t and type(t.name) == "string" and t.name ~= "" and t.name or nil
end
-- A class's name in today's language, by its token ("WARRIOR"): the game's
-- own (LOCALIZED_CLASS_NAMES_*), else the name kept.
function ns.className(token, kept)
  local names = LOCALIZED_CLASS_NAMES_MALE
  return token and names and names[token] or kept or (token and token:lower()) or nil
end
-- A noun inside a sentence: lower case, as English and French write a kind
-- ("a beast"), but German keeps its capital ("ein Wildtier").
function ns.noun(word)
  if not word then return nil end
  return ns.locale == "deDE" and word or word:lower()
end
function ns.translate(t)
  ns.locale = t.locale
  K.isOne = PLURALS[t.plural] or K.isOne
  ns.DECIMAL = t.decimal or ns.DECIMAL
  -- (the reader's gender, the game's own token: $gmasculine:feminine;)
  local female = UnitSex and UnitSex("player") == 3
  local L = K.L
  for english, word in pairs(t.words or {}) do
    L[english] = word:gsub("%$g([^:;]*):([^;]*);", function(m, f) return female and f or m end)
  end
end

-- The game's names in the client's language (its Text file's, from
-- i18n/<locale>/, English one language among them): every foe's name by its
-- id, each game's, complete; the places inside buildings by their ids.
local names, idOfName, insideIds
function ns.names(t)
  names, idOfName, insideIds = t, nil, nil
  -- (what wow-data's build leaves out of Forever, Season of Discovery's: a
  -- saved debrief's foe named by its id alone, never found by a name, which
  -- pairs doesn't see)
  if t and t.creatures and t.creaturesLeftOut then setmetatable(t.creatures, { __index = t.creaturesLeftOut }) end
end
local function ownNames()
  if not names then return nil end
  return ns.forever and names.creatures or names.creaturesClassic
end

-- A place inside a building, which has no area id: its id from the client's
-- name for it (the building areas' list, the kit's), and its name by its id.
local function inside()
  if not names then return {} end
  return (ns.forever and names.inside or names.insideClassic) or {}
end
function ns.insideId(name)
  if type(name) ~= "string" or name == "" or ns.secret(name) then return nil end
  if not insideIds then
    insideIds = {}
    for id, n in pairs(inside()) do
      if not insideIds[n] or id < insideIds[n] then insideIds[n] = id end
    end
  end
  return insideIds[name]
end
function ns.insideName(id) return id and inside()[id] or nil end
-- A tool's item's name in the client's language, by its id (the language's
-- list: the game names an item only once loaded).
function ns.itemNameOf(id) return id and names and names.items and names.items[id] or nil end
-- A creature's name in the client's language, by its id; nil where the
-- language's names don't have it.
function ns.creatureNameOf(id)
  local own = id and ownNames()
  return own and own[id] or nil
end
-- A creature's id from its name in the client's language (Forever's damage
-- meter names a foe only: the first id of a name).
function ns.creatureIdOf(name)
  if type(name) ~= "string" or ns.secret(name) then return nil end
  if not idOfName then
    idOfName = {}
    for id, n in pairs(ownNames() or {}) do
      if not idOfName[n] or id < idOfName[n] then idOfName[n] = id end
    end
  end
  return idOfName[name]
end
