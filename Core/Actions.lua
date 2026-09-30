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

-- Each action makes the call Blizzard's own buttons make, so the addon never writes chat state itself.
-- The friends list and the unit menu whisper through SendTell (Camelot/FriendsFrame.lua,
-- UnitPopupSharedButtonMixins.lua). A chat click passes its frame, so the whisper opens where Blizzard's
-- own link handler would open it. Invites also offer to convert a full party to a raid.
function ns.RunAction(action, name, chatFrame)
  if not name then return end

  if action == "whisper" then
    ChatFrameUtil.SendTell(name, chatFrame)
  elseif action == "invite" then
    C_PartyInfo.InviteUnit(name)
  elseif action == "friend" then
    AddCharacterFriend(name)
  end
end

-- Battle.net friends need the account APIs, because a name-based action cannot reach an account that is
-- not on a character of this realm right now.
function ns.RunBNetAction(action, accountIndex)
  local info = C_BattleNet.GetFriendAccountInfo(accountIndex)
  if not info then return end

  local game = info.gameAccountInfo
  if action == "whisper" then
    ChatFrameUtil.SendBNetTell(info.accountName)
  elseif action == "invite" then
    if game and game.playerGuid and game.gameAccountID then
      FriendsFrame_InviteOrRequestToJoin(game.playerGuid, game.gameAccountID)
    end
  elseif game and game.characterName and game.realmName == GetRealmName() then
    AddCharacterFriend(game.characterName)
  else
    ns.Print("Can't add that friend, they are not on a character on this realm.")
  end
end
