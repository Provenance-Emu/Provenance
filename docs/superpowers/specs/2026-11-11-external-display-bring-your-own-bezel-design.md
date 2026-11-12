# Bring your own bezel on the external display: design

Date: 2026-11-11. Status: approved by the owner 2026-11-11, with the recommendations as written. Piece 2 of
`2026-11-11-external-display-tv-bezels-design.md`; piece 1 (`ceb014c192`) is on develop.

## Why

Piece 1 put three built-in TVs around the picture on a cabled or AirPlay display. The owner also
wants what already exists to work: RetroArch overlay bezels people have, and The Bezel Project's
per-game artwork, whose maintainers have agreed to its use. A game then sits in art made for that
game, with nothing to set up.

## What the owner decided (before this document)

- Logos and game art in content a user brings in are the user's business.
- The Bezel Project is cleared. Its public GitHub repositories are the catalogue. Nothing of
  theirs is bundled. Listing the packs in emuskins is a later option.
- The UX stays simple: the app sorts out the combinations.
- Imported and downloaded TVs appear in the same TV picker as the built-in ones.

## What was checked (2026-11-11)

**The Bezel Project on GitHub.** `thebezelproject` is a user account with 155 public
repositories, all on `master`, none with a licence file. Two families, same file names, different
art: `bezelproject-<System>` (art themed on the game) and `bezelprojectSA-<System>` (art themed on
the system). Layout, the same in every repository looked at (SNES, NES, MegaDrive, PSX, GBA, GB,
MAME):

```
retroarch/overlay/<System-Name>.png + .cfg            the system's bezel
retroarch/overlay/GameBezels/<System>/<ROM name>.png + .cfg   one per game, No-Intro names
retroarch/overlay/ArcadeBezels/<romset>.png + .cfg    MAME only
retroarch/config/<core>/<ROM name>.cfg                RetroArch glue, 11 copies, not needed
```

