-- The addon's settings, each character's own (its profile, "Name - Realm",
-- the kit's: Kit.lua), all kept in SecondWindSettings so that one character
-- can take another's: chosen among this game's characters, or brought by a
-- code (/wind export, /wind import CODE). Their page in the game's Options
-- (AddOns tab): /wind settings, or a right-click on the minimap button; the
-- welcome page (Welcome.lua) offers them too.
--
--   SecondWindSettings.profiles["Name - Realm"] = { threshold, toast,
--     openAfterDeath, prepull, minimapHidden, minimapAngle, welcomed }
--   (the chat line after a close call or a death has no setting any more,
--   always shown: a profile's old chat value is left unread)
local _, ns = ...
local K = ns.kit
local L = K.L

-- (threshold: a close call is a fight survived below it, in percent of your
-- health; minimapAngle: the button's place around the minimap, in degrees,
-- 250 lower left, clear of the game's buttons and the siblings'; welcomed:
-- never copied)
local DEFAULTS = {
  threshold = 15,
  toast = true,
  openAfterDeath = true,
  prepull = true,
  minimapHidden = false,
  minimapAngle = 250,
  welcomed = false,
}
local SHARED = { "threshold", "toast", "openAfterDeath", "prepull", "minimapHidden", "minimapAngle" }
ns.THRESHOLDS = { 10, 15, 20, 25 }

-- The profiles: a code "SW1:p15:t1:d1:w1:h0:a250" (the threshold, the banner,
-- the card after a death, the word before a pull, the minimap button hidden,
-- its angle; an older code without w leaves it, an older one's c, the chat
-- line, is left out).
local P = K.profiles({
  saved = function()
    if type(SecondWindSettings) ~= "table" then SecondWindSettings = {} end
    return SecondWindSettings
  end,
  defaults = DEFAULTS,
  shared = SHARED,
  letters = {
    threshold = "p",
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

-- The opt-in that shares what the game tells of the world with the addons'
-- database (the kit's, K.collect): account-wide, in SecondWindCollect, which
-- Ravenpost sends; off until the player says yes.
ns.collect = K.collect({
  saved = function()
    if type(SecondWindCollect) ~= "table" then SecondWindCollect = {} end
    return SecondWindCollect
  end,
})

local category

function ns.createSettingsPanel()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("Second Wind")

  local threshold = Settings.RegisterProxySetting(
    category,
    "SECONDWIND_THRESHOLD",
    Settings.VarType.Number,
    L["A close call below"],
    DEFAULTS.threshold,
    function() return ns.option("threshold") end,
    function(value) ns.setOption("threshold", value) end
  )
  Settings.CreateDropdown(category, threshold, function()
    local options = Settings.CreateControlTextContainer()
    for _, n in ipairs(ns.THRESHOLDS) do
      options:Add(n, L["%d%% health"]:format(n))
    end
    return options:GetData()
  end, L["A fight you survive with your health below this is a close call, and gets a debrief."])

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
  checkbox(
    "toast",
    L["An alert after a death"],
    L["After a death, a banner among the game's alerts. A click opens the debrief."]
  )
  checkbox(
    "openAfterDeath",
    L["The debrief after a death"],
    L["Open the debrief on its own after a death (you aren't playing then). A close call's waits for a click."]
  )
  checkbox(
    "prepull",
    L["A word before a pull"],
    L["Out of a fight, when you target a foe like those of your close calls (an elite, two levels up, one met before), or you're hurt and that's one of the things they share: a line in chat, with the counts."]
  )
  checkbox("minimapHidden", L["Minimap button"], L["The book by the minimap: click to open it, drag to move it."], true)

  K.collectSetting(category, "SECONDWIND_SHARE", ns.collect)

  -- Another character's settings (of this game), for this one.
  K.copySetting(
    category,
    "SECONDWIND_COPYFROM",
    P,
    L["Another character's choices, for this one (of this game: Classic and Forever keep their own). From elsewhere: /wind export there, then /wind import CODE here."],
    function(other) print(ns.PREFIX .. L["%s's settings copied."]:format(other)) end
  )

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
