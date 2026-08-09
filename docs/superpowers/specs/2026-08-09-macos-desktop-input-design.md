# macOS Desktop Input UX — Design & Implementation Brief

**Date:** 2026-08-09  **Branch:** `feature/macos-desktop-input`
**Context:** Provenance on Mac is the iOS binary via "Designed for iPad" (Catalyst was removed 2026-08-08).
Predecessor spec: `docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md`.

## Problem

On Mac today the app behaves like an iPad app in a window:

1. **Touch skin renders on Mac.** `isDeltaSkinEnabled` guards on `os(tvOS) || os(macOS) || targetEnvironment(macCatalyst)` — all three are **false** in a Designed-for-iPad binary, so the `#else` branch runs and the skin draws. Same for the legacy OSD's `setupTouchControls()`, guarded `#if os(iOS) && !targetEnvironment(macCatalyst)`.
2. **Keyboard is not player 1 by default.** `GamepadManager.connectKeyboardControllerIfAvailable()` is gated on `Defaults[.controllerStyleNavigation]` (default **false**), so on Mac the virtual keyboard controller is never created.
3. **No menu bar.** `PVEmulatorViewController` registers zero key commands; there is no `UIMenuBuilder` anywhere in the repo.
4. **Hit targets are finger-sized.** Hit-testing uses a hardcoded `-20pt` inset; skins' authored `extendedEdges` is parsed but **never applied** (debug-display only).

## Core architecture: one predicate

All behavior keys off a single source of truth. **Mac unconditionally; iPad opts in** via the already-shipped key (no Defaults migration):

```swift
/// True when the app should behave like a desktop: keyboard is player 1,
/// no on-screen touch controls, keyboard HUD available.
/// Mac ("Designed for iPad") always; iPad opts in via Settings > Controller.
public static var isDesktopInputMode: Bool {
    ProcessInfo.processInfo.isiOSAppOnMac || Defaults[.controllerStyleNavigation]
}
```

`ProcessInfo.processInfo.isiOSAppOnMac` is the ONLY runtime Mac hook that exists in this codebase (3 current uses, all haptics-suppression in `DeltaSkinView.swift:884,1867,2312`). Compile-time `os(macOS)` is false here — do not use it.

**Scope limit (deliberate):** this predicate governs **in-game input only**. It must NOT flip the library into the TV-style UI on Mac — Mac has a pointer and the standard library is correct there. `MainView.shouldUseTVMediaUI` keeps its existing gate.

---

## Phase A — Make Mac usable

### A1. Home for the predicate
Add `isDesktopInputMode` as a static on `GamepadManager` (PVUIBase, already imports `Defaults`/`PVSettings` and is the natural owner of input-mode state). It must be reachable from PVUIBase and PVSwiftUI.

### A2. Suppress touch controls on Mac
- `PVUI/Sources/PVUIBase/Controller/PVEmulatorViewController+DeltaSkin.swift:15-22` — `isDeltaSkinEnabled` returns `false` when `isDesktopInputMode`. Keep the existing compile-time guards; add the runtime check to the `#else` branch.
- `PVUI/Sources/PVUIBase/Controller/OSD/PVControllerViewController.swift` — the `setupTouchControls()` / `layoutViews()` path (~:521-527) must no-op under `isDesktopInputMode`. Do not delete the compile-time guards; add a runtime early-return.
- Verify nothing else (skin container, toggle buttons, `updateHideTouchControls`) leaves an orphaned empty view or a stray toggle affordance on screen.

### A3. Keyboard as player 1
- `GamepadManager.connectKeyboardControllerIfAvailable()` is currently gated on `Defaults[.controllerStyleNavigation]`. Change that gate to `isDesktopInputMode` so Mac gets the virtual keyboard controller unconditionally.
- Gamepad precedence already works and must NOT be changed: `PVControllerManager.assignAuto(_:)` (~:709-730) already lets a real gamepad displace a keyboard/remote from a slot. Verify by reading it; do not reimplement.
- The runtime toggle observer added previously (`Defaults.publisher` in GamepadManager) must keep working for the iPad opt-in path.

