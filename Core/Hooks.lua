local _, ns = ...

-- Frames we have already wrapped, so a pooled row is never wrapped twice and does not fire the action
-- once per wrap.
local hookedFrames = {}

-- Chat name links --------------------------------------------------------------------------------

local pendingClick

-- The chat frame triggers this callback before it calls SetItemRef, so the intent is only recorded here
-- and acted on once the default link handling has run and opened its whisper box.
local function OnChatNameClick(_, chatFrame, link, _, button)
  pendingClick = nil
  if button ~= "LeftButton" then return end
  if ns.ChatRestricted() then return end

  local name = link:match("^player:([^:]+)")
  if not name or name == "" then return end

  local action = ns.PickAction()
  if not action then return end

  -- GetTime is frozen for the frame, so stamping it marks the intent as belonging to this click alone
  -- and a SetItemRef from any other source cannot consume it.
  pendingClick = { action = action, name = name, source = chatFrame, frameTime = GetTime() }
end

local function OnItemRef()
  local click = pendingClick
  pendingClick = nil
  if not click or click.frameTime ~= GetTime() then return end

  ns.CloseWhisperBox()
  ns.RunAction(click.action, click.name, true, click.source)
end

-- Unit frames ------------------------------------------------------------------------------------

local function OnUnitFrameClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local unit = frame.displayedUnit or (frame.GetUnit and frame:GetUnit()) or frame.unit
  if not unit or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end

  ns.RunAction(action, GetUnitName(unit, true))
end

local function HookUnitFrame(frame)
  if not frame or hookedFrames[frame] then return end

  hookedFrames[frame] = true
  frame:HookScript("OnClick", OnUnitFrameClick)
end

local function HookPartyFrames()
  for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
    HookUnitFrame(frame)
  end
end

local function HookUnitFrames()
  HookUnitFrame(TargetFrame)
  HookUnitFrame(TargetFrame and TargetFrame.totFrame)
  HookUnitFrame(FocusFrame)
  HookUnitFrame(FocusFrame and FocusFrame.totFrame)

  -- Party member frames come from a pool, so re-walk it whenever the pool is rebuilt.
  if PartyFrame and PartyFrame.PartyMemberFramePool then
    HookPartyFrames()
    hooksecurefunc(PartyFrame, "InitializePartyMemberFrames", HookPartyFrames)
  end

  -- Raid frames and raid-style party frames all pass through this one setup call.
  hooksecurefunc("CompactUnitFrame_SetUpFrame", HookUnitFrame)
end

-- Scrolling lists --------------------------------------------------------------------------------

-- Rows are pooled and re-initialised as the list scrolls, so the wrapper is attached per row as the
-- scroll box hands it out. rehookEveryInit covers the lists whose own initialiser calls SetScript on
-- every pass: that call drops our wrapper, so those must be wrapped again and cannot be guarded.
local function AttachListClick(scrollBox, handler, rehookEveryInit)
  if not scrollBox then return end

  ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame)
    if not rehookEveryInit then
      if hookedFrames[frame] then return end
      hookedFrames[frame] = true
    end
    frame:HookScript("OnClick", handler)
  end, scrollBox)
end

local function OnFriendsListClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  if frame.buttonType == FRIENDS_BUTTON_TYPE_WOW then
    local info = C_FriendList.GetFriendInfoByIndex(frame.id)
    if info and info.name then ns.RunAction(action, info.name, true) end
  elseif frame.buttonType == FRIENDS_BUTTON_TYPE_BNET then
    ns.RunBNetAction(action, frame.id)
  end
end

local function OnWhoListClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local info = C_FriendList.GetWhoInfo(frame.index)
  if info and info.fullName then ns.RunAction(action, info.fullName, true) end
end

local function OnBrowseEntryClick(frame, button)
  if button ~= "LeftButton" or frame.isDelisted or frame.hasSelf then return end

  local action = ns.PickAction()
  if not action then return end

  local info = C_LFGList.GetSearchResultInfo(frame.resultID)
  if info and info.leaderName then ns.RunAction(action, info.leaderName, true) end
end

local function OnGuildMemberClick(_, entry, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local info = entry.GetMemberInfo and entry:GetMemberInfo()
  if info and info.name then ns.RunAction(action, info.name, true) end
end

-- Install ----------------------------------------------------------------------------------------

local function InstallHooks()
  -- The predecessor WeakAura installs the same hooks under this frame name and its own hooks cannot be
  -- taken back out, so say so rather than let every click quietly fire twice.
  if SuperSocialWAHost then
    ns.Print("the Chat Shortcuts WeakAura is still active and does the same job. Disable it and /reload, or every click fires twice.")
  end

  EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkClick", OnChatNameClick, ns.addonName)
  hooksecurefunc("SetItemRef", OnItemRef)

  HookUnitFrames()

  -- The friends list keeps the OnClick its template declares, so one wrapper per row survives.
  EventUtil.ContinueOnAddOnLoaded("Blizzard_FriendsFrame", function()
    AttachListClick(FriendsListFrame and FriendsListFrame.ScrollBox, OnFriendsListClick, false)
  end)

  -- Who and browse rows are load-on-demand, and each binds its click differently: the browse row through
  -- a global entry point, the who row through a SetScript on every pass.
  EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
    AttachListClick(LFGWhoListFrame and LFGWhoListFrame.ScrollBox, OnWhoListClick, true)
    hooksecurefunc("LFGBrowseSearchEntry_OnClick", OnBrowseEntryClick)
  end)

  -- The guild roster is the Communities member list on this client, and every row click funnels through
  -- this one call, so the list itself is the only thing worth hooking.
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", function()
    local memberList = CommunitiesFrame and CommunitiesFrame.MemberList
    if not memberList then return end
    hooksecurefunc(memberList, "OnClubMemberButtonClicked", OnGuildMemberClick)
  end)
end

EventUtil.ContinueOnPlayerLogin(InstallHooks)
