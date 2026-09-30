# SocialShortcuts — Memory

Updated 2026-09-30 after the Forever-only rework (2.0.0). The owner's decision is WoW Forever 1.60.x only: `main` holds the Forever version and `1.15.x-backup` keeps the only commit with Era code. Verified against Gethe `forever` @ `966519cf` (1.60.1.70124), only files the Forever client loads, and Ketho `forever` @ `4149af64` (1.60.1.70009). The installed client is 1.60.1.70009. Nothing has run in a client.

## Current state

Modifier-click a player name to whisper, invite or add as a friend. It works on chat names, unit frames, the friends and who lists, the guild roster (Communities) and a Group Finder leader. Modifiers are set in the Blizzard Settings panel (`/ssc`).

| Item | State |
|---|---|
| Version | 2.0.0, `## Interface: 16001`, `## Category: Social` |
| Author | `miyanko` |
| Git | `main` has the 2.0.0 commit on top of `694c59c`, committed locally, not pushed. `1.15.x-backup` = `origin/1.15.x-backup` = `694c59c`. No `LICENSE`: removed on purpose on 2026-09-25, from every branch and all history; one gets added later by hand |
| Layout | `Core/` (Config, Names, Actions, Hooks), `UI/Options.lua` (Settings panel and slash command). No libraries |
| Lua | 540 lines (589 before the rework) |

History:

- The addon was born Forever-only. `4005195` (1.0.0) through `f6e2a7c` are `## Interface: 16001`.
- `694c59c` is the only commit with Era code, and it never ran in a client. No 1.15 release ever existed; the 1.15 tool was the Chat Shortcuts WeakAura. `1.15.x-backup` points there.
- `694c59c` also added Forever fixes that 2.0.0 keeps: the Frame-row `HasScript` skip, the Battle.net-club skip, the CHATLINK fix, `UnitFullName` (because `GetUnitName` ignores its second argument on Forever, `Mainline/UnitFrame.lua:1092`), and the `IsLegacyFriendSystemEnabled` check.

Click surfaces on Forever, verified in the loaded source:

| Surface | Forever |
|---|---|
| Chat names | `ChatFrame.OnHyperlinkClick` through EventRegistry, which is taint-isolated (`CallbackRegistry.lua:198-213`), plus a `SetItemRef` post-hook |
| Unit frames | Target, Focus, both `totFrame`s (created in their `OnLoad`), `PartyFrame.PartyMemberFramePool`, `CompactUnitFrame_SetUpFrame`. Forbidden frames and `disableMouse` frames (nameplates, `Blizzard_NamePlates.xml:95`) are skipped |
| Friends list | `FriendsListFrame.ScrollBox` from `Blizzard_FriendsFrame/Camelot/FriendsFrame.xml`. The Mainline FriendsFrame is `[ExcludeLoadGameType camelot]`. Frame rows such as invites are skipped |
| Who list | `LFGWhoListFrame.ScrollBox`, `frame.index`. Rows register `RightButtonUp` only (`Blizzard_GroupFinder_VanillaStyle/Mainline/WhoList.xml:4`) and their initialiser replaces `OnClick` every pass (`WhoList.lua:216`), so the addon hooks `OnMouseUp` once per row and needs `LeftButton` plus `upInside` |
| Guild roster | Communities member list (`CommunitiesFrame.MemberList`, `OnClubMemberButtonClicked`, only caller passes the entry). Battle.net communities are skipped |
| Group Finder | Browse rows, which register both buttons (`Blizzard_LFGVanilla_Browse.xml:487`), via `LFGBrowseSearchEntry_OnClick` |
| Invite | `C_PartyInfo.InviteUnit`, which asks for confirmation when the party would convert to a raid (`PartyInfoDocumentation.lua:361`) |

Hook timing: every hook installs at file load. Scroll lists hook the rows they already hold (`ForEachFrame`) and then each initialised row. Only the WeakAura notice (SSC-9) waits for `PLAYER_LOGIN`, because the aura builds its host frame when WeakAuras runs it. Settings load through `EventUtil.ContinueOnAddOnLoaded`.

