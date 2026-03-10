# Screen Recording — Architecture Notes

## Overview

Provenance supports ReplayKit screen recording on iOS, gated behind **Provenance Plus** via `FreemiumKit`.
The feature is iOS-only (`#if os(iOS)`); tvOS is excluded as ReplayKit recording has platform limitations.

## Components

| File | Role |
|------|------|
| `PVRecordingManager.swift` | `@MainActor` singleton wrapping `RPScreenRecorder` start/stop/discard |
| `PVEmulatorViewController+Recording.swift` | VC extension with `startScreenRecording()`, `stopScreenRecording()`, `discardScreenRecording()`, `toggleScreenRecording()` — the **only** place that updates `AppState` |
| `RetroMenuView.swift` (`recordingButton`) | SwiftUI button in the States tab, reads recording state from `AppState.shared.emulationUIState.isRecording` |
| `EmulationState.swift` | `isRecording: Bool` flag on `EmulationUIState` — the **single source of truth** for SwiftUI |

## Design Rules

### @MainActor isolation
`PVRecordingManager` is `@MainActor public final class`. All call sites must be on the main actor:
- From a `UIViewController` method: wrap in `Task { @MainActor in ... }` (already done in the VC extension)
- From a SwiftUI action closure: already on main actor

### async/await API
`startRecording()` and `stopRecording(presenter:)` are `async throws`.
Do **not** revert to completion-handler form — that pattern is replaced by Swift concurrency.

### Single source of truth for recording state
`AppState.shared.emulationUIState.isRecording` is the canonical UI-observable flag.
- **Set to `true`** only inside `startScreenRecording()` after `await PVRecordingManager.shared.startRecording()` succeeds
- **Set to `false`** inside `stopScreenRecording()`, `discardScreenRecording()`, and on any error path
- `PVRecordingManager.isRecording` is the manager's internal guard (prevents double-start/stop) — it must not be read directly by SwiftUI views
- `RetroMenuView` reads **AppState**, not `PVRecordingManager.shared.isRecording`

### NSObject
`PVRecordingManager` does **not** inherit from `NSObject`.
The `RPPreviewViewControllerDelegate` conformance is handled by the private inner class `PreviewDelegate`.

### Plus gating
The record button is wrapped in `PaidFeatureView` (FreemiumKit).
Do not add recording affordances outside this view without the same gating.

## Adding a new recording call site

1. Call `emulatorVC.toggleScreenRecording()` (or the start/stop/discard variants)
2. Read state from `AppState.shared.emulationUIState.isRecording`, not from `PVRecordingManager`
3. Wrap in `#if os(iOS)` and a `PaidFeatureView` if exposing UI

## Testing

- Simulator: `RPScreenRecorder.shared().isAvailable` returns `false` in the simulator — the button is hidden automatically
- Device: must run on a physical device to test actual recording start/stop
