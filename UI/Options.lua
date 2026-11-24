local _, ns = ...

local dropdowns = {}
local checkboxes = {}

-- Each option changes one action, so its row sits in that action's section.
local options = {
  whisper = {
    key = "whisperTab", label = "Whisper in New Tab",
    help = "Whisper on a name in chat opens a tab for that player and moves your whispers with them into it.",
  },
  invite = {
    key = "askToJoin", label = "Invite Asks to Join",
    help = "While you're not in a group, inviting a player who is already in one asks to join their group instead.",
  },
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
local ROW_HEIGHT, ROW_SPACING, LABEL_X, INTRO_Y = 26, 9, 37, -64
local categoryID

-- The dropdowns and the checkboxes share one left edge, CENTER -40 of the row.
local CONTROL_X = -40

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

-- One row under the one above it, as wide as the page, its label in GameFontNormal from x 37 to the row's
-- centre less 85. Its control starts at the row's CENTER -40.
local function AddRow(panel, above, label, fillTooltip)
  local row = CreateFrame("Frame", nil, panel)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -ROW_SPACING)
  row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -ROW_SPACING)
  row:EnableMouse(true)
  AttachTooltip(row, fillTooltip)
  local text = CreateText(row, GameFontNormal)
  text:SetPoint("LEFT", LABEL_X, 0)
  text:SetPoint("RIGHT", row, "CENTER", -85, 0)
  text:SetText(label)
  return row
end

-- One section per action, headed as Blizzard's settings list heads a group (SettingsListSectionHeaderTemplate,
-- Blizzard_SettingControls.xml:12-20): a 45 px slot, its title in GameFontHighlightLarge at 7, -16. The page's
-- own divider runs under the title, 8 below it as under the page title.
local function AddSection(panel, above, title)
  local inset = above == panel.intro and LABEL_X or 0
  local header = CreateFrame("Frame", nil, panel)
  header:SetHeight(45)
  header:SetPoint("TOPLEFT", above, "BOTTOMLEFT", -inset, 0)
  header:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", inset, 0)
  local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  text:SetJustifyH("LEFT")
  text:SetPoint("TOPLEFT", 7, -16)
  text:SetText(title)
  local divider = header:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOP", 0, -40)
  return header
end

local function RegisterPanel(panel)
  local category = Settings.RegisterCanvasLayoutCategory(panel, ns.title)
  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

-- The page is the addon's only visible surface, so its top says what the keys do before any row asks for
-- one. Where each action works is in its tooltip.
local INTRO = "Hold a key and left-click a player's name or frame to whisper, befriend or invite them. "
  .. "Plain clicks and Shift-click work as always."

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

local function AddKeyRow(panel, above, action)
  local fillTooltip = FillHelp(action)
  local row = AddRow(panel, above, "Key", fillTooltip)

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
  return row
end

-- The checkbox is the one Blizzard's settings list builds for a checkbox row (SettingsCheckboxControlMixin),
-- placed on the addon's own canvas for the same taint reason as the dropdowns. Its help is in the tooltip the
-- row and the checkbox share. Init wires the click to its own callback registry, the way the list control
-- listens to it.
local function AddOptionRow(panel, above, option)
  local fillTooltip = FillHelp(option)
  local row = AddRow(panel, above, option.label, fillTooltip)

  local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
  checkbox:SetPoint("LEFT", row, "CENTER", CONTROL_X, 0)
  checkbox:Init(ns.db[option.key], function() fillTooltip(SettingsTooltip) end)
  checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
    ns.db[option.key] = checked
  end, row)
  checkboxes[option.key] = checkbox
  return row
end

local function RestoreDefaults()
  for key, value in pairs(ns.defaults) do ns.db[key] = value end
  for key, checkbox in pairs(checkboxes) do checkbox:SetValue(ns.db[key]) end
  local note = ns.FreeCommandKey()
  if note then ns.Print(note) end
  RefreshDropdowns()
end

EventUtil.ContinueOnPlayerLogin(function()
  local panel = BuildPanel(INTRO, RestoreDefaults)
  local above = panel.intro
  for _, action in ipairs(ns.actions) do
    above = AddKeyRow(panel, AddSection(panel, above, action.label), action)
    local option = options[action.key]
    if option then above = AddOptionRow(panel, above, option) end
  end
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
  elseif command == "help" then
    ns.Print("Type /ssc for the settings, /ssc intro to see the welcome line again, or /ssc help for this list.")
  elseif command == "intro" then
    ns.ReplayIntro()
  else
    ns.Print("Unknown command. Type /ssc help for the list.")
  end
end

-- The Addon Compartment entry point named in the toc.
SocialShortcuts_CompartmentClick = ns.OpenSettings
