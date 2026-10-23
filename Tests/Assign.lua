-- Checks the modifier swap in Core/Config.lua against stubs of the client. Run from the repo root:
-- lua Tests/Assign.lua
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMetaKeyDown = nil, nil, nil, nil
IsMacClient = function() return true end
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND = "None", "Whisper", "Invite", "Add Friend"
EventUtil = { ContinueOnAddOnLoaded = function() end }

local ns = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

ns.db = { whisper = "CTRL", invite = "META", friend = "ALT" }
ns.AssignModifier("whisper", "ALT")
Check("taking a used key swaps the two", ns.db.whisper == "ALT" and ns.db.friend == "CTRL" and ns.db.invite == "META")
ns.AssignModifier("invite", "NONE")
Check("None frees a key without touching the others", ns.db.invite == "NONE" and ns.db.whisper == "ALT" and ns.db.friend == "CTRL")
ns.AssignModifier("friend", "NONE")
Check("two actions can both be off", ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "SHIFT")
Check("a free key moves without a swap", ns.db.whisper == "SHIFT" and ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "SHIFT")
Check("the same key again changes nothing", ns.db.whisper == "SHIFT")

print(failures == 0 and "Assign: all checks passed" or ("Assign: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
