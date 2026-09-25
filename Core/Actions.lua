local _, ns = ...

-- The chat history files each line under the conversation's type and target, spelled the way the server
-- spelled the sender. A list row may spell the same player differently, so the target is compared as a
-- name rather than looked up by its exact string. A target kept secret from restricted content is skipped.
local function IsWhisperWith(accessID, name)
  local chatType, chatTarget = ChatHistory_GetChatType(accessID)
  if chatType ~= "WHISPER" or not ns.CanAccess(chatTarget) then return false end
  return ns.SameName(chatTarget, name)
end

-- Copy the backlog into the new tab rather than letting the client migrate it, because migrating kills
-- the source frame's hyperlinks. Secret lines kept from restricted content stay behind, because addon
-- code cannot vouch for what it hands on.
local function CopyWhisperHistory(target, name, source)
  for i = 1, source:GetNumMessages() do
    local text, r, g, b, chatTypeID, messageAccessID, lineID = source:GetMessageInfo(i)
    if messageAccessID and ns.CanAccess(text) and IsWhisperWith(messageAccessID, name) then
      target:AddMessage(text, r, g, b, chatTypeID, messageAccessID, lineID)
    end
  end
end

-- A tab Blizzard opened for an incoming whisper is named in the server's spelling, so the lookup compares
-- names. A tab opened inside restricted content keeps a secret target and is never matched.
local function FindWhisperTab(name)
  for _, frameName in pairs(CHAT_FRAMES) do
    local frame = _G[frameName]
    if frame and frame.isTemporary and frame.inUse and frame.chatType == "WHISPER"
      and ns.CanAccess(frame.chatTarget) and ns.SameName(frame.chatTarget, name) then
      return frame
    end
  end
end

local function PrimaryChatFrame()
  return (GeneralDockManager and GeneralDockManager.primary) or DEFAULT_CHAT_FRAME
end

local function OpenWhisperTab(name, source)
  local frame = FindWhisperTab(name)
  if not frame then
    frame = FCF_OpenTemporaryWindow("WHISPER", name, nil, true)
    if not frame then return end
    CopyWhisperHistory(frame, name, source or PrimaryChatFrame())
  end

  if frame.isDocked then FCF_SelectDockFrame(frame) end
  FCF_FadeInChatFrame(frame)
  ChatFrameUtil.ActivateChat(frame.editBox)
end

-- Discard the text the default link handler staged, because deactivating on its own leaves it pending in
-- the box and it reappears on the next click.
function ns.CloseWhisperBox()
  local editBox = ChatFrameUtil.GetActiveWindow()
  if not editBox then return end

  editBox.text = ""
  editBox.setText = 0
  ChatFrameUtil.DeactivateChat(editBox)
end

-- Each client's own invite path: Era's menus call InviteToGroup, which offers to convert a full party to a
-- raid (Vanilla/UIParent.lua), while Forever has no such global and its menus call C_PartyInfo.InviteUnit.
local inviteByName = InviteToGroup or C_PartyInfo.InviteUnit

-- Forever can switch character friends off, and Blizzard then hides its own add-friend entries
-- (UnitPopupSharedButtonMixins.lua). Era has no such switch.
local function AddCharacterFriend(name)
  local isEnabled = C_FriendList.IsLegacyFriendSystemEnabled
  if isEnabled and not isEnabled() then
    ns.Print("Character friends are turned off on this client.")
    return
  end

  C_FriendList.AddFriend(name)
end

-- Only list and chat surfaces pass openTab. Unit frames withhold it because opening a chat window from a
-- secure click taints the chat frame system.
function ns.RunAction(action, name, openTab, source)
  if not name then return end

  if action == "whisper" then
    if openTab then
      OpenWhisperTab(name, source)
    else
      ChatFrameUtil.SendTell(name)
    end
  elseif action == "invite" then
    inviteByName(name)
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
