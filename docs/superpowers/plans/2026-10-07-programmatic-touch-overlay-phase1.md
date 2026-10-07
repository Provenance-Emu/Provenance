# Programmatic Touch Overlay — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `PVTouchOverlay` package (layout model, engine, templates for the Phase 1 families, procedural art, shared touch primitives, layout store, live editor) and mount it in PVUIBase as the default on-screen controller behind an Advanced toggle, so iOS players get a console-authentic, editable, subtype-aware overlay without touching imported Delta/Manic skins.

**Architecture:** A new Tier-4 Swift package holds a pure, Codable layout model (`OverlayTemplate` → `OverlayLayout` via `OverlayLayoutEngine`), per-family templates with per-system bindings, UIKit touch primitives that emit skin-vocabulary string tokens, and a SwiftUI host that draws procedural art. PVUIBase adapts those tokens to the existing `DeltaSkinInputHandler` (which already dispatches skin tokens to every `PV*SystemResponderClient`), publishes the game viewport through the existing `ViewportLayoutProviderBridge`, and resolves the controller subtype from the existing `ControllerLayoutVariant` machinery. Phase 1 replaces only the no-packaged-skin branch; the classic UIKit controller stays alive but hidden until Phase 2.

**Tech Stack:** Swift 6 language mode `.v5`/`.v6` (match sibling packages), SwiftUI + UIKit (iOS 17 / tvOS 17 floors, tvOS compiles but renders nothing), Swift Testing for the new package's tests, `Defaults` (sindresorhus) for settings, existing `PVCoreBridge` button enums and responder protocols.

**Spec:** `docs/superpowers/specs/2026-10-07-programmatic-touch-overlay-design.md`

## Global Constraints

- Minimum targets: iOS 17+, tvOS 17+; packages also declare macOS 14+, macCatalyst 17+, visionOS 1+, watchOS 9+ (copy the `platforms:` block from `PVShaders/Package.swift` verbatim). No availability guards for anything available since iOS 17.
- Every UIKit-dependent file is wrapped in `#if canImport(UIKit)`; the `Model/`, `Layout/`, `Families/`, `Store/` directories must compile without UIKit (they import only `Foundation`, `CoreGraphics`, `PVPrimitives`, `PVCoreBridge`).
- Never compare system identifiers as raw strings; use `SystemIdentifier` from `PVPrimitives` (`import PVPrimitives`).
- Notification names: one `public extension Notification.Name` constant per name in `PVCoreBridge`; posters and observers both use the constant.
- Input tokens are the skin vocabulary that `DeltaSkinInputHandler.buttonPressed(_:)` already accepts (`"a"`, `"b"`, `"up"`, `"l1"`, `"start"`, `"leftThumbstick"`, …). Never introduce integer button ids in the overlay.
- Conventional commits, subject < 72 chars, body ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Agents in `isolation: worktree`: DO NOT `git reset` / `rebase` / `push` / touch `develop`. Use `/usr/bin/git` (the rtk shell hook refuses `git` in worktrees).
- PVUI cannot build inside a git worktree (PackageBuildInfo plugin needs `.git/HEAD`). Run PVUI tests from a synced copy: rsync the worktree to the scratchpad excluding `.git`, write `.git/HEAD` containing `ref: refs/heads/develop`, symlink every empty `.gitmodules` path to the main checkout's copy, copy `PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite.zip`, and pass `-xcconfig realm.xcconfig` with `OTHER_CFLAGS = $(inherited) -Wno-invalid-specialization` and `OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-invalid-specialization`. The new `PVTouchOverlay` package has no plugin and builds in place.
- `swiftlint lint <path>` (this swiftlint has no `--path`). Only new lines must be clean in pre-existing large files.
- Test command for the new package (run from `PVTouchOverlay/`):
  `xcodebuild test -scheme PVTouchOverlay -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation`
- Test command for PVUI (from the synced copy's `PVUI/`):
  `xcodebuild test -scheme PVUI-UnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -xcconfig ../realm.xcconfig CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation`

## File Structure

```
PVTouchOverlay/
  Package.swift
  Sources/PVTouchOverlay/
    Model/
      OverlayPadKind.swift          OverlayPadKind, OverlayInputID, OverlayOrientation
      OverlayControl.swift          OverlayControlKind, OverlayControl, OverlayShape, OverlayPaletteSlot, OverlaySurfaceRole, OverlayAction, OverlayStickSide
      OverlayGroup.swift            OverlayGroup, OverlayPlacement
      OverlayTemplate.swift         OverlayTemplate, OverlayScreenPolicy
      OverlayLayout.swift           OverlayCanvas, OverlayInsets, ResolvedControl, ResolvedGroup, OverlayLayout
      OverlayOverrides.swift        AnchoredCenter, ControlOverride, GroupOverride, OverlayLayoutOverrides
    Layout/
      OverlayLayoutEngine.swift     resolve(template:canvas:overrides:gameAspect:)
      OverlayScreenPlanner.swift    screenFrames(policy:canvas:groups:gameAspect:)
    Families/
      OverlayFamily.swift           OverlayFamily protocol, OverlayFamilySlot, OverlayFamilyRegistry
      Family+FourFace.swift … one file per family
    Bindings/
      SystemOverlayBinding.swift    SystemOverlayBinding, OverlayPalette, SystemOverlayBindings registry
    Store/
      OverlayLayoutStore.swift      OverlayLayoutStore (@MainActor), OverlayLayoutFile (Codable schema)
      OverlayEditSession.swift      undo/redo snapshots
    Touch/                          #if canImport(UIKit)
      OverlayHitTester.swift        pure hit testing + d-pad octants (no UIKit, lives here for cohesion)
      OverlayTouchCluster.swift     MultiTouchCluster UIView
      OverlaySingleTouchSurface.swift
    Render/                         #if canImport(UIKit)
      OverlayPressLook.swift        press look constants (OverlayStyle itself lives in PVSettings)
      OverlayArt.swift              shape views
      OverlayGroupView.swift        per-group view with PressedSet
      OverlayHostView.swift         root SwiftUI view, OverlayInputSink protocol, OverlayHaptics
      OverlayEditorView.swift       edit-mode chrome, gestures, inspector, toolbar
  Tests/PVTouchOverlayTests/        one test file per source file above

PVCoreBridge/Sources/PVCoreBridge/Features/ControllerLayoutVariant.swift   (modify: read-back + notification)
PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+LayoutVariant.swift (new, MUST be added to PVCoreBridgeRetro.xcodeproj)
Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore.swift                      (modify: read-back)
PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift        (modify: keys)
PVSettings/Sources/PVSettings/Settings/Model/OverlayStyle.swift            (new: OverlayStyle enum, Defaults.Serializable)
PVUI/Package.swift                                                          (modify: dependency)
PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/
  ProgrammaticOverlayView.swift      mounts OverlayHostView, viewport bridge, DS dual-screen
  OverlayInputSinkAdapter.swift      OverlayInputSink → DeltaSkinInputHandler
  OverlayPadKindResolver.swift       subtype resolution
PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/Display/EmulatorWithSkinView.swift (modify: else-branch)
PVUI/Sources/PVUIBase/Controller/PVEmulatorViewController+DeltaSkin.swift         (modify: isDeltaSkinEnabled)
PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+MetalDualScreen.swift (modify: explicit-rects entry)
PVUI/Sources/PVSwiftUI/Settings/Views/AdvancedTogglesView.swift                   (modify: toggle row)
PVUI/Sources/PVUIBase/PVEmulatorVC/PauseTileMenuViewModel.swift                   (modify: layout tile)
```

---

### Task 0: Amend the spec for token ids and variant reuse

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-programmatic-touch-overlay-design.md`

The codebase already has two things the spec re-invented: every `PV*Button` enum has `init(_ value: String)` / `stringValue`, and `DeltaSkinInputHandler.buttonPressed(_ buttonId: String)` dispatches skin tokens to every system; and `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerLayoutVariant.swift` already defines `ControllerLayoutVariant` ids (`genesis-3btn`, `wii-classic`, …), `SystemIdentifier.availableControllerLayoutVariants`, the `ConsoleVariantConfigurable` protocol, and a Settings picker persisted in `Defaults[.controllerLayoutVariantsBySystem]`.

- [ ] **Step 1: Edit §3** — replace the `OverlayInputID` definition with:

```swift
public struct OverlayInputID: Hashable, Codable, Sendable {
    public let system: SystemIdentifier
    public let token: String      // skin vocabulary: "a", "b", "up", "l1", "start", "leftThumbstick", …
}
```
and add the sentence: "Tokens are the Delta/Manic skin vocabulary already understood by `DeltaSkinInputHandler`, so bindings are shareable with skins and the Phase 1 sink is a thin adapter."

- [ ] **Step 2: Edit §4.3** — replace the `ControllerSubtypeProvider` block with: "`OverlayPadKind.subtype` is a `ControllerLayoutVariant.id` (or `standard`). `ConsoleVariantConfigurable` gains a read-back `currentControllerLayoutVariantID` and a `Notification.Name.controllerLayoutVariantDidChange`; the thin wrapper and Dolphin implement both. The existing Settings picker remains the system-wide override; the pause menu gets a per-game override that also calls `applyControllerLayoutVariant`."

- [ ] **Step 3: Commit**

```bash
/usr/bin/git add docs/superpowers/specs/2026-10-07-programmatic-touch-overlay-design.md
/usr/bin/git commit -m "docs(spec): overlay ids are skin tokens; subtypes reuse ControllerLayoutVariant"
```

---

### Task 1: Package scaffold and core model types

**Files:**
- Create: `PVTouchOverlay/Package.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayPadKind.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayControl.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayGroup.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayTemplate.swift`
- Test: `PVTouchOverlay/Tests/PVTouchOverlayTests/OverlayModelTests.swift`
- Modify: `PVUI/Package.swift` (add `.package(path: "../PVTouchOverlay")` to `dependencies` and `"PVTouchOverlay"` to the `PVUIBase` target `dependencies`)

**Interfaces:**
- Produces: every type below, used by all later tasks.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVTouchOverlay",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVTouchOverlay", targets: ["PVTouchOverlay"])
    ],
    dependencies: [
        .package(path: "../PVPrimitives"),
        .package(path: "../PVCoreBridge"),
        .package(path: "../PVLogging"),
        .package(path: "../PVSettings"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.2")
    ],
    targets: [
        .target(
            name: "PVTouchOverlay",
            dependencies: [
                .product(name: "PVPrimitives", package: "PVPrimitives"),
                "PVCoreBridge",
                "PVLogging",
                "PVSettings",
                "Defaults"
            ]
        ),
        .testTarget(
            name: "PVTouchOverlayTests",
            dependencies: ["PVTouchOverlay"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
```

- [ ] **Step 2: Write the failing model test**

```swift
// Tests/PVTouchOverlayTests/OverlayModelTests.swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("Overlay model")
struct OverlayModelTests {
    @Test("Pad kind storage key is system.subtype.orientation")
    func padKindKey() {
        let kind = OverlayPadKind(system: .Genesis, subtype: "genesis-6btn")
        #expect(kind.storageKey(for: .landscape) == "com.provenance.genesis.genesis-6btn.landscape")
    }

    @Test("Standard pad kind uses the standard subtype")
    func standardKind() {
        #expect(OverlayPadKind.standard(.SNES).subtype == OverlayPadKind.standardSubtype)
    }

    @Test("Template round-trips through JSON")
    func templateCodable() throws {
        let a = OverlayInputID(system: .SNES, token: "a")
        let control = OverlayControl(id: "a", kind: .button(a), frame: CGRect(x: 0, y: 0, width: 56, height: 56),
                                     label: "A", shape: .circle, paletteSlot: .primary)
        let group = OverlayGroup(id: "face", controls: [control],
                                 placement: OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: 24, y: 40)))
        let template = OverlayTemplate(padKind: .standard(.SNES), orientation: .portrait, groups: [group], screenPolicy: .topBand)
        let data = try JSONEncoder().encode(template)
        let back = try JSONDecoder().decode(OverlayTemplate.self, from: data)
        #expect(back == template)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run (from `PVTouchOverlay/`): `xcodebuild test -scheme PVTouchOverlay -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation`
Expected: FAIL, "cannot find 'OverlayPadKind' in scope".

- [ ] **Step 4: Write the model**

```swift
// Model/OverlayPadKind.swift
import Foundation
import PVPrimitives

public enum OverlayOrientation: String, Codable, Sendable, Hashable, CaseIterable {
    case portrait, landscape
}

/// A controller subtype for a system. `subtype` is a `ControllerLayoutVariant.id`
/// (e.g. "genesis-6btn", "wii-classic") or `standardSubtype`.
public struct OverlayPadKind: Hashable, Codable, Sendable {
    public static let standardSubtype = "standard"
    public let system: SystemIdentifier
    public let subtype: String

    public init(system: SystemIdentifier, subtype: String) {
        self.system = system
        self.subtype = subtype
    }

    public static func standard(_ system: SystemIdentifier) -> OverlayPadKind {
        OverlayPadKind(system: system, subtype: standardSubtype)
    }

    public func storageKey(for orientation: OverlayOrientation) -> String {
        "\(system.rawValue).\(subtype).\(orientation.rawValue)"
    }
}

/// A skin-vocabulary input token tagged with its system so templates cannot
/// press one system's button on another system's core.
public struct OverlayInputID: Hashable, Codable, Sendable {
    public let system: SystemIdentifier
    public let token: String
    public init(system: SystemIdentifier, token: String) {
        self.system = system
        self.token = token
    }
}
```

```swift
// Model/OverlayControl.swift
import Foundation
import CoreGraphics

public enum OverlaySurfaceRole: String, Codable, Sendable, Hashable { case dsScreen, wiiPointer, lightGun, trackpad }
public enum OverlayAction: String, Codable, Sendable, Hashable {
    case menu, quickSave, quickLoad, fastForward, toggleKeyboard, toggleMouse, screenshot
}
public enum OverlayStickSide: String, Codable, Sendable, Hashable {
    case left, right
    /// Token understood by `DeltaSkinInputHandler.analogStickMoved(_:x:y:)`.
    public var token: String { self == .left ? "leftThumbstick" : "rightThumbstick" }
}

public enum OverlayControlKind: Hashable, Codable, Sendable {
    case button(OverlayInputID)
    case dpad(up: OverlayInputID, down: OverlayInputID, left: OverlayInputID, right: OverlayInputID)
    case stick(OverlayStickSide, click: OverlayInputID?)
    case analogTrigger(OverlayInputID)
    case touchSurface(OverlaySurfaceRole)
    case hardwareSwitch(descriptorID: String)
    case action(OverlayAction)
}

public enum OverlayShape: String, Codable, Sendable, Hashable {
    case circle, kidney, pill, bar, cross, ring, knob, key, surface
}

public enum OverlayPaletteSlot: String, Codable, Sendable, Hashable {
    case shell, primary, secondary, tertiary, quaternary, utility, dpad, stick, label
}

public struct OverlayControl: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var kind: OverlayControlKind
    /// Group-local points at reference scale (390pt-wide phone).
    public var frame: CGRect
    public var label: String?
    public var shape: OverlayShape
    public var paletteSlot: OverlayPaletteSlot

    public init(id: String, kind: OverlayControlKind, frame: CGRect, label: String? = nil,
                shape: OverlayShape, paletteSlot: OverlayPaletteSlot) {
        self.id = id; self.kind = kind; self.frame = frame
        self.label = label; self.shape = shape; self.paletteSlot = paletteSlot
    }
}
```

```swift
// Model/OverlayGroup.swift
import Foundation
import CoreGraphics

public struct OverlayPlacement: Hashable, Codable, Sendable {
    public enum Anchor: String, Codable, Sendable, Hashable {
        case bottomLeading, bottomTrailing, bottomCenter
        case topLeading, topTrailing, topCenter
        case centerLeading, centerTrailing, center
        case fill, fillInset
    }
    public var anchor: Anchor
    /// Distance from the anchored edges in points. For center anchors the matching component is ignored.
    public var inset: CGPoint
    public init(anchor: Anchor, inset: CGPoint = .zero) { self.anchor = anchor; self.inset = inset }
}

public struct OverlayGroup: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var controls: [OverlayControl]
    public var placement: OverlayPlacement
    public var scale: CGFloat
    public var opacity: CGFloat

    public init(id: String, controls: [OverlayControl], placement: OverlayPlacement,
                scale: CGFloat = 1, opacity: CGFloat = 1) {
        self.id = id; self.controls = controls; self.placement = placement
        self.scale = scale; self.opacity = opacity
    }

    /// Union of control frames at reference scale, origin-normalised to (0,0).
    public var naturalSize: CGSize {
        let union = controls.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        return union.isNull ? .zero : CGSize(width: union.maxX, height: union.maxY)
    }
}
```

```swift
// Model/OverlayTemplate.swift
import Foundation

public enum OverlayScreenPolicy: String, Codable, Sendable, Hashable {
    case topBand, centerColumn, dualStacked, fill
}

public struct OverlayTemplate: Hashable, Codable, Sendable {
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation
    public let groups: [OverlayGroup]
    public let screenPolicy: OverlayScreenPolicy

    public init(padKind: OverlayPadKind, orientation: OverlayOrientation,
                groups: [OverlayGroup], screenPolicy: OverlayScreenPolicy) {
        self.padKind = padKind; self.orientation = orientation
        self.groups = groups; self.screenPolicy = screenPolicy
    }
}
```

- [ ] **Step 5: Run tests, expect PASS (3 tests)**

- [ ] **Step 6: Register the dependency in `PVUI/Package.swift`**: add `.package(path: "../PVTouchOverlay"),` after the `.package(path: "../PVThemes"),` line, and add `"PVTouchOverlay",` after `"PVThemes",` in the `PVUIBase` target's `dependencies`. Do not build PVUI yet (Task 14 does).

- [ ] **Step 7: Commit**

```bash
/usr/bin/git add PVTouchOverlay PVUI/Package.swift
/usr/bin/git commit -m "feat(overlay): PVTouchOverlay package with core layout model"
```

---

### Task 2: Overrides model and layout engine

**Files:**
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayLayout.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Model/OverlayOverrides.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Layout/OverlayLayoutEngine.swift`
- Test: `PVTouchOverlay/Tests/PVTouchOverlayTests/AnchoredCenterTests.swift`
- Test: `PVTouchOverlay/Tests/PVTouchOverlayTests/OverlayLayoutEngineTests.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces: `OverlayCanvas`, `OverlayInsets`, `AnchoredCenter`, `GroupOverride`, `ControlOverride`, `OverlayLayoutOverrides`, `ResolvedControl`, `ResolvedGroup`, `OverlayLayout`, `OverlayLayoutEngine.resolve(template:canvas:overrides:gameAspect:)`, `OverlayLayoutEngine.referenceScale(for:)`, `OverlayLayoutEngine.extendedEdges`.

- [ ] **Step 1: Failing tests**

```swift
// Tests/PVTouchOverlayTests/AnchoredCenterTests.swift
import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("AnchoredCenter")
struct AnchoredCenterTests {
    let canvas = OverlayCanvas(size: CGSize(width: 390, height: 844),
                               safeArea: OverlayInsets(top: 59, left: 0, bottom: 34, right: 0))

    @Test("Points in the outer thirds hang from the nearest edge")
    func outerThirds() {
        let c = AnchoredCenter.make(center: CGPoint(x: 60, y: 780), in: canvas)
        #expect(c.h == .min && c.x == 60)
        #expect(c.v == .max && c.y == 64)           // 844 - 780
        #expect(c.resolve(in: canvas) == CGPoint(x: 60, y: 780))
    }

    @Test("Points in the middle third anchor to the centre line")
    func middleThird() {
        let c = AnchoredCenter.make(center: CGPoint(x: 200, y: 400), in: canvas)
        #expect(c.h == .mid && c.x == 5)            // 200 - 195
        #expect(c.v == .mid && c.y == -22)          // 400 - 422
    }

    @Test("A stored centre survives a wider canvas")
    func survivesResize() {
        let c = AnchoredCenter.make(center: CGPoint(x: 330, y: 780), in: canvas)
        let wide = OverlayCanvas(size: CGSize(width: 430, height: 932), safeArea: canvas.safeArea)
        #expect(c.resolve(in: wide) == CGPoint(x: 370, y: 868))
    }
}
```

```swift
// Tests/PVTouchOverlayTests/OverlayLayoutEngineTests.swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("OverlayLayoutEngine")
struct OverlayLayoutEngineTests {
    static let phonePortrait = OverlayCanvas(size: CGSize(width: 390, height: 844),
                                             safeArea: OverlayInsets(top: 59, left: 0, bottom: 34, right: 0))
    static let phoneLandscape = OverlayCanvas(size: CGSize(width: 844, height: 390),
                                              safeArea: OverlayInsets(top: 0, left: 59, bottom: 21, right: 59))
    static let padLandscape = OverlayCanvas(size: CGSize(width: 1180, height: 820),
                                            safeArea: OverlayInsets(top: 24, left: 0, bottom: 20, right: 0))

    func template(anchor: OverlayPlacement.Anchor, inset: CGPoint) -> OverlayTemplate {
        let a = OverlayInputID(system: .SNES, token: "a")
        let b = OverlayInputID(system: .SNES, token: "b")
        let g = OverlayGroup(id: "face", controls: [
            OverlayControl(id: "a", kind: .button(a), frame: CGRect(x: 60, y: 0, width: 56, height: 56), shape: .circle, paletteSlot: .primary),
            OverlayControl(id: "b", kind: .button(b), frame: CGRect(x: 0, y: 60, width: 56, height: 56), shape: .circle, paletteSlot: .secondary)
        ], placement: OverlayPlacement(anchor: anchor, inset: inset))
        return OverlayTemplate(padKind: .standard(.SNES), orientation: .portrait, groups: [g], screenPolicy: .topBand)
    }

    @Test("Reference scale is 1 on a 390pt phone and clamps at 1.35")
    func referenceScale() {
        #expect(OverlayLayoutEngine.referenceScale(for: Self.phonePortrait) == 1)
        #expect(OverlayLayoutEngine.referenceScale(for: Self.padLandscape) == 1.35)
    }

