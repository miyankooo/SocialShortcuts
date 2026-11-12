-- Checks the platform labels, the first load, the Command key and the modifier swap in Core/Config.lua
-- against stubs of the client. Run from the repo root: lua Tests/Assign.lua
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMetaKeyDown = nil, nil, nil, nil
IsMacClient = function() return true end
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND = "None", "Whisper", "Invite", "Add Friend"
MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK = "Command left click as right click"
NORMAL_FONT_COLOR = { WrapTextInColorCode = function(_, text) return text end }
local onLoaded
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) onLoaded = callback end }
local commandRightClick = true
C_CVar = {
  GetCVarBool = function() return commandRightClick end,
  SetCVar = function(_, value) commandRightClick = value == "1" end,
}

local ns = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

local labels = ns.modifierLabel
Check("macOS offers Control, Option and Command, never Shift",
  labels.CTRL == "Control" and labels.ALT == "Option" and labels.META == "Command" and labels.SHIFT == nil
  and #ns.modifierOrder == 4)

Check("Mac defaults: Option whispers, Command invites, Control adds a friend",
  ns.defaults.whisper == "ALT" and ns.defaults.invite == "META" and ns.defaults.friend == "CTRL")
Check("the settings list Whisper, Add Friend, then Invite above its option",
  ns.actions[1].key == "whisper" and ns.actions[2].key == "friend" and ns.actions[3].key == "invite")

Check("Command is taken while the game treats Command-click as a right click", not ns.IsCommandFree())
local lines, realPrint = {}, print
print = function(line) table.insert(lines, line) end
onLoaded()
print = realPrint
Check("the first load on a Mac turns the right-click option off", ns.IsCommandFree() and ns.db.invite == "META")
Check("the first load prints nothing and keeps the note for the welcome line at login",
  #lines == 0 and ns.firstRun.note == "Turned off Command left click as right click, so Command works as a key.")
Check("a second free changes nothing and says nothing", ns.FreeCommandKey() == nil)

IsMacClient = function() return false end
local pc = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", pc)
labels = pc.modifierLabel
Check("Windows offers Ctrl and Alt, never Shift or the Windows key",
  labels.CTRL == "Ctrl" and labels.ALT == "Alt" and labels.SHIFT == nil and labels.META == nil
  and #pc.modifierOrder == 3)
SocialShortcutsDB = { whisper = "SHIFT", invite = "ALT", friend = "META", join = "NONE" }
onLoaded()
Check("saved keys no longer offered fall back to the defaults", pc.db.whisper == "CTRL" and pc.db.friend == "NONE")
Check("a setting the addon no longer has is dropped", pc.db.join == nil)
Check("a missing toggle starts on", pc.db.askToJoin == true)
SocialShortcutsDB = { whisper = "SHIFT", invite = "META", friend = "CTRL", askToJoin = false }
onLoaded()
Check("a fallback never takes a key another action holds",
  pc.db.whisper == "NONE" and pc.db.invite == "ALT" and pc.db.friend == "CTRL")
SocialShortcutsDB = { whisper = "CTRL", invite = "ALT", friend = "NONE", askToJoin = false }
onLoaded()
Check("a saved toggle off stays off", pc.db.askToJoin == false)
SocialShortcutsDB = { whisper = "CTRL", invite = "ALT", friend = "NONE", askToJoin = "ALT" }
onLoaded()
Check("a key saved as the toggle falls back to on", pc.db.askToJoin == true)
commandRightClick = true
Check("Windows never reads or changes the Mac option", pc.IsCommandFree() and pc.FreeCommandKey() == nil and commandRightClick)
Check("Windows defaults: Ctrl whispers, Alt invites, Add Friend starts unbound",
  pc.defaults.whisper == "CTRL" and pc.defaults.invite == "ALT" and pc.defaults.friend == "NONE")

ns.db = { whisper = "CTRL", invite = "META", friend = "ALT" }
ns.AssignModifier("whisper", "ALT")
Check("taking a used key swaps the two", ns.db.whisper == "ALT" and ns.db.friend == "CTRL" and ns.db.invite == "META")
ns.AssignModifier("invite", "NONE")
Check("None frees a key without touching the others", ns.db.invite == "NONE" and ns.db.whisper == "ALT" and ns.db.friend == "CTRL")
ns.AssignModifier("friend", "NONE")
Check("two actions can both be off", ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "META")
Check("a free key moves without a swap",
  ns.db.whisper == "META" and ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "META")
Check("the same key again changes nothing", ns.db.whisper == "META")

print(failures == 0 and "Assign: all checks passed" or ("Assign: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
