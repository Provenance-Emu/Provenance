## Epic Progress Update — ReplayKit & Live Streaming

### Sub-task Status

| # | Task | Status | PR |
|---|------|--------|----|
| #2715 | Screen recording manager | ✅ Merged | — |
| #2716 | OSD recording indicator | 🔄 PR open | #3364 |
| #2717 | Live broadcast (RPBroadcastPickerView) | 🔄 Agent working | — |
| #2718 | Recording & streaming settings | 🔄 Agent working | — |
| #2719 | Clip capture (iOS 15+) | 🔄 Agent working | — |
| #2720 | Camera face-cam overlay | Queued | — |
| #2721 | tvOS recording/broadcast | Queued | — |

### Architecture Summary

Recording is **core-agnostic** — `RPScreenRecorder` captures the screen regardless of which emulator core is running. The OSD button is in the generic `PVControllerViewController<T>` base class, so all cores inherit it automatically.

The `OSDRecordingObserver` protocol (added in #3364) enables clean state propagation: any code path that starts/stops recording (pause menu, OSD button, programmatic) updates the HUD indicator consistently.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
