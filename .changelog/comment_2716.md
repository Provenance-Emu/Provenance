## 🎬 Recording Feature Status Update

### Groundwork Already Laid (from prior agent work)

| Component | File | Status |
|-----------|------|--------|
| `PVRecordingManager` | `PVUI/Sources/PVUIBase/Recording/PVRecordingManager.swift` | ✅ Complete |
| VC recording extension | `PVEmulatorVC/PVEmulatorViewController+Recording.swift` | ✅ Complete |
| `EmulationState.isRecording` | `State Management/EmulationState.swift` | ✅ Complete |
| Pause-menu tile | `RetroMenuView.swift` | ✅ Complete |

### What Was Just Implemented (PR #3364)

- **OSD record button** in the in-game HUD (this issue #2716)
  - `record.circle` SF symbol, positions left of Quick Save
  - Red pulsing animation while recording active
  - `OSDRecordingObserver` protocol for clean state updates from any call site
  - iOS-only; tvOS gets a no-op stub so the build stays green

### Next Sub-Tasks Firing Now

| Issue | Task | Agent Status |
|-------|------|-------------|
| #2717 | Live streaming via `RPBroadcastPickerView` | 🔄 In progress |
| #2718 | Recording & Streaming settings view | 🔄 In progress |
| #2719 | Clip capture (always-on buffer, iOS 15+) | 🔄 In progress |
| #2720 | Camera face-cam overlay | Queued |
| #2721 | tvOS recording/broadcast support | Queued |

### Expanding to More Cores

The recording infrastructure is **core-agnostic** by design:
- `PVRecordingManager` wraps `RPScreenRecorder.shared()` — records the *screen*, not core-specific output. Any emulator that runs through `PVEmulatorViewController` automatically gains recording support.
- The OSD record button is in `PVControllerViewController<T>` (the generic base) — every core that uses the OSD controller inherits it without changes.
- To support recording in a new core: no changes needed unless that core bypasses `PVEmulatorViewController` entirely (none currently do).

What **would** need per-core work for richer recording:
- **Audio routing** — cores using custom audio backends may not mix into RPScreenRecorder's audio capture. These would need `RPScreenRecorder.isMicrophoneEnabled` + ensuring game audio goes through `AVAudioSession`.
- **Metal/GL frame timing** — if a core renders at non-standard vsync intervals, the recorded video may show frame drops. This is a per-core performance tuning concern, not a recording architecture change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
