# Native-core netplay plan (October 2026)

Research done 2026-10-05 by reading code only. Nothing here has run on two
devices. Paths are relative to the repo root unless noted.

Priorities: Mednafen (many systems, often the only core), Dolphin, mGBA,
PPSSPP. melonDS and Mupen64Plus are out of scope: their libretro cores cover
them. Dolphin and PPSSPP also ship as libretro cores. Libretro Dolphin needs JIT,
so the native core is the non-JIT option. PPSSPP users run either core.

Order: shared contract → Mednafen → PPSSPP (native and libretro) → Dolphin
(build wiring, then integration) → mGBA (timeboxed spike). Each core is its
own commit.

## 0. Shared contract (PVNetplay + PVUI) — do first

Add to `PVNetplayCapable`, with default implementations so cores that are
not being changed still compile:

- A host "start game" action. Dolphin needs one: the host picks when every
  player has the game. Wire the waiting room's Start button to it.
- A "restart the game to apply" signal. PPSSPP needs it because some
  settings are only read at boot. The UI must offer the restart.
- Status and error text surfaced to the UI (Mednafen's NetplayText, Dolphin's
  connection and desync errors).

## 1. Mednafen

Bridge: `Cores/Mednafen/Sources/MednafenGameCore/MednafenGameCore+PVNetplayCapable.swift`
and `MednafenGameCoreBridge+Netplay.mm`. Mednafen source:
`Cores/Mednafen/Sources/mednafen/mednafen-src/src/`.

### Client today (mostly works)

- **Sockets are real.** `net/Net.cpp` and `Net_POSIX.cpp` are built with
  `HAVE_POSIX_SOCKETS` (`Cores/Mednafen/Package.swift:611-617`).
  - `MDFNI_NetplayConnect` does not block (`netplay.cpp:1243`).
  - The login happens later, in `Netplay_Update` → `NetplayStart` (`netplay.cpp:186-345`).
  - It runs every frame on the emulation thread (`mednafen.cpp:1937,1967`).
  - `RecvData` blocks the emulation thread until that frame's data arrives.
- **Stubs in `MednafenGameCoreBridge/stubs.mm`.**
  - `MDFND_NetplayText` (:52) is empty, so errors are silent. Route it to the OSD.
  - `MDFND_NetplaySetHints` (:61) is a no-op.
  - `MDFND_CheckNeedExit` (:64) always returns false, so a blocked `RecvData` can never be aborted. Make it return a real flag.
- **Threading.**
  - `MDFNI_NetplayDisconnect` runs on `_netplayQueue` while the emulation thread may be inside `Connection->Receive`, which is a use-after-free risk.
  - Disconnect from the emulation thread instead, through a flag checked in `Netplay_Update`.
  - The bridge's `@try/@catch` cannot catch C++ exceptions.
- **Port.**
  - `PVNetplayManager.host` passes `settings.port` (default 55435).
  - `resolvedHostPort` only substitutes 4046 when the port is 0.
  - Default to 4046 for Mednafen.
- **Reporting.** `currentPlayers` is hard-coded to 1 and `gameHash` is empty.

### Hosting: embed the vendored server

- **Location.** `mednafen-server` 0.5.2 is at `Cores/Mednafen/Sources/mednafen-server/`.
  - It speaks protocol 3, and the bundled client (Mednafen 1.32.1, `netplay.cpp:278`) sends protocol 3, so they are compatible.
  - About 2.5k lines of plain POSIX C++: `src/mednafen-server.cpp` (1998), `md5.cpp`, `time64.cpp`, `errno_holder.cpp`.
  - No threads. One `while(1)` select loop with a 25 ms sleep (~1975-1996). Separate IPv4 and IPv6 listen sockets.
- **Dead scaffolding.** `Package.swift:634-663` declares the targets `mednafen-server`, `MednafenServerBridge` and `Server.swift`, but nothing depends on them.
  - `src/main.c` is a stub.
  - `MednafenServerBridge.c` calls an undefined `main_function`, while `mednafen-server.cpp:1664` defines `int main`.
  - `Server.swift/NetworkConnection.swift` returns nil from every method.
- **Embedding work.**
  - Link the server into `MednafenGameCoreBridge`, with `main` renamed (e.g. `-Dmain=mednafen_server_main`).
  - Add an atomic stop flag to the main loop.
  - Replace the `exit(-1)` calls (lines 1681-1809) with returns.
  - Replace `LoadConfig(argv[1])` with a struct or a temporary conf file. Required keys: `maxclients`, `connecttimeout`, `port` (line 355); defaults 50, 5 and 4046. Optional: `idletimeout`, `password`.
  - Close the listen sockets on exit.
  - Run it on a dedicated thread on the host. The host's own client connects to 127.0.0.1:port.
