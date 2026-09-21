# SocialShortcuts

Modifier-click any player name to whisper, invite or add friend, for **WoW Forever 1.60.x** (Interface `16001`).

Four Lua files, no libraries. Every action is bound to a modifier you choose in the in-game settings.

## What it does

Hold a modifier and left-click a player name anywhere in the interface, and instead of the default behaviour you get one of three actions:

| Action | What happens |
| --- | --- |
| **Whisper** | Opens a whisper. From chat and the player lists it opens a dedicated whisper tab and copies that conversation's backlog into it; from a unit frame it fills the normal whisper box |
| **Invite to group** | `C_PartyInfo.InviteUnit` on the clicked player |
| **Add friend** | `C_FriendList.AddFriend` on the clicked player |

### Where it works

- **Chat** — any `player:` name link
- **Unit frames** — target, focus, both targets-of-target, party frames, raid frames and raid-style party frames
- **Friends list** — WoW friends and Battle.net friends
- **Who list** — the Who tab of the Group Finder
- **Group Finder browse** — the listing's leader
- **Guild roster** — the Communities member list, which is the guild roster on this client

Battle.net friends route through the account APIs: whisper sends a BNet tell, invite uses the account's current game session, and add friend only works when that account is on a character of your realm.

## Install

Drop the `SocialShortcuts` folder into:

```
World of Warcraft/_classic_beta_/Interface/AddOns/
```

## Configuration

Open **Options → AddOns → Social Shortcuts**, or type `/socialshortcuts` (short form `/ssc`).

Each action gets a dropdown listing every modifier the client can detect, plus *Unbound*. The client exposes exactly four modifiers, and their names depend on your platform:

| Binding | macOS | Windows |
| --- | --- | --- |
| `SHIFT` | Shift | Shift |
| `CTRL` | Control | Ctrl |
| `ALT` | Option | Alt |
| `META` | Command | Windows |

The addon detects the platform with `IsMacClient()` and shows only the right names, so a Mac user picks *Command* and a Windows user picks *Windows* for the same physical binding.

**Defaults** match the WeakAura this addon replaces:

| Action | macOS | Windows |
| --- | --- | --- |
| Whisper | Control | Ctrl |
| Invite to group | Command | Alt |
| Add friend | Option | Windows |

Two rules keep the bindings unambiguous:

- **Exactly one modifier must be held.** Holding Ctrl and Shift together matches nothing, so one chord can never trigger two actions.
- **Assigning a modifier another action already uses swaps the two**, rather than silently unbinding the action you did not touch.

Settings are per account (`SocialShortcutsDB`).

## Notes

**Replaces the Chat Shortcuts WeakAura.** If that aura is still enabled the addon says so at login, because both install the same hooks and every click would fire twice. Disable the aura and `/reload`.

**Secret values.** Inside restricted content 1.60 hands player names to addons as secret values. The invite, friend and whisper APIs accept those directly, but comparing or lowercasing one throws, so the whisper-tab lookup is skipped for a secret name and a plain whisper is sent instead.

**Taint.** Actions triggered from a unit frame never open a chat window, because doing that from a secure click taints the chat frame system.

## Compatibility

Written against build `1.60.1.69913` and verified against the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source). Every API, frame, template and click path it hooks was confirmed present in that source, including the `camelot` game-type variants that replace the classic friends and guild frames. It has not yet been run in game.

## Licence

MIT
