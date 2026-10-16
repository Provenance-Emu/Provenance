# Netplay lobby in the library — design

**Status:** first version implemented (branch `claude/netplay-lan-lobby-52716c`)
**Date:** 2026-10-15

## Problem

Netplay is reachable only from the pause menu, after a game has booted.
To join a friend you have to guess the game, boot it, pause, then browse.
Joe wants to see the rooms nearby from the library, then host or join
straight into the game.

## Prerequisite (fixed in the same branch)

Browse never showed a Dolphin room. Only `NetpacketTransport` (thin
netpacket cores) published `_provenance-np._tcp`. Dolphin's ENet server,
mGBA, Mednafen and PPSSPP ad hoc published nothing. `PVNetplayManager.host`
now publishes the room for any core whose `netplayAdvertisesOwnRoom` is
false (`NetServiceRoomAdvertiser`). The TXT record (`NetplayRoomTXTRecord`)
now carries `hash` (library MD5), `serial` and `system`, which the lobby
uses to match rooms to games.

## Scope of the first version

In:

- **Entry points.** iOS: a "Network Play" row in the side menu. tvOS: a
  "Network Play" item in the sidebar rail that opens a full-screen modal.
  Both appear only when `Defaults[.netplayEnabled]` is on.
- **Room list.** `NetplayLibraryLobbyView` (PVUIBase, shared by iOS and
  tvOS) owns its own `PVNetplayBonjourDiscovery`. The shared one's
  `stopDiscovery()` would clear rooms for every viewer. Each room shows its
  host, game, players, and whether this library has the game.
- **Matching.** `NetplayGameMatcher` (PVNetplay, pure) matches a room in
  order: library MD5 (case-insensitive), then serial + system. The second
  rule covers disc games: ISO, RVZ and CISO dumps of one GameCube disc have
  different MD5s but the same game ID, which Dolphin itself checks. A room
  without hash or serial (an older host) can't be matched; the row says so.
- **Join.** Tapping a matched room stores a `NetplayLaunchIntent.join(room)`
  in `PVNetplayManager` and launches the game through
  `SceneCoordinator.launchGame(_:core:)` with the room's core when the
  library has it. After the core starts, `PVEmulatorViewController` takes
  the intent, waits up to 15 s for `supportsNetplay` (thin cores register
  their netpacket interface late), and calls `join`. A toast reports the
  result; Dolphin then waits for the host's Start Game.
- **Host.** A "Host a game" list of recently played games. Tapping one
  stores `.host` and launches it. After boot the emulator opens the pause
  menu straight into its Network Play sheet (`NetplayLobbyView`); the user
  taps Host a Room, which leads to the existing create-room and waiting-room
  flow. Dolphin's host
  needs that Start Game anyway, so there's no separate auto-host path.
- **Intent expiry.** An intent is tied to the game's MD5. It is taken
  once, and it expires after 2 minutes. A failed or abandoned launch can't
  fire a join into a later, unrelated game.

Out (later):

- Internet / traversal rooms and a central lobby server.
- Game Center matchmaking from the library.
- Spectating from the library.
- Picking a different core than the host's.
- A per-game "Host" item in the game context menu.
- Serial and system in thin netpacket rooms (they carry the MD5 only, so a
  PSX room matches only an identical dump).

## Components

| Unit | Module | Purpose |
| --- | --- | --- |
| `NetplayGameMatcher` | PVNetplay | Room → local game: MD5, then serial + system. Generic over the game type, with lookup closures, so it has no Realm dependency. |
| `NetplayLaunchIntent` + `PVNetplayManager.setLaunchIntent` / `takeLaunchIntent(forGameMD5:)` | PVNetplay | Carries "join this room" / "host" across the game launch. |
| `PVNetplayManager.waitUntilNetplayReady(timeout:)` | PVNetplay | Polls the active bridge's `supportsNetplay`. |
| `PVNetplayManager` LAN advertisement (`NetServiceRoomAdvertiser`, TXT dedupe) | PVNetplay | Publishes rooms for cores that don't publish their own. |
| `NetplayLibraryLobbyView` | PVUIBase | Room list and host list; launches games. |
| `PVEmulatorViewController+Netplay` | PVUIBase | Consumes the intent after bridge registration. |
| Side menu row / tvOS sidebar item | PVSwiftUI | Entry points. |

## Error handling

- The game launches but its core can't do netplay (not `PVNetplayCapable`,
  or `supportsNetplay` still false after 15 s): a toast says so, and the
  game keeps running.
- Join fails (the host left, a different core version): an error toast;
  the game keeps running offline.
- No rooms found: an empty state that names the usual causes. Both devices
  must be on the same Wi-Fi, without client isolation, and Local Network
  permission must be on.

## Testing

`swift test` in PVNetplay covers the matcher, intent expiry and
single-use, the readiness wait (with a mock bridge), the TXT round trip and
the advertisement lifecycle. The UI is checked on devices (see the device
steps in the branch report).