    @Test("Bottom-trailing group sits inset from the safe bottom-right corner")
    func bottomTrailing() {
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: CGPoint(x: 24, y: 40)),
                                                 canvas: Self.phonePortrait, overrides: .empty, gameAspect: 4.0 / 3.0)
        let g = try! #require(layout.groups.first)
        #expect(g.frame.maxX == 390 - 24)
        #expect(g.frame.maxY == 844 - 34 - 40)
        #expect(g.frame.size == CGSize(width: 116, height: 116))
    }

    @Test("Group scale enlarges around the centre and clamps inside the safe area")
    func scaleClamps() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: CGSize(width: 2, height: 2), opacity: nil, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: CGPoint(x: 24, y: 40)),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4.0 / 3.0)
        let g = layout.groups[0]
        #expect(g.frame.size == CGSize(width: 232, height: 232))
        #expect(g.frame.maxX <= 390)
        #expect(g.frame.maxY <= 844 - 34)
    }

    @Test("A stored centre overrides the template placement")
    func storedCenter() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: AnchoredCenter(h: .min, x: 100, v: .min, y: 300),
                                                 scale: nil, opacity: nil, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4.0 / 3.0)
        #expect(layout.groups[0].frame.midX == 100)
        #expect(layout.groups[0].frame.midY == 300)
    }

    @Test("Per-control offsets move one button and hit frames are outset")
    func controlOffsetAndHitFrame() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: nil, opacity: nil,
                                                 buttons: ["a": ControlOverride(offset: CGPoint(x: 10, y: -10), scale: 1)])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4.0 / 3.0)
        let g = layout.groups[0]
        let a = g.controls.first { $0.control.id == "a" }!
        let b = g.controls.first { $0.control.id == "b" }!
        #expect(a.frame.minX == g.frame.minX + 60 + 10)
        #expect(a.frame.minY == g.frame.minY - 10)
        #expect(b.hitFrame == b.frame.insetBy(dx: -OverlayLayoutEngine.extendedEdges, dy: -OverlayLayoutEngine.extendedEdges))
    }

    @Test("Opacity override multiplies the group opacity")
    func opacity() {
        var overrides = OverlayLayoutOverrides.empty
        overrides.groups["face"] = GroupOverride(center: nil, scale: nil, opacity: 0.5, buttons: [:])
        let layout = OverlayLayoutEngine.resolve(template: template(anchor: .bottomTrailing, inset: .zero),
                                                 canvas: Self.phonePortrait, overrides: overrides, gameAspect: 4.0 / 3.0)
        #expect(layout.groups[0].opacity == 0.5)
    }
}
```

- [ ] **Step 2: Run, expect FAIL (types missing)**

- [ ] **Step 3: Implement**

```swift
// Model/OverlayLayout.swift
import Foundation
import CoreGraphics

/// UIKit-free safe-area insets.
public struct OverlayInsets: Hashable, Codable, Sendable {
    public var top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
    public static let zero = OverlayInsets(top: 0, left: 0, bottom: 0, right: 0)
}

/// The full-screen drawing area: window bounds plus the safe-area insets inside it.
public struct OverlayCanvas: Hashable, Sendable {
    public var size: CGSize
    public var safeArea: OverlayInsets
    public init(size: CGSize, safeArea: OverlayInsets) { self.size = size; self.safeArea = safeArea }
    public var bounds: CGRect { CGRect(origin: .zero, size: size) }
    public var safeRect: CGRect {
        CGRect(x: safeArea.left, y: safeArea.top,
               width: max(0, size.width - safeArea.left - safeArea.right),
               height: max(0, size.height - safeArea.top - safeArea.bottom))
    }
    public var orientation: OverlayOrientation { size.height >= size.width ? .portrait : .landscape }
}

public struct ResolvedControl: Hashable, Sendable, Identifiable {
    public var id: String { control.id }
    public let control: OverlayControl
    /// Absolute draw frame in canvas points.
    public let frame: CGRect
    /// Absolute hit frame (draw frame outset by extended edges).
    public let hitFrame: CGRect
}

public struct ResolvedGroup: Hashable, Sendable, Identifiable {
    public var id: String { group.id }
    public let group: OverlayGroup
    public let frame: CGRect
    public let controls: [ResolvedControl]
    public let scale: CGSize
    public let opacity: CGFloat
}

public struct OverlayLayout: Hashable, Sendable {
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation
    public let groups: [ResolvedGroup]
    /// One rect, or two for `.dualStacked` (top screen first).
    public let screenFrames: [CGRect]
}
```

```swift
// Model/OverlayOverrides.swift
import Foundation
import CoreGraphics

/// A centre point stored relative to the nearest canvas edge (or the centre line
/// when the point lies in the middle third), so it survives device changes.
public struct AnchoredCenter: Hashable, Codable, Sendable {
    public enum Edge: String, Codable, Sendable { case min, mid, max }
    public var h: Edge
    public var x: CGFloat
    public var v: Edge
    public var y: CGFloat

    public init(h: Edge, x: CGFloat, v: Edge, y: CGFloat) { self.h = h; self.x = x; self.v = v; self.y = y }

    public static func make(center: CGPoint, in canvas: OverlayCanvas) -> AnchoredCenter {
        func anchor(_ value: CGFloat, length: CGFloat) -> (Edge, CGFloat) {
            let third = length / 3
            if value < third { return (.min, value) }
            if value > 2 * third { return (.max, length - value) }
            return (.mid, value - length / 2)
        }
        let (h, x) = anchor(center.x, length: canvas.size.width)
        let (v, y) = anchor(center.y, length: canvas.size.height)
        return AnchoredCenter(h: h, x: x, v: v, y: y)
    }

    public func resolve(in canvas: OverlayCanvas) -> CGPoint {
        func value(_ edge: Edge, _ distance: CGFloat, length: CGFloat) -> CGFloat {
            switch edge {
            case .min: return distance
            case .max: return length - distance
            case .mid: return length / 2 + distance
            }
        }
        return CGPoint(x: value(h, x, length: canvas.size.width), y: value(v, y, length: canvas.size.height))
    }
}

public struct ControlOverride: Hashable, Codable, Sendable {
    public var offset: CGPoint
    public var scale: CGFloat
    public init(offset: CGPoint = .zero, scale: CGFloat = 1) { self.offset = offset; self.scale = scale }
}

public struct GroupOverride: Hashable, Codable, Sendable {
    public var center: AnchoredCenter?
    public var scale: CGSize?
    public var opacity: CGFloat?
    public var buttons: [String: ControlOverride]
    public init(center: AnchoredCenter?, scale: CGSize?, opacity: CGFloat?, buttons: [String: ControlOverride]) {
        self.center = center; self.scale = scale; self.opacity = opacity; self.buttons = buttons
    }
    public static let empty = GroupOverride(center: nil, scale: nil, opacity: nil, buttons: [:])
}

public struct OverlayLayoutOverrides: Hashable, Codable, Sendable {
    public var groups: [String: GroupOverride]
    public init(groups: [String: GroupOverride] = [:]) { self.groups = groups }
    public static let empty = OverlayLayoutOverrides()
}
```

```swift
// Layout/OverlayLayoutEngine.swift
import Foundation
import CoreGraphics

public enum OverlayLayoutEngine {
    /// Reference phone width the templates are authored against.
    public static let referenceWidth: CGFloat = 390
    public static let maxReferenceScale: CGFloat = 1.35
    /// Default outset applied to every control's hit frame (points at scale 1).
    public static let extendedEdges: CGFloat = 20
    public static let scaleRange: ClosedRange<CGFloat> = 0.5...2.0

    public static func referenceScale(for canvas: OverlayCanvas) -> CGFloat {
        min(max(min(canvas.size.width, canvas.size.height) / referenceWidth, 1), maxReferenceScale)
    }

    public static func resolve(template: OverlayTemplate,
                               canvas: OverlayCanvas,
                               overrides: OverlayLayoutOverrides,
                               gameAspect: CGFloat) -> OverlayLayout {
        let u = referenceScale(for: canvas)
        let groups = template.groups.map { group -> ResolvedGroup in
            let override = overrides.groups[group.id] ?? .empty
            let scale = clampedScale(override.scale ?? CGSize(width: group.scale, height: group.scale))
            let natural = group.naturalSize
            let size = CGSize(width: natural.width * u * scale.width, height: natural.height * u * scale.height)

            var center = override.center?.resolve(in: canvas)
                ?? placementCenter(group.placement, size: size, canvas: canvas)
            center = clampCenter(center, size: size, within: canvas.safeRect)
            let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)

            let controls = group.controls.map { control -> ResolvedControl in
                let co = override.buttons[control.id] ?? ControlOverride()
                let w = control.frame.width * u * scale.width * co.scale
                let h = control.frame.height * u * scale.height * co.scale
                let cx = origin.x + (control.frame.midX * u * scale.width) + co.offset.x
                let cy = origin.y + (control.frame.midY * u * scale.height) + co.offset.y
                let frame = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
                return ResolvedControl(control: control, frame: frame,
                                       hitFrame: frame.insetBy(dx: -extendedEdges * u, dy: -extendedEdges * u))
            }
            return ResolvedGroup(group: group, frame: CGRect(origin: origin, size: size), controls: controls,
                                 scale: scale, opacity: group.opacity * (override.opacity ?? 1))
        }
        let screens = OverlayScreenPlanner.screenFrames(policy: template.screenPolicy, canvas: canvas,
                                                        groups: groups, gameAspect: gameAspect)
        return OverlayLayout(padKind: template.padKind, orientation: template.orientation,
                             groups: groups, screenFrames: screens)
    }

    static func clampedScale(_ s: CGSize) -> CGSize {
        CGSize(width: min(max(s.width, scaleRange.lowerBound), scaleRange.upperBound),
               height: min(max(s.height, scaleRange.lowerBound), scaleRange.upperBound))
    }

    static func placementCenter(_ p: OverlayPlacement, size: CGSize, canvas: OverlayCanvas) -> CGPoint {
        let r = canvas.safeRect
        let x: CGFloat
        let y: CGFloat
        switch p.anchor {
        case .bottomLeading, .topLeading, .centerLeading: x = r.minX + p.inset.x + size.width / 2
        case .bottomTrailing, .topTrailing, .centerTrailing: x = r.maxX - p.inset.x - size.width / 2
        case .bottomCenter, .topCenter, .center, .fill, .fillInset: x = r.midX
        }
        switch p.anchor {
        case .bottomLeading, .bottomTrailing, .bottomCenter: y = r.maxY - p.inset.y - size.height / 2
        case .topLeading, .topTrailing, .topCenter: y = r.minY + p.inset.y + size.height / 2
        case .centerLeading, .centerTrailing, .center, .fill, .fillInset: y = r.midY
        }
        return CGPoint(x: x, y: y)
    }

    static func clampCenter(_ c: CGPoint, size: CGSize, within r: CGRect) -> CGPoint {
        // When the group is larger than the safe rect, centre it rather than pinning a corner.
        let x = size.width >= r.width ? r.midX : min(max(c.x, r.minX + size.width / 2), r.maxX - size.width / 2)
        let y = size.height >= r.height ? r.midY : min(max(c.y, r.minY + size.height / 2), r.maxY - size.height / 2)
        return CGPoint(x: x, y: y)
    }
}
```

`OverlayScreenPlanner` is Task 3; for this task add a temporary stub returning `[]` in `Layout/OverlayScreenPlanner.swift` so the engine compiles, then replace it in Task 3.

- [ ] **Step 4: Run tests, expect PASS (3 + 6 new, 3 from Task 1)**

- [ ] **Step 5: swiftlint the new files, then commit**

```bash
/usr/bin/git add PVTouchOverlay
/usr/bin/git commit -m "feat(overlay): layout engine with edge-anchored overrides"
```

---

### Task 3: Screen planner

**Files:**
- Modify: `PVTouchOverlay/Sources/PVTouchOverlay/Layout/OverlayScreenPlanner.swift` (replace stub)
- Test: `PVTouchOverlay/Tests/PVTouchOverlayTests/OverlayScreenPlannerTests.swift`

**Interfaces:**
- Produces: `OverlayScreenPlanner.screenFrames(policy:canvas:groups:gameAspect:) -> [CGRect]`, `OverlayScreenPlanner.dsAspect`.

- [ ] **Step 1: Failing tests**

```swift
import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayScreenPlanner")
struct OverlayScreenPlannerTests {
    let portrait = OverlayLayoutEngineTests.phonePortrait
    let landscape = OverlayLayoutEngineTests.phoneLandscape

    func group(_ id: String, _ frame: CGRect) -> ResolvedGroup {
        let g = OverlayGroup(id: id, controls: [], placement: OverlayPlacement(anchor: .bottomLeading))
        return ResolvedGroup(group: g, frame: frame, controls: [], scale: CGSize(width: 1, height: 1), opacity: 1)
    }

    @Test("topBand fits the picture above the highest control, aspect-fit, centred")
    func topBand() {
        let groups = [group("dpad", CGRect(x: 0, y: 600, width: 150, height: 150))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .topBand, canvas: portrait, groups: groups, gameAspect: 4.0 / 3.0)
        let f = frames[0]
        #expect(frames.count == 1)
        #expect(f.minY >= 59)
        #expect(f.maxY <= 600 - OverlayScreenPlanner.gap)
        #expect(abs(f.width / f.height - 4.0 / 3.0) < 0.001)
        #expect(abs(f.midX - 195) < 0.5)
    }

    @Test("centerColumn fits between the left and right clusters")
    func centerColumn() {
        let groups = [group("dpad", CGRect(x: 59, y: 100, width: 160, height: 160)),
                      group("face", CGRect(x: 844 - 59 - 160, y: 100, width: 160, height: 160))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .centerColumn, canvas: landscape, groups: groups, gameAspect: 4.0 / 3.0)
        let f = frames[0]
        #expect(f.minX >= 59 + 160 + OverlayScreenPlanner.gap)
        #expect(f.maxX <= 844 - 59 - 160 - OverlayScreenPlanner.gap)
        #expect(f.maxY <= 390 - 21)
    }

    @Test("dualStacked yields two 4:3 screens, top first, inside the top band")
    func dualStacked() {
        let groups = [group("face", CGRect(x: 0, y: 650, width: 150, height: 150))]
        let frames = OverlayScreenPlanner.screenFrames(policy: .dualStacked, canvas: portrait, groups: groups, gameAspect: OverlayScreenPlanner.dsAspect)
        #expect(frames.count == 2)
        #expect(frames[0].maxY <= frames[1].minY)
        #expect(frames[1].maxY <= 650 - OverlayScreenPlanner.gap)
        #expect(abs(frames[0].width / frames[0].height - 4.0 / 3.0) < 0.001)
        #expect(frames[0].size == frames[1].size)
    }

    @Test("fill uses the whole safe rect")
    func fill() {
        let frames = OverlayScreenPlanner.screenFrames(policy: .fill, canvas: landscape, groups: [], gameAspect: 16.0 / 9.0)
        #expect(frames == [landscape.safeRect])
    }
}
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

```swift
// Layout/OverlayScreenPlanner.swift
import Foundation
import CoreGraphics

public enum OverlayScreenPlanner {
    /// Gap between the picture and the nearest control group.
    public static let gap: CGFloat = 8
    /// Each DS screen is 256x192.
    public static let dsAspect: CGFloat = 4.0 / 3.0

    public static func screenFrames(policy: OverlayScreenPolicy, canvas: OverlayCanvas,
                                    groups: [ResolvedGroup], gameAspect: CGFloat) -> [CGRect] {
        let safe = canvas.safeRect
        let aspect = gameAspect > 0 ? gameAspect : 4.0 / 3.0
        switch policy {
        case .fill:
            return [safe]
        case .topBand:
            let band = topBand(safe: safe, groups: groups)
            return [aspectFit(aspect, in: band)]
        case .centerColumn:
            let column = centerColumn(safe: safe, groups: groups)
            return [aspectFit(aspect, in: column)]
        case .dualStacked:
            let band = topBand(safe: safe, groups: groups)
            let half = CGRect(x: band.minX, y: band.minY, width: band.width, height: (band.height - gap) / 2)
            let top = aspectFit(dsAspect, in: half)
            let bottom = top.offsetBy(dx: 0, dy: top.height + gap)
            // Centre the pair vertically in the band.
            let pairHeight = bottom.maxY - top.minY
            let dy = (band.height - pairHeight) / 2
            return [top.offsetBy(dx: 0, dy: dy), bottom.offsetBy(dx: 0, dy: dy)]
        }
    }

    static func topBand(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let highest = groups.filter { !$0.group.controls.contains { if case .touchSurface = $0.kind { return true } else { return false } } }
            .map(\.frame.minY).min() ?? safe.maxY
        let bottom = max(safe.minY, min(safe.maxY, highest - gap))
        return CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: bottom - safe.minY)
    }

    static func centerColumn(safe: CGRect, groups: [ResolvedGroup]) -> CGRect {
        let mid = safe.midX
        let leftEdge = groups.filter { $0.frame.midX < mid }.map(\.frame.maxX).max() ?? safe.minX
        let rightEdge = groups.filter { $0.frame.midX >= mid }.map(\.frame.minX).min() ?? safe.maxX
        let minX = min(max(safe.minX, leftEdge + gap), safe.maxX)
        let maxX = max(minX, min(safe.maxX, rightEdge - gap))
        return CGRect(x: minX, y: safe.minY, width: maxX - minX, height: safe.height)
    }

    static func aspectFit(_ aspect: CGFloat, in rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return CGRect(origin: rect.origin, size: .zero) }
        var w = rect.width
        var h = w / aspect
        if h > rect.height { h = rect.height; w = h * aspect }
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
```

- [ ] **Step 4: Run tests, expect PASS**
- [ ] **Step 5: Commit** — `feat(overlay): screen planner for topBand/centerColumn/dualStacked/fill`


---

### Task 4: Family protocol, builder kit, and the pad families (twoButton, fourFace, threeFace, sixFace)

**Files:**
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/OverlayFamily.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/OverlayFamilyKit.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+TwoButton.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+FourFace.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+ThreeFace.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+SixFace.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Bindings/SystemOverlayBinding.swift` (model only; the registry table is Task 8)
- Test: `PVTouchOverlay/Tests/PVTouchOverlayTests/OverlayFamilyTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `struct OverlayFamilySlot: RawRepresentable<String>` with constants `.a .b .c .x .y .z .l .r .l2 .r2 .l3 .r3 .start .select .one .two .plus .minus .home .cUp .cDown .cLeft .cRight`.
  - `protocol OverlayFamily { static var id: String; static var requiredSlots: [OverlayFamilySlot]; static func template(binding:padKind:orientation:) -> OverlayTemplate }`.
  - `struct OverlayColor: Codable { r g b a }`, `struct OverlayPalette`, `struct SystemOverlayBinding` with `func inputID(_ slot:) -> OverlayInputID`, `func label(_ slot:) -> String`.
  - `enum OverlayFamilyKit` builders: `button`, `dpad`, `stick`, `shoulder`, `pillRow`.
  - Families `TwoButtonFamily`, `FourFaceFamily`, `ThreeFaceFamily`, `SixFaceFamily`.

- [ ] **Step 1: Failing tests**

```swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("Pad families")
struct OverlayFamilyTests {
    static let canvases: [OverlayCanvas] = [
        OverlayLayoutEngineTests.phonePortrait, OverlayLayoutEngineTests.phoneLandscape,
        OverlayLayoutEngineTests.padLandscape,
        OverlayCanvas(size: CGSize(width: 375, height: 667), safeArea: .zero)     // no notch
    ]

    static let snes = SystemOverlayBinding(
        system: .SNES, families: [OverlayPadKind.standardSubtype: FourFaceFamily.self],
        defaultSubtype: OverlayPadKind.standardSubtype,
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
        palette: .snes, hardwareSwitches: [])

    @Test("Every family resolves with all groups inside the canvas on every canvas",
          arguments: [TwoButtonFamily.id, FourFaceFamily.id, ThreeFaceFamily.id, SixFaceFamily.id])
    func groupsStayOnCanvas(familyID: String) throws {
        let family = try #require(OverlayFamilyRegistry.family(id: familyID))
        for canvas in Self.canvases {
            let template = family.template(binding: Self.snes, padKind: .standard(.SNES), orientation: canvas.orientation)
            let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0)
            for g in layout.groups {
                #expect(canvas.bounds.contains(g.frame), "\(familyID) \(g.id) off canvas on \(canvas.size)")
            }
            #expect(!layout.screenFrames.isEmpty)
            #expect(layout.screenFrames[0].width > 100)
        }
    }

    @Test("Face buttons never overlap each other")
    func noOverlap() {
        let template = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let layout = OverlayLayoutEngine.resolve(template: template, canvas: Self.canvases[0], overrides: .empty, gameAspect: 4.0 / 3.0)
        let face = layout.groups.first { $0.id == "face" }!
        for (i, a) in face.controls.enumerated() {
            for b in face.controls.dropFirst(i + 1) {
                #expect(!a.frame.intersects(b.frame), "\(a.id) overlaps \(b.id)")
            }
        }
    }

    @Test("Four-face template binds SNES tokens")
    func tokens() {
        let template = FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait)
        let ids = template.groups.flatMap(\.controls).compactMap { c -> String? in
            if case .button(let id) = c.kind { return id.token } else { return nil }
        }
        #expect(Set(ids).isSuperset(of: ["a", "b", "x", "y", "l", "r", "start", "select"]))
    }

    @Test("Portrait uses topBand and landscape uses centerColumn")
    func policies() {
        #expect(FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .portrait).screenPolicy == .topBand)
        #expect(FourFaceFamily.template(binding: Self.snes, padKind: .standard(.SNES), orientation: .landscape).screenPolicy == .centerColumn)
    }
}
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement the protocol, binding model and kit**

```swift
// Families/OverlayFamily.swift
import Foundation

public struct OverlayFamilySlot: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let a = OverlayFamilySlot(rawValue: "a"), b = OverlayFamilySlot(rawValue: "b")
    public static let c = OverlayFamilySlot(rawValue: "c"), x = OverlayFamilySlot(rawValue: "x")
    public static let y = OverlayFamilySlot(rawValue: "y"), z = OverlayFamilySlot(rawValue: "z")
    public static let l = OverlayFamilySlot(rawValue: "l"), r = OverlayFamilySlot(rawValue: "r")
    public static let l2 = OverlayFamilySlot(rawValue: "l2"), r2 = OverlayFamilySlot(rawValue: "r2")
    public static let l3 = OverlayFamilySlot(rawValue: "l3"), r3 = OverlayFamilySlot(rawValue: "r3")
    public static let start = OverlayFamilySlot(rawValue: "start"), select = OverlayFamilySlot(rawValue: "select")
    public static let one = OverlayFamilySlot(rawValue: "one"), two = OverlayFamilySlot(rawValue: "two")
    public static let plus = OverlayFamilySlot(rawValue: "plus"), minus = OverlayFamilySlot(rawValue: "minus")
    public static let home = OverlayFamilySlot(rawValue: "home")
    public static let cUp = OverlayFamilySlot(rawValue: "cUp"), cDown = OverlayFamilySlot(rawValue: "cDown")
    public static let cLeft = OverlayFamilySlot(rawValue: "cLeft"), cRight = OverlayFamilySlot(rawValue: "cRight")
}

