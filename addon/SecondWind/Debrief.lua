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
local K = ns.kit
local L = K.L

-- (every word through L, each sentence whole: a language orders its own)
local WORDS =
  { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"], L["ten"] }
-- (a number opening a sentence is a word as far as twenty: "Twelve foes at once.")
local OPENING = {
  L["eleven"],
  L["twelve"],
  L["thirteen"],
  L["fourteen"],
  L["fifteen"],
  L["sixteen"],
  L["seventeen"],
  L["eighteen"],
  L["nineteen"],
  L["twenty"],
}
-- A count in a sentence: a word to ten, digits after.
local function words(n) return WORDS[n] or tostring(n) end
-- The same, opening a sentence (a sentence never opens on a digit, but for
-- the numbers past twenty).
local function opening(n)
  local w = WORDS[n] or OPENING[n - 10] or tostring(n)
  return (w:gsub("^%l", string.upper))
end
ns.opening = opening
local function seconds(n)
  n = math.floor(n + 0.5)
  return n == 1 and L["a second"] or L["%s seconds"]:format(words(n))
end
-- A share of my health in words: "half of your health", "a third of it".
local function share(f)
  if f >= 0.9 then return L["nearly all of your health"] end
  if f >= 0.6 then return L["most of your health"] end
  if f >= 0.45 then return L["half of your health"] end
  if f >= 0.3 then return L["a third of your health"] end
  if f >= 0.22 then return L["a quarter of your health"] end
  return nil
end
local LISTED = 3 -- names in a lesson's list, then "and N more"
local function list(names)
  if #names <= 1 then return names[1] or "" end
  if #names > LISTED then
    return L["%s and %s more"]:format(table.concat(names, ", ", 1, LISTED), words(#names - LISTED))
  end
  return L["%s and %s"]:format(table.concat(names, ", ", 1, #names - 1), names[#names])
end
local AFFLICTION = { Poison = L["poison"], Disease = L["a disease"], Curse = L["a curse"], Magic = L["magic"] }
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
ns.listOf = list
local function above(foe, d) return foe.level and d.level and foe.level > 0 and foe.level - d.level or 0 end
-- (the lesson by rank: an elite, a rare elite and a boss are told as they are)
local ELITE = {
  elite = L["%s was an elite."],
  rareelite = L["%s was a rare elite."],
  worldboss = L["%s was a boss."],
}
-- Harm from the world: what it is among the hits, and its lesson.
local ENV = {
  Falling = L["a fall"],
  Drowning = L["drowning"],
  Lava = L["lava"],
  Fire = L["fire"],
  Slime = L["slime"],
  Fatigue = L["fatigue"],
}
ns.ENV = ENV
local ENV_LESSON = {
  Falling = L["A fall took %d%% of your health."],
  Drowning = L["You ran out of breath: the water took %d%% of your health."],
  Lava = L["Lava took %d%% of your health."],
  Fire = L["Fire took %d%% of your health."],
  Slime = L["Slime took %d%% of your health."],
  Fatigue = L["You swam too far out: fatigue took %d%% of your health."],
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

-- How low a close call went, in words: "11% health", or on Forever, where the
-- game keeps my health from addons, "about 20% health" (rebuilt, within a
-- blow: Recorder.lua). bare: the figure alone, for the graph's label ("11%").
function ns.lowOf(d, bare)
  local pct = d.lowPct or 0
  -- (rebuilt from the game's warning: within a blow's size)
  if d.lowRange and d.lowRange[1] ~= d.lowRange[2] then
    return (bare and L["about %d%%"] or L["about %d%% health"]):format(pct)
  end
  -- (read at the fight's end: an earlier dip may have gone lower)
  if d.lowAtEnd then return (bare and L["%d%% or lower"] or L["%d%% health or lower"]):format(pct) end
  return (bare and L["%d%%"] or L["%d%% health"]):format(pct)
end

function ns.factsOf(d)
  local title = d.kind == "death" and L["Death"] or L["Close call: %s"]:format(ns.lowOf(d))
  local place = ns.placeOf(d)
  local unused, used, ready, left, untold, silent = {}, {}, {}, {}, {}, {}
  -- (Forever: a tool whose use leaves no trace is neither used nor unused;
  -- the tools by their keys, never their names)
  for _, key in ipairs(d.untold or {}) do
    silent[key] = true
  end
  for _, t in ipairs(d.unused or {}) do
    if type(t) == "table" and t.n then
      table.insert(unused, t)
      left[ns.toolKey(t) or t.n] = true
    end
  end
  for _, t in ipairs(d.ready or {}) do
    if type(t) == "table" and t.n then
      table.insert(ready, t)
      local key = ns.toolKey(t) or t.n
      -- (what went unused unknown, my casts hidden: none called used either)
      if silent[key] then
        table.insert(untold, t)
      elseif d.unused and not left[key] then
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
    local took = (d.startPct or 100) - (d.lowPct or 0)
    if ENV_LESSON[d.env] then return 100, ENV_LESSON[d.env]:format(took) end
    return 100, L["%s took %d%% of your health."]:format(d.env, took)
  end,
  -- went in hurt
  function(d)
    if d.startPct and d.startPct < 60 and not d.env then
      return 90, L["You went in at %d%% health."]:format(d.startPct)
    end
  end,
  -- stunned, feared...: on the way down, for a while or all of it
  function(d)
    local h = heldOf(d)
    if not h or h.seconds < HELD_MIN then return end
    local by = h.spell and L[" (%s)"]:format(h.spell) or ""
    local secs = seconds(h.seconds)
    local low = L["%d%% health"]:format(d.lowPct or 0)
    -- (the game's own word for it, as a sentence holds it: ns.state; a
    -- language may order its blanks: ns.fmt)
    local what = h.what and ns.state(h.what) or L["not in control"]
    local function told(s, ...) return 88, ns.fmt(s, what, secs, ...) end
    if d.blind then return told(L["You were %s for %s of the fight%s."], by) end
    local death = d.kind == "death"
    if h.all then
      if death then return told(L["You were %s for %s, until your death%s."], by) end
      return told(L["You were %s for %s, until you were down to %s%s."], low, by)
    end
    if death then return told(L["You were %s for %s on the way to your death%s."], by) end
    return told(L["You were %s for %s on the way down to %s%s."], low, by)
  end,
  -- a healing potion, a healthstone, ready in the bags
  function(d)
    if helpless(d) then return end
    for _, t in ipairs(d.unused or {}) do
      if t.k == "heal" then return 85, L["A %s was ready in your bags."]:format(t.n) end
    end
  end,
  -- a spell that guards, ready (and with it what holds a foe or gets me
  -- out: one sentence, not the same one twice)
  function(d)
    if helpless(d) then return end
    local names, others = {}, {}
    for _, t in ipairs(d.unused or {}) do
      if t.k == "guard" then table.insert(names, t.n) end
      if t.k == "stop" or t.k == "away" then table.insert(others, t.n) end
    end
    if #names == 0 then return end
    for _, n in ipairs(others) do
      table.insert(names, n)
    end
    if #names == 1 then return 80, L["%s was ready and went unused."]:format(names[1]) end
    if #names > 1 then return 80, L["%s were ready and went unused."]:format(list(names)) end
  end,
  -- a cure, ready, while what it cures was on me
  function(d)
    if helpless(d) then return end
    for _, t in ipairs(d.unused or {}) do
      if type(t) == "table" and t.k == "cure" and t.against then
        local on = AFFLICTION[t.against] or t.against:lower()
        return 78, L["%s was ready, with %s on you."]:format(t.n, on)
      end
    end
  end,
  -- too many at once
  function(d)
    local n = #(d.foes or {})
    if n >= 3 then return 75, L["%s foes at once."]:format(opening(n)) end
  end,
  -- one that came late
  function(d)
    for _, foe in ipairs(d.foes or {}) do
      if foe.first and foe.first >= 5 and not foe.player then
        return 72, L["%s joined %s in."]:format(foe.name, seconds(foe.first))
      end
    end
  end,
  -- a spell that holds a foe, or gets me out, ready (told with the guards
  -- when one went unused too)
  function(d)
    if helpless(d) then return end
    local names = {}
    for _, t in ipairs(d.unused or {}) do
      if t.k == "guard" then return end
      if t.k == "stop" or t.k == "away" then table.insert(names, t.n) end
    end
    if #names == 1 then return 70, L["%s was ready and went unused."]:format(names[1]) end
    if #names > 1 then return 70, L["%s were ready and went unused."]:format(list(names)) end
  end,
  -- one blow took a big share
  function(d)
    for _, h in ipairs(hits(d)) do
      local s = h.share and share(h.share)
      -- (the world's hit alone is told by its own lesson: a fall, the water)
      if s and h.share >= 0.3 and not (h.what and #(d.foes or {}) == 0) then
        local what
        if h.what and h.src ~= "?" then
          what = (h.src:gsub("^%l", string.upper))
        elseif h.spell then
          what = h.crit and L["A critical %s"]:format(h.spell) or h.spell
        elseif h.src ~= "?" then
          what = (h.crit and L["A critical blow from %s"] or L["A blow from %s"]):format(h.src)
        else
          what = h.crit and L["A critical blow"] or L["A blow"]
        end
        return 68, L["%s took %s at once."]:format(what, s)
      end
    end
  end,
  -- the fall from half health, fast
  function(d)
    local f = fall(d)
    if f and f.seconds <= 3 and d.kind ~= "death" then
      return 65, L["From half your health to %d%% in %s."]:format(d.lowPct or 0, seconds(math.max(1, f.seconds)))
    end
  end,
  -- an elite, or a foe above my level
  function(d)
    for _, foe in ipairs(d.foes or {}) do
      if foe.rank and ELITE[foe.rank] then return 62, ELITE[foe.rank]:format(foe.name) end
    end
    for _, foe in ipairs(d.foes or {}) do
      local n = above(foe, d)
      if n >= 2 then return 60, L["%s was %s levels above you."]:format(foe.name, words(n)) end
    end
  end,
  -- most of the harm was magic
  function(d)
    local magic, spell = magicOf(d)
    if magic >= 0.6 then
      return 50, L["Most of the harm was magic%s."]:format(spell and L[" (%s)"]:format(spell) or "")
    end
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
    if h.share and h.share >= 0.3 and not (h.what and #foes == 0) then t.blow = true end
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
local function when(t)
  t = math.floor((t or 0) + 0.5)
  if t <= 0 then return L["from the start"] end
  return t == 1 and L["a second in"] or L["%d seconds in"]:format(t)
end
ns.when = when
-- A foe's rank in words (UnitClassification's: the game's own tokens).
local RANK = { elite = L["elite"], rareelite = L["rare elite"], rare = L["rare"], worldboss = L["boss"] }
function ns.rankWord(rank) return RANK[rank] end
local function foeLine(foe)
  local about = {}
  if foe.level and foe.level > 0 then table.insert(about, L["level %d"]:format(foe.level)) end
  if foe.level == -1 then table.insert(about, L["level ??"]) end
  if foe.rank and foe.rank ~= "normal" then table.insert(about, ns.rankWord(foe.rank) or foe.rank) end
  if foe.type then table.insert(about, ns.noun(foe.type)) end
  local who = #about > 0 and ("%s (%s)"):format(foe.name, table.concat(about, ", ")) or foe.name
  local did = {}
  if foe.hits and foe.hits > 0 then
    table.insert(did, K.plural(foe.hits, "%d hit for %d", "%d hits for %d"):format(foe.hits, foe.damage or 0))
  elseif foe.damage and foe.damage > 0 then
    -- (the game's damage meter: the harm in all, not the blows)
    table.insert(did, L["%d damage in all"]:format(foe.damage))
  end
  if foe.misses and foe.misses > 0 then
    table.insert(did, K.plural(foe.misses, "%d miss", "%d misses"):format(foe.misses))
  end
  local first = foe.first and when(foe.first)
  local parts = first and { first, unpack(did) } or did
  if #parts == 0 then return who end
  return L["%s: %s"]:format(who, table.concat(parts, ", "))
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
  local sub = {}
  if f.place then table.insert(sub, f.place) end
  if d.level then table.insert(sub, L["level %d"]:format(d.level)) end
  if d.length then table.insert(sub, d.length == 1 and L["a second"] or L["%d seconds"]:format(d.length)) end
  if d.at then table.insert(sub, ns.date(d.at, true)) end
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
    local blow = k.spell and ns.fmt(L["%s's %s"], k.name, k.spell) or k.name
    local extra = k.overkill and k.overkill > 0 and L[" (%d more than your health)"]:format(k.overkill) or ""
    section(L["The killing blow"], { L["%s, %d damage%s"]:format(blow, k.amount or 0, extra) }, {
      {
        kind = "blow",
        death = true,
        foe = ns.foeNamed(d, k.name),
        spell = k.spell,
        id = k.id,
        what = k.what,
        amount = k.amount or 0,
        title = blow,
        detail = k.overkill and k.overkill > 0 and L["%d more than your health"]:format(k.overkill) or nil,
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
  section(L["Foes"], foes, foeRows)
  local mattered, hitRows = {}, {}
  for _, h in ipairs(f.hits) do
    -- (who dealt it, where the game said: not on Forever, several foes)
    local death = d.kind == "death"
    -- (the world's hit is its own word, "a fall", not "a blow, from a fall")
    local parts = {
      h.what and h.src ~= "?" and h.src
        or h.spell and (h.crit and L["%s, critical"]:format(h.spell) or h.spell)
        or (h.crit and L["a critical blow"] or L["a blow"]),
    }
    if h.src ~= "?" and not h.what then table.insert(parts, L["from %s"]:format(h.src)) end
    if h.before then
      -- (on a death the low point is the death)
      if h.before < 0.5 then
        table.insert(parts, death and L["at your death"] or L["at the low point"])
      else
        table.insert(
          parts,
          (death and L["%s s before your death"] or L["%s s before the low point"]):format(ns.tenths(h.before))
        )
      end
    end
    table.insert(mattered, L["%d: %s"]:format(h.amount, table.concat(parts, ", ")))
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
  section(L["The hits that mattered"], mattered, hitRows)
  local lost, lostRows = {}, {}
  for _, h in ipairs(d.held or {}) do
    local len = (h.to or d.length or h.t) - h.t
    if len >= 0.5 then
      local by = h.spell and L[" (%s)"]:format(h.spell) or ""
      local what = h.what or L["Control lost"]
      table.insert(lost, L["%s%s: %s s, %s"]:format(what, by, ns.tenths(len), when(h.t)))
      table.insert(lostRows, {
        kind = "held",
        icon = h.icon,
        spell = h.spell,
        title = what .. by,
        detail = L["%s seconds, %s"]:format(ns.tenths(len), when(h.t)),
      })
    end
  end
  section(L["Out of your control"], lost, lostRows)
  -- (Forever: the game's damage meter, by spell and who cast it, totals; the
  -- blows above, rebuilt, don't name their dealers)
  if d.spells and #d.spells > 0 then
    local harm, harmRows, all = {}, {}, 0
    for _, sp in ipairs(d.spells) do
      all = all + (sp.amount or 0)
    end
    for _, sp in ipairs(d.spells) do
      -- (the meter's melee has no spell: blows from the foe)
      local what = sp.spell and sp.src and L["%s from %s"]:format(sp.spell, sp.src)
        or sp.spell
        or sp.src and L["blows from %s"]:format(sp.src)
        or "?"
      table.insert(harm, L["%d in all: %s"]:format(sp.amount, what))
      table.insert(harmRows, {
        kind = "blow",
        spell = sp.spell,
        id = sp.id,
        amount = sp.amount,
        share = all > 0 and sp.amount / all or nil,
        title = sp.spell or "?",
        detail = sp.src and L["from %s"]:format(sp.src) or nil,
      })
    end
    section(L["The harm, by spell"], harm, harmRows)
  end
  local heals, healRows = {}, {}
  for _, h in ipairs(d.heals or {}) do
    -- ("received": the heals the game told, not who cast them: Forever)
    local who = h.name == "you" and L["Your own heals"] or h.name == "received" and L["Received in all"] or h.name
    table.insert(heals, L["%s: %d"]:format(who, h.amount))
    table.insert(healRows, { kind = "blow", heal = true, amount = h.amount, title = who })
  end
  section(L["Heals"], heals, healRows)
  local had, hadRows = {}, {}
  local function tools(head, these, state)
    table.insert(had, L["%s: %s"]:format(head, names(these)))
    table.insert(hadRows, { kind = "tools", label = head, tools = these, state = state })
  end
  if #f.unused > 0 then
    local held = helpless(d) and f.held
    local head = not held and L["Ready, unused"]
      or (held.what and L["Ready, but you were %s"]:format(held.what:lower()) or L["Ready, but out of your control"])
    tools(head, f.unused, held and "held" or "unused")
  end
  if #f.used > 0 then tools(L["Used"], f.used, "used") end
  if #f.untold > 0 then tools(L["Ready, no trace either way"], f.untold, "untold") end
  -- (my casts hidden: what was ready, no more said)
  if not d.unused and #f.ready > 0 then tools(L["Ready"], f.ready, "ready") end
  if d.ready and #d.ready == 0 then
    table.insert(had, L["No lifeline was ready."])
    table.insert(hadRows, { kind = "text", text = L["No lifeline was ready."] })
  end
  section(L["What you had"], had, hadRows)
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
      local what = h.spell and (from and L["%s from %s"]:format(h.spell, from) or h.spell) or from or L["a blow"]
      table.insert(marks, { kind = "hit", t = d.lowT - h.before, text = L["%d: %s"]:format(h.amount, what) })
    end
  end
  for _, foe in ipairs(d.foes or {}) do
    if foe.first and foe.first >= 1 then table.insert(marks, { kind = "foe", t = foe.first, text = foe.name }) end
  end
  for _, c in ipairs(d.casts or {}) do
    local tool, key = ns.toolOfCast(c)
    if tool and c.t then table.insert(marks, { kind = "used", t = c.t, text = tool, key = key }) end
  end
  for _, h in ipairs(d.held or {}) do
    if h.to and h.to > h.t then
      table.insert(marks, { kind = "held", t = h.t, to = h.to, text = h.what or L["Control lost"] })
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
    table.insert(out, L["%s:"]:format(s.heading))
    for _, l in ipairs(s.lines) do
      table.insert(out, "  " .. l)
    end
  end
  return table.concat(out, "\n")
end
