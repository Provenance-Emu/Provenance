# Unified Input Surface and Emulation Scene — one skin system, one scene, one quick action bar

Status: draft for review (written 2026-10-09 from a code map; not yet brainstormed with the
maintainer). Depends on the console-style overlays
(`2026-10-09-console-style-default-overlays-design.md`, batches 1–3 landed) and on the
legacy default skin being gone.

## 1. Why

The programmatic overlay (PVTouchOverlay) is now the on-screen controller for every system,
but it only carries the pad. Everything else a game needs from the touch screen is a
separate layer bolted beside it:

| Input | Today | Reached from |
|---|---|---|
| Virtual keyboard | `VirtualKeyboardView` hosted by `PVEmulatorViewController+VirtualKeyboard` | pause tile, skin button only if the skin declares `keyboardOverlay` |
| Touch-as-mouse | `TouchTrackpadView` + `MouseCursorOverlayView`, full-viewport sibling gated on the GPU view frame | pause tile |
| Light gun | `LightGunTouchView`, same sibling pattern, reuses the mouse cursor as crosshair | pause tile, explicit opt-in, auto-install disabled |
| DS/3DS touch | overlay `.dsScreen` surface (works) | — |
| Disc swap | `DiscSwappable` → `showSwapDiscsMenu()` action sheet | pause tile, skin token `swapdiscs` |
| FDS disk side, Lynx flip, WonderSwan rotate | nothing (`.flip`, `.diskSide` exist in `OverlayAction` and are dropped by the adapter) | — |
| Port devices, N64 paks, layout variants | `PortDeviceConfigurable`, `ConsoleVariantConfigurable` | pause sheets |
| Hardware switches (2600/5200/7800/MSX/SMS) | pills via position-less tokens; `overlayHardwareSwitch` is an empty stub | overlay |
| Output state (fast-forward on, rumble, disc activity) | not observable; the FF pill is stateless | — |

`OverlayInputSinkAdapter.handlerToken(for:)` returns nil for `.toggleKeyboard`,
`.toggleMouse`, `.keypad` (handled locally), `.flip`, `.diskSide`; `overlaySurface` only
wires `.dsScreen`. The handler (`DeltaSkinInputHandler`) has no keyboard, mouse, light gun,
flip or disk-side vocabulary, and only `PVEmulatorViewController` holds the
`KeyboardResponder` / `MouseResponder` / `LightGunResponder` references.

Consequences: computers have a pad but no keys in reach; mouse and gun games need a trip
through the pause menu; the sibling views break when the picture is not where the GPU view
is (external display, future AirPlay, a skin that moves the screen); and the overlay cannot
show state.

## 2. Goal

Everything on screen during play is a skin: a packaged `.deltaskin`/`.manicskin` or the
code-generated overlay, through the same layer, for every core. One touch surface. The overlay layout owns the whole device screen and every touch input a
core can take is an overlay control: pads, keyboard, pointer surfaces, media and accessory
actions, hardware switches. The game picture is a rectangle the overlay knows about
(`screenFrames`), not a view it reaches into. Output state flows back into the same layout
so pills can light up.

Non-goals: tvOS (controller only), replacing packaged `.deltaskin` / `.manicskin` files
(they keep their own screen and key maps), new core-side features beyond the protocol
additions in §4.

## 3. Architecture

### 3.1 Input target, not handler tokens

Add `OverlayInputTarget` (PVUI, next to the adapter): a value the host builds at mount with
weak references to the core as `ButtonResponder`, `KeyboardResponder?`, `MouseResponder?`,
`LightGunResponder?`, `DiscSwappable?`, `MediaControllable?` (§4), `PortDeviceConfigurable?`,
`ConsoleVariantConfigurable?`, plus host closures (`openPauseMenu`, `openAccessorySheet`,
`setGameSpeed`). `OverlayInputSinkAdapter` keeps routing pad buttons through
`DeltaSkinInputHandler` (unchanged, it carries the per-system remaps) and routes everything
else directly to the target. No new string tokens.

### 3.2 Capabilities drive the layout

`OverlayCapabilities` (PVTouchOverlay model) computed by the host from the core at mount
and refreshed on `OptionUpdated`/port-device change:

```
keyboard: Bool          // KeyboardResponder.gameSupportsKeyboard
mouse: MouseMode?       // .trackpad / .direct when MouseResponder.gameSupportsMouse
lightGun: Bool          // LightGunResponder.gameSupportsLightGun && registry says the game uses it
discs: Int              // DiscSwappable.numberOfDiscs
media: [MediaSlot]      // §4: FDS side, tape, cartridge
accessories: Bool       // PortDeviceConfigurable descriptors non-empty or variants > 1
hardwareSwitches: [HardwareSwitchDescriptor]
```

