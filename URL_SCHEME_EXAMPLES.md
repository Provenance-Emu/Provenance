# Provenance URL Scheme Examples

This document provides examples of how to use the Provenance URL scheme to open games using various methods.

## Basic URL Scheme Format

The basic format of the Provenance URL scheme is:

```
provenance://open?parameter=value
```

## Opening Games by MD5 Hash

To open a game by its MD5 hash:

```
provenance://open?md5=1a2b3c4d5e6f7g8h9i0j
```

Replace `1a2b3c4d5e6f7g8h9i0j` with the actual MD5 hash of the game.

## Opening Games by Name (Fuzzy Search)

To open a game by its name using fuzzy search:

```
provenance://open?title=Super%20Mario%20Bros
```

Provenance will search for games with names that match or contain "Super Mario Bros" and open the best match.

## Opening Games by Name and System (Fuzzy Search)

To open a game by both its name and system for more precise matching:

```
provenance://open?title=Super%20Mario%20Bros&system=NES
```

Provenance will search for games with names that match or contain "Super Mario Bros" on systems that match or contain "NES".

## URL Encoding

Remember to properly URL-encode any parameters that contain spaces or special characters. For example:
- "Super Mario Bros" becomes "Super%20Mario%20Bros"
- "Pokémon Red" becomes "Pok%C3%A9mon%20Red"

## Using the URL Scheme in Shortcuts

You can use these URLs in the Shortcuts app by adding a "Open URL" action with one of the URLs above.

## Using the URL Scheme in Other Apps

You can create links in other apps that open Provenance with specific games:

```html
<a href="provenance://open?title=Sonic%20the%20Hedgehog&system=Genesis">Play Sonic the Hedgehog</a>
```

## Using the URL Scheme from Terminal

You can test the URL scheme from Terminal using the `open` command:

```bash
open "provenance://open?title=Super%20Mario%20Bros&system=NES"
```

## Fallback Behavior

If a game cannot be found with the exact parameters provided:

1. When using both name and system, if no match is found, it will fall back to searching by name only.
2. When using fuzzy search by name, it will first try an exact match, then fall back to a contains match.
3. If no match is found at all, the URL scheme will return false and no game will be opened.

## Legacy Parameters

The following legacy parameters are also supported for backward compatibility:

```
provenance://open?PVGameMD5Key=1a2b3c4d5e6f7g8h9i0j
provenance://open?title=Super%20Mario%20Bros&system=com.provenance.nes
```

Where `system` in this case is the system identifier rather than the system name.
