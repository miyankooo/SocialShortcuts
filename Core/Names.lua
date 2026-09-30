local _, ns = ...

-- Player names reach this addon in several spellings. Blizzard joins a surname with " " in its own unit
-- names and a realm with "-", and the whisper box accepts " " or "-" (ChatFrameEditBox.lua
-- ExtractTellTarget). Comparing names through one key lets every spelling of a player find the same
-- whisper tab and backlog. SuperSocial's Core/Names.lua applies the same rule.

-- The lowercased first name, plus "-" and the lowercased second part when there is one. Space and hyphen
-- count as one separator, and a third part is dropped, so no spelling splits one player into two keys.
local function NameKey(name)
  if type(name) ~= "string" then return nil end

  local first, second = name:match("^%s*([^%s%-]+)[%s%-]*([^%s%-]*)")
  if not first then return nil end
  if second == "" then return strlower(first) end
  return strlower(first) .. "-" .. strlower(second)
end

-- A bare first name matches any second part, because some sources drop the surname or the home realm, and
-- a bare name cannot be told apart from its full form.
function ns.SameName(a, b)
  local keyA, keyB = NameKey(a), NameKey(b)
  if not keyA or not keyB then return false end
  if keyA == keyB then return true end
  if keyA:find("-", 1, true) and keyB:find("-", 1, true) then return false end
  return keyA:match("^[^%-]+") == keyB:match("^[^%-]+")
end

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
