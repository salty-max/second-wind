-- What the close calls share: over this character's debriefs (deaths among
-- them), the traits that come back (Debrief.lua's ns.traitsOf: the same tests
-- as the lessons'), the places, the foes met more than once and the tools left
-- unused most often. Counts, never advice. Pure, as Debrief.lua: the book
-- draws it (Book.lua's Patterns tab).
--   ns.patternsOf(debriefs, fights) = { enough, count, title, sub, lessons = {
--     a headline }, sections = { { heading, lines, rows } } }; fights: every
--     fight's tally (Recorder.lua), each trait set against it once there
--     are FIGHTS of them
--   ns.countsOf(debriefs): the counts themselves, for the word before a pull
--     (Pull.lua): { total, traits = { key = n }, foes = { name = n } }
local _, ns = ...
local K = ns.kit
local L = K.L

local MIN = 3 -- debriefs before anything is said
local SHOWN = 0.3 -- a trait listed in at least this share of them (and twice)
local HEADLINE = 0.5 -- the commonest told above, from this share
local ROWS = 5 -- places, foes, tools listed
local FIGHTS = 20 -- fights tallied before a trait is set against them all
local TRAITS = {
  { "world", L["harm from the world: a fall, the water"] },
  { "low", L["you went in below 60% health"] },
  { "many", L["three foes or more at once"] },
  { "late", L["a foe joined after the start"] },
  { "held", L["you were stunned, feared or the like on the way down"] },
  { "fast", L["from half health to the low point in three seconds or less"] },
  { "blow", L["one blow took a third of your health or more"] },
  { "elite", L["an elite"] },
  { "above", L["a foe two levels or more above you"] },
  { "magic", L["the harm was mostly magic"] },
  { "potion", L["a healing potion or healthstone went unused"] },
  { "guard", L["something that guards went unused"] },
  { "cure", L["a cure went unused, with what it cures on you"] },
}

-- Keys counted (once a debrief: a creature's id, a place's areas, a tool's
-- id; a name where the game gave none), the commonest first, twice or more,
-- each shown by its latest name (one creature met in two languages counts once).
local function ranked(counts, first, label)
  local list = {}
  for key, n in pairs(counts) do
    if n >= 2 then table.insert(list, { key = key, name = label[key] or tostring(key), n = n, first = first[key] }) end
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.first < b.first
  end)
  return list
end

local function counted(debriefs)
  local traits, places, foes, unused, firstSeen, order = {}, {}, {}, {}, {}, 0
  -- (each name's record, the latest: a foe's portrait, a tool's icon)
  local foeOf, toolOf, label, keyOf = {}, {}, {}, {}
  local deaths, since = 0, nil
  local function count(map, key, name)
    map[key] = (map[key] or 0) + 1
    label[key] = label[key] or name -- (the newest debrief's: today's language)
    if not firstSeen[key] then
      order = order + 1
      firstSeen[key] = order
    end
  end
  for _, d in ipairs(debriefs) do
    if d.kind == "death" then deaths = deaths + 1 end
    if d.at and (not since or d.at < since) then since = d.at end
    for key in pairs(ns.traitsOf(d)) do
      traits[key] = (traits[key] or 0) + 1
    end
    local place = d.sub and (d.sub .. ", " .. (d.zone or "?")) or d.zone
    if place then
      local sub = d.subArea or (d.subInside and ("w" .. d.subInside)) or d.sub or ""
      count(places, tostring(sub) .. "|" .. tostring(d.zoneArea or d.zone or ""), place)
    end
    local met = {}
    for _, foe in ipairs(d.foes or {}) do
      local key = ns.foeKey(foe)
      if key and not met[key] then
        met[key] = true
        count(foes, key, foe.name)
        foeOf[key] = foeOf[key] or foe
        if foe.name then keyOf[foe.name] = keyOf[foe.name] or key end
      end
    end
    local left = {}
    -- (held the whole way down: nothing could have been used)
    for _, t in ipairs(not ns.helpless(d) and d.unused or {}) do
      local key = type(t) == "table" and (t.item or t.sid or t.n)
      if key and not left[key] then
        left[key] = true
        count(unused, key, t.n)
        toolOf[key] = toolOf[key] or t
      end
    end
  end
  return {
    total = #debriefs,
    traits = traits,
    places = places,
    foes = foes,
    unused = unused,
    firstSeen = firstSeen,
    deaths = deaths,
    since = since,
    foeOf = foeOf,
    toolOf = toolOf,
    label = label,
    keyOf = keyOf, -- (a name's key: a target known by its name only)
  }
end
function ns.countsOf(debriefs) return counted(debriefs) end

function ns.patternsOf(debriefs, fights)
  local total = #debriefs
  if total < MIN then return { enough = false, count = total } end
  local c = counted(debriefs)
  local traits, places, foes, unused, firstSeen, label = c.traits, c.places, c.foes, c.unused, c.firstSeen, c.label
  local deaths, since = c.deaths, c.since
  local base = fights and fights.n and fights.n >= FIGHTS and fights or nil

  local page = { enough = true, count = total, title = L["What your close calls share"], lessons = {}, sections = {} }
  local closes = total - deaths
  local made = {}
  if closes > 0 then table.insert(made, closes == 1 and L["a close call"] or L["%d close calls"]:format(closes)) end
  if deaths > 0 then table.insert(made, deaths == 1 and L["a death"] or L["%d deaths"]:format(deaths)) end
  local of = #made == 2 and L["%s and %s"]:format(made[1], made[2]) or made[1]
  page.sub = since and L["From %d debriefs: %s, since %s"]:format(total, of, ns.date(since))
    or L["From %d debriefs: %s"]:format(total, of)
  page.figures = {
    { tostring(total), K.plural(total, "debrief", "debriefs") },
    { tostring(closes), K.plural(closes, "close call", "close calls") },
    { tostring(deaths), K.plural(deaths, "death", "deaths") },
    { fights and fights.n and tostring(fights.n) or "0", L["fights counted"] },
  }

  local often = {}
  for i, t in ipairs(TRAITS) do
    local n = traits[t[1]] or 0
    if n >= 2 and n / total >= SHOWN then table.insert(often, { n = n, i = i, key = t[1], phrase = t[2] }) end
  end
  table.sort(often, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.i < b.i
  end)
  if often[1] and often[1].n / total >= HEADLINE then
    local line = deaths > 0 and L["In %d of your %d close calls and deaths, %s."]
      or L["In %d of your %d close calls, %s."]
    table.insert(page.lessons, line:format(often[1].n, total, often[1].phrase))
  end
  -- (line: its text, for the copy and the tests; row: what the book draws)
  local function section(heading, list, line, row)
    if #list == 0 then return end
    local lines, rows = {}, {}
    for i = 1, math.min(ROWS, #list) do
      table.insert(lines, line(list[i]))
      table.insert(rows, row(list[i]))
    end
    table.insert(page.sections, { heading = heading, lines = lines, rows = rows })
  end
  -- (against every fight's, once enough are tallied: how common it is at all)
  section(
    L["Most often"],
    often,
    function(t)
      local all = base and L[" (%d of your %d fights)"]:format(base.traits[t.key] or 0, base.n) or ""
      return L["%d of %d: %s%s"]:format(t.n, total, t.phrase, all)
    end,
    function(t)
      return {
        kind = "share",
        share = t.n / total,
        title = (t.phrase:gsub("^%l", string.upper)),
        value = L["%d of your %d"]:format(t.n, total),
        base = base and (base.traits[t.key] or 0) / base.n or nil,
        detail = base and L["in %d of your %d fights"]:format(base.traits[t.key] or 0, base.n) or nil,
      }
    end
  )
  section(
    L["Where"],
    ranked(places, firstSeen, label),
    function(p) return L["%s: %d"]:format(p.name, p.n) end,
    function(p)
      return { kind = "share", share = p.n / total, title = p.name, value = L["%d of your %d"]:format(p.n, total) }
    end
  )
  section(
    L["Foes met more than once"],
    ranked(foes, firstSeen, label),
    function(f) return L["%s: in %d"]:format(f.name, f.n) end,
    function(f) return { kind = "foe", foe = c.foeOf[f.key], detail = L["in %d of your %d"]:format(f.n, total) } end
  )
  section(
    L["Left unused most often"],
    ranked(unused, firstSeen, label),
    function(t) return L["%s: %d times"]:format(t.name, t.n) end,
    function(t)
      return {
        kind = "tool",
        tool = c.toolOf[t.key],
        title = t.name,
        detail = L["unused in %d of your %d"]:format(t.n, total),
      }
    end
  )
  return page
end
