-- A debrief read: its facts (what the card shows) and its lessons (one or
-- two, each a rule over the facts, never invented). Pure: nothing here asks
-- the game; the recorder kept what it needs (Recorder.lua's schema).
--   ns.factsOf(d) = { title, place, hits = { { src, spell, amount, crit,
--     share, before } }, fall = { from, seconds }, used, unused (my casts
--     hidden: both empty, the tools in ready alone), ready, held = {
--     seconds, span, all, what, spell } (control lost on the way down),
--     untold (ready, its use leaving no trace: Forever) }
--   ns.marksOf(d): the graph's marks; ns.textOf(d): the card as plain text
--   ns.lessonsOf(d) = { text, text }
local _, ns = ...

local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
local function words(n) return WORDS[n] or tostring(n) end
local function seconds(n)
  n = math.floor(n + 0.5)
  return n == 1 and "a second" or (words(n) .. " seconds")
end
-- A share of my health in words: "half", "a third", "a quarter".
local function share(f)
  if f >= 0.9 then return "nearly all" end
  if f >= 0.6 then return "most" end
  if f >= 0.45 then return "half" end
  if f >= 0.3 then return "a third" end
  if f >= 0.22 then return "a quarter" end
  return nil
end
local LISTED = 3 -- names in a lesson's list, then "and N more"
local function list(names)
  if #names <= 1 then return names[1] or "" end
  if #names > LISTED then return table.concat(names, ", ", 1, LISTED) .. (" and %d more"):format(#names - LISTED) end
  return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end
local AFFLICTION = { Poison = "poison", Disease = "a disease", Curse = "a curse", Magic = "magic" }
local HELD_MIN = 1.5 -- seconds of control lost that a lesson tells

-- Control lost on the way down (stunned, feared...): from what was ready (half
-- my health, or the start) to the low point (or the death), the seconds it
-- covered, the stretch's length, all of it or not, the longest one's what and
-- spell; nil if none.
local function heldOf(d)
  if not d.held then return nil end
  local from = d.readyT or 0
  local to = d.lowT or d.length or from
  local secs, longest = 0, nil
  for _, h in ipairs(d.held) do
    local a, b = math.max(from, h.t or 0), math.min(to, h.to or to)
    if b > a then
      secs = secs + (b - a)
      if not longest or b - a > longest.len then longest = { len = b - a, what = h.what, spell = h.spell } end
    end
  end
  if secs <= 0 then return nil end
  local span = to - from
  return { seconds = secs, span = span, all = secs >= 0.9 * span, what = longest.what, spell = longest.spell }
end
-- Held the whole way down: nothing could have been used, nothing called unused.
local function helpless(d)
  local h = heldOf(d)
  return h and h.all and h.seconds >= HELD_MIN or false
end
ns.helpless = helpless
local function above(foe, d) return foe.level and d.level and foe.level > 0 and foe.level - d.level or 0 end
local ELITE = { elite = true, rareelite = true, worldboss = true }
-- Harm from the world: what it is among the hits, and its lesson.
local ENV =
  { Falling = "a fall", Drowning = "drowning", Lava = "lava", Fire = "fire", Slime = "slime", Fatigue = "fatigue" }
local ENV_LESSON = {
  Falling = "A fall took %d%% of your health.",
  Drowning = "You ran out of breath: the water took %d%% of your health.",
  Lava = "Lava took %d%% of your health.",
  Fire = "Fire took %d%% of your health.",
  Slime = "Slime took %d%% of your health.",
  Fatigue = "You swam too far out: fatigue took %d%% of your health.",
}

-- The hits that mattered: the largest of the run-up, the largest first.
local function hits(d)
  local out = {}
  for _, r in ipairs(d.events or {}) do
    if r.k == "hit" and r.amount then
      table.insert(out, {
        src = r.src or (r.what and ENV[r.what]) or "?",
        spell = r.spell,
        id = r.id,
        what = r.what,
        amount = r.amount,
        crit = r.crit,
        share = d.maxHealth and d.maxHealth > 0 and r.amount / d.maxHealth or nil,
        before = d.lowT and r.t and math.max(0, d.lowT - r.t) or nil,
      })
    end
  end
  table.sort(out, function(a, b) return a.amount > b.amount end)
  for i = #out, 4, -1 do
    out[i] = nil
  end
  return out
end

-- The share of the harm that was magic (a school other than physical), and
-- its first spell.
local function magicOf(d)
  local magic, all, spell = 0, 0, nil
  for _, r in ipairs(d.events or {}) do
    if r.k == "hit" and r.amount and not r.what then
      all = all + r.amount
      if r.school and r.school ~= 1 then
        magic = magic + r.amount
        spell = spell or r.spell
      end
    end
  end
  return all > 0 and magic / all or 0, spell
end

-- The fall: from the last moment at or above half health to the low point.
local function fall(d)
  local samples, low = d.samples or {}, d.lowT
  if not low then return nil end
  local from
  for _, s in ipairs(samples) do
    if s.t <= low and s.pct >= 50 then from = s end
  end
  if not from then return nil end
  return { from = from.pct, seconds = low - from.t }
end

-- How low a close call went, in words: "11%", or on Forever, where the game
-- keeps my health from addons, "about 20%" (rebuilt, within a blow: Recorder.lua).
function ns.lowOf(d)
  -- (rebuilt from the game's warning: within a blow's size)
  if d.lowRange and d.lowRange[1] ~= d.lowRange[2] then return ("about %d%%"):format(d.lowPct or 0) end
  -- (read at the fight's end: an earlier dip may have gone lower)
  if d.lowAtEnd then return ("%d%% or lower"):format(d.lowPct or 0) end
  return ("%d%%"):format(d.lowPct or 0)
end

function ns.factsOf(d)
  local title = d.kind == "death" and "Death" or ("Close call: %s health"):format(ns.lowOf(d))
  local place = d.sub and (d.sub .. ", " .. (d.zone or "?")) or d.zone or "?"
  local unused, used, ready, left, untold, silent = {}, {}, {}, {}, {}, {}
  -- (Forever: a tool whose use leaves no trace is neither used nor unused)
  for _, n in ipairs(d.untold or {}) do
    silent[n] = true
  end
  for _, t in ipairs(d.unused or {}) do
    if type(t) == "table" and t.n then
      table.insert(unused, t)
      left[t.n] = true
    end
  end
  for _, t in ipairs(d.ready or {}) do
    if type(t) == "table" and t.n then
      table.insert(ready, t)
      -- (what went unused unknown, my casts hidden: none called used either)
      if silent[t.n] then
        table.insert(untold, t)
      elseif d.unused and not left[t.n] then
        table.insert(used, t)
      end
    end
  end
  return {
    title = title,
    place = place,
    hits = hits(d),
    fall = fall(d),
    used = used,
    unused = unused,
    ready = ready,
    untold = untold,
    held = heldOf(d),
  }
end

-- ── lessons ──────────────────────────────────────────────────────────────────
-- Each rule: a weight and a sentence, or nothing. The two weightiest are told.
local RULES = {
  -- harm from the world, not from a foe
  function(d)
    if not d.env or #(d.foes or {}) > 0 or not d.lowPct then return end
    local lesson = ENV_LESSON[d.env] or (d.env .. " took %d%% of your health.")
    return 100, lesson:format((d.startPct or 100) - (d.lowPct or 0))
  end,
  -- went in hurt
  function(d)
    if d.startPct and d.startPct < 60 and not d.env then
      return 90, ("You went in at %d%% health."):format(d.startPct)
    end
  end,
  -- stunned, feared...: on the way down, for a while or all of it
  function(d)
    local h = heldOf(d)
    if not h or h.seconds < HELD_MIN then return end
    local what = h.what or "Out of your control"
    local by = h.spell and (" (" .. h.spell .. ")") or ""
    if d.blind then return 88, ("%s for %s of the fight%s."):format(what, seconds(h.seconds), by) end
    local low = d.kind == "death" and "your death" or ((d.lowPct or 0) .. "%")
    if h.all then return 88, ("%s the whole way down to %s%s."):format(what, low, by) end
    return 88, ("%s for %s on the way down to %s%s."):format(what, seconds(h.seconds), low, by)
  end,
  -- a healing potion, a healthstone, ready in the bags
  function(d)
    if helpless(d) then return end
    for _, t in ipairs(d.unused or {}) do
      if t.k == "heal" then return 85, ("A %s was in your bags, ready."):format(t.n) end
    end
  end,
  -- a spell that guards, ready
  function(d)
    if helpless(d) then return end
    local names = {}
    for _, t in ipairs(d.unused or {}) do
      if t.k == "guard" then table.insert(names, t.n) end
    end
    if #names == 1 then return 80, ("%s was ready and went unused."):format(names[1]) end
    if #names > 1 then return 80, ("%s were ready and went unused."):format(list(names)) end
  end,
  -- a cure, ready, while what it cures was on me
  function(d)
    if helpless(d) then return end
    for _, t in ipairs(d.unused or {}) do
      if type(t) == "table" and t.k == "cure" and t.against then
        return 78, ("%s was ready, with %s on you."):format(t.n, AFFLICTION[t.against] or t.against:lower())
      end
    end
  end,
  -- too many at once
  function(d)
    local n = #(d.foes or {})
    if n >= 3 then return 75, ("%s foes at once."):format(words(n):gsub("^%l", string.upper)) end
  end,
  -- one that came late
  function(d)
    for _, foe in ipairs(d.foes or {}) do
      if foe.first and foe.first >= 5 and not foe.player then
        return 72, ("%s joined %s in."):format(foe.name, seconds(foe.first))
      end
    end
  end,
  -- a spell that holds a foe, or gets me out, ready
  function(d)
    if helpless(d) then return end
    local names = {}
    for _, t in ipairs(d.unused or {}) do
      if t.k == "stop" or t.k == "away" then table.insert(names, t.n) end
    end
    if #names == 1 then return 70, ("%s was ready too."):format(names[1]) end
    if #names > 1 then return 70, ("%s were ready too."):format(list(names)) end
  end,
  -- one blow took a big share
  function(d)
    for _, h in ipairs(hits(d)) do
      local s = h.share and share(h.share)
      if s and h.share >= 0.3 then
        local from = h.src ~= "?" and (" from " .. h.src) or ""
        local what = h.spell and (h.crit and ("A critical " .. h.spell) or h.spell)
          or (h.crit and ("A critical blow" .. from) or ("A blow" .. from))
        return 68, ("%s took %s of your health at once."):format(what, s)
      end
    end
  end,
  -- the fall from half health, fast
  function(d)
    local f = fall(d)
    if f and f.seconds <= 3 and d.kind ~= "death" then
      return 65, ("From half your health to %d%% in %s."):format(d.lowPct or 0, seconds(math.max(1, f.seconds)))
    end
  end,
  -- an elite, or a foe above my level
  function(d)
    for _, foe in ipairs(d.foes or {}) do
      if foe.rank and ELITE[foe.rank] then return 62, ("%s was an elite."):format(foe.name) end
    end
    for _, foe in ipairs(d.foes or {}) do
      local n = above(foe, d)
      if n >= 2 then return 60, ("%s was %s levels above you."):format(foe.name, words(n)) end
    end
  end,
  -- most of the harm was magic
  function(d)
    local magic, spell = magicOf(d)
    if magic >= 0.6 then return 50, ("Most of the harm was magic%s."):format(spell and (" (" .. spell .. ")") or "") end
  end,
}
ns.MAX_LESSONS = 2

-- A fight's traits, for what the close calls share (Patterns.lua): the same
-- tests as the lessons', a yes or no each.
function ns.traitsOf(d)
  local t = {}
  local foes = d.foes or {}
  t.world = d.env ~= nil and #foes == 0 or nil
  t.low = d.startPct and d.startPct < 60 and not d.env or nil
  t.many = #foes >= 3 or nil
  for _, foe in ipairs(foes) do
    if foe.first and foe.first >= 5 and not foe.player then t.late = true end
    if foe.rank and ELITE[foe.rank] then t.elite = true end
    if above(foe, d) >= 2 then t.above = true end
  end
  t.magic = magicOf(d) >= 0.6 or nil
  for _, h in ipairs(hits(d)) do
    if h.share and h.share >= 0.3 then t.blow = true end
  end
  local f = fall(d)
  t.fast = f and f.seconds <= 3 and d.kind ~= "death" or nil
  local h = heldOf(d)
  t.held = h and h.seconds >= HELD_MIN or nil
  for _, tool in ipairs(d.unused or {}) do
    if type(tool) == "table" and tool.k == "heal" then t.potion = true end
    if type(tool) == "table" and tool.k == "guard" then t.guard = true end
    if type(tool) == "table" and tool.k == "cure" then t.cure = true end
  end
  t.grouped = d.grouped or nil
  return t
end

function ns.lessonsOf(d)
  local found = {}
  for _, rule in ipairs(RULES) do
    local weight, text = rule(d)
    if weight then table.insert(found, { weight = weight, text = text }) end
  end
  table.sort(found, function(a, b) return a.weight > b.weight end)
  local out = {}
  for i = 1, math.min(ns.MAX_LESSONS, #found) do
    out[i] = found[i].text
  end
  return out
end

-- ── the card ─────────────────────────────────────────────────────────────────
-- The card's text: its title, the line under it, the lessons, and its
-- sections ({ heading, lines }); the book draws it (Book.lua), the health
-- over the fight from d.samples.
local function plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. many) end
local function when(t)
  t = math.floor((t or 0) + 0.5)
  if t <= 0 then return "from the start" end
  return t == 1 and "a second in" or (t .. " seconds in")
end
local function foeLine(foe)
  local about = {}
  if foe.level and foe.level > 0 then table.insert(about, "level " .. foe.level) end
  if foe.level == -1 then table.insert(about, "level ??") end
  if foe.rank and foe.rank ~= "normal" then
    table.insert(about, foe.rank == "rareelite" and "rare elite" or foe.rank)
  end
  if foe.type then table.insert(about, foe.type:lower()) end
  local who = #about > 0 and ("%s (%s)"):format(foe.name, table.concat(about, ", ")) or foe.name
  local did = {}
  if foe.hits and foe.hits > 0 then
    table.insert(did, plural(foe.hits, "hit", "hits") .. " for " .. (foe.damage or 0))
  elseif foe.damage and foe.damage > 0 then
    -- (the game's damage meter: the harm in all, not the blows)
    table.insert(did, foe.damage .. " in all")
  end
  if foe.misses and foe.misses > 0 then table.insert(did, plural(foe.misses, "miss", "misses")) end
  local first = foe.first and when(foe.first)
  local parts = first and { first, unpack(did) } or did
  if #parts == 0 then return who end
  return ("%s: %s"):format(who, table.concat(parts, ", "))
end
local function names(tools)
  local out = {}
  for _, t in ipairs(tools) do
    table.insert(out, t.count and t.count > 1 and ("%s (%d)"):format(t.n, t.count) or t.n)
  end
  return table.concat(out, ", ")
end

-- A foe of the fight by its name (the killer's, for its portrait), else one
-- made of the name alone.
function ns.foeNamed(d, name)
  for _, foe in ipairs(d.foes or {}) do
    if foe.name == name then return foe end
  end
  return name and { name = name } or nil
end

-- The debrief's face, at the head of its card: the foe that did the most
-- harm (its portrait), else the world's harm (a fall, the water...).
function ns.faceOf(d)
  local top
  for _, foe in ipairs(d.foes or {}) do
    if not top or (foe.damage or 0) > (top.damage or 0) then top = foe end
  end
  if top then return { foe = top } end
  if d.env then return { env = d.env } end
  return nil
end

function ns.cardOf(d)
  local f = ns.factsOf(d)
  local sub = { f.place }
  if d.level then table.insert(sub, "level " .. d.level) end
  if d.length then table.insert(sub, d.length == 1 and "a second" or (d.length .. " seconds")) end
  if d.at then table.insert(sub, date("%d %b %H:%M", d.at)) end
  local card = {
    title = f.title,
    sub = table.concat(sub, " · "),
    lessons = ns.lessonsOf(d),
    sections = {},
    death = d.kind == "death",
    face = ns.faceOf(d),
  }
  -- (rows: what the book draws for each line, its pictures; a note: told
  -- small, as an aside)
  local function section(heading, lines, rows, note)
    if #lines > 0 then table.insert(card.sections, { heading = heading, lines = lines, rows = rows, note = note }) end
  end
  if d.kind == "death" and d.killer and d.killer.name then
    local k = d.killer
    local blow = k.spell and ("%s's %s"):format(k.name, k.spell) or k.name
    local extra = k.overkill and k.overkill > 0 and (" (%d more than you had)"):format(k.overkill) or ""
    section("The killing blow", { ("%s, %d%s"):format(blow, k.amount or 0, extra) }, {
      {
        kind = "blow",
        death = true,
        foe = ns.foeNamed(d, k.name),
        spell = k.spell,
        id = k.id,
        what = k.what,
        amount = k.amount or 0,
        title = blow,
        detail = k.overkill and k.overkill > 0 and ("%d more than you had"):format(k.overkill) or nil,
      },
    })
  end
  local foes, foeRows, total = {}, {}, 0
  for _, foe in ipairs(d.foes or {}) do
    total = total + (foe.damage or 0)
  end
  for _, foe in ipairs(d.foes or {}) do
    table.insert(foes, foeLine(foe))
    table.insert(foeRows, { kind = "foe", foe = foe, level = d.level, share = total > 0 and (foe.damage or 0) / total })
  end
  section("Foes", foes, foeRows)
  -- what Forever hid (its health and casts in a fight), said plainly
  local hidden = {}
  if d.rebuilt then
    local from = d.rebuilt == "death" and "counted back from your death"
      or d.rebuilt == "end" and "counted back from your health at the fight's end"
      or "counted from the game's own low-health warning (35%)"
    local range = d.lowRange and (": the lowest point between %d%% and %d%%"):format(d.lowRange[1], d.lowRange[2]) or ""
    table.insert(
      hidden,
      ("Forever hides your health from addons: it was rebuilt from each blow and heal the game told, %s%s."):format(
        from,
        range
      )
    )
  elseif d.lowAtEnd then
    table.insert(
      hidden,
      "Forever hides your health in a fight: the lowest point here is your health at its end; a dip before may "
        .. "have gone lower."
    )
  elseif d.blind and d.kind == "death" then
    table.insert(hidden, "Forever hides your health from addons: the blows before your death are the game's own recap.")
  end
  if d.readyFrom == "start" then table.insert(hidden, "What you had is what was ready when the fight began.") end
  if d.castsHidden and d.traced then
    table.insert(
      hidden,
      "Forever hid your casts: what you used is told by what a use leaves behind (one fewer in your bags, "
        .. "a cooldown begun); a spell without a cooldown leaves none."
    )
  elseif d.castsHidden then
    table.insert(hidden, "Forever hid your casts: what went unused can't be told.")
  end
  section("What the game hid", hidden, nil, true)
  local mattered, hitRows = {}, {}
  for _, h in ipairs(f.hits) do
    -- (who dealt it, where the game said: not on Forever, several foes)
    local parts =
      { h.spell and (h.crit and (h.spell .. ", critical") or h.spell) or (h.crit and "a critical blow" or "a blow") }
    if h.src ~= "?" then table.insert(parts, "from " .. h.src) end
    if h.before then
      table.insert(parts, h.before < 0.5 and "at the low point" or ("%.1f s before the low point"):format(h.before))
    end
    table.insert(mattered, ("%d: %s"):format(h.amount, table.concat(parts, ", ")))
    table.insert(hitRows, {
      kind = "blow",
      spell = h.spell,
      id = h.id,
      what = h.what,
      crit = h.crit,
      amount = h.amount,
      share = h.share,
      title = parts[1]:gsub("^%l", string.upper),
      detail = table.concat(parts, ", ", 2),
    })
  end
  section("The hits that mattered", mattered, hitRows)
  local lost, lostRows = {}, {}
  for _, h in ipairs(d.held or {}) do
    local len = (h.to or d.length or h.t) - h.t
    if len >= 0.5 then
      local by = h.spell and (" (" .. h.spell .. ")") or ""
      table.insert(lost, ("%s%s: %.1f s, %s"):format(h.what or "Control lost", by, len, when(h.t)))
      table.insert(lostRows, {
        kind = "held",
        icon = h.icon,
        spell = h.spell,
        title = (h.what or "Control lost") .. by,
        detail = ("%.1f seconds, %s"):format(len, when(h.t)),
      })
    end
  end
  section("Out of your control", lost, lostRows)
  -- (Forever: the game's damage meter, by spell and who cast it, totals; the
  -- blows above, rebuilt, don't name their dealers)
  if d.spells and #d.spells > 0 then
    local harm, harmRows, all = {}, {}, 0
    for _, sp in ipairs(d.spells) do
      all = all + (sp.amount or 0)
    end
    for _, sp in ipairs(d.spells) do
      local what = sp.spell and sp.src and (sp.spell .. " from " .. sp.src) or sp.spell or sp.src or "?"
      table.insert(harm, ("%d in all: %s"):format(sp.amount, what))
      table.insert(harmRows, {
        kind = "blow",
        spell = sp.spell,
        id = sp.id,
        amount = sp.amount,
        share = all > 0 and sp.amount / all or nil,
        title = sp.spell or "?",
        detail = sp.src and ("from " .. sp.src) or nil,
      })
    end
    section("The harm, by spell", harm, harmRows)
  end
  local heals, healRows = {}, {}
  for _, h in ipairs(d.heals or {}) do
    -- ("received": the heals the game told, not who cast them: Forever)
    local who = h.name == "you" and "Your own" or h.name == "received" and "In all" or h.name
    table.insert(heals, ("%s: %d"):format(who, h.amount))
    table.insert(healRows, { kind = "blow", heal = true, amount = h.amount, title = who })
  end
  section("Heals", heals, healRows)
  local had, hadRows = {}, {}
  local function tools(head, these, state)
    table.insert(had, head .. ": " .. names(these))
    table.insert(hadRows, { kind = "tools", label = head, tools = these, state = state })
  end
  if #f.unused > 0 then
    local held = helpless(d) and f.held
    local head = not held and "Ready, unused"
      or (held.what and ("Ready, but you were %s"):format(held.what:lower()) or "Ready, but out of your control")
    tools(head, f.unused, held and "held" or "unused")
  end
  if #f.used > 0 then tools("Used", f.used, "used") end
  if #f.untold > 0 then tools("Ready, no trace either way", f.untold, "untold") end
  -- (my casts hidden: what was ready, no more said)
  if not d.unused and #f.ready > 0 then tools("Ready", f.ready, "ready") end
  if d.ready and #d.ready == 0 then
    table.insert(had, "Nothing of the kind was ready.")
    table.insert(hadRows, { kind = "text", text = "Nothing of the kind was ready." })
  end
  section("What you had", had, hadRows)
  return card
end

-- The graph's marks (Book.lua): the hits that mattered, the foes that joined
-- after the start, the tools I used (a cast of one, or its trace, when told),
-- the stretches I had lost control. { kind = hit | foe | used | held, t, to,
-- text }, in seconds from the fight's start.
function ns.marksOf(d)
  local marks = {}
  for _, h in ipairs(hits(d)) do
    if h.before and d.lowT then
      local from = h.src ~= "?" and h.src or nil
      local what = h.spell and (from and (h.spell .. " from " .. from) or h.spell) or from or "a blow"
      table.insert(marks, { kind = "hit", t = d.lowT - h.before, text = ("%d: %s"):format(h.amount, what) })
    end
  end
  for _, foe in ipairs(d.foes or {}) do
    if foe.first and foe.first >= 1 then table.insert(marks, { kind = "foe", t = foe.first, text = foe.name }) end
  end
  for _, c in ipairs(d.casts or {}) do
    local tool = ns.toolOfCast and ns.toolOfCast(c)
    if tool and c.t then table.insert(marks, { kind = "used", t = c.t, text = tool }) end
  end
  for _, h in ipairs(d.held or {}) do
    if h.to and h.to > h.t then
      table.insert(marks, { kind = "held", t = h.t, to = h.to, text = h.what or "Control lost" })
    end
  end
  -- (by time; at the same moment, a foe's coming, its blow, the hold, my answer)
  local ORDER = { foe = 1, hit = 2, held = 3, used = 4 }
  table.sort(marks, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    if a.kind ~= b.kind then return ORDER[a.kind] < ORDER[b.kind] end
    return a.text < b.text
  end)
  return marks
end

-- The card as plain text, to copy: for a guild's channel, a Discord.
function ns.textOf(d)
  local c = ns.cardOf(d)
  local out = { "Second Wind: " .. c.title, c.sub }
  for _, l in ipairs(c.lessons) do
    table.insert(out, "- " .. l)
  end
  for _, s in ipairs(c.sections) do
    table.insert(out, "")
    table.insert(out, s.heading .. ":")
    for _, l in ipairs(s.lines) do
      table.insert(out, "  " .. l)
    end
  end
  return table.concat(out, "\n")
end
