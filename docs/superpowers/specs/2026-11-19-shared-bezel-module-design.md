# Shared TV bezel module (Provenance, iCube, iFly)

Date: 2026-11-19. Follows `2026-11-19-bezels-on-by-default-design.md`.

## Goal

iCube and iFly get the feature Provenance has: a TV or monitor around the game picture by default in
landscape, and a strip in the pause menu that previews each TV over the paused game. The code is shared
through one Swift package instead of being copied twice.

## What each app has today

| | Provenance | iCube | iFly |
|---|---|---|---|
| Repo, default branch | Provenance-Emu/Provenance, `develop` | Provenance-Emu/iCube, `develop` | JoeMatt/iFly, `develop` |
| Project | Xcode workspace + Tuist dev workspace | Tuist (`Source/iOS/App/Project.swift`) | Tuist (`Project.swift`) |
| SkinKit | revision `ab9dbb0`, all products | revision `ab9dbb0`; Core, Manager, UI, SkinKit2Core, SkinKit2Render, iOS and Catalyst only | revision `ab9dbb0`; Core, Catalog, Manager, UI |
| Who presents frames | `PVMetalViewController` (has the frame as a texture) | Dolphin's Metal backend, into one `CAMetalLayer` owned by `EmulationCoordinator` | flycast's Metal renderer, into `MetalHostView`'s `CAMetalLayer` |
| Where the picture's rect is decided | UIKit frames (35 call sites) | the SwiftUI frame of the surface (`EmulationScreen.iosEmulationSurface`) | the SwiftUI frame of `MetalLayerView` (`EmulationView.emulationGeometry`) |
| Slang shader runtime | `PVSlangRuntime` + `PVShaders` (in the Provenance repo) | its own port: `DOLShaderPostProcessor` + `FilterChain`, run on the whole backbuffer | its own port: `DOLShaderPostProcessor` + `FilterChain`, through a post-process callback |
| Pause menu | SwiftUI tiles in a UIKit host; the game stays visible | SwiftUI `PauseMenuView` in a `fullScreenCover` (covers the game) | SwiftUI `PauseMenuView` in a sheet (iOS) or `fullScreenCover` (tvOS) |
| Menu input from a controller | `PauseMenuNavigationCommand` publisher | `ControllerFocusCoordinator`, `MenuControllerNav` | focus engine (`controllerUserInteractionEnabled`) |
| Settings | `Defaults` package | `UserDefaults`, `@AppStorage` | `UserDefaults` with `iFly.` keys |
| Game key | ROM MD5 | Dolphin game ID (no MD5 is computed) | flycast game ID (`GameSettingsManager.currentGameId`) |
| `SystemIdentifier` (PVSystems) | yes | no | yes |

All three apps pin the same SkinKit revision, and that revision already has the format 2 renderer the TV
artwork is drawn with.

## Decision

1. **The code goes into SkinKit**, as two new products beside the existing ones. No new repository.
   - `SkinKitBezels`: no UIKit or SwiftUI. Depends on `SkinKit2Core` and `SkinKit2Render` only.
   - `SkinKitBezelsUI`: SwiftUI views for iOS and tvOS. Depends on `SkinKitBezels` only.
2. **The package runs no shader.** It describes a built-in TV as data (`TVBezelScene`: a preset id, its
   parameter values, the cabinet as PNG data for the preset's `BORDER` texture, and the tube's rect). An
   app that has a slang runtime feeds that to its own filter chain. Provenance does this today through
   `PVShaders`.
3. **The package can show a TV with no shader at all.** `TVBezelLayout` places the artwork and the picture,
   `TVBezelPlainArtwork` draws the cabinet with a black tube, and `TVBezelArtworkView` / `TVBezelStage`
   (SwiftUI) show it. This is the path iCube and iFly start with: both size their game surface with a
   SwiftUI frame, so a TV is a picture frame plus an image behind it. It needs no change to either core's
   presenter and cannot hang the GPU.
4. **Settings are behind a protocol**, `BezelSettingsStore`. Provenance implements it over its existing
   `Defaults` keys (names and stored values unchanged). `UserDefaultsBezelSettings(prefix:)` ships for apps
   with nothing of their own.
5. **App specifics are injected**, once at launch, through `BezelEnvironment.current`: the bezels folder,
   the cache folder, the user agent, the settings store, the list of systems (id and name), and "does my
   shader library have this preset". Logs go to `BezelLog.handler`.

### What moved, and what stays in Provenance

Moved to `SkinKitBezels` (from `PVSettings`, `PVUIBase` and `PVShaders`), with their tests:

- Rules: `ExternalDisplayBezelRules`, `GameplayBezelPlacement`, `BezelSwitcherModel`.
- Image bezels: `BezelScreenDetector`, `BezelPictureFit`, `BezelNameMatcher`, `RetroArchOverlayConfig`,
  `TVBezelImage`, `TVBezelLibrary`.
- The Bezel Project: `BezelProjectStyle`, `BezelProjectRepository`, `BezelProjectListing`,
  `BezelProjectService`, `ExternalDisplayGameContext`, `ExternalDisplayGameArtwork`,
  `Resources/TVBezels/bezel-project.json`.
- Catalogue and artwork: `TVBezel`, `TVBezelCatalog`, `TVBezelArtwork`, `TVBezelScene`,
  `TVBezelSceneCache`, `TVBezelRoomLight`, `TVFrameFailure`, `catalog.json` and the three skin documents.
- The pure half of `TVBezelShader` (preset ids, tube geometry, neutral tube values).