### A4. Menu bar commands
`showMenu(_:)` is `@objc @MainActor public` at `PVEmulatorViewController+PauseMenu.swift:23` — this is the exact API to call; `hideMenu()` is its counterpart.
- Add a **Game** `CommandMenu` to the emulator scene's existing `.commands` block in `PVUI/Sources/PVSwiftUI/App Delegate/Scenes/EmulationScene/EmulatorScene.swift` (already `#if !os(tvOS)`).
- Items: **Show Menu** (⇧⌘M — NOT ⌘M, which is Minimize on macOS) calling `showMenu(nil)` on the current emulator VC, alongside the existing ⌘P pause.
- Reach the VC the same way the existing ⌘L command does (`appState.emulationUIState.emulator`, downcast to `PVEmulatorViewController` — `loadSaveState` is on the concrete class, not the protocol).

---

## Phase B — Keyboard HUD

A translucent in-game overlay showing keyboard input, with rebinding.

**Behavior:** invisible by default → any mapped keypress fades it in → auto-fades after ~2s of no input → a menu-bar item / shortcut pins it open → **pinned mode only** exposes click-a-key-to-rebind.

**Hosting:** copy the existing pattern in `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+VirtualKeyboard.swift` — a child `UIHostingController` in a passthrough container floating over the game, with `show/hide/toggle` and `bringVirtualInputOverlaysToFront()`. That file already observes `.GCKeyboardDidConnect/Disconnect`; mirror it, don't fight it.

**Styling:** model translucency on `DeltaSkinKeyboardOverlayView.swift` (uses `config.opacity`) and the RetroWave design system (`RetroTheme`, `Color.retroPink/retroBlue`, `retroPausePanelBackground`). It should look deliberate, not like a debug label.

**Rebinding reuses shipped model — do NOT duplicate:** `KeyboardControllerMap` / `KeyboardControllerAction` in `PVUI/Sources/PVUIBase/Controller/KeyboardControllerMap.swift` (`current`, `standard`, `keys(for:)`, `set(keys:for:)`, `save()`, `displayName`). After a rebind call `PVControllerManager.shared.rebuildKeyboardController()`.

**Capture-mode hazard (this bit a previous task — read before writing):** taking over `GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler` and restoring a stale value silently kills keyboard input app-wide. `KeyboardMappingView.swift` solves this already (ordered `endCapture()` before any rebuild, plus `.GCKeyboardDidConnect/Disconnect` observers that abort capture WITHOUT a restore-write). Follow that implementation exactly.

**Gate:** only available when `isDesktopInputMode`. Add the pin toggle to the Game menu (Phase A4).

---

## Phase C — Pointer-sized hit targets

Independent of Mac (Mac hides the skin); this mainly serves **iPad with trackpad/mouse**.

In `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/DeltaSkinView.swift`:
- Hardcoded `insetBy(dx: -20, dy: -20)` appears at **three** sites: `:1328` (existing-touch re-check), `:1380` (candidate scan in `handleTouchAtLocation`), `:1898` (`hitTest(_:in:)`). Thumbstick margin `12` at `:1023`.
- **Extract the magic numbers to named constants** (CLAUDE.md forbids magic numbers) used by all sites.
- **Honor `extendedEdges`.** `DeltaSkinButton.extendedEdges` (`DeltaSkinButton.swift:61,254,272`) is decoded but only ever read for a debug label (`DeltaSkinView.swift:472`). Apply it in hit-testing, falling back to the default inset when nil.
- Keep D-pad direction-zone logic (`isLocationInDPadDirection`) working — it does not use the inset today.

Do not change visual button rendering — hit area only.

---

## Verification (all phases)

- `xcrun swiftc -parse <file>` on every changed Swift file (syntax truth; sourcekitd in this repo emits false positives for `canImport`, `#Preview`, `os(visionOS)`, `APP_STORE`, "no such module" — ignore those).
- `swiftlint lint <file>` **positionally** — SwiftLint 0.65.0 here has no `--path` flag.
- Do NOT run `xcodebuild` per task; a full workspace build is ~30 min. One consolidated iOS + tvOS build gates the branch at the end.
- Every changed file must compile for **iOS and tvOS**. PVUIBase also declares macOS.

## Out of scope

Native macOS target (Phase 2 of the predecessor spec), library UI changes on Mac, notarization, and the pre-existing follow-ups listed in `docs/superpowers/plans/2026-08-07-macos-desktop-polish-SMOKE-CHECKLIST.md`.
