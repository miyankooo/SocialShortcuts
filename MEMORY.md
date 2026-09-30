# SocialShortcuts — Memory

Updated 2026-09-30 after the Forever-only rework (2.0.0) and the owner's round-2 decisions (native whispers, no WeakAura notice, colour objects). The owner's decision is WoW Forever 1.60.x only: `main` holds the Forever version and `1.15.x-backup` keeps the only commit with Era code. Verified against Gethe `forever` @ `966519cf` (1.60.1.70124), only files the Forever client loads, and Ketho `forever` @ `4149af64` (1.60.1.70009). The installed client is 1.60.1.70009. Nothing has run in a client.

## Current state

Modifier-click a player name to whisper, invite or add as a friend. It works on chat names, unit frames, the friends and who lists, the guild roster (Communities) and a Group Finder leader. Modifiers are set in the Blizzard Settings panel (`/ssc`).

| Item | State |
|---|---|
| Version | 2.0.0, `## Interface: 16001`, `## Category: Social`. Round 2 kept the version, because 2.0.0 has not shipped |
| Author | `miyanko` |
| Git | `main` has the 2.0.0 commit and the round-2 commit on top of `694c59c`, committed locally, not pushed. `1.15.x-backup` = `origin/1.15.x-backup` = `694c59c`. No `LICENSE`: removed on purpose on 2026-09-25, from every branch and all history; one gets added later by hand |
| Layout | `Core/` (Config, Names, Actions, Hooks), `UI/Options.lua` (Settings panel and slash command). No libraries |
| Lua | 446 lines (540 after 2.0.0, 589 before the rework) |

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

Hook timing: every hook installs at file load. Scroll lists hook the rows they already hold (`ForEachFrame`) and then each initialised row. Saved settings load through `EventUtil.ContinueOnAddOnLoaded`, and the Settings panel registers at `PLAYER_LOGIN`.

Whispers (SSC-3, owner decision: the most native, leanest path):

- Every whisper is Blizzard's own entry point. Characters use `ChatFrameUtil.SendTell(name, chatFrame)` (`Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:383`). Battle.net friends use `ChatFrameUtil.SendBNetTell(accountName)` (`:388`). These are the calls Blizzard's own buttons make: `FriendsFrameSendMessageButton_OnClick` (`Camelot/FriendsFrame.lua:1171-1180`), `UnitPopupWhisperButtonMixin:OnClick` (`UnitPopupSharedButtonMixins.lua:449-452`), the Group Finder leader whisper (`Blizzard_LFGVanilla_Browse.lua:966`). `Mainline/ChatFrameUtilOverrides.lua` doesn't override either.
- The addon writes no chat state itself: no temporary window, no backlog copy, no edit-box fields, no `ACTIVE_CHAT_EDIT_BOX`.
- Chat name, whisper on a modifier that isn't CHATLINK: the addon does nothing. Blizzard's `HandlePlayerLink` already calls `SendTell(name, contextData.frame)` on every left click that isn't CHATLINK (`Mainline/ItemRefHandlers.lua:44`).
- Chat name, whisper on the CHATLINK modifier (Shift by default): the default handler inserts the name into the open box or sends a /who (`ItemRefHandlers.lua:10-39`). The addon then calls `SendTell(name, chatFrame)` from the `SetItemRef` post-hook, after the default handler, so the name isn't typed into the new whisper. `SendTell` replaces the box text, like Blizzard's own Whisper button.
- Chat name, invite or add friend: Blizzard's default click has already opened a whisper box for that name, and it stays open. The 2.0.0 `CloseWhisperBox` closed it by writing `editBox.text`/`setText` and calling `DeactivateChat`, which clears `ACTIVE_CHAT_EDIT_BOX`. It is gone. Owner decision (2026-09-30): leave Blizzard's whisper box open after an invite or add friend from chat, so the addon never writes chat state.
- Remaining taint surface: `SendTell` and `SendBNetTell` run Blizzard code under the addon's taint. That code writes `ACTIVE_CHAT_EDIT_BOX`, `LAST_ACTIVE_CHAT_EDIT_BOX` and edit-box state (`ChatFrameUtil.ActivateChat`, `ChatFrameUtil.lua:516-527`). Every addon that opens a whisper has the same exposure, and 2.0.0 already had it on unit frames. The in-game `taintLog` check stays.

