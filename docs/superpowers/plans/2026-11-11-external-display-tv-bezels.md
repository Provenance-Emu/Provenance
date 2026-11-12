# TVs on the External Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player picks a TV in External Display options and the game appears inside it on the external display, with reflections, room light and any filter inside the glass.

**Architecture:** Two draw stages on the external output. Stage 1 draws the game through the screen filter into a texture the size of the tube. Stage 2 runs a bezel-only slang pass (`uborder`) over the whole 16:9 scene with that texture as its picture and the TV's cabinet art, rendered once from a format 2 skin document, as its `BORDER` texture. Selection rules are pure types in PVSettings; shader glue is in PVShaders; catalogue, artwork and drawing are in PVUI.

**Tech Stack:** Swift, Metal, PVSlangRuntime `FilterChain`, SkinKit2Core/SkinKit2Render, Defaults, SwiftUI.

**Spec:** `docs/superpowers/specs/2026-11-11-external-display-tv-bezels-design.md` (piece 1 only).

## Global Constraints

- iOS 17+. All new PVUI code sits inside `#if os(iOS)` like the files it extends; tvOS must still compile.
- No image or shader bytes committed. Catalogue and artwork are JSON text.
- Device-side skin code is not changed. With the TV *None*, every existing path behaves as before.
- Existing filter paths in PVShaders behave as before; new parameters default to the old behaviour.
- Other agents share this checkout: commit only this plan's files, by path.
- Owner preference: write tests, do not loop on full xcodebuild test runs; one simulator build and check at the end.

## Review Focus

1. A stored TV id that no longer exists: the display shows the picture alone, no crash (Task 1 test).
2. A game that is not 4:3 (16:9, 10:9, 8:7): black bars inside the glass, never stretched (Task 2 test).
3. A display that is not 16:9: the scene is letterboxed (Task 2 test).
4. The user's filter is from the Bezels group, or has its own curvature: treated as Off / curvature forced off (Task 2 tests).
5. Artwork or preset not ready or failed: picture alone, then redraw (Task 4, checked by eye and by log).

---

### Task 1: Settings and selection rules (PVSettings)

