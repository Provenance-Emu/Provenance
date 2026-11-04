# Emulator host thinning (controls rework, phase 4) — Design

**Date:** 2026-11-03
**Status:** Proposed. Phases 1–3 are on develop (`d179081a94`, `20d6c6f426`, `229d74022c`, `8f03e815dd`).
**Package:** `PVUIBase` (`PVUI/Sources/PVUIBase/PVEmulatorVC/`, `PVUI/Sources/PVUIBase/Controller/`)

## 1. Why

Phases 1–3 replaced every on-screen controller path: the programmatic touch overlay
(`PVTouchOverlay`) and DeltaSkins are the two touch surfaces, desktop input mode has
`EmulatorQuickActionBar`, and `PVControllerViewController` with its 44 per-system subclasses
is gone. What is left is the host they all plug into: `PVEmulatorViewController` is a 3,758-line
class plus 36 `PVEmulatorViewController+*.swift` extensions in its own folder (7,756 lines) and
five more under `Controller/` (2,643 lines) — 14,157 lines on one `final class`, with
`// swiftlint:disable:next type_body_length` at the top.

The cost today:

- **Every session carries every feature.** `createEmulator()` and `finishEmulatorStart()` call
  seventeen `setup*` / `start*IfNeeded()` routines in a fixed order, and `quit()` and
  `deinit` undo them in a second, hand-maintained order. The two orders have drifted
  (`stopAchievements()` had to move below `stopEmulationAfterLoopExits()`; `cancelJITIndicatorSubscription()`
  is in `deinit` but `removeJITIndicator()` is in `viewWillDisappear`).
- **State lives in associated objects.** Twelve extensions store their state through
  `objc_setAssociatedObject` (Achievements, CompanionController, Controllers, Indicators, JIT,
  KeyboardHUD, LightGun, Netplay, Recording, VirtualInputState, VirtualKeyboard, VirtualMouse,
  plus `initialCorrectFrame` in `+DeltaSkinScreen`), because an extension cannot declare stored
  properties. Those keys are invisible to the type checker, to `deinit`, and to tests.
- **The pause menu reaches in directly.** `PauseTileMenuView` (2,420 lines) and
  `PauseTileMenuViewModel` (1,308 lines) take a concrete `PVEmulatorViewController`, build tiles
  by reading its state, and dispatch taps through a `switch tile.id` over string ids. Between them
  they touch 37 distinct members of the view controller (view) and 17 (view model).
- **Tests cannot reach it.** The only testable parts are the pieces that were already pulled out
  as plain types: `HostGPUViewPolicy`, `PauseToggleCoalescer`, `CoreActionTileProvider`,
  `SystemButtonTileProvider`, `EmulatorQuickActionBar.rows(for:)`.

The goal is a host that owns the four things only a view controller can own — the core's
lifecycle, the render surface, the input surface, and UIKit's responder/lifecycle overrides —
and a flat set of session features that attach to it through one small protocol. Precedents in
the same folder: `PlayTimeTracker` (a `@MainActor final class` replacing a KVO protocol),
`EmulatorQuickActionBar` (an object holding `weak var host`, with a `nonisolated static func rows`
that `EmulatorQuickActionBarTests` covers).

## 2. Decisions

1. **The class keeps its name.** `PVEmulatorViewController` stays. `EmulatorScene` constructs it,
   `SentryEventFilter` matches the string, every core comment and memory note names it, and the
   ObjC selectors (`pvMenu*`, `showMenu:`) are keyed on the responder, not the class name. Renaming
   buys nothing and makes every step's diff unreadable. A rename to `EmulatorHostViewController`
   is an optional last step (section 7, question 1).
2. **The protocol gets a new name and the old one becomes a typealias.** `PVEmualatorControllerProtocol`
   (misspelled since 2025) is what `DeltaSkinInputHandler`, `EmulationUIState.emulator`, and the
   protocol extensions (`quicksave`, `quickload`, `autoSaveState`, `createNewSaveState`,
   `controllerPauseButtonPressed`, the path accessors) see. It is renamed `EmulatorSessionHost`;
   `public typealias PVEmualatorControllerProtocol = EmulatorSessionHost` survives until step 10.
3. **Features are objects, not extensions.** One `@MainActor final class` per feature, owning its
   own stored state, created by the host's registry, torn down in `detach()`. No new associated
   objects. Extensions remain only for UIKit overrides (section 3.5), which must be members of the
   view controller class.
4. **One file per feature, in `PVUIBase/EmulatorSession/Features/`.** Not a new package: Saves,
   Cheats and Achievements need Realm (`PVLibrary`) and the pause-menu tile model, and a Tier-5
   package split would have to carry both. Revisit after step 10 (question 2).
5. **Pause-menu tiles are contributed, not read.** A feature returns its tiles and handles its own
   tile ids. `PauseTileMenuViewModel` keeps the section order table; `PauseTileMenuView` keeps its
   layout, sheets and the non-feature tiles (resume, quit, states, core options).
6. **Shipping order is by risk, not by size.** Observers and HUDs first, then the features with
   teardown-order constraints (Achievements, Saves), then input, and the render surface last.

## 3. Inventory

Line counts are `wc -l` on develop at `7554b487c5`. "Depends on" lists other extensions whose
members the file calls (from reading call sites, not from the import list). "Platform" lists the
`#if` guards that shape the file; a blank cell means it compiles the same on iOS and tvOS.

### 3.1 The class

| File | Lines | Owns | Depends on | Platform |
|---|---|---|---|---|
| `PVEmulatorViewController.swift` | 3,758 | `core`, `game`, `gameAudio` (lazy, `audioInited`, `isAudioMuted`), `gpuViewController` (lazy `PVMetalViewController`), `playTimeTracker`, `runningCancellable` (`core.isRunning` → boot HUD, pause handlers, play time, tvOS hint toast), `bootHUD`, `toastHostingController`, `menuButton`, `quickActionBar` + `volumeHUD` (iOS), `skinContainerView`/`currentSkin`/`skinHostingControllers`/`sharedInputHandler` and ~20 viewport fields (`currentTargetFrame`, `lastAppliedViewportFrame`, `overlayScreenFrames`, `isHandlingRotation`, `isApplyingViewport`, …), `secondaryScreen`/`secondaryWindow`, `isShowingMenu` (single pause authority), `isQuitting`, `pauseToggleCoalescer`, `pendingAutoSaveTask`, `onSuccessfulReturnToLibrary`, the static `staticSelf` + `NSSetUncaughtExceptionHandler`. Methods: `init`, `deinit`, `viewDidLoad`, `viewDidAppear`, `viewWillDisappear`, `viewWillTransition`, `viewDidLayoutSubviews`, `setupGPUView`, `createEmulator` (ROM resolution, archives, CloudKit download UI, `loadFile`, GPU attach branches, hosting handoff, audio graph, `startEmulationCompletion`), `finishEmulatorStart`, `applyPostStartAspectIfChanged`, `quit`, `dismissNav` ×3, the skin-management extension (`applySkin`, `createSkinView`, `radicalCleanup`, fallback skin search, rotation), the app-lifecycle extension (`appWillResignActive` etc.), `startAudio`/`setMono`, mic mute, skin reconnect handlers. 70 `#if` blocks. | everything below | tvOS root class is `GCEventViewController`; iOS: status bar, home indicator, `prefersPointerLocked`, quick action bar, volume HUD, virtual input setup; tvOS: Menu-press recognisers, pause hint toast, Steam controller mode |

