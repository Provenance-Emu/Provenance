# Programmatic Touch Overlay Engine — Design

**Date:** 2026-10-07
**Status:** Phase 1 implemented (feature/programmatic-touch-overlay)
**Package:** `PVTouchOverlay` (new, Tier 4)

## 1. Why

Provenance has three on-screen controller paths today and the two defaults are
disliked by the maintainer:

| Path | Where | Status |
|---|---|---|
| Imported Delta/Manic skins | `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/DeltaSkinView.swift` (2952 lines) + `DeltaSkinInputHandler.swift` (3109 lines) | Keep. The only skin renderer; always SwiftUI. |
| SwiftUI "Retrowave" default skin | `EmulatorWithSkinView+DefaultSkin.swift` (2468 lines), `DefaultDeltaSkin.swift` | Replace. |
| Classic UIKit pad | `Controller/OSD/PVControllerViewController.swift` + 43 `Controller/Systems/PV*ControllerViewController.swift` subclasses, layouts from Realm `system.controllerLayout` | Replace on iOS; keep a slim host on tvOS. |

There is no UIKit *skin* renderer. The classic pad survives because (a) it is
the fallback when skins are off or a core cannot position its render view, and
(b) cores that draw into their own view (Azahar, emuThree, Dolphin, PPSSPP)
parent that view to `core.touchViewController`, which is the classic pad's
view controller.

iCube (`Cores/Dolphin/dolphin-ios`, `Source/iOS/App/DolphiniOS/UI/Emulation/TouchOverlay/`)
already has what we want: a code-defined layout model, edge-anchored groups, a
procedural art kit, a live editor with a JSON layout store, and the perf
discipline needed to keep 120 Hz touch from re-rendering whole clusters. This
spec ports those concepts into a multi-system engine; it does not vendor the
iCube code (its ids are Dolphin integer button types and its pad kinds are
Dolphin-only).

iFly's skin code is a trimmed snapshot of Provenance's, not an advance. Its
useful bits (D-pad detent gating, display-type fallback chain, controller
style switch Flat/Glossy/Outline, group drag/resize editor) are folded into
this design where noted.

## 2. Decisions (made with the maintainer, 2026-10-07)

1. **Layout source:** new code-defined layout tables. `ControlLayoutEntry`
   Realm data and the 43 UIKit subclasses are deleted on iOS in Phase 2.
2. **Subtype source:** the core's reported device type is the truth; the user
   can override per game and the override is pushed back to the core.
3. **Relationship to DeltaSkinView:** shared input core, two renderers.
   Rendering stays separate (procedural art vs skin assets); touch primitives
   and the core dispatch are shared, and DeltaSkinView migrates onto them in
   Phase 3.
4. **Editor scope (v1):** full — group move/resize, per-button detach and
   move, per-group opacity and scale, undo/redo, per-game layouts.
5. **Art direction:** console-authentic per system with a global style switch
   (Flat default, Glossy, Outline).
6. **Where it lives:** a new Swift package `PVTouchOverlay`, hosted by
   PVUIBase. Not a folder in PVUIBase, not a vendored copy of iCube.

## 3. Layout model (`PVTouchOverlay/Sources/PVTouchOverlay/Model`)

Pure Swift, no UIKit, no Realm. Serializable, unit-testable.