**Files:**
- Create: `PVSettings/Sources/PVSettings/Settings/Model/ExternalDisplayBezelRules.swift`
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (keys beside `externalDisplaySkin`)
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/ExternalDisplayPlan.swift`
- Test: `PVSettings/Tests/PVSettingsTests/ExternalDisplayBezelRulesTests.swift`, `ExternalDisplayPlanTests.swift`

**Produces:**
- Keys: `externalDisplayBezel: Key<String>` (default `""` = None), `externalDisplayBezelMatchesSystem: Key<Bool>` (true), `externalDisplayBezelLightsRoom: Key<Bool>` (true).
- `public enum ExternalDisplayBezelRules` with
  `struct Candidate { id: String; preferredSystems: Set<String> }` and
  `static func bezelID(chosen: String, matchesSystem: Bool, systemID: String?, candidates: [Candidate]) -> String?`
  (system's preferred TV when matching is on, else the chosen one if it exists, else nil; first candidate wins a tie), and
  `enum TubeFilter { case tvOwn, user, off }` with
  `static func tubeFilter(hasUserSelection: Bool, userSelectionIsOff: Bool, userSelectionIsBezel: Bool) -> TubeFilter`.
- `ExternalDisplayPlan.Inputs.bezelChosen: Bool` (default false in the initializer) and `ExternalDisplayPlan.bezelOnExternalDisplay`; `skinOnExternalDisplay` is false whenever a bezel is on.

- [ ] Tests: chosen only; match on with and without a preferred TV; match off; unknown id gives nil; empty id gives nil; two candidates claiming one system gives the first; tube filter table; plan: bezel on implies no skin, bezel needs `gameOnExternalDisplay`.
- [ ] Implement, commit.

### Task 2: Shader glue (PVShaders)

**Files:**
- Create: `PVShaders/Sources/PVShaders/Library/TVBezelShader.swift`
- Modify: `PVShaders/Sources/PVShaders/SlangFilterRenderer.swift`, `ShaderPostProcessor.swift`, `RenderGeometry.swift`
- Test: `PVShaders/Tests/PVShadersTests/TVBezelShaderTests.swift`, `RenderGeometryTests.swift`

**Produces:**
- `public struct ShaderTextureOverrides: Sendable { key: String; textures: [String: Data] }` and
  `SlangFilterRenderer.prepare(_:textures:)`, `ShaderPostProcessor.update(_:smoothing:textures:)` (both default nil). The loaded identity is the preset id plus `key`; a wrapping `CompiledShaderContainer` returns the override for a named texture and the directory's own for the rest.
- `public enum TVBezelShader`:
  - `bezelOnlyID = "bezel/uborder/preset_tools/append-uborder-bezel-reflections"`, `ambientID = "bezel/uborder/uborder-koko-ambi"`, `borderTextureName = "BORDER"`, `sceneAspect = CGSize(16, 9)`.
  - `geometryValues(tubeAspect: CGFloat, tubeHeightFraction: CGFloat) -> [String: Float]`: `fr_aspect_y = 8`, `fr_aspect_x = 8 * aspect`, `fr_zoom = heightFraction * 9 / 16 * 100`, centre parameters 0.
  - `neutralTubeValues: [String: Float]` (the ambient preset's built-in crt-nobody turned down: `CN_InputGamma` 2.2, `CN_OutputGamma` 2.2, `CN_VIG_TOGGLE` 0, `CN_BEAM_MIN_WIDTH` 1, `CN_BEAM_MAX_WIDTH` 1, `CN_SCAN_SIZE` 1, `CN_MASK_STRENGTH` 0, `CN_PHOSPHOR_LAYOUT` 0).
  - `curvatureOffValues(for: ShaderCatalogEntry) -> [String: Float]`: for parameters named `CURVATURE`, `h_curvature`, `curvature`, `CRT_CURVATURE`, `warpX`, `warpY`, `WARP_X`, `WARP_Y`, `curv`, value 0 when the parameter's range includes 0.
  - `isBezelFilter(_ entry: ShaderCatalogEntry) -> Bool` (`looks.contains(.bezel)`).
  - `values(frame: [String: Float], tubeAspect:, tubeHeightFraction:, lightsRoom: Bool) -> [String: Float]` merging the above; `presetID(lightsRoom:)`.
- `RenderGeometry.sceneRect(drawableSize: CGSize) -> CGRect` (16:9 aspect-fit, integral) and `RenderGeometry.tubePixelSize(tubeRect: CGRect, canvas: CGSize, sceneRect: CGRect) -> (width: Int, height: Int)`.

- [ ] Tests: geometry values for a 4:3 tube 72 % of the scene height (`fr_zoom` 40.5, aspect 10.667/8); neutral values present only with room light; curvature off for an entry with `CURVATURE` and untouched for one without; bezel filter detection; scene rect for 1920x1080, 1024x768, 3440x1440; tube pixel size.
- [ ] Implement, `xcrun swift test` in PVShaders, commit.

### Task 3: Catalogue and artwork (PVUI)

**Files:**
- Create: `PVUI/Sources/PVUIBase/ExternalDisplay/TVBezel.swift` (model + bundled catalogue), `TVBezelArtwork.swift` (format 2 document to tube rect and PNG data)
- Create: `PVUI/Sources/PVUIBase/Resources/TVBezels/catalog.json`, `studio-monitor.skin.json` (then `living-room-tv`, `computer-monitor`)
- Modify: `PVUI/Package.swift` (PVUIBase gains `SkinKit2Core`, `SkinKit2Render`; resources)
- Test: `PVUI/Tests/PVUIBaseTests/TVBezelCatalogTests.swift`

**Produces:**
- `struct TVBezel: Decodable, Identifiable, Equatable { id, name, preferredSystems: [String], frame: [String: Float], look: Look?, lightsRoom: Bool, artwork: String }`, `Look { shader: String; values: [String: Float] }`.
- `enum TVBezelCatalog { static let bundled: [TVBezel]; static func bezel(id:) -> TVBezel?; static var candidates: [ExternalDisplayBezelRules.Candidate] }`.
- `struct TVBezelArtwork { let tubeRect: CGRect; let canvas: CGSize; init?(bezel:); func pngData(pixelSize: CGSize) -> Data? }` (canvas 1920x1080, tv / standard / landscape environment; exactly one screen node).

- [ ] Tests: catalogue decodes; ids unique; no system preferred by two TVs; every `look.shader` and both uborder presets are valid `ShaderID`s; every artwork document loads, has one screen, the screen is centred and 4:3.
- [ ] Author the Studio Monitor document and catalogue entry; render it with the scratch tool to judge it; commit.

### Task 4: Drawing (PVUI)

**Files:**
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/GameExternalOutputView.swift` (bezel state, tube texture)
- Modify: `PVUI/Sources/PVUIBase/PVGLViewController/PVMetalViewController.swift` (`presentOnExternalOutput` two stages; plain-picture helper shared with the existing fallback)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+ExternalDisplay.swift` (`updateExternalDisplayBezel()`, filter resolution, observed keys)

**Consumes:** Tasks 1 to 3.

- `GameExternalOutputView.showBezel(_ bezel: TVBezel?, lightsRoom: Bool, didChange:)`: loads artwork off the main thread, hands PNG data to `bezelProcessor.update(resolved, smoothing: true, textures:)`, keeps `tubeRect`; `bezelIsReady`.
- `presentOnExternalOutput`: when a bezel is set and ready, stage 1 into `output.tubeTexture(size:)` (filter or plain picture, aspect-fit, black bars), stage 2 into the drawable's `sceneRect`. If stage 2 returns false, draw the picture alone as today.
- Filter for stage 1: `ExternalDisplayBezelRules.tubeFilter` decides TV's own look (a `ResolvedShader` built from the catalogue values), the user's selection (values plus `curvatureOffValues`), or none.

- [ ] Implement; build `Provenance-Dev-UI` for the simulator; fake a display with the lldb recipe; screenshot; check the `External display:` log lines; commit.

### Task 5: Options UI (PVUI)

**Files:**
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/ExternalDisplayOptionsView.swift`

- **TV** picker (None plus `TVBezelCatalog.bundled`), **Match the System's Screen**, **Light the Room**, footers. The skin picker shows only when the TV is None. The Screen Filter summary reads "The TV's Own" when a TV is chosen and no selection is set; the reset button in the filter picker reads "Use the TV's own look" then. A Bezels-group pick is shown in the summary as "Off (has its own frame)".

- [ ] Implement, swiftlint the changed files, commit.

### Task 6: Remaining TVs, notes

- [ ] Living Room TV and Computer Monitor documents and catalogue entries, judged by eye.
- [ ] Update `CLAUDE.md` (External display bullet), the memory note and the shared notes folder. Push.
