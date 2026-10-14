-- The reader's language. The client loads its own Text_<locale>.lua next (the
-- TOCs name Text_[TextLocale].lua; scripts/locales.ts writes them from
-- i18n/), which hands its words to ns.translate; English stays wherever it
-- says nothing. Loaded after the kit and Creatures.lua, before any file reads
-- a word.
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

-- A creature type's English word (the game's own, UnitCreatureType's, in the
-- client's language: "Bête" is "Beast"), for its icon and the critter test.
local typeKeys = {}
function ns.typeKey(name) return name and (typeKeys[name] or name) or nil end

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
  for name, key in pairs(t.types or {}) do
    typeKeys[name] = key
  end
  -- (a foe Forever's damage meter names only, in the client's language: its
  -- creature, for its portrait)
  local names = ns.creatures and ns.creatures.names
  if names then
    for name, id in pairs(t.creatures or {}) do
      names[name] = names[name] or id
    end
  end
end
