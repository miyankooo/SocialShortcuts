# SocialShortcuts

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer, no API probes.
- `main` holds the Forever version. `1.15.x-backup` keeps the only commit with Era code and stays untouched.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`, in files the Forever client loads.

## Rules

- `ns.PickAction` returns nothing while `C_ChatInfo.InChatMessagingLockdown()` is true. Every click surface asks it before reading a name.
- Unit frames check `C_Secrets.CanCompareUnitTokens` and `C_Secrets.ShouldUnitComparisonBeSecret` before `UnitIsUnit`, and `C_Secrets.ShouldUnitIdentityBeSecret` before `UnitNameUnmodified`.
- Secret checks go through `ns.CanAccess`, which wraps `issecretvalue` in `pcall`.
- Build unit names with `ns.UnitFullName`, never `GetUnitName`, which ignores its second argument on Forever.
- Whispers go only through `ChatFrameUtil.SendTell` and `ChatFrameUtil.SendBNetTell`, the calls Blizzard's own buttons make. On a chat name, whisper acts only on the CHATLINK modifier, because Blizzard whispers on every other left click.
- The addon writes no chat state: no whisper tabs, backlog copies, edit box fields or `ACTIVE_CHAT_EDIT_BOX`. So it never closes Blizzard's whisper box.
- Hook Blizzard code only with `HookScript`, `hooksecurefunc` and `EventRegistry` callbacks. No protected calls. Hooks install at file load, through `EventUtil.ContinueOnAddOnLoaded` for Blizzard addons, never at login.
- Settings use the native vertical Settings layout with `Settings.RegisterAddOnSetting` dropdowns. No custom fonts, textures or hand-built widgets.
- Chat lines go through `ns.Print` with the shared yellow `[Social Shortcuts]:` prefix from `YELLOW_FONT_COLOR`. No literal `|cff` codes.
- Left out on purpose: a notice about the Chat Shortcuts WeakAura, and a `LICENSE` file, which gets added by hand.

## Checks

- Run `luac -p` on every Lua file after a change. The repo has no test harness.
- Turn on `/console scriptErrors 1` and `/console taintLog 1` before testing in game.
