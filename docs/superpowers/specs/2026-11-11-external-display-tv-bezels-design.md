# TVs around the picture on an external display: design

Date: 2026-11-11. Status: approved by the owner 2026-11-11. Follows the external display rework
(`e2dd429603`, `8e42ff5771`, `de98dcb798`).

## Why

On a cabled or AirPlay display Provenance now shows the game picture alone, or the device's skin
as a static image around it. A 4:3 game on a 16:9 TV leaves a third of the screen black. The
owner wants that space to be an old screen: a 70s console TV, a studio monitor, a home computer
monitor, with the glass reflecting the game and the game lighting the room. Manic, Delta and
RetroArch's iOS front end have nothing like it on a second screen.

## What the owner decided

- **Use what exists.** The bezel shaders already in the slang library, and The Bezel Project's
  RetroArch overlay packs, should both work. Logos and game art inside content a user brings in are
  the user's business, not the project's.
- **The Bezel Project is cleared.** The owner knows the maintainers and has their agreement. Their
  packs live in public GitHub repositories, so the GitHub API is the catalogue.
- **A fresh install offers a few built-in TVs**, before anything is imported.
- **Which TV shows is the user's choice, and for most systems that means one global setting.** A
  few systems have a screen people associate with them (C64 and Amiga monitors, PC and Mac
  screens). Those can be preferred for their systems, but any TV can be used with any system.
- **Skin format 2 may grow.** It is not published yet. It can gain Core Image filters, embedded
  shaders, and effects driven by the live picture (glow, reflection, ambient light) or by the
  device (camera, face detection, gyro). The emuskins site and its docs change with it.
- **Filters work with TVs.** A TV does not lock in a tube look. Any filter that has no bezel of
  its own, the built-in Metal filters included, applies to the screen area inside the TV, the way
  a Delta skin's screen filters apply inside the skin. (Owner, on reading the first draft, which
  had each TV own its look.)
- **How embedded shaders are permitted was left to the builder** (see "Calls made by the builder").

## Three pieces, built in this order

1. **TVs on the external display** from the bezel shaders the app already ships. This document
   specifies it in full.
2. **Bring your own bezel**: import a RetroArch overlay, and browse and download The Bezel
   Project's packs. Outlined below; gets its own short design before it is built.
3. **Format 2 live effects**: the skin format itself carries shaders and live inputs. Outlined
   below; spans SkinKit, the emuskins site and its TypeScript renderer, and gets its own design.

Piece 1 is deliberately shaped so that 2 and 3 add content to it, not replace it.

## What exists today (checked 2026-11-11)

- `GameExternalOutputView` (`PVUI/Sources/PVUIBase/ExternalDisplay/`) is a Metal-backed view on
  the external screen. `PVMetalViewController.presentOnExternalOutput` draws each frame into it
  through that screen's own `ShaderPostProcessor`, inside `pictureRect(aspect:drawableSize:)`,
  which is the game's aspect fitted into the view or into a skin's screen.
- The slang library (1.1.0) has `bezel/uborder`, 48 presets, 47 of which load. Its core,
  `uborder-bezel-reflections`, is **one pass** with two textures: `BORDER` (a 1920x1080 image of
  the room) and `LAYER2` (an image over it). It draws a tube frame from parameters (colour, inner,
  middle and outer widths, corner radius, glass curvature), reflects the picture on that frame,
  adds shine, and dims the room when "lights" are out. `uborder-koko-ambi` (five passes) also
  spills the picture's light onto the room. Base presets pair either with a tube shader (crt-geom,
  crt-aperture, crt-lottes, guest-advanced, newpixie and others).
- `preset_tools/append-uborder-bezel-reflections` is the same frame, glass and reflections as one
  pass with **no tube look in it**: it is meant to run after any other filter. The ambient form
  has no such bezel-only preset in the library: `uborder-koko-ambi` is four ambient passes plus a
  final pass with the crt-nobody tube look built in.
- Cost at 1920x1080 on an M2 Max, median GPU time per frame: 0.2 ms for the core, 0.3 to 0.9 ms
  with a tube shader, 0.5 to 1.3 ms for the ambient variants, 1.0 ms for the 12-pass
  guest-advanced variant. These are relative figures. Nothing has been timed on an iPad.
- These presets expect the **whole display** as their output and take the game's aspect as
  parameters (`fr_aspect_x`, `fr_aspect_y`, size `fr_zoom`). The app gives a filter the picture
  rect, so today a bezel preset chosen as a filter is squashed into 4:3 with a small picture.