```swift
public struct OverlayPadKind: Hashable, Codable {
    public let system: SystemIdentifier
    public let subtype: String          // a ControllerLayoutVariant.id, or "standard":
                                        // "genesis-3btn", "genesis-6btn", "psx-digital",
                                        // "psx-dualshock", "wii-wiimote", "wii-wiimote-nunchuck",
                                        // "wii-classic", "gc-standard", ...
}

public struct OverlayInputID: Hashable, Codable, Sendable {
    public let system: SystemIdentifier
    public let token: String      // skin vocabulary: "a", "b", "up", "l1", "start", "leftThumbstick", …
}

public enum OverlayControlKind: Hashable, Codable {
    case button(OverlayInputID)
    case dpad(up: OverlayInputID, down: OverlayInputID, left: OverlayInputID, right: OverlayInputID)
    case stick(OverlayStickSide, click: OverlayInputID?)
    case analogTrigger(OverlayInputID)
    case touchSurface(OverlaySurfaceRole)   // .dsScreen, .wiiPointer, .lightGun, .trackpad
    case hardwareSwitch(descriptorID: String) // latched console switches (HardwareSwitchDescriptor)
    case action(OverlayAction)              // .menu, .quickSave, .quickLoad, .fastForward,
                                            // .toggleKeyboard, .toggleMouse, .record, .screenshot, ...
}

public struct OverlayControl: Hashable, Codable {
    public var id: String
    public var kind: OverlayControlKind
    public var frame: CGRect              // group-local points at reference scale
    public var label: String?
    public var shape: OverlayShape
    public var paletteSlot: OverlayPaletteSlot
}

public struct OverlayGroup: Hashable, Codable {
    public var id: String                 // "dpad", "faceButtons", "leftStick", "shoulders", "startSelect", ...
    public var controls: [OverlayControl]
    public var placement: OverlayPlacement
    public var scale: CGFloat = 1
    public var opacity: CGFloat = 1
}

public struct OverlayPlacement: Hashable, Codable {
    public enum Anchor: String, Codable {
        case bottomLeading, bottomTrailing, bottomCenter
        case topLeading, topTrailing, topCenter
        case centerLeading, centerTrailing, center
        case fill, fillInset
    }
    public var anchor: Anchor
    public var inset: CGPoint             // distance from the anchored edges, points
}

public enum OverlayScreenPolicy: String, Codable {
    case topBand        // portrait: picture above controls
    case centerColumn   // landscape: picture between left/right clusters
    case dualStacked    // DS: top + bottom, each 4:3 aspect-fit
    case fill           // controls float over the picture
}

public struct OverlayTemplate {
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation   // .portrait / .landscape
    public let groups: [OverlayGroup]
    public let screenPolicy: OverlayScreenPolicy
}

public struct OverlayLayout {               // resolved, canvas-specific
    public let padKind: OverlayPadKind
    public let orientation: OverlayOrientation
    public let groups: [ResolvedGroup]      // absolute frames, hit frames, per-control frames
    public let screenFrames: [CGRect]       // 1 rect, or 2 for .dualStacked (top first)
}
```

Tokens are the Delta/Manic skin vocabulary already understood by `DeltaSkinInputHandler`, so bindings are shareable with skins and the Phase 1 sink is a thin adapter.

`OverlayLayoutEngine.resolve(template:canvas:safeArea:overrides:) -> OverlayLayout`
is a pure function. Reference scale `u = clamp(min(w,h)/390, 1...1.35)`.
Hit frames are draw frames outset by `extendedEdges` (default 20pt).
Resolution order is **scale first, clamp second**, so an enlarged group clamps
against its own footprint.

## 4. Templates and subtypes

### 4.1 Families

Templates are authored once per *family* (controller shape), not per system.
A system binds to a family and supplies ids, labels, palette.

| Family | Systems |
|---|---|
| `twoButton` | NES, GB, GBC, Master System, Game Gear, SG-1000, Lynx, Pokémon Mini, Supervision, WonderSwan |
| `fourFace` | SNES, GBA (+2 shoulders), Neo Geo Pocket, Virtual Boy (two d-pads) |
| `threeFace` | Genesis 3-button, 32X, Sega CD |
| `sixFace` | Genesis 6-button, Saturn, Neo Geo, arcade |
| `n64` | N64 |
| `digitalPad` | PS1 digital |
| `dualStick` | PS1 DualShock, PS2, PSP, Dreamcast, 3DS (circle pad + c-stick) |
| `gameCube` | GameCube |
| `wiiRemote`, `wiiRemoteSideways`, `wiiClassic`, `nunchuk` | Wii |
| `dsPad` | DS (fourFace + stylus surface) |
| `keypad` | Intellivision, ColecoVision, Jaguar, Odyssey2, Atari 5200, CD-i |
| `joystickOneButton` | Atari 2600, 7800, Vectrex (+ hardware switches) |
| `paddle`, `wheel` | Atari paddles, driving controllers, Naomi wheel boards |
| `computer` | DOS, Atari ST, Amiga, C64, MSX, Apple II, ZX Spectrum, PC-98 (minimal pad + keyboard/mouse toggles) |

