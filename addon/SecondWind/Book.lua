-- The book: the standard game window (portrait, title bar), its tabs (the
-- debriefs, the patterns) and the kit its pages are made of (Kit.lua).
-- /wind opens it. Until the card (PLAN.md, step 3) the debriefs are listed a
-- line each, and the patterns' tab says what it will hold.
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
local label, panel = K.label, K.panel

local TITLE = "Second Wind"
local TAB = { debriefs = 1, patterns = 2 }
ns.TAB = TAB
local TAB_TITLES = { "Debriefs", "Patterns" }

-- What a tab holds while it holds nothing yet.
local function emptyText(n)
  if n == TAB.patterns then
    return "What your close calls have in common shows here once a few are written: how they began, how "
      .. "many foes, which kinds, where."
  end
  return (
    "No close call yet. When a fight leaves you below %d%% health, or ends you, its debrief is written "
    .. "here: how it went, what you had ready and didn't use, and what to take from it."
  ):format(ns.option("threshold"))
end

local book

-- The debriefs, newest first, a line each (until the card).
local LISTED = 30
local function listed(debriefs)
  local lines = {}
  for i = #debriefs, math.max(1, #debriefs - LISTED + 1), -1 do
    local d = debriefs[i]
    table.insert(lines, date("%d %b %H:%M", d.at) .. "  " .. ns.summaryOf(d))
  end
  return table.concat(lines, "\n")
end

-- Rewrite what the open tab shows.
function ns.refresh()
  if not book then return end
  local record = ns.record()
  local debriefs = record and record.debriefs or {}
  book.count:SetText(#debriefs == 1 and "1 debrief" or ("%d debriefs"):format(#debriefs))
  if book.selectedTab == TAB.debriefs and #debriefs > 0 then
    book.empty:SetJustifyH("LEFT")
    book.empty:SetText(listed(debriefs))
  else
    book.empty:SetJustifyH("CENTER")
    book.empty:SetText(emptyText(book.selectedTab))
  end
end

-- A debrief written: a line in chat (the setting's), until the card's alert.
function ns.debriefed(d)
  if ns.option("chat") then print(ns.PREFIX .. ns.summaryOf(d) .. ".") end
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
  local window = K.gameWindow("SecondWindFrame", TITLE, "Interface\\Icons\\Spell_Nature_Rejuvenation")
  book = window or K.dialog("SecondWindFrame", TITLE)
  K.movable(book, 760, 520)

  local edge = window and 8 or 14
  book.count = label(book, K.BODY_FONT, 11, T.accent)
  book.count:SetPoint("TOPLEFT", 64, -36)
  book.sheet = panel(book)
  book.sheet:SetPoint("TOPLEFT", edge, -58)
  book.sheet:SetPoint("BOTTOMRIGHT", -edge, edge)
  book.empty = label(book.sheet, K.BODY_FONT, 13, T.soft)
  book.empty:SetPoint("CENTER")
  book.empty:SetWidth(680)
  book.empty:SetJustifyH("CENTER")

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
