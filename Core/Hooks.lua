local _, ns = ...

-- Frames we have already wrapped, so a pooled row is never wrapped twice and does not fire the action
-- once per wrap.
local hookedFrames = {}

local function HookScriptOnce(frame, script, handler)
  if hookedFrames[frame] then return end

  hookedFrames[frame] = true
  frame:HookScript(script, handler)
end

-- Chat name links --------------------------------------------------------------------------------

-- Every text that shows a player link calls SetItemRef with the click (ChatFrame.lua,
-- CommunitiesChatFrame.xml), and Blizzard's handler runs first and cannot be cancelled: CHATLINK (Shift)
-- inserts the name or runs a /who, any other left click opens a whisper (ItemRefHandlers.lua). The post-hook
-- serves the clicks the link cover below leaves to Blizzard: the CHATLINK key, lockdown and text outside the
-- chat windows.
local function PlayerNameFromLink(link)
  local name = link:match("^player:([^:]+)") or link:match("^playerCommunity:([^:]+)")
  if name and name ~= "" then return name end
end

local function OnItemRef(link, _, button, chatFrame)
  if button ~= "LeftButton" then return end

  -- Blizzard's own link handler whispers on every left click that is not CHATLINK-modified (Shift by
  -- default, ItemRefHandlers.lua), so that whisper is left to it, inside lockdown too, and the addon adds
  -- no second one and no notice.
  if ns.HeldAction() == "whisper" and not IsModifiedClick("CHATLINK") then return end

  -- The action is picked before the link is read, because inside restricted content the link is a secret
  -- that cannot be pattern matched, and PickAction refuses there.
  local action = ns.PickAction()
  if not action then return end

  -- A line kept from restricted content stays secret after the lockdown ends, so its link is checked too.
  if not ns.CanAccess(link) or type(link) ~= "string" then return end

  local name = PlayerNameFromLink(link)
  if name then ns.RunAction(action, name, chatFrame) end
end

-- While a key bound to Invite or Add Friend is held over a player name in chat, an addon button covers that
-- name and takes the click, and the chat window's links are off, so Blizzard never sees the click and no
-- whisper opens. The whisper key keeps Blizzard's own whisper.
--
-- The client itself says which name is under the cursor: a chat window reports the hovered link, its line and
-- the link's box when the cursor enters it, and reports when it leaves (ChatFrame.lua). The cover keeps that
-- report and works nothing out from the text. It only checks that the line still shows what it showed, since
-- new chat redraws the lines under a still cursor.
--
-- The cover sits on UIParent in DIALOG, placed in screen coordinates, and takes clicks by being shown. A second
-- frame watches while the cover is hidden. In game a chat link took the click even with the cover shown on top
-- of it as the mouse focus, so the cover alone cannot stop the whisper. The window's links are switched off for
-- as long as the cover shows, the way Blizzard switches them off for an uninteractable window
-- (FloatingChatFrame.lua). That is widget state, no Lua value of Blizzard's, so it taints nothing. Only links the
-- addon switched off are switched back on.
local hovered = {} -- the reported link: active, name, line, text, left, bottom, width, height
local mutedWindow -- the chat window whose links are off while the cover shows
local box = {} -- the cover's box on screen in cursor units: left, bottom, right, top
local linkWatch = CreateFrame("Frame")
linkWatch:Hide()
local linkCover = CreateFrame("Button", nil, UIParent)
linkCover:SetFrameStrata("DIALOG")
linkCover:RegisterForClicks("LeftButtonUp")
linkCover:Hide()

local function TakesChatClick()
  local action = ns.HeldAction()
  return action and action ~= "whisper" and not IsModifiedClick("CHATLINK")
    and not C_ChatInfo.InChatMessagingLockdown()
end

-- A line kept from restricted content can hold secret text, so it is checked before the comparison.
local function LinkStillThere()
  if not hovered.line:IsVisible() then return false end

  local text = hovered.line:GetText()
  return ns.CanAccess(text) and text == hovered.text
end

local function InBox(x, y)
  return box.left and x >= box.left and x <= box.right and y >= box.bottom and y <= box.top
end