How names and restrictions are handled:

- Unit-frame actions pass Blizzard's own unit-menu name form: "First Surname", or "Name-Realm" when `RegionalUniqueNamesEnabled()` is false (`Mainline/UnitPopupUtils.lua:124-131`).
- `Core/Names.lua` matches names with space and hyphen treated as the same separator.
- Every action is skipped while `C_ChatInfo.InChatMessagingLockdown()` is true.
- Unit frames also check `C_Secrets.CanCompareUnitTokens(unit, "player")` and `C_Secrets.ShouldUnitComparisonBeSecret(unit, "player")` before `UnitIsUnit` (`RequiresComparableUnitTokens`, `SecretWhenUnitComparisonRestricted`), and `C_Secrets.ShouldUnitIdentityBeSecret(unit)` before `UnitNameUnmodified` (`SecretWhenUnitIdentityRestricted`).
- `ns.CanAccess` wraps `issecretvalue` in `pcall`.
- A Shift (CHATLINK) click doesn't wipe typed text.
- Saved modifier tokens not in `ns.modifierOrder` (or a non-table `SocialShortcutsDB`) fall back to the defaults at load.

## Audit 2026-09-30: status after 2.0.0

| ID | Severity | Status | What was done, or what stays open |
|---|---|---|---|
| SSC-1 | High | Done, needs in-game check | Who rows: `OnMouseUp` hooked once per row, `LeftButton` and `upInside` required. `rehookEveryInit` is gone |
| SSC-2 | High | Done, needs in-game check | `HookUnitFrame` returns on `frame:IsForbidden()` or `frame.disableMouse`. Whether the old hook errored stays UNVERIFIED |
| SSC-3 | High | Open, owner decision | Unchanged: the dedicated whisper tab and backlog copy stay for chat and list clicks. Only the `GeneralDockManager` existence probe was dropped |
| SSC-4 | Medium | Done | `## Interface: 16001` |
| SSC-5 | Medium | Done | Deleted `HookNumberedRows`, `OnGuildRowClick`, `HookEraLists`, the `FriendsFrameFriendsScrollFrame` probe, `WHOS_TO_DISPLAY`, `GUILDMEMBERS_TO_DISPLAY` and `whoIndex` |
| SSC-6 | Medium | Done | `C_PartyInfo.InviteUnit(name)` directly |
| SSC-7 | Medium | Done | Probes removed: `IsMacClient`, `C_ChatInfo`, `issecretvalue`, `UnitNameUnmodified or UnitName`, `Constants … or " "`, `GeneralDockManager`, `IsLegacyFriendSystemEnabled`, `TargetFrame`/`FocusFrame`/`PartyFrame`, `GetSelectedClubInfo`, `GetMemberInfo`, the `memberList` nil check. Kept `frame.GetUnit`: only `PartyMemberFrameMixin` defines it (`Mainline/PartyMemberFrame.lua:4`), so it picks the frame type, not the client |
| SSC-8 | Medium | Done, needs in-game check | `C_Secrets` guards as listed above. Whether their scope differs from the chat lockdown stays UNVERIFIED |
| SSC-9 | Low | Open, owner decision | Unchanged: the `SuperSocialWAHost` notice at login |
| SSC-10 | Low | Done | Era and "both clients" comments rewritten |
| SSC-11 | Low | Done | `## Category: Social` |
| SSC-12 | Low | Done | README is Forever-only |
| SSC-13 | Low | Done | Hooks at file load; lists hook existing rows through `ForEachFrame` (its callback gets `(frame, elementData)`, unlike the registered one, so the addon calls it itself instead of passing `iterateExisting`) |
| SSC-14 | Low | Done | `ns.ChatRestricted` inlined into `ns.PickAction`, `NameKey` local, ADDON_LOADED frame replaced by `EventUtil.ContinueOnAddOnLoaded` |
| SSC-15 | Low | Done | Unknown tokens reset to the default |
| SSC-16 | Low | Open, owner decision | No Addon Compartment entry added |
| SSC-17 | Medium | Done by the lead | `1.15.x-backup` at `694c59c`, local and on GitHub |