/// A controller shape. Systems bind to a family and supply tokens, labels and a palette.
public protocol OverlayFamily {
    static var id: String { get }
    /// Slots the binding must provide tokens for. D-pads and sticks use fixed tokens.
    static var requiredSlots: [OverlayFamilySlot] { get }
    static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate
}

public enum OverlayFamilyRegistry {
    public static let all: [any OverlayFamily.Type] = [
        TwoButtonFamily.self, FourFaceFamily.self, ThreeFaceFamily.self, SixFaceFamily.self
        // Later tasks append: N64Family, DigitalPadFamily, DualStickFamily, GameCubeFamily,
        // WiiRemoteFamily, WiiRemoteSidewaysFamily, WiiClassicFamily, DSPadFamily
    ]
    public static func family(id: String) -> (any OverlayFamily.Type)? { all.first { $0.id == id } }
}
```

```swift
// Bindings/SystemOverlayBinding.swift
import Foundation
import PVPrimitives

public struct OverlayColor: Hashable, Codable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static let white = OverlayColor(1, 1, 1), black = OverlayColor(0, 0, 0)
}

public struct OverlayPalette: Hashable, Codable, Sendable {
    public var shell: OverlayColor, primary: OverlayColor, secondary: OverlayColor, tertiary: OverlayColor
    public var quaternary: OverlayColor, utility: OverlayColor, dpad: OverlayColor, stick: OverlayColor, label: OverlayColor
    public init(shell: OverlayColor, primary: OverlayColor, secondary: OverlayColor, tertiary: OverlayColor,
                quaternary: OverlayColor, utility: OverlayColor, dpad: OverlayColor, stick: OverlayColor, label: OverlayColor) {
        self.shell = shell; self.primary = primary; self.secondary = secondary; self.tertiary = tertiary
        self.quaternary = quaternary; self.utility = utility; self.dpad = dpad; self.stick = stick; self.label = label
    }
    public func color(for slot: OverlayPaletteSlot) -> OverlayColor {
        switch slot {
        case .shell: return shell;         case .primary: return primary;     case .secondary: return secondary
        case .tertiary: return tertiary;   case .quaternary: return quaternary; case .utility: return utility
        case .dpad: return dpad;           case .stick: return stick;         case .label: return label
        }
    }
    /// Super Famicom / PAL SNES colours.
    public static let snes = OverlayPalette(
        shell: OverlayColor(0.80, 0.80, 0.84), primary: OverlayColor(0.86, 0.19, 0.22),  // A red
        secondary: OverlayColor(0.98, 0.78, 0.18),                                        // B yellow
        tertiary: OverlayColor(0.16, 0.40, 0.80),                                         // X blue
        quaternary: OverlayColor(0.18, 0.62, 0.30),                                       // Y green
        utility: OverlayColor(0.45, 0.45, 0.50), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
}

/// Which family each subtype of a system uses, plus the tokens and art for its slots.
public struct SystemOverlayBinding {
    public let system: SystemIdentifier
    public let families: [String: any OverlayFamily.Type]      // subtype -> family
    public let defaultSubtype: String
    public let tokens: [OverlayFamilySlot: String]
    public let labels: [OverlayFamilySlot: String]
    public let palette: OverlayPalette
    /// `HardwareSwitchDescriptor.id`s to show (Phase 2 families use these).
    public let hardwareSwitches: [String]

    public init(system: SystemIdentifier, families: [String: any OverlayFamily.Type], defaultSubtype: String,
                tokens: [OverlayFamilySlot: String], labels: [OverlayFamilySlot: String],
                palette: OverlayPalette, hardwareSwitches: [String]) {
        self.system = system; self.families = families; self.defaultSubtype = defaultSubtype
        self.tokens = tokens; self.labels = labels; self.palette = palette; self.hardwareSwitches = hardwareSwitches
    }

    public func inputID(_ slot: OverlayFamilySlot) -> OverlayInputID {
        OverlayInputID(system: system, token: tokens[slot] ?? slot.rawValue)
    }
    public func label(_ slot: OverlayFamilySlot) -> String { labels[slot] ?? slot.rawValue.uppercased() }

    public func family(for subtype: String) -> any OverlayFamily.Type {
        families[subtype] ?? families[defaultSubtype] ?? families.values.first!
    }

    public func template(padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        family(for: padKind.subtype).template(binding: self, padKind: padKind, orientation: orientation)
    }
}
```

```swift
// Families/OverlayFamilyKit.swift
import Foundation
import CoreGraphics

/// Shared building blocks so families stay short and consistent.
public enum OverlayFamilyKit {
    public static let faceButton: CGFloat = 56
    public static let smallButton: CGFloat = 44
    public static let dpadSize: CGFloat = 150
    public static let stickSize: CGFloat = 120
    public static let shoulderSize = CGSize(width: 90, height: 40)
    public static let pillSize = CGSize(width: 70, height: 30)
    public static let edge: CGFloat = 16
    /// Height of the lowest control band above the safe bottom in portrait.
    public static let portraitBottom: CGFloat = 60

    public static func button(_ slot: OverlayFamilySlot, binding: SystemOverlayBinding, at origin: CGPoint,
                              size: CGFloat = faceButton, shape: OverlayShape = .circle, palette: OverlayPaletteSlot) -> OverlayControl {
        OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                       frame: CGRect(origin: origin, size: CGSize(width: size, height: size)),
                       label: binding.label(slot), shape: shape, paletteSlot: palette)
    }

    public static func dpad(binding: SystemOverlayBinding, size: CGFloat = dpadSize) -> OverlayControl {
        let s = binding.system
        return OverlayControl(id: "dpad",
                              kind: .dpad(up: OverlayInputID(system: s, token: "up"), down: OverlayInputID(system: s, token: "down"),
                                          left: OverlayInputID(system: s, token: "left"), right: OverlayInputID(system: s, token: "right")),
                              frame: CGRect(x: 0, y: 0, width: size, height: size), shape: .cross, paletteSlot: .dpad)
    }

    public static func stick(_ side: OverlayStickSide, click: OverlayInputID? = nil, size: CGFloat = stickSize) -> OverlayControl {
        OverlayControl(id: side == .left ? "leftStick" : "rightStick", kind: .stick(side, click: click),
                       frame: CGRect(x: 0, y: 0, width: size, height: size), shape: .ring, paletteSlot: .stick)
    }

    public static func shoulder(_ slot: OverlayFamilySlot, binding: SystemOverlayBinding, at origin: CGPoint = .zero,
                                analog: Bool = false) -> OverlayControl {
        let id = binding.inputID(slot)
        return OverlayControl(id: slot.rawValue, kind: analog ? .analogTrigger(id) : .button(id),
                              frame: CGRect(origin: origin, size: shoulderSize), label: binding.label(slot),
                              shape: .bar, paletteSlot: .utility)
    }

    /// Start/Select style pills in a row, 16pt apart.
    public static func pillRow(_ slots: [OverlayFamilySlot], binding: SystemOverlayBinding) -> [OverlayControl] {
        slots.enumerated().map { i, slot in
            OverlayControl(id: slot.rawValue, kind: .button(binding.inputID(slot)),
                           frame: CGRect(x: CGFloat(i) * (pillSize.width + edge), y: 0, width: pillSize.width, height: pillSize.height),
                           label: binding.label(slot), shape: .pill, paletteSlot: .utility)
        }
    }

