local addonName, ns = ...

ns.addonName = addonName

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

local macLabels = { NONE = "Unbound", SHIFT = "Shift", CTRL = "Control", ALT = "Option", META = "Command" }
local pcLabels = { NONE = "Unbound", SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt", META = "Windows" }

-- Fixed order so the dropdowns read the same every session, with the opt-out first.
ns.modifierOrder = { "NONE", "SHIFT", "CTRL", "ALT", "META" }
ns.modifierLabel = isMac and macLabels or pcLabels

local knownTokens = tInvert(ns.modifierOrder)

ns.actions = {
  { key = "whisper", label = "Whisper", help = "Open a whisper to the clicked player." },
  { key = "invite", label = "Invite to group", help = "Invite the clicked player to your group." },
  { key = "friend", label = "Add friend", help = "Add the clicked player to your friends list." },
}

-- Mirrors the modifiers the predecessor WeakAura used, so the muscle memory survives the move to an addon.
-- The options panel reads these too, so its Defaults button restores the same values.
ns.defaults = {
  whisper = "CTRL",
  invite = isMac and "META" or "ALT",
  friend = isMac and "ALT" or "META",
}

-- A few secrets outlive the chat lockdown: chat lines and whisper tabs kept from restricted content, and
-- unit names under identity restrictions. issecretvalue is declared SecretArguments = "AllowedWhenUntainted";
-- whether the flag makes it raise for addon code is unsettled, since Blizzard's own chat filter wrapper
-- calls canaccessvalue under captured addon taint (ChatFrameFilters.lua). pcall answers right either way,
-- because a raise means secret, and nil never reaches the predicate.
function ns.CanAccess(value)
  if value == nil then return true end

  local ok, secret = pcall(issecretvalue, value)
  return ok and not secret
end

-- Modules read this lazily, so it is safe that it stays empty until ADDON_LOADED.
ns.db = {}

function ns.Print(message)
  print("|cff58C6FASocial Shortcuts|r " .. message)
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

-- A token the dropdowns do not offer would bind nothing and leave its dropdown blank, so an unknown or
-- missing value falls back to the default.
local function LoadSettings()
  if type(SocialShortcutsDB) ~= "table" then SocialShortcutsDB = {} end

  for key, value in pairs(ns.defaults) do
    if not knownTokens[SocialShortcutsDB[key]] then
      SocialShortcutsDB[key] = value
    end
  end
  ns.db = SocialShortcutsDB
end

EventUtil.ContinueOnAddOnLoaded(addonName, LoadSettings)
