-- The book: the kit's (K.book: the game's window, its portrait and title bar,
-- the list on the left, the page on the right, the search, the tabs). The
-- Debriefs: the list on the left (newest first, this character's or every
-- character's: the select under the search), the open one's card on the
-- right (Debrief.lua's, drawn by Page.lua on the kit's page: the foe's
-- portrait at its head, the lessons, my health over the fight against the
-- threshold, marked with what happened in it, its sections, their foes, blows
-- and tools with their pictures), and a button to copy it as text. The
-- Patterns: what the close calls share (Patterns.lua), set against every
-- fight's, over the whole window, whose to pick at its head. The Lifelines:
-- what I carry for the worst moments, now (Tools.lua's page), over the whole
-- window. A debrief written: a line in chat with a link to it, a banner among
-- the game's alerts, and after a death the book opened at it (settings).
-- /wind opens it.
local _, ns = ...

local K = ns.kit
local L = K.L
local T = K.T
local DEATH = ns.DEATH -- (Page.lua: the look, its theme, its pages)
local label = K.label

local TITLE = "Second Wind"
local ICON = "Interface\\AddOns\\SecondWind\\Media\\Logo"
local TAB = { debriefs = 1, patterns = 2, carry = 3 }
ns.TAB = TAB
-- (the patterns and the lifelines over the whole window: a page as wide as
-- both panels, its text 28px short of its frame, as every page's)
local WHOLE_W = 688

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

-- ── the book ─────────────────────────────────────────────────────────────────
-- (whose debriefs: this character's, or every character's of this game: the
-- Debriefs' select, the Patterns' names to pick)
local WHOSE = { { value = "mine", text = L["This character"] }, { value = "every", text = L["Every character"] } }
local B = K.book({
  name = "SecondWindFrame",
  title = TITLE,
  art = ICON,
  place = function()
    SecondWindSettings = SecondWindSettings or {}
    return K.place(SecondWindSettings, "book")
  end,
  titles = { L["Debriefs"], L["Patterns"], L["Lifelines"] },
  first = TAB.debriefs,
  search = "SecondWindSearch",
  filter = true,
})
local book -- (the window, B.frame: its pages and list, for the tests)
local rows = {}
local function every() return B:filterOf(TAB.debriefs) == "every" end

local function find(debriefs, at)
  for i = #debriefs, 1, -1 do
    if debriefs[i].at == at then return debriefs[i] end
  end
end

-- The count beside the portrait: how many debriefs, whose.
local function counted(debriefs)
  local count = K.plural(#debriefs, "%d debrief", "%d debriefs"):format(#debriefs)
  if every() then
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
end

-- A row's two lines: what it was, and whose, where and when.
local function rowTitle(d) return d.kind == "death" and L["Death"] or L["Close call: %s"]:format(ns.lowOf(d, true)) end
local function rowUnder(d)
  local who = every() and ns.whose(d).name and (ns.whose(d).name .. " · ") or ""
  return who .. (d.sub or d.zone or "?") .. " · " .. ns.date(d.at)
end

-- The Debriefs: the list (those the search finds), the open one's card.
local function refreshDebriefs(scroll)
  local debriefs = ns.debriefsOf(every())
  counted(debriefs)
  if #debriefs == 0 then
    book.list:begin()
    book.list:finish()
    return book.card:draw(emptyPage(TAB.debriefs, 0), nil, not scroll)
  end
  local open = find(debriefs, book.open) or debriefs[#debriefs]
  book.open = open.at
  local q = K.query(book.search)
  book.list:begin()
  for i = #debriefs, 1, -1 do
    local d = debriefs[i]
    local title, under = rowTitle(d), rowUnder(d)
    if K.finds(title .. " " .. under, q) then
      local r = book.list:add("entry", title, nil, under)
      r.at = d.at
      r:SetScript("OnClick", function(self)
        book.open = self.at
        ns.refresh()
      end)
      if d == open then book.list:pick(r) end
      -- (a death in its red, picked or not)
      if d.kind == "death" then r.text:SetTextColor(unpack(DEATH)) end
    end
  end
  book.list:finish(scroll)
  -- (another character's: whose it is, on the line under the title)
  local c = ns.cardOf(open)
  local rec = ns.whose(open)
  if every() and rec ~= ns.record() and rec.name then
    local class = ns.className(rec.classFile, rec.class)
    local about = { class and ns.noun(class) or nil, rec.fallen and L["fallen"] or nil }
    c.sub = ("%s%s · %s"):format(rec.name, #about > 0 and (" (" .. table.concat(about, ", ") .. ")") or "", c.sub)
  end
  c.buttons = { { L["Copy as text"], function() ns.copyDebrief() end } }
  book.card:draw(c, open, not scroll)
  book.cardShown = book.card.shown -- (for the tests)
end

-- The Patterns: what the close calls share, or what the tab will hold;
-- whose, to pick at its head.
local function refreshPatterns(scroll)
  local debriefs = ns.debriefsOf(every())
  counted(debriefs)
  local patterns = ns.patternsOf(debriefs, ns.fightsOf(every()))
  local page = patterns.enough and patterns or emptyPage(TAB.patterns, #debriefs)
  page.chips = {}
  for _, w in ipairs(WHOSE) do
    table.insert(page.chips, {
      w.text,
      function()
        B:setFilter(TAB.debriefs, w.value)
        ns.refresh()
      end,
      B:filterOf(TAB.debriefs) == w.value,
    })
  end
  book.patterns:draw(page, nil, not scroll)
end

-- A tab over the whole window: a panel over both, its page.
local function whole(n, name, draw)
  local panel, page
  B:add(n, {
    whole = true,
    build = function(f)
      book = f
      panel = K.panel(f)
      panel:SetPoint("TOPLEFT", f.left, "TOPLEFT")
      panel:SetPoint("BOTTOMRIGHT", f.sheet, "BOTTOMRIGHT")
      page = ns.newPage(panel, name, WHOLE_W)
      f[n == TAB.patterns and "patterns" or "carry"] = page
    end,
    show = function(shown)
      panel:SetShown(shown == n)
      page:SetShown(shown == n)
    end,
    refresh = function(scroll) draw(page, scroll) end,
  })
end

B:add(TAB.debriefs, {
  build = function(f)
    book = f
    book.rows = rows
    book.scope = f.filter -- (for the tests)
    book.list = K.list(f.left, nil, rows, true, "SecondWindList")
    book.card = ns.newPage(f.sheet, "SecondWindCard", nil, true)
  end,
  show = function(n)
    book.list:SetShown(n == TAB.debriefs)
    book.card:SetShown(n == TAB.debriefs)
  end,
  refresh = refreshDebriefs,
  filter = { default = "mine", options = function() return WHOSE end },
})
whole(TAB.patterns, "SecondWindPatterns", function(_, scroll) refreshPatterns(scroll) end)
whole(TAB.carry, "SecondWindCarry", function(page, scroll)
  counted(ns.debriefsOf(every()))
  page:draw(ns.carryPage(ns.carried()), nil, not scroll)
end)

-- Rewrite what the open tab shows (keep: where a page was scrolled to).
function ns.refresh(keep) B:refresh(not keep) end

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
  local debriefs = ns.debriefsOf(every())
  local d = book and find(debriefs, book.open) or debriefs[#debriefs]
  if not d then return false end
  ns.showCopy(ns.textOf(d))
  return true
end

-- The window (made on first use: for the tests), a tab shown, the book
-- toggled, opened at a tab.
function ns.window()
  book = B:window()
  return book
end
function ns.showTab(n)
  if B.frame then B:show(n) end
end
function ns.toggle() B:toggle() end
function ns.openTab(n) B:open(n) end

-- The lifelines, drawn again as they change while their tab is open.
local function carried()
  if book and book:IsShown() and book.selectedTab == TAB.carry then ns.refresh(true) end
end
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED" }) do
  ns.on(e, carried)
end

-- The book open at a debrief (by when it was written).
function ns.openDebrief(at)
  B:window()
  book = B.frame
  book.open = at
  B:open(TAB.debriefs)
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
    kicker = d.kind == "death" and L["Death"] or L["Close call: %s"]:format(ns.lowOf(d, true)),
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
