-- Checks the raid container hook, the Group Finder invite and the chat link cover in Core/Hooks.lua against
-- stubs of the client. Run from the repo root: lua Tests/Hooks.lua
local hooks, notices, invites, runs = {}, {}, 0, {}
hooksecurefunc = function(target, method, hook)
  if type(target) == "string" then target, method, hook = nil, target, method end
  hooks[method] = hook
end

local function NewFrame(fields)
  local frame = fields or {}
  frame.hooks = 0
  frame.HookScript = function(self) self.hooks = self.hooks + 1 end
  return frame
end

TargetFrame = NewFrame({ totFrame = NewFrame() })
FocusFrame = NewFrame({ totFrame = NewFrame() })
PartyFrame = { PartyMemberFramePool = { EnumerateActive = function() return next, {} end } }
LFGWhoListFrame = { ScrollBox = { ForEachFrame = function() end } }
ScrollUtil = { AddInitializedFrameCallback = function() end }
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }
-- Listing 1 is solo and invitable, 2 a group, 3 solo but not invitable by you.
local members, asksToJoin = { 1, 3, 1 }, true
C_LFGList = { GetSearchResultInfo = function(id) return { leaderName = "Leader" .. id, numMembers = members[id] } end }
LFGBrowseUtil_GetInviteActionForResult = function(id)
  if id == 1 then return "Invite", function() invites = invites + 1 end end
  return "Invite", nil
end

local raidFrame, groupFrame, flaggedFrame = NewFrame({ frameType = "raid" }), NewFrame(), NewFrame({ frameType = "flagged" })
CompactRaidFrameContainer = { frameUpdateList = { normal = { raidFrame, groupFrame } } }
local loadedAddOns = { Blizzard_CompactRaidFrames = true, Blizzard_GroupFinder_VanillaStyle = true }
EventUtil = {
  ContinueOnAddOnLoaded = function(name, callback)
    if loadedAddOns[name] then callback() end
  end,
}

-- The cover is the one Button the file creates, the watch its one plain Frame.
local cover, watch, registryCallbacks = nil, nil, {}
-- UIParent starts a little off the screen's corner, in its own units.
UIParent = { GetEffectiveScale = function() return 0.5 end, GetRect = function() return 10, 20, 1000, 800 end }
CreateFrame = function(frameType, _, parent)
  local frame = { scripts = {}, shown = true, parent = parent, clears = 0 }
  function frame:RegisterForClicks() end
  function frame:SetFrameStrata(strata) self.strata = strata end
  function frame:ClearAllPoints() self.clears = self.clears + 1 end
  function frame:SetPoint(_, region, _, x, y) self.anchor = { region = region, x = x, y = y } end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:SetShown(shown) self.shown = shown end
  function frame:IsShown() return self.shown end
  function frame:SetScript(script, handler) self.scripts[script] = handler end
  if frameType == "Button" then cover = frame else watch = frame end
  return frame
end
EventRegistry = { RegisterCallback = function(_, event, callback) registryCallbacks[event] = callback end }
local chatLink, lockdown = false, false
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }

SECRET = {}
local picked, pickCalls = nil, 0
IsModifiedClick = function() return chatLink end
local ns = {
  HeldAction = function() return picked end,
  PickAction = function() pickCalls = pickCalls + 1 return picked end,
  RunAction = function(action, name, _, grouped)
    table.insert(runs, action .. " " .. name .. (grouped == nil and "" or grouped and " grouped" or " solo"))
  end,
  CanAccess = function(value) return value ~= SECRET end,
  AsksToJoin = function() return asksToJoin end,
}
assert(loadfile("Core/Hooks.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

Check("a frame the container already holds is hooked at install", raidFrame.hooks == 1)
Check("a group frame in the same list is left alone", groupFrame.hooks == 0)
table.insert(CompactRaidFrameContainer.frameUpdateList.normal, flaggedFrame)
hooks.GetUnitFrame(CompactRaidFrameContainer, "raid2", "flagged")
Check("a frame handed out later is hooked", flaggedFrame.hooks == 1)
Check("a frame is never hooked twice", raidFrame.hooks == 1)

local function ClickListing(id) hooks.LFGBrowseSearchEntry_OnClick({ resultID = id }, "LeftButton") end

picked = "invite"
ClickListing(1)
Check("an invitable listing gets Blizzard's invite", invites == 1 and #notices == 0 and #runs == 0)
ClickListing(2)
Check("while Invite asks to join, a group listing invites its leader as grouped", runs[1] == "invite Leader2 grouped")
asksToJoin = false
ClickListing(2)
Check("otherwise a group listing gets a notice", #runs == 1 and #notices == 1)
ClickListing(3)
Check("a solo listing Blizzard won't invite gets a suggestion", runs[2] == "invite Leader3 solo")
asksToJoin = true

picked = "whisper"
ClickListing(2)
Check("whisper still goes to the leader", runs[3] == "whisper Leader2")

picked, pickCalls = "whisper", 0
hooks.SetItemRef("player:Name", nil, "LeftButton")
Check("a chat whisper Blizzard makes never reaches the gate or its notice", pickCalls == 0 and #runs == 3)

-- One chat line, 300 by 12 at 100, 200 in its own units. The client reports the hovered link with its box
-- inside the line: 50 by 12, 10 from the left. The cursor rests on it.
local leaderLink, leaderText = "player:Leader:12:CHANNEL", "|Hplayer:Leader:12:CHANNEL|h[Leader]|h: LFM"
local lineScale = 1
-- The chat window holds the line container, which holds the lines.
local window = { hyperlinks = true }
function window:GetHyperlinksEnabled() return self.hyperlinks end
function window:SetHyperlinksEnabled(enabled) self.hyperlinks = enabled end
local lines = { GetEffectiveScale = function() return lineScale end, GetParent = function() return window end }
local line = { text = leaderText, visible = true }
function line:GetParent() return lines end
function line:IsVisible() return self.visible end
function line:GetText() return self.text end
function line:GetRect() return 100, 200, 300, 12 end

local cursorX, cursorY = 120, 206
GetCursorPosition = function() return cursorX * lineScale, cursorY * lineScale end
local function Enter(link, left, bottom, width, height)
  registryCallbacks["ChatFrame.OnHyperlinkEnter"](ns, "ChatFrame1", link or leaderLink, "[Leader]", line,
    left or 10, bottom or 0, width or 50, height or 12)
end
local function Leave() registryCallbacks["ChatFrame.OnHyperlinkLeave"](ns, "ChatFrame1") end
local function Update() watch.scripts.OnUpdate(watch, 0) end

runs, picked = {}, nil
Enter()
Check("a player name the client reports starts the watch, and clicks still pass through",
  watch.shown and not cover.shown)
picked = "invite"
Update()
Check("a key pressed while the cursor rests on the name shows the cover, with no key event", cover.shown)
Check("and switches the window's links off, so the link cannot take the click", window.hyperlinks == false)
Check("the cover lies on the box the client reported, in screen coordinates less UIParent's origin",
  cover.anchor.region == UIParent and cover.anchor.x == 210 and cover.anchor.y == 380
    and cover.width == 100 and cover.height == 24)
Check("the cover sits on UIParent in DIALOG", cover.parent == UIParent and cover.strata == "DIALOG")
Leave()
local clears = cover.clears
Update()
Update()
Check("once the cover took the mouse from the link, it keeps the click and stays in place",
  watch.shown and cover.shown and cover.clears == clears)
cover.scripts.OnClick()
Check("a click on the cover runs the action instead of Blizzard's whisper", runs[1] == "invite Leader")

picked = nil
Update()
Check("letting go of the key hides the cover and switches the links back on", watch.shown and not cover.shown
  and window.hyperlinks == true)
picked = "invite"
Update()
Check("pressing it again without moving takes the click again, with no new report",
  cover.shown and cover.clears == clears)

line.text = "|Hplayer:Other:13:CHANNEL|h[Other]|h: hi"
Update()
Check("a line redrawn under the cursor gives the click back to Blizzard", not cover.shown)
cover.scripts.OnClick()
Check("and a click on a stale cover acts on nothing", #runs == 1)
Enter("player:Other:13:CHANNEL")
Update()
cover.scripts.OnClick()
Check("the next report acts on the name the line shows now", runs[2] == "invite Other")
line.text = leaderText

Enter()
Update()
Leave()
cursorX = 200
Update()
Check("a cursor off the name ends the watch and leaves the links on", not watch.shown and not cover.shown
  and window.hyperlinks == true)
cursorX = 120

Enter(leaderLink, 10, -12)
Update()
Check("a box the client measures from the line's top is read that way", cover.shown and cover.anchor.y == 380)
Enter(leaderLink, 500, 500)
Update()
Check("a box that misses the cursor either way becomes a square around it",
  cover.shown and cover.anchor.x == 218 and cover.anchor.y == 380 and cover.width == 24 and cover.height == 24)
lineScale = 2
Enter()
Update()
Check("a scaled window is measured in its own scale", cover.shown and cover.anchor.x == 430 and cover.width == 200)
lineScale = 1

Enter()
Update()
Check("armed again before another report", cover.shown and window.hyperlinks == false)
local otherWindow = { hyperlinks = true, GetHyperlinksEnabled = window.GetHyperlinksEnabled,
  SetHyperlinksEnabled = window.SetHyperlinksEnabled }
lines.GetParent = function() return otherWindow end
Enter()
Check("a report from another window gives the first window its links back", window.hyperlinks == true
  and not cover.shown)
Update()
Check("and the new window's links go off while the cover shows", cover.shown and otherWindow.hyperlinks == false)
lines.GetParent = function() return window end
Enter()
Check("its links come back too", otherWindow.hyperlinks == true)
window.hyperlinks = false
Update()
picked = nil
Update()
Check("links the addon did not switch off stay off", window.hyperlinks == false)
window.hyperlinks, picked = true, "invite"

picked = "whisper"
Enter()
Update()
Check("the whisper key leaves the click to Blizzard", watch.shown and not cover.shown and window.hyperlinks == true)
picked, chatLink = "friend", true
Update()
Check("the CHATLINK key keeps Blizzard's insert-name or /who", not cover.shown)
chatLink, picked = false, "invite"
lockdown = true
Update()
Check("lockdown leaves the click to Blizzard", not cover.shown)
lockdown = false
line.visible = false
Update()
Check("a hidden line is never covered", not cover.shown)
line.visible = true

Update()
Enter("item:6948")
Update()
Check("the box of an earlier name never serves another link, and an item link is never covered",
  not watch.shown and not cover.shown)
Enter(SECRET)
Check("a secret link is never read", not watch.shown)
line.text = SECRET
Enter()
Check("a secret line is never read", not watch.shown)
line.text = leaderText
Enter(leaderLink, SECRET)
Check("a secret box is never read", not watch.shown)

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
