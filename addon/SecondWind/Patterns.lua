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

-- Names counted (a name once a debrief), the commonest first, twice or more.
local function ranked(counts, first)
  local list = {}
  for name, n in pairs(counts) do
    if n >= 2 then table.insert(list, { name = name, n = n, first = first[name] }) end
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
  local foeOf, toolOf = {}, {}
  local deaths, since = 0, nil
  local function count(map, name)
    map[name] = (map[name] or 0) + 1
    if not firstSeen[name] then
      order = order + 1
      firstSeen[name] = order
    end
  end
  for _, d in ipairs(debriefs) do
    if d.kind == "death" then deaths = deaths + 1 end
    if d.at and (not since or d.at < since) then since = d.at end
    for key in pairs(ns.traitsOf(d)) do
      traits[key] = (traits[key] or 0) + 1
    end
    local place = d.sub and (d.sub .. ", " .. (d.zone or "?")) or d.zone
    if place then count(places, place) end
    local met = {}
    for _, foe in ipairs(d.foes or {}) do
      if foe.name and not met[foe.name] then
        met[foe.name] = true
        count(foes, foe.name)
        foeOf[foe.name] = foe
      end
    end
    local left = {}
    -- (held the whole way down: nothing could have been used)
    for _, t in ipairs(not ns.helpless(d) and d.unused or {}) do
      if type(t) == "table" and t.n and not left[t.n] then
        left[t.n] = true
        count(unused, t.n)
        toolOf[t.n] = t
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
  }
end
function ns.countsOf(debriefs) return counted(debriefs) end

function ns.patternsOf(debriefs, fights)
  local total = #debriefs
  if total < MIN then return { enough = false, count = total } end
  local c = counted(debriefs)
  local traits, places, foes, unused, firstSeen = c.traits, c.places, c.foes, c.unused, c.firstSeen
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
    ranked(places, firstSeen),
    function(p) return L["%s: %d"]:format(p.name, p.n) end,
    function(p)
      return { kind = "share", share = p.n / total, title = p.name, value = L["%d of your %d"]:format(p.n, total) }
    end
  )
  section(
    L["Foes met more than once"],
    ranked(foes, firstSeen),
    function(f) return L["%s: in %d"]:format(f.name, f.n) end,
    function(f) return { kind = "foe", foe = c.foeOf[f.name], detail = L["in %d of your %d"]:format(f.n, total) } end
  )
  section(
    L["Left unused most often"],
    ranked(unused, firstSeen),
    function(t) return L["%s: %d times"]:format(t.name, t.n) end,
    function(t)
      return {
        kind = "tool",
        tool = c.toolOf[t.name],
        title = t.name,
        detail = L["unused in %d of your %d"]:format(t.n, total),
      }
    end
  )
  return page
end
