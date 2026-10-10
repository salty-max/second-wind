-- A debrief read: its facts (what the card shows) and its lessons (one or
-- two, each a rule over the facts, never invented). Pure: nothing here asks
-- the game; the recorder kept what it needs (Recorder.lua's schema).
--   ns.factsOf(d) = { title, place, hits = { { src, spell, amount, crit,
--     share, before } }, fall = { from, seconds }, used, unused }
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
local function list(names)
  if #names <= 1 then return names[1] or "" end
  return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end
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

function ns.factsOf(d)
  local title = d.kind == "death" and "Death" or ("Close call: %d%% health"):format(d.lowPct or 0)
  local place = d.sub and (d.sub .. ", " .. (d.zone or "?")) or d.zone or "?"
  local unused, used, left = {}, {}, {}
  for _, t in ipairs(d.unused or {}) do
    if type(t) == "table" and t.n then
      table.insert(unused, t)
      left[t.n] = true
    end
  end
  for _, t in ipairs(d.ready or {}) do
    if type(t) == "table" and t.n and not left[t.n] then table.insert(used, t) end
  end
  return { title = title, place = place, hits = hits(d), fall = fall(d), used = used, unused = unused }
end

-- ── lessons ──────────────────────────────────────────────────────────────────
-- Each rule: a weight and a sentence, or nothing. The two weightiest are told.
local RULES = {
  -- harm from the world, not from a foe
  function(d)
    if not d.env or #(d.foes or {}) > 0 then return end
    local lesson = ENV_LESSON[d.env] or (d.env .. " took %d%% of your health.")
    return 100, lesson:format((d.startPct or 100) - (d.lowPct or 0))
  end,
  -- went in hurt
  function(d)
    if d.startPct and d.startPct < 60 and not d.env then
      return 90, ("You went in at %d%% health."):format(d.startPct)
    end
  end,
  -- a healing potion, a healthstone, ready in the bags
  function(d)
    for _, t in ipairs(d.unused or {}) do
      if t.k == "heal" then return 85, ("A %s was in your bags, ready."):format(t.n) end
    end
  end,
  -- a spell that guards, ready
  function(d)
    local names = {}
    for _, t in ipairs(d.unused or {}) do
      if t.k == "guard" then table.insert(names, t.n) end
    end
    if #names == 1 then return 80, ("%s was ready and went unused."):format(names[1]) end
    if #names > 1 then return 80, ("%s were ready and went unused."):format(list(names)) end
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
        local what = h.spell and (h.crit and ("A critical " .. h.spell) or h.spell)
          or (h.crit and ("A critical blow from " .. h.src) or ("A blow from " .. h.src))
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
    if all > 0 and magic / all >= 0.6 then
      return 50, ("Most of the harm was magic%s."):format(spell and (" (" .. spell .. ")") or "")
    end
  end,
}
ns.MAX_LESSONS = 2

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
  end
  if foe.misses and foe.misses > 0 then table.insert(did, plural(foe.misses, "miss", "misses")) end
  local first = foe.first and when(foe.first)
  return ("%s: %s"):format(who, table.concat(first and { first, unpack(did) } or did, ", "))
end
local function names(tools)
  local out = {}
  for _, t in ipairs(tools) do
    table.insert(out, t.count and t.count > 1 and ("%s (%d)"):format(t.n, t.count) or t.n)
  end
  return table.concat(out, ", ")
end

function ns.cardOf(d)
  local f = ns.factsOf(d)
  local sub = { f.place }
  if d.level then table.insert(sub, "level " .. d.level) end
  if d.length then table.insert(sub, d.length == 1 and "a second" or (d.length .. " seconds")) end
  if d.at then table.insert(sub, date("%d %b %H:%M", d.at)) end
  local card = { title = f.title, sub = table.concat(sub, " · "), lessons = ns.lessonsOf(d), sections = {} }
  local function section(heading, lines)
    if #lines > 0 then table.insert(card.sections, { heading = heading, lines = lines }) end
  end
  if d.kind == "death" and d.killer and d.killer.name then
    local k = d.killer
    local blow = k.spell and ("%s's %s"):format(k.name, k.spell) or k.name
    local extra = k.overkill and k.overkill > 0 and (" (%d more than you had)"):format(k.overkill) or ""
    section("The killing blow", { ("%s, %d%s"):format(blow, k.amount or 0, extra) })
  end
  local foes = {}
  for _, foe in ipairs(d.foes or {}) do
    table.insert(foes, foeLine(foe))
  end
  section("Foes", foes)
  local mattered = {}
  for _, h in ipairs(f.hits) do
    local what = h.spell and (h.crit and (h.spell .. ", critical,") or (h.spell .. ","))
      or (h.crit and "a critical blow," or "a blow,")
    local before = h.before
      and (h.before < 0.5 and "at the low point" or ("%.1f s before the low point"):format(h.before))
    table.insert(mattered, ("%d: %s from %s%s"):format(h.amount, what, h.src, before and (", " .. before) or ""))
  end
  section("The hits that mattered", mattered)
  local heals = {}
  for _, h in ipairs(d.heals or {}) do
    table.insert(heals, h.name == "you" and ("Your own: %d"):format(h.amount) or ("%s: %d"):format(h.name, h.amount))
  end
  section("Heals", heals)
  local had = {}
  if #f.unused > 0 then table.insert(had, "Ready, unused: " .. names(f.unused)) end
  if #f.used > 0 then table.insert(had, "Used: " .. names(f.used)) end
  if d.ready and #d.ready == 0 then table.insert(had, "Nothing of the kind was ready.") end
  section("What you had", had)
  return card
end
