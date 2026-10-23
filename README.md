# Social Shortcuts

Hold a modifier key and left-click a player name to whisper, invite or add them as a friend.

## Features

- Three actions on a modifier-click: Whisper, Invite and Add Friend. Inviting into a full party offers to convert it to a raid.
- Works on player names in chat (main chat windows and the Communities chat), unit frames (target, focus, both targets of target, party and raid frames) and the social lists (friends, the Who tab, Group Finder listing leaders and the guild roster).
- Battle.net friends in the friends list get a Battle.net whisper and an invite to the character they are playing. Add Friend does nothing on them, since they are already your friend.

## Installation

1. Install it with the CurseForge app under WoW Forever, or copy the `SocialShortcuts` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
2. Restart the game or type `/reload`.
3. Enable Social Shortcuts in the AddOns list.

## Usage

1. Hold the key bound to an action. The first load prints your keys once.
2. Left-click a player name.
3. Change the keys with `/ssc` or Social Shortcuts in the addon menu at the minimap.

## Commands

| Command | Does |
| --- | --- |
| `/socialshortcuts` | Opens the settings |
| `/ssc` | Short form of `/socialshortcuts` |

## Settings

Options, AddOns, Social Shortcuts has one dropdown per action. Each lists None and every modifier the game can detect, named for your platform:

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
| Invite | Command | Alt |
| Add Friend | Option | Shift |

Exactly one modifier must be held, so one key combination never fires two actions. Picking a modifier another action already uses swaps the two. Settings are saved per account.

## Requirements

WoW Forever 1.60.x (Interface `16001`). No other addons needed.

## Restrictions

The shortcuts are off inside restricted content. In dungeons, raids, boss encounters and PvP matches the game hides player names from addons, so the default click runs. Chat lines kept from such content and unit frames whose identity the game hides keep the default click too.

In chat, the game's own click still runs. It opens a whisper on every left-click of a chat name, so Invite and Add Friend from chat leave that whisper box open. Press Escape to close it.

Shift keeps its game meaning, and Add Friend uses it on Windows by default. Shift-click on a chat name inserts the name into the text you're typing, or runs a /who. That still happens and the action fires as well.

Battle.net communities keep the default click, because their member list shows accounts, not characters.

Add Friend follows the game's friends setting. Where character friends are switched off, it says so instead of trying.

## License

MIT. See [LICENSE](LICENSE).
