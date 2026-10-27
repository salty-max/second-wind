-- The addon's settings, each character's own (its profile, "Name - Realm",
-- the kit's: Kit.lua), all kept in SecondWindSettings so that one character
-- can take another's: chosen among this game's characters, or brought by a
-- code (/wind export, /wind import CODE). Their page in the game's Options
-- (AddOns tab): /wind settings, or a right-click on the minimap button; the
-- welcome page (Welcome.lua) offers them too.
--
--   SecondWindSettings.profiles["Name - Realm"] = { threshold, toast,
--     bannerSeconds, openAfterDeath, prepull, minimapHidden, minimapAngle, welcomed }
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
  bannerSeconds = K.BANNER_SECONDS,
  openAfterDeath = true,
  prepull = true,
  minimapHidden = false,
  minimapAngle = K.MINIMAP_ANGLES.SecondWind,
  welcomed = false,
}
local SHARED = { "threshold", "toast", "bannerSeconds", "openAfterDeath", "prepull", "minimapHidden", "minimapAngle" }
ns.THRESHOLDS = { 10, 15, 20, 25 }

-- The profiles: a code "SW1:p15:t1:n10:d1:w1:h0:a250" (the threshold, the banner,
-- how long it stays, the card after a death, the word before a pull, the minimap button hidden,
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
    bannerSeconds = "n",
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
  prefix = ns.PREFIX,
})

-- The page in the game's Options (the kit's: K.options).
local O

function ns.createSettingsPanel()
  if O then return end
  O = K.options({
    title = "Second Wind",
    key = "SECONDWIND",
    get = ns.option,
    set = ns.setOption,
    defaults = DEFAULTS,
    profiles = P,
    slash = "/wind",
    prefix = ns.PREFIX,
  })
  O:choice(
    "threshold",
    L["A close call below"],
    L["A fight you survive with your health below this is a close call, and gets a debrief."],
    function()
      local out = {}
      for _, n in ipairs(ns.THRESHOLDS) do
        table.insert(out, { n, L["%d%% health"]:format(n) })
      end
      return out
    end
  )
  O:check(
    "toast",
    L["An alert after a death"],
    L["After a death, a banner among the game's alerts. A click opens the debrief."]
  )
  O:bannerSeconds("bannerSeconds")
  O:check(
    "openAfterDeath",
    L["The debrief after a death"],
    L["Open the debrief on its own after a death (you aren't playing then). A close call's waits for a click."]
  )
  O:check(
    "prepull",
    L["A word before a pull"],
    L["Out of a fight, when you target a foe like those of your close calls (an elite, two levels up, one met before), or you're hurt and that's one of the things they share: a line in chat, with the counts."]
  )
  O:check("minimapHidden", L["Minimap button"], L["The book by the minimap: click to open it, drag to move it."], true)
  O:collect(ns.collect)
  O:copy()
  O:done()
end

function ns.openSettings() return O ~= nil and O:open() end
