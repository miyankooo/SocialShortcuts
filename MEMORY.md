# SocialShortcuts — Memory

Updated 2026-09-25 after the dual-client port (decision: every addon in the folder supports both clients). Verified against Gethe `forever` @ `bd2470a` (1.60.1.70009), Gethe `classic_era` @ `33e177d` (1.15.9.69722) and the matching Ketho dumps. Nothing has run in a client.

## Current state

Modifier-click a player name to whisper, invite or add as a friend. It works on chat names, unit frames, the friends and who lists, the guild roster and a Group Finder leader. Modifiers are set in the Blizzard Settings panel (`/ssc`), which is native on both clients.

| Item | State |
|---|---|
| Version | 1.0.0, both clients from one toc, `## Interface: 11509, 16001` |
| Author | `miyanko` |
| Git | Committed and pushed on 2026-09-25: `main` = `origin/main`. No `LICENSE`: removed on purpose on 2026-09-25, from every branch and all history; one gets added later by hand |

Click surfaces, each verified in its client's source:

| Surface | 1.15.9 | 1.60.1 |
|---|---|---|
| Chat names | `ChatFrame.OnHyperlinkClick` + `SetItemRef` hook | same |
| Unit frames | Target, Focus, party pool, `CompactUnitFrame_SetUpFrame` | same |
| Friends list | `FriendsFrameFriendsScrollFrame.buttons` (fixed rows) | `FriendsListFrame.ScrollBox`. Frame rows such as invites are skipped |
| Who list | `WhoFrameButton1..17`, `whoIndex` | `LFGWhoListFrame.ScrollBox`, `index`, rehooked each init |
| Guild roster | `GuildFrameButtonN` / `GuildFrameGuildStatusButtonN` | Communities member list. Battle.net communities are skipped |
| Invite | `InviteToGroup` (`Vanilla/UIParent.lua:1387`) | `C_PartyInfo.InviteUnit` |

How names and restrictions are handled:

- The client probe is `FriendsFrameFriendsScrollFrame`, which exists only on Era.
- Unit-frame actions pass Blizzard's own unit-menu name form: "Name" or "Name-Realm" on Era, "First Surname" on Forever. `GetUnitName(unit, true)` isn't used, because it ignores the flag on Forever.
- `Core/Names.lua` matches names with space and hyphen treated as the same separator.
- Every action is skipped while `C_ChatInfo.InChatMessagingLockdown()` is true.
- `ns.CanAccess` wraps `canaccessvalue` in `pcall`.
- A Shift (CHATLINK) click no longer wipes typed text.

## Blockers, issues, challenges

1. When chat lockdown is active on Forever is unknown. The shortcuts are off wherever it applies.
2. That the server accepts "First Surname" for invite and add-friend on Forever is inferred from Blizzard's own invite button, not proven.
3. Names in the Communities chat window keep the default click.
4. There's no `_classic_era_` install. The installed beta is 69913, the source is 70009.

## Next steps

1. Run `/console scriptErrors 1` first.

Both clients:

- [ ] `/ssc` opens settings with three modifier dropdowns. Picking a taken modifier swaps them.
- [ ] Each action from a chat name: the whisper opens a tab with the backlog, and a second click reuses it.
- [ ] Target, party and raid frames, the friends list (WoW and Battle.net), the who list after `/who`, the guild roster, and a Group Finder leader.
- [ ] With Shift bound, typed text survives a click.

Era:

- [ ] Both guild roster views work. Inviting into a full party shows the convert-to-raid popup.

Forever:

- [ ] Invite and add friend from a unit frame land with "First Surname". This settles issue 2.
- [ ] The friends list with a pending invite throws no error. A Battle.net community member keeps the default click.
- [ ] Check `/dump C_ChatInfo.InChatMessagingLockdown()` in a dungeon. There, modifier-clicks do nothing and throw no error. After leaving, clicking a name on a line posted inside does nothing and throws no error.
