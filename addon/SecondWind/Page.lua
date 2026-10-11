-- The book's pages, drawn (Book.lua holds the window, its tabs and the list):
-- a header (a round portrait, the title, the line under it, a rule), the
-- lessons (a bar of the accent beside each), my health over the fight (a
-- debrief's), then sections, a heading over a rule, and their rows, each drawn
-- as its kind wants. What is drawn: Debrief.lua's card, Patterns.lua's page,
-- Tools.lua's lifelines, { title, sub, face, lessons, death, sections = { {
-- heading, lines, rows, note } } }, a row of each line:
--   foe: its portrait (the creature's still one, as its unit frame shows
--     it, from its display: Creatures.lua's, as the Field Journal's, else
--     found by a hidden model; a player's class crest; else its kind's
--     picture), its name in the colour of its level against mine, what it
--     was, what it did, its share of the harm
--   blow: a spell's icon (a blow's, a heal's, the world's), its amount, what
--     and from whom, the share of my health it took
--   held: control lost, with the game's own icon for it
--   tools: a label over the tools' icons (those unused lit, those used
--     marked, those that left no trace dimmed), their counts
--   tool: one tool, its icon, its state (ready or how long until), what for;
--     or one of a kind I carry none of
--   share: a share of my close calls (a bar), against every fight's (a mark)
--   text: a line alone
-- A section without rows draws its lines; a note's lines are an aside, small.
-- A picture hovered shows the game's tooltip: an item's, a spell's, a foe's
-- level and kind.
local _, ns = ...

-- ── look ─────────────────────────────────────────────────────────────────────
-- The kit's, in Second Wind's theme: frost steel, blue-grey titles on cool
-- panels, calm after the fight (the Codex's gold on ink, the Field Journal's
-- sage, Hearthtale's ember).
local K = ns.kit
K.theme({
  accent = { 0.66, 0.78, 0.88 },
  text = { 0.90, 0.92, 0.95 },
  soft = { 0.56, 0.61, 0.67 },
  ring = { 0.48, 0.60, 0.72 },
  bar = { 0.45, 0.66, 0.86 },
  dim = { 0.50, 0.53, 0.57 },
  tint = { 0.86, 0.92, 1.00 },
  shade = { 0.02, 0.025, 0.035, 0.55 },
  highlight = { 0.78, 0.88, 1.00 },
})
local T = K.T
local label, rule = K.label, K.rule

local HEADER_H, PORTRAIT = 84, 64
ns.DEATH = { 0.86, 0.45, 0.42 } -- a death's title, its ring, the bar at its end
local DEATH = ns.DEATH
local HEAL = { 0.45, 0.86, 0.52 }
local GOOD = { 0.55, 0.85, 0.55 }
-- The graph's marks (Debrief.lua's ns.marksOf): their colours, their words.
local MARK = {
  hit = { 0.92, 0.36, 0.30 },
  foe = { 0.95, 0.72, 0.32 },
  used = { 0.45, 0.86, 0.52 },
  held = { 0.72, 0.62, 0.92 },
}
local LEGEND = {
  { "hit", "the hits that mattered" },
  { "foe", "a foe joined" },
  { "used", "what you used" },
  { "held", "out of your control" },
}
-- A tool's frame in a debrief: unused (it could have helped), used, held (out
-- of my control), ready (my casts hidden), untold (no trace either way).
local STATE = {
  unused = MARK.foe,
  used = MARK.used,
  held = MARK.held,
  ready = T.ring,
  untold = T.dim,
}
-- A rank's ring.
local RANK = {
  elite = { 0.95, 0.78, 0.30 },
  rareelite = { 0.85, 0.88, 0.95 },
  rare = { 0.85, 0.88, 0.95 },
  worldboss = { 0.95, 0.35, 0.30 },
}
local RANK_WORD = { elite = "elite", rareelite = "rare elite", rare = "rare", worldboss = "boss" }

-- ── pictures ─────────────────────────────────────────────────────────────────
local ICONS = "Interface\\Icons\\"
local QUESTION = ICONS .. "INV_Misc_QuestionMark"
local MELEE = ICONS .. "INV_Sword_04"
local FOE = ICONS .. "Ability_DualWield" -- (a foe nothing is known of)
local HEALS = ICONS .. "Spell_Holy_Heal"
local EMPTY = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local CRESTS = "Interface\\TargetingFrame\\UI-Classes-Circles"
-- The world's harm (a fall, the water...), and a foe of a kind with no portrait.
local WORLD = {
  Falling = ICONS .. "Spell_Magic_FeatherFall",
  Drowning = ICONS .. "Spell_Shadow_DemonBreath",
  Fatigue = ICONS .. "Spell_Nature_Sleep",
  Lava = ICONS .. "Spell_Fire_Fire",
  Fire = ICONS .. "Spell_Fire_Fire",
  Slime = ICONS .. "Spell_Nature_Acid_01",
}
local KIND = {
  Beast = ICONS .. "Ability_Hunter_Pet_Wolf",
  Humanoid = ICONS .. "INV_Misc_Head_Human_01",
  Undead = ICONS .. "Spell_Shadow_RaiseDead",
  Demon = ICONS .. "Spell_Shadow_SummonFelHunter",
  Dragonkin = ICONS .. "INV_Misc_Head_Dragon_01",
  Mechanical = ICONS .. "INV_Gizmo_01",
  Elemental = ICONS .. "Spell_Fire_Fire",
}

