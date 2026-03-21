## Summary

- **`PVBroadcastManager`** — new `@MainActor` singleton wrapping `RPBroadcastPickerView` (iOS) and `RPBroadcastActivityViewController` (tvOS), matching `PVRecordingManager` pattern
- **`isBroadcasting`** state added to `EmulationState`
- **`PVEmulatorViewController+Recording`** — `startBroadcast(from:)` / `stopBroadcast()` methods added for iOS + tvOS
- **RetroMenuView** — "GO LIVE" / "STOP LIVE" tile in CAPTURE section, Plus-gated, iOS+tvOS

## Test plan

- [ ] Tap "GO LIVE" → system broadcast picker appears (requires Twitch/YouTube app installed)
- [ ] Broadcast starts → `isBroadcasting` flips to true
- [ ] "STOP LIVE" tile appears while broadcasting
- [ ] tvOS build compiles without errors
- [ ] iOS build compiles without errors

Part of #2714
Closes #2717

🤖 Generated with [Claude Code](https://claude.com/claude-code)