- **Constraints** (`mednafen-server.cpp:1516-1550`).
  - The protocol version must match.
  - The 64-byte emulator ID (`"mednafen 1.32.1"`) must match, so both sides need the same build.
  - The game ID is MD5(game MD5 + gamekey), so both sides need the same game and key.
  - Controller types and sizes must match.
  - `netplay.password` is the server password, separate from the gamekey.
- **Testable.** Server and client in one process over loopback.

## 2. PPSSPP (native and libretro)

Source: `Cores/PPSSPP/libretro_ppsspp` (v1.15.4-138), shared by both builds.
Below, HLE = `Core/HLE`.

### Model

- A game's adhoc init starts the FriendFinder thread (HLE `proAdhoc.cpp:1360`).
  - It resolves `g_Config.proAdhocServer` and connects over TCP to port 27312 (fixed, `proAdhoc.h:121`).
  - It logs in with the MAC from `getLocalMac()` (`proAdhoc.cpp:1923`, reads `g_Config.sMACAddress`).
- Game data then goes peer to peer (PDP over UDP, PTP over TCP) to `gamePort + portOffset` (`sceNetAdhoc.cpp:1431`, `:610`). Both devices need the same `iPortOffset`.
- **Never use 127.x or "localhost" across two devices.**
  - `InitLocalhostIP` sets `isLocalServer` (HLE `sceNet.cpp:130-131`).
  - That binds sockets to loopback (`sceNetAdhoc.cpp:1428`, `3327`, `3441`).
  - The native bridge's current host (`proAdhocServer="127.0.0.1"`) is therefore wrong.
- **Read only at boot**, in `__KernelInit` (`sceKernel.cpp:142-143`):
  - `iPortOffset`
  - `isLocalServer`
  - the built-in server start: `__NetAdhocInit` starts `proAdhocServerThread` only if `bEnableWlan && bEnableAdhocServer` (`sceNetAdhoc.cpp:1265-1279`)
- **Read live:**
  - `bEnableWlan`
  - `proAdhocServer`, re-read when the game next enters its ad hoc lobby
  - the MAC, read at login
- The built-in server has no iOS guard. It binds `INADDR_ANY:27312` (`proAdhocServer.cpp:1677-1840`).

### Config

| Setting | Host | Client |
|---|---|---|
| `bEnableWlan` | true | true |
| `bEnableAdhocServer` | true | false |
| `proAdhocServer` | its own LAN IP | the host's LAN IP |
| `iPortOffset` | 10000 | 10000 (the same value) |
| `sMACAddress` | unique per install | unique per install |

- MAC: a locally administered address, random and persisted per install. Never leave it empty or let two devices share one.
- UPnP: off.

### Native

- Files: `Cores/PPSSPP/PVPPSSPPCore/Core/PVPPSSPPCore+Netplay.mm` and `+PVNetplayCapable.swift`.
- Apply the pending config between `g_Config.Load` (`PPSSPPGameCore.mm:178`) and `PSP_Init` (`:246`).
- Starting mid-game requires a game restart.
- Honest status from:
  - `friendFinderRunning` (`proAdhoc.h:951`)
  - `netAdhocctlInited` (`sceNetAdhoc.h:123`)
  - `adhocctlState` (`proAdhoc.h:957`; CONNECTED=1)
  - `getActivePeerCount()` (`proAdhoc.cpp:1786`; walks `friends`, so take `peerlock`)
- The user still has to open the game's own ad hoc menu on both devices.

### Libretro (thin wrapper)

- No netpacket support: it opens its own sockets.
- Options (exact strings, in `libretro_core_options.h`):

| Option | Values |
|---|---|
| `ppsspp_enable_wlan` | disabled \| enabled |
| `ppsspp_enable_builtin_pro_ad_hoc_server` | disabled \| enabled |
| `ppsspp_change_pro_ad_hoc_server_address` | socom.cc \| psp.gameplayer.club \| myneighborsushicat.com \| localhost \| IP address |
| `ppsspp_pro_ad_hoc_server_address01..12` | one digit each; three per octet, so 192.168.1.7 → 192168001007 |
| `ppsspp_port_offset` | "0".."65000" in steps of 1000 |
| `ppsspp_enable_upnp` | disabled \| enabled |
| `ppsspp_change_mac_address01..12` | one hex nibble each; all zeros → `CreateRandMAC()` each boot, which is unique per device |