UNVERIFIED assumptions in 2.0.0 (engine behaviour the source can't show):

- A Button that registers only `RightButtonUp` still gets `OnMouseUp` for a left click, with `upInside` as the third argument. Blizzard reads `(button, upInside)` in plain `OnMouseUp` scripts (`Blizzard_Settings_Shared/Blizzard_SettingControls.lua:1118`).
- `IsForbidden()` is callable on a forbidden nameplate frame from addon code.
- `CanCompareUnitTokens` false makes `UnitIsUnit` raise rather than return; either way the addon skips.

Nothing to do:

- Chat-link capture, and the friends-list `buttonType`/`id` fields (`Camelot/FriendsFrame.lua:1688-1689`).
- Battle.net actions mirror Blizzard (`SendBNetTell`, `FriendsFrame_InviteOrRequestToJoin`).
- The Communities and Group Finder hooks.
- `HookScript` and `hooksecurefunc` post-hooks, with no protected calls.
- Lockdown gating before any name read.
- The Settings panel: native vertical layout, `RegisterAddOnSetting` dropdowns, `OpenToCategory(category:GetID())`. No custom fonts, textures or hand-built widgets. It follows the shared UI spec item 7.
- First load with empty SavedVariables.
- The `UI_Chat` icon.
- `LE_REALM_RELATION_SAME` and `Constants.CharacterNameSeparatorConsts` are engine enums (`bir-forever/LuaEnum.lua`), even though apicheck lists the first as missing.
- No libraries. `luac -p` passes.

## Blockers, issues, challenges

1. When chat lockdown is active on Forever is unknown. The shortcuts are off wherever it applies.
2. That the server accepts "First Surname" for invite and add-friend on Forever is inferred from Blizzard's own invite button, not proven.
3. Names in the Communities chat window keep the default click.
4. The whisper-tab design's taint exposure (SSC-3) is unproven either way.

## Next steps

1. Owner decisions: SSC-3 (whisper tab vs `SendTell`), SSC-9 (keep the WeakAura notice), SSC-16 (Addon Compartment entry).
2. Push `main` after review.
3. In game, run `/console scriptErrors 1` and `/console taintLog 1` first, then the checks below.

Offline check: `lua ssc_smoke.lua <addon dir>` in the audit scratchpad stubs the Forever globals, loads the toc files and exercises the fixes (28/28 on 2026-09-30). It is not part of the repo.

Forever checks:

- [ ] `/ssc` opens settings with three modifier dropdowns. Picking a taken modifier swaps them.
- [ ] Each action from a chat name: the whisper opens and a second click reuses it.
- [ ] Target, party and raid frames, the friends list (WoW and Battle.net), the guild roster, and a Group Finder leader.
- [ ] After `/who`, a modifier-left-click on a who row fires its action once; an unmodified click and a right click (menu) behave as before (SSC-1).
- [ ] After a `/reload` in a raid, raid frames take a modifier-click at once (SSC-13).
- [ ] With Shift bound, typed text survives a click.
- [ ] Invite and add friend from a unit frame land with "First Surname". This settles issue 2.
- [ ] The friends list with a pending invite throws no error. A Battle.net community member keeps the default click.
- [ ] Check `/dump C_ChatInfo.InChatMessagingLockdown(), C_Secrets.ShouldUnitIdentityBeSecret("target"), C_Secrets.CanCompareUnitTokens("target", "player")` in a dungeon. There, modifier-clicks do nothing and throw no error. After leaving, clicking a name on a line posted inside does nothing and throws no error (SSC-8).
- [ ] In a dungeon with enemy nameplates shown: no Lua error from the unit-frame hook (SSC-2).
- [ ] After a few whisper actions, `taintLog` shows no SocialShortcuts taint on chat frames (SSC-3).
