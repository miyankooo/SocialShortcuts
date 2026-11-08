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

-- The set's welcome line: what the addon does, where to choose the keys, the keys it starts with, and last a
-- game option the first load changed.
local function PrintWelcome(note)
  local bindings = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then table.insert(bindings, ns.modifierLabel[token] .. " to " .. action.verb) end
  end

  local line = "Whispers, invites or befriends a player when you hold a key and left-click their name. Open the "
    .. SurfaceLink(SETTINGS) .. " or type /ssc to choose your keys."
  if #bindings > 0 then line = line .. " Starting keys: " .. table.concat(bindings, ", ") .. "." end
  if note then line = line .. " " .. note end
  ns.Print(line)
end

EventUtil.ContinueOnPlayerLogin(function()
  if ns.firstRun then PrintWelcome(ns.firstRun.note) end
end)

-- Another addon's link may come from a line kept from restricted content, so it is checked before the
-- comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
  if ns.CanAccess(link) and link == LINK then ns.OpenSettings() end
end, ns)
