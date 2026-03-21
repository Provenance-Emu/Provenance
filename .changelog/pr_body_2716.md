## Summary

- Adds a **Record button** to the in-game OSD quick-action strip (iOS only)
- Button uses `record.circle` SF symbol; switches to `stop.circle.fill` (red) when recording
- Red pulsing animation while recording is active (standard camera indicator style)
- Positioned left of the Quick Save button in the top-right HUD cluster
- Calls `PVEmulatorViewController.toggleScreenRecording()` — integrates with `PVRecordingManager`
- Button only appears when `RPScreenRecorder.shared().isAvailable` returns true
- `OSDRecordingObserver` protocol allows `PVEmulatorViewController` to push state changes back to the HUD without a hard coupling to `PVControllerViewController`
- tvOS: protocol no-op stub — no button shown (recording is iOS-only)

## Test plan

- [ ] Build iOS target and run in emulator — record button appears in top-right HUD
- [ ] Tap record → system recording permission prompt appears → recording starts → button turns red and pulses
- [ ] Tap record again → recording stops → preview sheet appears → button returns to white
- [ ] Stop recording from pause menu → OSD button also updates to white/stopped state
- [ ] tvOS build compiles without errors

Part of #2714
Closes #2716

🤖 Generated with [Claude Code](https://claude.com/claude-code)
