local _, ns = ...

-- Blizzard's own invite, whisper and add-friend menu builds a unit's name from UnitNameUnmodified and joins
-- the second part with the surname separator (" ") while regionally unique names are on, and with "-"
-- across realms otherwise (Mainline/UnitPopupUtils.lua GetFullPlayerName). GetUnitName(unit, true) would
-- not do: it ignores its argument, reads UnitName and joins any second part with a space, so a realm would
-- come out as "Name Realm" wherever unique names are off.
local surnameSeparator = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

-- The unit's name in Blizzard's own form, or nil when the client hides it. Identity restrictions are a gate
-- apart from the chat lockdown, so they are asked before the name is read. An empty second part is
-- skipped, so a surname-less name never gains a trailing space.
function ns.UnitFullName(unit)
  if C_Secrets.ShouldUnitIdentityBeSecret(unit) then return nil end

  local name, second = UnitNameUnmodified(unit)
  if not ns.CanAccess(name) or not ns.CanAccess(second) then return nil end
  if not name or name == "" then return nil end
  if not second or second == "" then return name end
  if RegionalUniqueNamesEnabled() then return name .. surnameSeparator .. second end
  if UnitRealmRelationship(unit) ~= LE_REALM_RELATION_SAME then return name .. "-" .. second end
  return name
end
