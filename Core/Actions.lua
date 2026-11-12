local _, ns = ...

-- Character friends can be switched off, and Blizzard then hides its own add-friend entries
-- (UnitPopupSharedButtonMixins.lua).
local function AddCharacterFriend(name)
  if not C_FriendList.IsLegacyFriendSystemEnabled() then
    ns.Print("Character friends are turned off on this client.")
    return
  end

  C_FriendList.AddFriend(name)
end

-- Invite asks to join instead, like Blizzard's own menu entry turns into Request to Join Group while you
-- are alone and the player is in a group (UnitPopupButtons.lua). Where the caller knows the player's group,
-- as a unit frame or a Group Finder listing does, the request goes out inside the click. A name in chat or a
-- list carries no group, so the invite goes out, and when the client answers that the player is already in
-- a group, the join request follows for the same name.
local JOIN_WINDOW = 3
local pendingJoin

function ns.AsksToJoin()
  return ns.db.askToJoin and not IsInGroup()
end

local escaped = ERR_ALREADY_IN_GROUP_S:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
local alreadyInGroup = "^" .. escaped:gsub("%%s", "(.+)") .. "$"

-- The answer names the player as the server knows them, with or without realm or surname, so only the first
-- part is compared. Another player's answer, such as one to an invite from Blizzard's menu, asks nothing.
local function FirstName(name)
  return name:match("^[^%s%-]*"):lower()
end

-- The answer comes as a system chat line or an error message. A line kept from restricted content can be
-- secret, so it is checked before the match.
local function OnPartyResult(_, event, ...)
  if not pendingJoin then return end
  if GetTime() - pendingJoin.time > JOIN_WINDOW then
    pendingJoin = nil
    return
  end

  local message = event == "UI_ERROR_MESSAGE" and select(2, ...) or ...
  local answered = ns.CanAccess(message) and type(message) == "string" and message:match(alreadyInGroup)
  if answered and FirstName(answered) == FirstName(pendingJoin.name) then
    local name = pendingJoin.name
    pendingJoin = nil
    C_PartyInfo.RequestInviteFromUnit(name)
  end
end

local resultFrame = CreateFrame("Frame")
resultFrame:RegisterEvent("CHAT_MSG_SYSTEM")
resultFrame:RegisterEvent("UI_ERROR_MESSAGE")
resultFrame:SetScript("OnEvent", OnPartyResult)

-- In a group without lead or assist, Blizzard's menu shows Suggest Invite (LFGUtil.lua) and still calls
-- InviteUnit, which the server turns into a suggestion to the leader. It only stops first when the party is
-- full (UnitPopupUtils.lua, TryInvite), and so does the shortcut.
local function CanOnlySuggest()
  return IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player")
end

-- grouped is true or false where the caller knows the player's group, nil where it does not.
local function Invite(name, grouped)
  if CanOnlySuggest() and C_PartyInfo.IsPartyFull() then
    UIErrorsFrame:AddExternalErrorMessage(ERR_GROUP_FULL)
    return
  end

  local asksToJoin = ns.AsksToJoin()
  if asksToJoin and grouped then
    C_PartyInfo.RequestInviteFromUnit(name)
    return
  end

  -- Marked before the call, because the client can answer at once, inside InviteUnit, when it already knows
  -- the player is grouped.
  pendingJoin = asksToJoin and grouped == nil and { name = name, time = GetTime() } or nil
  C_PartyInfo.InviteUnit(name)
end

-- Each action makes the call Blizzard's own buttons make, so the addon never writes chat state itself.
-- The friends list and the unit menu whisper through SendTell (Camelot/FriendsFrame.lua,
-- UnitPopupSharedButtonMixins.lua). Invite is Blizzard's one menu entry that reads Invite, Suggest Invite or
-- Request to Join Group by situation (UnitPopupUtils.lua, TryInvite). A chat click passes its frame, so the
-- whisper opens where Blizzard's own link handler would open it. Invites also offer to convert a full party
-- to a raid.
function ns.RunAction(action, name, chatFrame, grouped)
  if not name then return end

  if action == "whisper" then
    ChatFrameUtil.SendTell(name, chatFrame)
  elseif action == "invite" then
    Invite(name, grouped)
  elseif action == "friend" then
    AddCharacterFriend(name)
  end
end

-- Battle.net friends need the account APIs, because a name-based action cannot reach an account that is
-- not on a character of this realm right now. Add Friend does nothing here: they are already a friend.
-- Invite there asks to join on its own when the friend is in a group (FriendsFrame_InviteOrRequestToJoin).
function ns.RunBNetAction(action, accountIndex)
  local info = C_BattleNet.GetFriendAccountInfo(accountIndex)
  if not info then return end

  local game = info.gameAccountInfo
  if action == "whisper" then
    ChatFrameUtil.SendBNetTell(info.accountName)
  elseif action == "invite" and game and game.playerGuid and game.gameAccountID then
    FriendsFrame_InviteOrRequestToJoin(game.playerGuid, game.gameAccountID)
  end
end
