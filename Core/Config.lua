local addonName, ns = ...

ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

-- The client offers exactly four modifier predicates, so a binding stores the physical modifier and the
-- platform only decides what it is called: META is Command on macOS, ALT is Option. Detecting the platform
-- here keeps every other file free of Mac branches. Shift is never offered, because a Shift-click on a name
-- in chat is the game's own insert-name or /who. Shift, and the Windows key on Windows, stay tested, so a
-- click with one of them held never counts as a plain Ctrl or Alt click.
local modifierTests = {
  SHIFT = IsShiftKeyDown,
  CTRL = IsControlKeyDown,
  ALT = IsAltKeyDown,
  META = IsMetaKeyDown,
}

local isMac = IsMacClient()

local macLabels = { NONE = NONE, CTRL = "Control", ALT = "Option", META = "Command" }
local pcLabels = { NONE = NONE, CTRL = "Ctrl", ALT = "Alt" }

-- Fixed order so the dropdowns read the same every session, with the opt-out first. Windows leaves out its
-- third key, because the Windows key opens the Start menu over the game and no game option blocks it. A
-- saved binding on a key no longer offered is then unknown and falls back in LoadSettings.
ns.modifierOrder = { "NONE", "CTRL", "ALT" }
if isMac then table.insert(ns.modifierOrder, "META") end
ns.modifierLabel = isMac and macLabels or pcLabels

local knownTokens = tInvert(ns.modifierOrder)

-- Labels are the strings Blizzard's own unit menu shows for the same actions (UnitPopupSharedButtonMixins.lua).
-- The verb completes the first-run hint. Invite comes last, so its Invite Asks to Join option sits right
-- below it in the settings.
ns.actions = {
  { key = "whisper", label = WHISPER, verb = "whisper", help = "Open a whisper to the clicked player." },
  { key = "friend", label = ADD_FRIEND, verb = "add as a friend", help = "Add the clicked player to your friends list." },
  {
    key = "invite", label = PARTY_INVITE, verb = "invite",
    help = "Invite the clicked player to your group. In a group you don't lead, it suggests them to your leader instead.",
  },
}

-- Defaults follow reach from a hand on WASD: Invite, used most, gets the key next to the space bar, Whisper
-- the next easiest and Add Friend, used least, the farthest. Windows has two keys, so Add Friend starts
-- unbound there. The options panel reads these too, so its Defaults button restores the same values.
ns.defaults = {
  whisper = isMac and "ALT" or "CTRL",
  invite = isMac and "META" or "ALT",
  friend = isMac and "CTRL" or "NONE",
  askToJoin = true,
}

-- The Mac client can turn Command-left-click into a right click
-- (Blizzard_SettingsDefinitions_Shared/Mac.lua). A right click never reaches the shortcuts, so Command works
-- as a key only while that option is off.
local COMMAND_RIGHT_CLICK = "MacUseCommandLeftClickAsRightClick"

function ns.IsCommandFree()
  return not isMac or not C_CVar.GetCVarBool(COMMAND_RIGHT_CLICK)
end

-- The Mac defaults bind Command, so the first load and the Defaults button turn the option off. After that
-- the game's own checkbox decides, and the settings grey Command out while it is on. Returns the note for
-- the chat line when it had to change the option, so the user learns why Command-click stopped
-- right-clicking. The write is a plain C_CVar call: Blizzard's settings panel picks up script CVar changes
-- through securecallfunction (Blizzard_SettingsPanel.lua), so its own state never runs under addon taint.
function ns.FreeCommandKey()
  if ns.IsCommandFree() then return nil end

  C_CVar.SetCVar(COMMAND_RIGHT_CLICK, "0")
  return "Turned off " .. MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK .. ", so Command works as a key."
end

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

-- The action bound to the modifier held right now, before any restriction is asked.
function ns.HeldAction()
  local held = HeldModifier()
  if not held then return nil end

  for _, action in ipairs(ns.actions) do
    if ns.db[action.key] == held then return action.key end
  end
end

-- Inside restricted content the client hands player names, chat links and listing leaders out as secret
-- values. Addon code can neither inspect a secret name nor pass one on: InviteUnit, RequestInviteFromUnit
-- and AddFriend are declared SecretArguments = "AllowedWhenUntainted", so a tainted caller handing them a
-- secret raises. Every click surface asks this first, and the lockdown question takes no argument, so it
-- answers before any surface reads a name. A bound click there says so in Blizzard's red error text,
-- because the default click that runs instead would look like the shortcut misfired.
function ns.PickAction()
  local action = ns.HeldAction()
  if action and C_ChatInfo.InChatMessagingLockdown() then
    UIErrorsFrame:AddExternalErrorMessage(ns.title .. " are off here.")
    return nil
  end
  return action
end

-- The addon has no visible surface of its own, so the first load on an account names the keys once. A
-- changed game option rides on the same line.
local function PrintFirstRunHint(note)
  local bindings = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      table.insert(bindings, ns.modifierLabel[token] .. " to " .. action.verb)
    end
  end
  local hint = "Hold a key and left-click a player name: " .. table.concat(bindings, ", ")
    .. ". Type /ssc to change the keys."
  ns.Print(note and hint .. " " .. note or hint)
end

local function IsKeyTaken(db, token)
  for _, action in ipairs(ns.actions) do
    if db[action.key] == token then return true end
  end
end

-- A token the dropdowns do not offer would bind nothing and leave its dropdown blank, so an unknown or
-- missing value falls back to the default, or to None when another action already holds that key. A toggle
-- keeps any saved true or false. Keys of settings the addon no longer has are dropped.
local function LoadSettings()
  local firstRun = type(SocialShortcutsDB) ~= "table"
  if firstRun then SocialShortcutsDB = {} end
  local db = SocialShortcutsDB

  for key, value in pairs(db) do
    local default = ns.defaults[key]
    local valid = type(default) == "boolean" and type(value) == "boolean" or knownTokens[value]
    if default == nil or not valid then db[key] = nil end
  end
  for _, action in ipairs(ns.actions) do
    if db[action.key] == nil then
      local default = ns.defaults[action.key]
      db[action.key] = IsKeyTaken(db, default) and "NONE" or default
    end
  end
  if db.askToJoin == nil then db.askToJoin = ns.defaults.askToJoin end
  ns.db = db

  if firstRun then PrintFirstRunHint(ns.FreeCommandKey()) end
end

EventUtil.ContinueOnAddOnLoaded(addonName, LoadSettings)