- One request lists a system: `GET /repos/thebezelproject/<repo>/git/trees/HEAD:retroarch/overlay?recursive=1`
  (works without a token, never truncated in the five tried; 120 KB gzipped for SNES's 1,445
  games, 740 KB for MAME's 11,000). Without a token GitHub allows **60 API requests an hour per
  IP address**. Images come from `raw.githubusercontent.com`, which that limit does not count.
- A game's art is one 1920x1080 PNG, 100 to 400 KB. A whole system is large (SNES 356 MB).
- **The `.cfg` says nothing about where the screen is.** Every one is the same five lines: the
  image's name, `full_screen = true`, no buttons. Their installer sets no viewport either:
  RetroArch draws the picture full height behind the art. So the screen area has to be read from
  the image.

**The art.** In 20 overlays from 17 repositories the see-through area is one region, centred to
within 1% of the width, and nearly as tall as the image (1036 to 1080 of 1080 px). Its shape
follows the system: 1.335 for TV consoles (rounded corners, with a soft shadow ring of
half-transparent pixels, about 5% of the image), 1.50 GBA, 1.11 Game Boy, 0.79 Vectrex, 0.67 DS
(one hole for both screens). Everything outside the hole is opaque.

**How to composite it** (rendered both ways with the scratch tool from piece 1):

- Through the `uborder` preset, as its `BORDER` with `ub_border_top = 1` or as `LAYER2`, the
  result is the plain composite plus a glare on the glass. No reflections show, because the
  preset reflects the picture on its own frame and opaque art covers that frame. The art already
  paints a frame; there is no room for a second one.
- Room light on the art (`uborder-koko-ambi`) brightens the art slightly and brings that preset's
  built-in scanlines. Not worth five passes.
- Off centre, the preset needs `fr_center_x` and `bz_center_x`, and the same value moves the
  picture and the frame by different distances (the picture's unit is the tube's width, not the
  scene's). Bezel Project art would get by, being centred; arcade and cabinet overlays from
  elsewhere would not.

**So imported art is composited plainly**: the picture is drawn into the screen area and the image
is laid over it, the way a skin is already drawn around the picture on the external display
(`GameExternalOutputView`'s image view and screen frame). It works at any position and shape and
costs no GPU passes. The glass, reflections and room light stay a feature of the built-in TVs.

## What the player sees

In **External Display** options, "Around the Picture":

- **TV** opens a list in place of today's menu: *None*; **Built In** (the three TVs);
  **My Bezels** (imported and saved ones, swipe to delete, tap the info button to rename or set
  the system it belongs to); **Import a Bezel…**.
- **Game Bezels** (a switch, off by default): "Shows artwork made for the game you are playing,
  from The Bezel Project, downloaded the first time you play it." It is independent of the TV row:
  a game with art shows its art, any other game shows the chosen TV, or the picture alone when the
  TV is *None*.
- **The Bezel Project** opens the browser: the credit and a link to the project, a choice of
  style (*Game Art* or *System Art*, the two families), then systems, then a searchable list of
  that system's games. Tapping an entry downloads and previews it, with **Add to My Bezels**.
  A system's own bezel is the first entry of its list.

While a game runs (the pause menu's sheet), the section starts with **This Game**: what is showing
and why ("Game art from The Bezel Project", "Chosen for this game", "The system's screen", "Your
TV"). It opens the same list with *Automatic* on top; picking anything else pins it to this game,
and **Choose from The Bezel Project…** opens that system's list to fix a wrong or missing match by
hand.

*Match the System's Screen* and *Light the Room* stay as they are. Light the Room's footer says it
applies to the built-in TVs.

## Which TV shows for a game

First that applies:

1. The TV pinned to this game (which may be *None*).
2. With Game Bezels on: the game's own art, when the name matches.
3. With a TV chosen and Match the System's Screen on: a TV that lists the game's system. My Bezels
   come before the built-in ones.
4. The chosen TV, or the picture alone.

This changes one piece 1 rule: *None* no longer switches everything off, since Game Bezels can
show art with no TV chosen. A stored id that no longer exists still resolves to nothing, and a
pin whose TV is gone counts as no pin, so the order carries on from step 2. Cores that draw on
their own surface and two-screen systems (DS, 3DS) get no TV, as before.

- A bezel that belongs to a system (step 3) replaces the chosen TV for that system's games. That
  is what setting its system means, and the info screen says so.
- A TV of either kind wins over the device's skin drawn around the picture, as in piece 1.
  `ExternalDisplayPlan`'s `bezelChosen` input becomes "a TV or game art applies to this game and
  its files are on the device". When art lands or is deleted the catalogue posts a change and
  `updateExternalDisplay()` runs again, so the plan and both screens follow.
- A pin is a TV id. The catalogue resolves the id of any art on the device, listed in the picker
  or not, so art picked from the browser for one game needs no place in My Bezels.
- Pins are keyed by the game's MD5. A pin does not follow a game whose ROM is replaced in place
  (`GameRekey`); the game goes back to *Automatic*. Accepted.
- The options view takes the running game (MD5, system, ROM name) as an optional value: the pause
  sheet passes it, Settings does not, and **This Game** shows only with it.

## Import

- **Import a Bezel…** is a file picker for PNG files, `.cfg` files and folders. A PNG alone is
  enough. A PNG in the bezels folder (below) that the app has not seen is imported the same way, so
  Files and the web server work too.
- **The `.cfg`** (RetroArch overlay format: `key = value`, optional quotes, `#` comments) is read
  for: `overlay0_overlay`, the image it belongs to; `overlay0_name`, a display name;
  `overlay0_descs`, where more than zero means a touch-control overlay, which is refused with a
  message saying so; `overlays` above 1, where the first is used. `overlay0_full_screen` and
  `overlay0_rect` are parsed and ignored: the image is always fitted whole to the display.
- **The screen area** is read from the image's alpha. See-through means alpha under 50%. The
  largest connected see-through region is the screen; its rect is the span of rows and columns the
  region covers at least half as widely as its widest, so rounded corners, shadow rings and stray
  pixels do not move it. Refused, with a reason: no see-through region; one smaller than 10% of
  the image; one larger than 97% (nothing to show); a second region at least half the size of the
  first (two screens).
- **The picture** is fitted into that rect keeping its shape, black behind it. When the game's
  shape is within 4% of the rect's it is stretched to fill, so no sliver shows beside the art.
- The image is fitted whole into the display, black around it when the display is another shape,
  and decoded no larger than the display.
- The screen filter runs inside the screen area as it does with no TV: the display's own choice,
  or the same as the device. Imported art has no look of its own. A filter's own curvature stays
  on (there is no glass to double it). A filter from the Bezels group counts as *Off*, as inside a
  built-in TV.

## The Bezel Project

- **Which repository for which system** is a bundled JSON table: system identifier to an ordered
  list of repository suffixes (SNES: `SNES`, `SFC`; Genesis: `MegaDrive`; and so on). Systems
  Provenance does not have, and DS and 3DS, are left out. Matching walks a system's repositories
  in order and stops at the first that has the game. The style choice decides the family
  (`bezelproject-` or `bezelprojectSA-`) for both the browser and Game Bezels.
- **A game with no art of its own** shows the chosen TV (step 3 or 4 above), not The Bezel
  Project's bezel for its system. That bezel can be added to My Bezels from the browser, where it
  belongs to its system. (Approved by the owner.)
- **A system's list** is fetched with the one request above the first time it is needed, reduced
  to names and sizes, and kept in Caches for 30 days (pull to refresh). When GitHub answers that
  the limit is reached, the cached list keeps working and the browser says when it resets. No
  account and no token.
- **Matching a game** uses the ROM's file name without its extension, then the library title:
  1. the same name, ignoring case and accents;
  2. the same title with the most tags in common (`(USA)`, `(Rev 1)`), preferring the same
     region, then the entry with the fewest extra tags;
  3. the same title alone, after folding punctuation, `&`/`and` and a trailing article
     (`Addams Family, The`).
  Arcade sets match on the exact romset name only. There is no fuzzy matching: wrong art is worse
  than none. A game with no match is remembered until the list is refreshed.
- **Game Bezels at play time**: when a game starts on an external display the lookup runs in the
  background (list if needed, match, download). Until the art is there the chosen TV shows, and the
  display switches when it lands. Offline or limited, nothing is said and the next launch tries
  again.
- **What GitHub sees**: the device's address, which system lists were fetched and which images.
  The match is made on the device.
- **Credit**: "Artwork by The Bezel Project" with a link to `github.com/thebezelproject`, at the
  top of the browser and in the app's acknowledgements.

## Where it lives and how it is listed

Approved by the owner as recommended:

- **One `Bezels/` folder in the library**, beside `DeltaSkins/` under the documents root, so it is
  visible in Files and the web server, moves with the library, and is not part of iCloud sync yet:
  `Bezels/Imported/` for the user's own, `Bezels/The Bezel Project/<repository>/` for downloads.
  Each image has a small JSON beside it written by the app (name, screen rect, image size, system,
  source). Downloads stay until deleted, so they work offline.
- **The picker lists** *None*, **Built In**, **My Bezels**. Game art fetched by the Game Bezels
  switch is not listed (it would be hundreds of rows); it is managed in the browser, per system,
  with a count, a size and Delete. An entry lands in My Bezels only through **Add to My Bezels**.

## How it is built

- `TVBezel` gains a second kind of artwork: an image file with a screen rect, beside the format 2
  document. `TVBezelCatalog` becomes the bundled TVs plus the library's.
- `GameExternalOutputView` draws an image TV with the image view and screen frame the skin path
  uses; the two-stage shader path is untouched and still serves the built-in TVs.
- The pure parts (the `.cfg` parser, screen detection on an alpha buffer, name matching, the
  selection order, the list parser) sit beside `ExternalDisplayBezelRules` in PVSettings, where
  piece 1 put its rules, so they test on the host in seconds. Files, network and UI are in PVUIBase
  under `ExternalDisplay/`.
- Settings: `externalDisplayGameBezels` (Bool, false), `externalDisplayBezelProjectStyle`
  (game art or system art), `externalDisplayBezelByGame` (game MD5 to TV id). Not synced.
- All UI and drawing is `#if os(iOS)` like the code it extends; the pure parts compile everywhere.

## Tests

Unit tests, with images and lists made in code (no artwork in the repository):

- Screen detection: a rounded hole, a shadow ring, stray pixels, an off-centre hole, a hole
  touching the edges, no hole, a tiny hole, an almost empty image, two holes.
- `.cfg`: quotes and no quotes, comments, spacing, a touch-control overlay, several overlays, a
  missing image name, unknown keys.
- Matching: each tier, region preference, articles and punctuation, arcade names, no match, and
  that near-misses do not match.
- Selection: the four steps above in every combination, Game Bezels with the TV *None*, a pinned
  *None*, unknown ids.
- The list parser on a small hand-written GitHub response; the rate-limit answer; the system table
  decodes and names only real system identifiers.
- Picture fitting: inside 4:3, 3:2 and tall holes, and the 4% rule.

By eye in the simulator with the fake-display recipe: one imported overlay and one downloaded
Bezel Project bezel around a running game.

## Goals

- Drop in a RetroArch bezel PNG and see the game inside it on the external display.
- Turn on one switch and get the right art for each game, with no other setup.
- Browse The Bezel Project by system, with credit, without bundling or mirroring it.

## Non-goals

- Glass, reflections or room light on imported art.
- Reading RetroArch's own config files (`input_overlay`, custom viewports), zip packs, or
  touch-control overlays.
- Downloading a whole system at once, thumbnails in lists, iCloud sync of bezels, emuskins listing.
- Bezels on the device's own screen, in extra windows, on tvOS, or for two-screen systems.
- A per-system picker beyond "this bezel belongs to this system".

## Anti-goals

- Wrong art shown for a game because of a loose match.
- Any network request when Game Bezels is off and the browser is closed.
- Bezel Project artwork in the repository, the app bundle or a test fixture.
- A change to how the built-in TVs draw, or to anything when no TV and no game art applies.

## Calls made by the builder (not the owner's words)

- Imported art is composited plainly, never through the bezel shader (from the test above).
- Game Bezels is a switch separate from the TV row, off by default, and works with the TV *None*.
- A per-game pin, set from the pause menu; no per-system setting beyond a bezel's own system.
- Both Bezel Project families are offered as a style choice, game art first.
- See-through is alpha under 50%; the size limits for refusing an image; the 4% stretch rule.
- Three matching tiers and no fuzzy matching.
- Lists kept 30 days; no GitHub token; nothing said when a background lookup fails.
- The pure parts live in PVSettings.

## Left to the builder

- Type and file names, the JSON beside each image, the ids of imported and downloaded TVs.
- The system table's contents, checked against the repository list.
- How the catalogue notices new files in the folder.
- Size limits on downloaded and imported images, and the wording of every message.