local function icon(tex, path)
  tex:SetTexture(path or QUESTION)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- A blow's or a heal's picture: its spell's (by id, else by name), the
-- world's, a swing's.
local function blowIcon(row)
  if row.heal then return HEALS end
  if row.what and WORLD[row.what] then return WORLD[row.what] end
  if not row.spell or row.spell == "Attack" or row.spell == "Melee" then return row.icon or MELEE end
  return row.icon or ns.spellIcon(row.id) or ns.spellIcon(row.spell) or QUESTION
end

-- A creature's display, found once by a hidden model (the server asked the
-- first time), then kept on the foe; one at a time, the others waiting.
local waiting, resolving, failed = {}, nil, {}
local function resolveNext()
  if resolving or not (C_Timer and C_Timer.NewTicker) then return end
  local foe = table.remove(waiting, 1)
  if not foe then return end
  local model = CreateFrame("PlayerModel", nil, UIParent)
  if not (model.SetCreature and model.GetDisplayInfo) then return end
  -- (off screen but shown: a hidden model doesn't load)
  model:SetSize(64, 64)
  model:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -200, -200)
  resolving = foe
  model:SetCreature(foe.npc)
  local tries = 0
  C_Timer.NewTicker(0.5, function(ticker)
    tries = tries + 1
    local display = model:GetDisplayInfo()
    if type(display) == "number" and not ns.secret(display) and display > 0 then
      foe.display = display
    elseif tries < 10 then
      model:SetCreature(foe.npc) -- (again: the first time only asked the server)
      return
    else
      failed[foe.npc] = true
    end
    ticker:Cancel()
    model:ClearModel()
    model:Hide()
    resolving = nil
    if foe.display and ns.refresh then ns.refresh(true) end
    resolveNext()
  end)
end
local function resolve(foe)
  if failed[foe.npc] or resolving == foe then return end
  for _, f in ipairs(waiting) do
    if f == foe then return end
  end
  table.insert(waiting, foe)
  resolveNext()
end

-- A foe's portrait: a player's class crest, the creature's still portrait
-- (its display found and kept), else its kind's picture.
local function portrait(p, foe)
  p.tex:SetDesaturated(false)
  -- (a foe of an older debrief, or one a fight named only: what was seen of it)
  ns.knownFoe(foe)
  local crest = foe.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[foe.class]
  if crest then
    p.tex:SetTexture(CRESTS)
    p.tex:SetTexCoord(unpack(crest))
    return
  end
  -- (its display: the data's, as the Field Journal's portraits; else found
  -- once in the game by a hidden model, kept on the foe)
  local display = foe.display or (foe.npc and ns.creatures and ns.creatures.models[foe.npc])
  if display and SetPortraitTextureFromCreatureDisplayID then
    p.tex:SetTexCoord(0, 1, 0, 1)
    SetPortraitTextureFromCreatureDisplayID(p.tex, display)
    return
  end
  if foe.npc and not display then resolve(foe) end
  if foe.level == -1 then return icon(p.tex, SKULL) end
  icon(p.tex, KIND[foe.type] or (foe.player and KIND.Humanoid) or FOE)
end

-- A page's face: a foe's portrait, the world's harm, an icon.
local function face(p, f, death)
  p.ring:SetVertexColor(unpack(death and DEATH or (f and f.foe and RANK[f.foe.rank]) or T.ring))
  if f and f.foe then return portrait(p, f.foe) end
  p.tex:SetDesaturated(false)
  if f and f.env then return icon(p.tex, WORLD[f.env]) end
  icon(p.tex, f and f.icon or "Interface\\AddOns\\SecondWind\\Media\\Logo")
end

-- ── colours and words ────────────────────────────────────────────────────────
-- The highest level that gives me nothing (the game's grey), then a foe's
-- level against mine in the game's colours: red, orange, yellow, green, grey.
local function grey(level)
  if level <= 5 then return 0 end
  if level <= 39 then return level - math.floor(level / 10) - 5 end
  if level <= 59 then return level - math.floor(level / 5) - 1 end
  return level - 9
end
local function levelColour(foe, me)
  if foe.level == -1 then return { 1, 0.1, 0.1 } end
  if not (foe.level and foe.level > 0 and me) then return T.text end
  local diff = foe.level - me
  if diff >= 5 then return { 1, 0.1, 0.1 } end
  if diff >= 3 then return { 1, 0.5, 0.25 } end
  if diff >= -2 then return { 1, 0.82, 0 } end
  if foe.level > grey(me) then return { 0.25, 0.75, 0.25 } end
  return { 0.6, 0.6, 0.6 }
end

local function aboutFoe(foe)
  local about = {}
  if foe.level and foe.level > 0 then table.insert(about, "level " .. foe.level) end
  if foe.level == -1 then table.insert(about, "level ??") end
  if foe.rank and RANK_WORD[foe.rank] then table.insert(about, RANK_WORD[foe.rank]) end
  if foe.class then
    table.insert(about, foe.class:lower())
  elseif foe.type then
    table.insert(about, foe.type:lower())
  elseif foe.player then
    table.insert(about, "a player")
  end
  return table.concat(about, " · ")
end

-- A font string as wide as its text, no wider than max (what follows it on
-- the line then sits right after it).
local function fit(fs, max)
  fs:SetWidth(0)
  fs:SetWidth(math.min(fs:GetStringWidth() + 2, max))
end

local function plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. many) end
local function didFoe(foe)
  local did = {}
  if foe.first then
    local t = math.floor(foe.first + 0.5)
    table.insert(
      did,
      t <= 0 and "from the start" or t == 1 and "joined a second in" or ("joined %d seconds in"):format(t)
    )
  end
  if foe.hits and foe.hits > 0 then
    table.insert(did, plural(foe.hits, "hit", "hits") .. " for " .. (foe.damage or 0))
  elseif foe.damage and foe.damage > 0 then
    table.insert(did, foe.damage .. " in all")
  end
  if foe.misses and foe.misses > 0 then table.insert(did, plural(foe.misses, "miss", "misses")) end
  return table.concat(did, " · ")
