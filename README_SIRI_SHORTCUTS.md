# Siri Shortcuts for Provenance

This document explains how to use Siri shortcuts with Provenance to quickly open your favorite games.

## Available Shortcuts

Provenance supports several ways to open games using Siri shortcuts:

### 1. Open Game by MD5

This shortcut allows you to open a specific game in Provenance by its MD5 hash.

### 2. Open Game by Name

This shortcut allows you to open a game by its name using fuzzy search. Provenance will find the closest match to the name you provide.

### 3. Open Game by Name and System

This shortcut allows you to specify both a game name and a system name for more precise matching. For example, "Super Mario Bros on NES" or "Sonic on Genesis".

## How to Create Shortcuts

### Creating a Basic Shortcut

1. Open the Shortcuts app on your iOS device
2. Tap the "+" button to create a new shortcut
3. Tap "Add Action"
4. Search for "Provenance" in the search bar
5. Select "Open game" from the list of actions
6. Choose which parameter to use:
   - MD5: Enter the exact MD5 hash of the game
   - Game Name: Enter the name of the game (fuzzy matching supported)
   - System Name: Enter the name of the system (optional, for more precise matching)
7. Tap "Next" and give your shortcut a name (e.g., "Open Super Mario Bros")
8. Optionally, add the shortcut to your home screen or set up a Siri phrase

### Examples of Siri Phrases

- "Hey Siri, open Super Mario Bros"
- "Hey Siri, play Sonic the Hedgehog on Genesis"
- "Hey Siri, start Pokémon Red on Game Boy"

## Finding Game Information

### How to Find a Game's MD5 Hash

You can find the MD5 hash of a game in Provenance by:

1. Open Provenance
2. Navigate to the game in your library
3. Long-press on the game and select "Info"
4. The MD5 hash will be displayed in the game information screen

### Game and System Names

For the fuzzy search features, you don't need to know the exact names. Provenance will try to find the best match based on what you provide. However, using names that are closer to the actual game and system names will yield better results.

## URL Scheme

Provenance also supports opening games via URL scheme:

```
provenance://open?md5=YOUR_GAME_MD5_HERE
```

Or using game name:

```
provenance://open?title=GAME_NAME_HERE
```

Or using both game name and system:

```
provenance://open?title=GAME_NAME_HERE&system=SYSTEM_NAME_HERE
```

You can use these URL schemes in other apps or shortcuts to open games in Provenance.

## Troubleshooting

If your Siri shortcut is not working:

1. Make sure Provenance is installed and has been opened at least once
2. Verify that the game is in your Provenance library
3. If using game name search, try using a more specific name or add the system name
4. If using MD5, verify that the hash is correct
5. Restart your device and try again

## Technical Details

The Siri shortcuts integration uses the Intents framework to handle requests to open games. When a shortcut is triggered, Provenance uses the following search strategy:

1. If an MD5 hash is provided, it looks for an exact match in the database
2. If a game name is provided, it first tries an exact match, then falls back to fuzzy matching
3. If both game name and system name are provided, it tries to find a game that matches both criteria

For developers: The implementation can be found in the following files:
- `PVIntentHandler.swift` - Handles the Siri intents with fuzzy search capabilities
- `PVAppDelegate+Intents.swift` - Registers the intent handler and processes intent responses
- `Intents.intentdefinition` - Defines the available intents and their parameters
