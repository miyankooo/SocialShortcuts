-- Checks that each action in Core/Actions.lua makes the call Blizzard's own button makes, and that Invite
-- asks to join a grouped player, against stubs of the client. Run from the repo root: lua Tests/Actions.lua
local calls = {}
local now, inGroup, onEvent, isLeader, partyFull, notices = 100, false, nil, false, false, {}
ChatFrameUtil = { SendTell = function(name) table.insert(calls, "tell " .. name) end }
C_PartyInfo = {
  InviteUnit = function(name)
    table.insert(calls, "invite " .. name)
    if name == "Known" then onEvent(nil, "CHAT_MSG_SYSTEM", "Known is already in a group.") end
  end,
  RequestInviteFromUnit = function(name) table.insert(calls, "request " .. name) end,
  IsPartyFull = function() return partyFull end,
}
C_FriendList = {
  IsLegacyFriendSystemEnabled = function() return true end,
  AddFriend = function(name) table.insert(calls, "friend " .. name) end,
}

ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
GetTime = function() return now end
IsInGroup = function() return inGroup end
UnitIsGroupLeader = function() return isLeader end
UnitIsGroupAssistant = function() return false end
ERR_GROUP_FULL = "Your party is full."
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }
CreateFrame = function()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, _, handler) onEvent = handler end,
  }
end

local ns = { db = { askToJoin = true }, CanAccess = function() return true end }
assert(loadfile("Core/Actions.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

ns.RunAction("whisper", "Name")
ns.RunAction("invite", "Name")
ns.RunAction("friend", "Name")
Check("each action makes Blizzard's own call", calls[1] == "tell Name" and calls[2] == "invite Name" and calls[3] == "friend Name")
ns.RunAction("invite", nil)
Check("a missing name calls nothing", #calls == 3)

calls = {}
ns.RunAction("invite", "Leader")
onEvent(nil, "CHAT_MSG_SYSTEM", "Someone joins the party.")
onEvent(nil, "CHAT_MSG_SYSTEM", "Leader is already in a group.")
Check("alone, Invite on a grouped player asks to join", calls[1] == "invite Leader" and calls[2] == "request Leader")
onEvent(nil, "CHAT_MSG_SYSTEM", "Leader is already in a group.")
Check("one invite asks to join once", #calls == 2)

calls = {}
ns.RunAction("invite", "Leader-Realm")
onEvent(nil, "CHAT_MSG_SYSTEM", "Stranger is already in a group.")
Check("another player's answer asks nothing", #calls == 1)
onEvent(nil, "CHAT_MSG_SYSTEM", "leader is already in a group.")
Check("the answer may drop the realm and change case", calls[2] == "request Leader-Realm")

calls = {}
ns.RunAction("invite", "Known")
Check("an answer inside the invite call still asks to join", calls[2] == "request Known")

calls = {}
ns.RunAction("invite", "Leader")
onEvent(nil, "UI_ERROR_MESSAGE", 1, "Leader is already in a group.")
Check("the answer counts as an error message too", calls[2] == "request Leader")

calls = {}
ns.RunAction("invite", "Leader")
now = now + 4
onEvent(nil, "CHAT_MSG_SYSTEM", "Leader is already in a group.")
Check("a late answer asks nothing", #calls == 1)

calls = {}
ns.RunAction("invite", "Leader", nil, true)
Check("alone, Invite on a player known to be grouped asks to join at once",
  #calls == 1 and calls[1] == "request Leader")
calls = {}
ns.RunAction("invite", "Loner", nil, false)
onEvent(nil, "CHAT_MSG_SYSTEM", "Loner is already in a group.")
Check("alone, Invite on a player known to be solo only invites", #calls == 1 and calls[1] == "invite Loner")

calls, inGroup = {}, true
ns.RunAction("invite", "Leader", nil, true)
Check("in a group, Invite on a grouped player invites or suggests", #calls == 1 and calls[1] == "invite Leader")
calls = {}
ns.RunAction("invite", "Leader")
onEvent(nil, "CHAT_MSG_SYSTEM", "Leader is already in a group.")
Check("in a group, Invite never asks to join", #calls == 1)

calls, partyFull = {}, true
ns.RunAction("invite", "Friend")
Check("without lead in a full party, Invite says so and sends nothing",
  #calls == 0 and #notices == 1 and notices[1] == "Your party is full.")
isLeader = true
ns.RunAction("invite", "Friend")
Check("the leader of a full party still invites, as Blizzard's menu does", calls[1] == "invite Friend")

calls, inGroup, isLeader, partyFull, ns.db.askToJoin = {}, false, false, false, false
ns.RunAction("invite", "Leader")
onEvent(nil, "CHAT_MSG_SYSTEM", "Leader is already in a group.")
Check("the toggle off keeps a plain invite", #calls == 1)

print(failures == 0 and "Actions: all checks passed" or ("Actions: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