-- The client reports the link's box inside its line. Blizzard's own code reads it from the line's bottom left
-- (GameDialogDefs.lua) and from its top left (Blizzard_EncounterJournal.lua), so the cover takes the reading
-- that holds the cursor, which is on the link while the client reports it. With neither, a square of the
-- link's height around the cursor still takes the click. Geometry turns secret where the client restricts it,
-- so it is checked first. UIParent need not start at the screen's corner, so its own origin is taken off.
local function PlaceCover(x, y)
  local line = hovered.line
  local scale = line:GetParent():GetEffectiveScale()
  local left, bottom, _, lineHeight = line:GetRect()
  if not ns.CanAccess(scale) or not ns.CanAccess(left) or not left then return false end

  local width, height = hovered.width * scale, hovered.height * scale
  box.left, box.bottom = (left + hovered.left) * scale, (bottom + hovered.bottom) * scale
  box.right, box.top = box.left + width, box.bottom + height
  if not InBox(x, y) then
    box.bottom = box.bottom + lineHeight * scale
    box.top = box.bottom + height
  end
  if not InBox(x, y) then
    box.left, box.bottom = x - height / 2, y - height / 2
    box.right, box.top = box.left + height, box.bottom + height
  end

  local uiScale = UIParent:GetEffectiveScale()
  local uiLeft, uiBottom = UIParent:GetRect()
  linkCover:ClearAllPoints()
  linkCover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", box.left / uiScale - uiLeft, box.bottom / uiScale - uiBottom)
  linkCover:SetSize((box.right - box.left) / uiScale, (box.top - box.bottom) / uiScale)
  return true
end

local function ArmCover(arm)
  if arm == linkCover:IsShown() then return end

  linkCover:SetShown(arm)
  if arm then
    local window = hovered.line:GetParent():GetParent()
    if window:GetHyperlinksEnabled() then
      mutedWindow = window
      window:SetHyperlinksEnabled(false)
    end
  elseif mutedWindow then
    -- Links switched back on under the cursor can report it at once, so the window is let go first.
    local window = mutedWindow
    mutedWindow = nil
    window:SetHyperlinksEnabled(true)
  end
end

-- Runs every frame from the report of a player link until the cursor is off it. The keys are read here, so a
-- key pressed while the cursor rests on the name needs no key event. While the cover shows, the client reports
-- the link as left, and the cover's own box says the cursor is still on the name. The box
-- is kept after the key is let go, so pressing it again without moving the cursor takes the click again.
local function UpdateLinkCover()
  local x, y = GetCursorPosition()
  if not hovered.active and not InBox(x, y) then
    box.left = nil
    linkWatch:Hide()
    ArmCover(false)
    return
  end

  ArmCover(TakesChatClick() and LinkStillThere() and (box.left ~= nil or PlaceCover(x, y)) or false)
end

-- Every report starts over: the box and the switched-off links of an earlier link never serve a new one. A link
-- from restricted content is a secret and is never read, and neither are a secret line or box.
local function OnChatLinkEnter(link, line, left, bottom, width, height)
  box.left = nil
  ArmCover(false)
  local name = ns.CanAccess(link) and type(link) == "string" and PlayerNameFromLink(link)
  local text = name and line:GetText()
  hovered.active = name and ns.CanAccess(text) and ns.CanAccess(left) and true or false
  if not hovered.active then return end

  hovered.name, hovered.line, hovered.text = name, line, text
  hovered.left, hovered.bottom, hovered.width, hovered.height = left, bottom, width, height
  linkWatch:Show()
end

local function OnChatLinkLeave()
  hovered.active = false
end

linkWatch:SetScript("OnUpdate", UpdateLinkCover)
linkCover:SetScript("OnClick", function()
  local action = LinkStillThere() and ns.PickAction()
  if action then ns.RunAction(action, hovered.name) end
end)


-- Unit frames ------------------------------------------------------------------------------------

-- Unit comparison has restrictions of its own, apart from the chat lockdown: the client refuses a
-- comparison it does not permit and returns a secret for a restricted one, so both are asked before
-- UnitIsUnit.
local function IsOtherPlayer(unit)
  if not UnitIsPlayer(unit) then return false end
  if not C_Secrets.CanCompareUnitTokens(unit, "player") then return false end
  if C_Secrets.ShouldUnitComparisonBeSecret(unit, "player") then return false end
  return not UnitIsUnit(unit, "player")
