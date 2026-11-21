local addonName, ns = ...

-- Outside its settings the addon shows nothing, so the first load on an account points there once, with a
-- link that opens them. The line waits for login, when the settings exist and the client's own load lines
-- are already in chat.

-- Blizzard reserves the addon link type for addons and hands every click on one to all of them through one
-- EventRegistry event (ItemRefHandlersShared.lua). Gold is the colour of Blizzard's own action links in
-- chat, such as club invites (ItemRef.lua).
local LINK = LinkTypes.AddOn .. ":" .. addonName

local function SurfaceLink(label)
  return NORMAL_FONT_COLOR:WrapTextInColorCode(LinkUtil.FormatLink(LinkTypes.AddOn, "[" .. label .. "]", addonName))
end

-- The set's welcome line: what the addon does, where to choose the keys, the keys bound now, and last a game
-- option the first load changed or a bound key needs.
local function PrintWelcome(keysLabel, note)
  local bindings = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then table.insert(bindings, ns.modifierLabel[token] .. " to " .. action.verb) end
  end

  local line = "Whispers, invites or befriends a player when you hold a key and left-click their name. Open the "
    .. SurfaceLink(SETTINGS) .. " or type /ssc to choose your keys."
  if #bindings > 0 then line = line .. " " .. keysLabel .. ": " .. table.concat(bindings, ", ") .. "." end
  if note then line = line .. " " .. note end
  ns.Print(line)
end

EventUtil.ContinueOnPlayerLogin(function()
  if ns.firstRun then PrintWelcome("Starting keys", ns.firstRun.note) end
end)

-- A bound Command does nothing while the game still treats Command-click as a right click.
local function CommandNote()
  if ns.IsCommandFree() then return nil end
  for _, action in ipairs(ns.actions) do
    if ns.db[action.key] == "META" then return ns.CommandBlockedLine() end
  end
end

-- /ssc intro replays the onboarding. The feature is a modifier-click on a name, which has no control of the
-- addon's own to point a help tip at, so the replay is the welcome line alone, with the keys as they are now.
function ns.ReplayIntro()
  PrintWelcome("Your keys", CommandNote())
end

-- Another addon's link may come from a line kept from restricted content, so it is checked before the
-- comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
  if ns.CanAccess(link) and link == LINK then ns.OpenSettings() end
end, ns)
