local _, ns = ...

local dropdowns = {}
local askToJoinCheckbox

local askToJoin = {
  label = "Invite Asks to Join",
  help = "While you're not in a group, inviting a player who is already in one asks to join their group instead.",
}

-- Text in a font role: GameFontNormal (heading, gold), GameFontHighlight (body, white), GameFontDisable (muted,
-- grey), GameFontNormalLarge (title, 16 px, a dialog's subject line only).
local function CreateText(parent, fontObject, layer)
  local text = parent:CreateFontString(nil, layer or "ARTWORK")
  text:SetFontObject(fontObject or GameFontHighlight)
  text:SetJustifyH("LEFT")
  return text
end

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. A frame whose
-- template already sets OnEnter gets HookScript instead.
local function AttachTooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- Blizzard's menu dropdown, filled with SetupMenu. Its art hangs 8 px past each side, so the caller indents it by 8.
local function CreateDropdown(parent, width, name)
  local dropdown = CreateFrame("DropdownButton", name, parent, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(width or 160)
  return dropdown
end

-- The addon's page in Blizzard's Settings window, as its own canvas, copying the settings list's look
-- (Blizzard_SettingsList.xml:14-30, Blizzard_SettingControls.xml, Blizzard_SettingControls.lua). Never a settings
-- list: a pick in a list dropdown runs addon code in Blizzard's pooled controls and taints its settings until /reload.
-- Seen here on build 70532: nameplate errors until /reload (2026-10-21).
local ROW_HEIGHT, ROW_SPACING, LABEL_X, INTRO_Y, INTRO_GAP = 26, 9, 37, -64, 16
local categoryID

-- The dropdowns and the checkbox share one left edge, CENTER -40 of the row, so the checkbox reads as part of
-- Invite above it. Its help sits a tight step under it.
local CONTROL_X = -40
local HELP_GAP = 4

local function BuildPanel(introText, restoreDefaults)
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(ns.title)
  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOP", 0, -50)
  local defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defaults:SetSize(96, 22)
  defaults:SetPoint("TOPRIGHT", -36, -16)
  defaults:SetText(SETTINGS_DEFAULTS)
  defaults:SetScript("OnClick", restoreDefaults)
  panel.intro = CreateText(panel, GameFontHighlight)
  panel.intro:SetPoint("TOPLEFT", LABEL_X, INTRO_Y)
  panel.intro:SetPoint("TOPRIGHT", -LABEL_X, INTRO_Y)
  panel.intro:SetText(introText)
  return panel
end

-- One row below the intro, its label in GameFontNormal from x 37 to the row's centre less 85. A checkbox
-- (SettingsCheckboxTemplate) goes at the row's CENTER -80, a WowStyle1DropdownTemplate 220 wide at CENTER -48.
-- Within one page, controls share one left edge.
local function AddRow(panel, index, label, fillTooltip)
  local y = -INTRO_GAP - (index - 1) * (ROW_HEIGHT + ROW_SPACING)
  local row = CreateFrame("Frame", nil, panel)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", panel.intro, "BOTTOMLEFT", -LABEL_X, y)
  row:SetPoint("TOPRIGHT", panel.intro, "BOTTOMRIGHT", LABEL_X, y)
  row:EnableMouse(true)
  AttachTooltip(row, fillTooltip)
  local text = CreateText(row, GameFontNormal)
  text:SetPoint("LEFT", LABEL_X, 0)
  text:SetPoint("RIGHT", row, "CENTER", -85, 0)
  text:SetText(label)
  return row
end

local function RegisterPanel(panel)
  local category = Settings.RegisterCanvasLayoutCategory(panel, ns.title)
  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

-- The page is the addon's only visible surface, so its top says what the keys do before any row asks for
-- one. The keys are named from the platform's own list, so Windows never reads Command.
local function IntroText()
  local keys = {}
  for _, token in ipairs(ns.modifierOrder) do
    if token ~= "NONE" then table.insert(keys, ns.modifierLabel[token]) end
  end
  local last = table.remove(keys)
  local held = #keys > 0 and table.concat(keys, ", ") .. " or " .. last or last

  return "Hold " .. held .. " and left-click a player's name or frame to whisper them, add them as a friend "
    .. "or invite them, without the right-click menu. Pick the key for each action below.\n\n"
    .. "Works in chat, on unit frames, in the friends list, the Who list, the guild roster and Group Finder.\n\n"
    .. "Other clicks work as always: a plain click on a name in chat opens a whisper, and Shift-click "
    .. "inserts the name or runs a /who."
end

-- The tooltip a row and its control share: the setting's name over its help.
local function FillHelp(entry)
  return function(tooltip)
    GameTooltip_SetTitle(tooltip, entry.label)
    GameTooltip_AddNormalLine(tooltip, entry.help)
  end
end

-- A swap can change another row, and its menu is closed, so a refresh of its selection text is enough.
local function RefreshDropdowns()
  for _, dropdown in pairs(dropdowns) do dropdown:Update() end
end

local function AddActionRow(panel, action, index)
  local fillTooltip = FillHelp(action)
  local row = AddRow(panel, index, action.label, fillTooltip)

  local dropdown = CreateDropdown(row, 220)
  dropdown:SetPoint("LEFT", row, "CENTER", CONTROL_X, 0)
  -- The template sets its own OnEnter for its hover art, so the help hooks it.
  dropdown:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    fillTooltip(GameTooltip, self)
    GameTooltip:Show()
  end)
  dropdown:HookScript("OnLeave", GameTooltip_Hide)
  dropdown:SetupMenu(function(_, rootDescription)
    for _, token in ipairs(ns.modifierOrder) do
      local radio = rootDescription:CreateRadio(ns.modifierLabel[token],
        function() return ns.db[action.key] == token end,
        function()
          ns.AssignModifier(action.key, token)
          RefreshDropdowns()
        end)

      -- The menu is rebuilt on every open, so the game option is read fresh. Disabled with an error line, the
      -- way Blizzard's dungeon finder greys out a choice (LFDFrame.lua).
      if token == "META" and not ns.IsCommandFree() then
        radio:SetEnabled(false)
        radio:SetTooltip(function(tooltip)
          GameTooltip_SetTitle(tooltip, ns.modifierLabel.META)
          GameTooltip_AddErrorLine(tooltip, ns.CommandBlockedLine())
        end)
      end
    end
  end)

  -- Generated once here, because the frame is hidden until the panel shows it.
  dropdown:GenerateMenu()
  dropdowns[action.key] = dropdown
end

-- The checkbox is the one Blizzard's settings list builds for a checkbox row (SettingsCheckboxControlMixin),
-- placed on the addon's own canvas for the same taint reason as the dropdowns. It lines up with the left
-- edge of the Invite dropdown above it, since it only changes what Invite does. Its help shows under it,
-- because when it applies is not clear from the label alone. Init wires the click to its own callback
-- registry, the way the list control listens to it.
local function AddAskToJoinRow(panel, index)
  local fillTooltip = FillHelp(askToJoin)
  local row = AddRow(panel, index, askToJoin.label, fillTooltip)

  local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
  checkbox:SetPoint("LEFT", row, "CENTER", CONTROL_X, 0)

  -- Below the checkbox and starting at its left edge, so a wrap grows down into free space and never into
  -- the Invite row above.
  local help = CreateText(row, GameFontHighlight)
  help:SetPoint("TOPLEFT", row, "BOTTOM", CONTROL_X, -HELP_GAP)
  help:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", -LABEL_X, -HELP_GAP)
  help:SetText(askToJoin.help)

  checkbox:Init(ns.db.askToJoin, function() fillTooltip(SettingsTooltip) end)
  checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
    ns.db.askToJoin = checked
  end, row)
  askToJoinCheckbox = checkbox