end

-- Compact frames carry displayedUnit and party member frames GetUnit, which keeps the member's own unit
-- while they ride a vehicle. Target and focus frames only carry unit.
local function OnUnitFrameClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local unit = frame.displayedUnit or (frame.GetUnit and frame:GetUnit()) or frame.unit
  if not unit or not IsOtherPlayer(unit) then return end

  -- The name Blizzard's own unit menu would pass for this unit (Core/Names.lua), so invite and add friend
  -- get "First Surname". The group check is the one Blizzard's menu makes before it offers Request to Join.
  ns.RunAction(action, ns.UnitFullName(unit), nil, UnitInAnyGroup(unit, LE_PARTY_CATEGORY_HOME))
end

local function HookUnitFrame(frame)
  HookScriptOnce(frame, "OnClick", OnUnitFrameClick)
end

-- The compact setup also runs for nameplates and pet frames, which take no clicks and may be forbidden to
-- addon code. Party and raid player frames are the ones set up with DefaultCompactUnitFrameSetup
-- (CompactPartyFrame.lua, Blizzard_CompactRaidFrameContainer.lua), and the function is a plain value.
local function OnCompactFrameSetUp(frame, setUpFunc)
  if setUpFunc == DefaultCompactUnitFrameSetup then HookUnitFrame(frame) end
end

-- The raid container passes the setup function it stored when it loaded
-- (Blizzard_CompactRaidFrameContainer.lua), so once another addon hooks DefaultCompactUnitFrameSetup the
-- check above misses its frames. Its player frames all sit in its normal update list, and the group frames
-- sharing that list carry no frameType.
local function HookRaidContainerFrames(container)
  for _, frame in ipairs(container.frameUpdateList.normal) do
    if frame.frameType then HookUnitFrame(frame) end
  end
end

local function HookPartyFrames()
  for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
    HookUnitFrame(frame)
  end
end

local function HookUnitFrames()
  HookUnitFrame(TargetFrame)
  HookUnitFrame(TargetFrame.totFrame)
  HookUnitFrame(FocusFrame)
  HookUnitFrame(FocusFrame.totFrame)

  -- Party member frames come from a pool, so re-walk it whenever the pool is rebuilt.
  HookPartyFrames()
  hooksecurefunc(PartyFrame, "InitializePartyMemberFrames", HookPartyFrames)

  -- Raid frames and raid-style party frames all pass through this one setup call.
  hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactFrameSetUp)
end

-- Scrolling lists --------------------------------------------------------------------------------

-- Rows are pooled and re-initialised as the list scrolls, so the wrapper goes on the rows the scroll box
-- already holds and then on each row as it is handed out. The friends list also hands out plain Frame rows
-- (dividers and pending invites, Camelot/FriendsFrame.xml), which have no OnClick to hook and would raise
-- if asked to.
local function AttachListClick(scrollBox, script, handler)
  local function HookRow(frame)
    if frame:HasScript(script) then HookScriptOnce(frame, script, handler) end
  end

  scrollBox:ForEachFrame(HookRow)
  ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame) HookRow(frame) end, ns)
end

local function OnFriendsListClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  if frame.buttonType == FRIENDS_BUTTON_TYPE_WOW then
    local info = C_FriendList.GetFriendInfoByIndex(frame.id)
    if info and info.name then ns.RunAction(action, info.name) end
  elseif frame.buttonType == FRIENDS_BUTTON_TYPE_BNET then
    ns.RunBNetAction(action, frame.id)
  end
end

-- Who rows register RightButtonUp only (WhoList.xml), so a left click never reaches OnClick. Mouse-up
-- still fires for it, and upInside keeps a press dragged off the row from counting as a click.
local function OnWhoListMouseUp(frame, button, upInside)
  if button ~= "LeftButton" or not upInside or not frame.index then return end

  local action = ns.PickAction()
  if not action then return end

  local info = C_FriendList.GetWhoInfo(frame.index)
  if info and info.fullName then ns.RunAction(action, info.fullName) end