- `check_variables()` runs at load and on every `retro_run`.
- Read only at boot: `ppsspp_enable_builtin_pro_ad_hoc_server` and `ppsspp_port_offset`. The host must restart.
- Drive the options through `_bridge.setCoreOption`, and persist them per game so they survive the restart.
- Don't persist MAC nibbles.

## 3. Dolphin (native)

Bridge: `Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore+Netplay.mm` and
`+PVNetplayCapable.swift`. Source: the `Cores/Dolphin/dolphin-ios` submodule.

### Today: compiled out, and stale

- `HAVE_DOLPHIN_NETPLAY` is 0.
  - `PVDolphin.xcodeproj` has neither `dolphin-ios/Externals/SFML/SFML/include` nor the enet include path.
  - The libraries `libsfml-networkDolphin.a`, `libsfml-systemDolphin.a` and `libenetDolphin.a` exist under `lib/`. Check that they are linked.
- The guarded code would not compile against this revision:
  - `BootGame` takes `std::unique_ptr<BootSessionData>`.
  - `TraversalClient` lives in `Common::`.
  - `IsRecording` is non-const.
  - There is no `SetPassword` and no `GetInterfaceListToSend`.
  - `NETPLAY_INPUT_BUFFER_SIZE` is now `NETPLAY_BUFFER_SIZE` (host, 5) and `NETPLAY_CLIENT_BUFFER_SIZE` (1).
- Template to follow: `dolphin-ios/Source/Android/jni/NetPlay/NetPlayUICallbacks.cpp` and `Netplay.cpp`.

### NetPlayUI pure virtuals (`Core/NetPlayClient.h:45-96`)

| Method | Signature or note |
|---|---|
| `BootGame` | `(const std::string&, std::unique_ptr<BootSessionData>)` |
| `StopGame` | |
| `IsHosting` | const |
| `Update` | |
| `AppendChat` | |
| `OnMsgChangeGame` | `(SyncIdentifier, name)` |
| `OnMsgChangeGBARom` | `(int, GBAConfig)` |
| `OnMsgStartGame` | |
| `OnMsgStopGame` | |
| `OnMsgPowerButton` | |
| `OnPlayerConnect` / `OnPlayerDisconnect` | |
| `OnPadBufferChanged` | |
| `OnHostInputAuthorityChanged` | |
| `OnDesync` | |
| `OnConnectionLost` | |
| `OnConnectionError` | |
| `OnTraversalError` | `(Common::TraversalClient::FailureReason)` |
| `OnTraversalStateChanged` | `(Common::TraversalClient::State)` |
| `OnGameStartAborted` | |
| `OnGolferChanged` | |
| `OnTtlDetermined` | `(u8)` |
| `IsRecording` | non-const |
| `FindGameFile` | `(SyncIdentifier, SyncIdentifierComparison*)` → `shared_ptr<const UICommon::GameFile>` |
| `FindGBARomPath` | |
| Game digest ×4 | `ShowGameDigestDialog`, `SetGameDigestProgress`, `SetGameDigestResult`, `AbortGameDigest` |
| `OnIndexAdded` | |
| `OnIndexRefreshFailed` | |
| Chunked progress ×3 | `ShowChunkedProgressDialog(const std::string&, u64, std::span<const int>)`, `HideChunkedProgressDialog`, `SetChunkedProgress` |
| `SetHostWiiSyncData` | `(std::vector<u64>, std::string)` |

Critical methods:
- `FindGameFile`: the host server calls it too (`NetPlayServer.cpp:1359`, `1600`, `1740`, `2068`).
- `BootGame`
- `StopGame`
- `OnMsgStartGame`: call `client->StartGame(path)`.
- `OnMsgPowerButton`: call `UICommon::TriggerSTMPowerEvent()`.
- `SetHostWiiSyncData`: forward to `client->SetWiiSyncData(nullptr, …)`.
- `IsRecording`: return false.

### Sequence

1. **Host.**
   - Create `NetPlayServer(port, false, ui, {use_traversal, "stun.dolphin-emu.org", 6262, 6226})` and check `is_connected`.
   - Call `ChangeGame(gamefile->GetSyncIdentifier(), name)`.
   - Join its own server at 127.0.0.1:`GetPort()` and check `IsConnected()`.