Chat output: `ns.Print` prefixes every line with `YELLOW_FONT_COLOR:WrapTextInColorCode("[Social Shortcuts]:") .. " "` (`ColorMixin:WrapTextInColorCode`, `Blizzard_SharedXMLBase/Color.lua:68`). No literal `|cff` codes are left.

How names and restrictions are handled:

- Unit-frame actions pass Blizzard's own unit-menu name form: "First Surname", or "Name-Realm" when `RegionalUniqueNamesEnabled()` is false (`Mainline/UnitPopupUtils.lua:124-131`).
- Every action is skipped while `C_ChatInfo.InChatMessagingLockdown()` is true.
- Unit frames also check `C_Secrets.CanCompareUnitTokens(unit, "player")` and `C_Secrets.ShouldUnitComparisonBeSecret(unit, "player")` before `UnitIsUnit` (`RequiresComparableUnitTokens`, `SecretWhenUnitComparisonRestricted`), and `C_Secrets.ShouldUnitIdentityBeSecret(unit)` before `UnitNameUnmodified` (`SecretWhenUnitIdentityRestricted`).
- `ns.CanAccess` wraps `issecretvalue` in `pcall`.
- A CHATLINK click (Shift by default) for invite or add friend leaves the typed text alone. The default handler still inserts the name, as it always does.
- Saved modifier tokens not in `ns.modifierOrder` (or a non-table `SocialShortcutsDB`) fall back to the defaults at load.

## Audit 2026-09-30: status after 2.0.0

| ID | Severity | Status | What was done, or what stays open |
|---|---|---|---|
| SSC-1 | High | Done, needs in-game check | Who rows: `OnMouseUp` hooked once per row, `LeftButton` and `upInside` required. `rehookEveryInit` is gone |
| SSC-2 | High | Done, needs in-game check | `HookUnitFrame` returns on `frame:IsForbidden()` or `frame.disableMouse`. Whether the old hook errored stays UNVERIFIED |
| SSC-3 | High | Done (owner round 2), needs in-game check | Whisper tab, backlog copy and `CloseWhisperBox` removed, along with `FindWhisperTab`, `CopyWhisperHistory`, `OpenWhisperTab`, `IsWhisperWith`, `NameKey` and `SameName`. Every whisper is `SendTell` or `SendBNetTell` (see Whispers) |
| SSC-4 | Medium | Done | `## Interface: 16001` |
| SSC-5 | Medium | Done | Deleted `HookNumberedRows`, `OnGuildRowClick`, `HookEraLists`, the `FriendsFrameFriendsScrollFrame` probe, `WHOS_TO_DISPLAY`, `GUILDMEMBERS_TO_DISPLAY` and `whoIndex` |
| SSC-6 | Medium | Done | `C_PartyInfo.InviteUnit(name)` directly |
| SSC-7 | Medium | Done | Probes removed: `IsMacClient`, `C_ChatInfo`, `issecretvalue`, `UnitNameUnmodified or UnitName`, `Constants … or " "`, `GeneralDockManager`, `IsLegacyFriendSystemEnabled`, `TargetFrame`/`FocusFrame`/`PartyFrame`, `GetSelectedClubInfo`, `GetMemberInfo`, the `memberList` nil check. Kept `frame.GetUnit`: only `PartyMemberFrameMixin` defines it (`Mainline/PartyMemberFrame.lua:4`), so it picks the frame type, not the client |
| SSC-8 | Medium | Done, needs in-game check | `C_Secrets` guards as listed above. Whether their scope differs from the chat lockdown stays UNVERIFIED |
| SSC-9 | Low | Done (owner round 2) | `WarnDuplicateAura`, its `PLAYER_LOGIN` wait and the README paragraph removed |
| SSC-10 | Low | Done | Era and "both clients" comments rewritten |
| SSC-11 | Low | Done | `## Category: Social` |
| SSC-12 | Low | Done | README is Forever-only |
| SSC-13 | Low | Done | Hooks at file load; lists hook existing rows through `ForEachFrame` (its callback gets `(frame, elementData)`, unlike the registered one, so the addon calls it itself instead of passing `iterateExisting`) |
| SSC-14 | Low | Done | `ns.ChatRestricted` inlined into `ns.PickAction`, `NameKey` local, ADDON_LOADED frame replaced by `EventUtil.ContinueOnAddOnLoaded` |
| SSC-15 | Low | Done | Unknown tokens reset to the default |
| SSC-16 | Low | Done (owner decision) | Addon Compartment entry opens the settings (`SocialShortcuts_CompartmentClick`/`Enter`/`Leave` in `UI/Options.lua`, named in the toc) |
| SSC-17 | Medium | Done by the lead | `1.15.x-backup` at `694c59c`, local and on GitHub |
| Colours | Low | Done (owner round 2) | Chat prefix from `YELLOW_FONT_COLOR`, as listed above |

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
4. `SendTell` runs under the addon's taint (see Whispers). Whether that ever blocks a protected chat action later is unproven.

