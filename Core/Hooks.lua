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
-- runs the shortcut after it, so an Invite or Add Friend click also leaves Blizzard's whisper box open.
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

-- The guild roster is the Communities member list, and every row click funnels through one call.
EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", function()
  hooksecurefunc(CommunitiesFrame.MemberList, "OnClubMemberButtonClicked", OnGuildMemberClick)
end)