- `ResolvedShader` carries a catalogue entry and a `[String: Float]` of parameter values, so a TV
  can supply its own values without touching the user's saved ones. A preset's textures come from
  `CompiledShaderContainer.getLUTByName`, so a wrapper container can substitute `BORDER`.
- A throwaway render showed that parameters alone make a convincing dark studio monitor and a
  beige computer monitor, and nothing else: the frame is one flat colour and a plain rounded
  rectangle. A wood console or a compact Mac needs drawn cabinet art.
- SkinKit implements format 2 (`SkinKit2Core`, `SkinKit2Render`): a `tv` device with a 1920x1080
  canvas, shapes, gradients, image fills, shadows, blur, blend modes and materials (gloss, brushed
  metal, plastic grain, CRT). `Skin2Renderer.image` turns a resolved document into a `CGImage`. It
  is static: no access to the live picture, no animation beyond pressed states.
- `ExternalDisplayOptionsView` holds the external display options and is shared by Settings and
  the pause menu.

## Piece 1: TVs on the external display

### What the player sees

In **External Display** options, under the mode picker, a new row **TV** opens a list: *None*,
then the built-in TVs. Picking one puts the game inside that TV on the external display: a tube
with curved glass, a frame that reflects the picture, a cabinet, and a room behind it that the
picture lights. The device's own screen does not change.

The **Screen Filter** row stays, and decides the tube look inside the glass. With a TV chosen its
first choice is **The TV's Own**, which is what a fresh choice of TV uses: each TV comes with a
look that suits it. Any other filter can be picked instead, from the built-in Metal filters or the
library, or *Off* for clean pixels behind glass. Filters from the Bezels group are left out of the
list while a TV is chosen, since they bring a frame of their own.

Below the list, a switch **Match the System's Screen** (on by default): when the game's system has
a preferred TV, that TV is used instead of the chosen one. With it off, the chosen TV is used for
every game.

### The starter set

Three TVs, with generic names and no maker marks:

| TV | Look | Its own tube look | Preferred for |
|---|---|---|---|
| Studio Monitor | dark grey metal box, thin frame, nearly flat glass, tally light | aperture grille, sharp | none |
| Living Room TV | wide wood console, rounded frame, strongly curved glass, speaker cloth either side, dials below | soft, visible scanlines, slight bloom | none |
| Computer Monitor | beige plastic, thick frame, mild curve, power light | fine dot mask, sharp | C64, Amiga, Atari ST, Atari 8-bit, MSX, ZX Spectrum, Apple II, DOS, Macintosh |

The owner's wider list (C64 and Amiga monitors as their own models, a compact Mac, an IBM screen,
a consumer Trinitron-style set, a JVC-style monitor) comes after this set, as more entries in the
same catalogue. When those exist, the Computer Monitor's preferred list shrinks to what is left.

### How a TV is made

A TV is data, not code:

- `id`, display name, and the systems it is preferred for (as `SystemIdentifier` values).
- The **glass and frame**: parameter values for the bezel-only uborder pass (frame colour and
  widths, corner radius, curvature, reflection strength, room dimming).
- Its **own tube look**: the id of an ordinary filter in the catalogue (a library preset or a
  built-in Metal filter) and parameter values for it. This is a default, not part of the TV.
- Whether it lights the room. A field, so a TV can be switched without code.
- **Artwork**: a format 2 skin document with a `tv` layout that draws the cabinet and the room. It
  has exactly one screen node, and that node is the tube: its rect is the only statement of where
  the tube is and what aspect it has (4:3 for all three). The catalogue does not repeat it.

The tube is **centred** on the canvas in the starter set. The shader has centre parameters for
its frame and its glass, but a test showed they use different units and drift apart, so an
off-centre tube waits until that mapping is worked out. The Living Room TV is the wide console
kind with the screen in the middle, so nothing is lost.

The catalogue is a JSON file plus one format 2 document per TV, bundled as text resources in
PVUI. No image files are committed. At first use on a display the artwork is rendered once with
`Skin2Renderer` at the display's pixel size and handed to the shader as its `BORDER` texture
through a container that wraps the preset's own. The shader then draws the glass, the reflective
frame, the reflections and the light on the room over and around it, every frame.

### Drawing

- The TV scene is always 16:9. With a TV chosen, the output rect is the scene fitted into the
  drawable: the whole drawable on a 16:9 display, letterboxed or pillarboxed with black on any
  other. The artwork is rendered at that rect's pixel size, a uniform scale of the 1920x1080
  canvas.
- The game's picture is fitted into the tube's aspect first (black bars inside the glass when the
  game is not 4:3, as on a real set), and that fitted picture is what the shader receives. The
  shader's own aspect parameters are therefore always the **tube's** aspect, never the game's.