    /// Standard group set shared by the pad families. `face` is supplied by the family.
    public static func padTemplate(face: [OverlayControl], shoulders: [OverlayFamilySlot], systemButtons: [OverlayFamilySlot],
                                   binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation,
                                   analogShoulders: Bool = false) -> OverlayTemplate {
        let landscape = orientation == .landscape
        var groups: [OverlayGroup] = [
            OverlayGroup(id: "dpad", controls: [dpad(binding: binding)],
                         placement: landscape ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: edge, y: portraitBottom))),
            OverlayGroup(id: "face", controls: face,
                         placement: landscape ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: edge, y: portraitBottom)))
        ]
        let shoulderY: CGFloat = portraitBottom + dpadSize + 24
        for (i, slot) in shoulders.enumerated() {
            let leading = slot.rawValue.hasPrefix("l")
            let row = CGFloat(i / 2)        // l, r on row 0; l2, r2 on row 1
            let anchor: OverlayPlacement.Anchor = landscape ? (leading ? .topLeading : .topTrailing)
                                                            : (leading ? .bottomLeading : .bottomTrailing)
            let inset = landscape ? CGPoint(x: edge, y: 12 + row * (shoulderSize.height + 8))
                                  : CGPoint(x: edge, y: shoulderY + row * (shoulderSize.height + 8))
            groups.append(OverlayGroup(id: "shoulder-\(slot.rawValue)",
                                       controls: [shoulder(slot, binding: binding, analog: analogShoulders)],
                                       placement: OverlayPlacement(anchor: anchor, inset: inset)))
        }
        if !systemButtons.isEmpty {
            groups.append(OverlayGroup(id: "system", controls: pillRow(systemButtons, binding: binding),
                                       placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20))))
        }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }
}
```

- [ ] **Step 4: Implement the four pad families**

```swift
// Families/Family+TwoButton.swift
import Foundation
public enum TwoButtonFamily: OverlayFamily {
    public static let id = "twoButton"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.faceButton
        let face = [
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: 0, y: 24), size: s, palette: .secondary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: s + 12, y: 0), size: s, palette: .primary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
```

```swift
// Families/Family+FourFace.swift
import Foundation
public enum FourFaceFamily: OverlayFamily {
    public static let id = "fourFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.faceButton
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: s, y: 0), palette: .tertiary),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: s), palette: .quaternary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 2 * s, y: s), palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: s, y: 2 * s), palette: .secondary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
```

```swift
// Families/Family+ThreeFace.swift
import Foundation
public enum ThreeFaceFamily: OverlayFamily {
    public static let id = "threeFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .c, .start]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.faceButton
        // Genesis arc: A low-left, B middle, C high-right.
        let face = [
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 0, y: 40), palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: s + 8, y: 16), palette: .secondary),
            OverlayFamilyKit.button(.c, binding: binding, at: CGPoint(x: 2 * (s + 8), y: 0), palette: .tertiary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
```

```swift
// Families/Family+SixFace.swift
import Foundation
public enum SixFaceFamily: OverlayFamily {
    public static let id = "sixFace"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .c, .x, .y, .z, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.smallButton
        let gap: CGFloat = 8
        func col(_ i: Int) -> CGFloat { CGFloat(i) * (s + gap) }
        // Top row X Y Z, bottom row A B C, arcing up to the right like the real pad.
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: col(0), y: 24), size: s, palette: .tertiary),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: col(1), y: 12), size: s, palette: .quaternary),
            OverlayFamilyKit.button(.z, binding: binding, at: CGPoint(x: col(2), y: 0), size: s, palette: .utility),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: col(0), y: 24 + s + gap), size: s, palette: .primary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: col(1), y: 12 + s + gap), size: s, palette: .secondary),
            OverlayFamilyKit.button(.c, binding: binding, at: CGPoint(x: col(2), y: s + gap), size: s, palette: .tertiary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
```

- [ ] **Step 5: Run tests, expect PASS**
- [ ] **Step 6: swiftlint, commit** — `feat(overlay): family protocol, builder kit and the four pad families`

---

### Task 5: N64, PlayStation digital and dual-stick families

**Files:**
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+N64.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+DigitalPad.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Families/Family+DualStick.swift`
- Modify: `Families/OverlayFamily.swift` (append the three to `OverlayFamilyRegistry.all`)
- Test: extend `OverlayFamilyTests.groupsStayOnCanvas` arguments with `N64Family.id, DigitalPadFamily.id, DualStickFamily.id`, and add:

```swift
    static let psx = SystemOverlayBinding(
        system: .PSX, families: ["psx-digital": DigitalPadFamily.self, "psx-dualshock": DualStickFamily.self],
        defaultSubtype: "psx-dualshock",
        tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1", .l2: "l2", .r2: "r2",
                 .l3: "l3", .r3: "r3", .start: "start", .select: "select"],
        labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L1", .r: "R1", .l2: "L2", .r2: "R2", .start: "START", .select: "SELECT"],
        palette: .playStation, hardwareSwitches: [])

    @Test("Dual-stick adds two sticks below the pad; digital adds none")
    func sticks() {
        func stickCount(_ f: any OverlayFamily.Type) -> Int {
            f.template(binding: Self.psx, padKind: OverlayPadKind(system: .PSX, subtype: "psx-dualshock"), orientation: .portrait)
                .groups.flatMap(\.controls).filter { if case .stick = $0.kind { return true } else { return false } }.count
        }
        #expect(stickCount(DualStickFamily.self) == 2)
        #expect(stickCount(DigitalPadFamily.self) == 0)
    }

    @Test("N64 has a left stick, a C cluster and a Z trigger")
    func n64() {
        let n64 = SystemOverlayBinding(
            system: .N64, families: [OverlayPadKind.standardSubtype: N64Family.self], defaultSubtype: OverlayPadKind.standardSubtype,
            tokens: [.a: "a", .b: "b", .z: "z", .l: "l", .r: "r", .start: "start",
                     .cUp: "cUp", .cDown: "cDown", .cLeft: "cLeft", .cRight: "cRight"],
            labels: [.a: "A", .b: "B", .z: "Z", .l: "L", .r: "R", .start: "START", .cUp: "C▲", .cDown: "C▼", .cLeft: "C◀", .cRight: "C▶"],
            palette: .n64, hardwareSwitches: [])
        let t = N64Family.template(binding: n64, padKind: .standard(.N64), orientation: .portrait)
        let ids = Set(t.groups.flatMap(\.controls).map(\.id))
        #expect(ids.isSuperset(of: ["leftStick", "cUp", "cDown", "cLeft", "cRight", "z", "a", "b"]))
    }
```

**Interfaces:** Produces `N64Family`, `DigitalPadFamily`, `DualStickFamily`, palettes `.n64`, `.playStation`.

- [ ] **Step 1: Add the tests above, run, expect FAIL**

- [ ] **Step 2: Implement**

```swift
// Families/Family+DigitalPad.swift
import Foundation
public enum DigitalPadFamily: OverlayFamily {
    public static let id = "digitalPad"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .l2, .r2, .start, .select]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.faceButton
        // PlayStation diamond: △ top, □ left, ○ right, ✕ bottom. Slots: x=△ y=□ b=○ a=✕.
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: s, y: 0), palette: .quaternary),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: s), palette: .tertiary),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: 2 * s, y: s), palette: .primary),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: s, y: 2 * s), palette: .secondary)
        ]
        return OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r, .l2, .r2], systemButtons: [.select, .start],
                                            binding: binding, padKind: padKind, orientation: orientation)
    }
}
```

```swift
// Families/Family+DualStick.swift
import Foundation
public enum DualStickFamily: OverlayFamily {
    public static let id = "dualStick"
    public static let requiredSlots: [OverlayFamilySlot] = DigitalPadFamily.requiredSlots + [.l3, .r3]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        var base = DigitalPadFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let landscape = orientation == .landscape
        let k = OverlayFamilyKit.self
        // Sticks sit below and inside the d-pad / face clusters so thumbs rest on them.
        let inset = landscape ? CGPoint(x: k.edge + k.dpadSize + 12, y: 12) : CGPoint(x: k.edge + 20, y: 12)
        let groups = base.groups + [
            OverlayGroup(id: "leftStick", controls: [k.stick(.left, click: binding.inputID(.l3))],
                         placement: OverlayPlacement(anchor: .bottomLeading, inset: inset)),
            OverlayGroup(id: "rightStick", controls: [k.stick(.right, click: binding.inputID(.r3))],
                         placement: OverlayPlacement(anchor: .bottomTrailing, inset: inset))
        ]
        // In portrait, lift the d-pad and face above the sticks.
        let lifted = groups.map { g -> OverlayGroup in
            guard !landscape, g.id == "dpad" || g.id == "face" else { return g }
            var g = g
            g.placement.inset.y += k.stickSize + 24
            return g
        }
        base = OverlayTemplate(padKind: padKind, orientation: orientation, groups: lifted, screenPolicy: base.screenPolicy)
        return base
    }
}
```

```swift
// Families/Family+N64.swift
import Foundation
public enum N64Family: OverlayFamily {
    public static let id = "n64"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .z, .l, .r, .start, .cUp, .cDown, .cLeft, .cRight]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let k = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let s = k.faceButton, c = k.smallButton
        let face = [
            k.button(.b, binding: binding, at: CGPoint(x: 0, y: 0), palette: .quaternary),       // green B upper-left
            k.button(.a, binding: binding, at: CGPoint(x: s - 8, y: s - 8), size: s + 8, palette: .tertiary) // blue A larger
        ]
        let cCluster = [
            k.button(.cUp, binding: binding, at: CGPoint(x: c, y: 0), size: c, palette: .secondary),
            k.button(.cLeft, binding: binding, at: CGPoint(x: 0, y: c), size: c, palette: .secondary),
            k.button(.cRight, binding: binding, at: CGPoint(x: 2 * c, y: c), size: c, palette: .secondary),
            k.button(.cDown, binding: binding, at: CGPoint(x: c, y: 2 * c), size: c, palette: .secondary)
        ]
        var groups: [OverlayGroup] = [
            OverlayGroup(id: "leftStick", controls: [k.stick(.left)],
                         placement: landscape ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge + 12, y: k.portraitBottom))),
            OverlayGroup(id: "dpad", controls: [k.dpad(binding: binding, size: 110)],
                         placement: landscape ? OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge, y: 12))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge, y: k.portraitBottom + k.stickSize + 20))),
            OverlayGroup(id: "face", controls: face,
                         placement: landscape ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: k.edge + 3 * c + 12, y: 0))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge + 3 * c + 12, y: k.portraitBottom))),
            OverlayGroup(id: "cCluster", controls: cCluster,
                         placement: landscape ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge, y: k.portraitBottom + 20))),
            OverlayGroup(id: "shoulder-l", controls: [k.shoulder(.l, binding: binding)],
                         placement: OverlayPlacement(anchor: landscape ? .topLeading : .bottomLeading,
                                                     inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom + k.stickSize + 140))),
            OverlayGroup(id: "shoulder-r", controls: [k.shoulder(.r, binding: binding)],
                         placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                                     inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom + k.stickSize + 140))),
            OverlayGroup(id: "z", controls: [k.shoulder(.z, binding: binding)],
                         placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 60 : 20 + k.pillSize.height + 12))),
            OverlayGroup(id: "system", controls: k.pillRow([.start], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        if landscape { groups = groups.map { $0 } }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }
}
```

Add to `OverlayPalette`:

```swift
    public static let n64 = OverlayPalette(
        shell: OverlayColor(0.35, 0.35, 0.38), primary: OverlayColor(0.86, 0.19, 0.22),
        secondary: OverlayColor(0.98, 0.78, 0.18),   // C buttons yellow
        tertiary: OverlayColor(0.16, 0.40, 0.80),    // A blue
        quaternary: OverlayColor(0.18, 0.62, 0.30),  // B green
        utility: OverlayColor(0.45, 0.45, 0.50), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
    public static let playStation = OverlayPalette(
        shell: OverlayColor(0.55, 0.55, 0.58), primary: OverlayColor(0.86, 0.28, 0.33),   // ○ red
        secondary: OverlayColor(0.45, 0.62, 0.86),                                         // ✕ blue
        tertiary: OverlayColor(0.86, 0.50, 0.70),                                          // □ pink
        quaternary: OverlayColor(0.30, 0.72, 0.52),                                        // △ green
        utility: OverlayColor(0.40, 0.40, 0.44), dpad: OverlayColor(0.30, 0.30, 0.34),
        stick: OverlayColor(0.30, 0.30, 0.34), label: .white)
```

- [ ] **Step 3: Run tests, expect PASS**
- [ ] **Step 4: Commit** — `feat(overlay): N64, PlayStation digital and dual-stick families`

---

### Task 6: GameCube and Wii families

**Files:**
- Create: `Families/Family+GameCube.swift`, `Families/Family+WiiRemote.swift` (upright remote + optional Nunchuk), `Families/Family+WiiRemoteSideways.swift`, `Families/Family+WiiClassic.swift`
- Modify: `Families/OverlayFamily.swift` (register), `Bindings/SystemOverlayBinding.swift` (palettes `.gameCube`, `.wii`)
- Test: extend `groupsStayOnCanvas` arguments; add:

```swift
    @Test("Upright Wii Remote has a wiiPointer surface; sideways has none")
    func wiiPointer() {
        let wii = SystemOverlayBinding(
            system: .Wii, families: ["wii-wiimote": WiiRemoteSidewaysFamily.self, "wii-wiimote-nunchuck": WiiRemoteFamily.self,
                                      "wii-classic": WiiClassicFamily.self, "wii-classic-pro": WiiClassicFamily.self],
            defaultSubtype: "wii-wiimote-nunchuck",
            tokens: [.a: "a", .b: "b", .one: "x", .two: "y", .plus: "start", .minus: "select", .home: "r3", .c: "l1", .z: "r1",
                     .x: "x", .y: "y", .l: "l1", .r: "r1", .l2: "l2", .r2: "r2", .start: "start", .select: "select"],
            labels: [:], palette: .wii, hardwareSwitches: [])
        func hasPointer(_ f: any OverlayFamily.Type, _ subtype: String) -> Bool {
            f.template(binding: wii, padKind: OverlayPadKind(system: .Wii, subtype: subtype), orientation: .portrait)
                .groups.flatMap(\.controls).contains { $0.kind == .touchSurface(.wiiPointer) }
        }
        #expect(hasPointer(WiiRemoteFamily.self, "wii-wiimote-nunchuck"))
        #expect(!hasPointer(WiiRemoteSidewaysFamily.self, "wii-wiimote"))
    }

    @Test("GameCube L and R are analog triggers and Z is a button")
    func gcTriggers() {
        let gc = SystemOverlayBinding(
            system: .GameCube, families: [OverlayPadKind.standardSubtype: GameCubeFamily.self], defaultSubtype: OverlayPadKind.standardSubtype,
            tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .z: "z", .l: "l2", .r: "r2", .start: "start"],
            labels: [:], palette: .gameCube, hardwareSwitches: [])
        let kinds = GameCubeFamily.template(binding: gc, padKind: .standard(.GameCube), orientation: .landscape)
            .groups.flatMap(\.controls).reduce(into: [String: OverlayControlKind]()) { $0[$1.id] = $1.kind }
        #expect(kinds["l"] == .analogTrigger(OverlayInputID(system: .GameCube, token: "l2")))
        #expect(kinds["z"] == .button(OverlayInputID(system: .GameCube, token: "z")))
    }
```

**Token facts for the implementer** (from `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkinNintendoHomeConsoleMapping.swift`): GameCube skin tokens `a b x y start up down left right`, `z` (or `r1`) = Z, `l2` = L trigger, `r2` = R trigger; right thumbstick = C-stick. Wii tokens: `a b`, `x`=1, `y`=2, `start`=+, `select`=−, `l1`=Nunchuk C, `r1`=Nunchuk Z, `r3`=Home, left thumbstick = Nunchuk stick. The Wii subtype ids come from `ControllerLayoutVariant`: `wii-wiimote` is described there as the horizontal (sideways) layout, `wii-wiimote-nunchuck` is upright with pointer, `wii-classic`/`wii-classic-pro` share the Classic family.

- [ ] **Step 1: Add tests, run, expect FAIL**
- [ ] **Step 2: Implement**

```swift
// Families/Family+GameCube.swift
import Foundation
public enum GameCubeFamily: OverlayFamily {
    public static let id = "gameCube"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .z, .l, .r, .start]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let k = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let big: CGFloat = 72, small: CGFloat = 44
        // Big green A centre, red B lower-left, X kidney right, Y kidney top.
        let face = [
            k.button(.a, binding: binding, at: CGPoint(x: 52, y: 52), size: big, palette: .primary),
            k.button(.b, binding: binding, at: CGPoint(x: 0, y: 100), size: small, palette: .secondary),
            k.button(.x, binding: binding, at: CGPoint(x: 130, y: 44), size: small, shape: .kidney, palette: .utility),
            k.button(.y, binding: binding, at: CGPoint(x: 60, y: 0), size: small, shape: .kidney, palette: .utility)
        ]
        let groups: [OverlayGroup] = [
            OverlayGroup(id: "leftStick", controls: [k.stick(.left)],
                         placement: landscape ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge + 8, y: k.portraitBottom + 110))),
            OverlayGroup(id: "dpad", controls: [k.dpad(binding: binding, size: 100)],
                         placement: OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom))),
            OverlayGroup(id: "face", controls: face,
                         placement: landscape ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge, y: k.portraitBottom + 110))),
            OverlayGroup(id: "rightStick", controls: [k.stick(.right, size: 90)],
                         placement: OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge + 20, y: landscape ? 12 : k.portraitBottom))),
            OverlayGroup(id: "shoulder-l", controls: [k.shoulder(.l, binding: binding, analog: true)],
                         placement: OverlayPlacement(anchor: landscape ? .topLeading : .bottomLeading,
                                                     inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom + 250))),
            OverlayGroup(id: "shoulder-r", controls: [k.shoulder(.r, binding: binding, analog: true),
                                                      k.shoulder(.z, binding: binding, at: CGPoint(x: 0, y: k.shoulderSize.height + 8))],
                         placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                                     inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom + 250))),
            OverlayGroup(id: "system", controls: k.pillRow([.start], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }
}
```

```swift
// Families/Family+WiiRemote.swift  (upright remote; Nunchuk stick + C/Z on the left; pointer surface over the picture)
import Foundation
public enum WiiRemoteFamily: OverlayFamily {
    public static let id = "wiiRemote"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .one, .two, .plus, .minus, .home, .c, .z]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let k = OverlayFamilyKit.self
        let landscape = orientation == .landscape
        let pointer = OverlayControl(id: "pointer", kind: .touchSurface(.wiiPointer), frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                     shape: .surface, paletteSlot: .shell)
        let ab = [
            k.button(.a, binding: binding, at: CGPoint(x: 0, y: 0), size: 64, palette: .primary),
            k.button(.b, binding: binding, at: CGPoint(x: 72, y: 24), size: 56, shape: .bar, palette: .utility)
        ]
        let oneTwo = [
            k.button(.one, binding: binding, at: CGPoint(x: 0, y: 0), size: k.smallButton, palette: .utility),
            k.button(.two, binding: binding, at: CGPoint(x: k.smallButton + 8, y: 0), size: k.smallButton, palette: .utility)
        ]
        let nunchuk = [
            k.button(.c, binding: binding, at: CGPoint(x: 0, y: 0), size: k.smallButton, palette: .utility),
            k.button(.z, binding: binding, at: CGPoint(x: 0, y: k.smallButton + 8), size: k.smallButton, shape: .bar, palette: .utility)
        ]
        let groups: [OverlayGroup] = [
            OverlayGroup(id: "pointer", controls: [pointer], placement: OverlayPlacement(anchor: .fill)),
            OverlayGroup(id: "nunchukStick", controls: [k.stick(.left)],
                         placement: landscape ? OverlayPlacement(anchor: .centerLeading, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge + 8, y: k.portraitBottom))),
            OverlayGroup(id: "nunchukCZ", controls: nunchuk,
                         placement: landscape ? OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge, y: 12))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge + k.stickSize + 20, y: k.portraitBottom + 20))),
            OverlayGroup(id: "dpad", controls: [k.dpad(binding: binding, size: 100)],
                         placement: landscape ? OverlayPlacement(anchor: .topLeading, inset: CGPoint(x: k.edge, y: 12))
                                              : OverlayPlacement(anchor: .bottomLeading, inset: CGPoint(x: k.edge, y: k.portraitBottom + k.stickSize + 24))),
            OverlayGroup(id: "ab", controls: ab,
                         placement: landscape ? OverlayPlacement(anchor: .centerTrailing, inset: CGPoint(x: k.edge, y: 0))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge, y: k.portraitBottom))),
            OverlayGroup(id: "oneTwo", controls: oneTwo,
                         placement: landscape ? OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge, y: 12))
                                              : OverlayPlacement(anchor: .bottomTrailing, inset: CGPoint(x: k.edge, y: k.portraitBottom + 100))),
            OverlayGroup(id: "system", controls: k.pillRow([.minus, .home, .plus], binding: binding),
                         placement: OverlayPlacement(anchor: .bottomCenter, inset: CGPoint(x: 0, y: landscape ? 12 : 20)))
        ]
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: groups,
                               screenPolicy: landscape ? .centerColumn : .topBand)
    }
}
```

```swift
// Families/Family+WiiRemoteSideways.swift
import Foundation
public enum WiiRemoteSidewaysFamily: OverlayFamily {
    public static let id = "wiiRemoteSideways"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .one, .two, .plus, .minus, .home]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let k = OverlayFamilyKit.self
        let s = k.faceButton
        // Held sideways: d-pad left thumb, 1/2 right thumb (2 is the primary), A/B above.
        let face = [
            k.button(.one, binding: binding, at: CGPoint(x: 0, y: 24), size: s, palette: .utility),
            k.button(.two, binding: binding, at: CGPoint(x: s + 12, y: 0), size: s, palette: .utility)
        ]
        let ab = [
            k.button(.b, binding: binding, at: CGPoint(x: 0, y: 0), size: k.smallButton, shape: .bar, palette: .utility),
            k.button(.a, binding: binding, at: CGPoint(x: k.smallButton + 8, y: 0), size: k.smallButton, palette: .primary)
        ]
        var t = k.padTemplate(face: face, shoulders: [], systemButtons: [.minus, .home, .plus],
                              binding: binding, padKind: padKind, orientation: orientation)
        let landscape = orientation == .landscape
        t = OverlayTemplate(padKind: padKind, orientation: orientation, groups: t.groups + [
            OverlayGroup(id: "ab", controls: ab,
                         placement: OverlayPlacement(anchor: landscape ? .topTrailing : .bottomTrailing,
                                                     inset: CGPoint(x: k.edge, y: landscape ? 12 : k.portraitBottom + 140)))
        ], screenPolicy: t.screenPolicy)
        return t
    }
}
```

```swift
// Families/Family+WiiClassic.swift
import Foundation
public enum WiiClassicFamily: OverlayFamily {
    public static let id = "wiiClassic"
    public static let requiredSlots: [OverlayFamilySlot] = [.a, .b, .x, .y, .l, .r, .l2, .r2, .plus, .minus, .home]
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let s = OverlayFamilyKit.faceButton
        // Classic Controller: X top, Y left, A right, B bottom (SNES-style, swapped A/B positions vs. SNES).
        let face = [
            OverlayFamilyKit.button(.x, binding: binding, at: CGPoint(x: s, y: 0), palette: .utility),
            OverlayFamilyKit.button(.y, binding: binding, at: CGPoint(x: 0, y: s), palette: .utility),
            OverlayFamilyKit.button(.a, binding: binding, at: CGPoint(x: 2 * s, y: s), palette: .utility),
            OverlayFamilyKit.button(.b, binding: binding, at: CGPoint(x: s, y: 2 * s), palette: .utility)
        ]
        let base = OverlayFamilyKit.padTemplate(face: face, shoulders: [.l, .r, .l2, .r2], systemButtons: [.minus, .home, .plus],
                                                binding: binding, padKind: padKind, orientation: orientation)
        // Reuse the dual-stick lift so the sticks sit under the pad.
        let dual = DualStickFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let sticks = dual.groups.filter { $0.id == "leftStick" || $0.id == "rightStick" }
            .map { g -> OverlayGroup in var g = g; g.controls = g.controls.map { c in
                var c = c; if case .stick(let side, _) = c.kind { c.kind = .stick(side, click: nil) }; return c }; return g }
        let lifted = base.groups.map { g -> OverlayGroup in
            guard orientation == .portrait, g.id == "dpad" || g.id == "face" else { return g }
            var g = g; g.placement.inset.y += OverlayFamilyKit.stickSize + 24; return g
        }
        return OverlayTemplate(padKind: padKind, orientation: orientation, groups: lifted + sticks, screenPolicy: base.screenPolicy)
    }
}
```

Palettes to add: `.gameCube` (indigo shell `OverlayColor(0.33, 0.30, 0.55)`, primary green A `OverlayColor(0.26, 0.68, 0.40)`, secondary red B `OverlayColor(0.80, 0.20, 0.22)`, utility grey X/Y/Z `OverlayColor(0.62, 0.62, 0.66)`, stick grey, label white) and `.wii` (white shell `OverlayColor(0.96, 0.96, 0.97)`, primary A light blue `OverlayColor(0.45, 0.70, 0.95)`, utility light grey `OverlayColor(0.85, 0.85, 0.88)`, label dark `OverlayColor(0.15, 0.15, 0.18)`; fill the remaining slots with the same greys).

Note for `DualStickFamily`'s `requiredSlots` including `.l3/.r3`: the Classic Controller has no stick clicks; the code above strips the click ids, and `SystemOverlayBinding.inputID` falls back to the slot's raw value if a token is missing, so Wii bindings need not provide them.

- [ ] **Step 3: Register the four families in `OverlayFamilyRegistry.all`; run tests, expect PASS**
- [ ] **Step 4: Commit** — `feat(overlay): GameCube and Wii pad families`

---

### Task 7: DS family and surface placement rule

**Files:**
- Create: `Families/Family+DSPad.swift`
- Modify: `Families/OverlayFamily.swift` (register), `Layout/OverlayLayoutEngine.swift` (surface placement)
- Test: `Tests/PVTouchOverlayTests/DSPadFamilyTests.swift`

**Interfaces:**
- Produces: `DSPadFamily`; the rule that a `.touchSurface(.dsScreen)` control's resolved frame equals `screenFrames.last`, a `.touchSurface(.wiiPointer)` control's resolved frame equals `screenFrames.first`, exposed as `OverlayLayout.surfaceFrame(for role:) -> CGRect?`.

- [ ] **Step 1: Failing test**

```swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("DS pad family")
struct DSPadFamilyTests {
    let ds = SystemOverlayBinding(
        system: .DS, families: [OverlayPadKind.standardSubtype: DSPadFamily.self], defaultSubtype: OverlayPadKind.standardSubtype,
        tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"],
        labels: [:], palette: .snes, hardwareSwitches: [])

    @Test("DS portrait stacks two screens and the stylus surface covers the bottom one")
    func stacked() {
        let t = DSPadFamily.template(binding: ds, padKind: .standard(.DS), orientation: .portrait)
        #expect(t.screenPolicy == .dualStacked)
        let layout = OverlayLayoutEngine.resolve(template: t, canvas: OverlayLayoutEngineTests.phonePortrait, overrides: .empty,
                                                 gameAspect: OverlayScreenPlanner.dsAspect)
        #expect(layout.screenFrames.count == 2)
        #expect(layout.surfaceFrame(for: .dsScreen) == layout.screenFrames[1])
    }

    @Test("Pointer surface covers the first screen frame")
    func pointerSurface() {
        let wii = OverlayFamilyTests.wiiBinding
        let t = WiiRemoteFamily.template(binding: wii, padKind: OverlayPadKind(system: .Wii, subtype: "wii-wiimote-nunchuck"), orientation: .landscape)
        let layout = OverlayLayoutEngine.resolve(template: t, canvas: OverlayLayoutEngineTests.phoneLandscape, overrides: .empty, gameAspect: 16.0 / 9.0)
        #expect(layout.surfaceFrame(for: .wiiPointer) == layout.screenFrames[0])
    }
}
```
(Move the Wii binding from Task 6's test into a `static let wiiBinding` on `OverlayFamilyTests` so both suites share it.)

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**

```swift
// Families/Family+DSPad.swift
import Foundation
public enum DSPadFamily: OverlayFamily {
    public static let id = "dsPad"
    public static let requiredSlots: [OverlayFamilySlot] = FourFaceFamily.requiredSlots
    public static func template(binding: SystemOverlayBinding, padKind: OverlayPadKind, orientation: OverlayOrientation) -> OverlayTemplate {
        let base = FourFaceFamily.template(binding: binding, padKind: padKind, orientation: orientation)
        let stylus = OverlayControl(id: "stylus", kind: .touchSurface(.dsScreen), frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                    shape: .surface, paletteSlot: .shell)
        return OverlayTemplate(padKind: padKind, orientation: orientation,
                               groups: base.groups + [OverlayGroup(id: "stylus", controls: [stylus], placement: OverlayPlacement(anchor: .fill))],
                               screenPolicy: orientation == .portrait ? .dualStacked : .centerColumn)
    }
}
```

In `OverlayLayoutEngine.resolve`, after `screens` is computed, rebuild any group whose single control is a `.touchSurface` so its `frame`/`hitFrame` (and the group frame) equal the matching screen frame; add to `OverlayLayout`:

```swift
    public func surfaceFrame(for role: OverlaySurfaceRole) -> CGRect? {
        groups.flatMap(\.controls).first { $0.control.kind == .touchSurface(role) }?.frame
    }
```
Rule: `.dsScreen` → `screenFrames.last`; every other role → `screenFrames.first`. Landscape DS (`centerColumn`) gives one frame, so the stylus covers the whole picture; that is acceptable for Phase 1 and noted in the host (Task 14) which still sends only bottom-half-relative points when `screenFrames.count == 1` by using the lower half of the rect.

- [ ] **Step 4: Run tests, expect PASS**
- [ ] **Step 5: Commit** — `feat(overlay): DS family with stylus surface bound to the bottom screen`

---

### Task 8: System bindings registry and PlayStation variants

**Files:**
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Bindings/SystemOverlayBindings.swift`
- Modify: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerLayoutVariant.swift` (add `psxDigital`, `psxDualShock`; `.PSX` case in `availableControllerLayoutVariants`)
- Test: `Tests/PVTouchOverlayTests/SystemOverlayBindingsTests.swift`

**Interfaces:**
- Produces: `SystemOverlayBindings.binding(for: SystemIdentifier) -> SystemOverlayBinding?`, `SystemOverlayBindings.phase1Systems: [SystemIdentifier]`, `ControllerLayoutVariant.psxDigital` (`"psx-digital"`), `.psxDualShock` (`"psx-dualshock"`).

**Token verification is part of this task.** For every binding, open the system's `PV*Button.swift` in `PVCoreBridge/Sources/PVCoreBridge/Features/Controls/` and the matching `case` in `DeltaSkinInputHandler.normalizeSkinButtonId` (`PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkinInputHandler.swift`, ~line 2267 onward) and confirm each token string parses to the intended enum case. Record any correction in the commit body.

- [ ] **Step 1: Failing tests**

```swift
import Foundation
import Testing
import PVPrimitives
import PVCoreBridge
@testable import PVTouchOverlay

@Suite("System bindings")
struct SystemOverlayBindingsTests {
    @Test("Every Phase 1 system has a binding whose families' required slots are all tokenised",
          arguments: SystemOverlayBindings.phase1Systems)
    func complete(system: SystemIdentifier) throws {
        let b = try #require(SystemOverlayBindings.binding(for: system))
        for (subtype, family) in b.families {
            for slot in family.requiredSlots {
                #expect(b.tokens[slot] != nil, "\(system) \(subtype) missing token for \(slot.rawValue)")
            }
        }
        #expect(b.families[b.defaultSubtype] != nil)
    }

    @Test("Variant ids used as subtypes exist in ControllerLayoutVariant")
    func variantsExist() {
        for system in SystemOverlayBindings.phase1Systems {
            guard let b = SystemOverlayBindings.binding(for: system),
                  let variants = system.availableControllerLayoutVariants else { continue }
            let ids = Set(variants.map(\.id))
            for subtype in b.families.keys where subtype != OverlayPadKind.standardSubtype {
                #expect(ids.contains(subtype), "\(system) subtype \(subtype) is not a ControllerLayoutVariant")
            }
        }
    }

    @Test("PlayStation exposes digital and DualShock variants")
    func psxVariants() {
        #expect(SystemIdentifier.PSX.availableControllerLayoutVariants?.map(\.id) == ["psx-dualshock", "psx-digital"])
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Add the variants to `ControllerLayoutVariant.swift`**

```swift
    // MARK: PlayStation
    static let psxDualShock = ControllerLayoutVariant(
        id: "psx-dualshock", displayName: "DualShock",
        description: "Analog controller with two sticks, L3/R3 and analog mode.", sfSymbol: "gamecontroller.fill")
    static let psxDigital = ControllerLayoutVariant(
        id: "psx-digital", displayName: "Digital Pad",
        description: "Original PlayStation controller without analog sticks.", sfSymbol: "gamecontroller")
```
and in `availableControllerLayoutVariants`: `case .PSX: return [.psxDualShock, .psxDigital]`.

- [ ] **Step 4: Write the registry**

```swift
// Bindings/SystemOverlayBindings.swift
import Foundation
import PVPrimitives

public enum SystemOverlayBindings {
    public static let phase1Systems: [SystemIdentifier] = [
        .NES, .GB, .GBC, .SNES, .GBA, .Genesis, .Sega32X, .SegaCD, .N64, .PSX, .GameCube, .Wii, .DS
    ]

    public static func binding(for system: SystemIdentifier) -> SystemOverlayBinding? { table[system] }

    private static let std = OverlayPadKind.standardSubtype

    private static let table: [SystemIdentifier: SystemOverlayBinding] = {
        var t: [SystemIdentifier: SystemOverlayBinding] = [:]
        let twoButtonTokens: [OverlayFamilySlot: String] = [.a: "a", .b: "b", .start: "start", .select: "select"]
        let twoButtonLabels: [OverlayFamilySlot: String] = [.a: "A", .b: "B", .start: "START", .select: "SELECT"]
        for s in [SystemIdentifier.NES, .GB, .GBC] {
            t[s] = SystemOverlayBinding(system: s, families: [std: TwoButtonFamily.self], defaultSubtype: std,
                                        tokens: twoButtonTokens, labels: twoButtonLabels,
                                        palette: s == .NES ? .nes : .gameBoy, hardwareSwitches: [])
        }
        let fourTokens: [OverlayFamilySlot: String] = [.a: "a", .b: "b", .x: "x", .y: "y", .l: "l", .r: "r", .start: "start", .select: "select"]
        let fourLabels: [OverlayFamilySlot: String] = [.a: "A", .b: "B", .x: "X", .y: "Y", .l: "L", .r: "R", .start: "START", .select: "SELECT"]
        t[.SNES] = SystemOverlayBinding(system: .SNES, families: [std: FourFaceFamily.self], defaultSubtype: std,
                                        tokens: fourTokens, labels: fourLabels, palette: .snes, hardwareSwitches: [])
        // GBA has no X/Y; FourFace with L/R only. Use TwoButton + shoulders via the kit? Simpler: FourFace minus X/Y is TwoButton
        // plus shoulders, so GBA binds TwoButtonFamily and adds l/r through a dedicated family in Phase 2. For Phase 1 bind FourFace
        // tokens with x/y mapped to the same a/b so no dead buttons exist.
        t[.GBA] = SystemOverlayBinding(system: .GBA, families: [std: GBAFamily.self], defaultSubtype: std,
                                       tokens: [.a: "a", .b: "b", .l: "l", .r: "r", .start: "start", .select: "select"],
                                       labels: [.a: "A", .b: "B", .l: "L", .r: "R", .start: "START", .select: "SELECT"],
                                       palette: .gameBoy, hardwareSwitches: [])
        let genesisTokens: [OverlayFamilySlot: String] = [.a: "a", .b: "b", .c: "c", .x: "x", .y: "y", .z: "z", .start: "start", .select: "mode"]
        let genesisLabels: [OverlayFamilySlot: String] = [.a: "A", .b: "B", .c: "C", .x: "X", .y: "Y", .z: "Z", .start: "START", .select: "MODE"]
        for s in [SystemIdentifier.Genesis, .Sega32X, .SegaCD] {
            t[s] = SystemOverlayBinding(system: s, families: ["genesis-3btn": ThreeFaceFamily.self, "genesis-6btn": SixFaceFamily.self],
                                        defaultSubtype: "genesis-3btn", tokens: genesisTokens, labels: genesisLabels,
                                        palette: .genesis, hardwareSwitches: [])
        }
        t[.N64] = SystemOverlayBinding(system: .N64, families: [std: N64Family.self], defaultSubtype: std,
                                       tokens: [.a: "a", .b: "b", .z: "z", .l: "l", .r: "r", .start: "start",
                                                .cUp: "cUp", .cDown: "cDown", .cLeft: "cLeft", .cRight: "cRight"],
                                       labels: [.a: "A", .b: "B", .z: "Z", .l: "L", .r: "R", .start: "START",
                                                .cUp: "C▲", .cDown: "C▼", .cLeft: "C◀", .cRight: "C▶"],
                                       palette: .n64, hardwareSwitches: [])
        t[.PSX] = SystemOverlayBinding(system: .PSX, families: ["psx-digital": DigitalPadFamily.self, "psx-dualshock": DualStickFamily.self],
                                       defaultSubtype: "psx-dualshock",
                                       tokens: [.a: "cross", .b: "circle", .x: "triangle", .y: "square", .l: "l1", .r: "r1", .l2: "l2", .r2: "r2",
                                                .l3: "l3", .r3: "r3", .start: "start", .select: "select"],
                                       labels: [.a: "✕", .b: "○", .x: "△", .y: "□", .l: "L1", .r: "R1", .l2: "L2", .r2: "R2", .start: "START", .select: "SELECT"],
                                       palette: .playStation, hardwareSwitches: [])
        t[.GameCube] = SystemOverlayBinding(system: .GameCube,
                                            families: ["gc-standard": GameCubeFamily.self, "gc-bongos": GameCubeFamily.self, "gc-keyboard": GameCubeFamily.self],
                                            defaultSubtype: "gc-standard",
                                            tokens: [.a: "a", .b: "b", .x: "x", .y: "y", .z: "z", .l: "l2", .r: "r2", .start: "start"],
                                            labels: [.a: "A", .b: "B", .x: "X", .y: "Y", .z: "Z", .l: "L", .r: "R", .start: "START"],
                                            palette: .gameCube, hardwareSwitches: [])
        t[.Wii] = SystemOverlayBinding(system: .Wii,
                                       families: ["wii-wiimote": WiiRemoteSidewaysFamily.self, "wii-wiimote-nunchuck": WiiRemoteFamily.self,
                                                  "wii-classic": WiiClassicFamily.self, "wii-classic-pro": WiiClassicFamily.self],
                                       defaultSubtype: "wii-wiimote-nunchuck",
                                       tokens: [.a: "a", .b: "b", .one: "x", .two: "y", .plus: "start", .minus: "select", .home: "r3",
                                                .c: "l1", .z: "r1", .x: "x", .y: "y", .l: "l1", .r: "r1", .l2: "l2", .r2: "r2"],
                                       labels: [.a: "A", .b: "B", .one: "1", .two: "2", .plus: "+", .minus: "−", .home: "⌂", .c: "C", .z: "Z",
                                                .x: "X", .y: "Y", .l: "L", .r: "R", .l2: "ZL", .r2: "ZR"],
                                       palette: .wii, hardwareSwitches: [])
        t[.DS] = SystemOverlayBinding(system: .DS, families: [std: DSPadFamily.self], defaultSubtype: std,
                                      tokens: fourTokens, labels: fourLabels, palette: .ds, hardwareSwitches: [])
        return t
    }()
}
```

`GBAFamily` is `FourFaceFamily` without X/Y: add `Families/Family+GBA.swift` as a 15-line family whose face is the TwoButton pair and whose `padTemplate` call passes `shoulders: [.l, .r]`. Add palettes `.nes` (grey shell, red A/B), `.gameBoy` (grey-purple shell, magenta A/B), `.genesis` (black shell, grey face, red Start), `.ds` (light shell, grey face). Register `GBAFamily` in the registry.

- [ ] **Step 5: Run tests, expect PASS. Also build PVCoreBridge:** `cd PVCoreBridge && xcodebuild build -scheme PVCoreBridge -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation -skipMacroValidation`
- [ ] **Step 6: Commit** — `feat(overlay): system bindings for the Phase 1 systems; PSX layout variants`

---

### Task 9: Style and procedural art

**Files:**
- Create: `PVSettings/Sources/PVSettings/Settings/Model/OverlayStyle.swift` (PVSettings, so `Defaults` keys can use it without a package cycle)
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Render/OverlayPressLook.swift`
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Render/OverlayArt.swift`
- Test: `Tests/PVTouchOverlayTests/OverlayArtTests.swift`

**Interfaces:**
- Produces: in PVSettings `public enum OverlayStyle: String, Codable, CaseIterable, Identifiable, Defaults.Serializable { flat, glossy, outline }` with `static let defaultStyle = .flat` and `displayName`; in PVTouchOverlay (`import PVSettings`) `struct OverlayArtSpec: Equatable { shape, color: OverlayColor, labelColor, style, pressed: Bool, label: String? }`; `struct OverlayShapePath { static func path(_ shape: OverlayShape, in rect: CGRect) -> Path }`; SwiftUI `struct OverlayControlArt: View, Equatable { let spec: OverlayArtSpec }`; `extension Color { init(_ c: OverlayColor) }`; constants `OverlayPressLook.scale = 0.92`, `OverlayPressLook.duration = 0.08`.

- [ ] **Step 1: Failing tests** (pure parts only; views are exercised in Task 11's host tests)

```swift
import Foundation
import Testing
import SwiftUI
import PVSettings
@testable import PVTouchOverlay

@Suite("Overlay art")
struct OverlayArtTests {
    @Test("Every shape produces a non-empty path", arguments: OverlayShape.allCases)
    func shapes(shape: OverlayShape) {
        let p = OverlayShapePath.path(shape, in: CGRect(x: 0, y: 0, width: 56, height: 40))
        #expect(!p.isEmpty)
        #expect(p.boundingRect.width > 0)
    }

    @Test("Pressed spec differs only by pressed flag so Equatable drives redraws")
    func specEquality() {
        let a = OverlayArtSpec(shape: .circle, color: .white, labelColor: .black, style: .flat, pressed: false, label: "A")
        var b = a; b.pressed = true
        #expect(a != b)
        #expect(a == OverlayArtSpec(shape: .circle, color: .white, labelColor: .black, style: .flat, pressed: false, label: "A"))
    }
}
```
Add `CaseIterable` to `OverlayShape` in Task 1's file.

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**

```swift
// PVSettings/Sources/PVSettings/Settings/Model/OverlayStyle.swift
import Foundation
import Defaults

/// Visual style of the programmatic touch overlay controls.
public enum OverlayStyle: String, Codable, Sendable, CaseIterable, Identifiable, Defaults.Serializable {
    case flat, glossy, outline
    public var id: String { rawValue }
    public static let defaultStyle: OverlayStyle = .flat
    public var displayName: String {
        switch self { case .flat: return "Flat"; case .glossy: return "Glossy"; case .outline: return "Outline" }
    }
}
```

```swift
// Render/OverlayPressLook.swift
import Foundation
public enum OverlayPressLook {
    public static let scale: CGFloat = 0.92
    public static let duration: Double = 0.08
    public static let rimWidth: CGFloat = 1.5
}
```

```swift
// Render/OverlayArt.swift
#if canImport(UIKit)
import SwiftUI
import PVSettings

public struct OverlayArtSpec: Equatable, Sendable {
    public var shape: OverlayShape
    public var color: OverlayColor
    public var labelColor: OverlayColor
    public var style: OverlayStyle
    public var pressed: Bool
    public var label: String?
    public init(shape: OverlayShape, color: OverlayColor, labelColor: OverlayColor, style: OverlayStyle, pressed: Bool, label: String?) {
        self.shape = shape; self.color = color; self.labelColor = labelColor; self.style = style; self.pressed = pressed; self.label = label
    }
}

public extension Color {
    init(_ c: OverlayColor) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
}

public enum OverlayShapePath {
    public static func path(_ shape: OverlayShape, in rect: CGRect) -> Path {
        switch shape {
        case .circle, .knob:
            return Path(ellipseIn: rect)
        case .ring:
            var p = Path(ellipseIn: rect)
            p.addEllipse(in: rect.insetBy(dx: rect.width * 0.3, dy: rect.height * 0.3))
            return p
        case .pill:
            return Path(roundedRect: rect, cornerRadius: rect.height / 2)
        case .key:
            return Path(roundedRect: rect, cornerRadius: 6)
        case .surface:
            return Path(roundedRect: rect, cornerRadius: 10)
        case .bar:
            // Tapered trigger: narrower at the top.
            var p = Path()
            let taper = rect.width * 0.12
            p.move(to: CGPoint(x: rect.minX + taper, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        case .kidney:
            // Bean: two overlapping circles joined by a rounded rect, tilted by the caller via rotationEffect.
            let r = rect.height / 2
            var p = Path(roundedRect: CGRect(x: rect.minX + r * 0.4, y: rect.minY, width: rect.width - r * 0.8, height: rect.height), cornerRadius: r)
            p.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: rect.height, height: rect.height))
            p.addEllipse(in: CGRect(x: rect.maxX - rect.height, y: rect.minY, width: rect.height, height: rect.height))
            return p
        case .cross:
            let arm = rect.width / 3
            var p = Path()
            p.addRoundedRect(in: CGRect(x: rect.minX + arm, y: rect.minY, width: arm, height: rect.height), cornerSize: CGSize(width: 6, height: 6))
            p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY + arm, width: rect.width, height: arm), cornerSize: CGSize(width: 6, height: 6))
            return p
        }
    }
}