end

local function OnBrowseEntryClick(frame, button)
  if button ~= "LeftButton" or frame.isDelisted or frame.hasSelf then return end

  local action = ns.PickAction()
  if not action then return end

  local info = C_LFGList.GetSearchResultInfo(frame.resultID)
  local leader = info and info.leaderName
  if not leader then return end
  if action ~= "invite" then
    ns.RunAction(action, leader)
    return
  end

  -- Blizzard's own entry menu offers Invite only on a one-member listing while the player may invite
  -- (Blizzard_LFGVanilla_Browse.lua), and the shortcut runs that same function. Past it, a one-member
  -- listing can only mean a group without lead, so Invite suggests, and a group listing gets a join request
  -- while Invite asks to join. Anything else says so where the menu greys the button out.
  local _, invite = LFGBrowseUtil_GetInviteActionForResult(frame.resultID)
  local grouped = info.numMembers > 1
  if invite then
    invite()
  elseif not grouped or ns.AsksToJoin() then
    ns.RunAction("invite", leader, nil, grouped)
  else
    UIErrorsFrame:AddExternalErrorMessage("Invite isn't available for this listing.")
  end
end

-- A Battle.net community lists accounts, whose names may be Kstrings that Blizzard only ever hands to
-- SendBNetTell (UnitPopupSharedButtonMixins.lua, the whisper button). The selected club tells them apart,
-- the same lookup Blizzard's own member click makes, and those members keep the default click.
local function IsBattleNetClub(memberList)
  local clubInfo = memberList:GetSelectedClubInfo()
  return clubInfo ~= nil and clubInfo.clubType == Enum.ClubType.BattleNet
end

local function OnGuildMemberClick(memberList, entry, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action or IsBattleNetClub(memberList) then return end

  local info = entry:GetMemberInfo()
  if info and info.name then ns.RunAction(action, info.name) end
end

-- Install ----------------------------------------------------------------------------------------

-- Hooks go in at file load rather than login, so no frame the client sets up in between is missed.
hooksecurefunc("SetItemRef", OnItemRef)

-- Every chat window reports link hovers through these two events, with the link, its line and its box
-- (ChatFrame.lua).
EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", function(_, _, link, _, line, ...) OnChatLinkEnter(link, line, ...) end, ns)
EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnChatLinkLeave, ns)

HookUnitFrames()

-- The friends list rows keep the OnClick their template declares, so one wrapper per row survives.
EventUtil.ContinueOnAddOnLoaded("Blizzard_FriendsFrame", function()
  AttachListClick(FriendsListFrame.ScrollBox, "OnClick", OnFriendsListClick)
end)

-- The who row initialiser calls SetScript("OnClick") on every pass but leaves OnMouseUp alone, so one
-- wrapper per row survives there too. Browse rows bind their click through a global entry point.
EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
  AttachListClick(LFGWhoListFrame.ScrollBox, "OnMouseUp", OnWhoListMouseUp)
  hooksecurefunc("LFGBrowseSearchEntry_OnClick", OnBrowseEntryClick)
end)

-- Raid frames in the flat layout come from the container, so its list is walked whenever it hands one out.
EventUtil.ContinueOnAddOnLoaded("Blizzard_CompactRaidFrames", function()
  HookRaidContainerFrames(CompactRaidFrameContainer)
  hooksecurefunc(CompactRaidFrameContainer, "GetUnitFrame", HookRaidContainerFrames)
end)

-- The guild roster is the Communities member list, and every row click funnels through one call. The
-- Communities chat is a plain message frame without the chat window events, so its own link scripts are
-- hooked (CommunitiesChatFrame.xml).
EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", function()
  hooksecurefunc(CommunitiesFrame.MemberList, "OnClubMemberButtonClicked", OnGuildMemberClick)

  local messageFrame = CommunitiesFrame.Chat.MessageFrame
  messageFrame:HookScript("OnHyperlinkEnter", function(_, link, _, line, ...) OnChatLinkEnter(link, line, ...) end)
  messageFrame:HookScript("OnHyperlinkLeave", OnChatLinkLeave)
end)