- The artwork renders off the main thread. Until it and the preset are ready the display shows
  the picture alone, as the slang renderer already does while a preset compiles; the frame is
  redrawn when they are ready, so a paused game picks the TV up too.
- Two stages. First the screen filter draws the game into a texture the size of the tube in
  pixels, so scanlines and masks are laid out for the pixels they will occupy. Then the bezel-only
  pass takes that texture as its picture and draws the glass, frame, reflections and room around
  it. With the filter *Off* the first stage is a plain scaled copy.
- Which filter: the external display's own selection if the user made one, else the TV's own look.
  A selection that resolves to a Bezels-group filter is treated as *Off*. The TV's glass and frame
  values, and its own look's values, are passed as `ResolvedShader`s built from the catalogue, so
  they never mix with values the user saved for the same presets in the filter browser. A filter
  the user picked uses the user's saved values as it does everywhere else.
- **Room light with any filter is the open technical point.** Reflections are certain, because the
  bezel-only pass exists. Light on the room needs the ambient passes to run on the filtered
  picture and feed the final pass, and the library has that only fused with a tube look. The
  builder tries, in order: the fused preset with its built-in look turned down to neutral by
  parameters; one new bezel-plus-ambient preset added to the shader library (a release of
  `JoeMatt/slang-shaders-metal` and a lock bump); and failing both, room light only while the
  filter is *The TV's Own* or *Off*, with the switch's footer saying so.
- **No double curvature.** The glass is the only thing that bends the picture. A filter that has
  a curvature switch among its parameters has it forced off while it runs inside a TV (a short
  table of known parameter names; the user's saved value is untouched and applies again outside a
  TV). The owner asked for this on approval: the options multiply, so the app sorts out the
  combinations and the player only ever picks a TV and a filter.
- Known limit, accepted: a fine mask can shimmer under strongly curved glass because the glass
  resamples the filtered picture. The TVs' own looks are tuned by eye to avoid it.
- While a TV is chosen the device's skin is not drawn around the picture on the external display
  (`externalDisplaySkin` applies only when the TV is *None*).
- If the preset is missing, excluded or fails to compile, the display shows the picture alone and
  the reason is logged once. Nothing else about the session changes.

### Where it does not apply

- Cores that present on their own surface (Dolphin, Azahar, native PPSSPP) are mirrored today and
  stay mirrored: no TV.
- Dual-screen layouts (DS, 3DS): no TV, the same rule as filters.
- tvOS has no external display path; all of this is `#if os(iOS)` like the code it extends, and
  must leave the tvOS build compiling.

### Settings

- `externalDisplayBezel`: the chosen TV's id, or none. Global.
- `externalDisplayBezelMatchesSystem`: Bool, default true.
- `externalDisplayBezelLightsRoom`: Bool, default true. Shown as **Light the Room**. Off, the
  ambient passes do not run: reflections stay, the light on the room goes. It is both a taste
  setting and the way out if a display or device cannot hold frame rate.
- The screen filter is the existing `ShaderScope.screen(.external)` selection. Unset now means
  *The TV's Own* while a TV is chosen, and "same as the device" when the TV is *None*, as today.

Resolution for a game: with no TV chosen, none (matching replaces the chosen TV, it does not
switch TVs on). Otherwise, if matching is on and a TV lists the game's system as preferred, that
TV; otherwise the chosen TV. A stored id that no longer exists resolves to none.

### Tests

Unit tests, in PVUI's unit suite and PVSettings where the type lives:

- Selection: chosen TV, match on and off, a system with and without a preferred TV, an unknown
  stored id, two TVs claiming one system (catalogue order wins and the catalogue test rejects it).
- Layout: the tube rect on displays of several sizes and aspects; the picture rect inside the tube
  for 4:3, 16:9, 10:9 and 8:7 games.
- Curvature: a filter with a known curvature switch has it off inside a TV and unchanged outside.
- Filter choice: unset gives the TV's own look; a user's pick wins, with the user's saved values;
  *Off* gives none; a Bezels-group pick counts as *Off*; with the TV *None* an unset selection
  still means "same as the device".
- Parameters: a TV's values override the preset's defaults and ignore the user's saved values; the
  shader's aspect parameters are the tube's aspect whatever the game's aspect is; Light the Room
  decides whether the ambient passes run.
- Catalogue: the bundled JSON decodes, every TV names presets that exist in the manifest and are
  not excluded, every artwork document validates, has a `tv` layout and exactly one screen node,
  and that screen is centred.