/// One control's art. Equatable so a press re-renders only this view.
public struct OverlayControlArt: View, Equatable {
    public let spec: OverlayArtSpec
    public init(spec: OverlayArtSpec) { self.spec = spec }

    public var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let path = OverlayShapePath.path(spec.shape, in: rect)
            let base = Color(spec.color)
            ZStack {
                switch spec.style {
                case .flat:
                    path.fill(spec.pressed ? base.opacity(0.75) : base)
                    path.stroke(Color.white.opacity(0.35), lineWidth: OverlayPressLook.rimWidth)
                case .glossy:
                    path.fill(LinearGradient(colors: [base.opacity(spec.pressed ? 0.8 : 1), base.opacity(0.6)],
                                             startPoint: .top, endPoint: .bottom))
                    path.fill(LinearGradient(colors: [Color.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                    path.stroke(Color.black.opacity(0.35), lineWidth: OverlayPressLook.rimWidth)
                case .outline:
                    path.fill(spec.pressed ? base.opacity(0.35) : Color.clear)
                    path.stroke(base, lineWidth: 2)
                }
                if let label = spec.label, spec.shape != .ring, spec.shape != .surface, spec.shape != .cross {
                    Text(label)
                        .font(.system(size: min(geo.size.height * 0.4, 18), weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(spec.labelColor))
                        .minimumScaleFactor(0.5)
                        .padding(4)
                }
            }
            .scaleEffect(spec.pressed ? OverlayPressLook.scale : 1)
            .animation(.easeOut(duration: OverlayPressLook.duration), value: spec.pressed)
        }
    }
}
#endif
```

- [ ] **Step 4: Run tests, expect PASS**
- [ ] **Step 5: Commit** — `feat(overlay): style switch and procedural control art`

---

### Task 10: Hit tester and touch primitives

**Files:**
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Touch/OverlayHitTester.swift` (UIKit-free)
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Touch/OverlayTouchCluster.swift` (`#if canImport(UIKit)`)
- Create: `PVTouchOverlay/Sources/PVTouchOverlay/Touch/OverlaySingleTouchSurface.swift` (`#if canImport(UIKit)`)
- Test: `Tests/PVTouchOverlayTests/OverlayHitTesterTests.swift`

**Interfaces:**
- Produces:
  - `enum OverlayDPadDirection: Hashable { up, down, left, right }`.
  - `enum OverlayHit: Hashable { case control(id: String), dpad(id: String, OverlayDPadDirection) }`.
  - `OverlayHitTester.hits(at points: [CGPoint], controls: [ResolvedControl], previousDPad: [String: Set<OverlayDPadDirection>]) -> Set<OverlayHit>`.
  - `OverlayHitTester.dpadDirections(point:in frame:previous:) -> Set<OverlayDPadDirection>` with `deadZoneFraction = 0.18`, `hysteresisDegrees = 8`.
  - `final class OverlayTouchCluster: UIView` with `var controls: [ResolvedControl]`, `var onChange: ((Set<OverlayHit>) -> Void)?`.
  - `final class OverlaySingleTouchSurface: UIView` with `var onBegan/onMoved: ((CGPoint) -> Void)?` (normalized 0…1 in its bounds, clamped), `var onEnded: (() -> Void)?`.

- [ ] **Step 1: Failing tests**

```swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

@Suite("OverlayHitTester")
struct OverlayHitTesterTests {
    let a = ResolvedControl(control: OverlayControl(id: "a", kind: .button(OverlayInputID(system: .SNES, token: "a")),
                                                    frame: .zero, shape: .circle, paletteSlot: .primary),
                            frame: CGRect(x: 100, y: 100, width: 56, height: 56), hitFrame: CGRect(x: 80, y: 80, width: 96, height: 96))
    let b = ResolvedControl(control: OverlayControl(id: "b", kind: .button(OverlayInputID(system: .SNES, token: "b")),
                                                    frame: .zero, shape: .circle, paletteSlot: .secondary),
                            frame: CGRect(x: 150, y: 100, width: 56, height: 56), hitFrame: CGRect(x: 130, y: 80, width: 96, height: 96))
    let dpad = ResolvedControl(control: OverlayControl(id: "dpad", kind: .dpad(up: OverlayInputID(system: .SNES, token: "up"),
                                                                                 down: OverlayInputID(system: .SNES, token: "down"),
                                                                                 left: OverlayInputID(system: .SNES, token: "left"),
                                                                                 right: OverlayInputID(system: .SNES, token: "right")),
                                                       frame: .zero, shape: .cross, paletteSlot: .dpad),
                               frame: CGRect(x: 0, y: 0, width: 150, height: 150), hitFrame: CGRect(x: -20, y: -20, width: 190, height: 190))

    @Test("Finger inside a draw frame wins over an overlapping hit frame")
    func drawFrameWins() {
        let hits = OverlayHitTester.hits(at: [CGPoint(x: 152, y: 128)], controls: [a, b], previousDPad: [:])
        #expect(hits == [.control(id: "b")])
    }

    @Test("In the overlap of two hit frames the nearest centre wins")
    func nearestCentre() {
        let hits = OverlayHitTester.hits(at: [CGPoint(x: 140, y: 85)], controls: [a, b], previousDPad: [:])
        #expect(hits == [.control(id: "a")])
    }

    @Test("Multiple touches produce the union")
    func union() {
        let hits = OverlayHitTester.hits(at: [CGPoint(x: 110, y: 110), CGPoint(x: 190, y: 110)], controls: [a, b], previousDPad: [:])
        #expect(hits == [.control(id: "a"), .control(id: "b")])
    }

    @Test("D-pad: centre is dead, cardinals and diagonals resolve")
    func dpadOctants() {
        let f = dpad.frame
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 75, y: 75), in: f, previous: []) == [])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 75, y: 10), in: f, previous: []) == [.up])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 140, y: 75), in: f, previous: []) == [.right])
        #expect(OverlayHitTester.dpadDirections(point: CGPoint(x: 135, y: 15), in: f, previous: []) == [.up, .right])
    }

    @Test("D-pad hysteresis keeps the previous direction near a boundary")
    func dpadHysteresis() {
        let f = dpad.frame
        // 22.5° is the up/up-right boundary; 26° sits just past it on the up-right side.
        let angle = 26.0 * .pi / 180
        let p = CGPoint(x: 75 + 60 * sin(angle), y: 75 - 60 * cos(angle))
        #expect(OverlayHitTester.dpadDirections(point: p, in: f, previous: [.up]) == [.up])
        #expect(OverlayHitTester.dpadDirections(point: p, in: f, previous: []) == [.up, .right])
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement the hit tester**

```swift
// Touch/OverlayHitTester.swift
import Foundation
import CoreGraphics

public enum OverlayDPadDirection: Hashable, Sendable, CaseIterable { case up, down, left, right }

public enum OverlayHit: Hashable, Sendable {
    case control(id: String)
    case dpad(id: String, OverlayDPadDirection)
}

public enum OverlayHitTester {
    public static let deadZoneFraction: CGFloat = 0.18
    public static let hysteresisDegrees: CGFloat = 8

    public static func hits(at points: [CGPoint], controls: [ResolvedControl],
                            previousDPad: [String: Set<OverlayDPadDirection>]) -> Set<OverlayHit> {
        var result = Set<OverlayHit>()
        for p in points {
            guard let target = topControl(at: p, in: controls) else { continue }
            if case .dpad = target.control.kind {
                let dirs = dpadDirections(point: p, in: target.frame, previous: previousDPad[target.id] ?? [])
                for d in dirs { result.insert(.dpad(id: target.id, d)) }
            } else {
                result.insert(.control(id: target.id))
            }
        }
        return result
    }

    /// Finger inside a draw frame wins; otherwise the nearest centre among hit frames.
    public static func topControl(at p: CGPoint, in controls: [ResolvedControl]) -> ResolvedControl? {
        if let inside = controls.first(where: { $0.frame.contains(p) }) { return inside }
        return controls.filter { $0.hitFrame.contains(p) }
            .min { a, b in distance(p, a.frame.center) < distance(p, b.frame.center) }
    }

    public static func dpadDirections(point: CGPoint, in frame: CGRect, previous: Set<OverlayDPadDirection>) -> Set<OverlayDPadDirection> {
        let dx = point.x - frame.midX
        let dy = point.y - frame.midY
        let radius = min(frame.width, frame.height) / 2
        guard hypot(dx, dy) > radius * deadZoneFraction else { return [] }
        // 0° = up, clockwise.
        var deg = atan2(dx, -dy) * 180 / .pi
        if deg < 0 { deg += 360 }
        let hyst = hysteresisDegrees
        // Each octant is 45° wide, centred on 0, 45, 90, …
        func octant(_ d: CGFloat) -> Int { Int(((d + 22.5).truncatingRemainder(dividingBy: 360)) / 45) % 8 }
        let current = octant(deg)
        let previousOctant = previous.isEmpty ? nil : octantIndex(of: previous)
        if let prev = previousOctant, prev != current {
            // Stay on the previous octant while within hysteresis of its boundary.
            let prevCentre = CGFloat(prev) * 45
            var delta = abs(deg - prevCentre); if delta > 180 { delta = 360 - delta }
            if delta <= 22.5 + hyst { return directions(forOctant: prev) }
        }
        return directions(forOctant: current)
    }

    static func directions(forOctant o: Int) -> Set<OverlayDPadDirection> {
        switch o {
        case 0: return [.up];            case 1: return [.up, .right];   case 2: return [.right]; case 3: return [.down, .right]
        case 4: return [.down];          case 5: return [.down, .left];  case 6: return [.left];  default: return [.up, .left]
        }
    }
    static func octantIndex(of dirs: Set<OverlayDPadDirection>) -> Int? {
        (0..<8).first { directions(forOctant: $0) == dirs }
    }
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }
```

- [ ] **Step 4: Implement the UIKit surfaces**

```swift
// Touch/OverlayTouchCluster.swift
#if canImport(UIKit)
import UIKit

/// One multi-touch surface over a group of buttons and d-pads. Each event recomputes the
/// union of hits across all live touches and emits only when the set changes.
public final class OverlayTouchCluster: UIView {
    public var controls: [ResolvedControl] = []
    /// Frame conversion: controls are in canvas points; the view may be offset. Set by the host.
    public var canvasOrigin: CGPoint = .zero
    public var onChange: ((Set<OverlayHit>) -> Void)?

    private var live: [ObjectIdentifier: CGPoint] = [:]   // live touches, not @State (perf)
    private var current = Set<OverlayHit>()
    private var dpadState: [String: Set<OverlayDPadDirection>] = [:]

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let canvasPoint = CGPoint(x: point.x + canvasOrigin.x, y: point.y + canvasOrigin.y)
        return OverlayHitTester.topControl(at: canvasPoint, in: controls) != nil
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches); recompute() }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches); recompute() }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { untrack(touches); recompute() }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { untrack(touches); recompute() }

    /// Release everything (view removal, edit mode, rotation).
    public func releaseAll() { live.removeAll(); recompute() }

    private func track(_ touches: Set<UITouch>) {
        for t in touches {
            let p = t.location(in: self)
            live[ObjectIdentifier(t)] = CGPoint(x: p.x + canvasOrigin.x, y: p.y + canvasOrigin.y)
        }
    }
    private func untrack(_ touches: Set<UITouch>) { for t in touches { live[ObjectIdentifier(t)] = nil } }

    private func recompute() {
        let hits = OverlayHitTester.hits(at: Array(live.values), controls: controls, previousDPad: dpadState)
        var next: [String: Set<OverlayDPadDirection>] = [:]
        for case let .dpad(id, d) in hits { next[id, default: []].insert(d) }
        dpadState = next
        guard hits != current else { return }
        current = hits
        onChange?(hits)
    }
}

/// Single-touch surface for sticks, triggers, stylus, pointer, trackpad. Reports normalized
/// (0…1, clamped) positions within its bounds.
public final class OverlaySingleTouchSurface: UIView {
    public var onBegan: ((CGPoint) -> Void)?
    public var onMoved: ((CGPoint) -> Void)?
    public var onEnded: (() -> Void)?
    private var tracking: UITouch?

    public override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = false; backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking == nil, let t = touches.first else { return }
        tracking = t; onBegan?(normalized(t))
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = tracking, touches.contains(t) else { return }
        onMoved?(normalized(t))
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }
    public func releaseAll() { if tracking != nil { tracking = nil; onEnded?() } }

    private func finish(_ touches: Set<UITouch>) {
        guard let t = tracking, touches.contains(t) else { return }
        tracking = nil; onEnded?()
    }
    private func normalized(_ t: UITouch) -> CGPoint {
        let p = t.location(in: self)
        guard bounds.width > 0, bounds.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: min(max(p.x / bounds.width, 0), 1), y: min(max(p.y / bounds.height, 0), 1))
    }
}
#endif
```

- [ ] **Step 5: Run tests, expect PASS**
- [ ] **Step 6: Commit** — `feat(overlay): hit tester with d-pad octants and multi-touch surfaces`

---

### Task 11: Input sink, group view and host view

**Files:**
- Create: `Render/OverlayInputSink.swift`
- Create: `Render/OverlayPressedState.swift`
- Create: `Render/OverlayGroupView.swift`
- Create: `Render/OverlayHostView.swift`
- Test: `Tests/PVTouchOverlayTests/OverlayHostDispatchTests.swift`

**Interfaces:**
- Produces:
```swift
public protocol OverlayInputSink: AnyObject {
    func overlayPress(_ id: OverlayInputID)
    func overlayRelease(_ id: OverlayInputID)
    func overlayStick(_ side: OverlayStickSide, x: Float, y: Float)        // -1…1, +y = up
    func overlayAnalogTrigger(_ id: OverlayInputID, value: Float)        // 0…1
    func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase)
    func overlayAction(_ action: OverlayAction)
    func overlayHardwareSwitch(descriptorID: String, isOn: Bool)
}
public enum OverlaySurfacePhase { case began, moved, ended }
```
  - `@Observable final class OverlayPressedState { var pressed: Set<String> }` (per group), `@Observable final class OverlayKnobState { var offset: CGSize }`.
  - `struct OverlayHostView: View` with `init(layout: OverlayLayout, binding: SystemOverlayBinding, style: OverlayStyle, globalOpacity: Double, sink: any OverlayInputSink, editing: Bool)`.
  - `enum OverlayHaptics { static func press(intensity: Double) }`.
  - `final class OverlayHitDispatcher` (pure, testable): turns `Set<OverlayHit>` deltas into sink calls, releases before presses.

- [ ] **Step 1: Failing test for the dispatcher**

```swift
import Foundation
import Testing
import PVPrimitives
@testable import PVTouchOverlay

