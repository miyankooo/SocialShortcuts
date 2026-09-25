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

  -- The action is picked before the link is read, because inside restricted content the link is a secret
  -- that cannot be pattern matched, and PickAction refuses there.
  local action = ns.PickAction()
  if not action then return end

  -- A line kept from restricted content stays secret after the lockdown ends, so its link is checked too.
  if not ns.CanAccess(link) then return end

  local name = link:match("^player:([^:]+)")
  if not name or name == "" then return end

  -- GetTime is frozen for the frame, so stamping it marks the intent as belonging to this click alone
  -- and a SetItemRef from any other source cannot consume it.
  pendingClick = { action = action, name = name, source = chatFrame, frameTime = GetTime() }
end

local function OnItemRef()
  local click = pendingClick
  pendingClick = nil
  if not click or click.frameTime ~= GetTime() then return end

  -- A CHATLINK-modified click (Shift by default) makes the default handler insert the name or run a /who
  -- instead of staging a whisper (ItemRefHandlers.lua, both clients), so the active box then holds the
  -- player's own typing and must not be wiped.
  if not IsModifiedClick("CHATLINK") then ns.CloseWhisperBox() end
  ns.RunAction(click.action, click.name, true, click.source)
end

-- Unit frames ------------------------------------------------------------------------------------

local function OnUnitFrameClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local unit = frame.displayedUnit or (frame.GetUnit and frame:GetUnit()) or frame.unit
  if not unit or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end

  -- The name Blizzard's own unit menu would pass for this unit on this client (Core/Names.lua), so invite
  -- and add friend get "First Surname" on Forever and "Name-Realm" across realms on Era.
  ns.RunAction(action, ns.UnitFullName(unit))
end

local function HookClickOnce(frame, handler)
  if not frame or hookedFrames[frame] then return end

  hookedFrames[frame] = true
  frame:HookScript("OnClick", handler)
end

local function HookUnitFrame(frame)
  HookClickOnce(frame, OnUnitFrameClick)
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
-- Forever's friends list also hands out plain Frame rows (dividers and pending invites,
-- Camelot/FriendsFrame.xml), which have no OnClick to hook and would raise if asked to.
local function AttachListClick(scrollBox, handler, rehookEveryInit)
  if not scrollBox then return end

  ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame)
    if not frame:HasScript("OnClick") then return end

    if rehookEveryInit then
      frame:HookScript("OnClick", handler)
    else
      HookClickOnce(frame, handler)
    end
  end, scrollBox)
end

-- Era builds its lists from a fixed set of named rows at load, so each row is wrapped once and for good.
local function HookNumberedRows(prefix, count, handler)
  for i = 1, count or 0 do
    HookClickOnce(_G[prefix .. i], handler)
  end
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

-- Era's who rows carry whoIndex, Forever's carry index.
local function OnWhoListClick(frame, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action then return end

  local whoIndex = frame.whoIndex or frame.index
  if not whoIndex then return end

  local info = C_FriendList.GetWhoInfo(whoIndex)
  if info and info.fullName then ns.RunAction(action, info.fullName, true) end
end

local function OnBrowseEntryClick(frame, button)
  if button ~= "LeftButton" or frame.isDelisted or frame.hasSelf then return end

  local action = ns.PickAction()
  if not action then return end

  local info = C_LFGList.GetSearchResultInfo(frame.resultID)
  if info and info.leaderName then ns.RunAction(action, info.leaderName, true) end
end

-- A Battle.net community lists accounts, whose names may be Kstrings that Blizzard only ever hands to
-- SendBNetTell (UnitPopupSharedButtonMixins.lua, the whisper button). The selected club tells them apart,
-- the same lookup Blizzard's own member click makes, and those members keep the default click.
local function IsBattleNetClub(memberList)
  local clubInfo = memberList.GetSelectedClubInfo and memberList:GetSelectedClubInfo()
  return clubInfo ~= nil and clubInfo.clubType == Enum.ClubType.BattleNet
end

local function OnGuildMemberClick(memberList, entry, button)
  if button ~= "LeftButton" then return end

  local action = ns.PickAction()
  if not action or IsBattleNetClub(memberList) then return end

  local info = entry.GetMemberInfo and entry:GetMemberInfo()
  if info and info.name then ns.RunAction(action, info.name, true) end
end

local function OnGuildRowClick(frame, button)
  if button ~= "LeftButton" or not frame.guildIndex then return end

  local action = ns.PickAction()
  if not action then return end

  local name = GetGuildRosterInfo(frame.guildIndex)
  if name then ns.RunAction(action, name, true) end
end

-- Era keeps friends, who and guild as tabs of the always-loaded FriendsFrame. The guild tab has two row
-- sets, one per roster view, and both route through the same click.
local function HookEraLists()
  for _, row in ipairs(FriendsFrameFriendsScrollFrame.buttons or {}) do
    HookClickOnce(row, OnFriendsListClick)
  end
  HookNumberedRows("WhoFrameButton", WHOS_TO_DISPLAY, OnWhoListClick)
  HookNumberedRows("GuildFrameButton", GUILDMEMBERS_TO_DISPLAY, OnGuildRowClick)
  HookNumberedRows("GuildFrameGuildStatusButton", GUILDMEMBERS_TO_DISPLAY, OnGuildRowClick)
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

  -- Only Era defines this scroll frame, so it tells the two clients apart. Forever ships the friends list
  -- as its own addon, whose rows keep the OnClick their template declares, so one wrapper per row survives.
  if FriendsFrameFriendsScrollFrame then
    HookEraLists()
  else
    EventUtil.ContinueOnAddOnLoaded("Blizzard_FriendsFrame", function()
      AttachListClick(FriendsListFrame and FriendsListFrame.ScrollBox, OnFriendsListClick, false)
    end)
  end

  -- Browse rows are load-on-demand on both clients and bind their click through a global entry point.
  -- Forever also moved the who list here, and its rows SetScript on every pass. Era has no LFGWhoListFrame,
  -- so the who hook is a no-op there.
  EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
    AttachListClick(LFGWhoListFrame and LFGWhoListFrame.ScrollBox, OnWhoListClick, true)
    hooksecurefunc("LFGBrowseSearchEntry_OnClick", OnBrowseEntryClick)
  end)

  -- On Forever the guild roster is the Communities member list. Era uses it for communities, and for the
  -- guild too when the useClassicGuildUI CVar is off. Every row click funnels through this one call, so the
  -- list itself is the only thing worth hooking.
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", function()
    local memberList = CommunitiesFrame and CommunitiesFrame.MemberList
    if not memberList then return end
    hooksecurefunc(memberList, "OnClubMemberButtonClicked", OnGuildMemberClick)
  end)
end

EventUtil.ContinueOnPlayerLogin(InstallHooks)