end

local function RestoreDefaults()
  for key, value in pairs(ns.defaults) do ns.db[key] = value end
  askToJoinCheckbox:SetValue(ns.db.askToJoin)
  local note = ns.FreeCommandKey()
  if note then ns.Print(note) end
  RefreshDropdowns()
end

EventUtil.ContinueOnPlayerLogin(function()
  local panel = BuildPanel(IntroText(), RestoreDefaults)
  for index, action in ipairs(ns.actions) do AddActionRow(panel, action, index) end
  AddAskToJoinRow(panel, #ns.actions + 1)
  RegisterPanel(panel)
end)

-- Opening in combat waits for combat to end, since the settings panel's open path has restrictions.
local waitingForCombat = false
function ns.OpenSettings()
  if not categoryID then return end
  if InCombatLockdown() then
    ns.Print("Opens after combat.")
    if not waitingForCombat then
      waitingForCombat = true
      EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
        waitingForCombat = false
        ns.OpenSettings()
      end)
    end
    return
  end
  Settings.OpenToCategory(categoryID)
end

-- One long command and one short alias. The bare command opens the main surface; help, intro and minimap
-- (where there is a minimap button) are the shared words, and any other word prints the hint.
SLASH_SOCIALSHORTCUTS1, SLASH_SOCIALSHORTCUTS2 = "/socialshortcuts", "/ssc"
SlashCmdList.SOCIALSHORTCUTS = function(message)
  local command = strtrim(message or ""):lower()
  if command == "" then
    ns.OpenSettings()
  elseif command == "help" or command == "?" then
    ns.Print("Type /ssc for the settings, /ssc intro to see the welcome line again, or /ssc help for this list.")
  elseif command == "intro" then
    ns.ReplayIntro()
  else
    ns.Print("Unknown command. Type /ssc help for the list.")
  end
end

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the
-- menu row.
SocialShortcuts_CompartmentClick = ns.OpenSettings

function SocialShortcuts_CompartmentEnter(_, menuButton)
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip_SetTitle(GameTooltip, ns.title)
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      GameTooltip_AddColoredDoubleLine(GameTooltip, ns.modifierLabel[token] .. "-click", action.label,
        HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    end
  end
  GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
  GameTooltip:Show()
end

function SocialShortcuts_CompartmentLeave()
  GameTooltip:Hide()
end
