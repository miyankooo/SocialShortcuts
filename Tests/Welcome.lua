-- Checks the first-run welcome line, its settings link and the /ssc commands in UI/Welcome.lua and
-- UI/Options.lua against stubs of the client. Run from the repo root: lua Tests/Welcome.lua
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND, SETTINGS = "None", "Whisper", "Invite", "Add Friend", "Settings"
MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK, MAC_SETTINGS_LABEL = "Command left click as right click", "Keyboard Options"
strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = {}
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

-- Runs fn and returns the chat lines it printed.
local function Capture(fn, ...)
  local lines, realPrint = {}, print
  print = function(line) table.insert(lines, line) end
  fn(...)
  print = realPrint
  return lines
end

-- Loads the addon on a fresh client and logs in, returning the chat lines and the addon table. Options only
-- registers its panel at login; Welcome loads after it, so the stubbed login runs Welcome's greeting alone.
local function Login(mac, savedVariables, rightClick)
  IsMacClient = function() return mac end
  SocialShortcutsDB = savedVariables
  commandRightClick = rightClick
  local ns = {}
  assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)
  assert(loadfile("UI/Options.lua"))("SocialShortcuts", ns)
  assert(loadfile("UI/Welcome.lua"))("SocialShortcuts", ns)

  local lines = Capture(function()
    onLoaded()
    onLogin()
  end)
  return lines, ns
end

local function Has(line, text) return line ~= nil and line:find(text, 1, true) ~= nil end

local PREFIX = "<gold>[Social Shortcuts]</gold>: "
local WHAT = "Whispers, invites or befriends a player when you hold a key and left-click their name. "
local OPEN = "Open the <gold>|Haddon:SocialShortcuts|h[Settings]|h</gold> or type /ssc to choose your keys. "
local MAC_KEYS = "Starting keys: Option to whisper, Control to add as a friend, Command to invite."
local NOTE = " Turned off Command left click as right click, so Command works as a key."

local lines, ns = Login(true, nil, true)
Check("the first login prints one line", #lines == 1)
Check("only the bracketed title is gold, the colon and the message are not", Has(lines[1], PREFIX .. "Whispers"))
Check("Mac: what it does, the gold Settings link and /ssc, the starting keys, the changed game option last",
  lines[1] == PREFIX .. WHAT .. OPEN .. MAC_KEYS .. NOTE)

local opened = 0
ns.OpenSettings = function() opened = opened + 1 end
onItemRef("addon:SocialShortcuts", "[Settings]", "LeftButton")
Check("a click on the link opens the settings", opened == 1)
onItemRef("addon:OtherAddon", "[Other]", "LeftButton")
onItemRef(SECRET, "[Settings]", "LeftButton")
Check("another addon's link or a secret one opens nothing", opened == 1)

lines = Login(true, nil, false)
Check("with the option already off the line has no note",
  #lines == 1 and lines[1] == PREFIX .. WHAT .. OPEN .. MAC_KEYS)

lines = Login(false, nil, nil)
Check("Windows names Ctrl and Alt and leaves out unbound Add Friend",
  #lines == 1 and lines[1] == PREFIX .. WHAT .. OPEN .. "Starting keys: Ctrl to whisper, Alt to invite.")

lines = Login(true, { whisper = "ALT", invite = "META", friend = "CTRL", askToJoin = true }, false)
Check("a later login prints nothing", #lines == 0)

-- The slash command: a bare /ssc opens the settings, help and intro are the shared words, anything else
-- prints the hint and opens nothing.
local HELP = PREFIX .. "Type /ssc for the settings, /ssc intro to see the welcome line again, or /ssc help for this list."
lines, ns = Login(true, { whisper = "ALT", invite = "META", friend = "NONE", askToJoin = true }, false)
local Slash = SlashCmdList.SOCIALSHORTCUTS
opened = 0
ns.OpenSettings = function() opened = opened + 1 end

Check("a bare /ssc opens the settings and prints nothing", #Capture(Slash, "") == 0 and opened == 1)
lines = Capture(Slash, "help")
Check("/ssc help prints one line naming every command", #lines == 1 and lines[1] == HELP)
Check("/ssc ? and a padded upper-case HELP do the same",
  Capture(Slash, "?")[1] == HELP and Capture(Slash, "  HELP ")[1] == HELP)

lines = Capture(Slash, "intro")
Check("/ssc intro prints the welcome line again with the keys bound now, without the first-run note",
  #lines == 1 and lines[1] == PREFIX .. WHAT .. OPEN .. "Your keys: Option to whisper, Command to invite.")
commandRightClick = true
lines = Capture(Slash, "intro")
Check("with Command bound while the game option is on, the replay says what to turn off, last",
  lines[1] == PREFIX .. WHAT .. OPEN .. "Your keys: Option to whisper, Command to invite. "
    .. "Turn off Command left click as right click in Keyboard Options to use Command.")
ns.AssignModifier("invite", "NONE")
lines = Capture(Slash, "intro")
Check("without a bound Command the replay has no note", lines[1] == PREFIX .. WHAT .. OPEN .. "Your keys: Option to whisper.")
ns.AssignModifier("whisper", "NONE")
lines = Capture(Slash, "intro")
Check("with no key bound the replay leaves out the keys", lines[1] == PREFIX .. WHAT .. strtrim(OPEN))

lines = Capture(Slash, "settings")
Check("an unknown word prints the hint and opens nothing",
  #lines == 1 and lines[1] == PREFIX .. "Unknown command. Type /ssc help for the list." and opened == 1)

print(failures == 0 and "Welcome: all checks passed" or ("Welcome: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
