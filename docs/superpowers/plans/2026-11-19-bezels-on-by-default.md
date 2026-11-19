# TV Bezels On By Default Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A TV around the game by default in landscape (controller or generated touch controls), and a switcher strip in the pause menu that previews each TV on the paused game and is drivable from a controller.

**Architecture:** The decisions (which TV, whether the device may show one, what the switcher saves) are pure rules in PVSettings with fast tests. PVUIBase wires them into `PVEmulatorViewController` and `PVMetalViewController`, adds a transient preview choice read ahead of the saved settings, and adds the strip as a mode of `PauseTileMenuView`. A scene cache and a two-processor swap in `GameExternalOutputView` make stepping fast and flash-free.

**Tech Stack:** Swift 6.x, SwiftUI, UIKit, Metal, the `Defaults` package, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-19-bezels-on-by-default-design.md` (read it first; this plan argues from it).

## Global Constraints

- iOS 17 and tvOS 17 minimum. Every changed file compiles for iOS and tvOS; guard iOS-only API with `#if os(iOS)`.
- New pure rules live in PVSettings and are covered by `swift test`. PVUI is compiled once per task that touches it.
- No Bezel Project artwork in the repo, the bundle or the tests.
- "Off" is never modelled as an optional's `nil`. `""` (`ExternalDisplayBezelRules.noBezelID`) is Off; a `nil` preview means "no preview".
- Stored values keep their meaning: a stored `""` stays None and a stored TV id stays that TV.
- Use `SystemIdentifier`, not raw `com.provenance.*` strings, in new app code (test fixtures may use strings, as the existing rule tests do).
- Shared checkout: commit only your own files by path, never `git add -A`. Never `git reset`, `rebase` or `stash`.
- User-facing copy fixed by this plan must be used verbatim.

Commands used throughout:

```bash
# PVSettings tests (fast)
cd PVSettings && xcrun swift test --filter <SuiteName>

# PVUI compile check (several minutes; run once per PVUI task)
printf 'OTHER_CFLAGS = $(inherited) -Wno-invalid-specialization\nOTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-invalid-specialization\n' > /tmp/pv-realm.xcconfig
cd PVUI && xcodebuild build-for-testing -scheme PVUI-UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' -xcconfig /tmp/pv-realm.xcconfig \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS=x86_64 -skipPackagePluginValidation -skipMacroValidation
# Expected: ** TEST BUILD SUCCEEDED **

# PVUI unit tests for one suite: same command with `test` and `-only-testing:PVUIBaseTests/<Suite>`
```

## Review Focus

1. **The chosen TV no longer exists** (an imported bezel was deleted). Expected: no TV shows, nothing crashes, and the switcher opens on Automatic. Tests in Tasks 1 and 5.
2. **`living-room-tv` is missing from the catalogue** (artwork or shader library failed to load). Expected: Automatic shows no TV and reports "nothing fits". Test in Task 1.
3. **Keep with "This game only" off on a game that has a pin.** Expected: the pin is removed, otherwise the saved default never shows for that game. Test in Task 5.
4. **Stepping past either end of the strip, and Keep on "More…".** Expected: the selection clamps; Keep on More writes nothing. Tests in Task 5.
5. **Rotation to portrait, or a real skin applied, while the strip is open.** Expected: the strip closes as Cancel and nothing is saved. Rule test in Task 2; behaviour step in Task 6.

---

### Task 1: "Automatic" in the TV rules

**Files:**
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/ExternalDisplayBezelRules.swift`
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift:74` (default of `externalDisplayBezel`)
- Test: `PVSettings/Tests/PVSettingsTests/ExternalDisplayBezelRulesTests.swift`

**Interfaces:**
- Produces:

```swift
extension ExternalDisplayBezelRules {
    public static let automaticBezelID = "auto"
    public static let automaticDefaultBezelID = "living-room-tv"

    public struct Resolution: Equatable, Sendable {
        public enum Outcome: Equatable, Sendable {
            case bezel(String)
            case noneChosen      // the player chose None, or the game is pinned to none
            case noneForSystem   // Automatic, and the system has a screen of its own
            case noneAvailable   // Automatic or a chosen TV, and nothing in the catalogue fits
        }
        public let outcome: Outcome
        /// Automatic produced the answer (no usable pin, no game artwork, chosen is `automaticBezelID`).
        public let isAutomatic: Bool
        public var bezelID: String? { get }   // the id for `.bezel`, else nil
    }

    public static func resolve(chosen: String, matchesSystem: Bool, systemID: String?,
                               systemSuitsTV: Bool, candidates: [Candidate],
                               pinned: String? = nil, gameArt: String? = nil,
                               automaticDefault: String = automaticDefaultBezelID) -> Resolution
}
```

- `bezelID(chosen:matchesSystem:systemID:candidates:pinned:gameArt:)` stays, implemented as `resolve(..., systemSuitsTV: true).bezelID`, so its existing tests keep passing.