final class RecordingSink: OverlayInputSink {
    var log: [String] = []
    func overlayPress(_ id: OverlayInputID) { log.append("press \(id.token)") }
    func overlayRelease(_ id: OverlayInputID) { log.append("release \(id.token)") }
    func overlayStick(_ side: OverlayStickSide, x: Float, y: Float) { log.append("stick \(side.rawValue) \(x) \(y)") }
    func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) { log.append("trigger \(id.token) \(value)") }
    func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) { log.append("surface \(role.rawValue) \(phase)") }
    func overlayAction(_ action: OverlayAction) { log.append("action \(action.rawValue)") }
    func overlayHardwareSwitch(descriptorID: String, isOn: Bool) { log.append("switch \(descriptorID) \(isOn)") }
}

@Suite("OverlayHitDispatcher")
struct OverlayHostDispatchTests {
    let snes = SystemIdentifier.SNES
    var controls: [OverlayControl] {
        [OverlayControl(id: "a", kind: .button(OverlayInputID(system: snes, token: "a")), frame: .zero, shape: .circle, paletteSlot: .primary),
         OverlayControl(id: "b", kind: .button(OverlayInputID(system: snes, token: "b")), frame: .zero, shape: .circle, paletteSlot: .secondary),
         OverlayControl(id: "dpad", kind: .dpad(up: OverlayInputID(system: snes, token: "up"), down: OverlayInputID(system: snes, token: "down"),
                                                 left: OverlayInputID(system: snes, token: "left"), right: OverlayInputID(system: snes, token: "right")),
                        frame: .zero, shape: .cross, paletteSlot: .dpad),
         OverlayControl(id: "l", kind: .analogTrigger(OverlayInputID(system: snes, token: "l")), frame: .zero, shape: .bar, paletteSlot: .utility),
         OverlayControl(id: "menu", kind: .action(.menu), frame: .zero, shape: .pill, paletteSlot: .utility)]
    }

    @Test("Releases are emitted before presses and only deltas are sent")
    func deltas() {
        let sink = RecordingSink()
        let d = OverlayHitDispatcher(controls: controls, sink: sink)
        d.apply([.control(id: "a")])
        d.apply([.control(id: "a"), .control(id: "b")])
        d.apply([.control(id: "b")])
        #expect(sink.log == ["press a", "press b", "release a"])
    }

    @Test("D-pad directions map to their tokens and a diagonal presses two")
    func dpad() {
        let sink = RecordingSink()
        let d = OverlayHitDispatcher(controls: controls, sink: sink)
        d.apply([.dpad(id: "dpad", .up), .dpad(id: "dpad", .right)])
        #expect(Set(sink.log) == ["press up", "press right"])
        d.apply([])
        #expect(Set(sink.log.suffix(2)) == ["release up", "release right"])
    }

    @Test("Analog triggers send 1 then 0; actions fire on touch-down only")
    func triggerAndAction() {
        let sink = RecordingSink()
        let d = OverlayHitDispatcher(controls: controls, sink: sink)
        d.apply([.control(id: "l"), .control(id: "menu")])
        d.apply([])
        #expect(sink.log == ["trigger l 1.0", "action menu", "trigger l 0.0"])
    }

    @Test("releaseAll clears held inputs")
    func releaseAll() {
        let sink = RecordingSink()
        let d = OverlayHitDispatcher(controls: controls, sink: sink)
        d.apply([.control(id: "a")])
        d.releaseAll()
        #expect(sink.log == ["press a", "release a"])
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement sink protocol, dispatcher, state**

```swift
// Render/OverlayInputSink.swift
import Foundation
import CoreGraphics

public enum OverlaySurfacePhase: Sendable { case began, moved, ended }

public protocol OverlayInputSink: AnyObject {
    func overlayPress(_ id: OverlayInputID)
    func overlayRelease(_ id: OverlayInputID)
    func overlayStick(_ side: OverlayStickSide, x: Float, y: Float)
    func overlayAnalogTrigger(_ id: OverlayInputID, value: Float)
    func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase)
    func overlayAction(_ action: OverlayAction)
    func overlayHardwareSwitch(descriptorID: String, isOn: Bool)
}

/// Turns hit-set deltas into sink calls. Releases first, then presses, so a shared token
/// held by two controls stays down until both release.
public final class OverlayHitDispatcher {
    private let controls: [String: OverlayControl]
    private weak var sink: (any OverlayInputSink)?
    private var current = Set<OverlayHit>()

    public init(controls: [OverlayControl], sink: any OverlayInputSink) {
        self.controls = Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0) })
        self.sink = sink
    }

    public func apply(_ hits: Set<OverlayHit>) {
        let released = current.subtracting(hits)
        let pressed = hits.subtracting(current)
        current = hits
        for hit in released { emit(hit, down: false) }
        for hit in pressed { emit(hit, down: true) }
    }

    public func releaseAll() { apply([]) }

    private func emit(_ hit: OverlayHit, down: Bool) {
        guard let sink else { return }
        switch hit {
        case .dpad(let id, let dir):
            guard case .dpad(let up, let dn, let lf, let rt)? = controls[id]?.kind else { return }
            let token = [OverlayDPadDirection.up: up, .down: dn, .left: lf, .right: rt][dir]!
            down ? sink.overlayPress(token) : sink.overlayRelease(token)
        case .control(let id):
            guard let kind = controls[id]?.kind else { return }
            switch kind {
            case .button(let t): down ? sink.overlayPress(t) : sink.overlayRelease(t)
            case .analogTrigger(let t): sink.overlayAnalogTrigger(t, value: down ? 1 : 0)
            case .action(let a): if down { sink.overlayAction(a) }
            case .stick, .touchSurface, .hardwareSwitch, .dpad: break   // handled by their own surfaces/views
            }
        }
    }
}
```

```swift
// Render/OverlayPressedState.swift
import Foundation
import Observation
import CoreGraphics

@Observable public final class OverlayPressedState {
    public var pressed: Set<String> = []
    public init() {}
}

@Observable public final class OverlayKnobState {
    public var offset: CGSize = .zero
    public init() {}
}
```

- [ ] **Step 4: Implement the group view and host**

```swift
// Render/OverlayGroupView.swift
#if canImport(UIKit)
import SwiftUI
import UIKit

/// UIKit cluster surface bridged into SwiftUI. Controls are in canvas points; the
/// representable is laid out at the group's frame, so `canvasOrigin` is the group origin.
struct OverlayClusterRepresentable: UIViewRepresentable {
    let controls: [ResolvedControl]
    let origin: CGPoint
    let onChange: (Set<OverlayHit>) -> Void
    func makeUIView(context: Context) -> OverlayTouchCluster {
        let v = OverlayTouchCluster(frame: .zero); v.onChange = onChange; return v
    }
    func updateUIView(_ v: OverlayTouchCluster, context: Context) {
        v.controls = controls; v.canvasOrigin = origin; v.onChange = onChange
    }
    static func dismantleUIView(_ v: OverlayTouchCluster, coordinator: ()) { v.releaseAll() }
}

struct OverlaySurfaceRepresentable: UIViewRepresentable {
    let onBegan: (CGPoint) -> Void
    let onMoved: (CGPoint) -> Void
    let onEnded: () -> Void
    func makeUIView(context: Context) -> OverlaySingleTouchSurface {
        let v = OverlaySingleTouchSurface(frame: .zero)
        v.onBegan = onBegan; v.onMoved = onMoved; v.onEnded = onEnded
        return v
    }
    func updateUIView(_ v: OverlaySingleTouchSurface, context: Context) {
        v.onBegan = onBegan; v.onMoved = onMoved; v.onEnded = onEnded
    }
    static func dismantleUIView(_ v: OverlaySingleTouchSurface, coordinator: ()) { v.releaseAll() }
}

/// Draws one resolved group: art layer (never redraws on press) + touch layer.
struct OverlayGroupView: View {
    let group: ResolvedGroup
    let palette: OverlayPalette
    let style: OverlayStyle
    let dispatcher: OverlayHitDispatcher
    let sink: any OverlayInputSink
    let hapticIntensity: Double
    @State private var pressedState = OverlayPressedState()
    @State private var knob = OverlayKnobState()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(group.controls) { rc in
                controlArt(rc)
                    .frame(width: rc.frame.width, height: rc.frame.height)
                    .offset(x: rc.frame.minX - group.frame.minX, y: rc.frame.minY - group.frame.minY)
                    .allowsHitTesting(false)
            }
            touchLayer
        }
        .frame(width: group.frame.width, height: group.frame.height)
        .opacity(group.opacity)
    }

    @ViewBuilder private func controlArt(_ rc: ResolvedControl) -> some View {
        let spec = OverlayArtSpec(shape: rc.control.shape, color: palette.color(for: rc.control.paletteSlot),
                                  labelColor: palette.label, style: style,
                                  pressed: pressedState.pressed.contains(rc.id), label: rc.control.label)
        if case .stick = rc.control.kind {
            OverlayStickArt(spec: spec, knob: knob).equatable()
        } else {
            OverlayControlArt(spec: spec).equatable()
        }
    }

    @ViewBuilder private var touchLayer: some View {
        let clusterControls = group.controls.filter { rc in
            switch rc.control.kind { case .stick, .touchSurface, .hardwareSwitch: return false; default: return true }
        }
        if !clusterControls.isEmpty {
            OverlayClusterRepresentable(controls: clusterControls, origin: group.frame.origin) { hits in
                let before = pressedState.pressed
                dispatcher.apply(hits)
                var now = Set<String>()
                for h in hits { switch h { case .control(let id): now.insert(id); case .dpad(let id, _): now.insert(id) } }
                if now != before {
                    if before.isEmpty && !now.isEmpty { OverlayHaptics.press(intensity: hapticIntensity) }
                    pressedState.pressed = now
                }
            }
        }
        ForEach(group.controls.filter { if case .stick = $0.control.kind { return true } else { return false } }) { rc in
            if case .stick(let side, _) = rc.control.kind {
                OverlaySurfaceRepresentable(
                    onBegan: { p in moveStick(side, p, rc) },
                    onMoved: { p in moveStick(side, p, rc) },
                    onEnded: { knob.offset = .zero; sink.overlayStick(side, x: 0, y: 0) })
                .frame(width: rc.hitFrame.width, height: rc.hitFrame.height)
                .offset(x: rc.hitFrame.minX - group.frame.minX, y: rc.hitFrame.minY - group.frame.minY)
            }
        }
    }

    private func moveStick(_ side: OverlayStickSide, _ p: CGPoint, _ rc: ResolvedControl) {
        // p is normalized in the hit frame; convert to -1…1 about the centre, clamp to unit circle.
        var x = Float((p.x - 0.5) * 2), y = Float((0.5 - p.y) * 2)
        let mag = hypotf(x, y)
        if mag > 1 { x /= mag; y /= mag }
        let travel = rc.frame.width * 0.3
        knob.offset = CGSize(width: CGFloat(x) * travel, height: -CGFloat(y) * travel)
        sink.overlayStick(side, x: x, y: y)
    }
}

/// Stick art: static ring + a knob that follows `knob.offset` (only this view re-renders on move).
struct OverlayStickArt: View, Equatable {
    let spec: OverlayArtSpec
    let knob: OverlayKnobState
    static func == (l: OverlayStickArt, r: OverlayStickArt) -> Bool { l.spec == r.spec }
    var body: some View {
        ZStack {
            OverlayControlArt(spec: spec)
            OverlayKnobView(color: spec.color, knob: knob)
        }
    }
}
struct OverlayKnobView: View {
    let color: OverlayColor
    let knob: OverlayKnobState
    var body: some View {
        GeometryReader { geo in
            Circle().fill(Color(color).opacity(0.9))
                .frame(width: geo.size.width * 0.45, height: geo.size.height * 0.45)
                .position(x: geo.size.width / 2 + knob.offset.width, y: geo.size.height / 2 + knob.offset.height)
        }
    }
}

public enum OverlayHaptics {
    private static let generator = UIImpactFeedbackGenerator(style: .medium)
    public static func press(intensity: Double) {
        guard intensity > 0 else { return }
        generator.impactOccurred(intensity: min(max(intensity, 0.1), 1))
    }
}
#endif
```

```swift
// Render/OverlayHostView.swift
#if canImport(UIKit)
import SwiftUI

/// Root overlay view. Lays out on the full-screen canvas; the caller passes a layout
/// already resolved for that canvas.
public struct OverlayHostView: View {
    public let layout: OverlayLayout
    public let binding: SystemOverlayBinding
    public let style: OverlayStyle
    public let globalOpacity: Double
    public let hapticIntensity: Double
    public let sink: any OverlayInputSink
    public let editing: Bool
    private let dispatcher: OverlayHitDispatcher

    public init(layout: OverlayLayout, binding: SystemOverlayBinding, style: OverlayStyle, globalOpacity: Double,
                hapticIntensity: Double, sink: any OverlayInputSink, editing: Bool = false) {
        self.layout = layout; self.binding = binding; self.style = style; self.globalOpacity = globalOpacity
        self.hapticIntensity = hapticIntensity; self.sink = sink; self.editing = editing
        self.dispatcher = OverlayHitDispatcher(controls: layout.groups.flatMap { $0.group.controls }, sink: sink)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.groups) { g in
                if g.group.controls.contains(where: { if case .touchSurface = $0.kind { return true } else { return false } }) {
                    surface(g)
                } else {
                    OverlayGroupView(group: g, palette: binding.palette, style: style, dispatcher: dispatcher,
                                     sink: sink, hapticIntensity: hapticIntensity)
                        .offset(x: g.frame.minX, y: g.frame.minY)
                }
            }
        }
        .opacity(globalOpacity)
        .allowsHitTesting(!editing)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func surface(_ g: ResolvedGroup) -> some View {
        if let rc = g.controls.first, case .touchSurface(let role) = rc.control.kind {
            OverlaySurfaceRepresentable(
                onBegan: { p in sink.overlaySurface(role, normalized: p, phase: .began) },
                onMoved: { p in sink.overlaySurface(role, normalized: p, phase: .moved) },
                onEnded: { sink.overlaySurface(role, normalized: .zero, phase: .ended) })
            .frame(width: rc.frame.width, height: rc.frame.height)
            .offset(x: rc.frame.minX, y: rc.frame.minY)
        }
    }
}
#endif
```

- [ ] **Step 5: Run tests, expect PASS; build the package for iOS Simulator and tvOS Simulator** (`-destination 'generic/platform=tvOS Simulator'`) to prove the UIKit guards hold.
- [ ] **Step 6: Commit** — `feat(overlay): input sink, hit dispatcher, group and host views`

---

### Task 12: Layout store and edit session

**Files:**
- Create: `Store/OverlayLayoutStore.swift`
- Create: `Store/OverlayEditSession.swift`
- Test: `Tests/PVTouchOverlayTests/OverlayLayoutStoreTests.swift`, `Tests/PVTouchOverlayTests/OverlayEditSessionTests.swift`

**Interfaces:**
- Produces:
```swift
public struct OverlayLayoutFile: Codable, Equatable { var version: Int; var layouts: [String: [String: GroupOverride]]; var games: [String: [String: [String: GroupOverride]]] }
@MainActor public final class OverlayLayoutStore: ObservableObject {
    public static let currentVersion = 1
    public static let fileName = "touch_overlay_layout_v1.json"
    @Published public private(set) var revision: Int
    public init(fileURL: URL)                                   // tests pass a temp URL
    public static let shared: OverlayLayoutStore                // Application Support URL
    public func overrides(for key: String, gameMD5: String?) -> OverlayLayoutOverrides   // per-game → pad-kind → empty
    public func set(_ overrides: OverlayLayoutOverrides, for key: String, gameMD5: String?)
    public func reset(key: String, gameMD5: String?)
    public func snapshot() -> OverlayLayoutFile
    public func restore(_ file: OverlayLayoutFile)
}
public final class OverlayEditSession { init(store:key:gameMD5:); func record(); func undo() -> Bool; func redo() -> Bool; var canUndo/canRedo; func cancel(); func commit() }
```

- [ ] **Step 1: Failing tests**

```swift
import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayLayoutStore") @MainActor
struct OverlayLayoutStoreTests {
    func tempStore() -> OverlayLayoutStore {
        OverlayLayoutStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }
    let key = "com.provenance.snes.standard.portrait"
    let move = OverlayLayoutOverrides(groups: ["face": GroupOverride(center: AnchoredCenter(h: .max, x: 50, v: .max, y: 60), scale: nil, opacity: nil, buttons: [:])])

    @Test("Per-game overrides win over pad-kind overrides, which win over empty")
    func fallback() {
        let s = tempStore()
        #expect(s.overrides(for: key, gameMD5: "abc") == .empty)
        s.set(move, for: key, gameMD5: nil)
        #expect(s.overrides(for: key, gameMD5: "abc") == move)
        var perGame = move; perGame.groups["face"]?.opacity = 0.4
        s.set(perGame, for: key, gameMD5: "abc")
        #expect(s.overrides(for: key, gameMD5: "abc") == perGame)
        #expect(s.overrides(for: key, gameMD5: "other") == move)
    }

    @Test("Writes persist to disk and reload")
    func persists() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = OverlayLayoutStore(fileURL: url)
        a.set(move, for: key, gameMD5: nil)
        let b = OverlayLayoutStore(fileURL: url)
        #expect(b.overrides(for: key, gameMD5: nil) == move)
        #expect(b.snapshot().version == OverlayLayoutStore.currentVersion)
    }

    @Test("Reset removes only the requested layer and bumps revision")
    func reset() {
        let s = tempStore()
        s.set(move, for: key, gameMD5: nil)
        s.set(move, for: key, gameMD5: "abc")
        let rev = s.revision
        s.reset(key: key, gameMD5: "abc")
        #expect(s.overrides(for: key, gameMD5: "abc") == move)   // falls back to pad-kind layer
        s.reset(key: key, gameMD5: nil)
        #expect(s.overrides(for: key, gameMD5: "abc") == .empty)
        #expect(s.revision > rev)
    }
}

@Suite("OverlayEditSession") @MainActor
struct OverlayEditSessionTests {
    @Test("Undo and redo walk store snapshots; cancel restores the entry state")
    func undoRedo() {
        let store = OverlayLayoutStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        let key = "com.provenance.snes.standard.portrait"
        let session = OverlayEditSession(store: store, key: key, gameMD5: nil)
        let o1 = OverlayLayoutOverrides(groups: ["face": GroupOverride(center: nil, scale: CGSize(width: 1.2, height: 1.2), opacity: nil, buttons: [:])])
        let o2 = OverlayLayoutOverrides(groups: ["face": GroupOverride(center: nil, scale: CGSize(width: 1.5, height: 1.5), opacity: nil, buttons: [:])])
        session.record(); store.set(o1, for: key, gameMD5: nil)
        session.record(); store.set(o2, for: key, gameMD5: nil)
        #expect(session.canUndo)
        #expect(session.undo()); #expect(store.overrides(for: key, gameMD5: nil) == o1)
        #expect(session.undo()); #expect(store.overrides(for: key, gameMD5: nil) == .empty)
        #expect(!session.undo())
        #expect(session.redo()); #expect(store.overrides(for: key, gameMD5: nil) == o1)
        session.cancel()
        #expect(store.overrides(for: key, gameMD5: nil) == .empty)
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**

```swift
// Store/OverlayLayoutStore.swift
import Foundation
import Combine
import PVLogging

public struct OverlayLayoutFile: Codable, Equatable, Sendable {
    public var version: Int
    public var layouts: [String: [String: GroupOverride]]
    public var games: [String: [String: [String: GroupOverride]]]
    public static let empty = OverlayLayoutFile(version: OverlayLayoutStore.currentVersion, layouts: [:], games: [:])
}

@MainActor
public final class OverlayLayoutStore: ObservableObject {
    public static let currentVersion = 1
    public static let fileName = "touch_overlay_layout_v1.json"
    public static let shared: OverlayLayoutStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return OverlayLayoutStore(fileURL: dir.appendingPathComponent(fileName))
    }()

    @Published public private(set) var revision: Int = 0
    private let fileURL: URL
    private var file: OverlayLayoutFile

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(OverlayLayoutFile.self, from: data),
           decoded.version == Self.currentVersion {
            file = decoded
        } else {
            file = .empty
        }
    }

    public func overrides(for key: String, gameMD5: String?) -> OverlayLayoutOverrides {
        if let md5 = gameMD5, let g = file.games[md5]?[key] { return OverlayLayoutOverrides(groups: g) }
        if let l = file.layouts[key] { return OverlayLayoutOverrides(groups: l) }
        return .empty
    }

    public func set(_ overrides: OverlayLayoutOverrides, for key: String, gameMD5: String?) {
        if let md5 = gameMD5 { file.games[md5, default: [:]][key] = overrides.groups }
        else { file.layouts[key] = overrides.groups }
        persist()
    }

    public func reset(key: String, gameMD5: String?) {
        if let md5 = gameMD5 { file.games[md5]?[key] = nil; if file.games[md5]?.isEmpty == true { file.games[md5] = nil } }
        else { file.layouts[key] = nil }
        persist()
    }

    public func snapshot() -> OverlayLayoutFile { file }
    public func restore(_ snapshot: OverlayLayoutFile) { file = snapshot; persist() }

    private func persist() {
        revision &+= 1
        do {
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try enc.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            ELOG("OverlayLayoutStore: failed to write \(fileURL.lastPathComponent): \(error)")
        }
    }
}
```

```swift
// Store/OverlayEditSession.swift
import Foundation

/// Undo/redo over whole-store snapshots for one edit session. History is not persisted.
@MainActor
public final class OverlayEditSession {
    private let store: OverlayLayoutStore
    public let key: String
    public let gameMD5: String?
    private let entrySnapshot: OverlayLayoutFile
    private var undoStack: [OverlayLayoutFile] = []
    private var redoStack: [OverlayLayoutFile] = []

