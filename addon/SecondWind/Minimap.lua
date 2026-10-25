-- The book's button on the minimap (the kit's: Kit.lua): click to open the
-- book, right-click for its settings, drag to move it around the minimap.
-- Its place (and whether it shows) is kept with this character's settings
-- (Settings.lua).
local _, ns = ...
local K = ns.kit

local M

function ns.createMinimapButton()
  if M then return end
  M = K.minimapButton({
    name = "SecondWindMinimapButton",
    icon = "Interface\\AddOns\\SecondWind\\Media\\Logo",
    crop = true,
    title = "Second Wind",
    lines = function()
      local record = ns.record()
      local n = record and #record.debriefs or 0
      return { K.plural(n, "%d debrief", "%d debriefs"):format(n) }
    end,
    click = function() ns.toggle() end,
    rightClick = function() ns.openSettings() end,
    get = ns.option,
    set = ns.setOption,
  })
end

function ns.updateMinimapButton()
  if M then M:update() end
end
