# SocialShortcuts

Hold a modifier, left-click any player name, and whisper, invite or add them as a friend.

## Features

**Three actions on a modifier-click.** Hold the modifier you assigned and left-click a player name, and instead of the default behaviour you get one of:

| Action | What happens |
| --- | --- |
| Whisper | Opens a whisper. From chat and the player lists it opens a dedicated whisper tab and brings that conversation's backlog with it; from a unit frame it fills the normal whisper box |
| Invite to group | Invites the clicked player |
| Add friend | Adds the clicked player to your friends list |

**Works on every player name in the interface:**

- Chat — any clickable player name
- Unit frames — target, focus, both targets-of-target, party frames and raid frames
- Friends list — WoW friends and Battle.net friends
- Who list — the Who tab of the Group Finder
- Group Finder — the leader of a listing
- Guild roster — the guild member list

**Your own modifiers.** Every action is assigned in the in-game settings, and the modifier names match your platform: Mac users pick Command and Option, Windows users pick Windows and Alt.

**Battle.net aware.** A Battle.net friend gets a real BNet whisper, an invite to whatever character they are playing, and an add-friend that works when they are on your realm.

## Installation

Drop the `SocialShortcuts` folder into:

```
World of Warcraft/_classic_beta_/Interface/AddOns/
```

## Settings

Open **Options → AddOns → Social Shortcuts**, or type `/socialshortcuts` (short form `/ssc`).

Each action has a dropdown listing every modifier the game can detect, plus *Unbound*. The names depend on your platform:

| macOS | Windows |
| --- | --- |
| Shift | Shift |
| Control | Ctrl |
| Option | Alt |
| Command | Windows |

Defaults:

| Action | macOS | Windows |
| --- | --- | --- |
| Whisper | Control | Ctrl |
| Invite to group | Command | Alt |
| Add friend | Option | Windows |

Two rules keep the bindings predictable:

- **Exactly one modifier must be held.** Holding Control and Shift together does nothing, so one key combination can never fire two actions.
- **Picking a modifier another action already uses swaps the two**, instead of quietly unbinding the action you did not touch.

Settings are saved per account.

## Requirements

WoW Forever 1.60.x (Interface `16001`). No libraries, no dependencies.

## Restrictions

**Replaces the Chat Shortcuts WeakAura.** If that aura is still enabled the addon tells you at login, because both do the same job and every click would fire twice. Disable the aura and `/reload`.

**Inside restricted content** the game hides player names from addons. Whispers still work, but they open in the normal whisper box rather than a dedicated tab.

**Not yet run in game.** Every part of the game interface this addon touches was checked against Blizzard's published 1.60.1 UI source, but it has not been tested on a live character.
