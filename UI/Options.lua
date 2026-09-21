local _, ns = ...

local settingsByAction = {}
local categoryID

-- A swap assigns through the other setting, which fires its own change callback. This flag stops the two
-- from handing the modifier back and forth.
local resolvingConflict = false

-- Taking a modifier another action already uses swaps the two, because quietly unbinding the other action
-- would take away a shortcut the user never asked to give up.
local function ResolveConflict(actionKey, token, previous)
  if resolvingConflict or token == "NONE" then return end

  resolvingConflict = true
  for _, action in ipairs(ns.actions) do
    local other = settingsByAction[action.key]
    if action.key ~= actionKey and other and other:GetValue() == token then
      other:SetValue(previous)
    end
  end
  resolvingConflict = false
end

local function BuildModifierOptions()
  local container = Settings.CreateControlTextContainer()
  for _, token in ipairs(ns.modifierOrder) do
    container:Add(token, ns.modifierLabel[token])
  end
  return container:GetData()
end

local function AddActionDropdown(category, action)
  local variable = "SOCIAL_SHORTCUTS_" .. strupper(action.key)
  local setting = Settings.RegisterAddOnSetting(category, variable, action.key, ns.db,
    Settings.VarType.String, action.label, ns.defaults[action.key])

  -- The previous value has to be read before the swap, because the setting has already been written by
  -- the time the callback runs.
  local previous = setting:GetValue()
  setting:SetValueChangedCallback(function(_, value)
    local freed = previous
    previous = value
    ResolveConflict(action.key, value, freed)
  end)

  Settings.CreateDropdown(category, setting, BuildModifierOptions, action.help)
  settingsByAction[action.key] = setting
end

local function RegisterPanel()
  local category = Settings.RegisterVerticalLayoutCategory("Social Shortcuts")

  for _, action in ipairs(ns.actions) do
    AddActionDropdown(category, action)
  end

  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

EventUtil.ContinueOnPlayerLogin(RegisterPanel)

SLASH_SOCIALSHORTCUTS1, SLASH_SOCIALSHORTCUTS2 = "/socialshortcuts", "/ssc"
function SlashCmdList.SOCIALSHORTCUTS()
  if categoryID then
    Settings.OpenToCategory(categoryID)
  end
end
