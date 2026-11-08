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
UIParent = { GetEffectiveScale = function() return 1 end }
CreateFrame = function()
  cover = { scripts = {}, shown = false }
  function cover:SetFrameStrata() end
  function cover:EnableMouse() end
  function cover:SetScale(scale) self.scale = scale end
  function cover:RegisterForClicks() end
  function cover:RegisterEvent() end
  function cover:ClearAllPoints() end
  function cover:SetPoint(_, region, _, x, y) self.anchor = { region = region, x = x, y = y } end
  function cover:SetSize(width, height) self.width, self.height = width, height end
  function cover:Show() self.shown = true end
  function cover:Hide() self.shown = false end
  function cover:IsShown() return self.shown end
  function cover:SetScript(script, handler) self.scripts[script] = handler end
  return cover
end
EventRegistry = { RegisterCallback = function(_, event, callback) registryCallbacks[event] = callback end }
local chatLink, lockdown = false, false
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }

local picked, pickCalls = nil, 0
IsModifiedClick = function() return chatLink end
local ns = {
  HeldAction = function() return picked end,
  PickAction = function() pickCalls = pickCalls + 1 return picked end,
  RunAction = function(action, name, _, grouped)
    table.insert(runs, action .. " " .. name .. (grouped == nil and "" or grouped and " grouped" or " solo"))
  end,
  CanAccess = function() return true end,
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

-- A two-row line at 100, 200 with the name on its bottom row, from x 10 to 50, and the cursor on the name.
local line = {
  text = "[Leader]: LFM", scale = 1,
  GetText = function(self) return self.text end,
  GetEffectiveScale = function(self) return self.scale end,
  GetRect = function() return 100, 200, 300, 24 end,
}
local cursorX, cursorY = 120, 206
GetCursorPosition = function() return cursorX * line.scale, cursorY * line.scale end
local function Hover(link, bottom)
  registryCallbacks["ChatFrame.OnHyperlinkEnter"](nil, "ChatFrame1", link, "[Leader]", line, 10, bottom or 0, 40, 12)
end

runs, picked = {}, "invite"
Hover("player:Leader:12:CHANNEL")
Check("an invite key over a player name covers exactly that name",
  cover.shown and cover.anchor.region == line and cover.anchor.x == 10 and cover.anchor.y == 0
    and cover.width == 40 and cover.height == 12)
Hover("player:Leader:12:CHANNEL", -24)
Check("bounds read from the line's top left cover the same name", cover.shown and cover.anchor.y == 0)
cursorX = 200
Hover("player:Leader:12:CHANNEL")
Check("a cursor beside the bounds gets no cover", not cover.shown)
cursorX, line.scale = 120, 2
Hover("player:Leader:12:CHANNEL")
Check("a scaled line scales the cover with it", cover.shown and cover.scale == 2)
line.scale = 1
Hover("player:Leader:12:CHANNEL")
registryCallbacks["ChatFrame.OnHyperlinkLeave"]()
Check("the cover taking the mouse keeps the name", cover.shown)
cover.scripts.OnClick()
Check("a click on the cover runs the action instead of Blizzard's whisper", runs[1] == "invite Leader")

line.text = "[Other]: hi"
cover.scripts.OnClick()
Check("a redrawn line drops the click and the cover", #runs == 1 and not cover.shown)
line.text = "[Leader]: LFM"

picked = "whisper"
Hover("player:Leader:12:CHANNEL")
Check("the whisper key leaves the click to Blizzard", not cover.shown)
picked, chatLink = "friend", true
Hover("player:Leader:12:CHANNEL")
Check("the CHATLINK key keeps Blizzard's insert-name or /who", not cover.shown)
chatLink, picked = false, "invite"
Hover("item:6948")
Check("an item link is never covered", not cover.shown)
lockdown = true
Hover("player:Leader:12:CHANNEL")
Check("lockdown leaves the click to Blizzard", not cover.shown)
lockdown = false

Hover("player:Leader:12:CHANNEL")
picked = nil
cover.scripts.OnEvent()
Check("letting go of the key removes the cover", not cover.shown)
picked = "invite"
cover.scripts.OnEvent()
Check("pressing it again over the name brings the cover back", cover.shown)
cover.scripts.OnLeave()
cover.scripts.OnEvent()
Check("leaving the name drops it", not cover.shown)

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