The planner adds controls from capabilities, not from the binding: a `.toggleKeyboard` pill
when `keyboard`, a `.pointer` surface over the picture when `mouse` or `lightGun`, a
`.media` pill when `discs > 1 || !media.isEmpty`, an `.accessory` pill when `accessories`.
Bindings may still place these explicitly (position override); capabilities decide
presence. This removes the "binding has no screen-policy field" workaround for computers:
the keyboard drawer and pointer surface are capability-driven.

### 3.3 Keyboard drawer

`VirtualKeyboardView`'s layouts (`VirtualKeyboardLayouts`: full, compact, functionRow,
c64, zxSpectrum, amstradCPC, atariST) become an overlay **group** rendered by the overlay
(`OverlayKeyboardGroup`), toggled by `.toggleKeyboard`, docked to the bottom in portrait and
to the right in landscape, picture shrinking to fit (the planner already aspect-fits).
Keys emit `GCKeyCode` to `KeyboardResponder.keyDown/keyUp` through the target. Modifier
latching, repeat and the layout picker move with it. `PVEmulatorViewController+VirtualKeyboard`
shrinks to: hardware-keyboard connect/disconnect (hide drawer on connect) and the tvOS
host, which keeps `VirtualKeyboardView` as is.

Hardware keyboard raw forwarding (`keyChangedHandler`) is implemented only by
`PVThinLibretroCore`; DOSBox, Atari800, fMSX, EP128, O2EM and Bliss receive only the
gamepad mapping. Fix in the same batch: `PVControllerManager` forwards raw keys to every
`KeyboardResponder` via `keyDown/keyUp` when `gameSupportsKeyboard`, with
`keyChangedHandler` as an optional fast path.

### 3.4 Pointer surface (mouse and light gun)

One `OverlayPointerSurface` control placed over the picture rectangle (every screen frame
when there are two). Modes from capabilities:

- `.trackpad`: relative motion, tap = left, two-finger tap / long press = right, drag with
  hold = left-drag; scroll with two fingers. Calls `MouseResponder`.
- `.direct`: absolute, finger = cursor.
- `.lightGun`: tap = trigger at point, drag = aim, two-finger tap = reload, long press =
  AuxA, double tap = Start, off-screen when the finger leaves the rectangle. Calls
  `LightGunResponder.lightGunMovedToPoint(_:isOffscreen:)` normalised to the picture
  rectangle the overlay publishes.

The overlay draws its own cursor / crosshair layer (`OverlayCursorLayer`) inside the same
rectangle, so the picture can be on another screen and the crosshair still lands where the
game expects. `GCMouseMouseResponderDriver` and `GCMouseLightGunDriver` keep driving physical
mice; the cursor layer subscribes to the same position notifications they post today.
`TouchTrackpadView`, `LightGunTouchView` and `MouseCursorOverlayView` are deleted at the end
of the batch along with `+VirtualMouse` and `+LightGun` show/hide plumbing; the pause tiles
become capability toggles (`mouse` on/off per game override stays in `MouseGameRegistry`).

Light gun auto-installs when `LightGunGameRegistry` says the game is a gun game (today it
is opt-in because the sibling view fought the trackpad; the single surface removes that).

### 3.5 Media and accessory actions

- `.media` pill: tap cycles disc / disk side; long press opens an overlay sheet listing
  `MediaSlot`s with their states (disc 1..n, FDS side A/B, tape play/stop). Uses
  `MediaControllable` (§4), falling back to `DiscSwappable`.
- `.flip` (Lynx, WonderSwan): rotates the picture rectangle 90° in the planner and pushes
  the matching layout variant (`wonderSwanVertical`), and for Lynx sets the core option
  that Mednafen reads for `lynx.rotateinput` (currently hard-coded false in
  `MednafenGameCoreBridge.mm:403`; becomes a core option).
- `.accessory` pill: opens an overlay sheet merging `PortDeviceConfigurable` descriptors,
  `ConsoleVariantConfigurable` variants and N64 pak slots (`MupenOptions.controllerPakOption`,
  `TransferPakSupport`). Picking a variant goes through `OverlayPadKindResolver.variantToPush`
  as today; picking a port device calls `setDeviceType(_:forPort:)` and refreshes
  capabilities (a Super Scope or Zapper pick turns on the light-gun surface; a mouse pick
  turns on the trackpad). The 2600 paddle variant lands here: `Family+Paddle` exists, the
  variant and Stella port device do not.