    public init(store: OverlayLayoutStore, key: String, gameMD5: String?) {
        self.store = store; self.key = key; self.gameMD5 = gameMD5
        self.entrySnapshot = store.snapshot()
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call before a mutation.
    public func record() { undoStack.append(store.snapshot()); redoStack.removeAll() }

    @discardableResult public func undo() -> Bool {
        guard let prev = undoStack.popLast() else { return false }
        redoStack.append(store.snapshot()); store.restore(prev); return true
    }
    @discardableResult public func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(store.snapshot()); store.restore(next); return true
    }
    public func cancel() { store.restore(entrySnapshot); undoStack.removeAll(); redoStack.removeAll() }
    public func commit() { undoStack.removeAll(); redoStack.removeAll() }
}
```

- [ ] **Step 4: Run tests, expect PASS**
- [ ] **Step 5: Commit** — `feat(overlay): layout store with per-game layer and undoable edit session`

---

### Task 13: Editor view

**Files:**
- Create: `Render/OverlayEditorView.swift`
- Create: `Render/OverlayEditController.swift`
- Test: `Tests/PVTouchOverlayTests/OverlayEditControllerTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor @Observable final class OverlayEditController` with `init(store:key:gameMD5:canvas:)`, `var selectedGroupID: String?`, `var selectedControlID: String?`, `func moveGroup(_ id: String, to center: CGPoint)`, `func scaleGroup(_ id: String, by factor: CGFloat)`, `func setOpacity(_ id: String, _ value: CGFloat)`, `func detachControl(groupID:controlID:)`, `func moveControl(groupID:controlID:by delta: CGPoint)`, `func reattachControl(groupID:controlID:)`, `func resetGroup(_ id:)`, `func resetAll()`, `func undo()`, `func redo()`, `func cancel()`, `func done()`, `var canUndo/canRedo`.
  - `struct OverlayEditorView: View` with `init(controller:layout:binding:style:)` overlaying dashed chrome, handles, inspector and toolbar on top of an `OverlayHostView(editing: true)`.

- [ ] **Step 1: Failing tests (controller only; the view is verified on device)**

```swift
import Foundation
import Testing
@testable import PVTouchOverlay

@Suite("OverlayEditController") @MainActor
struct OverlayEditControllerTests {
    let canvas = OverlayLayoutEngineTests.phonePortrait
    let key = "com.provenance.snes.standard.portrait"
    func make() -> (OverlayEditController, OverlayLayoutStore) {
        let store = OverlayLayoutStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        return (OverlayEditController(store: store, key: key, gameMD5: nil, canvas: canvas), store)
    }

    @Test("Moving a group stores an anchored centre; undo removes it")
    func move() {
        let (c, store) = make()
        c.moveGroup("face", to: CGPoint(x: 330, y: 780))
        let o = store.overrides(for: key, gameMD5: nil).groups["face"]
        #expect(o?.center == AnchoredCenter(h: .max, x: 60, v: .max, y: 64))
        c.undo()
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"] == nil)
    }

    @Test("Scaling multiplies and clamps to the engine range")
    func scale() {
        let (c, store) = make()
        c.scaleGroup("face", by: 1.5); c.scaleGroup("face", by: 1.5)
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.scale == CGSize(width: 2, height: 2))
    }

    @Test("Detach then move records a per-control offset; reattach clears it")
    func detach() {
        let (c, store) = make()
        c.detachControl(groupID: "face", controlID: "a")
        c.moveControl(groupID: "face", controlID: "a", by: CGPoint(x: 10, y: -5))
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.buttons["a"]?.offset == CGPoint(x: 10, y: -5))
        c.reattachControl(groupID: "face", controlID: "a")
        #expect(store.overrides(for: key, gameMD5: nil).groups["face"]?.buttons["a"] == nil)
    }

    @Test("Cancel restores the state at entry")
    func cancel() {
        let (c, store) = make()
        c.setOpacity("face", 0.3)
        c.cancel()
        #expect(store.overrides(for: key, gameMD5: nil) == .empty)
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement the controller**

```swift
// Render/OverlayEditController.swift
import Foundation
import Observation
import CoreGraphics

@MainActor @Observable
public final class OverlayEditController {
    public var selectedGroupID: String?
    public var selectedControlID: String?
    public var detached: Set<String> = []          // "group/control"
    public let canvas: OverlayCanvas
    private let store: OverlayLayoutStore
    private let session: OverlayEditSession
    private let key: String
    private let gameMD5: String?

    public init(store: OverlayLayoutStore, key: String, gameMD5: String?, canvas: OverlayCanvas) {
        self.store = store; self.key = key; self.gameMD5 = gameMD5; self.canvas = canvas
        self.session = OverlayEditSession(store: store, key: key, gameMD5: gameMD5)
        let existing = store.overrides(for: key, gameMD5: gameMD5)
        for (g, o) in existing.groups { for c in o.buttons.keys { detached.insert("\(g)/\(c)") } }
    }

    public var canUndo: Bool { session.canUndo }
    public var canRedo: Bool { session.canRedo }
    public var overrides: OverlayLayoutOverrides { store.overrides(for: key, gameMD5: gameMD5) }

    private func mutate(_ groupID: String, _ body: (inout GroupOverride) -> Void) {
        session.record()
        var all = overrides
        var g = all.groups[groupID] ?? .empty
        body(&g)
        all.groups[groupID] = g
        store.set(all, for: key, gameMD5: gameMD5)
    }

    public func moveGroup(_ id: String, to center: CGPoint) {
        mutate(id) { $0.center = AnchoredCenter.make(center: center, in: canvas) }
    }
    public func scaleGroup(_ id: String, by factor: CGFloat) {
        mutate(id) {
            let s = $0.scale ?? CGSize(width: 1, height: 1)
            $0.scale = OverlayLayoutEngine.clampedScale(CGSize(width: s.width * factor, height: s.height * factor))
        }
    }
    public func setOpacity(_ id: String, _ value: CGFloat) { mutate(id) { $0.opacity = min(max(value, 0.1), 1) } }
    public func detachControl(groupID: String, controlID: String) {
        detached.insert("\(groupID)/\(controlID)")
        mutate(groupID) { if $0.buttons[controlID] == nil { $0.buttons[controlID] = ControlOverride() } }
    }
    public func moveControl(groupID: String, controlID: String, by delta: CGPoint) {
        mutate(groupID) {
            var c = $0.buttons[controlID] ?? ControlOverride()
            c.offset = CGPoint(x: c.offset.x + delta.x, y: c.offset.y + delta.y)
            $0.buttons[controlID] = c
        }
    }
    public func reattachControl(groupID: String, controlID: String) {
        detached.remove("\(groupID)/\(controlID)")
        mutate(groupID) { $0.buttons[controlID] = nil }
    }
    public func resetGroup(_ id: String) {
        session.record()
        var all = overrides; all.groups[id] = nil
        store.set(all, for: key, gameMD5: gameMD5)
        detached = detached.filter { !$0.hasPrefix("\(id)/") }
    }
    public func resetAll() { session.record(); store.reset(key: key, gameMD5: gameMD5); detached.removeAll() }
    public func undo() { session.undo() }
    public func redo() { session.redo() }
    public func cancel() { session.cancel() }
    public func done() { session.commit() }
}
```
Make `OverlayLayoutEngine.clampedScale` `public static`.

- [ ] **Step 4: Implement the editor view**

```swift
// Render/OverlayEditorView.swift
#if canImport(UIKit)
import SwiftUI

/// Edit chrome drawn over a non-interactive `OverlayHostView`. Each group gets a dashed
/// frame, a drag gesture, a corner resize handle and tap-to-select; a floating inspector
/// edits the selection; the toolbar offers Undo/Redo/Reset/Cancel/Done.
public struct OverlayEditorView: View {
    @Bindable var controller: OverlayEditController
    public let layout: OverlayLayout
    public let binding: SystemOverlayBinding
    public let style: OverlayStyle
    public let onFinish: (_ saved: Bool) -> Void
    @State private var dragStartCenter: CGPoint?
    @State private var pinchStart: CGFloat = 1

    public init(controller: OverlayEditController, layout: OverlayLayout, binding: SystemOverlayBinding,
                style: OverlayStyle, onFinish: @escaping (_ saved: Bool) -> Void) {
        self.controller = controller; self.layout = layout; self.binding = binding; self.style = style; self.onFinish = onFinish
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            OverlayHostView(layout: layout, binding: binding, style: style, globalOpacity: 1, hapticIntensity: 0,
                            sink: OverlayNullSink.shared, editing: true)
            ForEach(layout.groups) { g in groupChrome(g) }
            VStack { toolbar; Spacer(); if controller.selectedGroupID != nil { inspector } }
                .padding()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private func groupChrome(_ g: ResolvedGroup) -> some View {
        let selected = controller.selectedGroupID == g.id
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: [6, 4]))
            .foregroundStyle(selected ? Color.yellow : Color.white.opacity(0.7))
            .frame(width: g.frame.width, height: g.frame.height)
            .offset(x: g.frame.minX, y: g.frame.minY)
            .contentShape(Rectangle())
            .onTapGesture { controller.selectedGroupID = g.id; controller.selectedControlID = nil }
            .onTapGesture(count: 2) { controller.resetGroup(g.id) }
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { v in
                    if dragStartCenter == nil { dragStartCenter = CGPoint(x: g.frame.midX, y: g.frame.midY) }
                    if let s = dragStartCenter {
                        controller.moveGroup(g.id, to: CGPoint(x: s.x + v.translation.width, y: s.y + v.translation.height))
                    }
                }
                .onEnded { _ in dragStartCenter = nil })
            .simultaneousGesture(MagnificationGesture()
                .onChanged { m in controller.scaleGroup(g.id, by: m / pinchStart); pinchStart = m }
                .onEnded { _ in pinchStart = 1 })
        // Corner resize handle
        Circle().fill(Color.yellow).frame(width: 22, height: 22)
            .offset(x: g.frame.maxX - 11, y: g.frame.maxY - 11)
            .gesture(DragGesture().onChanged { v in
                let factor = 1 + v.translation.width / max(g.frame.width, 1)
                controller.scaleGroup(g.id, by: factor); pinchStart = 1
            })
        // Detached controls get their own chrome
        ForEach(g.controls.filter { controller.detached.contains("\(g.id)/\($0.id)") }) { rc in
            Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Color.cyan)
                .frame(width: rc.frame.width, height: rc.frame.height)
                .offset(x: rc.frame.minX, y: rc.frame.minY)
                .gesture(DragGesture(minimumDistance: 2).onChanged { v in
                    controller.moveControl(groupID: g.id, controlID: rc.id, by: CGPoint(x: v.translation.width - (v.predictedEndTranslation.width - v.translation.width) * 0, y: v.translation.height))
                })
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Button("Undo") { controller.undo() }.disabled(!controller.canUndo)
            Button("Redo") { controller.redo() }.disabled(!controller.canRedo)
            Button("Reset Pad") { controller.resetAll() }
            Spacer()
            Button("Cancel") { controller.cancel(); onFinish(false) }
            Button("Done") { controller.done(); onFinish(true) }.bold()
        }
        .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var inspector: some View {
        let gid = controller.selectedGroupID ?? ""
        let o = controller.overrides.groups[gid] ?? .empty
        return VStack(alignment: .leading, spacing: 8) {
            Text(gid).font(.headline)
            HStack { Text("Opacity"); Slider(value: Binding(get: { Double(o.opacity ?? 1) }, set: { controller.setOpacity(gid, CGFloat($0)) }), in: 0.1...1) }
            HStack { Text("Scale"); Slider(value: Binding(get: { Double(o.scale?.width ?? 1) },
                                                          set: { controller.scaleGroup(gid, by: CGFloat($0) / (o.scale?.width ?? 1)) }), in: 0.5...2) }
            if let g = layout.groups.first(where: { $0.id == gid }), g.controls.count > 1 {
                ForEach(g.controls) { rc in
                    let key = "\(gid)/\(rc.id)"
                    Toggle("Detach \(rc.control.label ?? rc.id)", isOn: Binding(
                        get: { controller.detached.contains(key) },
                        set: { $0 ? controller.detachControl(groupID: gid, controlID: rc.id) : controller.reattachControl(groupID: gid, controlID: rc.id) }))
                }
            }
        }
        .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Sink used while editing so no input reaches the core.
public final class OverlayNullSink: OverlayInputSink {
    public static let shared = OverlayNullSink()
    public func overlayPress(_ id: OverlayInputID) {}
    public func overlayRelease(_ id: OverlayInputID) {}
    public func overlayStick(_ side: OverlayStickSide, x: Float, y: Float) {}
    public func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) {}
    public func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) {}
    public func overlayAction(_ action: OverlayAction) {}
    public func overlayHardwareSwitch(descriptorID: String, isOn: Bool) {}
}
#endif
```
The detached-control drag must move by the per-event delta, not the cumulative translation: keep a `@State private var lastControlTranslation: CGSize = .zero`, apply `translation - last`, and reset to `.zero` in `onEnded`. Replace the placeholder arithmetic in `moveControl(... by:)` above with that delta. `DragGesture` is unavailable on tvOS; this whole file is already excluded there by the host (Task 14 never mounts it on tvOS) but must still compile: wrap the gesture modifiers in `#if !os(tvOS)`.

- [ ] **Step 5: Run tests, expect PASS; build for iOS and tvOS simulators**
- [ ] **Step 6: Commit** — `feat(overlay): live layout editor with detach, inspector and undo`

---

### Task 14: Mount the overlay in PVUIBase behind an Advanced toggle

**Files:**
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (add keys next to `skinButtonReposition`, ~line 1007)
- Modify: `PVUI/Sources/PVSwiftUI/Settings/Views/AdvancedTogglesView.swift` (toggle row + style picker, near the `skinButtonReposition` row ~line 188)
- Create: `PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/OverlayInputSinkAdapter.swift`
- Create: `PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/ProgrammaticOverlayView.swift`
- Modify: `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/Display/EmulatorWithSkinView.swift` (the `else` branch that calls `defaultControllerSkin()`, ~line 143)
- Modify: `PVUI/Sources/PVUIBase/Controller/PVEmulatorViewController+DeltaSkin.swift` (`isDeltaSkinEnabled`, lines 15-26)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+MetalDualScreen.swift` (add an explicit-rects entry point)
- Test: `PVUI/Tests/PVUIBaseTests/OverlayInputSinkAdapterTests.swift`

**Interfaces:**
- Consumes: `OverlayHostView`, `OverlayInputSink`, `SystemOverlayBindings`, `OverlayLayoutEngine`, `OverlayLayoutStore`, `OverlayStyle`; existing `DeltaSkinInputHandler.buttonPressed/buttonReleased/analogStickMoved/ndsBottomScreenTouched/ndsBottomScreenTouchReleased`, `ViewportLayoutProviderBridge`, `applyMetalDualScreenLayout`.
- Produces: `Defaults.Keys.programmaticOverlay: Key<Bool>` (default `true`), `Defaults.Keys.overlayStyle: Key<OverlayStyle>`, `Defaults.Keys.overlayHapticIntensity: Key<Double>` (default 0.8); `final class OverlayInputSinkAdapter: OverlayInputSink`; `struct ProgrammaticOverlayView: View`; `PVEmulatorViewController.applyMetalDualScreenLayout(outputFrames: [CGRect])`.

- [ ] **Step 1: Failing adapter test**

```swift
// PVUI/Tests/PVUIBaseTests/OverlayInputSinkAdapterTests.swift
import Foundation
import Testing
import PVPrimitives
import PVTouchOverlay
@testable import PVUIBase

@Suite("OverlayInputSinkAdapter") @MainActor
struct OverlayInputSinkAdapterTests {
    final class SpyHandler: DeltaSkinInputHandler {
        var pressed: [String] = [], released: [String] = [], sticks: [(String, Float, Float)] = []
        var ndsTouches: [CGPoint] = [], ndsReleases = 0
        override func buttonPressed(_ buttonId: String) { pressed.append(buttonId) }
        override func buttonReleased(_ buttonId: String) { released.append(buttonId) }
        override func analogStickMoved(_ stickId: String, x: Float, y: Float) { sticks.append((stickId, x, y)) }
        override func ndsBottomScreenTouched(at p: CGPoint) { ndsTouches.append(p) }
        override func ndsBottomScreenTouchReleased() { ndsReleases += 1 }
    }

    @Test("Tokens pass straight through; sticks use the thumbstick ids; actions map to skin function tokens")
    func passthrough() {
        let h = SpyHandler()
        let a = OverlayInputSinkAdapter(handler: h)
        a.overlayPress(OverlayInputID(system: .SNES, token: "a")); a.overlayRelease(OverlayInputID(system: .SNES, token: "a"))
        a.overlayStick(.left, x: 0.5, y: -0.25)
        a.overlayAction(.quickSave); a.overlayAction(.menu)
        #expect(h.pressed == ["a", "quicksave", "menu"])
        #expect(h.released == ["a", "quicksave"])          // menu is handled on press by the handler's menuButtonHandler
        #expect(h.sticks.count == 1 && h.sticks[0].0 == "leftThumbstick" && h.sticks[0].1 == 0.5 && h.sticks[0].2 == -0.25)
    }

    @Test("DS screen surface forwards normalized points and release")
    func dsSurface() {
        let h = SpyHandler()
        let a = OverlayInputSinkAdapter(handler: h)
        a.overlaySurface(.dsScreen, normalized: CGPoint(x: 0.25, y: 0.75), phase: .began)
        a.overlaySurface(.dsScreen, normalized: .zero, phase: .ended)
        #expect(h.ndsTouches == [CGPoint(x: 0.25, y: 0.75)])
        #expect(h.ndsReleases == 1)
    }
}
```
`buttonPressed`, `buttonReleased`, `analogStickMoved`, `ndsBottomScreenTouched`, `ndsBottomScreenTouchReleased` on `DeltaSkinInputHandler` are currently non-`open`/non-overridable internal methods; mark them `open` (the class is `public class`) so the spy can override them. No behaviour change.

- [ ] **Step 2: Run PVUI tests (synced copy), expect FAIL**

- [ ] **Step 3: Settings keys and toggle**

```swift
// PVSettingsModel.swift, next to skinButtonReposition
    /// Programmatic touch overlay (PVTouchOverlay) replaces the generated default skin
    /// and the classic on-screen pad when no packaged skin is selected. iOS only.
    static let programmaticOverlay = Key<Bool>("programmaticOverlay", default: true)
    /// Visual style of the programmatic overlay controls.
    static let overlayStyle = Key<OverlayStyle>("overlayStyle", default: .flat)
    /// 0 disables overlay haptics; 1 is full strength.
    static let overlayHapticIntensity = Key<Double>("overlayHapticIntensity", default: 0.8)
```
`OverlayStyle` already lives in PVSettings (Task 9) and conforms to `Defaults.Serializable`, so the key compiles as written.

In `AdvancedTogglesView.swift` add after the `skinButtonReposition` toggle:

```swift
                PremiumThemedToggle(isOn: $programmaticOverlay) {
                    SettingsRow(title: "Programmatic Touch Overlay",
                                subtitle: "Console-style on-screen controls with a live layout editor. Off uses the classic pad.",
                                icon: .sfSymbol("gamecontroller.fill"))
                }
                Picker("Overlay Style", selection: $overlayStyle) {
                    ForEach(OverlayStyle.allCases) { Text($0.displayName).tag($0) }
                }
```
with `@Default(.programmaticOverlay) var programmaticOverlay` and `@Default(.overlayStyle) var overlayStyle` declared beside the existing `@Default` properties (~line 37). Match the surrounding `SettingsRow` initializer exactly as the neighbouring rows use it.

- [ ] **Step 4: Adapter**

```swift
// PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/OverlayInputSinkAdapter.swift
import Foundation
import PVTouchOverlay

/// Phase 1 bridge: the overlay speaks skin tokens, and `DeltaSkinInputHandler` already
/// dispatches skin tokens to every system's responder protocol.
@MainActor
public final class OverlayInputSinkAdapter: OverlayInputSink {
    private let handler: DeltaSkinInputHandler
    public init(handler: DeltaSkinInputHandler) { self.handler = handler }

    public func overlayPress(_ id: OverlayInputID) { handler.buttonPressed(id.token) }
    public func overlayRelease(_ id: OverlayInputID) { handler.buttonReleased(id.token) }
    public func overlayStick(_ side: OverlayStickSide, x: Float, y: Float) { handler.analogStickMoved(side.token, x: x, y: y) }
    public func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) {
        value > 0 ? handler.buttonPressed(id.token) : handler.buttonReleased(id.token)
    }
    public func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) {
        switch (role, phase) {
        case (.dsScreen, .began), (.dsScreen, .moved): handler.ndsBottomScreenTouched(at: normalized)
        case (.dsScreen, .ended): handler.ndsBottomScreenTouchReleased()
        case (.wiiPointer, _), (.lightGun, _), (.trackpad, _): break   // Wii pointer spec / existing overlays
        }
    }
    public func overlayAction(_ action: OverlayAction) {
        let token: String
        switch action {
        case .menu: handler.buttonPressed("menu"); return             // handler fires menuButtonHandler on press
        case .quickSave: token = "quicksave"
        case .quickLoad: token = "quickload"
        case .fastForward: token = "togglefastforward"
        case .toggleKeyboard: token = "keyboard"
        case .toggleMouse: token = "mouse"
        case .screenshot: token = "screenshot"
        }
        handler.buttonPressed(token); handler.buttonReleased(token)
    }
    public func overlayHardwareSwitch(descriptorID: String, isOn: Bool) {
        // Phase 2 (systems with switches are not in the Phase 1 bindings).
    }
}
```
Verify the exact function tokens in `DeltaSkinInputHandler.swift` lines ~21-41 and ~412-616 (`quicksave`, `quickload`, `togglefastforward`, `screenshot`, keyboard/mouse toggles) and adjust the strings to match; the test asserts `"quicksave"` so update both if the handler differs.

- [ ] **Step 5: The host view**

```swift
// PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/ProgrammaticOverlayView.swift
#if !os(tvOS)
import SwiftUI
import UIKit
import Defaults
import PVPrimitives
import PVEmulatorCore
import PVSettings
import PVTouchOverlay
import PVLogging

/// Mounts `OverlayHostView` in place of the generated default skin, publishes the game
/// viewport through `ViewportLayoutProviderBridge`, and drives the DS dual-screen split.
struct ProgrammaticOverlayView: View {
    let systemId: SystemIdentifier
    let binding: SystemOverlayBinding
    let coreInstance: PVEmulatorCore
    let inputHandler: DeltaSkinInputHandler
    let gameMD5: String?
    /// Called with the resolved screen frames (1 or 2) whenever layout changes.
    let onScreenFrames: ([CGRect]) -> Void

    @ObservedObject private var store = OverlayLayoutStore.shared
    @Default(.overlayStyle) private var style
    @Default(.controllerOpacity) private var globalOpacity
    @Default(.overlayHapticIntensity) private var hapticIntensity
    @Default(.buttonVibration) private var hapticsOn
    @State private var sink: OverlayInputSinkAdapter?
    @State private var viewportBridge: ViewportLayoutProviderBridge?
    @State private var lastFrames: [CGRect] = []
    @State private var editing = false
    @State private var editController: OverlayEditController?
    let padKind: OverlayPadKind

