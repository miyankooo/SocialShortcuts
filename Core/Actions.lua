local _, ns = ...

-- Copy the backlog into the new tab rather than letting the client migrate it, because migrating kills
-- the source frame's hyperlinks.
local function CopyWhisperHistory(target, name, source)
  local accessID = ChatHistory_GetAccessID("WHISPER", name)
  for i = 1, source:GetNumMessages() do
    local text, r, g, b, chatTypeID, messageAccessID, lineID = source:GetMessageInfo(i)
    if messageAccessID == accessID then
      target:AddMessage(text, r, g, b, chatTypeID, messageAccessID, lineID)
    end
  end
end

local function FindWhisperTab(name)
  local target = strlower(name)
  for _, frameName in pairs(CHAT_FRAMES) do
    local frame = _G[frameName]
    if frame and frame.isTemporary and frame.inUse and frame.chatType == "WHISPER"
      and frame.chatTarget and strlower(frame.chatTarget) == target then
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

-- Only list and chat surfaces pass openTab. Unit frames withhold it because opening a chat window from a
-- secure click taints the chat frame system. A secret name falls back the same way, since the tab lookup
-- has to compare names and a plain whisper does not.
function ns.RunAction(action, name, openTab, source)
  if not name then return end

  if action == "whisper" then
    if openTab and not ns.ChatRestricted() then
      OpenWhisperTab(name, source)
    else
      ChatFrameUtil.SendTell(name)
    end
  elseif action == "invite" then
    C_PartyInfo.InviteUnit(name)
  elseif action == "friend" then
    C_FriendList.AddFriend(name)
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
    C_FriendList.AddFriend(game.characterName)
  else
    ns.Print("Can't add that friend, they are not on a character on this realm.")
  end
end
