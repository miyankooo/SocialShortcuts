-- Checks the first-run welcome line and its settings link in UI/Welcome.lua against stubs of the client.
-- Run from the repo root: lua Tests/Welcome.lua
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND, SETTINGS = "None", "Whisper", "Invite", "Add Friend", "Settings"
MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK = "Command left click as right click"
NORMAL_FONT_COLOR = { WrapTextInColorCode = function(_, text) return "<gold>" .. text .. "</gold>" end }
LinkTypes = { AddOn = "addon" }
-- Blizzard's own formatter (LinkUtil.lua).
LinkUtil = {
  FormatLink = function(linkType, text, ...)
    return table.concat({ ("|H%s"):format(linkType), ... }, ":") .. ("|h%s|h"):format(text)
  end,
}
local SECRET = {}
issecretvalue = function(value) return value == SECRET end

local onLoaded, onLogin, onItemRef
EventUtil = {
  ContinueOnAddOnLoaded = function(_, callback) onLoaded = callback end,
  ContinueOnPlayerLogin = function(callback) onLogin = callback end,
}
EventRegistry = {
  RegisterCallback = function(_, event, callback, owner)
    if event == "SetItemRef" then onItemRef = function(...) callback(owner, ...) end end
  end,
}
local commandRightClick
C_CVar = {
  GetCVarBool = function() return commandRightClick end,
  SetCVar = function(_, value) commandRightClick = value == "1" end,
}

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

-- Loads the addon on a fresh client and logs in, returning the chat lines and the addon table.
local function Login(mac, savedVariables, rightClick)
  IsMacClient = function() return mac end
  SocialShortcutsDB = savedVariables
  commandRightClick = rightClick
  local ns = {}
  assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)
  assert(loadfile("UI/Welcome.lua"))("SocialShortcuts", ns)

  local lines, realPrint = {}, print
  print = function(line) table.insert(lines, line) end
  onLoaded()
  onLogin()
  print = realPrint
  return lines, ns
end

local function Has(line, text) return line ~= nil and line:find(text, 1, true) ~= nil end

local lines, ns = Login(true, nil, true)
Check("the first login prints one line", #lines == 1)
Check("only the bracketed title is gold, the colon and the message are not",
  Has(lines[1], "<gold>[Social Shortcuts]</gold>: Open the "))
Check("it opens with the gold Settings link and /ssc",
  Has(lines[1], "Open the <gold>|Haddon:SocialShortcuts|h[Settings]|h</gold> or type /ssc"))
Check("it names the Mac starting keys",
  Has(lines[1], "Starting keys: Option to whisper, Control to add as a friend, Command to invite."))
Check("the changed game option rides on the same line, last",
  Has(lines[1], "Command to invite. Turned off Command left click as right click, so Command works as a key."))

local opened = 0
ns.OpenSettings = function() opened = opened + 1 end
onItemRef("addon:SocialShortcuts", "[Settings]", "LeftButton")
Check("a click on the link opens the settings", opened == 1)
onItemRef("addon:OtherAddon", "[Other]", "LeftButton")
onItemRef(SECRET, "[Settings]", "LeftButton")
Check("another addon's link or a secret one opens nothing", opened == 1)

lines = Login(true, nil, false)
Check("with the option already off the line has no note",
  #lines == 1 and Has(lines[1], "Command to invite.") and not Has(lines[1], "Turned off"))

lines = Login(false, nil, nil)
Check("Windows names Ctrl and Alt and leaves out unbound Add Friend",
  #lines == 1 and Has(lines[1], "Starting keys: Ctrl to whisper, Alt to invite.") and not Has(lines[1], "friend"))

lines = Login(true, { whisper = "ALT", invite = "META", friend = "CTRL", askToJoin = true }, false)
Check("a later login prints nothing", #lines == 0)

print(failures == 0 and "Welcome: all checks passed" or ("Welcome: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
