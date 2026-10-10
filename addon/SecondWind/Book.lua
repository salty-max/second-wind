-- The book: the standard game window (portrait, title bar) and its tabs. The
-- Debriefs: the list on the left (newest first), the open one's card on the
-- right (Debrief.lua's text: its title, the line under it, the lessons, my
-- health over the fight drawn as bars against the threshold, its sections).
-- The Patterns: what the close calls share (PLAN.md, step 4: a word until
-- then). A debrief written: a line in chat with a link to it, the game's
-- alert, and after a death the book opened at it (settings). /wind opens it.
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
local DEATH = { 0.86, 0.45, 0.42 } -- a death's title, and the bar at its end
local label, panel, rule = K.label, K.panel, K.rule

local TITLE = "Second Wind"
local ICON = "Interface\\Icons\\Spell_Nature_Rejuvenation"
local TAB = { debriefs = 1, patterns = 2 }
ns.TAB = TAB
local TAB_TITLES = { "Debriefs", "Patterns" }
local LIST_W, ROW_H, CARD_W, PAGE_W, GRAPH_H = 236, 38, 470, 704, 60

local function emptyText(n, count)
  if n == TAB.patterns then
    return (
      "What your close calls have in common shows here once three are written (%s so far): how they "
      .. "began, how many foes, which kinds, where."
    ):format(count == 0 and "none" or tostring(count))
  end
  return (
    "No close call yet. When a fight leaves you below %d%% health, or ends you, its debrief is written "
    .. "here: how it went, what you had ready and didn't use, and what to take from it."
  ):format(ns.option("threshold"))
end

local book

-- ── the list ─────────────────────────────────────────────────────────────────
local function row(i)
  local r = book.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, book.list.child)
  r:SetSize(LIST_W - 22, ROW_H)
  r:SetPoint("TOPLEFT", 4, -(i - 1) * ROW_H - 4)
  r.mark = K.highlight(r)
  r.title = label(r, K.BODY_FONT, 13, T.text)
  r.title:SetPoint("TOPLEFT", 8, -5)
  r.title:SetWidth(LIST_W - 36)
  r.title:SetWordWrap(false)
  r.sub = label(r, K.BODY_FONT, 11, T.soft)
  r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
  r.sub:SetWidth(LIST_W - 36)
  r.sub:SetWordWrap(false)
  r:SetScript("OnClick", function(self)
    book.open = self.at
    ns.refresh()
  end)
  book.rows[i] = r
  return r
end

-- ── pages ────────────────────────────────────────────────────────────────────
-- A page of the sheet: a scroll area, its title, labels drawn top to bottom
-- (reused from one drawing to the next) and, for a card, my health over the
-- fight. Drawn from Debrief.lua's card or Patterns.lua's page: { title, sub,
-- lessons, sections = { { heading, lines } } }.
local function newPage(name, x, width, withGraph)
  local p = K.scrollArea(book.sheet, width, name)
  p:SetPoint("TOPLEFT", x, -16)
  p:SetPoint("BOTTOMRIGHT", -20, 12)
  p.width, p.lines, p.hasGraph = width, {}, withGraph and true or false
  p.title = label(p.child, K.TITLE_FONT, 20, T.accent)
  p.title:SetPoint("TOPLEFT", 0, 0)
  p.title:SetWidth(width)
  if withGraph then
    local g = CreateFrame("Frame", nil, p.child)
    g:SetSize(width, GRAPH_H)
    g.bars = {}
    g.threshold = g:CreateTexture(nil, "OVERLAY")
    g.threshold:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.5)
    local base = rule(g)
    base:SetPoint("BOTTOMLEFT")
    base:SetWidth(width)
    p.graph = g
  end
  return p
end

local function line(p, i, size, colour)
  local l = p.lines[i]
  if not l then
    l = label(p.child, K.BODY_FONT, size, colour)
    l:SetWidth(p.width)
    l:SetJustifyH("LEFT")
    p.lines[i] = l
  end
  l:SetFont(K.BODY_FONT, size, "")
  l:SetTextColor(unpack(colour))
  l:Show()
  return l
end

