-- Checks the raid container hook, the Group Finder invite and the chat link hook in Core/Hooks.lua against
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

local chatLink = false

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

picked = "invite"
hooks.SetItemRef("player:Leader:12:CHANNEL", nil, "LeftButton")
Check("an invite click on a chat name invites the player", runs[4] == "invite Leader")
hooks.SetItemRef("item:6948", nil, "LeftButton")
Check("an item link is never acted on", #runs == 4)
hooks.SetItemRef(SECRET, nil, "LeftButton")
Check("a secret link is never read", #runs == 4)

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