## Next steps

1. No owner decisions open. Decided: the Addon Compartment entry (SSC-16) is added, and the whisper box Blizzard opens on a chat-name click stays open after an invite or add friend.
2. Push `main` after review.
3. In game, run `/console scriptErrors 1` and `/console taintLog 1` first, then the checks below.

Offline check: `lua ssc_smoke.lua <addon dir>` in the audit scratchpad stubs the Forever globals, loads the toc files and exercises the fixes. Any other global read raises, so a leftover chat global or `SuperSocialWAHost` fails it. It passed 28/28 after 2.0.0 and 39/39 after round 2. It is not part of the repo.

Forever checks:

- [ ] `/ssc` opens settings with three modifier dropdowns. Picking a taken modifier swaps them.
- [ ] Each action from a chat name. Whisper opens Blizzard's whisper box once, with no duplicate header or text. Invite and add friend land, and Blizzard's whisper box is open, which is expected.
- [ ] Target, party and raid frames, the friends list (WoW and Battle.net), the guild roster, and a Group Finder leader.
- [ ] After `/who`, a modifier-left-click on a who row fires its action once; an unmodified click and a right click (menu) behave as before (SSC-1).
- [ ] After a `/reload` in a raid, raid frames take a modifier-click at once (SSC-13).
- [ ] With Shift bound to invite or add friend, typed text survives a chat click. With Shift bound to whisper, a Shift-click on a chat name opens the whisper with no name typed into it.
- [ ] Invite and add friend from a unit frame land with "First Surname". This settles issue 2.
- [ ] The friends list with a pending invite throws no error. A Battle.net community member keeps the default click.
- [ ] Check `/dump C_ChatInfo.InChatMessagingLockdown(), C_Secrets.ShouldUnitIdentityBeSecret("target"), C_Secrets.CanCompareUnitTokens("target", "player")` in a dungeon. There, modifier-clicks do nothing and throw no error. After leaving, clicking a name on a line posted inside does nothing and throws no error (SSC-8).
- [ ] In a dungeon with enemy nameplates shown: no Lua error from the unit-frame hook (SSC-2).
- [ ] Whisper from a unit frame, a WoW and a Battle.net friend, a who row, a Group Finder leader and a Shift-bound chat name. Then send the whispers, reply with R, and open chat with Enter. `taintLog` blames SocialShortcuts for no blocked action (SSC-3).