2. **Client.** `OnChangeGame` (`NetPlayClient.cpp:802`) → `SendGameStatus` → `FindGameFile`.
3. **Start.** The host checks `DoAllPlayersHaveGame()`, then calls `RequestStartGame()` (`NetPlayServer.cpp:~1515`), which runs `SetupNetSettings`, then the save and code sync, then `StartGame`.
4. **Each player.** `OnStartGame` → `OnMsgStartGame` → `client->StartGame(path)` (`:1743`).
   - That calls `NetPlay_Enable`, which must only happen after the running game has stopped.
   - Then `BootGame(path, session)`, which calls `BootManager::BootCore(system, BootParameters::GenerateFromFile(path, std::move(*session)), wsi)`.
   - `BootCore` applies the netplay config layer itself, and refuses unless `Core::IsUninitialized`.

### Reboot in place (`PVDolphinCore.mm`)

1. Keep `wsi` as an ivar; it is currently a local at `:812`.
2. Call `Core::Stop` and wait for Uninitialized. `startVM` (`:~799`) already shows this.
3. Run `BootCore` on a serial boot queue, then `SetSoundStreamRunning(true)`.
4. Don't use `stopEmulation`'s full teardown (`:1039`).
5. Register `Core::AddOnStateChangedCallback` so a user quit sends `RequestStopGame`, as Android does at `NetPlayUICallbacks.cpp:~65`. Suppress it for the stop that precedes the netplay reboot.

Risks:
- Video backend re-init on the same CAMetalLayer.
- Callbacks fire on the netplay thread. Never take `@synchronized(self)` in one.
- The UI object must outlive the client.

### Traversal

- Host: `use_traversal=true`.
- The code is `Common::g_TraversalClient->GetHostID()`. Read it when `OnTraversalStateChanged(Connected)` fires; `host_id[0]=='\0'` means not ready.
- `queryDolphinTraversalCode` is currently dead.

### Input

- `SI_DeviceGCController` uses `NetPlay_GetInput` → `GetNetPads` → `Pad::GetStatus`.
- Provenance injects through `ciface::iOS::StateManager` into Pad, so input works unchanged.
- Player 1 must stay on pad 0. The server assigns pads in connect order.

### Determinism

- `SetupNetSettings` copies the host's `MAIN_CPU_CORE` and `MAIN_CPU_THREAD` to every client (`:1380-1381`).
- Force the interpreter (or cached interpreter) and single core while netplay is active. Otherwise a JIT host breaks a non-JIT client.
- Save states are rejected during netplay. `PVDolphinCore+Saves.mm:314` already handles that.

### Testable

- `CompareSyncIdentifier` against fixtures.
- Server and client in one process over loopback, with a fake UI recording the callback order.

## 4. mGBA (spike first)

Bridge: `Cores/mGBA/Sources/PVmGBACore/PVmGBACore+PVNetplayCapable.swift` and
`PVmGBAGameCoreBridge+Netplay.mm`.

### The current link cannot work

1. Only device 0 schedules a multiplayer transfer (`libmGBA-embed/mgba/src/gba/sio.c:~176-196`; the slave branch is a TODO). The slave never gets `finishMultiplayer`, a busy bit or an IRQ.
2. Data is exchanged only inside each side's own SIOCNT write (`.mm:191-280`). The slave never sends, so the master waits 2 s and tears the session down (`.mm:254-275`).
3. The emulation thread blocks on the network for every transfer.
4. Stale or wrong data is used (`.mm:303-319`).

Also:
- `GBASIOSetDriver` is called from non-emulation threads.
- `stopLink` can't interrupt a blocked connect or accept; use `shutdown()`.
- The host binds IPv4 only.
- The host advertises 0.0.0.0, and port 0 is never reported back.
- The password is ignored.

### Direction

- mGBA's own lockstep: `src/core/lockstep.c` is compiled. `src/gba/sio/lockstep.c` is in the tree but not compiled (`Package.swift:116-117`).
- Upstream mGBA has no network link. Lockstep over the network costs a round trip per transfer, which is fine for trading and poor for real-time play.
- Spike it before committing days of work.
- gpSP over netpacket (thin wrapper) is the GBA link path that already exists.

## Verification

- Per core: the core's own scheme build, PVUI on iOS and tvOS, and loopback tests where noted. Dolphin also needs a full AppStore app build on iOS and tvOS.
- None of this can be verified end to end without two devices.
