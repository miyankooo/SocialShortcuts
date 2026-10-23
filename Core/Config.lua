local addonName, ns = ...

ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

-- The client offers exactly four modifier predicates, so a binding stores the physical modifier and the
-- platform only decides what it is called: META is Command on macOS and the Windows key elsewhere, ALT is
-- Option on macOS. Detecting the platform here keeps every other file free of Mac branches.
local modifierTests = {
  SHIFT = IsShiftKeyDown,
  CTRL = IsControlKeyDown,
  ALT = IsAltKeyDown,
  META = IsMetaKeyDown,
}

local isMac = IsMacClient()

local macLabels = { NONE = NONE, SHIFT = "Shift", CTRL = "Control", ALT = "Option", META = "Command" }
local pcLabels = { NONE = NONE, SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt", META = "Windows" }

-- Fixed order so the dropdowns read the same every session, with the opt-out first.
ns.modifierOrder = { "NONE", "SHIFT", "CTRL", "ALT", "META" }
ns.modifierLabel = isMac and macLabels or pcLabels

local knownTokens = tInvert(ns.modifierOrder)

-- Labels are the strings Blizzard's own unit menu shows for the same actions (UnitPopupSharedButtonMixins.lua).
-- The verb completes the first-run hint.
ns.actions = {
  { key = "whisper", label = WHISPER, verb = "whisper", help = "Open a whisper to the clicked player." },
  { key = "invite", label = PARTY_INVITE, verb = "invite", help = "Invite the clicked player to your group." },
  { key = "friend", label = ADD_FRIEND, verb = "add as a friend", help = "Add the clicked player to your friends list." },
}

-- The Mac keys mirror the predecessor WeakAura, so the muscle memory survives the move to an addon. Windows
-- takes Shift for Add Friend, because the Windows key opens the Start menu. The options panel reads these
-- too, so its Defaults button restores the same values.
ns.defaults = {
  whisper = "CTRL",
  invite = isMac and "META" or "ALT",
  friend = isMac and "ALT" or "SHIFT",
}

-- A few secrets outlive the chat lockdown: chat lines kept from restricted content, and unit names under
-- identity restrictions. issecretvalue is declared SecretArguments = "AllowedWhenUntainted"; whether the
-- flag makes it raise for addon code is unsettled, since Blizzard's own chat filter wrapper calls
-- canaccessvalue under captured addon taint (ChatFrameFilters.lua). pcall answers right either way,
-- because a raise means secret, and nil never reaches the predicate.
function ns.CanAccess(value)
  if value == nil then return true end

  local ok, secret = pcall(issecretvalue, value)
  return ok and not secret
end

-- Modules read this lazily, so it is safe that it stays empty until ADDON_LOADED.
ns.db = {}

-- The chat prefix every addon of this set shares, in Blizzard's own colour object rather than a hex code.
function ns.Print(message)
  print(YELLOW_FONT_COLOR:WrapTextInColorCode("[" .. ns.title .. "]:") .. " " .. message)
end

-- Exactly one modifier has to be held. Requiring the rest to be up stops one chord from matching two
-- bindings, and makes an assignment mean the same thing no matter which modifier it is.
local function HeldModifier()
  local held
  for token, IsDown in pairs(modifierTests) do
    if IsDown() then
      if held then return nil end
      held = token
    end
  end
  return held
end

-- Taking a modifier another action already uses swaps the two, because quietly unbinding the other action
-- would take away a shortcut the user never asked to give up.
function ns.AssignModifier(actionKey, token)
  local previous = ns.db[actionKey]
  if previous == token then return end

  if token ~= "NONE" then
    for _, action in ipairs(ns.actions) do
      if action.key ~= actionKey and ns.db[action.key] == token then ns.db[action.key] = previous end
    end
  end
  ns.db[actionKey] = token
end

-- Inside restricted content the client hands player names, chat links and listing leaders out as secret
-- values. Addon code can neither inspect a secret name nor pass one on: InviteUnit and AddFriend are
-- declared SecretArguments = "AllowedWhenUntainted", so a tainted caller handing them a secret raises.
-- Every click surface asks this first, and the lockdown question takes no argument, so it answers before
-- any surface reads a name.
function ns.PickAction()
  if C_ChatInfo.InChatMessagingLockdown() then return nil end

  local held = HeldModifier()
  if not held then return nil end

  for _, action in ipairs(ns.actions) do
    if ns.db[action.key] == held then return action.key end
  end
end

-- The addon has no visible surface of its own, so the first load on an account names the keys once.
local function PrintFirstRunHint()
  local bindings = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      table.insert(bindings, ns.modifierLabel[token] .. " to " .. action.verb)
    end
  end
  ns.Print("Hold a key and left-click a player name: " .. table.concat(bindings, ", ") .. ". Type /ssc to change the keys.")
end

-- A token the dropdowns do not offer would bind nothing and leave its dropdown blank, so an unknown or
-- missing value falls back to the default.
local function LoadSettings()
  local firstRun = type(SocialShortcutsDB) ~= "table"
  if firstRun then SocialShortcutsDB = {} end

  for key, value in pairs(ns.defaults) do
    if not knownTokens[SocialShortcutsDB[key]] then
      SocialShortcutsDB[key] = value
    end
  end
  ns.db = SocialShortcutsDB

  if firstRun then PrintFirstRunHint() end
end

EventUtil.ContinueOnAddOnLoaded(addonName, LoadSettings)