    var body: some View {
        GeometryReader { geo in
            let canvas = OverlayCanvas(size: CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                                                    height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom),
                                       safeArea: OverlayInsets(top: geo.safeAreaInsets.top, left: geo.safeAreaInsets.leading,
                                                               bottom: geo.safeAreaInsets.bottom, right: geo.safeAreaInsets.trailing))
            let key = padKind.storageKey(for: canvas.orientation)
            let template = binding.template(padKind: padKind, orientation: canvas.orientation)
            let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                                     overrides: store.overrides(for: key, gameMD5: gameMD5),
                                                     gameAspect: gameAspect())
            ZStack(alignment: .topLeading) {
                if let sink {
                    OverlayHostView(layout: layout, binding: binding, style: style, globalOpacity: globalOpacity,
                                    hapticIntensity: hapticsOn ? hapticIntensity : 0, sink: sink, editing: editing)
                }
                if editing, let editController {
                    OverlayEditorView(controller: editController, layout: layout, binding: binding, style: style) { _ in
                        editing = false; self.editController = nil
                    }
                }
            }
            .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
            .onAppear {
                sink = OverlayInputSinkAdapter(handler: inputHandler)
                viewportBridge = ViewportLayoutProviderBridge(core: coreInstance, calculateFrame: { _, _, _ in lastFrames.first })
                publish(layout.screenFrames)
            }
            .onChange(of: layout.screenFrames) { _, frames in publish(frames) }
            .onChange(of: store.revision) { _, _ in publish(layout.screenFrames) }
            .onReceive(NotificationCenter.default.publisher(for: .overlayEditLayoutRequested)) { _ in
                editController = OverlayEditController(store: store, key: key, gameMD5: gameMD5, canvas: canvas)
                editing = true
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                editController = OverlayEditController(store: store, key: key, gameMD5: gameMD5, canvas: canvas)
                editing = true
            }
        }
        .ignoresSafeArea()
    }

    private func gameAspect() -> CGFloat {
        let a = coreInstance.aspectSize
        if a.width > 0, a.height > 0, a.width / a.height > 0.5, a.width / a.height < 2.5 { return a.width / a.height }
        return 4.0 / 3.0
    }

    private func publish(_ frames: [CGRect]) {
        guard frames != lastFrames, let first = frames.first, first.width > 0 else { return }
        lastFrames = frames
        viewportBridge?.notifyFrameUpdated(first)
        onScreenFrames(frames)
    }
}

extension Notification.Name {
    /// Posted by the pause menu "Edit Layout" tile. Declared here (PVUIBase) because both poster and observer live in PVUIBase.
    static let overlayEditLayoutRequested = Notification.Name("PVOverlayEditLayoutRequested")
}
#endif
```
The long-press must not fire while a finger is on a control: SwiftUI's `onLongPressGesture` on the ZStack is only reached for touches the UIKit clusters did not claim (their `point(inside:)` rejects empty space), so empty-space long-press works without extra filtering.

- [ ] **Step 6: Mount point in `EmulatorWithSkinView`**

Replace the `else` branch body (currently `defaultControllerSkin().background(Color.clear).onAppear {...}`) with:

```swift
                } else if Defaults[.programmaticOverlay],
                          let systemId, let binding = SystemOverlayBindings.binding(for: systemId) {
                    ProgrammaticOverlayView(systemId: systemId, binding: binding, coreInstance: coreInstance,
                                            inputHandler: inputHandler, gameMD5: game.md5Hash.isEmpty ? nil : game.md5Hash,
                                            onScreenFrames: { frames in
                                                NotificationCenter.default.post(name: .overlayScreenFramesDidChange, object: nil,
                                                                                userInfo: ["frames": frames.map { NSValue(cgRect: $0) }])
                                            },
                                            padKind: OverlayPadKindResolver.padKind(for: systemId, core: coreInstance, gameMD5: game.md5Hash))
                        .onAppear { if !skinRenderComplete { skinRenderComplete = true; onSkinLoaded() } }
                } else {
                    defaultControllerSkin()
                    ... (existing code unchanged)
```
`OverlayPadKindResolver` is Task 15; until then stub it in the same new directory as `static func padKind(for:core:gameMD5:) -> OverlayPadKind { .standard(system) }` with the variant-aware body filled in by Task 15. Declare `Notification.Name.overlayScreenFramesDidChange` next to `overlayEditLayoutRequested`.

- [ ] **Step 7: `isDeltaSkinEnabled` and DS dual-screen**

In `PVEmulatorViewController+DeltaSkin.swift` replace the two `guard` lines after the desktop-input check with:

```swift
        guard Defaults[.skinMode] != .off && core.supportsSkins else { return false }
        // The programmatic overlay covers every bound system without a packaged skin, including
        // explicit-selection cores (Dolphin): a bound system always has an overlay to show.
        if Defaults[.programmaticOverlay],
           let sid = game.system?.systemIdentifier, SystemOverlayBindings.binding(for: sid) != nil {
            return true
        }
        guard core.requiresExplicitSkinSelection else { return true }
        return hasExplicitSkinSelectionForGame
```

In `PVEmulatorViewController+MetalDualScreen.swift`, factor the tail of `applyMetalDualScreenLayout()` (the part after the per-screen source/dest rects are computed, which builds `DualScreenRenderInfo`s, calls `expandMetalViewToFillParent()` and sets `isMetalDualScreenActive`) into `private func installDualScreenLayout(_ infos: [DualScreenRenderInfo])`, then add:

```swift
    /// Dual-screen split driven by explicit view-space output frames (programmatic overlay).
    /// `outputFrames[0]` is the top screen, `[1]` the bottom; sources are the core's real layout
    /// halves exactly as `applyMetalDualScreenLayout()` derives them when a skin has no inputFrame.
    func applyMetalDualScreenLayout(outputFrames: [CGRect]) {
        guard outputFrames.count == 2, canUseMetalDualScreenRendering || isProgrammaticOverlayActive else {
            clearMetalDualScreenLayout(); return
        }
        let sources = defaultDualScreenSourceRects()        // extract from the existing no-inputFrame branch
        let infos = zip(sources, outputFrames).map { DualScreenRenderInfo(sourceRectNative: $0.0, framebufferSize: currentDSFramebufferSize(), viewDestRect: $0.1) }
        installDualScreenLayout(infos)
    }
```
Use the actual `DualScreenRenderInfo` initializer and helper names as they exist after the 2026-10-07 DS fix (read `PVMetalViewController+DualScreen.swift` first; the fix renamed the fields to native-pixel rects plus framebuffer size). `canUseMetalDualScreenRendering` requires "a skin active"; add `isProgrammaticOverlayActive` (true when `Defaults[.programmaticOverlay]` and `currentSkin == nil` and a binding exists) to that gate. Observe `.overlayScreenFramesDidChange` in `PVEmulatorViewController+DeltaSkin.swift`'s `observeAppStateChanges()` neighbourhood and call `applyMetalDualScreenLayout(outputFrames:)` when `frames.count == 2` for `SystemIdentifier.DS`, else `clearMetalDualScreenLayout()`.

- [ ] **Step 8: Run the PVUI tests from the synced copy, expect PASS including the new adapter suite. Build tvOS too:** `xcodebuild build -scheme PVUI-UnitTests -destination 'generic/platform=tvOS Simulator' ...` (the new file is `#if !os(tvOS)`; the mount point must be inside the existing `#if` structure of `EmulatorWithSkinView`; if that file has no platform split at the mount, wrap the new branch in `#if !os(tvOS)`).
- [ ] **Step 9: swiftlint the changed PVUI files; commit** — `feat(overlay): mount the programmatic overlay behind an Advanced toggle`

---

### Task 15: Controller subtype resolution

**Files:**
- Modify: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerLayoutVariant.swift` (read-back + notification)
- Create: `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+LayoutVariant.swift` (**add to `PVCoreBridgeRetro.xcodeproj` — run `python3 Scripts/audits/check_pbxproj_sources.py`**)
- Modify: `Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore.swift` (read-back)
- Create: `PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/OverlayPadKindResolver.swift` (replace Task 14's stub)
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PauseTileMenuViewModel.swift` (+ its view) to add "Controller Layout" and "Edit Layout" tiles
- Test: `PVUI/Tests/PVUIBaseTests/OverlayPadKindResolverTests.swift`

**Interfaces:**
- Produces in PVCoreBridge:
```swift
public protocol ConsoleVariantConfigurable: AnyObject {
    func applyControllerLayoutVariant(_ variantID: String)
    /// The variant the core is actually running, or nil when it cannot tell.
    var currentControllerLayoutVariantID: String? { get }
}
public extension Notification.Name { static let controllerLayoutVariantDidChange = Notification.Name("PVControllerLayoutVariantDidChange") }
```
  (`object` = the core; `userInfo["variantID"]` = String.)
- Produces in PVUIBase: `enum OverlayPadKindResolver { static func padKind(for system: SystemIdentifier, core: PVEmulatorCore, gameMD5: String) -> OverlayPadKind }` with order: per-game override (`Defaults[.controllerLayoutVariantsByGame][md5]`, new `Key<[String: String]>` in `PVSettings/Sources/PVSettings/Settings/ControllerLayoutSettings.swift`) → core read-back → `Defaults.controllerLayoutVariant(forSystemID:)` → `system.defaultControllerLayoutVariant?.id` → `standard`; the result is only used if the binding has a family for it, else the binding's `defaultSubtype`.

- [ ] **Step 1: Failing resolver test**

```swift
import Foundation
import Testing
import Defaults
import PVPrimitives
import PVCoreBridge
import PVEmulatorCore
import PVTouchOverlay
import PVSettings
@testable import PVUIBase

@Suite("OverlayPadKindResolver") @MainActor
struct OverlayPadKindResolverTests {
    final class VariantCore: PVEmulatorCore, ConsoleVariantConfigurable {
        var reported: String?
        func applyControllerLayoutVariant(_ variantID: String) { reported = variantID }
        var currentControllerLayoutVariantID: String? { reported }
    }

    @Test("Order: per-game, core, system setting, default")
    func order() {
        Defaults[.controllerLayoutVariantsBySystem] = [:]
        Defaults[.controllerLayoutVariantsByGame] = [:]
        let core = VariantCore()
        #expect(OverlayPadKindResolver.padKind(for: .Genesis, core: core, gameMD5: "m").subtype == "genesis-3btn")
        Defaults.setControllerLayoutVariant("genesis-6btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(OverlayPadKindResolver.padKind(for: .Genesis, core: core, gameMD5: "m").subtype == "genesis-6btn")
        core.reported = "genesis-3btn"
        #expect(OverlayPadKindResolver.padKind(for: .Genesis, core: core, gameMD5: "m").subtype == "genesis-3btn")
        Defaults[.controllerLayoutVariantsByGame] = ["m": "genesis-6btn"]
        #expect(OverlayPadKindResolver.padKind(for: .Genesis, core: core, gameMD5: "m").subtype == "genesis-6btn")
    }

    @Test("Unknown subtypes fall back to the binding default")
    func unknown() {
        Defaults[.controllerLayoutVariantsByGame] = ["m": "not-a-variant"]
        #expect(OverlayPadKindResolver.padKind(for: .Genesis, core: VariantCore(), gameMD5: "m").subtype == "genesis-3btn")
        Defaults[.controllerLayoutVariantsByGame] = [:]
    }
}
```

- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**

PVCoreBridge: add the read-back requirement and a default `extension ConsoleVariantConfigurable { public var currentControllerLayoutVariantID: String? { nil } }` so existing conformers compile; add the notification constant.

PVSettings `ControllerLayoutSettings.swift`:
```swift
    /// Per-game controller layout variant override, keyed by game MD5.
    static let controllerLayoutVariantsByGame = Key<[String: String]>("controllerLayoutVariantsByGame", default: [:])
```

Resolver:
```swift
// PVUI/Sources/PVUIBase/SwiftUI/TouchOverlay/OverlayPadKindResolver.swift
import Foundation
import Defaults
import PVPrimitives
import PVCoreBridge
import PVEmulatorCore
import PVSettings
import PVTouchOverlay

enum OverlayPadKindResolver {
    static func padKind(for system: SystemIdentifier, core: PVEmulatorCore, gameMD5: String) -> OverlayPadKind {
        guard let binding = SystemOverlayBindings.binding(for: system) else { return .standard(system) }
        let candidates: [String?] = [
            gameMD5.isEmpty ? nil : Defaults[.controllerLayoutVariantsByGame][gameMD5],
            (core as? ConsoleVariantConfigurable)?.currentControllerLayoutVariantID,
            Defaults.controllerLayoutVariant(forSystemID: system.rawValue),
            system.defaultControllerLayoutVariant?.id
        ]
        let subtype = candidates.compactMap { $0 }.first { binding.families[$0] != nil } ?? binding.defaultSubtype
        return OverlayPadKind(system: system, subtype: subtype)
    }
}
```

Thin wrapper (`PVThinLibretroCore+LayoutVariant.swift`):
```swift
import Foundation
import PVCoreBridge
import PVPrimitives

extension PVThinLibretroCore: ConsoleVariantConfigurable {
    /// Genesis Plus GX reports 3-/6-button pads as port devices named "MD Joypad 3 Button" /
    /// "MD Joypad 6 Button" via SET_CONTROLLER_INFO; PCSX-ReARMed uses the core option
    /// `pcsx_rearmed_pad1type` (standard / analog / dualshock / negcon / guncon). Verify both
    /// against the running core's `controllerPortDescriptors` / `_bridge.coreOptions` before relying on them.
    public func applyControllerLayoutVariant(_ variantID: String) {
        switch variantID {
        case "genesis-3btn", "genesis-6btn":
            let wants6 = variantID == "genesis-6btn"
            if let device = controllerPortDescriptors.first?.first(where: { $0.name.contains(wants6 ? "6" : "3") })?.deviceType {
                setDeviceType(device, forPort: 0)
            }
        case "psx-digital": setOptionValue("standard", forKey: "pcsx_rearmed_pad1type")
        case "psx-dualshock": setOptionValue("dualshock", forKey: "pcsx_rearmed_pad1type")
        default: break
        }
        NotificationCenter.default.post(name: .controllerLayoutVariantDidChange, object: self, userInfo: ["variantID": variantID])
    }

    public var currentControllerLayoutVariantID: String? {
        guard let sid = systemIdentifier.flatMap(SystemIdentifier.init(rawValue:)) else { return nil }
        switch sid {
        case .Genesis, .Sega32X, .SegaCD:
            let name = controllerPortDescriptors.first?.first { $0.deviceType == currentDeviceType(forPort: 0) }?.name ?? ""
            return name.contains("6") ? "genesis-6btn" : (name.contains("3") ? "genesis-3btn" : nil)
        case .PSX:
            switch _bridge.coreOptions["pcsx_rearmed_pad1type"] {
            case "standard": return "psx-digital"
            case "analog", "dualshock": return "psx-dualshock"
            default: return nil
            }
        default: return nil
        }
    }
}
```
`setOptionValue(_:forKey:)` must be whatever `PVThinLibretroCore` already exposes for writing a core option at runtime (search `PVThinLibretroCore.swift` for the method `applyPersistedCoreOptions()` uses to push one option; reuse it, do not add a parallel path).

Dolphin: add `public var currentControllerLayoutVariantID: String? { _bridge.currentControllerVariantID() }` if the bridge exposes the applied id (search `applyControllerVariant` in `PVDolphinCore.mm`; if it only stores to an ivar, add a one-line getter there), and post `.controllerLayoutVariantDidChange` at the end of `applyControllerLayoutVariant`.

`ProgrammaticOverlayView` (Task 14) additionally observes `.controllerLayoutVariantDidChange` with `object == coreInstance` and recomputes `padKind` (make `padKind` an `@State` initialised from the resolver and refreshed in the observer).

Pause menu: in `PauseTileMenuViewModel.swift`, where tiles are assembled (the hardware-switch tiles are ~lines 640-660), add when `Defaults[.programmaticOverlay]` and a binding exists: a tile "Edit Layout" that posts `.overlayEditLayoutRequested` and dismisses the menu, and, when `system.availableControllerLayoutVariants != nil`, a tile "Controller Layout" that presents the existing `ControllerLayoutVariantPicker` (from `PVUI/Sources/PVSwiftUI/Settings/Views/ControllerLayoutVariantPickerView.swift`; move it to PVUIBase if PVSwiftUI is not importable from the pause menu) with a "This game / All <system> games" segmented control writing `Defaults[.controllerLayoutVariantsByGame][md5]` or `Defaults.setControllerLayoutVariant(_:forSystemID:)`, then calling `(core as? ConsoleVariantConfigurable)?.applyControllerLayoutVariant(id)`.

- [ ] **Step 4: Run PVUI tests (synced copy), expect PASS. Run `python3 Scripts/audits/check_pbxproj_sources.py` and fix the pbxproj for the new PVLibRetro file. Run the PVCoreBridgeRetro test scheme (CLAUDE.md command) to confirm the thin wrapper still builds.**
- [ ] **Step 5: Commit** — `feat(overlay): resolve controller subtypes from core, game and system settings`

---

### Task 16: Validation, docs and hand-off

**Files:**
- Modify: `CLAUDE.md` (Module Structure list: add `PVTouchOverlay`; Build gotchas: the worktree/PackageBuildInfo note)
- Modify: `docs/superpowers/specs/2026-10-07-programmatic-touch-overlay-design.md` (status line → "Phase 1 implemented")

- [ ] **Step 1: Full package tests** — run the `PVTouchOverlay` test command; expected: every suite passes.
- [ ] **Step 2: Full PVUI tests** from a synced copy; expected `** TEST SUCCEEDED **` with the three new PVUIBase suites included.
- [ ] **Step 3: Simulator app build**: `xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance-Lite (AppStore)" -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO` from the main checkout (not a worktree). Expected: BUILD SUCCEEDED. Then the tvOS variant with `-destination "generic/platform=tvOS Simulator"`.
- [ ] **Step 4: swiftlint** every changed Swift file; `Scripts/audits/check_pbxproj_sources.py`; `python3 Scripts/maint/maint.py status` (no new scripts were added, so nothing should be stale from this work).
- [ ] **Step 5: CLAUDE.md** — add `- **PVTouchOverlay** — Programmatic on-screen controller: layout families, live editor, shared touch primitives` to the module list, and under "Build & toolchain gotchas": "**PVUI cannot build inside a git worktree.** The PackageBuildInfo plugin reads `.git/HEAD`; a worktree's `.git` is a file. Run PVUI tests from an rsync'd copy with a fake `.git/HEAD` and submodule symlinks (see the Phase 1 overlay plan, Global Constraints)."
- [ ] **Step 6: Device smoke list** (record results in the PR description; a simulator cannot verify touch feel):
  - SNES, Genesis 3 and 6, N64, PS1 DualShock, GameCube, Wii (nunchuk + classic), DS: controls press the right buttons, sticks move, DS stylus taps register on the bottom screen.
  - Rotate on each; safe-area change (Stage Manager on iPad); the picture follows `screenFrames`.
  - Long-press empty space → editor; move, resize, detach a button, undo, Done; relaunch → layout persists; Reset Pad.
  - Toggle off in Advanced → classic pad returns.
- [ ] **Step 7: Commit** — `docs: PVTouchOverlay in CLAUDE.md; spec status Phase 1`

Then follow `superpowers:finishing-a-development-branch`.

---

## Self-review notes

- **Spec coverage:** §3 model → Tasks 1–2; §4 families and subtypes → Tasks 4–8 and 15; §5 rendering/art/haptics → Tasks 9 and 11; §6 input and screen placement → Tasks 3, 7, 10, 11, 14; §7 editor and store → Tasks 12–13; §8 Phase 1 migration → Task 14; §9 tests → every task plus Task 16. Snapshot image tests from §9 are deferred to Phase 2 because the Prefire snapshot scheme does not compile today (CLAUDE.md); structural art tests stand in.
- **Deviations from the spec, recorded in Task 0:** token-string ids instead of integer ids; `ControllerLayoutVariant` reused instead of a new `ControllerSubtypeProvider`. `twoButton` and GBA bindings were added to Phase 1 because they cost one file each and cover the largest user base.
- **Type consistency check:** `OverlayInputID(system:token:)`, `OverlayPadKind.storageKey(for:)`, `OverlayLayoutEngine.resolve(template:canvas:overrides:gameAspect:)`, `OverlayLayout.screenFrames`/`surfaceFrame(for:)`, `OverlayHitDispatcher.apply(_:)`, `OverlayInputSink` method names, `OverlayLayoutStore.overrides(for:gameMD5:)`/`set(_:for:gameMD5:)`, `OverlayEditController` method names, `SystemOverlayBindings.binding(for:)` are used identically across Tasks 2–15.

## Device smoke list (Phase 1)

A simulator cannot verify touch feel. Run these on device and record results here or in the merge notes.

**Controls and screens**
- SNES, Genesis 3-button and 6-button, N64, PS1 DualShock, GameCube, Wii (nunchuk and classic), DS: controls press the right buttons, sticks move, DS stylus taps register on the bottom screen.
- Rotate on each system. Change the safe area (Stage Manager on iPad). The picture follows `screenFrames`.
- Menu access (blocking): no Phase 1 template has a menu button. Confirm the floating menu button stays visible and tappable while the overlay is active.
- Default-on: the toggle ships enabled, so Dolphin GameCube/Wii now show the overlay instead of the classic pad. Confirm that is acceptable.

**Editor and persistence**
- Long-press empty space opens the editor (holding a control must not). Move, resize, detach a button, undo, Done. Relaunch: the layout persists. Reset Pad works.
- Pause menu "Edit Layout" opens the editor with the game paused; the game resumes on Done.
- Toggle off in Advanced: the classic pad returns.

**Controller variants (Task 15)**
- Genesis (Genesis Plus GX thin): set 6-button via the pause menu. The overlay switches to six face buttons and Port Devices shows "MD Joypad 6 Button". Relaunch and confirm both persist.
- Untouched Genesis game: the core now gets "MD Joypad 3 Button" pushed instead of "Joypad Auto" (binding default). Confirm it plays normally.
- PSX (PCSX-ReARMed / Beetle): launch an untouched game; Port Devices should show dualshock once the game runs and the overlay draws two sticks. Switch to Digital Pad: sticks disappear and the port device is standard/joypad. Switch back to DualShock. Confirm Beetle's "DualShock"/"DualAnalog" names map.
- Wii/GC (Dolphin): pick Classic Controller during play; the overlay changes and the extension hot-swaps. Launch with a per-game Classic choice; it boots Classic.
- "All <system> games" in the Controller Layout sheet clears this game's per-game override.
- 32X and Sega CD games offer the Genesis variants.
- The Port Devices picker's port-0 choice is overridden at boot by the resolved variant while the overlay is active (expected).