~20 families cover all 60+ `SystemIdentifier` cases. Each family has a
portrait and a landscape template. iPad uses the landscape template in both
orientations with larger insets.

### 4.2 System bindings

```swift
public struct SystemOverlayBinding {
    public let system: SystemIdentifier
    public let families: [String: OverlayFamily]      // subtype -> family
    public let defaultSubtype: String
    public let slots: [OverlayFamilySlot: OverlayInputID]
    public let labels: [OverlayFamilySlot: String]
    public let palette: OverlayPalette
    public let hardwareSwitches: [String]             // HardwareSwitchDescriptor ids to show
}
```

One table per system. This is the only per-system authoring and it contains no
layout code. A completeness test asserts every `SystemIdentifier` has a binding
and every slot the family uses resolves to a valid `OverlayInputID`.

### 4.3 Subtype resolution

`OverlayPadKind.subtype` is a `ControllerLayoutVariant.id` (or `standard`). `ConsoleVariantConfigurable` gains a read-back `currentControllerLayoutVariantID` and a `Notification.Name.controllerLayoutVariantDidChange`; the thin wrapper and Dolphin implement both. The existing Settings picker remains the system-wide override; the pause menu gets a per-game override that also calls `applyControllerLayoutVariant`.

- Thin wrapper implements it from the libretro controller-port device and the
  relevant core options (`pcsx_rearmed_pad1type`, Genesis Plus GX pad type,
  `melonds_touch_mode`, ...). Dolphin from Wiimote extension and sideways
  state. Native cores from their own options.

The host applies the resolved variant at boot, and the pause menu offers a per-game override (persisted by MD5 via `CoreOptionsContext.currentGameMD5`), so core and overlay never disagree.

## 5. Rendering and art

### 5.1 View structure

- `OverlayHostView` (SwiftUI) lays out on the full-screen canvas (safe-area
  insets added back, then offset to the screen corner). Two layers:
  - **Art layer:** not hit-testable, never redraws on press.
  - **Touch layer:** one view per group; pressed state flows through an
    `@Observable` per-group `PressedSet` so a press re-renders only that
    button.
- Stick knob position and the DS stylus dot are separate `@Observable`
  values read only by the moving view.
- All art views are `Equatable`, keyed on `(style, palette, pressed, scale)`.
- Hosted in `OverlayContainerView` (UIKit, `UIHostingController` child) which
  sits above the GPU view and below keyboard, light-gun, cursor and menu
  overlays in the existing z-order (`bringVirtualInputOverlaysToFront`).
- Live touches are kept in a reference box, not `@State` (iCube commit
  b8614b8d0e lesson).

### 5.2 Art

- `OverlayPalette` per binding: shell, face-button colours by slot, label,
  rim. Nintendo/Sega from real hardware; GameCube and Wii palettes port from
  iCube's `TouchOverlayArt.Variant`.
- `OverlayShape`: `circle`, `kidney`, `pill`, `bar` (tapered trigger),
  `cross`, `ring` (stick base), `knob`, `key`, `surface` (translucent region
  with corner marks).
- `OverlayStyle`: `.flat` (default), `.glossy`, `.outline`. Press feedback is
  baked per style: fill switches instantly, scale animates to 0.92, no
  per-frame blur.
- Global opacity and scale (existing settings from 083b1b89e1) apply to the
  whole overlay; per-group values multiply on top.
- Hardware switches render with the existing `HardwareSwitchView`, driven by
  `HardwareSwitchLatch`.

### 5.3 Haptics

One shared `UIImpactFeedbackGenerator` per intensity. Fires on
empty-to-pressed and on d-pad detent change only (iFly detent gating). Gated
by `Defaults[.buttonVibration]` plus a new 0...1 intensity setting.

## 6. Input and screen placement

### 6.1 Shared touch primitives (`PVTouchOverlay/Sources/PVTouchOverlay/Touch`)

Plain `UIView`s with `touchesBegan/Moved/Ended/Cancelled`,
`isMultipleTouchEnabled = true`, no gesture recognizers.

