-- The book: the standard game window (portrait, title bar) and its tabs. The
-- Debriefs: the list on the left (newest first), the open one's card on the
-- right (Debrief.lua's, drawn by Page.lua: the foe's portrait at its head, the
-- lessons, my health over the fight against the threshold, marked with what
-- happened in it, its sections, their foes, blows and tools with their
-- pictures), and a button to copy it as text. The Patterns: what the close
-- calls share (Patterns.lua), set against every fight's. The Lifelines: what
-- I carry for the worst moments, now (Tools.lua's page). A debrief written: a
-- line in chat with a link to it, a banner among the game's alerts, and after a death the
-- book opened at it (settings). /wind opens it.
local _, ns = ...

local K = ns.kit
local L = K.L
local T = K.T
local DEATH = ns.DEATH -- (Page.lua: the look, its theme, its pages)
local label, panel = K.label, K.panel

local TITLE = "Second Wind"
local ICON = "Interface\\AddOns\\SecondWind\\Media\\Logo"
local TAB = { debriefs = 1, patterns = 2, carry = 3 }
ns.TAB = TAB
local TAB_TITLES = { L["Debriefs"], L["Patterns"], L["Lifelines"] }
-- (a page's text stops 28px short of its frame, as the other books' do: the
-- scroll thumb sits in that margin)
local LIST_W, ROW_H, CARD_W, PAGE_W = 236, 38, 440, 676

-- A tab with nothing to show yet: a page all the same, what it will hold.
local function emptyText(n, count)
  if n == TAB.patterns then
    return L["What your close calls have in common shows here once three are written (%s so far): how they began, how many foes, which kinds, where."]:format(
      count == 0 and L["none"] or tostring(count)
    )
  end
  return L["No close call yet. When a fight leaves you below %d%% health, or ends you, its debrief is written here: how it went, what you had ready and didn't use, and what to take from it."]:format(
    ns.option("threshold")
  )
end
local function emptyPage(n, count)
  local patterns = n == TAB.patterns
  return {
    title = patterns and L["Patterns"] or L["Debriefs"],
    sub = patterns and L["%s of the three it takes"]:format(count == 0 and L["None"] or tostring(count))
      or L["Nothing written yet"],
    face = { icon = ICON },
    lessons = {},
    sections = { { heading = L["What comes here"], lines = { emptyText(n, count) } } },
  }
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

-- ── the book ─────────────────────────────────────────────────────────────────
local function find(debriefs, at)
  for i = #debriefs, 1, -1 do
    if debriefs[i].at == at then return debriefs[i] end
  end
end

-- Rewrite what the open tab shows (keep: where a page was scrolled to).
function ns.refresh(keep)
  if not book then return end
  -- (this character's, or every character's of this game: the select above)
  local every = book.every
  local debriefs = ns.debriefsOf(every)
  local count = K.plural(#debriefs, "%d debrief", "%d debriefs"):format(#debriefs)
  if every then
    local whose = {}
    for _, d in ipairs(debriefs) do
      whose[ns.whose(d)] = true
    end
    local n = 0
    for _ in pairs(whose) do
      n = n + 1
    end
    count = count .. K.plural(n, ", %d character", ", %d characters"):format(n)
  end
  book.count:SetText(count)
  local listing = book.selectedTab == TAB.debriefs and #debriefs > 0
  local patterns = book.selectedTab == TAB.patterns and ns.patternsOf(debriefs, ns.fightsOf(every)) or nil
  local studied = patterns ~= nil and patterns.enough
  local carrying = book.selectedTab == TAB.carry
  book.scope:SetShown(not carrying)
  book.list:SetShown(listing)
  book.left:SetShown(listing)
  book.card:SetShown(listing)
  book.copy:SetShown(listing)
  local empty = not listing and not studied and not carrying
  book.patterns:SetShown(studied or empty) -- (the whole sheet: the patterns, or what a tab will hold)
  book.carry:SetShown(carrying)
  if carrying then return book.carry:draw(ns.carryPage(ns.carried()), nil, keep) end
  if studied then return book.patterns:draw(patterns, nil, keep) end
  if empty then return book.patterns:draw(emptyPage(book.selectedTab, #debriefs), nil, keep) end
  local open = find(debriefs, book.open) or debriefs[#debriefs]
  book.open = open.at
  local n = 0
  for i = #debriefs, 1, -1 do
    n = n + 1
    local d, r = debriefs[i], row(n)
    r.at = d.at
    r.title:SetText(d.kind == "death" and L["Death"] or L["Close call: %s"]:format(ns.lowOf(d)))
    r.title:SetTextColor(unpack(d.kind == "death" and DEATH or T.text))
    local who = every and ns.whose(d).name and (ns.whose(d).name .. " · ") or ""
    r.sub:SetText(who .. (d.sub or d.zone or "?") .. " · " .. ns.date(d.at))
    r.mark:SetShown(d == open)
    r:Show()
  end
  for i = n + 1, #book.rows do
    book.rows[i]:Hide()
  end
  book.list.child:SetHeight(n * ROW_H + 8)
  book.list:UpdateThumb()
  -- (another character's: whose it is, on the line under the title)
  local c = ns.cardOf(open)
  local rec = ns.whose(open)
  if every and rec ~= ns.record() and rec.name then
    local class = ns.className(rec.classFile, rec.class)
    local about = { class and ns.noun(class) or nil, rec.fallen and L["fallen"] or nil }
    c.sub = ("%s%s · %s"):format(rec.name, #about > 0 and (" (" .. table.concat(about, ", ") .. ")") or "", c.sub)
  end
  book.card:draw(c, open, keep)
  book.cardShown = book.card.shown -- (for the tests)
end

-- ── the debrief as text ──────────────────────────────────────────────────────
-- A box holding it, selected, to copy (Ctrl+C): for a guild's channel, a
-- Discord. The text stays as it is whatever is typed.
local copier
function ns.showCopy(text)
  if not copier then
    copier = K.dialog("SecondWindCopy", L["The debrief, as text"])
    K.movable(copier, 540, 400)
    local note = label(copier, K.BODY_FONT, 11, T.soft)
    note:SetPoint("TOPLEFT", 22, -42)
    note:SetText(L["Copy it (Ctrl+C), then paste it where you like."])
    copier.scroll = K.scrollArea(copier, 480, "SecondWindCopyScroll")
    copier.scroll:SetPoint("TOPLEFT", 22, -64)
    copier.scroll:SetPoint("BOTTOMRIGHT", -34, 20)
    local box = CreateFrame("EditBox", nil, copier.scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(480)
    box:SetScript("OnEscapePressed", function() copier:Hide() end)
    box:SetScript("OnTextChanged", function(self, typed)
      if typed then
        self:SetText(copier.text)
        self:HighlightText()
      end
    end)
    copier.scroll:SetScrollChild(box)
    copier.scroll.child = box
    copier.box = box
  end
  copier.text = text
  copier.box:SetText(text)
  copier:Show()
  copier.box:SetFocus()
  copier.box:HighlightText()
  copier.scroll:ScrollTo(0)
  return copier
end

-- The open debrief (or the last one) as text; false if there is none.
function ns.copyDebrief()
  local debriefs = ns.debriefsOf(book and book.every)
  local d = book and find(debriefs, book.open) or debriefs[#debriefs]
  if not d then return false end
  ns.showCopy(ns.textOf(d))
  return true
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
  SecondWindSettings = SecondWindSettings or {}
  K.movable(book, K.BOOK_W, K.BOOK_H, K.place(SecondWindSettings, "book"))
  book.rows = {}

  local edge = window and 8 or 14
  book.count = label(book, K.BODY_FONT, 11, T.accent)
  book.count:SetPoint("TOPLEFT", 64, -36)
  -- (the sheet over the whole window; the list's panel above its left part)
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

  -- the card, right of the list (its button to copy it above); the patterns
  -- and the lifelines, the whole sheet
  book.card = ns.newPage(book.sheet, "SecondWindCard", LIST_W + 20, CARD_W, true)
  book.patterns = ns.newPage(book.sheet, "SecondWindPatterns", 20, PAGE_W, false)
  book.carry = ns.newPage(book.sheet, "SecondWindCarry", 20, PAGE_W, false)
  book.copy = K.button(book, L["Copy as text"], 120)
  book.copy:SetPoint("TOPRIGHT", -14, -31)
  book.copy:SetScript("OnClick", function() ns.copyDebrief() end)
  -- (whose debriefs: this character's, or every character's of this game)
  book.scope = K.select(book, 150, L["This character"])
  book.scope:SetPoint("TOPRIGHT", -142, -31)
  book.scope:SetOptions({
    { value = "mine", text = L["This character"] },
    { value = "every", text = L["Every character"] },
  })
  book.scope:SetValue("mine")
  book.every = false
  book.scope.onChange = function(v)
    book.every = v == "every"
    book.open = nil
    ns.refresh()
  end

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

-- The book open at a tab.
function ns.openTab(n)
  window()
  book.selectedTab = n
  if book:IsShown() then
    ns.showTab(n)
  else
    book:Show()
  end
end

-- The lifelines, drawn again as they change while their tab is open.
local function carried()
  if book and book:IsShown() and book.selectedTab == TAB.carry then ns.refresh(true) end
end
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED" }) do
  ns.on(e, carried)
end

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
-- Links in chat (|Hsecondwind:debrief:<at>|h, the kit's): the game hands a
-- link of an unknown type to the handler registered for it.
local link = K.links("secondwind", function(target)
  local at = tonumber(target:match("^debrief:(%d+)$") or "")
  if at then ns.openDebrief(at) end
end)
function ns.link(at, text) return link("debrief:" .. at, text) end

-- The banner (the kit's, among the game's alerts): what it was, where; a
-- click opens the debrief, a right-click or its cross dismisses it.
local banners
local function toast(d)
  banners = banners
    or K.banners({ name = "SecondWindBanner", art = ICON, seconds = function() return ns.option("bannerSeconds") end })
  banners:show({
    picture = ICON,
    kicker = d.kind == "death" and L["Death"] or L["Close call: %s"]:format(ns.lowOf(d)),
    title = d.sub or d.zone or "",
    tip = L["Click to read its debrief"],
    click = function() ns.openDebrief(d.at) end,
    at = d.at,
  })
end

function ns.debriefed(d)
  -- (its weightiest lesson in the line: the gist without opening anything;
  -- the banner after a death only, a close call's line being enough)
  local lesson = ns.lessonsOf(d)[1]
  local line = lesson and L["%s: %s"]:format(ns.summaryOf(d), lesson) or L["%s."]:format(ns.summaryOf(d))
  print(ns.PREFIX .. line .. " " .. ns.link(d.at, L["Debrief"]))
  if d.kind == "death" and ns.option("toast") then toast(d) end
  if d.kind == "death" and ns.option("openAfterDeath") then ns.openDebrief(d.at) end
  if book and book:IsShown() then ns.refresh() end
end
