-- The addon's settings, each character's own (its profile, "Name - Realm",
-- the kit's: Kit.lua), all kept in SecondWindSettings so that one character
-- can take another's: chosen among this game's characters, or brought by a
-- code (/wind export, /wind import CODE). Their page in the game's Options
-- (AddOns tab): /wind settings, or a right-click on the minimap button; the
-- welcome page (Welcome.lua) offers them too.
--
--   SecondWindSettings.profiles["Name - Realm"] = { threshold, chat, toast,
--     openAfterDeath, prepull, minimapHidden, minimapAngle, welcomed }
local _, ns = ...
local K = ns.kit

-- (threshold: a close call is a fight survived below it, in percent of your
-- health; minimapAngle: the button's place around the minimap, in degrees,
-- 250 lower left, clear of the game's buttons and the siblings'; welcomed:
-- never copied)
local DEFAULTS = {
  threshold = 15,
  chat = true,
  toast = true,
  openAfterDeath = true,
  prepull = true,
  minimapHidden = false,
  minimapAngle = 250,
  welcomed = false,
}
local SHARED = { "threshold", "chat", "toast", "openAfterDeath", "prepull", "minimapHidden", "minimapAngle" }
ns.THRESHOLDS = { 10, 15, 20, 25 }

-- The profiles: a code "SW1:p15:c1:t1:d1:w1:h0:a250" (the threshold, a line
-- in chat, the toast, the card after a death, the word before a pull, the
-- minimap button hidden, its angle; an older code without w leaves it).
local P = K.profiles({
  saved = function()
    if type(SecondWindSettings) ~= "table" then SecondWindSettings = {} end
    return SecondWindSettings
  end,
  defaults = DEFAULTS,
  shared = SHARED,
  letters = {
    threshold = "p",
    chat = "c",
    toast = "t",
    openAfterDeath = "d",
    prepull = "w",
    minimapHidden = "h",
    minimapAngle = "a",
  },
  tag = "SW1",
  changed = function(key)
    if key == "minimapHidden" or key == "minimapAngle" then ns.updateMinimapButton() end
  end,
})
ns.profiles = P

-- This character's profile at its login: its own, else the defaults.
function ns.loadProfile() P:load() end
function ns.option(key) return P:get(key) end
function ns.setOption(key, value) P:set(key, value) end

local category

function ns.createSettingsPanel()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("Second Wind")

  local threshold = Settings.RegisterProxySetting(
    category,
    "SECONDWIND_THRESHOLD",
    Settings.VarType.Number,
    "A close call below",
    DEFAULTS.threshold,
    function() return ns.option("threshold") end,
    function(value) ns.setOption("threshold", value) end
  )
  Settings.CreateDropdown(category, threshold, function()
    local options = Settings.CreateControlTextContainer()
    for _, n in ipairs(ns.THRESHOLDS) do
      options:Add(n, n .. "% health")
    end
    return options:GetData()
  end, "A fight you survive with your health below this is a close call, and gets a debrief.")

  local function checkbox(key, name, tooltip, invert)
    invert = invert or false
    local setting = Settings.RegisterProxySetting(
      category,
      "SECONDWIND_" .. key:upper(),
      Settings.VarType.Boolean,
      name,
      not DEFAULTS[key] == invert,
      function() return ns.option(key) ~= invert end,
      function(value) ns.setOption(key, value ~= invert) end
    )
    Settings.CreateCheckbox(category, setting, tooltip)
  end
  checkbox("chat", "A line in chat", "After a close call or a death, a line in chat with a link to its debrief.")
  checkbox("toast", "An alert", "After a close call or a death, the game's alert; a click opens the debrief.")
  checkbox(
    "openAfterDeath",
    "The debrief after a death",
    "Open the debrief on its own after a death (you aren't playing then). A close call's waits for a click."
  )
  checkbox(
    "prepull",
    "A word before a pull",
    "Out of a fight, when you target a foe like those of your close calls (an elite, two levels up, one met before), or you're hurt and that's one of the things they share: a line in chat, with the counts."
  )
  checkbox("minimapHidden", "Minimap button", "The book by the minimap: click to open it, drag to move it.", true)

  -- Another character's settings (of this game), for this one.
  K.copySetting(
    category,
    "SECONDWIND_COPYFROM",
    P,
    "Another character's choices, for this one (of this game: Classic and Forever keep their own). From elsewhere: /wind export there, then /wind import CODE here.",
    function(other) print(ns.PREFIX .. ("%s's settings copied."):format(other)) end
  )

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
