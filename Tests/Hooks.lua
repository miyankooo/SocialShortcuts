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

local cover, registryCallbacks = nil, {}
CreateFrame = function()
  cover = { scripts = {}, shown = false }
  function cover:EnableMouse() end
  function cover:RegisterForClicks() end
  function cover:RegisterEvent() end
  function cover:SetParent(parent) self.parent = parent end
  function cover:GetParent() return self.parent end
  function cover:ClearAllPoints() end
  function cover:SetPoint(_, region, _, x, y) self.anchor = { region = region, x = x, y = y } end
  function cover:SetSize(width, height) self.width, self.height = width, height end
  function cover:Show() self.shown = true end
  -- The client fires OnLeave on a hidden frame under the cursor (Blizzard_Menu/Menu.lua).
  function cover:Hide()
    if self.shown and self.scripts.OnLeave then self.scripts.OnLeave(self) end
    self.shown = false
  end
  function cover:IsShown() return self.shown end
  function cover:SetScript(script, handler) self.scripts[script] = handler end
  return cover
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

-- Two chat lines in one container, one unit per raw text position, so a span's area runs from its first
-- position to its last, as CalculateScreenAreaFromCharacterSpan measures it from the line's bottom left.
local leaderText = "|Hplayer:Leader:12:CHANNEL|h[Leader]|h: LFM"
local function NewLine(text, bottom)
  return {
    text = text, visible = true,
    IsObjectType = function(_, objectType) return objectType == "FontString" end,
    IsVisible = function(self) return self.visible end,
    GetRect = function() return 100, bottom, 300, 12 end,
    GetText = function(self) return self.text end,
    CalculateScreenAreaFromCharacterSpan = function(_, first, last)
      return { { left = first, bottom = 0, width = last - first, height = 12 } }
    end,
  }
end
local line, lowerLine = NewLine(leaderText, 200), NewLine("|Hplayer:Other:13:CHANNEL|h[Other]|h: hi", 186)
local highlight = { IsObjectType = function() return false end }
local window = { hyperlinks = true }
function window:GetHyperlinksEnabled() return self.hyperlinks end
local lines = { scale = 1 }
function lines:GetParent() return window end
function lines:GetEffectiveScale() return self.scale end
function lines:GetRegions() return highlight, lowerLine, line end
line.GetParent = function() return lines end

local cursorX, cursorY = 120, 206
GetCursorPosition = function() return cursorX * lines.scale, cursorY * lines.scale end
local function Hover() registryCallbacks["ChatFrame.OnHyperlinkEnter"](ns, "ChatFrame1", "player:Leader", "[Leader]", line) end
local function Update() cover.scripts.OnUpdate(cover, 0) end

runs, picked = {}, "invite"
Hover()
Check("an invite key over a player name covers exactly that name, right above its line",
  cover.shown and cover.parent == lines and cover.anchor.region == line and cover.anchor.x == 1
    and cover.anchor.y == 0 and cover.width == #leaderText - #": LFM" and cover.height == 12)
cursorX = 200
Hover()
Check("a cursor beside the name gets no cover", not cover.shown)
cursorX, lines.scale = 120, 2
Hover()
Check("a scaled window reads the cursor in its own scale", cover.shown)
lines.scale = 1

cover.scripts.OnClick()
Check("a click on the cover runs the action instead of Blizzard's whisper", runs[1] == "invite Leader")

picked = nil
cover.scripts.OnEvent()
Check("letting go of the key removes the cover", not cover.shown)
picked = "invite"
cover.scripts.OnEvent()
Check("pressing it again over the same name brings the cover back, though hiding fired OnLeave", cover.shown)

line.text = lowerLine.text
Update()
cover.scripts.OnClick()
Check("a line redrawn under a still cursor acts on the name it shows now", runs[2] == "invite Other")
line.text = "plain chat"
Update()
Check("a redraw that leaves no name under the cursor removes the cover", not cover.shown)
cover.scripts.OnClick()
Check("and a click then acts on nothing", #runs == 2)
line.text = leaderText

cursorY = 190
cover.scripts.OnEvent()
Check("the cursor on another line of the window gets that line's name", cover.shown and cover.anchor.region == lowerLine)
cursorY = 206
line.visible = false
cover.scripts.OnEvent()
Check("a hidden line under the cursor shows no name", not cover.shown)
line.visible = true
window.hyperlinks = false
cover.scripts.OnEvent()
Check("an uninteractable chat window gets no cover", not cover.shown)
window.hyperlinks = true
line.text = SECRET
cover.scripts.OnEvent()
Check("a secret line is never read", not cover.shown)
line.text = leaderText

picked = "whisper"
Hover()
Check("the whisper key leaves the click to Blizzard", not cover.shown)
picked, chatLink = "friend", true
Hover()
Check("the CHATLINK key keeps Blizzard's insert-name or /who", not cover.shown)
chatLink, picked = false, "invite"
line.text = "|Hitem:6948|h[Hearthstone]|h"
Hover()
Check("an item link is never covered", not cover.shown)
line.text = leaderText
lockdown = true
Hover()
Check("lockdown leaves the click to Blizzard", not cover.shown)
lockdown = false

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
