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

local MIN = 3 -- debriefs before anything is said
local SHOWN = 0.3 -- a trait listed in at least this share of them (and twice)
local HEADLINE = 0.5 -- the commonest told above, from this share
local ROWS = 5 -- places, foes, tools listed
local FIGHTS = 20 -- fights tallied before a trait is set against them all
local TRAITS = {
  { "world", "harm from the world: a fall, the water" },
  { "low", "you went in below 60% health" },
  { "many", "three foes or more at once" },
  { "late", "a foe joined after the start" },
  { "held", "you were stunned, feared or the like on the way down" },
  { "fast", "from half health to the low point in three seconds or less" },
  { "blow", "one blow took a third of your health or more" },
  { "elite", "an elite" },
  { "above", "a foe two levels or more above you" },
  { "magic", "the harm was mostly magic" },
  { "potion", "a healing potion or healthstone went unused" },
  { "guard", "something that guards went unused" },
  { "cure", "a cure went unused, with what it cures on you" },
}

local function plural(n, one, many) return n == 1 and ("a " .. one) or (n .. " " .. many) end

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

  local page = { enough = true, count = total, title = "What your close calls share", lessons = {}, sections = {} }
  local closes = total - deaths
  local made = {}
  if closes > 0 then table.insert(made, plural(closes, "close call", "close calls")) end
  if deaths > 0 then table.insert(made, plural(deaths, "death", "deaths")) end
  page.sub = ("From %d debriefs: %s%s"):format(
    total,
    table.concat(made, " and "),
    since and (", since " .. date("%d %b", since)) or ""
  )
  page.figures = {
    { tostring(total), "debriefs" },
    { tostring(closes), closes == 1 and "close call" or "close calls" },
    { tostring(deaths), deaths == 1 and "death" or "deaths" },
    { fights and fights.n and tostring(fights.n) or "0", "fights counted" },
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
    local of = deaths > 0 and "close calls and deaths" or "close calls"
    table.insert(page.lessons, ("In %d of your %d %s, %s."):format(often[1].n, total, of, often[1].phrase))
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
  local of = ("of your %d"):format(total)
  -- (against every fight's, once enough are tallied: how common it is at all)
  section(
    "Most often",
    often,
    function(t)
      local all = base and (" (%d of your %d fights)"):format(base.traits[t.key] or 0, base.n) or ""
      return ("%d of %d: %s%s"):format(t.n, total, t.phrase, all)
    end,
    function(t)
      return {
        kind = "share",
        share = t.n / total,
        title = t.phrase:gsub("^%l", string.upper),
        value = ("%d %s"):format(t.n, of),
        base = base and (base.traits[t.key] or 0) / base.n or nil,
        detail = base and ("in %d of your %d fights"):format(base.traits[t.key] or 0, base.n) or nil,
      }
    end
  )
  section(
    "Where",
    ranked(places, firstSeen),
    function(p) return ("%s: %d"):format(p.name, p.n) end,
    function(p) return { kind = "share", share = p.n / total, title = p.name, value = ("%d %s"):format(p.n, of) } end
  )
  section(
    "Foes met more than once",
    ranked(foes, firstSeen),
    function(f) return ("%s: in %d"):format(f.name, f.n) end,
    function(f) return { kind = "foe", foe = c.foeOf[f.name], detail = ("in %d %s"):format(f.n, of) } end
  )
  section(
    "Left unused most often",
    ranked(unused, firstSeen),
    function(t) return ("%s: %d times"):format(t.name, t.n) end,
    function(t)
      return { kind = "tool", tool = c.toolOf[t.name], title = t.name, detail = ("unused in %d %s"):format(t.n, of) }
    end
  )
  return page
end