-- My health over the fight: a bar for each sample, the threshold a line.
local function graph(p, d, y)
  local g = p.graph
  local samples = d.samples or {}
  g:SetPoint("TOPLEFT", 0, -y)
  g:SetShown(#samples > 1)
  if #samples <= 1 then return y end
  local w = p.width / #samples
  for i, s in ipairs(samples) do
    local bar = g.bars[i]
    if not bar then
      bar = g:CreateTexture(nil, "ARTWORK")
      g.bars[i] = bar
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", (i - 1) * w, 0)
    bar:SetSize(math.max(1, w - 1), math.max(1, GRAPH_H * s.pct / 100))
    local low = s.pct == d.lowPct
    local colour = low and (d.kind == "death" and DEATH or T.accent) or T.bar
    bar:SetColorTexture(colour[1], colour[2], colour[3], low and 1 or 0.6)
    bar:Show()
  end
  for i = #samples + 1, #g.bars do
    g.bars[i]:Hide()
  end
  g.threshold:ClearAllPoints()
  g.threshold:SetPoint("BOTTOMLEFT", 0, GRAPH_H * ns.option("threshold") / 100)
  g.threshold:SetSize(p.width, 1)
  return y + GRAPH_H + 14
end

-- A page drawn: c its text; d a debrief (its health over the fight), or nil.
local function drawPage(p, c, d)
  local n, y = 0, 30
  local function put(text, size, colour, gap)
    n = n + 1
    local l = line(p, n, size, colour)
    y = y + (gap or 0)
    l:SetPoint("TOPLEFT", 0, -y)
    l:SetText(text)
    y = y + l:GetStringHeight() + 4
  end
  p.title:SetText(c.title)
  p.title:SetTextColor(unpack(d and d.kind == "death" and DEATH or T.accent))
  put(c.sub, 11, T.soft)
  for _, lesson in ipairs(c.lessons) do
    put(lesson, 13, T.text, 6)
  end
  if p.hasGraph and d then y = graph(p, d, y + 12) end
  for _, s in ipairs(c.sections) do
    put(s.heading, 13, T.accent, 6)
    for _, l in ipairs(s.lines) do
      put(l, 12, T.text)
    end
  end
  for i = n + 1, #p.lines do
    p.lines[i]:Hide()
  end
  p.child:SetHeight(y + 10)
  p:ScrollTo(0)
  p.shown = c -- (for the tests)
end

-- ── the book ─────────────────────────────────────────────────────────────────
local function find(debriefs, at)
  for i = #debriefs, 1, -1 do
    if debriefs[i].at == at then return debriefs[i] end
  end
end

-- Rewrite what the open tab shows.
function ns.refresh()
  if not book then return end
  local record = ns.record()
  local debriefs = record and record.debriefs or {}
  book.count:SetText(#debriefs == 1 and "1 debrief" or ("%d debriefs"):format(#debriefs))
  local listing = book.selectedTab == TAB.debriefs and #debriefs > 0
  local patterns = book.selectedTab == TAB.patterns and ns.patternsOf(debriefs) or nil
  local studied = patterns ~= nil and patterns.enough
  book.list:SetShown(listing)
  book.left:SetShown(listing)
  book.card:SetShown(listing)
  book.patterns:SetShown(studied)
  book.empty:SetShown(not listing and not studied)
  if studied then return drawPage(book.patterns, patterns) end
  if not listing then
    book.empty:SetText(emptyText(book.selectedTab, #debriefs))
    return
  end
  local open = find(debriefs, book.open) or debriefs[#debriefs]
  book.open = open.at
  local n = 0
  for i = #debriefs, 1, -1 do
    n = n + 1
    local d, r = debriefs[i], row(n)
    r.at = d.at
    r.title:SetText(d.kind == "death" and "Death" or ("Close call: %d%%"):format(d.lowPct or 0))
    r.title:SetTextColor(unpack(d.kind == "death" and DEATH or T.text))
    r.sub:SetText((d.sub or d.zone or "?") .. " · " .. date("%d %b", d.at))
    r.mark:SetShown(d == open)
    r:Show()
  end
  for i = n + 1, #book.rows do
    book.rows[i]:Hide()
  end
  book.list.child:SetHeight(n * ROW_H + 8)
  book.list:UpdateThumb()
  drawPage(book.card, ns.cardOf(open), open)
  book.cardShown = book.card.shown -- (for the tests)
end

-- The tab n shown.
function ns.showTab(n)
  if not book then return end
  book.selectedTab = n
  if PanelTemplates_SetTab then PanelTemplates_SetTab(book, n) end
  ns.refresh()
end

-- The standard game window, else a plain dialog where the client has no such
-- template (Kit.lua).
local function build()
  local window = K.gameWindow("SecondWindFrame", TITLE, ICON)
  book = window or K.dialog("SecondWindFrame", TITLE)
  K.movable(book, 760, 520)
  book.rows = {}

  local edge = window and 8 or 14
  book.count = label(book, K.BODY_FONT, 11, T.accent)
  book.count:SetPoint("TOPLEFT", 64, -36)
  -- (the sheet over the whole window: the empty tabs' word in its middle;
  -- the list's panel above its left part)
  book.sheet = panel(book)
  book.sheet:SetPoint("TOPLEFT", edge, -58)
  book.sheet:SetPoint("BOTTOMRIGHT", -edge, edge)
  book.left = panel(book, true)
  book.left:SetPoint("TOPLEFT", edge, -58)
  book.left:SetPoint("BOTTOMLEFT", edge, edge)
  book.left:SetWidth(LIST_W)
  book.left:SetFrameLevel(book.sheet:GetFrameLevel() + 2)
  book.list = K.scrollArea(book.left, LIST_W - 16, "SecondWindList")
  book.list:SetPoint("TOPLEFT", 4, -6)
  book.list:SetPoint("BOTTOMRIGHT", -12, 6)
  book.empty = label(book.sheet, K.BODY_FONT, 13, T.soft)
  book.empty:SetPoint("CENTER")
  book.empty:SetWidth(420)
  book.empty:SetJustifyH("CENTER")

  -- the card, right of the list; the patterns, the whole sheet
  book.card = newPage("SecondWindCard", LIST_W + 20, CARD_W, true)
  book.patterns = newPage("SecondWindPatterns", 20, PAGE_W, false)

  book.selectedTab = TAB.debriefs
  book:SetScript("OnShow", function() ns.showTab(book.selectedTab) end)
  K.tabs(book, TAB_TITLES, function(n) ns.showTab(n) end)
end

local function window()
  if not book then build() end
  return book
end
ns.window = window -- (for the tests)

function ns.toggle() window():SetShown(not book:IsShown()) end

-- The book open at a debrief (by when it was written).
function ns.openDebrief(at)
  window()
  book.open = at
  book.selectedTab = TAB.debriefs
  if book:IsShown() then
    ns.showTab(TAB.debriefs)
  else
    book:Show() -- (its OnShow shows the tab)
  end
end

-- ── a debrief written ────────────────────────────────────────────────────────
function ns.link(at, text) return ("|cffa8c7e0|Hsecondwind:debrief:%d|h[%s]|h|r"):format(at, text) end

-- The game's alert: the new recipe's (an icon, a title, a name), a click
-- opens the debrief (a right-click dismisses it).
local TOAST = "NewRecipeLearnedAlertFrameTemplate"
local toasts
local function setUp(frame, d)
  frame.secondWindAt = d.at
  if frame.Icon then frame.Icon:SetTexture(ICON) end
  frame.Title:SetText(d.kind == "death" and "Death" or ("Close call: %d%%"):format(d.lowPct or 0))
  frame.Name:SetText(d.sub or d.zone or "")
  if AlertFrame_SetDuration then AlertFrame_SetDuration(frame, 12) end
  frame:SetScript("OnClick", function(self, button, down)
    if AlertFrame_OnClick and AlertFrame_OnClick(self, button, down) then return end
    if self.secondWindAt then ns.openDebrief(self.secondWindAt) end
  end)
end
local function toast(d)
  if not toasts then
    if not (AlertFrame and AlertFrame.AddQueuedAlertFrameSubSystem and C_XMLUtil and C_XMLUtil.GetTemplateInfo) then
      return
    end
    if not C_XMLUtil.GetTemplateInfo(TOAST) then return end
    toasts = AlertFrame:AddQueuedAlertFrameSubSystem(TOAST, setUp, 2, 6)
  end
  toasts:AddAlert(d)
end

function ns.debriefed(d)
  if ns.option("chat") then print(ns.PREFIX .. ns.summaryOf(d) .. ". " .. ns.link(d.at, "Debrief")) end
  if ns.option("toast") then toast(d) end
  if d.kind == "death" and ns.option("openAfterDeath") then ns.openDebrief(d.at) end
  if book and book:IsShown() then ns.refresh() end
end

-- Links in chat (|Hsecondwind:debrief:<at>|h): the game hands a link of an
-- unknown type to the handler registered for it.
local function followLink(link)
  local at = tonumber(link:match("^secondwind:debrief:(%d+)$") or "")
  if at then ns.openDebrief(at) end
end
if LinkUtil and LinkUtil.RegisterLinkHandler then
  LinkUtil.RegisterLinkHandler("secondwind", function(link)
    followLink(link)
    return LinkProcessorResponse and LinkProcessorResponse.Handled
  end)
elseif hooksecurefunc and SetItemRef then
  -- Clients without the link registry still pass every click to SetItemRef.
  hooksecurefunc("SetItemRef", function(link) followLink(link) end)
end
