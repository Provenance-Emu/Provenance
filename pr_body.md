## Summary

Wires `NetplayLobbyView` into two entry points so users can initiate network play:

- **Game library long-press context menu** — "Network Play" appears when `netplayEnabled` feature flag is on, presenting `NetplayLobbyView` as a sheet
- **In-game pause tile menu** — "Network Play" tile (antenna SF Symbol) appears in the GAME section when `netplayEnabled` is on, presenting `NetplayLobbyView` as a sheet

### Implementation details

- Moved all four netplay SwiftUI views (`NetplayLobbyView`, `NetplayCreateRoomView`, `NetplayRoomBrowserView`, `NetplayManualConnectView`) from `PVSwiftUI` → `PVUIBase` to avoid a circular module dependency (PVUIBase ← PVSwiftUI)
- Added `PVNetplay` as a conditional platform dependency to `PVUIBase` in `Package.swift`
- `GameContextMenu` uses the existing delegate pattern — added `didRequestNetworkPlayFor(_:)` to `GameContextMenuDelegate`; `ConsoleGamesView` implements it and presents the sheet via `ConsoleGamesViewModel.showNetworkPlay`
- `PauseTileMenuView` adds a new `showingNetworkPlay` state and `.sheet` that reads game title and core identifier from `emulatorVC`
- All new UI is hidden when `PVFeatureFlagsManager.shared.netplayEnabled` is `false` (default)

## Test plan

- [ ] Enable `netplayEnabled` debug override in Feature Flags
- [ ] Long-press a game → "Network Play" appears in menu → tapping presents `NetplayLobbyView`
- [ ] Enable `pauseTileMenu` flag, launch a game, open pause menu → "Network Play" tile is visible → tapping presents `NetplayLobbyView`
- [ ] Disable `netplayEnabled` → neither entry point is visible
- [ ] Compiles on iOS and tvOS simulator without errors

Part of #2483, #3086
Closes #3320

🤖 Generated with [Claude Code](https://claude.com/claude-code)