end

-- ── tooltips ─────────────────────────────────────────────────────────────────
local function tipFor(frame, what)
  frame:EnableMouse(true)
  frame.tip = what
  frame:SetScript("OnEnter", function(self)
    local tip = self.tip
    if not tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if tip.item and GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(tip.item)
    elseif tip.spell and GameTooltip.SetSpellByID then
      GameTooltip:SetSpellByID(tip.spell)
    else
      GameTooltip:AddLine(tip.title or "?", 1, 1, 1)
      if tip.text and tip.text ~= "" then GameTooltip:AddLine(tip.text, T.soft[1], T.soft[2], T.soft[3], true) end
    end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function toolTip(t)
  if t.item then return { item = t.item } end
  local id = ns.spellIdOf(t.n)
  if id then return { spell = id } end
  return { title = t.n }
end

-- ── a page ───────────────────────────────────────────────────────────────────
-- A scroll area holding the header and pools of blocks, one a kind (reused
-- from one drawing to the next).
local Page = {}

function ns.newPage(parent, name, x, width, withGraph)
  local p = K.scrollArea(parent, width, name)
  for k, v in pairs(Page) do
    p[k] = v
  end
  p:SetPoint("TOPLEFT", x, -16)
  p:SetPoint("BOTTOMRIGHT", -20, 12)
  p.width, p.pools, p.hasGraph = width, {}, withGraph and true or false
  p.portrait = K.roundIcon(p.child, PORTRAIT, true)
  p.portrait:SetPoint("TOPLEFT", 2, -2)
  p.title = label(p.child, K.TITLE_FONT, 22, T.accent)
  p.title:SetPoint("TOPLEFT", p.portrait, "TOPRIGHT", 14, -8)
  p.title:SetWidth(width - PORTRAIT - 18)
  p.title:SetWordWrap(false)
  p.sub = label(p.child, K.BODY_FONT, 12, T.soft)
  p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -7)
  p.sub:SetWidth(width - PORTRAIT - 18)
  local line = rule(p.child)
  line:SetPoint("TOPLEFT", 0, -(HEADER_H - 8))
  line:SetPoint("TOPRIGHT", 0, -(HEADER_H - 8))
  if withGraph then p.graph = Page.newGraph(p.child, width) end
  return p
end

-- A block of a kind, from its pool (made by its maker the first time).
local MAKERS = {}
function Page:take(kind)
  local pool = self.pools[kind]
  if not pool then
    pool = { n = 0 }
    self.pools[kind] = pool
  end
  pool.n = pool.n + 1
  local b = pool[pool.n]
  if not b then
    b = MAKERS[kind](self)
    pool[pool.n] = b
  end
  b:ClearAllPoints()
  b:Show()
  return b
end

-- A block at the page's next place, so tall (and a gap after it).
function Page:place(b, height, gap)
  b:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
  self.y = self.y + height + (gap or 0)
end

-- ── the blocks ───────────────────────────────────────────────────────────────
local ROW_TEXT = 12

function MAKERS.heading(p)
  local h = CreateFrame("Frame", nil, p.child)
  h:SetSize(p.width, 24)
  h.text = label(h, K.TITLE_FONT, 15, T.accent)
  h.text:SetPoint("BOTTOMLEFT", 0, 5)
  h.line = rule(h)
  h.line:SetPoint("BOTTOMLEFT")
  h.line:SetPoint("BOTTOMRIGHT")
  return h
end