- `MultiTouchCluster<Hit>`: one surface per group of buttons + d-pad. Each
  event recomputes the union of hits over all live touches and emits only the
  delta; releases before presses; a shared id held by two controls stays down
  until both release.
- `HitTester`: finger inside draw frame wins, else nearest centre within the
  hit frame. D-pad: 8 octants, 18% dead zone, 8° hysteresis; diagonals fan to
  two cardinals (f681174757 semantics).
- `SingleTouchSurface`: sticks, analog triggers, DS stylus, Wii pointer,
  trackpad. Reports normalized position in its frame, began/ended.
- `OverlayInputSink`: the only object that talks to the core. Takes
  `OverlayInputID` press/release, stick axes, surface events; dispatches to the
  typed `PV*SystemResponderClient` protocols. Extracted from
  `DeltaSkinInputHandler.trySystemResponderCall`. The `JSButton` /
  `forwardButtonPressToController` fallback is not carried over.

### 6.2 Screen placement

- `OverlayLayout.screenFrames` is the authority for the game picture.
  `screenPolicy` selects the free region; frames are aspect-fit from
  `core.aspectSize` / `screenRect` and recomputed on `viewDidLayoutSubviews`
  when bounds or safe area change (settle guard from a63e1622f1, so thin
  wrapper late geometry does not bake in).
- Frames are pushed through `PVViewportLayoutDelegate.viewportFrameDidUpdate`;
  DS through `applyMetalDualScreenLayout` (post-2026-10-07 fix, real source
  sizes). Own-view cores use `EmulatorCoreViewportPositioning` (Dolphin today;
  Azahar/emuThree/PPSSPP in the own-view hosting spec).

### 6.3 Surfaces to the core

- DS stylus: normalized point in the bottom screen frame →
  `PVDSSystemResponderClient.touchScreenAtPoint` via `NDSScreenLayout`.
- Wii pointer: normalized point → new optional
  `setWiiPointer(normalized:active:forPlayer:)` on `PVWiiSystemResponderClient`.
  Modes (drag/follow/gyro) and the Dolphin bridge wiring are the Wii pointer
  spec; this engine provides the surface and the call.
- Light gun / trackpad: existing `LightGunCrosshairView` and
  `TouchTrackpadView` semantics, hosted as surfaces.

## 7. Editor and layout store

### 7.1 Editor

- Enter: long-press 0.5 s on empty overlay space, or Pause → Controls → Edit
  Layout. Core pauses, top bar hides, groups get dashed chrome. Editor and play
  share `OverlayCanvas` (status bar hidden) so WYSIWYG holds.
- Gestures: drag group to move; corner handle or pinch to resize (0.5x–2.0x);
  tap selects and shows a floating inspector (opacity, scale, Detach button);
  a detached button moves independently, Reattach snaps it back; double-tap
  resets a group. Toolbar: Undo, Redo, Reset Pad, Done. Touch surfaces are
  groups; resizing them resizes the game picture via `screenPolicy`.
- `OverlayEditMode`: `.none | .layout`; input is suppressed while editing.

### 7.2 Store

`OverlayLayoutStore` (`@MainActor`, observable, `revision` counter), one
pretty-printed, schema-versioned JSON file in Application Support:
`touch_overlay_layout_v1.json`.

```
{
  "version": 1,
  "layouts": {
    "<system>.<subtype>.<orientation>": { "<groupId>": Entry, ... }
  },
  "games": {
    "<md5>": { "<system>.<subtype>.<orientation>": { "<groupId>": Entry } }
  }
}
Entry = { "at": AnchoredCenter?, "scale": [sx, sy]?, "opacity": Double?,
          "buttons": { "<controlId>": { "offset": [dx, dy], "scale": Double } }? }
AnchoredCenter = { "h": "min|mid|max", "x": Double, "v": "min|mid|max", "y": Double }
```

- Fallback: per-game → per-pad-kind → template default. A group with no entry
  keeps following the template.
- `AnchoredCenter` picks the anchor by canvas thirds and stores the distance
  in points from that edge, so positions survive device changes.
- Save sheet asks "This game" or "All <system> games".
- Undo: in-memory `UndoManager` over whole-store snapshots for the active key
  during an edit session. Done commits; Cancel restores the entry snapshot.
  History is not persisted.

