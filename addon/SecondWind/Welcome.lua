-- The welcome (the kit's, Kit.lua): once per character, a few seconds after
-- its first login (out of combat; /wind welcome shows it again), laid out as
-- the book's window: on the left what Second Wind is; on the right this
-- character's choices (Settings.lua: the close call's threshold, a line in
-- chat, the alert, the debrief after a death, the minimap button), then
-- another character's to take, chosen among this game's or brought by a code
-- (/wind export there). Closing it, however, is enough to have seen it.
local _, ns = ...
local K = ns.kit

-- (Forever hides my health from addons: said before it surprises)
local FOREVER = "\n\nOn World of Warcraft: Forever, the game hides your health from addons, in a fight and out of "
  .. "it: Second Wind rebuilds it from each blow and heal the game tells, counted from its own low-health "
  .. "warning, the screen's red edge below 35%, so keep that warning on (Options, Combat)."

local W = K.welcome({
  name = "SecondWindWelcome",
  title = "Welcome to Second Wind",
  art = "Interface\\AddOns\\SecondWind\\Media\\Logo",
  logo = "Interface\\AddOns\\SecondWind\\Media\\Logo",
  heading = "Second Wind",
  tagline = "A debrief after each close call and death.",
  intro = "When a fight leaves you on your last breath and you live, or ends you, Second Wind writes it down "
    .. "once the fight is over: how it went, the hits that mattered, what you had ready and didn't use, and "
    .. "what to take from it.\n\n"
    .. "Nothing shows during a fight. Over time, the book shows what your close calls have in common.\n\n"
    .. "On Hardcore, the debrief of a death is the life's last page."
    .. (ns.forever and FOREVER or ""),
  profiles = ns.profiles,
  choices = function()
    local thresholds = {}
    for _, n in ipairs(ns.THRESHOLDS) do
      table.insert(thresholds, { value = n, text = n .. "% health" })
    end
    return {
      {
        text = "A close call below",
        hint = "A fight you survive below this gets a debrief.",
        options = thresholds,
        get = function() return ns.option("threshold") end,
        set = function(v) ns.setOption("threshold", v) end,
      },
      {
        text = "A line in chat",
        hint = "After a close call or a death: its main lesson, and a link to its debrief.",
        get = function() return ns.option("chat") end,
        set = function(v) ns.setOption("chat", v) end,
      },
      {
        text = "An alert after a death",
        hint = "The game's alert; a click opens the debrief. A close call has its line in chat.",
        get = function() return ns.option("toast") end,
        set = function(v) ns.setOption("toast", v) end,
      },
      {
        text = "The debrief after a death",
        hint = "Opened on its own (you aren't playing then); a close call's waits for a click.",
        get = function() return ns.option("openAfterDeath") end,
        set = function(v) ns.setOption("openAfterDeath", v) end,
      },
      {
        text = "A word before a pull",
        hint = "Targeting a foe like those of your close calls, out of a fight: a line in chat, with the counts.",
        get = function() return ns.option("prepull") end,
        set = function(v) ns.setOption("prepull", v) end,
      },
      {
        text = "The book by the minimap",
        hint = "Click it to open the book; drag it around the minimap.",
        get = function() return not ns.option("minimapHidden") end,
        set = function(v) ns.setOption("minimapHidden", not v) end,
      },
    }
  end,
  footnote = "Change them any time: /wind settings, or a right-click on the minimap button. /wind opens the book.",
  open = { text = "Open the book", click = function() ns.toggle() end },
  exportHint = "Copy it (Ctrl+C), then on another character: Use a code, or /wind import CODE.",
  importHint = "Paste the code (/wind export on the other character), then press Enter.",
  refused = "That isn't a Second Wind settings code.",
})

-- The welcome; "export": with this character's code ready to copy.
ns.welcome = W -- (its frame, rows, picker and code: for the tests)
function ns.showWelcome(mode) W:Show(mode) end

K.welcomeOnce(W, ns.profiles, function() return ns.record() ~= nil end)