- [ ] **Step 1: Write the failing tests** (add to the existing suite, reusing its `candidates`; add `.init(id: "living-room-tv")` to a second candidate list `withDefault`)

```swift
@Test("Automatic gives a console the default TV and a handheld none")
func automaticBySystem() {
    let tv = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                           systemSuitsTV: true, candidates: withDefault)
    #expect(tv.outcome == .bezel("living-room-tv"))
    #expect(tv.isAutomatic)
    let handheld = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.gba",
                                 systemSuitsTV: false, candidates: withDefault)
    #expect(handheld.outcome == .noneForSystem)
    #expect(handheld.bezelID == nil)
}

@Test("Automatic prefers a TV that lists the system, whatever Match the System's Screen says")
func automaticPrefersListingTV() {
    let r = Rules.resolve(chosen: "auto", matchesSystem: false, systemID: "com.provenance.c64",
                          systemSuitsTV: true, candidates: withDefault)
    #expect(r.outcome == .bezel("computer"))
}

@Test("Automatic with no default TV in the catalogue shows nothing")
func automaticWithoutDefault() {
    let r = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                          systemSuitsTV: true, candidates: candidates)   // no living-room-tv
    #expect(r.outcome == .noneAvailable)
}

@Test("A pin and game artwork still come before Automatic, and are not Automatic")
func pinBeatsAutomatic() {
    let pinnedNone = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.snes",
                                   systemSuitsTV: true, candidates: withDefault, pinned: "")
    #expect(pinnedNone.outcome == .noneChosen)
    #expect(!pinnedNone.isAutomatic)
    let pinned = Rules.resolve(chosen: "auto", matchesSystem: true, systemID: "com.provenance.gba",
                               systemSuitsTV: false, candidates: withDefault, pinned: "studio")
    #expect(pinned.outcome == .bezel("studio"))
}

@Test("A stored None stays None, and a chosen TV that is gone shows nothing")
func storedChoicesKeepTheirMeaning() {
    #expect(Rules.resolve(chosen: "", matchesSystem: true, systemID: "com.provenance.snes",
                          systemSuitsTV: true, candidates: withDefault).outcome == .noneChosen)
    #expect(Rules.resolve(chosen: "deleted-import", matchesSystem: true, systemID: "com.provenance.snes",
                          systemSuitsTV: true, candidates: withDefault).outcome == .noneAvailable)
}

@Test("An explicit TV ignores whether the system suits a TV")
func explicitIgnoresSystemSuitsTV() {
    #expect(Rules.resolve(chosen: "studio", matchesSystem: true, systemID: "com.provenance.gba",
                          systemSuitsTV: false, candidates: withDefault).outcome == .bezel("studio"))
}
```