function MAKERS.lesson(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetWidth(p.width)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT", 0, 1)
  b.bar:SetPoint("BOTTOMLEFT", 0, -1)
  b.bar:SetWidth(3)
  b.text = label(b, K.BODY_FONT, 13, T.text)
  b.text:SetPoint("TOPLEFT", 12, 0)
  b.text:SetWidth(p.width - 12)
  b.text:SetSpacing(2)
  return b
end

function MAKERS.text(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetWidth(p.width)
  b.text = label(b, K.BODY_FONT, ROW_TEXT, T.text)
  b.text:SetPoint("TOPLEFT")
  b.text:SetWidth(p.width)
  b.text:SetSpacing(2)
  return b
end

-- A small square picture with a thin frame (its colour: what it says).
local function square(parent, size)
  local s = CreateFrame("Frame", nil, parent)
  s:SetSize(size, size)
  s.edge = s:CreateTexture(nil, "BACKGROUND")
  s.edge:SetPoint("TOPLEFT", -1, 1)
  s.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  s.edge:SetColorTexture(0, 0, 0, 0.9)
  s.tex = s:CreateTexture(nil, "ARTWORK")
  s.tex:SetAllPoints()
  s.count = label(s, K.BODY_FONT, 10, { 1, 1, 1 })
  s.count:SetFont(K.BODY_FONT, 10, "OUTLINE")
  s.count:SetPoint("BOTTOMRIGHT", -1, 2)
  return s
end
local function frameColour(s, c, alpha) s.edge:SetColorTexture(c[1], c[2], c[3], alpha or 1) end

function MAKERS.foe(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetSize(p.width, 46)
  b.portrait = K.roundIcon(b, 38, true)
  b.portrait:SetPoint("TOPLEFT", 2, -2)
  b.name = label(b, K.BODY_FONT, 13, T.text)
  b.name:SetPoint("TOPLEFT", 52, -2)
  b.name:SetWordWrap(false)
  b.about = label(b, K.BODY_FONT, 11, T.soft)
  b.about:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
  b.about:SetWordWrap(false)
  b.did = label(b, K.BODY_FONT, 11, T.soft)
  b.did:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
  b.did:SetWidth(p.width - 52)
  b.did:SetWordWrap(false)
  b.share = K.bar(b)
  b.share:SetPoint("TOPLEFT", b.did, "BOTTOMLEFT", 0, -5)
  b.share:SetSize(p.width - 52, 3)
  b.share:SetMinMaxValues(0, 1)
  b.share:SetStatusBarColor(unpack(MARK.hit))
  tipFor(b.portrait, nil)
  return b
end

function MAKERS.blow(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetSize(p.width, 34)
  b.icon = square(b, 26)
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.amount = label(b, K.TITLE_FONT, 16, MARK.hit)
  b.amount:SetPoint("TOPLEFT", 38, -1)
  b.amount:SetWidth(54)
  b.title = label(b, K.BODY_FONT, ROW_TEXT, T.text)
  b.title:SetPoint("TOPLEFT", 96, -2)
  b.title:SetWidth(p.width - 96)
  b.title:SetWordWrap(false)
  b.detail = label(b, K.BODY_FONT, 11, T.soft)
  b.detail:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -3)
  b.detail:SetWidth(p.width - 96)
  b.detail:SetWordWrap(false)
  b.share = K.bar(b)
  b.share:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 10, -4)
  b.share:SetSize(46, 3)
  b.share:SetMinMaxValues(0, 1)
  tipFor(b.icon, nil)
  return b
end

function MAKERS.tools(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetWidth(p.width)
  b.label = label(b, K.BODY_FONT, 11, T.soft)
  b.label:SetPoint("TOPLEFT")
  b.icons = {}
  return b
end

function MAKERS.tool(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetSize(p.width, 34)
  b.icon = square(b, 28)
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.title = label(b, K.BODY_FONT, ROW_TEXT, T.text)
  b.title:SetPoint("TOPLEFT", 42, -2)
  b.title:SetWordWrap(false)
  b.value = label(b, K.BODY_FONT, 11, T.soft)
  b.value:SetPoint("LEFT", b.title, "RIGHT", 8, 0)
  b.value:SetWordWrap(false)
  b.detail = label(b, K.BODY_FONT, 11, T.soft)
  b.detail:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -3)
  b.detail:SetWidth(p.width - 42)
  b.detail:SetWordWrap(false)
  tipFor(b.icon, nil)
  return b
end

function MAKERS.share(p)
  local b = CreateFrame("Frame", nil, p.child)
  b:SetWidth(p.width)
  b.title = label(b, K.BODY_FONT, ROW_TEXT, T.text)
  b.title:SetPoint("TOPLEFT")
  b.title:SetWidth(p.width - 130)
  b.title:SetWordWrap(false)
  b.value = label(b, K.BODY_FONT, 11, T.soft)
  b.value:SetPoint("TOPRIGHT")
  b.value:SetWidth(126)
  b.value:SetJustifyH("RIGHT")
  b.bar = K.bar(b)
  b.bar:SetPoint("TOPLEFT", 0, -18)
  b.bar:SetSize(p.width, 6)
  b.bar:SetMinMaxValues(0, 1)
  b.base = b.bar:CreateTexture(nil, "OVERLAY")
  b.base:SetColorTexture(1, 1, 1, 0.85)
  b.base:SetSize(2, 10)
  b.detail = label(b, K.BODY_FONT, 10, T.soft)
  b.detail:SetPoint("TOPLEFT", b.bar, "BOTTOMLEFT", 0, -4)
  return b
end

-- ── rows ─────────────────────────────────────────────────────────────────────
local DRAW = {}

function DRAW.foe(p, r)
  local b, foe = p:take("foe"), r.foe or { name = "?" }
  portrait(b.portrait, foe)
  b.portrait.ring:SetVertexColor(unpack(RANK[foe.rank] or T.ring))
  b.portrait.tip = { title = foe.name, text = aboutFoe(foe) }
  b.name:SetText(foe.name or "?")
  b.name:SetTextColor(unpack(levelColour(foe, r.level)))
  -- (a long name cut short, what it was beside it)
  fit(b.name, p.width - 200)
  b.about:SetText(aboutFoe(foe))
  local did = r.detail or didFoe(foe)
  b.did:SetText(did)
  b.share:SetShown(r.share ~= nil)
  if r.share then b.share:SetValue(r.share) end
  p:place(b, r.share and 46 or 40, 6)
end

function DRAW.blow(p, r)
  local b = p:take("blow")
  icon(b.icon.tex, blowIcon(r))
  b.icon.count:SetText("")
  frameColour(b.icon, r.death and DEATH or { 0, 0, 0 }, 0.9)
  b.icon.tip = r.id and { spell = r.id } or { title = r.title, text = r.detail }
  b.amount:SetText(r.amount and tostring(r.amount) or "")
  b.amount:SetTextColor(unpack(r.heal and HEAL or r.death and DEATH or MARK.hit))
  b.title:SetText(r.title or "")
  b.detail:SetText(r.detail or "")
  b.share:SetShown(r.share ~= nil)
  if r.share then
    b.share:SetValue(math.min(1, r.share))
    b.share:SetStatusBarColor(unpack(r.heal and HEAL or MARK.hit))
  end
  p:place(b, 32, 4)
end

function DRAW.held(p, r)
  local b = p:take("blow")
  icon(b.icon.tex, r.icon or (r.spell and ns.spellIcon(r.spell)) or ICONS .. "Spell_Frost_Stun")
  b.icon.count:SetText("")
  frameColour(b.icon, MARK.held, 0.9)
  b.icon.tip = { title = r.title, text = r.detail }
  b.amount:SetText("")
  b.title:SetText(r.title or "")
  b.detail:SetText(r.detail or "")
  b.share:Hide()
  p:place(b, 32, 4)
end

local ICON_SIZE, ICON_GAP = 32, 6
function DRAW.tools(p, r)
  local b = p:take("tools")
  b.label:SetText(r.label or "")
  local colour = STATE[r.state] or T.ring
  local perRow = math.max(1, math.floor((p.width + ICON_GAP) / (ICON_SIZE + ICON_GAP)))
  for i, t in ipairs(r.tools or {}) do
    local s = b.icons[i]
    if not s then
      s = square(b, ICON_SIZE)
      tipFor(s, nil)
      b.icons[i] = s
    end
    local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", col * (ICON_SIZE + ICON_GAP) + 2, -(18 + line * (ICON_SIZE + ICON_GAP)))
    icon(s.tex, ns.toolIcon(t))
    s.tex:SetDesaturated(r.state == "untold")
    s.tex:SetAlpha(r.state == "untold" and 0.6 or 1)
    s.count:SetText(t.count and t.count > 1 and tostring(t.count) or "")
    frameColour(s, colour)
    s.tip = toolTip(t)
    s:Show()
  end
  local n = #(r.tools or {})
  for i = n + 1, #b.icons do
    b.icons[i]:Hide()
  end
  local lines = math.max(1, math.ceil(n / perRow))
  local height = 18 + lines * (ICON_SIZE + ICON_GAP)
  b:SetHeight(height)
  p:place(b, height, 4)
end

function DRAW.tool(p, r)
  local b = p:take("tool")
  local t = r.tool
  b.title:SetText(r.title or (t and t.n) or "")
  b.title:SetTextColor(unpack(r.missing and T.soft or T.text))
  fit(b.title, p.width - 200)
  b.value:SetText(r.value or "")
  b.value:SetTextColor(unpack(r.ready and GOOD or T.soft))
  b.detail:SetText(r.detail or "")
  if r.missing then
    b.icon.tex:SetTexture(EMPTY)
    b.icon.tex:SetTexCoord(0, 1, 0, 1)
    b.icon.tex:SetDesaturated(false)
    b.icon.tex:SetAlpha(1)
    b.icon.count:SetText("")
    frameColour(b.icon, T.dim, 0.6)
    b.icon.tip = nil
  else
    icon(b.icon.tex, t and ns.toolIcon(t))
    -- (not ready now: dimmed, as the game greys a spell on cooldown)
    local waitingFor = r.ready == false and r.value ~= nil
    b.icon.tex:SetDesaturated(waitingFor)
    b.icon.tex:SetAlpha(waitingFor and 0.7 or 1)
    b.icon.count:SetText(t and t.count and t.count > 1 and tostring(t.count) or "")
    frameColour(b.icon, r.ready and GOOD or T.ring, 0.9)
    b.icon.tip = t and toolTip(t) or nil
  end
  p:place(b, (r.detail and r.detail ~= "") and 34 or 30, 4)
end

function DRAW.share(p, r)
  local b = p:take("share")
  b.title:SetText(r.title or "")
  b.value:SetText(r.value or "")
  b.bar:SetValue(math.min(1, r.share or 0))
  b.base:ClearAllPoints()
  b.base:SetShown(r.base ~= nil)
  if r.base then b.base:SetPoint("CENTER", b.bar, "LEFT", p.width * math.min(1, r.base), 0) end
  b.detail:SetText(r.detail or "")
  local height = r.detail and 40 or 28
  b:SetHeight(height)
  p:place(b, height, 4)
end

function DRAW.text(p, r, size, colour)
  local b = p:take("text")
  b.text:SetFont(K.BODY_FONT, size or ROW_TEXT, "")
  b.text:SetTextColor(unpack(colour or T.text))
  b.text:SetText(r.text or "")
  local height = b.text:GetStringHeight()
  b:SetHeight(height)
  p:place(b, height, 4)
end

-- ── the graph ────────────────────────────────────────────────────────────────
-- My health over the fight, by time, as a chart: a dark plot, its 100% and
-- 50% lines, the threshold's danger zone in red; my health a stepped line
-- (it changes at each blow and heal) over a soft fill, red where it fell into
-- the danger zone; the lowest point a dot and its value, a death a skull at
-- the end. Under it, a lane of what happened, by time: the icon of each tool I
-- used, the portrait of each foe as it joined, a red tick for each hit that
-- mattered, a purple bar for each stretch out of my control (a band in the
-- plot too); then the time. Hovered: the moment's time, my health, what
-- happened then.
local PLOT_H, LANE_H, AXIS_W = 100, 18, 30
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DANGER = { 0.88, 0.32, 0.28 }
-- (the fill under my health: the bar's blue, and the danger's red, a fifth
-- over the plot's dark)
local FILL, FILL_LOW = { 0.14, 0.19, 0.25 }, { 0.23, 0.12, 0.12 }

function Page.newGraph(parent, width)
  local g = CreateFrame("Frame", nil, parent)
  g:SetSize(width, PLOT_H + LANE_H + 18)
  g.width, g.plotW = width, width - AXIS_W - 2
  g.plot = CreateFrame("Frame", nil, g)
  g.plot:SetPoint("TOPLEFT", AXIS_W, 0)
  g.plot:SetSize(g.plotW, PLOT_H)
  g.lane = CreateFrame("Frame", nil, g)
  g.lane:SetPoint("TOPLEFT", g.plot, "BOTTOMLEFT", 0, -3)
  g.lane:SetSize(g.plotW, LANE_H)
  g.pieces, g.icons, g.labels = {}, {}, {}
  g.legend = label(parent, K.BODY_FONT, 11, T.soft)
  g.legend:SetWidth(width)
  -- (the moment under the mouse)
  g.cursor = g.plot:CreateTexture(nil, "OVERLAY", nil, 7)
  g.cursor:SetColorTexture(1, 1, 1, 0.35)
  g.cursor:SetWidth(1)
  g.cursor:Hide()
  g.plot:EnableMouse(true)
  g.plot:SetScript("OnEnter", function(self)
    self:SetScript("OnUpdate", function() g:hover() end)
  end)
  g.plot:SetScript("OnLeave", function(self)
    self:SetScript("OnUpdate", nil)
    g.cursor:Hide()
    GameTooltip:Hide()
  end)
  for k, v in pairs(Page.graphMethods) do
    g[k] = v
  end
  return g
end

local G = {}
Page.graphMethods = G

-- A piece of the chart (a texture, reused from one drawing to the next),
-- on the plot or the lane, at a layer.
function G:piece(on, layer, sub)
  self.n = self.n + 1
  local t = self.pieces[self.n]
  if not t then
    t = self.plot:CreateTexture(nil, "ARTWORK")
    self.pieces[self.n] = t
  end
  t:SetParent(on)
  t:SetDrawLayer(layer, sub or 0)
  t:SetVertexColor(1, 1, 1, 1)
  t:ClearAllPoints()
  t:Show()
  return t
end
function G:rect(on, layer, sub, colour, alpha, x, y, w, h)
  local t = self:piece(on, layer, sub)
  t:SetColorTexture(colour[1], colour[2], colour[3], alpha)
  t:SetPoint("BOTTOMLEFT", on, "BOTTOMLEFT", x, y)
  t:SetSize(math.max(1, w), math.max(1, h))
  return t
end
function G:text(i, size, colour)
  local l = self.labels[i]
  if not l then
    l = label(self, K.BODY_FONT, size, colour)
    self.labels[i] = l
  end
  l:SetFont(K.BODY_FONT, size, "")
  l:SetTextColor(unpack(colour))
  l:ClearAllPoints()
  l:Show()
  return l
end
-- An icon of the lane (a frame: its tooltip), square or round.
function G:icon(i)
  local f = self.icons[i]
  if not f then
    f = K.roundIcon(self.lane, 14, true)
    tipFor(f, nil)
    self.icons[i] = f
  end
  f:ClearAllPoints()
  f:Show()
  return f
end

-- What a mark's tool looks like: the tool as the debrief kept it, by name.
local function toolNamed(d, name)
  for _, list in ipairs({ d.ready or {}, d.unused or {} }) do
    for _, t in ipairs(list) do
      if type(t) == "table" and t.n == name then return t end
    end
  end
  return { n = name }
end

function G:draw(d, samples, threshold)
  self.n, self.d = 0, d
  local plot, lane, w = self.plot, self.lane, self.plotW
  local span = math.max(d.length or 0, samples[#samples].t or 0, d.lowT or 0, 1)
  self.span = span
  -- (on whole pixels: the steps' fills meet without a seam)
  local function x(t) return math.floor(math.max(0, math.min(1, (t or 0) / span)) * w + 0.5) end
  local function y(pct) return math.max(0, math.min(100, pct or 0)) / 100 * PLOT_H end
  -- the plot, its lines, the danger zone (over the fill: a tint)
  self:rect(plot, "BACKGROUND", 0, { 0, 0, 0 }, 0.4, 0, 0, w, PLOT_H)
  self:rect(plot, "ARTWORK", 2, DANGER, 0.13, 0, 0, w, y(threshold))
  self:rect(plot, "ARTWORK", 3, DANGER, 0.55, 0, y(threshold), w, 1)
  for _, pct in ipairs({ 50, 100 }) do
    self:rect(plot, "ARTWORK", 3, { 1, 1, 1 }, 0.08, 0, y(pct) - 1, w, 1)
  end
  self:rect(plot, "ARTWORK", 3, { 1, 1, 1 }, 0.18, 0, 0, w, 1)
  local nl = 0
  local function axis(text, pct, colour)
    nl = nl + 1
    local l = self:text(nl, 10, colour)
    l:SetPoint("RIGHT", plot, "BOTTOMLEFT", -4, y(pct))
    l:SetText(text)
  end
  axis("100%", 100, T.soft)
  axis("50%", 50, T.soft)
  axis(threshold .. "%", threshold, DANGER)
  -- out of my control: a band over the fill
  for _, h in ipairs(d.held or {}) do
    if h.to and h.to > h.t then self:rect(plot, "ARTWORK", 1, MARK.held, 0.22, x(h.t), 0, x(h.to) - x(h.t), PLOT_H) end
  end
  -- my health: a fill and a stepped line, red in the danger zone
  for i, s in ipairs(samples) do
    local from = x(s.t)
    local to = samples[i + 1] and x(samples[i + 1].t) or w
    local low = s.pct < threshold
    -- (the fill opaque, each step a pixel over the next: no seam between)
    self:rect(plot, "ARTWORK", 0, low and FILL_LOW or FILL, 1, from, 0, to - from + 1, y(s.pct))
    self:rect(plot, "OVERLAY", 0, low and DANGER or T.bar, 1, from, y(s.pct) - 1, to - from + 1, 2)
    local nextPct = samples[i + 1] and samples[i + 1].pct
    if nextPct and nextPct ~= s.pct then
      local a, b = math.min(s.pct, nextPct), math.max(s.pct, nextPct)
      self:rect(plot, "OVERLAY", 0, nextPct < threshold and DANGER or T.bar, 1, to - 1, y(a) - 1, 2, y(b) - y(a) + 2)
    end
  end
  -- the lowest point: a dot and its value; a death: a skull at its end
  local lowS
  for _, s in ipairs(samples) do
    if not lowS or s.pct < lowS.pct then lowS = s end
  end
  if d.kind == "death" then
    local skull = self:piece(plot, "OVERLAY", 3)
    skull:SetTexture(SKULL)
    skull:SetTexCoord(0, 1, 0, 1)
    skull:SetSize(16, 16)
    skull:SetPoint("BOTTOM", plot, "BOTTOMLEFT", math.min(w - 8, x(d.length or span)), 2)
  elseif lowS then
    local dot = self:piece(plot, "OVERLAY", 3)
    dot:SetTexture(MASK)
    dot:SetTexCoord(0, 1, 0, 1)
    dot:SetVertexColor(1, 1, 1, 1)
    dot:SetSize(9, 9)
    dot:SetPoint("CENTER", plot, "BOTTOMLEFT", x(lowS.t), y(lowS.pct))
    nl = nl + 1
    local l = self:text(nl, 11, { 1, 1, 1 })
    local right = x(lowS.t) > w - 70
    l:SetPoint(right and "RIGHT" or "LEFT", plot, "BOTTOMLEFT", x(lowS.t) + (right and -8 or 8), y(lowS.pct) + 8)
    l:SetText(ns.lowOf(d))
  end
  -- the lane: what happened, by time
  self:rect(lane, "BACKGROUND", 0, { 0, 0, 0 }, 0.25, 0, 0, w, LANE_H)
  local marks, kinds, ni, last = ns.marksOf(d), {}, 0, -100
  for _, m in ipairs(marks) do
    kinds[m.kind] = true
    if m.kind == "held" then
      self:rect(lane, "ARTWORK", 0, MARK.held, 0.9, x(m.t), LANE_H / 2 - 2, x(m.to) - x(m.t), 4)
    elseif m.kind == "hit" then
      self:rect(lane, "ARTWORK", 1, MARK.hit, 1, x(m.t) - 1, 2, 2, LANE_H - 4)
    else
      ni = ni + 1
      local f = self:icon(ni)
      -- (side by side when two came at once)
      local at = math.max(7, math.min(w - 7, math.max(x(m.t), last + 16)))
      last = at
      f:SetPoint("CENTER", lane, "LEFT", at, 0)
      if m.kind == "foe" then
        local foe = ns.foeNamed(d, m.text)
        portrait(f, foe)
        f.ring:SetVertexColor(unpack(MARK.foe))
        f.tip = { title = m.text, text = ("joined %d seconds in"):format(math.floor(m.t + 0.5)) }
      else
        local t = toolNamed(d, m.text)
        icon(f.tex, ns.toolIcon(t))
        f.tex:SetDesaturated(false)
        f.ring:SetVertexColor(unpack(MARK.used))
        f.tip = toolTip(t)
      end
    end
  end
  for i = ni + 1, #self.icons do
    self.icons[i]:Hide()
  end
  -- the time
  for i, t in ipairs({ 0, span / 2, span }) do
    nl = nl + 1
    local l = self:text(nl, 10, T.soft)
    local where = i == 1 and "LEFT" or i == 2 and "CENTER" or "RIGHT"
    l:SetPoint(
      "TOP" .. (where == "CENTER" and "" or where),
      lane,
      "BOTTOM" .. (where == "CENTER" and "" or where),
      0,
      -3
    )
    l:SetText(("%d s"):format(math.floor(t + 0.5)))
  end
  for i = self.n + 1, #self.pieces do
    self.pieces[i]:Hide()
  end
  for i = nl + 1, #self.labels do
    self.labels[i]:Hide()
  end
  self.shownMarks = marks -- (for the tests)
  return kinds
end

-- The moment under the mouse: a line through it, and the tooltip.
function G:hover()
  local d, plot = self.d, self.plot
  if not d or not plot:GetLeft() then return end
  local cx = GetCursorPosition() / plot:GetEffectiveScale() - plot:GetLeft()
  local t = math.max(0, math.min(1, cx / self.plotW)) * self.span
  local pct
  for _, s in ipairs(d.samples or {}) do
    if s.t <= t then pct = s.pct end
  end
  self.cursor:ClearAllPoints()
  self.cursor:SetPoint("TOP", plot, "TOPLEFT", math.max(0, math.min(self.plotW, cx)), 0)
  self.cursor:SetHeight(PLOT_H)
  self.cursor:Show()
  GameTooltip:SetOwner(plot, "ANCHOR_CURSOR")
  local health = pct and ((d.rebuilt and "about " or "") .. pct .. "% health") or ""
  GameTooltip:AddLine(("%d s   %s"):format(math.floor(t + 0.5), health), 1, 1, 1)
  local near = math.max(1, self.span / 40)
  for _, m in ipairs(ns.marksOf(d)) do
    local to = m.to or m.t
    if t >= m.t - near and t <= to + near then
      local c = MARK[m.kind]
      GameTooltip:AddLine(m.text, c[1], c[2], c[3], true)
    end
  end
  GameTooltip:Show()
end

-- The chart on a page, at its place; its legend under it.
function Page:graphOf(d)
  local g = self.graph
  local samples = d.samples or {}
  g:ClearAllPoints()
  g:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
  g:SetShown(#samples > 1)
  g.legend:SetShown(false)
  if #samples <= 1 then return end
  local threshold = ns.option("threshold")
  local kinds = g:draw(d, samples, threshold)
  self.y = self.y + g:GetHeight() + 8
  local words = { K.hex(DANGER) .. ("below %d%%, your threshold"):format(threshold) .. "|r" }
  for _, l in ipairs(LEGEND) do
    if kinds[l[1]] then table.insert(words, K.hex(MARK[l[1]]) .. l[2] .. "|r") end
  end
  g.legend:ClearAllPoints()
  g.legend:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
  g.legend:SetText(table.concat(words, "   "))
  g.legend:Show()
  self.y = self.y + g.legend:GetStringHeight() + 12
end

-- ── a page drawn ─────────────────────────────────────────────────────────────
-- c: what it shows; d: a debrief (my health over the fight), or nil; keep:
-- where it was scrolled to stays (a page drawn again as it changes).
function Page:draw(c, d, keep)
  for _, pool in pairs(self.pools) do
    for i = 1, pool.n do
      pool[i]:Hide()
    end
    pool.n = 0
  end
  self.title:SetText(c.title)
  self.title:SetTextColor(unpack(c.death and DEATH or T.accent))
  self.sub:SetText(c.sub or "")
  face(self.portrait, c.face, c.death)
  self.y = HEADER_H
  for _, lesson in ipairs(c.lessons or {}) do
    local b = self:take("lesson")
    b.bar:SetColorTexture(unpack(c.death and DEATH or T.accent))
    b.text:SetText(lesson)
    local height = b.text:GetStringHeight()
    b:SetHeight(height)
    self:place(b, height, 8)
  end
  if self.hasGraph then
    if d then
      self.y = self.y + 4
      self:graphOf(d)
    else
      self.graph:Hide()
      self.graph.legend:Hide()
    end
  end
  for _, s in ipairs(c.sections or {}) do
    local h = self:take("heading")
    h.text:SetText(s.heading)
    self:place(h, 24, 8)
    for i, l in ipairs(s.lines) do
      local r = s.rows and s.rows[i]
      if s.note then
        DRAW.text(self, { text = l }, 11, T.soft)
      elseif r and DRAW[r.kind] then
        DRAW[r.kind](self, r)
      else
        DRAW.text(self, { text = l })
      end
    end
    self.y = self.y + 6
  end
  self.child:SetHeight(self.y + 16)
  self:ScrollTo(keep and self:GetVerticalScroll() or 0)
  self.shown = c -- (for the tests)
end
