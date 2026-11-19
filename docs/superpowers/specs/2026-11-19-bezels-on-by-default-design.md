# TV bezels on by default, and a quick switcher in the pause menu

Date: 2026-11-19. Status: draft for owner approval (builder check folded in).

## Why

The TVs around the picture look great and almost nobody will find them: today one shows on
the device only when a hardware controller is connected and the player has gone looking for
the Bezels tile and picked one. The owner wants a TV around the game by default in
landscape, including touch play on the generated controls (which are only buttons, so they
can float over the TV's cabinet and room), and wants bezels quick to switch on, off and
between from the pause menu, with a real preview, all drivable from a controller.

## Goals

1. In landscape, a single-screen game on a CRT-era system shows inside a TV by default, on
   iPhone, iPad and Apple TV, with a controller or with the generated touch controls.
2. From the pause menu, one tile opens a switcher strip over the paused game. Stepping left
   and right shows the paused game in each TV at full size. Keep or cancel in one press.
3. Everything in the switcher works from a controller on iOS, the remote or a controller on
   tvOS, and by touch.
4. Nobody who picked a TV, or picked None, has it changed. A player who never picked
   anything gets Automatic; that is the point, and they cannot be told apart from one who
   looked at the list and left it alone.

## Non-goals

- Portrait. If a TV arrives that works upright with the buttons over it, it joins the same
  rules later; nothing here should make that harder.
- Handheld systems, DS and 3DS. No handheld artwork exists and a TV cannot frame two screens.
- Real skins (anything that is not the generated controls). They frame the picture themselves.
- Re-laying-out the generated buttons around the TV. They stay where they are today.
- New TV artwork, and any change to imported bezels or The Bezel Project beyond listing them.

## Anti-goals

- A black screen. On 2026-11-18 a GPU hang on an A12Z iPad Pro made iOS refuse every frame
  from the app until relaunch (see "GPU safety"). Putting every player on the TV path must
  not make that more likely.
- A switcher that saves as you browse. Stepping is a preview; only Keep writes anything.
- Hiding the game while choosing. Today's Bezels tile opens a full-screen cover; that is the
  thing being replaced.

## How it works today

- The choice is `Defaults[.externalDisplayBezel]` (a TV id; `""` means none, the default),
  per-game pins in `externalDisplayBezelByGame`, and `ExternalDisplayBezelRules.bezelID`
  (PVSettings) decides: pin, then game artwork, then (only with a TV chosen) a TV listing the
  system, then the chosen TV. The same choice drives the external display and the device.
- On the device, `PVEmulatorViewController.updateGameplayBezel()` resolves the TV and hands
  it to `PVMetalViewController.updateLocalBezel`, gated by `canShowGameplayBezels`
  (`ExternalDisplay/GameplayBezelOptionsView.swift`): single-screen layout, filters apply,
  the host GPU view draws the game, and on iOS a hardware controller is connected.
- The TV is a `GameExternalOutputView` added inside the GPU view at the GPU view's bounds.
  With the generated controls up, the GPU view is sized to the picture rect the overlay
  publishes (`PVEmulatorViewController+DeltaSkinScreen.swift:195`), so a TV there would be
  drawn inside that small rect, not behind the buttons.
- `updateGameplayBezel()` runs at core start, on controller connect and disconnect, on filter
  changes and from the Bezels sheet. It does not run on rotation, when the overlay mounts,
  or when the settings change from the Settings app during a game.
- The pause menu's Bezels tile (`bezelsTileID`) opens `GameplayBezelOptionsView` as a
  `.fullScreenCover`: nested lists, four or five steps to change a TV, no preview except for
  imported images.
- Loading a TV is slow and uncached: `TVBezelScene.make` parses the skin document, draws the
  cabinet with CoreGraphics at the display's pixel width and PNG-encodes it, every time the
  TV, size, room light or glass setting changes. The previous TV stays up until then.
- Built-in TVs: Living Room TV, Studio Monitor, Computer Monitor (which lists the computer
  systems in `preferredSystems`). Up to six shader-preset TVs (`TVBezelCatalog.shaderPresets`).
  Plus imported images and Bezel Project downloads (`TVBezelLibrary`).
- Picture size: the tube is 960x720 on the 1920x1080 scene. In a TV the picture is about two
  thirds of the screen height on a landscape phone and about half on a 4:3 iPad.

## Approaches considered for the switcher

- **A. Strip over the paused game (chosen by the owner).** The menu gives way to a slim strip;
  the paused game fills the screen in the selected TV. The preview is the real thing and a
  change is one press. Cost: each step loads a TV, so it needs a cache and must keep the old
  TV up until the new one draws.
- **B. Thumbnail grid.** The paused frame rendered small inside every TV at once. Shows every
  choice together, but the thumbnails are not the true look and it is one offscreen render
  per TV: the most GPU work, on the path that already hung.
- **C. Cycle from the tile.** Each press of the tile picks the next TV. Fastest to build, but
  the menu covers the game, so there is no preview.

The default itself has one sensible build (an "Automatic" value), so no alternatives are listed.

## Design

### 1. "Automatic" becomes the default choice

- New stored value `ExternalDisplayBezelRules.automaticBezelID = "auto"`.
  `externalDisplayBezel`'s default changes from `""` to `"auto"`. A player who never chose
  gets Automatic; a stored `""` (they chose None) and a stored TV id are untouched.
- `ExternalDisplayBezelRules.bezelID` gains two inputs: `systemSuitsTV: Bool` and
  `automaticDefault: String`. With `chosen == "auto"`, after pins and game artwork:
  - `systemSuitsTV == false` gives no TV;
  - otherwise a TV that lists the system (the player's own first, as today), else
    `automaticDefault`.
  An explicit TV keeps today's behaviour, `matchesSystem` included.
- `systemSuitsTV` is the system's screen type being CRT (`ScreenType.isCRT`). It comes from
  `PVScreenType` in `systems.plist` and is copied onto every core at launch, thin libretro
  cores included (`GameLaunchingViewController.swift:1422`). It separates Game Boy, GBA,
  Game Gear, Lynx and the like (LCD and dot-matrix) from consoles and computers. A system
  with no `PVScreenType` reads as unknown and gets no TV, which is the safe side; the first
  build step audits the plist so no CRT-era system is missing one. `modern` systems get no
  TV. The `PVPortable` flag is not used: it is wrong for Wii and "retroarch".
- The rule returns more than an id: the strip's Automatic label needs to know whether the
  answer was "this TV", "none, the system has its own screen" or "none, nothing fits".
- `automaticDefault` is `"living-room-tv"`. Computers get Computer Monitor through its
  existing `preferredSystems` list.
- A per-game pin gains nothing new: no pin already means "follow the default".
- **My call:** Automatic also applies to the external display in Game on External Display
  mode, because both screens share one choice and one rule. Say so if the TV there should
  stay opt-in.

### 2. Where a TV may show on the device

Replace `canShowGameplayBezels` with a pure rule in PVSettings (working name
`GameplayBezelPlacement`), so it is testable without a device. Inputs: platform is tvOS;
window is landscape; what supplies the controls (generated controls, a real or built-in skin,
or none because a controller hid them); a hardware controller is connected; the choice is
Automatic or explicit; and the existing layout conditions (single screen, filters apply, the
host GPU view draws the game, the Metal presenter presents the core's frames).

| Play | Landscape | Portrait |
|---|---|---|
| Apple TV | TV | n/a |
| Controller, on-screen controls hidden | TV | an explicitly chosen TV only, as today |
| Generated touch controls | TV | none |
| Real or built-in skin on screen | none | none |

The pause menu builds its tiles once, and the strip can be open across a rotation or a
controller connecting: both re-evaluate the rule when its inputs change, and the strip
closes (as Cancel) if a TV can no longer show. Turning "hide on-screen controls with a
controller" on or off mid-game is one of those inputs.

Automatic never produces a TV in portrait. Own-surface cores (Dolphin, Azahar, native
PPSSPP) and dual-screen layouts never get one, as today.

"Landscape" is the window's shape (`AdaptiveWindowShape` / `currentOrientation`), so an
unfolded phone and an iPad in a wide Stage Manager window count.

### 3. The picture under the generated controls

When a TV shows and the generated controls are up, the GPU view fills the emulator view
instead of taking the overlay's picture rect, so the cabinet and room sit behind the buttons
and the picture goes in the tube. The buttons do not move.

- While a TV shows, the emulator view's bounds win: frames the overlay publishes
  (`applyViewport` at `PVEmulatorViewController+DeltaSkinScreen.swift:195`,
  `overlayScreenFramesDidChange`) still lay out the buttons but no longer size the GPU view.
- The layout editor shows the game without a TV, so buttons are placed against the picture
  rect they were designed for. **My call.**
- The scaling mode does not apply inside a TV: the picture is aspect-fit in the tube, as it
  already is.
- Anything that maps a touch or pointer to game coordinates (virtual mouse, light gun,
  the controller touchpad pointer) must use the picture's rect inside the tube, not the
  overlay's published rect. `GameExternalOutputView` already knows that rect. The builder
  lists the callers first; any input path that cannot be made to follow the tube turns the
  TV off while it is in use rather than aiming wrong. **My call.** Touch-screen systems (DS,
  3DS) are already excluded.
- When the TV goes away (rotation to portrait, a skin is picked, the choice becomes None) the
  GPU view returns to the overlay's rect through the existing path.

### 4. Keeping the TV in step

`updateGameplayBezel()` must also run:

- after a rotation settles (`handleOrientationChange`, once `currentOrientation` is set);
- when the generated controls mount or unmount (`overlayScreenFramesDidChange`) and when a
  skin is applied or removed;
- when any bezel setting changes: the `Defaults.updates` observer in
  `PVEmulatorViewController+ExternalDisplay.swift` calls `updateOnScreenControlsVisibility()`
  and `updateExternalDisplay()` today and must call `updateGameplayBezel()` as well.

It already runs once more than the list above says: after a Bezel Project download finishes.

The only readers of the stored choice are the two rule calls
(`PVEmulatorViewController+ExternalDisplay.swift:44`, `GameplayBezelOptionsView.swift:32`) and
the pickers, so nothing else treats `""` as "off" or a non-empty value as "a TV is on".

### 5. The switcher strip

**Entry.** The pause menu's Bezels tile, shown whenever the placement rule could show a TV
for the game in its current state. Tapping it no longer opens the full-screen cover.

**Presentation.** The pause menu's panel hides and a strip appears along the bottom; the
paused game is fully visible behind it. It is part of the pause menu's own view (a mode of
`PauseTileMenuView`), not a sheet or cover, and it counts in `isCoveredByPresentation` so the
tile grid stops taking controller input.

```
┌──────────────────────────────────────────────────────────────┐
│               the paused game, in the selected TV            │
│                                                              │
│  ◀  Off · Automatic · [Living Room TV] · Studio Monitor · …  ▶ │
│  Keep    Cancel    This game only: Off    Room light: On    More… │
└──────────────────────────────────────────────────────────────┘
```

**Items, in order:** Off; Automatic (labelled with what it resolves to for this game, for
example "Automatic · Living Room TV", or "Automatic · none for this system"); the built-in
TVs; the shader-preset TVs; the player's listed imported and downloaded bezels; then More….

**Controls.**

| Action | iOS controller | tvOS | Touch |
|---|---|---|---|
| Previous / next TV | d-pad or stick left / right (repeats) | focus moves along the strip | tap an item, or swipe the strip |
| Jump to the next group | L1 / R1 | n/a | n/a |
| Keep | A | Select on the focused item | Keep |
| Cancel | B | Menu / Back (returns to the pause menu, does not close it) | Cancel |
| This game only (toggle) | Y | focusable button | button |
| Room light (toggle) | X | focusable button | button |
| More… | step onto it, then A | focusable button | button |

On iOS the strip reads the pause menu's existing `PauseMenuControllerInput` stream; inside
the strip X, Y, L1 and R1 take the meanings above instead of quick save, quick load and page
switching. On tvOS the focus engine drives it: the strip is a row of focusable items and
focusing one previews it. The button legend on screen names the real buttons, as the rest of
the pause menu does.

**Preview, Keep, Cancel.**

- Stepping sets a transient preview choice on the emulator view controller (TV id and room
  light). `updateGameplayBezel()` and `updateExternalDisplay()` use it ahead of the saved
  settings. Nothing is saved while browsing.
- Keep saves the choice: with "This game only" off, to `externalDisplayBezel`; with it on, to
  the game's pin in `externalDisplayBezelByGame` (Off pins none, Automatic removes the pin).
  Room light saves to `externalDisplayBezelLightsRoom`. The strip closes back to the pause menu.
- Cancel clears the preview; the saved look returns. Closing the pause menu any other way
  cancels.
- The strip opens on the TV that is showing now. "This game only" starts on when the game
  has a pin.
- An external display, when one shows the game, previews the same choice.

**More…** opens today's `GameplayBezelOptionsView` (import, The Bezel Project, the Game
Bezels switch), unchanged, as the place for managing the library.

**Speed.**

- Stepping is debounced (about 150 ms) so holding a direction does not queue a load per item.
- The old TV stays on screen until the new one can draw. Today the old one stays only until
  the new artwork is ready, then the picture drops to bare while the new shader compiles; in
  the switcher that flash must not happen. How (for example a second processor swapped in
  when ready) is the builder's choice.
- A small cache of built scenes (`TVBezelScene`, keyed as `GameExternalOutputView.bezelKey`
  is today) so returning to a TV is immediate: about six entries, emptied on a memory warning.
  It is app-wide, not per game: with TVs on by default every game start would otherwise pay
  the artwork render again, on Apple TV too.
- The item being loaded shows a small progress mark in the strip; its name is selected at once.

### 6. GPU safety

Default-on puts every player on the TV path, so this ships with it.

- **Room light by device.** `externalDisplayBezelLightsRoom` defaults to on today. It becomes
  "unset means by device": unset resolves to on for GPUs in Apple family 7 and later (A14,
  M1) and off below. A player who sets it gets what they set. A plain `Bool` key has no
  unset state, so the key becomes optional or gains a companion; the builder checks whether
  the key is in iCloud settings sync before changing its type. **My call**, on a hunch not a measurement: the room-light
  preset costs several times the plain one, and the only GPU hang seen so far was on an A12Z.
- **Watch the TV frames.** The two TV draw paths (`directRender`'s local TV branch and
  `presentOnExternalOutput`) commit without a completion handler today, so their failures are
  silent. They get one that logs the error.
- **Fail soft where possible.** A hang or timeout on a TV frame drops the TV on that screen
  for the rest of the game session and says so once ("The TV was turned off: this device
  could not draw it").
- **Fail honestly where not.** Once iOS reports access revoked (`MTLCommandBufferError`
  code 4), nothing in the app can draw again. Show one alert saying the picture cannot be
  restored until Provenance is reopened, instead of a silent black screen.
- **Open item, not part of this build:** which filter hung the GPU on 2026-11-18 is unknown.
  The fix already on develop (`21cbfe10d6`) stops the full-screen filter running while a TV
  loads; if that filter can hang the GPU by itself, default-on does not change that.

### 7. Settings

- A "Bezels" page in Settings on iOS and tvOS (tvOS has none today): the choice (Automatic,
  None, or a TV, through `TVBezelPickerView` with Automatic added), Light the Room, Game
  Bezels, The Bezel Project. One line under Automatic says what it does: a TV for consoles
  and computers in landscape, none for handhelds.
- External Display settings keep their TV row; it edits the same choice.

## Constraints

- iOS 17 and tvOS 17 minimum; code must compile for both, and for the macOS and visionOS
  package declarations with guards.
- `ShaderSelection.off`-style traps: the preview choice must be able to say "Off" distinctly
  from "no preview". Do not model it as an optional whose `nil` means Off.
- No Bezel Project artwork in the repo, the bundle or the tests.
- New pure rules live in PVSettings with `swift test` coverage; PVUI is built once per batch.

## Build order

Each step is shippable by itself.

1. Rules: Automatic, `systemSuitsTV`, the placement table, the new default. Full-bounds GPU
   view under the generated controls, touch mapping, the refresh hooks. After this step TVs
   are on by default.
2. The switcher strip: preview, Keep and Cancel, controller and focus handling, debounce,
   no-flash swap, scene cache. The Bezels tile points at it.
3. GPU safety (room light by device, watched frames, the two failure messages) and the
   Settings page. Step 3's safety items should land before a TestFlight that contains step 1.

## Tests

- PVSettings: `bezelID` with Automatic (CRT and LCD systems, a TV listing the system, pins,
  game artwork, stored None untouched); the placement table, every row and column; the
  switcher's pure model (building the item list, stepping and group jumps, what Keep writes
  for each scope and item, Cancel writing nothing); room light by device family.
- PVUI (`PVUIBaseTests`): the catalogue contains `living-room-tv`; the tile appears under the
  placement rule; the scene cache evicts and empties.
- By hand, before release: fifteen minutes of touch play in a TV on the oldest supported
  iPhone, watching frame pacing and heat; iPhone and iPad in the simulator for button and
  tube overlap in landscape; Apple TV focus in the strip; the A12Z iPad Pro through twenty game launches with
  Automatic and a filter selected, watching the device log for a GPU hang.

## Left to the builder

- Names of the new types and where the strip's view code lives.
- How the no-flash swap and the scene cache are built.
- The strip's exact look, following the pause menu's existing style.
- Where touch-to-game mapping reads the picture rect, and which callers need it.
- Whether the rotation hook sits at the end of `handleOrientationChange` or in the rotation
  animation's completion.

## Calls made without the owner (check these)

1. Automatic applies to the external display too.
2. Consoles and computers are told from handhelds by `screenType` being CRT.
3. A controller in portrait keeps showing an explicitly chosen TV, as today; Automatic does not.
4. Room light defaults off below Apple GPU family 7.
5. Inside the strip, X is Room light, Y is This game only, L1 and R1 jump between groups.
6. The failure messages in "GPU safety" and their wording.
7. The layout editor shows the game without a TV.
8. An input path that cannot follow the tube turns the TV off while it is in use.
9. On Apple TV, Menu in the strip cancels back to the pause menu.
10. No thermal or battery logic beyond room light by device; a by-hand heat check instead.