Rendering itself is checked by eye in the simulator with the debugger recipe that fakes a display
(memory note `external-display-rework-nov2026`), and on the owner's iPad with an HDMI adapter.

### Goals

- A player picks a TV and sees their game inside it on the external display, with reflections on
  the frame and light on the room, at full frame rate.
- Any filter without its own bezel works inside any TV.
- Three TVs that look different from each other at a glance and are recognisably of their kind.
- Adding a TV is adding data.

### Non-goals for piece 1

- Per-system and per-game TV choices beyond the preferred-system rule. Per-game arrives with The
  Bezel Project's per-game art in piece 2.
- Editing a TV's parameters in the app.
- TVs on the device's own screen, in extra windows, or on tvOS.
- Lights or animations driven by the game (power light, disk activity, warm-up, degauss). Piece 3.
- Thumbnails in the picker (a list of names is enough to start).

### Anti-goals

- A TV that costs frames. The target is the external display's own refresh rate, normally 60 Hz,
  with the device's picture unaffected. Nothing has been timed on an iPad, and a 4K display has
  four times the pixels of the Mac test, so the owner's hardware check decides: a TV that cannot
  hold frame rate with room light has its catalogue field turned off.
- A TV that crops or stretches the game. Black bars inside the glass are correct.
- Changing the device-side skin code, or any behaviour when the TV is *None*.

### Calls made by the builder (not the owner's words)

- The order of the three pieces, and three TVs as the starter set with these looks and names.
- Generic names with no maker marks for the built-in set. The owner is relaxed about marks in
  user content; the built-in set is the project's own, so it stays unmarked.
- Built-in artwork is format 2 documents, not images and not drawing code, so that piece 3 can
  fold the shader settings into the same file and so TVs can later be shared through emuskins.
- Each TV suggests a tube look, used until the user picks a filter for the external display.
- Bezels-group filters are left out while a TV is chosen.
- The order of fallbacks for room light with an arbitrary filter (under "Drawing").
- One switch for system matching, no per-system list.
- Room light is on by default, with a **Light the Room** switch.
- The starter TVs have a centred tube.
- On a display that is not 16:9 the whole scene is letterboxed, not stretched or re-laid out.
- PVShaders may gain what this needs (a way to substitute a preset's texture, a way to fit the
  picture before the shader, a TV entry point on the post processor), as long as every existing
  filter path behaves as before. Only the device-side skin code is off limits.

### Left to the builder

- The exact preset behind each TV, its parameter values and its artwork, judged by eye.
- Where the catalogue type lives (PVSettings for the selection logic so it is testable without
  UIKit; PVUI for artwork and rendering) and the names of the new types.
- How the artwork texture is cached and invalidated when the display changes size.
- How the picture is fitted into the tube before the shader (an intermediate texture or a change
  to the post processor).
- The wording of the options screen.

## Piece 2 (outline): bring your own bezel

- **Import**: a RetroArch overlay (PNG with a transparent screen area, plus its `.cfg`) becomes a
  TV in the same catalogue. The tube rect is read from the transparent area. The image is the
  shader's top layer, so imported art also gets reflections behind it where the art allows, or it
  is composited plainly over the picture when it does not.
- **The Bezel Project**: a browser over their GitHub repositories (one per system, with per-game
  overlays named after the ROM), downloaded on demand into the library, never bundled. Per-game
  art is matched to the game by name, which is where a per-game TV choice enters. The owner has
  the maintainers' agreement; the browser credits the project and links to it.
- Listing those packs in emuskins is a later option.

## Piece 3 (outline): format 2 live effects

- The format gains nodes that take the **live picture** as an input, so a skin can place the game
  inside its own artwork and run effects on it and around it.
- **Shaders in skins**: a skin may carry shaders only as compiled slang presets, the same
  container the app's runtime already loads, declared in the skin's `requires`. No scripting and
  no other shader source. The site compiles them. This lifts the 2.0 anti-goal "no shader source
  in downloaded content" on purpose and only this far. (Builder's call; the owner delegated it.)
- **Core Image** effects on screens and on live layers, Apple platforms only. This is also where a
  TV's own look can be a Core Image filter list, as a Delta skin's screen filters are, and where
  the device skin's screen filters start to apply on the external display.
- **Signals** a skin can bind to: average and edge colours of the picture, audio level, rumble,
  disk or save activity, device motion, and face position where the user allows the camera.
- **Time**: simple animation (warm-up, flicker, a light that pulses).
- A renderer that cannot run a live effect, such as the site's TypeScript renderer, draws the
  static tree, and a skin that cannot work without one says so in `requires`.
- The built-in TVs of piece 1 become ordinary format 2 skins once the format can express them.