- [ ] **Step 2: Run** `cd PVSettings && xcrun swift test --filter ExternalDisplayBezelRules`. Expected: compile failure, `resolve` not found.
- [ ] **Step 3: Implement `resolve` and the constants.** Order: usable pin (`""` gives `.noneChosen`), game artwork, then `chosen`: `""` gives `.noneChosen`; `"auto"` gives `.noneForSystem` when `!systemSuitsTV`, else the TV listing the system (the player's own first, then catalogue order), else `automaticDefault` if it is a known candidate, else `.noneAvailable`; any other id keeps today's logic and gives `.noneAvailable` when unknown.
- [ ] **Step 4: Change the default.** `externalDisplayBezel`'s default becomes `ExternalDisplayBezelRules.automaticBezelID`; update its doc comment.
- [ ] **Step 5: Run the suite again.** Expected: all pass, the pre-existing tests included.
- [ ] **Step 6: Commit** `feat(display): an Automatic TV choice, now the default`.

### Task 2: Where the device may show a TV

**Files:**
- Create: `PVSettings/Sources/PVSettings/Settings/Model/GameplayBezelPlacement.swift`
- Test: `PVSettings/Tests/PVSettingsTests/GameplayBezelPlacementTests.swift`

**Interfaces:**
- Produces:

```swift
public enum GameplayBezelPlacement {
    public enum Controls: Equatable, Sendable {
        case generated            // the generated touch controls are on screen
        case skin                 // a real or built-in skin is on screen
        case hiddenByController   // a hardware controller hid the on-screen controls
        case bare                 // nothing on screen and no controller (never name a case `none`:
                                  // passed as an optional it silently becomes Optional.none)
    }
    public struct Inputs: Equatable, Sendable {
        public var isAppleTV: Bool
        public var isLandscape: Bool
        public var controls: Controls
        /// Single screen, filters apply, the host GPU view draws the game, the presenter presents the core's frames.
        public var layoutSupportsTV: Bool
        /// `Resolution.isAutomatic` of the TV that would show.
        public var choiceIsAutomatic: Bool
        public var editingLayout: Bool
        public init(isAppleTV: Bool, isLandscape: Bool, controls: Controls, layoutSupportsTV: Bool,
                    choiceIsAutomatic: Bool, editingLayout: Bool = false)
    }
    public static func showsTV(_ inputs: Inputs) -> Bool
    /// The pause menu offers the switcher: an explicitly chosen TV could show in this state.
    public static func offersSwitcher(_ inputs: Inputs) -> Bool
}
```

- [ ] **Step 1: Write the failing tests.** One parameterised test over the spec's table plus the guards:

```swift
@Test("The placement table", arguments: [
    // appleTV, landscape, controls, automatic, expected
    (true,  true,  Placement.Controls.bare,               true,  true),
    (false, true,  .hiddenByController, true,  true),
    (false, true,  .generated,          true,  true),
    (false, true,  .bare,               true,  true),
    (false, true,  .skin,               false, false),
    (false, false, .hiddenByController, false, true),   // an explicit TV, as today
    (false, false, .hiddenByController, true,  false),  // Automatic never in portrait
    (false, false, .generated,          false, false),
    (false, false, .skin,               false, false),
])
func table(appleTV: Bool, landscape: Bool, controls: Placement.Controls, automatic: Bool, expected: Bool) {
    #expect(Placement.showsTV(.init(isAppleTV: appleTV, isLandscape: landscape, controls: controls,
                                    layoutSupportsTV: true, choiceIsAutomatic: automatic)) == expected)
}

@Test("No TV when the layout cannot take one, or while the layout editor is open")
func guards() {
    #expect(!Placement.showsTV(.init(isAppleTV: true, isLandscape: true, controls: .bare,
                                     layoutSupportsTV: false, choiceIsAutomatic: false)))
    #expect(!Placement.showsTV(.init(isAppleTV: false, isLandscape: true, controls: .generated,
                                     layoutSupportsTV: true, choiceIsAutomatic: false, editingLayout: true)))
}

@Test("The switcher is offered wherever an explicit TV could show, and nowhere else")
func switcher() {
    #expect(Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: true, controls: .generated,
                                           layoutSupportsTV: true, choiceIsAutomatic: true)))
    #expect(Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: false, controls: .hiddenByController,
                                           layoutSupportsTV: true, choiceIsAutomatic: true)))
    #expect(!Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: false, controls: .generated,
                                            layoutSupportsTV: true, choiceIsAutomatic: false)))
    #expect(!Placement.offersSwitcher(.init(isAppleTV: false, isLandscape: true, controls: .skin,
                                            layoutSupportsTV: true, choiceIsAutomatic: false)))
}
```

(`private typealias Placement = GameplayBezelPlacement` in the suite.)

- [ ] **Step 2: Run** `xcrun swift test --filter GameplayBezelPlacement`. Expected: compile failure.
- [ ] **Step 3: Implement.** `offersSwitcher` is `showsTV` with `choiceIsAutomatic` forced to `false`.
- [ ] **Step 4: Run again.** Expected: pass.
- [ ] **Step 5: Commit** `feat(display): rule for where the device shows a TV`.

### Task 3: Room light by device

**Files:**
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/ExternalDisplayBezelRules.swift`
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift:80`
- Modify: every reader of `externalDisplayBezelLightsRoom` (`grep -rn externalDisplayBezelLightsRoom PVUI/Sources`): `ExternalDisplayOptionsView.swift`, `PVEmulatorViewController+ExternalDisplay.swift`, `GameplayBezelOptionsView.swift`
- Create: `PVUI/Sources/PVUIBase/ExternalDisplay/TVBezelRoomLight.swift`
- Test: `PVSettings/Tests/PVSettingsTests/ExternalDisplayBezelRulesTests.swift`

**Interfaces:**
- Produces:

```swift
// PVSettings
extension ExternalDisplayBezelRules {
    /// `stored == nil` means the player never set it: on for recent GPUs only.
    public static func lightsRoom(stored: Bool?, gpuIsRecent: Bool) -> Bool
}
// Key keeps its name and becomes optional:
static let externalDisplayBezelLightsRoom = Key<Bool?>("externalDisplayBezelLightsRoom", default: nil)

// PVUIBase
enum TVBezelRoomLight {
    /// Apple GPU family 7 and later (A14, M1).
    static let gpuIsRecent: Bool   // MTLCreateSystemDefaultDevice()?.supportsFamily(.apple7) ?? false
    static var isOn: Bool { get }  // lightsRoom(stored: Defaults[.externalDisplayBezelLightsRoom], gpuIsRecent:)
    static func set(_ on: Bool)    // writes the stored value
}
```

- [ ] **Step 1: Failing test**

```swift
@Test("Room light follows the device until the player sets it")
func roomLightByDevice() {
    #expect(Rules.lightsRoom(stored: nil, gpuIsRecent: true))
    #expect(!Rules.lightsRoom(stored: nil, gpuIsRecent: false))
    #expect(Rules.lightsRoom(stored: true, gpuIsRecent: false))
    #expect(!Rules.lightsRoom(stored: false, gpuIsRecent: true))
}
```

- [ ] **Step 2: Run, expect a compile failure. Step 3: Implement the rule and change the key type.**
- [ ] **Step 4: Add `TVBezelRoomLight` and move every reader to `TVBezelRoomLight.isOn`;** toggles bind through `Binding(get: { TVBezelRoomLight.isOn }, set: TVBezelRoomLight.set)`. The `Defaults.updates` list in `PVEmulatorViewController+ExternalDisplay.swift` keeps observing the key.
- [ ] **Step 5: Run the PVSettings suite and the PVUI compile check.** Expected: pass, `TEST BUILD SUCCEEDED`.
- [ ] **Step 6: Commit** `feat(display): room light defaults by GPU generation`.

### Task 4: TVs on by default on the device

**Files:**
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/TVBezel.swift` (`TVBezelCatalog`)
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/GameplayBezelOptionsView.swift` (the `PVEmulatorViewController` extension at the top)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController.swift` (stored properties near line 296; `handleOrientationChange` near line 3160)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+ExternalDisplay.swift` (`externalDisplayBezel`, the `Defaults.updates` observer)
- Modify: `PVUI/Sources/PVUIBase/Controller/PVEmulatorViewController+DeltaSkinScreen.swift:174-200` (`applyViewportFromCurrentSkin`), `:807` (`applyFrameToMetal`)
- Modify: `PVUI/Sources/PVUIBase/Controller/PVEmulatorViewController+DeltaSkin.swift` (`overlayScreenFramesDidChange`)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+VirtualMouse.swift:262` (`resolvedVirtualMouseViewportFrame`)
- Modify: `PVUI/Sources/PVUIBase/PVGLViewController/PVMetalViewController.swift` (`updateLocalBezel` area)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PauseTileMenuViewModel.swift:422`
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/TVBezelPickerView.swift`
- Test: `PVUI/Tests/PVUIBaseTests/TVBezelCatalogTests.swift`

**Interfaces:**
- Consumes: `ExternalDisplayBezelRules.resolve`, `Resolution`, `GameplayBezelPlacement` (Tasks 1, 2); `TVBezelRoomLight.isOn` (Task 3).
- Produces:

```swift
extension TVBezelCatalog {
    /// Replaces `bezel(chosen:matchesSystem:systemID:pinned:gameArt:)`; delete that one and move its two callers.
    static func resolve(chosen: String, matchesSystem: Bool, systemID: String?, systemSuitsTV: Bool,
                        pinned: String? = nil, gameArt: String? = nil)
        -> (resolution: ExternalDisplayBezelRules.Resolution, bezel: TVBezel?)
}

extension PVEmulatorViewController {
    /// A preview from the switcher, read ahead of the saved settings. `nil` is no preview; `choice == ""` is Off.
    struct BezelPreview: Equatable { var choice: String; var lightsRoom: Bool }
    var bezelPreview: BezelPreview?            // stored in the class body; didSet calls refreshBezels()
    var isGameplayBezelShowing: Bool           // stored; set by updateGameplayBezel()
    /// The one place both screens resolve the TV: preview first, then pin, artwork and the saved choice.
    func resolvedBezel() -> (resolution: ExternalDisplayBezelRules.Resolution, bezel: TVBezel?)
    var bezelPlacementInputs: GameplayBezelPlacement.Inputs { get }
    var offersBezelSwitcher: Bool { get }      // replaces canShowGameplayBezels for the pause tile
    func refreshBezels()                       // updateGameplayBezel() + (iOS) updateExternalDisplay()
}

extension PVMetalViewController {
    /// The game picture's rect inside the TV, in the GPU view's coordinates (points); nil when no TV shows.
    func localBezelPictureFrame() -> CGRect?
}
```

- [ ] **Step 1: Failing catalogue test** in `TVBezelCatalogTests`:

```swift
@Test("The catalogue holds the TV Automatic falls back to")
func automaticDefaultExists() {
    #expect(TVBezelCatalog.bezel(id: ExternalDisplayBezelRules.automaticDefaultBezelID) != nil)
    let r = TVBezelCatalog.resolve(chosen: ExternalDisplayBezelRules.automaticBezelID, matchesSystem: true,
                                   systemID: "com.provenance.snes", systemSuitsTV: true)
    #expect(r.bezel?.id == "living-room-tv")
}
```

- [ ] **Step 2: `TVBezelCatalog.resolve`, `resolvedBezel()`.** `systemSuitsTV` is `ScreenType(rawValue: gpuViewController.screenType)?.isCRT ?? false` (the value `GameLaunchingViewController.swift:1423` copies from the system). With a preview: `chosen = preview.choice`, no pin, no game artwork. `externalDisplayBezel` (external screen) and `updateGameplayBezel()` both call it; room light comes from the preview, else `TVBezelRoomLight.isOn`.
- [ ] **Step 3: Placement.** `bezelPlacementInputs`: `isAppleTV` by `#if os(tvOS)`; `isLandscape` from `currentOrientation == .landscape`; `controls` is `.skin` when a skin is mounted and `!isProgrammaticOverlayActive`, else `.hiddenByController` when `controllerHidesOnScreenControls`, else `.generated` when `isProgrammaticOverlayActive`, else `.bare`; `layoutSupportsTV` is today's three conditions from `canShowGameplayBezels`; `editingLayout` from the layout editor's open state (`PVEmulatorViewController+LayoutEditor.swift`). `updateGameplayBezel()` shows the resolved TV only when `GameplayBezelPlacement.showsTV`, sets `isGameplayBezelShowing`, and calls `applyViewportFromCurrentSkin()` when that flag changed. Delete `canShowGameplayBezels`.
- [ ] **Step 4: The picture under the generated controls.** In `applyViewportFromCurrentSkin()`, inside the `isProgrammaticOverlayActive` branch: when `isGameplayBezelShowing`, apply `view.bounds` with reason `"viewport-tv"` instead of the overlay's frame. In `applyFrameToMetal`, skip `adjustFrameForScalingMode` for that reason.
- [ ] **Step 5: Pointer mapping.** Implement `localBezelPictureFrame()` (image bezels: `GameExternalOutputView.pictureRect`; shader TVs: the picture aspect-fit in the tube rect of the 16:9 scene). `resolvedVirtualMouseViewportFrame()` returns it, converted to `view`, ahead of the GPU view's frame. Then `grep -rn "gpuViewController.view.frame\|gpuView.frame\|currentTargetFrame" PVUI/Sources/PVUIBase` for other touch-to-game readers (light gun, touch pointer): each either uses the same helper or, if it cannot, is listed in the commit message so Task 9 records it as a known gap.
- [ ] **Step 6: Hooks.** Call `updateGameplayBezel()` from: the 50 ms work item in `handleOrientationChange` right after `currentOrientation` is set; `overlayScreenFramesDidChange` on mount and unmount (next to the existing `updateExternalDisplay()`); `currentSkin`'s `didSet`; and the `Defaults.updates` observer, which also gains `.hideOnScreenControlsWithController` if missing and the bezel keys it already lists.
- [ ] **Step 7: Pause tile and picker.** The Bezels tile shows when `emulatorVC.offersBezelSwitcher`. `TVBezelPickerView` gains `var offersSystemAutomatic = false`; when set it lists a row "Automatic" with id `ExternalDisplayBezelRules.automaticBezelID` above "None", with the footer "Automatic shows a TV for consoles and computers in landscape, and none for handhelds." Pass `offersSystemAutomatic: true` from the global pickers in `GameplayBezelOptionsView` and `ExternalDisplayOptionsView`.
- [ ] **Step 8: Run** the PVUI compile check, then `-only-testing:PVUIBaseTests/TVBezelCatalogTests`. Expected: succeed, pass.
- [ ] **Step 9: Check in the simulator** with the dev harness (`make dev-harness ROM=<2600 test ROM> TARGET=ui`): the screenshot in `build/harness/` shows the picture inside the Living Room TV in landscape. Rotate a manual run to portrait: the TV goes and the picture returns to the overlay's rect.
- [ ] **Step 10: Commit** `feat(display): a TV around the game by default in landscape`.

### Task 5: The switcher's model

**Files:**
- Create: `PVSettings/Sources/PVSettings/Settings/Model/BezelSwitcherModel.swift`
- Test: `PVSettings/Tests/PVSettingsTests/BezelSwitcherModelTests.swift`

**Interfaces:**
- Produces:

```swift
public struct BezelSwitcherModel: Equatable, Sendable {
    public enum Group: Int, Sendable, CaseIterable { case basics, builtIn, shaderPresets, yours, more }
    public struct Item: Equatable, Sendable, Identifiable { public let id: String; public let group: Group }
    public static let moreID = "more"

    public private(set) var items: [Item]      // Off (""), Automatic ("auto"), builtIn…, shaderPresets…, yours…, More
    public private(set) var index: Int
    public var thisGameOnly: Bool
    public var lightsRoom: Bool

    /// - Parameter current: the choice in effect: the game's pin if it has one, else the saved choice.
    ///   An id not in the list opens on Automatic.
    public init(builtIn: [String], shaderPresets: [String], yours: [String],
                current: String, gameHasPin: Bool, lightsRoom: Bool)
    public var selection: Item { get }
    public mutating func step(_ delta: Int)          // clamps at both ends
    public mutating func jumpGroup(_ delta: Int)     // to the first item of the previous / next non-empty group
    public mutating func select(id: String)          // no-op for an unknown id

    public enum PinChange: Equatable, Sendable { case unchanged, set(String), remove }
    public struct Commit: Equatable, Sendable {
        public let chosen: String?        // new `externalDisplayBezel`; nil leaves it alone
        public let pin: PinChange
        public let lightsRoom: Bool
    }
    /// What Keep saves. `nil` when More is selected.
    public func commit(gameHasPin: Bool) -> Commit?
}
```

- [ ] **Step 1: Failing tests**

```swift
private func model(current: String = "auto", pin: Bool = false) -> BezelSwitcherModel {
    BezelSwitcherModel(builtIn: ["living-room-tv", "studio-monitor"], shaderPresets: ["uborder"],
                       yours: [], current: current, gameHasPin: pin, lightsRoom: true)
}

@Test("Items run Off, Automatic, TVs, More, and it opens on the current choice")
func order() {
    let m = model(current: "studio-monitor")
    #expect(m.items.map(\.id) == ["", "auto", "living-room-tv", "studio-monitor", "uborder", "more"])
    #expect(m.selection.id == "studio-monitor")
    #expect(!m.thisGameOnly)
    #expect(model(current: "studio-monitor", pin: true).thisGameOnly)
}

@Test("A current choice that is gone opens on Automatic")
func missingCurrent() { #expect(model(current: "deleted-import").selection.id == "auto") }

@Test("Stepping clamps at both ends")
func clamps() {
    var m = model(current: "")
    m.step(-1); #expect(m.selection.id == "")
    m.step(99); #expect(m.selection.id == "more")
}

@Test("Group jumps skip empty groups")
func groups() {
    var m = model(current: "")
    m.jumpGroup(1); #expect(m.selection.id == "living-room-tv")
    m.jumpGroup(1); #expect(m.selection.id == "uborder")
    m.jumpGroup(1); #expect(m.selection.id == "more")     // "yours" is empty
    m.jumpGroup(-1); #expect(m.selection.id == "uborder")
}

@Test("Keep for every game saves the choice and drops this game's pin")
func keepEveryGame() {
    var m = model(current: "auto", pin: true)
    m.thisGameOnly = false
    m.select(id: "studio-monitor")
    #expect(m.commit(gameHasPin: true) == .init(chosen: "studio-monitor", pin: .remove, lightsRoom: true))
    #expect(m.commit(gameHasPin: false) == .init(chosen: "studio-monitor", pin: .unchanged, lightsRoom: true))
}

@Test("Keep for this game pins it and leaves the saved choice alone")
func keepThisGame() {
    var m = model()
    m.thisGameOnly = true
    m.select(id: "")
    #expect(m.commit(gameHasPin: false) == .init(chosen: nil, pin: .set(""), lightsRoom: true))
    m.select(id: "auto")
    #expect(m.commit(gameHasPin: true) == .init(chosen: nil, pin: .remove, lightsRoom: true))
}

@Test("Keep on More saves nothing")
func keepOnMore() {
    var m = model(); m.select(id: "more")
    #expect(m.commit(gameHasPin: false) == nil)
}
```

- [ ] **Step 2: Run** `xcrun swift test --filter BezelSwitcherModel`, expect a compile failure. **Step 3: Implement. Step 4: Run, expect pass.**
- [ ] **Step 5: Commit** `feat(display): model for the pause-menu TV switcher`.

### Task 6: The switcher strip in the pause menu

**Files:**
- Create: `PVUI/Sources/PVUIBase/ExternalDisplay/BezelSwitcherStrip.swift`
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PauseTileMenuView.swift` (`showingBezels` at `:160`, tile tap at `:639`, `isCoveredByPresentation` at `:480`, `handleControllerCommand` at `:491`, the cover at `:2055`, tvOS input at `:2318`)
- Test: `PVUI/Tests/PVUIBaseTests/PauseSettingsPageTests.swift` (tile gating)

**Interfaces:**
- Consumes: `BezelSwitcherModel` (Task 5); `PVEmulatorViewController.bezelPreview`, `resolvedBezel()`, `offersBezelSwitcher`, `refreshBezels()` (Task 4); `TVBezelRoomLight` (Task 3).
- Produces:

```swift
struct BezelSwitcherStrip: View {
    @Binding var model: BezelSwitcherModel
    let name: (BezelSwitcherModel.Item) -> String   // "Off", "Automatic · Living Room TV", a TV's name, "More…"
    let isLoading: Bool
    let showsThisGameOnly: Bool
    let showsRoomLight: Bool
    let onKeep: () -> Void
    let onCancel: () -> Void
    let onMore: () -> Void
}
```

- [ ] **Step 1: Strip view.** A bottom-aligned bar in the pause menu's style: a horizontal `ScrollView` of item chips that keeps the selection centred, and a row of buttons: "Keep", "Cancel", "This game only", "Room light", "More…". On tvOS every chip and button is focusable, focusing a chip calls `model.select(id:)`, and `.onExitCommand(perform: onCancel)`. On iOS a tap on a chip selects it and the legend shows the controller's glyphs for A, B, X, Y, L1 and R1 when a controller is connected.
- [ ] **Step 2: Automatic's label.** From `emulatorVC` with a preview of `"auto"`: `.bezel(id)` gives "Automatic · <TV name>"; `.noneForSystem` and `.noneAvailable` give "Automatic · none for this system".
- [ ] **Step 3: Pause menu mode.** Add `@State private var bezelSwitcher: BezelSwitcherModel?`. The Bezels tile builds it (`builtIn` from `TVBezelCatalog.bundled`, `shaderPresets`, `yours` from listed `TVBezelLibrary.shared.bezels`; `current` is the game's pin, else `Defaults[.externalDisplayBezel]`) instead of setting `showingBezels`. While it is non-nil the menu's panel is not drawn and the strip is, bottom-aligned, over the clear background. `isCoveredByPresentation` gains `|| bezelSwitcher != nil`.
- [ ] **Step 4: Preview, Keep, Cancel.** `.task(id: bezelSwitcher?.selection.id)` sleeps 150 ms then sets `emulatorVC.bezelPreview = .init(choice:, lightsRoom:)` (not for More); a room-light toggle sets it at once. Keep applies `model.commit(gameHasPin:)` to `Defaults[.externalDisplayBezel]`, `Defaults[.externalDisplayBezelByGame]` and `TVBezelRoomLight.set`, then clears the preview and the model. Cancel clears both. `onDisappear` of the pause menu clears the preview. More clears the preview and the model and sets `showingBezels = true` (today's cover stays as the library).
- [ ] **Step 5: Controller (iOS).** At the top of `handleControllerCommand`, before the covered guard: when `bezelSwitcher != nil` route `.left`/`.right` to `step(∓1)`, `.previousTab`/`.nextTab` to `jumpGroup(∓1)`, `.activate` to Keep (or More when it is selected), `.back` to Cancel, `.quickSave` (X) to the room-light toggle, `.quickLoad` (Y) to "This game only", and return. On tvOS extend the existing guard to `!showingBezels && bezelSwitcher == nil`.
- [ ] **Step 6: Closing when a TV can no longer show.** Observe `emulatorVC.offersBezelSwitcher` where the menu already rebuilds its sections on rotation and controller changes; when it turns false with the strip open, Cancel.
- [ ] **Step 7: Loading mark.** `isLoading` is `(gpuViewController as? PVMetalViewController)?.isLocalBezelLoading` (added in Task 7; until then pass `false`).
- [ ] **Step 8: Tile test.** In `PauseSettingsPageTests`, where `bezelsTileID` is already referenced: the tile is present exactly when the view model's emulator reports `offersBezelSwitcher`. Follow the file's existing fixture.
- [ ] **Step 9: PVUI compile check and that suite.** Then by hand in the simulator: open the strip with a keyboard-mapped controller, step through every item, Keep, reopen, Cancel, rotate to portrait with it open.
- [ ] **Step 10: Commit** `feat(display): preview and switch TVs from a strip in the pause menu`.

### Task 7: Fast, flash-free switching

**Files:**
- Create: `PVUI/Sources/PVUIBase/ExternalDisplay/TVBezelSceneCache.swift`
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/GameExternalOutputView.swift`
- Modify: `PVUI/Sources/PVUIBase/PVGLViewController/PVMetalViewController.swift` (`drawBezel`)
- Test: `PVUI/Tests/PVUIBaseTests/TVBezelSceneCacheTests.swift`

**Interfaces:**
- Produces:

```swift
/// App-wide: with TVs on by default every game start would otherwise redraw the cabinet.
final class TVBezelSceneCache: @unchecked Sendable {
    static let shared: TVBezelSceneCache
    init(capacity: Int = 6)
    func scene(for key: String) -> TVBezelScene?     // marks the entry most recently used
    func store(_ scene: TVBezelScene, for key: String)
    func removeAll()                                  // also on UIApplication.didReceiveMemoryWarningNotification
}

extension GameExternalOutputView {
    /// Swaps in the TV that finished loading once its shader can draw. Call before drawing a frame.
    func promotePendingBezelIfReady()
}
extension PVMetalViewController { var isLocalBezelLoading: Bool { get } }
```

- [ ] **Step 1: Failing cache tests:** a stored scene comes back; storing a seventh evicts the least recently used; reading an entry protects it from eviction; `removeAll()` empties it. Build fixture scenes with `TVBezelScene(tubeRect:shader:textures:)` and a `ShaderCatalogEntry` like the one in `PVShaders/Tests/PVShadersTests/ShaderPostProcessorTests.swift`.
- [ ] **Step 2: Implement the cache** (lock-protected dictionary plus recency order).
- [ ] **Step 3: Use it in `showBezel`:** look up `key` before detaching `TVBezelScene.make`; store what `make` returns.
- [ ] **Step 4: No flash.** Give the view a second `ShaderPostProcessor`. A newly loaded scene goes to the pending one; the current scene and processor keep drawing. `promotePendingBezelIfReady()` swaps them when the pending processor `isReady`, and drops the pending one when it `hasFailed`. `drawBezel` calls it first. `isBezelPending` stays true only while nothing can draw (no current scene). Showing no TV clears both.
- [ ] **Step 5: `isLocalBezelLoading`** is true while the local output has a load in flight or a pending scene.
- [ ] **Step 6: PVUI compile check and `TVBezelSceneCacheTests`.** By hand: step between two TVs in the strip; the first TV stays until the second appears, with no bare frame between.
- [ ] **Step 7: Commit** `perf(display): cache TV scenes and swap them without a flash`.

### Task 8: GPU safety

**Files:**
- Create: `PVUI/Sources/PVUIBase/ExternalDisplay/TVFrameFailure.swift`
- Modify: `PVUI/Sources/PVUIBase/PVGLViewController/PVMetalViewController.swift` (the local TV branch of `directRender` near line 2480; `presentOnExternalOutput`)
- Modify: `PVUI/Sources/PVUIBase/ExternalDisplay/GameExternalOutputView.swift`
- Test: `PVUI/Tests/PVUIBaseTests/TVFrameFailureTests.swift`

**Interfaces:**
- Produces:

```swift
enum TVFrameFailure {
    enum Action: Equatable { case dropTV, accessRevoked, logOnly }
    /// `.accessRevoked` for MTLCommandBufferError.Code.accessRevoked (4); `.dropTV` for .timeout (2) and
    /// .pageFault (3); `.logOnly` otherwise and for errors outside MTLCommandBufferErrorDomain.
    static func action(for error: Error) -> Action
}
extension GameExternalOutputView {
    /// No TV on this screen for the rest of the game session; `showBezel` becomes a no-op for TVs.
    func dropBezelForSession()
}
```

- [ ] **Step 1: Failing tests:** `NSError(domain: MTLCommandBufferErrorDomain, code: 4)` gives `.accessRevoked`; codes 2 and 3 give `.dropTV`; code 1 and a `URLError` give `.logOnly`. Confirm the constants against `Metal.framework/Headers/MTLCommandBuffer.h` in the active SDK before relying on them.
- [ ] **Step 2: Implement `TVFrameFailure`.**
- [ ] **Step 3: Watch the frames.** Both TV paths add a completion handler before `commit()`: on error `ELOG("GPU error drawing the TV on <device|external display>: \(error)")`, then on the main queue act on `TVFrameFailure.action`:
  - `.dropTV`: `output.dropBezelForSession()`, `redrawPausedFrame()`, and once per game session `PVToastManager.post("The TV was turned off: this device could not draw it", type: .warning, duration: 4.0, icon: "tv")`.
  - `.accessRevoked`: once per app run, `PVAlertCenter.shared.present(PVAlert(title: "Graphics Stopped", message: "iOS has stopped Provenance from drawing after a graphics error. Reopen Provenance to continue playing.", type: .error, actions: [.ok {}]))`.
  - `.logOnly`: nothing more.
  Do not call `recoverFromGPUError()` for `.accessRevoked`: a new queue is refused too.
- [ ] **Step 4: PVUI compile check and `TVFrameFailureTests`.**
- [ ] **Step 5: Commit** `fix(display): drop a TV the GPU cannot draw, and say when iOS has cut drawing off`.

### Task 9: Settings page, docs, final checks

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/BezelSettingsView.swift`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift` (near the External Display row at `:1844`)
- Modify: `CLAUDE.md` (the TV paragraphs under "Metal rendering gotchas"), `docs/release-3.4.0-todo.md`

- [ ] **Step 1: `BezelSettingsView`** (iOS and tvOS): a "Bezel" row to `TVBezelPickerView(offersSystemAutomatic: true)` bound to `externalDisplayBezel`; "Light the Room" bound through `TVBezelRoomLight`; "Game Bezels" bound to `externalDisplayGameBezels`; a link to The Bezel Project browser where `ExternalDisplayOptionsView` already offers it. Section footer: "Automatic shows a TV for consoles and computers in landscape, and none for handhelds."
- [ ] **Step 2: Settings row** titled "Bezels", subtitle "A TV or monitor around the game picture.", not wrapped in `#if os(iOS)`.
- [ ] **Step 3: Docs.** CLAUDE.md: Automatic and `resolve`; `GameplayBezelPlacement`; the full-bounds GPU view under the generated controls and `localBezelPictureFrame()`; the preview choice; the scene cache and the pending processor; `TVFrameFailure`. Release todo: the by-hand checks below, and any pointer-mapping gap Task 4 listed.
- [ ] **Step 4: Full PVUI unit tests** (the command above with `test`). Expected: no new failures against develop.
- [ ] **Step 5: By-hand checks to record as owed, not to block on:** button and tube overlap on iPhone and iPad simulators in landscape; Apple TV focus in the strip; fifteen minutes of touch play in a TV on the oldest supported iPhone; twenty launches on the A12Z iPad Pro with Automatic and a filter selected, watching `idevicesyslog` for a GPU hang.
- [ ] **Step 6: Commit** `feat(settings): a Bezels page, and docs for TVs on by default`.

---

## Order and shipping

Tasks 1 to 4 turn TVs on by default; 5 to 7 are the switcher; 8 and 9 are safety and Settings. Per the spec, Task 8 lands before a TestFlight build that contains Task 4. Tasks 5 and 8 depend on nothing after Task 3 and can be done early.
