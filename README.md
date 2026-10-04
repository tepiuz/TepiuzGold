# Tepiuz Gold

Tepiuz Gold remembers your characters' money and shows their balances and a total in World of Warcraft: Forever. It extends Blizzard's existing backpack tooltip using the default UI's race and currency icons.

## Requirements

- World of Warcraft: Forever
- Interface 16001 (game version 1.60.1)

## Installation

To install a release zip yourself, exit the game and extract it so the addon folder sits here:

```text
World of Warcraft/_classic_beta_/Interface/AddOns/TepiuzGold/TepiuzGold.toc
```

The folder name has to be `TepiuzGold`. Start the game and enable Tepiuz Gold on the AddOns screen. Restart the client after first installation.

## How it works

Hover the default backpack button to see a race icon and full character name (including surname) beside Blizzard's gold, silver and copper icons. Your current character appears first with its name highlighted in Blizzard gold; the others are sorted by name.

Each character must be logged into at least once with Tepiuz Gold enabled before the addon can know its money. Other characters show their last recorded balance.

Entries saved by earlier versions with only a first name are upgraded on that character's next login. Race icons are also learned on login; characters with no recorded or available icon still show their names and balances.

Balances and race icons are stored account-wide in `TepiuzGoldDB`, keyed by realm and character name, with a schema version and update timestamps. Money is captured on entering the world, on `PLAYER_MONEY`, and before displaying the breakdown. Logout attempts a final update while player data is available; after leaving the world, the last valid balance is retained. There is no polling or dependency.

The backpack, currency and race-icon helpers, Settings controls and confirmation dialog were checked against the [Blizzard UI source for Forever build 70009](https://github.com/Gethe/wow-ui-source/tree/bd2470aed543f72697a044e989285b6c83e63f73).

## Options

Open **Settings → AddOns → Tepiuz Gold** to manage recorded characters, for example after renaming or deleting one:

| Option | Effect |
| --- | --- |
| Character | Choose a recorded character from the dropdown. The current character is marked as current. |
| Delete selected | Remove only the selected character's stored balance. The current character cannot be deleted while it is being tracked. |
| Clear storage | Forget all recorded characters. Your current character is recorded again immediately. |

Both actions ask for confirmation. Removed characters return when you log into them again.

## License

[MIT](LICENSE)