- Hardware switches: implement `overlayHardwareSwitch` (toggle vs momentary from
  `HardwareSwitches.swift` descriptors) instead of pills faking it with tokens.

### 3.6 Output state

`OverlayStatus` (observable, PVTouchOverlay model) published by the host:

```
fastForward: Bool, slowMotion: Bool, rewinding: Bool
keyboardShown: Bool, pointerMode: PointerMode?
media: [MediaSlotState]        // current disc index, side, activity flag
rumble: RumblePulse?           // from HapticsManager / PVRumbleProtocol events, expires
jitActive: Bool?               // PVEmulatorCore.isJITActive
```

Pills render lit/unlit from it (FF, keyboard, pointer, media), the media pill blinks on
activity, and rumble pulses the whole pad briefly (visual only; haptics unchanged). Sources
already exist: `core.gameSpeed`, `achievementsBlocksFastForward`, `DiscSwappable`,
`PVEmulatorCore+Rumble`, `PVIndicatorID`. The existing indicator lights
(`+Indicators.swift`) read the same object so there is one status source.

### 3.7 External display

The overlay already owns the device screen when the picture goes to a second `UIScreen`
(`attachGPUView(to:)`). Add an `OverlayScreenPolicy.remote` the host selects when the GPU
view is not in the overlay's window: the picture rectangle stays as the pointer / DS-touch
surface at full size (optionally with a dim placeholder), pads around it. Nothing else
changes because every surface already normalises to the overlay's own rectangle (§3.4).
This is the test that §3.4 was done right.

## 4. Protocol additions (PVCoreBridge)

```swift
public enum MediaSlotKind { case disc, floppySide, tape, cartridge }
public struct MediaSlot { kind, index, title, states: [String] }  // "A"/"B", "Disc 1"…
public protocol MediaControllable: AnyObject {
    var mediaSlots: [MediaSlot] { get }
    func mediaState(for slot: MediaSlot) -> Int
    func setMediaState(_ state: Int, for slot: MediaSlot)
    func ejectMedia(_ slot: MediaSlot) / insertMedia(_ slot: MediaSlot)
}
```

Implementations: thin libretro (disk-control interface: `set_eject_state`,
`set_image_index`, `get_num_images`; FDS and multi-disc both ride it), Mednafen
(`setMedia`), FCEU native (`EMUCMD_FDS_EJECT_INSERT`, `EMUCMD_FDS_SIDE_SELECT`),
DuckStation. `DiscSwappable` stays as the simple case and gets a default
`MediaControllable` bridge.

`KeyboardResponder` unchanged. `MouseResponder` unchanged. `LightGunResponder` unchanged.
`HardwareSwitchProvider` unchanged.

## 5. Delivery (one session, four batches, each a PR)

1. **Target + keyboard + status.** `OverlayInputTarget`, `OverlayCapabilities`,
   `OverlayStatus`, keyboard drawer group, hardware-keyboard forwarding fix, FF/keyboard
   pill state. Delete `VirtualInputToggleOverlayView` and the skin-only keyboard button
   path. Tests: capability derivation per responder set, drawer key → `keyDown/keyUp`,
   status → pill state.
2. **Pointer surface.** Trackpad and light-gun modes, cursor layer, auto-install from
   registries, physical-mouse driver subscription, delete the three sibling views.
   Tests: normalisation to one and two screen rectangles, gesture → responder calls,
   off-screen handling.
3. **Media + accessories + switches.** `MediaControllable` and its implementations,
   `.media` / `.flip` / `.accessory` controls and sheets, `overlayHardwareSwitch`,
   Lynx rotate option, 2600 paddle variant + Stella port device. Tests: sheet model from
   descriptors, slot cycling, switch toggle vs momentary.
4. **External display policy.** `.remote` policy, placeholder, device smoke on an
   AirPlay/HDMI screen.

Device smoke list per batch appended to `docs/RELEASE_SMOKE_TESTS.md`: DOS (keyboard +
mouse), NES Duck Hunt (gun), PSX multi-disc, FDS side flip, Lynx rotate, SNES mouse via
accessory pick, 2600 paddle.

## Part II — Scene consolidation and deletions

Maintainer direction (2026-10-09): once every core renders under the same skin layer, the
emulation scene can lose its parallel paths. Measured on develop:

