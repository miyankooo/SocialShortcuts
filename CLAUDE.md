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
- Hook Blizzard code only with `HookScript`, `hooksecurefunc` and ScrollBox callbacks owned by `ns`. No protected calls. Hooks install at file load, through `EventUtil.ContinueOnAddOnLoaded` for Blizzard addons, never at login.
- Chat names go through one `SetItemRef` post-hook that reads `player:` and `playerCommunity:` links.
- Compact unit frames are hooked only when set up with `DefaultCompactUnitFrameSetup`, so nameplates and pet frames are never touched.
- Battle.net friend rows take Whisper and Invite only.
- Settings are an own canvas page through `Settings.RegisterCanvasLayoutCategory`: three `WowStyle1DropdownTemplate` dropdowns over `ns.db` and a Defaults button, placed with the header and row metrics of Blizzard's settings list. Never Blizzard's list dropdowns: picking in one taints Blizzard's own settings until /reload on build 70532, and nameplates then raise secret-value errors (tested 2026-10-21). Own-frame dropdowns stay clean. Blizzard fonts, atlases and templates only. Opening the page in combat waits for `PLAYER_REGEN_ENABLED`.
- Taking a modifier another action uses swaps the two, in `ns.AssignModifier`.
- Action labels are Blizzard's unit menu strings (`WHISPER`, `PARTY_INVITE`, `ADD_FRIEND`) and the opt-out is `NONE`. Title Case for labels, sentence case for tooltips and chat.
- Windows defaults are Ctrl, Alt and Shift. Never default to the Windows key.
- The only chat line outside errors is the first-run hint, printed once per account when `SocialShortcutsDB` is new.
- `ns.title` reads the toc Title. It names the settings category, the compartment tooltip and the chat prefix, so the name is never a literal.
- Chat lines go through `ns.Print` with the shared yellow `[<Title>]:` prefix from `YELLOW_FONT_COLOR`. No literal `|cff` codes.
- Left out on purpose: a notice about the Chat Shortcuts WeakAura.
- The toc version stays 1.0.0 until the first CurseForge release.
- Licence: MIT (LICENSE).

## Checks

- Run `luac -p` on every Lua file and `lua Tests/Assign.lua` after a change. The check covers the modifier swap only.
- Turn on `/console scriptErrors 1` and `/console taintLog 1` before testing in game.