Imported Delta/Manic skins are not editable here (feature-flagged
`DeltaSkinButtonOffsets` editor remains until Phase 3).

## 8. Migration

### Phase 1 — engine behind a toggle
- New package `PVTouchOverlay` (targets `PVTouchOverlay`, `PVTouchOverlayTests`),
  registered in `Provenance.xcworkspace` and as a `PVUIBase` dependency.
- `PVEmulatorViewController` overlay resolution: packaged skin selected →
  DeltaSkinView; else programmatic overlay when Advanced toggle
  `programmaticOverlay` is on (default on); else current default skin.
- Classic `PVControllerViewController` keeps running hidden only for cores
  that parent their render view to `touchViewController`.
- Families: `fourFace`, `threeFace`, `sixFace`, `n64`, `digitalPad`,
  `dualStick`, `gameCube`, the four Wii kinds, `dsPad`. Dolphin's
  `requiresExplicitSkinSelection` is dropped once GC/Wii templates exist.
- `ControllerSubtypeProvider` implemented by the thin wrapper and Dolphin.

### Phase 2 — delete the old paths
- Remaining families and bindings.
- Delete: the 43 `Controller/Systems/*ControllerViewController.swift`,
  `EmulatorWithSkinView+DefaultSkin.swift`, `DefaultDeltaSkin.swift`,
  `JSButton`, `JSDPad`, `Moveable`, `PVButtonGroupOverlayView`, iOS use of
  `ControlLayoutEntry` / `system.controllerLayout`,
  `PVCoreFactory.controllerViewController`'s per-system switch.
- tvOS keeps a slim `PVControllerViewController` for focus/physical pads, no
  subviews.
- Quick-action bar, record, keyboard/mouse toggles move into an
  `OverlayActionBar` group.
- `core.touchViewController` points at a stable `OverlayContainerView` host
  (enables Azahar/emuThree `supportsSkins = true` in the own-view spec).

### Phase 3 — DeltaSkinView on shared primitives
- Replace `MultiTouchView` and `DeltaSkinView` hit-testing with
  `MultiTouchCluster`/`HitTester`/`SingleTouchSurface`; route through
  `OverlayInputSink`; delete `forwardButtonPressToController` and `JSButton`
  fallbacks; back-port iFly detent gating and the display-type `lookupChain`.

## 9. Tests

- `PVTouchOverlayTests` (Swift Testing): layout engine resolution for every
  template on four canvases (iPhone portrait/landscape with notch, iPad,
  no-safe-area); `AnchoredCenter` round trips; store migration and fallback
  order; undo snapshots; hit-tester octants, hysteresis and nearest-centre;
  screen-policy frames including `dualStacked`; binding completeness.
- Snapshot tests of every family in every style at a fixed canvas under
  `PVUI-UnitTests`.
- Device smoke list: rotation, safe-area change, Stage Manager resize, thin
  wrapper late geometry, editor on iPad, DS stylus through the surface, GC and
  Wii on Dolphin with render-view repositioning.

## 10. Out of scope (separate specs)

- Wii pointer modes (drag/follow/gyro) and Dolphin bridge wiring.
- Own-view core hosting generalisation (Azahar, emuThree, PPSSPP).
- Hardware-switch state back-channel from core to UI.
- Skin import with cross-system retargeting (iFly `SkinCompatibility`).
- Enabling the native melonDS / DeSmuME cores (`PVDisabled`).

## 11. Risks

- **Template authoring volume.** Mitigated by families; Phase 1 ships the
  families that exercise every control kind before breadth.
- **Own-view cores.** Until the hosting spec lands, Azahar/emuThree keep the
  hidden classic controller as their `touchViewController`.
- **Perf regressions at 120 Hz.** The art/touch split, reference-box touches,
  `@Observable` knob and `Equatable` art are mandatory, not optional; add
  `os_signpost` probes like iCube's `TouchOverlayRenderProbe`.
- **PackageBuildInfo plugin vs worktrees.** PVUI cannot build inside a git
  worktree (needs `.git/HEAD`); tests run from a synced copy. Document in
  CLAUDE.md.