| Path | Lines | Status after this spec |
|---|---|---|
| `Controller/OSD/PVControllerViewController` + `JSDPad`/`JSButton`/`Moveable`/`PVButtonGroupOverlayView` + `Controller/Systems/PV*ControllerViewController` (≈30 subclasses) | ≈10,400 | deleted |
| `PVEmulatorViewController` + extensions, `PVMetalViewController`, `PVGLViewController` | ≈20,200 | one scene host, GL VC deleted if no core still needs it |
| `PVUIKit` module + `PVUIBase/Game Library`, `Menus` (legacy UIKit library UI) | map in batch 0 | deleted where SwiftUI `ContentView` already covers it |
| `SkinMode` setting (off / selectedOnly / always) | — | removed on iOS: a skin is always present (packaged or generated); tvOS unchanged |

### II.1 Scene

`EmulatorSceneView` (SwiftUI, iOS) with exactly these layers, bottom to top: GPU surface
(`MTKView` or the core's own view, one wrapper, no `skipLayout` special cases in the
scene), skin layer (packaged skin renderer or the overlay), quick action bar, HUD
(indicators, cheevos toasts, performance labels), pause menu. Z-order is the layer list;
`ensureGPUViewVisibilityAndZOrder`, `bringSubviewToFront` chains and the
rotation re-stack code go. `PVEmulatorViewController` shrinks to lifecycle, core start/stop,
audio and the scene host; its `+DeltaSkin`, `+DeltaSkinScreen`, `+VirtualKeyboard`,
`+VirtualMouse`, `+LightGun`, `+Controllers` (touch parts) extensions fold into the scene
model or are deleted per Part I.

The shader pipeline (`PVMetalViewController`, PVShaders) keeps its renderer but drops the
view-controller-level layout, dual-screen frame juggling and own-surface detection; the
scene gives it one drawable rectangle per screen and nothing else.

### II.2 Quick action bar

One bar for every core, replacing the partial sets in the UIKit controller bar (FF, load,
save, keyboard, mouse, record) and the deleted purple skin (keyboard/mouse toggles, JIT
pill). Items are the existing pause-menu tile providers (`PauseTileMenuViewModel`,
`SystemButtonTileProvider`, `systemMenuButtons(for:)`, hardware switches, port devices,
pak slots, disc swap, keyboard/mouse/light-gun toggles) rendered compact. Default set per
system comes from the binding; the user edits it per system and per game with the same
editor the overlay uses (`PauseTileMenu` customisation store). Status indicators
(`PVIndicatorID`: JIT, netplay ping/bandwidth, player count, analog, swap; plus disc
activity and DSU) are bar items driven by `OverlayStatus` (§3.6). The bar lives in the skin
layer so packaged skins can place or hide it.

### II.3 Deletion order

0. **Map and delete the UIKit controller path.** `PVControllerViewController`, OSD views,
   `Controller/Systems/*`, `VirtualInputState` Combine plumbing, `pressStart/pressSelect`
   bridges from `PVControllerManager` (route hardware keyboard Start/Select through the
   handler instead), `SkinMode` on iOS. Map `PVUIKit` and `Game Library`/`Menus` usage from
   `ProvenanceApp` → `ContentView`; delete what nothing reaches. This is the first batch of
   the session because Part I §3.3–3.5 would otherwise have to keep both paths working.
1–4. Part I batches, each deleting the sibling views it replaces.
5. **Scene host.** `EmulatorSceneView`, z-order removal, GL VC retirement, pause menu as a
   layer. Device smoke across native (Dolphin, Azahar, Mupen), thin (PSX, N64, PPSSPP
   Vulkan), dual-screen (DS, 3DS), rotation, background/resume, external display.

Expected payoff beyond behaviour: PVUI loses roughly 30k lines of UIKit scene and controller
code, which is the slowest-compiling part of the module, and the test surface for skins
drops to one layer.

## 6. Open questions for the maintainer

1. Keyboard drawer: embed `VirtualKeyboardView`'s SwiftUI layouts inside the overlay group
   (fast, keeps tvOS sharing code) or redraw keys with the overlay's own pill renderer
   (consistent look, more work)? Recommendation: embed first, restyle later.
2. Light-gun auto-install: on when the registry flags the game (recommended) or keep
   opt-in?
3. Should the `.accessory` sheet replace the three pause sheets (port devices, controller
   layout, pak slots) or sit beside them? Recommendation: replace on iOS, keep the pause
   tiles on tvOS.

## 7. Out of scope

- Companion keyboard/mouse over the network (`CompanionKeyboardMouseCapable`) — unchanged.
- MIDI, Wii pointer beyond the existing `.wiiPointer` surface.
- Packaged-skin keyboard overlays (`keyboardOverlay`) — they keep working as they do.