### 3.2 Extensions in `PVEmulatorVC/`

| File | Lines | Owns (state · views · observers) | Depends on | Platform |
|---|---|---|---|---|
| `+Achievements` | 548 | assoc: `achievementSessionManager`, `achievementOverlayViewController`, `StartToken`, `sessionPoints`, `loadedROMURL`. `RetroAchievementsOSDDelegate` conformance. Hardcore gates `achievementsBlocksSaveStateLoad/FastForward/Rewind`, `setGameSpeedRespectingAchievements`. | LiveActivities (`updateLiveActivityAchievements`); called by Saves/protocol `quickload`, Cheats, `EmulatorQuickActionBar`, `PauseTileMenuView`, `DeltaSkinInputHandler` | iOS-only hardcore toast path |
| `+AltRepresentations` | 86 | none stored; installs a toggle on `DeltaSkinInputHandler`; posts `.deltaSkinForceRecalculate` | DualScreen (relayout), main (`coreInputHandler`) | |
| `+AudioMuteWarning` | 82 | `static var hasShownAudioMuteWarning` | — | iOS only |
| `+AudioRoute` | 59 | `AVAudioSession.routeChangeNotification` observer → pause | main (`isShowingMenu`) | `!os(macOS)` |
| `+AudioVisualizer` | 490 | uses main's `audioVisualizerHostingController`/`visualizerMode`; orientation observer; constraints incl. Dynamic Island offset | main (`menuButton`, skin container z-order) | iOS only (whole file) |
| `+Cheats` | 462 | `CheatCodeNormalizer` (pure); `setCheatState`, `showCheatsMenu`, `recoverCheatCodes` (Realm); **`@objc extension PVEmulatorCore` shim** (`setCheat`, `supportsCheatCode`, `cheatCodeTypes`, `resetCheatCodes`) | Achievements (`downgradeHardcoreForCheatIfNeeded`) | iOS/tvOS presentation split |
| `+CompanionController` | 271 | assoc: session, bridge, keyboard/mouse Combine cancel; `CompanionHostingController`, `CoreCompanionBridge` | Controllers (`PVControllerManager`) | iOS + Catalyst only |
| `+Controllers` | 611 | `handlePause` (PauseGame coalescing), `hideOrShowMenuButton`, controller connect/disconnect, `updateOnScreenControlsVisibility`, mapping-changed + reassigned handlers, external `UIScreen` connect/disconnect, `attachGPUView(to:)`/`restoreGPUViewToDevice`; tvOS: Siri Remote keyboard/mouse/light-gun handlers (assoc: 4 keys + `LGRemoteHandlerKey`) | DeltaSkin (`skinDidReportLoaded`, `isProgrammaticOverlayActive`), render (gpu view), VirtualKeyboard/VirtualMouse/LightGun (tvOS Siri paths) | iOS: pause-handler rebind; tvOS: Siri Remote, Steam controller |
| `+CoreOptions` | 89 | `showCoreOptions`, `handleCoreAction`, `dismissCoreOptions` | main (`dismissNav`) | iOS sheet vs tvOS push |
| `+CoreScalingMode` | 26 | `Defaults.publisher(.scalingMode)` → `EmulatorCoreScalingModeApplying` | main (`scalingModeCancellable`) | |
| `+DualScreen` | 637 | `dualScreenViewportRects`, `applyDualScreenViewport` (+ EmuThree special case), `setupDualScreenObservers` (`handleSwapScreenChanged`, `handleSkinFrameUpdated`), `receivedScreenFrames` | MetalDualScreen, DualScreenLCD, DeltaSkinScreen (`applyFrameToGPUView`, `currentSkinViewportFrame`), main (`overlayScreenFrames`) | |
| `+DualScreenLCD` | 98 | `dualScreenLCDOverlays` (stored on main), `LCDGridOverlayView`, `Defaults.updates(.dualScreenLCDLook)` | DualScreen | |
| `+FirstFrameWatchdog` | 52 | 5 s `[NO-FRAME]` diagnostic | render (gpu view frame, `rendersToOpenGL`) | |
| `+Indicators` | 133 | assoc: `indicatorOverlayViewController`; `setup/remove/refresh/temporarilyHide/restore` | JIT (indicator registry) | `canImport(UIKit)` |
| `+JIT` | 178 | assoc: `jitIndicatorViewController`, `showJITIndicatorCancellable`; `Defaults.publisher(.showJITStatusIndicator)`; `coreRequiresJIT` | Indicators | `canImport(PVJIT)` |
| `+KeyPresses` | 102 | **UIResponder overrides** `pressesBegan/Ended/Cancelled`; forwards unmapped keys to `GCEventViewController`/core; `guardedModifierFlags` | ControllerMapping (mapped key codes) | iOS-only filtering |
| `+KeyboardHUD` | 221 | assoc: hosting VC, view model, `didShowLaunchLegend`; `setupKeyboardHUDIfNeeded` (re-run from `viewDidAppear`), `teardownKeyboardHUD` (`viewWillDisappear`), `toggleKeyboardHUDPinned` | VirtualKeyboard (layout), MenuBar (⇧⌘M) | `!os(tvOS)` |
| `+LightGun` | 263 | assoc: `LightGunTouchView`, `GCMouseLightGunDriver`, `ownsCursorOverlay`; `nonisolated takeLightGunCleanupHandle()` for `deinit` | VirtualMouse (cursor overlay), DeltaSkinScreen (viewport frame) | iOS only |
| `+LiveActivities` | 125 | none stored (talks to `PVLiveActivities`); start/end/paused/autosave/achievements | — | iOS + `canImport(PVLiveActivities)` |
| `+MenuBar` | 223 | `PVMenuSettingsHostingController`; **`canPerformAction`/`validate(_:)` overrides**; `@objc pvMenu*` responder actions (settings, save, load, screenshot, quit, pause menu, toggle pause, reset, keyboard HUD); posts `.pvShowSettings` | Saves, ScreenShot, PauseMenu, KeyboardHUD | iOS only (Mac menu bar via Designed for iPad) |
| `+Menus` | 168 | `layoutMenuButton`, `hideMenu`, `showMoreInfo`/`hideMoreInfo`, `showSpeedMenu`, `showSkinOptions` | Achievements (`setGameSpeedRespectingAchievements`), Indicators | iOS alerts vs tvOS |
| `+MetalDualScreen` | 282 | `isMetalDualScreenActive` (on main); `applyMetalDualScreenLayout` ×2, `installMetalDualScreenSwap(on:)`, `clearMetalDualScreenLayout` | render (`PVMetalViewController` dual-screen API), DualScreen | tvOS branch in layout |
| `+MultiDisc` | 43 | `showSwapDiscsMenu` | main (`dismissNav`) | |
| `+Netplay` | 205 | assoc: start `TaskBox`, `openNetworkPlay` flag; `startNetplayBridgeIfNeeded` (`finishEmulatorStart`), `stopNetplayBridge` (awaited in `quit`), launch-intent runner, `takeNetworkPlayMenuRequest` (read by `PauseTileMenuView`) | PauseMenu | `canImport(PVNetplay)` |
| `+OSD` | 101 | observer for `PVOSDMessageNotification` (posted by core bridges, e.g. Mednafen `stubs.mm`) → `PVToastManager` | — | |
| `+PauseMenu` | 164 | `showMenu(_:)` (`@objc`), `UIAdaptivePresentationControllerDelegate`, `cleanupAfterMenuDismissal`; presents `PVGameMenuOverlay` → `PauseTileMenuView(emulatorVC:)` | Indicators, Menus, main (`menuPresentationViewController`, `isShowingMenu`, `enableControllerInput`) | |
| `+PerformanceLabls` | 154 | `initFPSLabel` (uses main's `fpsHUDView`, `fpsLabel`, `fpsTimer`, `themeDidChangeObserver`), `updateFPSLabel`, `memoryUsage`, `cpuUsage` | main (`applyFPSCounterVisibilityPreference`) | tvOS font size |
| `+Recording` | 406 | broadcast + screen recording + clip buffering (`PVRecordingManager`), assoc: `cameraOverlay`; started in `viewDidAppear`, stopped in `viewWillDisappear` when leaving | — | 12 `os(iOS)` blocks; clips on iOS+tvOS |
| `+Saves` | 307 | `autosaveTimer` create/destroy, `loadSaveState` (pause-around, `resumeOnce`), `convertOldSaveStatesToNewIfNeeded` | Achievements (hardcore gate), LiveActivities (`recordLiveActivityAutosave`), ScreenShot, protocol `createNewSaveState` | |
| `+ScreenShot` | 112 | `captureScreenshot` (picks render target, crops to picture rect) | render (gpu view), DualScreen, main (`currentTargetFrame`) | |
| `+Shaders` | 46 | `shaderGameMD5`, `shaderSelectionDidChange`, `shaderParametersDidChange` | render | |
| `+TransferPak` | 45 | `applyPersistedTransferPakIfNeeded` (before `startEmulation`) | — | |
| `+VirtualInputState` | 68 | assoc: `VirtualInputState`; `coreSupportsVirtualKeyboard/Mouse` | — | tvOS guard |
| `+VirtualKeyboard` | 504 | assoc: hosting VC, container, view model, hidden-by-HW, HW keyboard observers, frame cancellable; `setupVirtualInputOverlaysIfNeeded`, `removeVirtualInputOverlays`, `bringVirtualInputOverlaysToFront` (every layout pass), `VirtualKeyboardDelegate`, `KeyboardPassthroughView` | VirtualMouse, VirtualInputState, DeltaSkinScreen (viewport) | `!os(tvOS)` |
| `+VirtualMouse` | 343 | assoc: cursor host, `TouchTrackpadView`, `GCMouseMouseResponderDriver`, last valid viewport; `refreshVirtualMouseLayout` (every layout pass); `nonisolated takeVirtualMouseCleanupHandles()` for `deinit` | DeltaSkinScreen (`currentSkinViewportFrame`), VirtualInputState | iOS only |
| `+ZIP` | 52 | `handleArchives(atPath:)` | — | |

Helpers in the same folder that are already plain types and stay as they are:
`PVEmulatorControllerProtocol.swift` (457), `CoreActionTileProvider.swift` (413),
`SystemButtonTileProvider.swift` (87), `PauseMenuTile.swift` (109), `PauseMenuViewRegistry.swift` (54),
`PauseToggleCoalescer.swift` (39), `PlayTimeTracker.swift` (116), `CreateEmulatorError.swift` (43),
`CoreDidThrow+NotificationName.swift` (30), `EmulatorQuickActionBar.swift` (383), `VirtualInputState.swift` (83).
Consumers that take the concrete class: `PauseTileMenuView.swift` (2,420, `let emulatorVC: PVEmulatorViewController`),
`PauseTileMenuViewModel.swift` (1,308, `rebuild(emulatorVC:)`), `PVGameMenuOverlay.swift` (142),
`RetroMenuView*.swift` (3,670 + 4 extensions; the legacy list menu, untouched here).

### 3.3 Extensions in `Controller/`

| File | Lines | Owns | Depends on | Platform |
|---|---|---|---|---|
| `+DeltaSkin` | 1,301 | `isDeltaSkinEnabled`, `observeLiveSkinSelection` (`liveSkinSelectionTask`), skin scan/finalise, `observeAppStateChanges` (background/foreground publishers → `skinCancellables`), `observeOverlayScreenFrames`, `applyResolvedControllerVariantIfNeeded` + `observeCoreStartForControllerVariant`, `subscribeSkinLoadPause`, `configureGPUView`, `addSkinView`, `refreshGPUView`, debug overlay (~450 lines), `applyScreenFiltersFromCurrentSkin` | DeltaSkinScreen, DualScreen, Controllers (`hideOrShowMenuButton`) | 5 `!os(tvOS)` blocks |
| `+DeltaSkinDirect` | 19 | `setupDeltaSkinDirectly` (called from `viewDidLoad`) | DeltaSkin | |
| `+DeltaSkinScreen` | 1,185 | `PVViewportLayoutDelegate` conformance (`viewportFrameDidUpdate`), `applyViewportFromCurrentSkin`, `recomputeSkinViewportIfLayoutChanged`, skin frame maths (`calculateFrameFromSkin`, scale/offset/normalise), `adjustFrameForScalingMode`, `reapplyScalingModeForSkin`, `applyFrameToGPUView` → `applyFrameToRetroArch` (`EmulatorCoreViewportPositioning`) / `applyFrameToMetal` / `applyFrameToGL`, `hostGPUViewDrawsGame` (→ `HostGPUViewPolicy`), `coreManagesOwnHosting`, `revealHostGPUView`, `ensureGPUViewVisibilityAndZOrder`, assoc: `initialCorrectFrame` | render, DualScreen, main (viewport fields) | 6 `!os(tvOS)`, 3 `os(tvOS)` |
| `+LayoutEditor` | 112 | `openLayoutEditor`, hold gesture (`LayoutEditorHoldGestureRecognizer`), posts `.overlayEditLayoutRequested` | Indicators | iOS |
| `+ScreenFilter` | 26 | `applyScreenFilters` → gpu view | render | |

### 3.4 Launch and teardown paths that touch the host

- `EmulatorScene.presentEMU(withCore:forGame:source:)` (`PVSwiftUI/App Delegate/Scenes/EmulationScene/EmulatorScene.swift:540`)
  creates the core via `NSClassFromString(core.principleClass)`, constructs `PVEmulatorViewController(game:core:)`,
  stores it in `AppState.shared.emulationUIState.emulator`, adds it as a child, then calls `initCore()`.
  `viewDidLoad` calls `initCore()` again inside `createEmulator()` (the protocol method is not idempotent-guarded;
  both calls set paths, controllers, `romMD5`, `CoreOptionsContext.currentGameMD5`, and `core.initialize()`).
- `EmulatorScene.tearDownEmulatorAndClose(optionallySave:)` awaits `quit(optionallySave:)`, then detaches the child.
- The host's `quitCompletionHandler`/`onSuccessfulReturnToLibrary` closures and `SceneCoordinator.shared.closeEmulator()`
  are the return path.

### 3.5 Seams that must survive

These are the `@objc`, protocol and notification contracts other modules depend on. Every migration
step is checked against this list.

**Object identity handed to cores**
- `core.touchViewController = self` (`PVEmulatorCore.touchViewController: UIViewController?`, `@objc open`).
  Dolphin (`PVDolphinCore.mm:1345–1412`) adds its root controller and `m_view` into `touchViewController.view`
  and pins Auto Layout constraints to it; Azahar (`PVAzaharCoreBridge+Video.mm:63`) refuses to start without it;
  EmuThree does the same; PPSSPP (`PVPPSSPPCore+Video.mm:214–240`) constrains `m_view` to it; `PVLibRetroCore.m:3026`
  returns its view. The object must be a `UIViewController` whose `view` is the session's root for the whole session.
  The host remains that object; the render-surface object (step 8) is not handed to cores.
- `core.renderDelegate` (`PVRenderDelegate`, `@objc`) is `PVMetalViewController`; unchanged.
- `core.viewportLayoutDelegate` (`PVViewportLayoutDelegate`, `@objc`, assigned weakly) is the host today
  (`+DeltaSkinScreen`). It can move to the render-surface object in step 8 because it is a protocol, not a class.
- `core.audioDelegate` (`PVAudioDelegate`; `@objc func audioSampleRateDidChange()`) — host.
- `core.startEmulationCompletion: (@MainActor (Bool) -> Void)?` — host; it is the only place post-boot work may run
  (thin wrapper reports geometry and sample rate late; CLAUDE.md "Metal rendering gotchas").
- `staticSelf` + `NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)` → `core.emergencyStopEmulation()`.

**Notifications observed by the host (posters outside the folder)**
- `.PVEmulatorCoreDidFailToStart` (PVCoreBridge; posted by `PVThinLibretroFrontend.mm:5769`, `PVThinLibretroCore.swift:310`, `PVAzaharCore.swift:65`).
- `.pvThinLibretroFrontendCoreDidThrow` (`PVThinLibretroFrontendCoreDidThrowNotification`, `PVThinLibretroFrontend.mm:4923`).
- `PVOSDMessageNotification` (core bridges; `Cores/Mednafen/.../stubs.mm:21`).
- `"PauseGame"` (posted by `PVControllerManager.swift:397` and by the host's own `setupPauseHandler` closures; a magic string, see question 4).
- `.PVControllerManagerControllerReassigned`, `ControllerMappingStore.didChangeNotification`, `.PVControllerMicButtonToggleMute` (PVUIBase controller layer).
- `"DeltaSkinInputHandlerReconnect"`, `"DeltaSkinChanged"`, `"DeltaSkinReconnectMenuHandler"` (`DeltaSkinInputHandler.swift:2474/2482`); `.deltaSkinForceRecalculate`; `.overlayEditLayoutRequested`.
- `.GCControllerDidConnect/Disconnect`, `.GCKeyboardDidConnect/Disconnect`, `UIScreen.didConnect/DisconnectNotification`, the five `UIApplication` lifecycle notifications, `.themeDidChange`, `AVAudioSession.routeChangeNotification`.

**UIKit overrides (must stay members of the view controller class)**
`viewDidLoad`, `viewDidAppear`, `viewWillDisappear`, `viewWillTransition`, `viewDidLayoutSubviews`,
`pressesBegan/Ended/Cancelled` (`+KeyPresses`), `canPerformAction(_:withSender:)` and `validate(_:)` plus the
`@objc pvMenu*` responder actions (`+MenuBar`; the Mac menu bar sends them with a nil target, so they resolve
through the responder chain), `prefersStatusBarHidden`, `preferredScreenEdgesDeferringSystemGestures`,
`supportedInterfaceOrientations`, `prefersPointerLocked` (reads the light-gun GCMouse driver),
`preferredUserInterfaceStyle` (tvOS), `GCEventViewController.controllerUserInteractionEnabled` (tvOS).

**Protocol consumers**
`DeltaSkinInputHandler(emulatorCore:emulatorController: any PVEmualatorControllerProtocol)`,
`EmulationUIState.emulator: PVEmualatorControllerProtocol?` (read across PVSwiftUI), `GameLaunchingViewController`
(`resumeOnce`), `PauseTileMenuView` / `PauseTileMenuViewModel` / `PVGameMenuOverlay` / `EmulatorQuickActionBar`
(concrete class), `@objc extension PVEmulatorCore` in `+Cheats.swift` (`setCheat(code:type:enabled:)` is called from
ObjC-visible cheat UI paths).

## 4. Target architecture

### 4.1 What the host owns

```
PVEmulatorViewController (final class, @MainActor by inheritance)
├── core: PVEmulatorCore, game: PVGame            — identity
├── lifecycle                                      — createEmulator / finishEmulatorStart / quit,
│                                                    app-state notifications, isShowingMenu (pause authority),
│                                                    isQuitting, PauseToggleCoalescer, PlayTimeTracker, boot HUD,
│                                                    uncaught-exception hook, EmulationUIState / EmulationState
├── renderSurface: EmulatorRenderSurface           — gpuViewController attach/detach, own-view hosting handoff,
│                                                    external display, picture rect, dual screen, scaling mode,
│                                                    post-start aspect relayout, PVViewportLayoutDelegate
├── inputSurface: EmulatorInputSurface             — skin container / touch overlay / quick action bar /
│                                                    menu button / layout-editor hold gesture, coreInputHandler,
│                                                    on-screen-controls visibility, z-order restack
├── gameAudio: any AudioEngineProtocol             — graph setup, start/stop, mono, mute, route change
├── features: EmulatorFeatureRegistry              — ordered [any EmulatorSessionFeature]
└── UIKit overrides                                — view lifecycle, presses, menu-bar actions, appearance
```

After step 10 the class file holds the identity, lifecycle, audio and overrides, and the two
surface objects are created in `init`. Target: `PVEmulatorViewController.swift` under 900 lines
with no `type_body_length` disable.

### 4.2 `EmulatorSessionFeature`

```swift
/// One optional capability of a running emulator session (achievements, cheats, saves, …).
/// Created by `EmulatorFeatureRegistry` after the host's view loads; torn down in `detach()`.
/// All members are main-actor. A feature keeps its own state as stored properties, never in
/// associated objects, and never keeps a strong reference to the host.
@MainActor
public protocol EmulatorSessionFeature: AnyObject {
    /// Stable id, also the prefix of every pause-menu tile the feature contributes.
    static var id: EmulatorFeatureID { get }

    /// `nil` when the feature does not apply to this core / platform / settings
    /// (e.g. `LightGunFeature` for a core that is not a `LightGunResponder`). The registry skips it.
    init?(host: any EmulatorSessionHost)

    /// After `viewDidLoad`, before `createEmulator()`. Install views and observers.
    func attach()
    /// From `finishEmulatorStart`: the core has loaded the ROM and reports real geometry / sample rate.
    func coreDidStart()
    /// `viewDidAppear` / `viewWillDisappear(leaving:)`. `leaving` is `isMovingFromParent || isBeingDismissed`.
    func hostDidAppear()
    func hostWillDisappear(leaving: Bool)
    /// `viewDidLayoutSubviews`, after the surfaces have restacked.
    func hostDidLayout()
    /// The host paused or resumed the core, with the reason (menu, background, resign-active, user).
    func sessionDidPause(_ reason: EmulatorPauseReason)
    func sessionDidResume()
    /// From `quit()`, before `core.stopEmulationAfterLoopExits()`. May await (netplay disconnect).
    func willStopCore() async
    /// From `quit()`, after the emulation loop has exited. Symmetric with `attach()`.
    func detach()

    /// Pause-menu contribution. Called on every `PauseTileMenuViewModel.rebuild`.
    func pauseMenuTiles(for route: PauseTileMenuRoute) -> [PauseMenuTileContribution]
    /// `true` when the feature handled the tap. `menu` dismisses, resumes or presents on the feature's behalf.
    func handlePauseMenuTile(id: String, menu: any PauseMenuDismissing) -> Bool
    func handlePauseMenuLongPress(tileID: String, option: PauseMenuTileLongPressOption) -> Bool
}

public extension EmulatorSessionFeature {   // every hook defaults to a no-op
    func attach() {} ; func coreDidStart() {} ; func hostDidAppear() {} ; func hostWillDisappear(leaving: Bool) {}
    func hostDidLayout() {} ; func sessionDidPause(_: EmulatorPauseReason) {} ; func sessionDidResume() {}
    func willStopCore() async {} ; func detach() {}
    func pauseMenuTiles(for _: PauseTileMenuRoute) -> [PauseMenuTileContribution] { [] }
    func handlePauseMenuTile(id _: String, menu _: any PauseMenuDismissing) -> Bool { false }
    func handlePauseMenuLongPress(tileID _: String, option _: PauseMenuTileLongPressOption) -> Bool { false }
}

public struct PauseMenuTileContribution: Equatable, Sendable {
    public let sectionID: String        // "game", "statesData", "settingsData", "controlsData", "quickSettingsData", "menu", "displayData", "core"
    public let tiles: [PauseMenuTile]
}
```

`EmulatorFeatureRegistry` is a plain `@MainActor final class` with `features: [any EmulatorSessionFeature]`
in declaration order, `feature<T>(_: T.Type) -> T?`, and one method per hook that fans out. It is also
where the quit order lives: `willStopCore()` runs in registration order, `detach()` in reverse.
The feature list is a static table in the host (`EmulatorFeatureCatalog.all`), so a test can assert
which features apply to a fake host.

The pause menu's `switch tile.id` shrinks to: resume / quit / states / core-options cases that stay in the
view, then `features.handlePauseMenuTile(id:menu:)`. Tile ids keep their current strings (`"recording"`,
`"saveClip"`, `"audioVisualizer"`, …) so `PauseTileMenuViewModel`'s route tables and `PauseMenuTileTests`
do not change.

### 4.3 `EmulatorSessionHost` (what features see)

Kept from `PVEmualatorControllerProtocol`: `core`, `game`, `isShowingMenu`, `gameAudio`, `coreInputHandler`,
`quit(optionallySave:completion:)`, `quicksave()`, `quickload()`, `autoSaveState()`, `captureScreenshot()`,
`takeScreenshot()`, `showMenu(_:)`, `hideMenu()`, `controllerPauseButtonPressed(_:)`,
`saveStatePersistenceService`, the path accessors and `initCore()` (protocol extensions move unchanged).

Added:

```swift
@MainActor
public protocol EmulatorSessionHost: AnyObject {
    // … kept members above …
    var viewController: UIViewController { get }        // `self`; for presentation and as touchViewController
    var hudContainer: UIView { get }                     // above the surfaces, below toasts: HUDs, indicators, visualizer
    var renderSurface: any EmulatorRenderSurfacing { get }
    var inputSurface: any EmulatorInputSurfacing { get }
    var isQuitting: Bool { get }
    var pictureRect: CGRect { get }                      // last applied viewport in view coordinates (dual-screen: union)
    var pictureRectDidChange: AnyPublisher<CGRect, Never> { get }
    func setPaused(_ paused: Bool, reason: EmulatorPauseReason)   // the only way a feature pauses the core
    func dismissNav(resumeEmulation: Bool, completion: (() -> Void)?)
    func present(_ vc: UIViewController, animated: Bool, completion: (() -> Void)?)  // re-enables controller input on dismiss
    func feature<T: EmulatorSessionFeature>(_ type: T.Type) -> T?
}
```

Removed from the protocol (they become feature members or tile handlers): `init(game:core:)` (only
`EmulatorScene` constructs it), `audioInited`, `autosaveTimer`, `hideOrShowMenuButton`, `showCoreOptions`,
`showMoreInfo`, `hideMoreInfo`, `showSpeedMenu`, `showSwapDiscsMenu`. `EmulationUIState.emulator` and
`DeltaSkinInputHandler` keep compiling through the typealias.

`EmulatorRenderSurfacing` exposes `gpuViewController`, `hostGPUViewDrawsGame`, `pictureRect`,
`applyFrame(_:reason:)`, `reapplyScalingMode()`, `attachToExternalScreen(_:)`, `restoreToDevice()`.
`EmulatorInputSurfacing` exposes `isSkinActive`, `isProgrammaticOverlayActive`, `isDesktopMode`,
`setOnScreenControlsHidden(_:)`, `restack()`, `overlayLayer(for: OverlayLayer) -> UIView` (the z-order
slots: `.underSkin`, `.aboveSkin`, `.hud`, `.cursor`; replaces `bringVirtualInputOverlaysToFront` /
`ensureVisualizerOnTop` / `keepOverlayMenuButtonInFront`).

### 4.4 Features

| Feature | Replaces | Tiles | Hooks used |
|---|---|---|---|
| `PerformanceHUDFeature` | `+PerformanceLabls`, FPS members on the class | `fpsCounterToggle` | attach, coreDidStart, hostDidLayout, detach |
| `FirstFrameWatchdogFeature` | `+FirstFrameWatchdog` | — | coreDidStart |
| `OSDBridgeFeature` | `+OSD` | — | attach, detach |
| `AudioRouteFeature`, `AudioMuteWarningFeature` | `+AudioRoute`, `+AudioMuteWarning` | — | attach, coreDidStart |
| `IndicatorsFeature` | `+Indicators` | — | coreDidStart, sessionDidPause/Resume (hide while the menu is up), detach |
| `JITFeature` | `+JIT` | — | coreDidStart, hostWillDisappear, detach |
| `LiveActivityFeature` | `+LiveActivities` | — | coreDidStart, sessionDidPause/Resume, willStopCore |
| `AchievementsFeature` | `+Achievements` | — (gates are queried by Saves, Cheats, speed) | coreDidStart, detach (after loop exit) |
| `SavesFeature` | `+Saves`, `pendingAutoSaveTask`, timer in `viewDidAppear` | `saveState`, `loadState`, `browseSaves`, `autoSaveState` | hostDidAppear, hostWillDisappear, sessionDidPause(.resignActive), willStopCore |
| `ScreenshotFeature` | `+ScreenShot` | `screenshot`, `screenshots` | — |
| `CheatsFeature` | `+Cheats` (minus the `PVEmulatorCore` shim) | `cheats` | attach (recover codes), tile |
| `RecordingFeature` | `+Recording` | `recording`, `broadcast`, `saveClip`, `cameraPosition` | hostDidAppear, hostWillDisappear(leaving:) |
| `NetplayFeature` | `+Netplay` | `netplay` | coreDidStart, willStopCore (awaited) |
| `CompanionControllerFeature` | `+CompanionController` | `companion` | tile, detach |
| `CoreOptionsFeature` | `+CoreOptions`, `+MultiDisc`, `+TransferPak`, `+CoreScalingMode` | core option/action tiles (via the two providers), `swapDisc` | attach (transfer pak before start), coreDidStart |
| `VirtualInputFeature` | `+VirtualKeyboard`, `+VirtualMouse`, `+VirtualInputState`, `+KeyboardHUD` | `keyboardToggle`, `mouseToggle` | attach, hostDidAppear, hostDidLayout, hostWillDisappear, detach |
| `LightGunFeature` | `+LightGun` | `lightGunToggle` | attach, hostDidLayout, hostWillDisappear, detach |
| `SiriRemoteFeature` (tvOS) | Siri Remote half of `+Controllers` | — | coreDidStart, hostWillDisappear(leaving:) |
| `AudioVisualizerFeature` (iOS) | `+AudioVisualizer` | `audioVisualizer` | hostDidAppear, hostDidLayout, detach |
| `ShaderFeature` | `+Shaders`, `+ScreenFilter` | `filterCycle`, `shaderSettings` | coreDidStart |
| `AltRepresentationsFeature` | `+AltRepresentations` | `altLayout` | attach (installs on `coreInputHandler`) |
| `LayoutEditorFeature` | `+LayoutEditor` | `editLayout` | attach |

Stays on the host: `+Controllers` (pause handling, controller connect/disconnect, external screens),
`+PauseMenu`, `+Menus` (slimmed to `hideMenu`/`showMoreInfo`), `+MenuBar`, `+KeyPresses`, `+ZIP`,
`+DualScreen`/`+MetalDualScreen`/`+DualScreenLCD` (move into the render surface in step 8), the skin
management extension and `+DeltaSkin*` (move into the input and render surfaces in steps 8–9).

## 5. Migration plan

Ten steps, each a PR against `develop`, each leaving every scheme building and every session
behaving as before. Tests go in `PVUI/Tests/PVUIBaseTests/` as Swift Testing suites over
`nonisolated static func` decision tables, in the style of `EmulatorQuickActionBarTests` and
`HostGPUViewPolicyTests`; the feature objects themselves are exercised through a `FakeEmulatorSessionHost`
that records hook calls (no UIKit view hierarchy needed for the pure parts). "Device check" names
the cores and platforms that must be run by hand before merge; everything else is covered by the
simulator harness (`make dev-harness`) or has no rendering effect.

Per CLAUDE.md, steps that add a file to PVUIBase need no pbxproj edit (SwiftPM target), but
`Scripts/audits/check_pbxproj_sources.py` still runs in CI; new test files go in the existing test target.

### Step 1 — Protocol, registry, first feature (PerformanceHUD)

- Add `EmulatorSession/EmulatorSessionFeature.swift`, `EmulatorFeatureRegistry.swift`, `EmulatorFeatureCatalog.swift`,
  `EmulatorSessionHost.swift` (new protocol name; `PVEmualatorControllerProtocol` becomes the typealias; the file keeps its
  protocol extensions).
- Add `Features/PerformanceHUDFeature.swift`: owns `fpsHUDView`, `fpsLabel`, `fpsTimer`, the theme observer, the
  `Defaults.publisher(.showFPSCount)` subscription, `memoryUsage`/`cpuUsage`. Delete `+PerformanceLabls.swift`
  and the eight FPS members from the class (`applyFPSHUDTheme`, `applyFPSCounterVisibilityPreference`,
  `configureFPSCounterPreferenceObservationIfNeeded`, their teardown lines in `quit`).
- Host: create the registry in `init`, call `attach()` at the end of `viewDidLoad`, `coreDidStart()` at the end of
  `finishEmulatorStart`, `hostDidLayout()` at the end of `viewDidLayoutSubviews`, `detach()` in `quit` after
  `stopAchievements()`. Other hooks are wired but have no subscribers yet; the `fpsCounterToggle` tile keeps its
  id and moves its handler into the feature.
- Files: `PVEmulatorViewController.swift`, `+PerformanceLabls.swift` (deleted), `PVEmulatorControllerProtocol.swift`,
  `PauseTileMenuView.swift` (one case), `PauseTileMenuViewModel.swift` (one tile).
- Tests: `EmulatorFeatureRegistryTests` (hook fan-out order, reverse `detach`, `feature(_:)` lookup, `init?` returning
  nil skips the feature); `PerformanceHUDFeatureTests` (`PerformanceHUDFeature.isShown(enabled:skipLayout:)`,
  `labelText(fps:cpu:memory:)` formatting, tvOS font size).
- Device check: none (simulator harness screenshot with the FPS counter on).

### Step 2 — Small observers

- `OSDBridgeFeature` (+OSD), `FirstFrameWatchdogFeature`, `AudioRouteFeature`, `AudioMuteWarningFeature`.
  `registerForOSDNotifications()` and `registerAudioRouteChangeObserver()` leave `initNotificationObservers()`.
- Tests: `OSDMessage(userInfo:)` decoding (type mapping, zero/negative duration → 3 s); `FirstFrameWatchdog.report(…)`
  string builder and the "presenter draws its own view" exemption; `AudioMuteWarning.shouldWarn(outputVolume:isMuted:shownThisLaunch:)`.
- Device check: none.

### Step 3 — Indicators, JIT, Live Activities

- Convert the three associated-object groups to stored properties on `IndicatorsFeature`, `JITFeature`,
  `LiveActivityFeature`. `isShowingMenu.didSet` calls `features.sessionDidPause(.menu)` / `sessionDidResume()`
  instead of `setLiveActivityPaused`; `showMenu` / `cleanupAfterMenuDismissal` stop calling
  `temporarilyHideIndicatorOverlay` / `restoreIndicatorOverlay` directly.
- `cancelJITIndicatorSubscription()` leaves `deinit`: the subscription is cancelled in `hostWillDisappear(leaving: true)`
  and `detach()`. (`deinit` keeps only the exception-handler reset, `staticSelf = nil`, `core.touchViewController = nil`
  and the `MainActor.assumeIsolated` safety nets; see section 6.1.)
- Tests: `JITFeature.applies(to:)` over `jitRequirement` (extends `JITCoreCapabilityTests`); `LiveActivityFeature`
  pause/resume/autosave state machine with a fake activity client; indicator visibility when the menu is up.
- Device check: tvOS pause menu open/close keeps the JIT pill and indicator overlay in sync (mGBA, Dolphin).

### Step 4 — Achievements

- `AchievementsFeature` owns the session manager, overlay, start token, points, loaded ROM URL, and the
  `RetroAchievementsOSDDelegate` conformance. The quit ordering is encoded in the hooks: `detach()` runs after
  `core.stopEmulationAfterLoopExits()`, which is what `stopAchievements()` requires (rcheevos is `RC_NO_THREADS`).
- The gates become `AchievementGates` (pure `enum`): `blocksSaveStateLoad(hardcore:active:hasSession:)`,
  `blocksFastForward`, `blocksRewind`, and `speedAfterGate(requested:hardcore:)`. Callers (`quickload` in the protocol
  extension, `EmulatorQuickActionBar`, `PauseTileMenuView`, `DeltaSkinInputHandler`, Cheats) go through
  `host.feature(AchievementsFeature.self)?.blocks…` with a `false` default.
- Tests: `AchievementGatesTests` (every combination; thin/RetroArch cores with `achievementsActive == false`
  but a live session still block).
- Device check: iOS and tvOS, logged in: unlock an achievement (snes9x or mGBA); in hardcore, quick load and
  fast-forward are refused with the toast; soft-core allows both; quit while an unlock toast is on screen does not crash.

### Step 5 — Saves, screenshots, cheats, recording

- `SavesFeature`: autosave timer (created in `hostDidAppear` unless quitting, destroyed in `hostWillDisappear` and
  `willStopCore`), `loadSaveState`, `convertOldSaveStatesToNewIfNeeded`, and the resign-active autosave
  (`pendingAutoSaveTask`) which `sessionDidPause(.resignActive)` starts and `sessionDidResume()` awaits before the
  host unpauses. `ScreenshotFeature` keeps `captureScreenshot()` reachable through the host protocol (menu-bar
  action and autosave thumbnails use it). `CheatsFeature` takes `+Cheats` minus the `@objc extension PVEmulatorCore`,
  which moves to its own file `PVEmulatorCore+CheatShim.swift` unchanged. `RecordingFeature` takes `+Recording`.
- Tests: `AutosavePolicy.shouldAutosave(lastAutosaveAge:lastManualSaveAge:minimumGap:)`; `AutosaveTimerPolicy`
  (skip when quitting or in background); `CheatCodeNormalizerTests` (exists as private code today; make it internal);
  `RecordingFeature.availability(isSupported:hasController:plusActive:)` and the clip-buffer stop rule
  (`leaving` only).
- Device check: iPhone: background the app mid-game, return, play, quit — one autosave on resign-active, no second
  save on resume, no `0x8BADF00D`; Record 10 s and Save Clip; tvOS: Save & Quit and resume from the autosave.

### Step 6 — Core-facing features and tile dispatch

- `CoreOptionsFeature` (+CoreOptions, +MultiDisc, +TransferPak, +CoreScalingMode), `NetplayFeature`,
  `CompanionControllerFeature`. `PauseTileMenuViewModel.rebuild` appends `features.pauseMenuTiles(for:)` into the
  named sections; `PauseTileMenuView.handleTileTap` tries `features.handlePauseMenuTile` before its own switch; the
  `takeNetworkPlayMenuRequest` read moves behind the feature.
- Tests: `PauseTileRouterTests` (every tile id in the route tables maps to exactly one owner: view or feature);
  per-feature tile tables given capabilities, like `CoreActionTileProviderTests`; `NetplayFeature.launchIntent`
  timing table (`readyTimeout`, `hostMenuDelay`).
- Device check: netplay host from the library lobby (gpSP, two devices, LAN) still opens the host menu after boot;
  N64 Transfer Pak slot persists across launches (Mupen); disc swap on a PSX multi-disc game (thin mednafen_psx_hw).

### Step 7 — Input-side features and the overlay stack

- Introduce `EmulatorInputSurface` with `restack()` and the `OverlayLayer` slots, called once from
  `viewDidLayoutSubviews` instead of the three `bring*ToFront` calls. `VirtualInputFeature`
  (+VirtualKeyboard, +VirtualMouse, +VirtualInputState, +KeyboardHUD), `LightGunFeature`, `SiriRemoteFeature`
  (tvOS half of +Controllers), `AudioVisualizerFeature`. The two `nonisolated take*CleanupHandles()` methods go
  away: the views are removed in `hostWillDisappear(leaving: true)` / `detach()`.
- `prefersPointerLocked` reads `features.feature(LightGunFeature.self)?.gcMouseDriver != nil`.
- Tests: `OverlayStackOrderTests` (the layer order is total and stable; cursor above keyboard above skin above GPU
  view); `VirtualInputFeature.applies(to:)` for keyboard/mouse cores; `SiriRemoteFeature` mode toggles.
- Device check: iPad desktop mode (Mac "Designed for iPad" too): DOSBox-pure or ScummVM libretro — virtual keyboard
  and trackpad show/hide, keyboard HUD survives the pause menu (⇧⌘M), hardware keyboard hides the overlay;
  iPhone: light gun on NES (FCEU) and the GCMouse driver; tvOS: Siri Remote keyboard/mouse on a keyboard core
  and light gun tap/reload; skin session: overlays sit above the skin after rotation.

### Step 8 — Render surface

- `EmulatorRenderSurface` (`@MainActor final class`, `PVViewportLayoutDelegate`) takes `gpuViewController`, the
  three attach branches from `setupGPUView` / `createEmulator` (expressed as `RenderSurfacePolicy.attachment(for:)`),
  `attachGPUView(to:)` / `restoreGPUViewToDevice`, `applyPostStartAspectIfChanged`, `+DualScreen`, `+MetalDualScreen`,
  `+DualScreenLCD`, `+Shaders`/`+ScreenFilter`, and the viewport maths from `+DeltaSkinScreen`
  (`applyFrameToGPUView` → Metal / GL / `EmulatorCoreViewportPositioning`). The host keeps `touchViewController = self`
  and the hosting decision (`coreManagesOwnHosting`), because the identity handed to cores must stay the view
  controller (section 3.5). `pictureRect` / `pictureRectDidChange` become the one source other code reads.
- Tests: `RenderSurfacePolicyTests` (attachment per `coreID` × `skipLayout` × skin present × platform; encodes the
  current `#if os(tvOS)` branches); `HostGPUViewPolicyTests` and `DualScreenSourceMappingTests` unchanged;
  `PostStartAspectPolicy.needsRelayout(previous:current:)`.
- Device check (the largest): own-view cores — Dolphin iOS + tvOS, Azahar iOS, EmuThree iOS, native PPSSPP iOS + tvOS
  (boot, render, pause/resume, rotate, quit, relaunch another core); thin libretro virtualjaguar on tvOS (the
  late-aspect fix); melonDS DS skin dual screen and swap; Azahar 3DS LCD overlay; external display in dedicated mode
  (iPad + AirPlay); `[NO-FRAME]` never fires on a working boot. Both skin and overlay sessions on iPhone, portrait
  and landscape.

### Step 9 — Input surface

- `EmulatorInputSurface` absorbs the skin-management extension (`applySkin`, `createSkinView`, `radicalCleanup`,
  fallback search, rotation), `+DeltaSkin.swift`, `+DeltaSkinDirect.swift`, `+LayoutEditor.swift`, the menu button,
  `EmulatorQuickActionBar` and `SubtleVolume` installation, `hideOrShowMenuButton` / `updateOnScreenControlsVisibility`,
  and ownership of `coreInputHandler`. `isDeltaSkinEnabled`, `isProgrammaticOverlayActive` become surface properties.
  The ~450-line skin debug overlay (`toggleDebugOverlay`, a two-finger triple tap) moves into a
  `SkinDebugOverlayFeature` so it stops living on the host; whether it survives at all is the owner's call.
- Tests: `MenuButtonPolicyTests` (`hideOrShowMenuButton`'s rule as `MenuButtonPolicy.isHidden(skinEnabled:overlayActive:skinLoaded:graceExpired:)`);
  `OnScreenControlsPolicy.hidden(hideWithController:controllers:)`; skin fallback-order table.
- Device check: iPhone and iPad, portrait and landscape: a skin with a screen cutout, the touch overlay, a skin that
  fails to load (menu button comes back after the 3 s grace), the layout editor hold gesture, desktop-mode quick
  action bar and volume HUD, skin change from the pause menu, alt-representation toggle.

### Step 10 — Collapse

- Delete the `PVEmualatorControllerProtocol` typealias and every remaining `objc_setAssociatedObject` in the folder;
  remove `swiftlint:disable:next type_body_length`; `initCore()` guarded so the `EmulatorScene` + `viewDidLoad` double
  call initialises once; decide on the rename (question 1).
- Tests: a `PVEmulatorVCSourceAuditTests` that greps the folder at test time for `objc_setAssociatedObject` and
  `PVEmualatorControllerProtocol` (zero hits), mirroring the CI audit scripts.
- Device check: one smoke pass per platform (iOS, tvOS) on a native core, a thin core and an own-view core.

## 6. Risks and non-goals

### 6.1 Thread and actor boundaries

- PVUI compiles in Swift 5 language mode (`swiftLanguageModes: [.v5]` in `PVUI/Package.swift`) with the Swift 6
  compiler; `PVEmulatorCore` is `.v6` and `PVCoreBridge`/`PVTouchOverlay` declare both. `UIViewController` is
  `@MainActor`, so the host and every feature are main-actor by inheritance or annotation, but `deinit` is
  nonisolated — phase 3 needed `MainActor.assumeIsolated` around `quickActionBar?.invalidate()`. Rule for this phase:
  **features never clean up in `deinit`.** All teardown is in `detach()` / `hostWillDisappear(leaving: true)`, which
  the host calls from main-actor code. The host's `deinit` keeps only the non-UI safety nets it has today.
- `startEmulationCompletion` is `@MainActor`; `coreDidStart()` is dispatched from it, never from the core's boot thread.
- `handleControllerMappingsChanged` is `@objc nonisolated` and hops to main itself; features that observe
  `NotificationCenter` use `.receive(on: DispatchQueue.main)` or `Task { @MainActor }` like the existing code, and
  never touch the core from the posting thread.
- Timers (`autosaveTimer`, the record pulse, the FPS timer) fire on main; their closures check `host.isQuitting`
  first, as the autosave timer does now.

### 6.2 Emulation-loop and Metal rules

- The emu loop holds `@synchronized(self)` around `executeFrame` at 60 fps. Features never call `core.setPauseEmulation`
  directly; `host.setPaused(_:reason:)` is the single authority (it is `isShowingMenu`'s `didSet` today and keeps the
  `core.isOn, !isQuitting` guard). `quit()` keeps awaiting `stopEmulationAfterLoopExits()` off-main before anything
  that frees core-owned memory (rcheevos, netplay bridge).
- `PVMetalViewController.draw(in:)` must early-return when `UIApplication.shared.applicationState != .active`
  (CLAUDE.md "Metal rendering gotchas"). The render surface never calls `draw`, never reads `currentDrawable`, and
  `sessionDidPause(.background)` runs after the host has paused the core and audio (`appDidEnterBackground` order
  is unchanged).
- The thin wrapper reports geometry, aspect and sample rate only after `startEmulation`. Anything that sizes itself
  from the picture must subscribe to `pictureRectDidChange` or do its work in `coreDidStart()`; reading
  `core.aspectSize` or `core.audioSampleRate` in `attach()` reproduces the bugs `applyPostStartAspectIfChanged` and the
  audio-graph rebuild fixed.

### 6.3 tvOS

- The root class is `GCEventViewController`; `enableControllerInput(_:)` flips `controllerUserInteractionEnabled` and
  the manager's flag together. Features never present view controllers directly — `host.present` is what re-enables
  controller input on dismiss and rebinds pause handlers (`restoreInputStateAfterMenuDismissal`).
- The Menu-press recognisers (`setupTVOSMenuGestures`, re-run in `viewDidAppear`, `finishEmulatorStart` and after
  modals) and `reestablishPauseHandlers` stay on the host; they are not features.
- `SiriRemoteFeature` installs handlers on `GCMicroGamepad` and must remove them in `detach()` exactly as
  `teardownSiriRemoteForLightGun` restores the saved handler today.

### 6.4 Own-view cores

- Dolphin, Azahar, EmuThree and native PPSSPP build their UIKit hierarchy inside `touchViewController.view`, in
  `-setupView` paths that have no `else`: a nil host means the core never starts (comment in `createEmulator`).
  The handoff (`core.touchViewController = self` for every core except libretro and PPSSPP, which get it only when no
  skin layer is up) stays verbatim on the host until step 8, and step 8 may change where it is called from but not
  what object is handed over. `HostGPUViewPolicy` keeps deciding whether the host GPU view is shown.
- The queued own-view hosting spec (`EmulatorCoreViewportPositioning` positioning for cores that draw to their
  own view) is downstream of step 8: the render surface is where a per-core positioning strategy would plug in.
  This spec does not design it (question 5).

### 6.5 Platform scope

- iOS 17+ and tvOS 17+ ship. Mac Catalyst is not supported; the existing `!targetEnvironment(macCatalyst)` guards are
  carried over as they are and no Catalyst code is added. Desktop input mode means iPad with keyboard/gamepad
  navigation and "Designed for iPad" on Apple Silicon. macOS/visionOS guards stay compile-only.

### 6.6 Non-goals

- No rename of `PVEmulatorViewController` before step 10; no change to `EmulatorScene` / `SceneCoordinator` beyond
  the `initCore()` guard.
- No new feature behaviour, no settings changes, no change to `PauseTileMenuView`'s layout, routes or tile ids.
- `RetroMenuView` (the legacy list menu, 3,670 lines) is not touched.
- `PVMetalViewController` internals, `DeltaSkinView` / `DeltaSkinInputHandler`, and `PVTouchOverlay` are not touched
  beyond the host type they accept.
- No Realm → SwiftData work; `saveStatePersistenceService` stays the seam for #2510.
- No move of features into a new package.

## 7. Open questions for the owner

1. **Class name at step 10:** keep `PVEmulatorViewController`, or rename to `EmulatorHostViewController` and update
   `EmulatorScene`, `SentryEventFilter`'s transaction-name strings and the memory notes in one commit?
2. **Package boundary:** stay in `PVUIBase/EmulatorSession/`, or split the Realm-free features (Performance HUD,
   OSD, watchdog, indicators, JIT, live activity, netplay, visualizer) into a `PVEmulatorSession` package later so
   they can `swift test` without Xcode?
3. **Pause-menu ordering:** keep the section order table in `PauseTileMenuViewModel` with features contributing
   into named sections (this spec), or let each feature declare a section with a sort key so the view model owns
   no feature knowledge at all?
4. **`"PauseGame"`:** where should the constant live — `PVUIBase` (`PVControllerManager` posts it) or `PVCoreBridge`
   next to `PVEmulatorCoreDidFailToStart`? Nothing outside PVUI observes it today.
5. **Own-view hosting:** should step 8 wait for the `EmulatorCoreViewportPositioning` own-view hosting spec and be
   its vehicle, or ship first with today's behaviour and have that spec build on `EmulatorRenderSurface`?
