# SocialShortcuts

Hold a modifier, left-click any player name, and whisper, invite or add them as a friend.

## Features

**Three actions on a modifier-click.** Hold the modifier you assigned and left-click a player name, and instead of the default behaviour you get one of:

| Action | What happens |
| --- | --- |
| Whisper | Opens a whisper. From chat and the player lists it opens a dedicated whisper tab and brings that conversation's backlog with it; from a unit frame it fills the normal whisper box |
| Invite to group | Invites the clicked player. On Classic Era a full party gets the game's own offer to convert to a raid |
| Add friend | Adds the clicked player to your friends list |

**Works on every player name in the interface:**

- Chat — any clickable player name in the main chat windows
- Unit frames — target, focus, both targets-of-target, party frames and raid frames
- Friends list — WoW friends and Battle.net friends
- Who list — the Who tab of the Group Finder on Forever, of the Social window on Classic Era
- Group Finder — the leader of a listing
- Guild roster — the Communities member list on Forever, the Guild tab of the Social window on Classic Era

**Your own modifiers.** Every action is assigned in the in-game settings, and the modifier names match your platform: Mac users pick Command and Option, Windows users pick Windows and Alt.

**Battle.net aware.** A Battle.net friend gets a real BNet whisper, an invite to whatever character they are playing, and an add-friend that works when they are on your realm.

**Names the way the game writes them.** A click on a unit frame passes the name exactly as the game's own right-click menu would: `First Surname` on WoW Forever, `Name-Realm` for a cross-realm player on Classic Era. Chat and list clicks pass the same string the game's own menus pass for that row. A whisper tab is found again however a name is spelled (`First Surname`, `First-Surname`, `Name-Realm`), so a click never opens a second tab for someone you already talk to.

## Installation

Drop the `SocialShortcuts` folder into the AddOns folder of the client you play. The same folder works on both:

```
World of Warcraft/_classic_era_/Interface/AddOns/     # Classic Era
World of Warcraft/_classic_beta_/Interface/AddOns/    # WoW Forever
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

One folder runs on both clients. No libraries, no dependencies.

| Client | Interface | Lists it hooks |
| --- | --- | --- |
| Classic Era 1.15.x | `11509` | Friends, Who and Guild tabs of the Social window, Group Finder listings |
| WoW Forever 1.60.x | `16001` | Friends list, the Who tab of the Group Finder, the Communities guild roster, Group Finder listings |

## Restrictions

**Replaces the Chat Shortcuts WeakAura.** If that aura is still enabled the addon tells you at login, because both do the same job and every click would fire twice. Disable the aura and `/reload`.

**Off inside restricted content.** On WoW Forever, in dungeons, raids, boss encounters and PvP matches the game hides player names from addons and refuses them when an addon passes them on. Every shortcut does nothing there and the default click runs as usual. Chat lines and whisper tabs kept from such content stay hidden afterwards, so a whisper tab never copies those lines. Classic Era never applies these restrictions.

**Main chat windows only.** Names in the Communities chat window open their link without the event the addon listens for, so they keep the default click.

**Battle.net communities keep the default click.** Their member list shows Battle.net accounts, not characters, so there is no character name to whisper, invite or befriend. Guild and character communities work as usual.

**Add friend follows the game's friends setting.** Where WoW Forever has character friends switched off, Add friend says so instead of trying.

**Not yet run in game.** Every part of the game interface this addon touches was checked against Blizzard's published UI source for 1.60.1 and 1.15.9, but it has not been tested on a live character.