New in `SkinKitBezels`: `BezelEnvironment`, `BezelLog`, `BezelSettingsStore`, `BezelPreview`,
`BezelChoice` (the resolve step each app would otherwise repeat), `TVBezelLayout`, `TVBezelPlainArtwork`.

Moved to `SkinKitBezelsUI`: `BezelSwitcherStrip`, `BezelSwitcherHost`, `TVBezelPickerView`,
`BezelProjectBrowserView`. The host talks to the game through `BezelSwitcherSession`
(game key, system, "can a TV show now", "is it loading", and the preview to show), and takes controller
input as a publisher of `BezelNavigationCommand`. New: `BezelSetting` (a property wrapper over the
settings store), `TVBezelArtworkView`, `TVBezelStage`.

Stays in Provenance:

- `GameExternalOutputView`, `PVMetalViewController` (`updateLocalBezel`, `drawBezel`, `watchTVFrame`),
  `PVEmulatorViewController+GameplayBezel`, the pause menu wiring, the settings pages
  (`BezelOptionsView`, `GameplayBezelOptionsView`, `ExternalDisplayOptionsView`), the `Defaults` keys.
- Everything in `PVShaders`. The three `TVBezelShader` functions that read a `ShaderCatalogEntry`
  (`curvatureOffValues`, `bendsPictureItself`, `isBezelFilter`) are now an extension in PVUIBase.
- New glue: `ProvenanceBezels` (PVUIBase) sets `BezelEnvironment.current`; `DefaultsBezelSettings` is the
  store; `TVBezelScene.resolvedShader` turns a scene into a `ResolvedShader` and `ShaderTextureOverrides`.

Identifiers that are stored on devices do not change: TV ids (`living-room-tv`, `slang:bezel/…`,
`file:…`), `auto`, `""`, the `Bezels/` folder layout and the `.bezel.json` files.

## The shader half: what was ruled out

**Moving the slang runtime and `ShaderPostProcessor` into a shared repo now.** Not done, for four reasons.

1. It would not give iCube or iFly a TV by itself. Each already has a ported `FilterChain` wired into its
   own core's present path; a second runtime in the same app would need a second hook, or a migration of
   the app's existing shader feature. That is a larger job than the bezel feature.
2. `PVShaders` depends on `PVSettings`, `PVPrimitives`, `PVLogging` and `Defaults`. Only `PVSlangRuntime`
   is free-standing; the catalogue, store and post processor are not.
3. The presets are not in any repo. Provenance fetches a 1,000-preset library at build time. Each app would
   need that pipeline, or the package would have to carry the two `uborder` presets, and
   `uborder-koko-ambi` contains GPL-3 passes.
4. The multi-pass TV is the heaviest thing drawn and the one thing that has hung a GPU. Giving two more
   apps that path on day one is the wrong order; the plain TV carries no such risk.

There are now three copies of the OpenEmu-derived filter chain (Provenance, iCube, iFly). Making them one
package is worth doing, as its own project. The interface here is ready for it: `TVBezelScene` is exactly
what a shared runtime would consume, so nothing in `SkinKitBezels` would change.

**A new repository for bezels.** Ruled out: the artwork is a SkinKit format 2 document, the package would
depend on SkinKit anyway, and all three apps already resolve SkinKit at one revision.

**Keeping the rules in `PVSettings` and sharing only views.** Ruled out: the rules are the part most worth
sharing, and `PVSettings` is not a shared package.

## GPU safety

Kept, and where:

- Draw the plain picture while a TV loads: Provenance's renderer, unchanged. The plain TV path draws
  nothing on the GPU.
- Watch TV frames and drop the TV on a timeout or page fault; say so when iOS has revoked GPU access:
  `TVFrameFailure` (shared) classifies; Provenance's `watchTVFrame` acts. An app that adds the shader path
  must do the same.
- Room light off by default before Apple GPU family 7: `TVBezelRoomLight` (shared).

## What iCube and iFly do

Both: add the two products, set `BezelEnvironment.current` at launch, resolve the TV with
`BezelChoice.resolve`, ask `GameplayBezelPlacement.showsTV` whether it may show, and when it may, lay the
game surface out with `TVBezelLayout` and put `TVBezelArtworkView` behind (built-in TV) or above (image
bezel) it. The switcher is `BezelSwitcherHost` over the paused game.

- **iFly**: override the rect `emulatorFrame` / `displayFrame` returns and add the artwork to the same
  `ZStack`. The pause menu is a sheet, so the strip needs its own overlay on the emulation view rather
  than a `PauseSheet` case. Game key: `GameSettingsManager.shared.currentGameId`.
- **iCube**: the same in `iosEmulationSurface`. Its post processor filters the surface only, so the
  artwork view is untouched by filters. The pause menu is a `fullScreenCover`, so the strip also needs its
  own overlay. SkinKit is linked on iOS and Catalyst only: tvOS needs the products added there. No
  `SystemIdentifier`: it passes `com.provenance.gamecube` and `com.provenance.wii` as plain strings. When
  an external display takes the render host, no TV shows on the device.

The shader TV (reflections, glass, room light) is a second step in each app, through its own filter chain
and with the safety rules above. It needs the two `uborder` presets in that app's shader library.

## Open questions for the owner

1. iCube's 2026-11-02 hand-off says no new UI before the release screenshots. The iCube work is on a
   branch with a PR, not merged; when it lands is the owner's call.
2. The plain TV has no glass, reflections or room light. If that is not good enough for iCube and iFly,
   the shader path through each app's own chain is the next step, before or after a shared runtime.
3. SkinKit needs a tagged release holding the two products before any app can pin a version. Until then
   the apps depend on the branch.
