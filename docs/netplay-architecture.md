# Provenance Netplay Architecture Design

**Issue:** [#2544](https://github.com/Provenance-Emu/Provenance/issues/2544)
**Status:** Research / Pre-implementation
**Date:** 2026-03-05

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Core Audit Results](#2-core-audit-results)
3. [RetroArch Netplay Deep Dive](#3-retroarch-netplay-deep-dive)
4. [Native Frameworks Research](#4-native-frameworks-research)
5. [Architecture Design](#5-architecture-design)
6. [UI Flow & Wireframes](#6-ui-flow--wireframes)
7. [Phased Implementation Plan](#7-phased-implementation-plan)
8. [Risk Assessment](#8-risk-assessment)
9. [Open Questions](#9-open-questions)

---

## 1. Executive Summary

Provenance currently exposes RetroArch netplay only via the RetroArch in-game menu (pause → RA Menu → Network). There is no native Swift/SwiftUI netplay UI, no session discovery, and no support for netplay across native emulator cores (Dolphin, PPSSPP, Mednafen, etc.).

**Key findings:**
- RetroArch is compiled **with** `HAVE_NETWORKING`, `HAVE_NETPLAYDISCOVERY`, and `HAVE_NETPLAYDISCOVERY_NSNET` but **without** `HAVE_NETPLAY`. LAN room discovery and NAT traversal code is present, but the core rollback/input-sync netplay engine is not enabled.
- Adding `HAVE_NETPLAY` to `BuildFlags.xcconfig` is the single highest-leverage change to enable RetroArch netplay features through the RetroArch menu today.
- Several native cores (Mednafen, Mupen64Plus, Dolphin, PPSSPP) have upstream netplay support that is not built or exposed.
- A modular native Swift netplay layer is achievable in phases, starting with RetroArch cores and local P2P.

---

## 2. Core Audit Results

### 2.1 RetroArch / libretro Cores

All RetroArch cores loaded by `PVRetroArchCore` share a single RetroArch runtime. Netplay is implemented at the RetroArch level (not per-core), making it the most accessible path.

| Feature | Current Status |
|---------|---------------|
| `HAVE_NETWORKING` | **Enabled** in `BuildFlags.xcconfig` |
| `HAVE_NETPLAYDISCOVERY` | **Enabled** |
| `HAVE_NETPLAYDISCOVERY_NSNET` | **Enabled** (uses NSNetService/Bonjour) |
| `HAVE_NETWORKGAMEPAD` | **Enabled** |
| `HAVE_NETPLAY` | **MISSING** — core netplay engine not compiled |

**Implication:** Adding `-DHAVE_NETPLAY` to `OTHER_CFLAGS` (and `OTHER_DEBUG_CFLAGS`) in `CoresRetro/RetroArch/BuildFlags.xcconfig` would enable RetroArch's full netplay system for all ~60 RetroArch cores. This includes rollback netplay, spectator mode, relay server support (RA.ME), and LAN discovery — all accessible via the RA in-game menu immediately.

**RetroArch cores that are known-working with netplay upstream:**
- NES (bsnes-hd, nestopia, mesen, fceumm)
- SNES (bsnes, snes9x)
- GBA (mGBA)
- Genesis / Mega Drive (genesis_plus_gx, picodrive)
- N64 (mupen64plus, parallel-n64)
- PS1 (beetle-psx)
- Arcade (fbalpha, mame)
- GBC (gambatte, sameboy)

### 2.2 Native Cores with Built-in Netplay Support

These cores have upstream netplay APIs that Provenance does not currently expose.

#### Mednafen
- **Systems:** PS1, PC Engine/CD, NES, SNES, GBA, GB/GBC, GG, SMS, Lynx, NGP, Saturn, VirtualBoy, WonderSwan
- **Netplay source:** `netplay.cpp` is **compiled** in `Cores/Mednafen/Package.swift` (line 824)
- **Protocol:** Mednafen uses its own TCP-based protocol. Server-hosted rooms with a dedicated mednafen server binary.
- **Exposure gap:** The `PVMednafenCoreBridge` does not expose `StartNetplay()` / `StopNetplay()` or any networking hooks.
- **Effort to expose:** Medium. Mednafen's netplay requires a relay server for WAN; LAN works without one.

#### Dolphin (GameCube / Wii)
- **Systems:** GameCube, Wii
- **Location:** `Cores/Dolphin/PVDolphinCore/`
- **Upstream capability:** Dolphin has a mature netplay system supporting both LAN and relay (Dolphin traversal server). Supports rollback (savestates) and braid-mode.
- **Exposure gap:** `PVDolphinCore.mm` has no netplay APIs surfaced. Dolphin's `Core/NetPlay*` classes exist in the `dolphin-ios` submodule but are not called.
- **Effort to expose:** High. Dolphin netplay requires UI to pick players, game confirmation, and pad buffering config.

#### PPSSPP (PSP)
- **Systems:** PSP
- **Location:** `Cores/PPSSPP/PPSSPPGameCore.mm`
- **Upstream capability:** PPSSPP has "Adhoc" (local wireless) simulation and an infrastructure mode via `AdhocServer`. The PSP's XLink Kai / Adhoc party emulation is partially supported.
- **Exposure gap:** No adhoc or infrastructure hooks in `PPSSPPGameCore.mm`.
- **Effort to expose:** High. PPSSPP adhoc emulation uses a local UDP server and requires a second PPSSPP instance.

#### Mupen64Plus (N64)
- **Systems:** N64
- **Location:** `Cores/Mupen64Plus/Sources/`
- **Upstream capability:** Mupen64Plus core has netplay through `mupen64plus-input-sdl`'s network mode. Limited and outdated; rarely used upstream.
- **Effort to expose:** Very High. Not recommended for v1.

#### FCEU (NES)
- **Systems:** NES / Famicom
- **Location:** `Cores/FCEU/fceux-netplay-server/`
- **Status:** `fceux_netplay_server.h/.m` exists but is an **empty stub** (just `@implementation fceux_netplay_server @end`). The FCEU-2.2.3 source has `sdl-netplay.cpp` / `unix-netplay.cpp` with a working SDL-based netplay implementation but it's SDL-specific and not adapted for Provenance.
- **Effort to expose:** Very High (SDL dependency). Use RetroArch's fceumm/nestopia core instead.

#### TGBDual (Game Boy Link Cable)
- **Systems:** GB / GBC
- **Status:** TGBDual emulates **two** Game Boy instances simultaneously for local link cable play. This is already integrated. Not network-based but relevant to multiplayer surface area.

### 2.3 Summary Matrix

| Core | System(s) | Upstream Netplay | Built in Provenance | Native UI Needed |
|------|-----------|-----------------|--------------------|-|
| PVRetroArchCore | 60+ systems | Yes (RetroArch) | No (`HAVE_NETPLAY` missing) | Yes (or RA menu) |
| Mednafen | PS1, PCE, SNES, etc. | Yes (TCP, server) | Compiled, not exposed | Yes |
| Dolphin | GC, Wii | Yes (relay + LAN) | Not exposed | Yes |
| PPSSPP | PSP | Adhoc emulation | Not exposed | Yes |
| Mupen64Plus | N64 | Limited | Not exposed | Yes |
| FCEU native | NES | Stub only | Stub | N/A |
| TGBDual | GB/GBC | Link cable sim | Working locally | N/A |

---

## 3. RetroArch Netplay Deep Dive

### 3.1 How RetroArch Implements Netplay

RetroArch netplay is a **rollback-based** system (similar to GGPO) when latency is low, falling back to delay-based sync for high-latency connections.

**Core mechanism:**
```
Frame N:
  - Player 1 sends input to Player 2 (and vice-versa)
  - Both sides run the same frame with both inputs
  - If inputs diverge due to latency, rollback to last confirmed frame and re-simulate
```

**Key source files in `PVCoreBridgeRetro/Sources/retro/`:**
- `tasks/task_netplay_lan_scan.c` — broadcasts UDP query packets and collects LAN room responses
- `tasks/task_netplay_nat_traversal.c` — implements STUN-based NAT traversal for P2P WAN connections
- `tasks/task_netplay_find_content.c` — matches game content hash with connected peer
- `runloop.c` — netplay hooks in the main emulation loop (`HAVE_NETPLAY` guards)
- `configuration.c` / `configuration.h` — `netplay_enable`, `netplay_server`, `netplay_port`, `netplay_delay_frames`, etc.

**Discovery:**
- LAN: UDP broadcast on port 55435; responders use `HAVE_NETPLAYDISCOVERY`
- WAN relay: RA.ME (RetroArch relay server) at `ra.me` — a publicly hosted TURN/STUN server
- iOS uses `HAVE_NETPLAYDISCOVERY_NSNET` (Bonjour/NSNetService) for LAN discovery — this is **already enabled**

**Why `HAVE_NETPLAY` is missing:**
Likely excluded to keep binary size down or due to past build failures. Enabling it requires also linking against mbedTLS (which is already present as `HAVE_BUILTINMBEDTLS` in the line flags) and may need `HAVE_NETPLAY` added to the linker/compiler search list that drives what `.c` files are compiled.

### 3.2 RetroArch Netplay Data Flow

```
[PVRetroArchCoreBridge]
       |
       v
[RetroArch runloop.c]  ←—HAVE_NETPLAY—→  [netplay.c]
       |                                      |
       |                              [netplay_io.c]   (input sync)
       |                              [netplay_net.c]  (TCP/UDP socket)
       |                              [netplay_delta.c] (rollback)
       v
[libretro core] ←——————retro_run()————————————
```

### 3.3 What Provenance Gets for Free from RetroArch

Once `HAVE_NETPLAY` is enabled:
- Full rollback/delay netplay for all 60+ RA cores
- LAN room hosting and joining (via RA menu)
- WAN via RA.ME relay (via RA menu)
- Spectator mode (up to 11 spectators)
- Content matching (ensures both peers run same ROM)
- Save state sync at session start

**What still needs custom implementation:**
- Native SwiftUI lobby / room browser UI
- Integration with iOS share sheet / AirDrop for room invites
- MultipeerConnectivity or GameKit for discovery outside RA's UDP broadcast
- Swift API bridge to start/stop netplay programmatically from Swift code
- In-game HUD overlay showing connection status, ping, frame delay

---

## 4. Native Frameworks Research

### 4.1 Apple MultipeerConnectivity

**Framework:** `MultipeerConnectivity`
**Transport:** Bluetooth + Wi-Fi (Infrastructure and peer-to-peer Wi-Fi)
**Suitable for:** LAN / local room discovery and session establishment

**Pros:**
- Automatic peer discovery without a server
- Works over Bluetooth (no Wi-Fi needed) at lower bandwidth
- Easy to implement in Swift; well-documented
- Supports up to 8 peers in a session

**Cons:**
- ~15-30ms overhead vs direct UDP for high-frequency game input
- Not suitable for WAN; local only
- Encryption overhead may add latency

**Best use in Provenance:** Lobby discovery and initial handshake. Once peers find each other, hand off to RetroArch's own UDP netplay transport.

### 4.2 GameKit / Game Center

**Framework:** `GameKit`
**Suitable for:** WAN matchmaking, friend invites, turn-based and real-time matches

**Pros:**
- Apple-managed relay servers (no need for RA.ME for WAN)
- Friends list and invite flow built-in
- `GKMatch` provides real-time data channel usable for input sync

**Cons:**
- Requires Apple Developer account + Game Center entitlement
- App must be published to App Store (not available for sideloaded builds)
- Apple relay latency varies; not optimized for emulator input rates
- `GKMatch` has limited control over transport (no raw UDP)

**Best use in Provenance:** Future WAN matchmaking for App Store builds. Not recommended for v1.

### 4.3 Network.framework (NWConnection / NWListener)

**Framework:** `Network` (available iOS 12+)
**Transport:** Direct TCP or UDP sockets with native Swift API

**Pros:**
- Full control over socket behavior
- QUIC support (iOS 15+) for reliable multiplexed UDP
- Can implement input-sync protocol to match RetroArch's

**Best use in Provenance:** Used internally by RetroArch. Could be used for a Swift-side control plane (room management) while RetroArch handles the game data plane.

### 4.4 Bonjour / NSNetService (Already Enabled)

`HAVE_NETPLAYDISCOVERY_NSNET` is already compiled into Provenance's RetroArch build. This means RetroArch already uses Bonjour to advertise rooms on the LAN. We can consume this from Swift via `NetServiceBrowser` to list available rooms without any native core changes.

---

## 5. Architecture Design

### 5.1 Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Provenance App (SwiftUI)                     │
│  ┌─────────────────┐  ┌───────────────────┐  ┌──────────────┐  │
│  │  NetplayLobby   │  │  RoomBrowserView  │  │  InGameHUD   │  │
│  │     View        │  │  (LAN / WAN)      │  │  Overlay     │  │
│  └────────┬────────┘  └────────┬──────────┘  └──────┬───────┘  │
│           │                   │                     │           │
│  ┌────────▼───────────────────▼─────────────────────▼────────┐ │
│  │               PVNetplayManager (Swift Actor)               │ │
│  │  - Session lifecycle (host / join / spectate / leave)      │ │
│  │  - Peer discovery (Bonjour + MultipeerConnectivity)        │ │
│  │  - Core capability negotiation                             │ │
│  │  - ROM hash verification                                   │ │
│  └──────────┬───────────────────────────────┬─────────────────┘ │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌──────────────────────────────┐
│   PVNetplayRetroArch    │    │   PVNetplayNativeCore        │
│   Bridge (ObjC/Swift)   │    │   Bridge (future, per-core)  │
│                         │    │                              │
│  - Calls RA command API │    │  - PVDolphinNetplayBridge    │
│    to start/stop netplay│    │  - PVMednafenNetplayBridge   │
│  - Reads RA config vars │    │  - PVPPSSPPAdhocBridge       │
│  - Room status polling  │    │                              │
└─────────────┬───────────┘    └──────────────────────────────┘
              │
              ▼
┌─────────────────────────────┐
│  RetroArch Runtime          │
│  (PVRetroArchCoreBridge)    │
│                             │
│  - netplay.c / netplay_io.c │
│  - UDP input sync           │
│  - Rollback state           │
│  - RA.ME relay (WAN)        │
│  - Bonjour LAN (NSNet)      │
└─────────────────────────────┘
```

### 5.2 PVNetplayManager Protocol

```swift
// PVNetplay/Sources/PVNetplay/PVNetplayManager.swift

public enum NetplayRole {
    case host(port: UInt16)
    case client(host: String, port: UInt16)
    case spectator(host: String, port: UInt16)
}

public enum NetplayState {
    case idle
    case hosting(room: NetplayRoom)
    case connecting(to: NetplayRoom)
    case connected(session: NetplaySession)
    case disconnected(reason: DisconnectReason)
}

public protocol PVNetplayCapable: AnyObject {
    var supportsNetplay: Bool { get }
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws
    func stopNetplay() async
    var netplayState: NetplayState { get }
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> { get }
}

public struct NetplayRoom: Identifiable, Sendable {
    public let id: UUID
    public let hostName: String
    public let gameName: String
    public let gameHash: String       // MD5 of ROM for verification
    public let coreIdentifier: String
    public let maxPlayers: Int
    public let currentPlayers: Int
    public let pingMS: Int?
    public let isLAN: Bool
    public let hostAddress: String
    public let port: UInt16
}

public struct NetplaySettings: Sendable {
    public var frameDelay: Int        // 0 = rollback only, >0 = delay frames
    public var maxSpectators: Int     // 0-11
    public var allowSpectators: Bool
    public var relayServer: String?   // nil = direct P2P, "ra.me" = relay
    public var password: String?
    public var playerIndex: Int       // 0-based
}
```

### 5.3 RetroArch Netplay Bridge

RetroArch exposes a command interface (`command.c`) that can be called from ObjC. A thin bridge wraps this:

```objc
// PVNetplayRetroArchBridge.h
@interface PVNetplayRetroArchBridge : NSObject

/// Start hosting a netplay session using RetroArch's netplay engine
- (BOOL)startHosting:(NSString *)nickname
                port:(uint16_t)port
         frameDelay:(int)frameDelay
              error:(NSError **)error;

/// Connect to a remote netplay host
- (BOOL)connectToHost:(NSString *)hostname
                 port:(uint16_t)port
             nickname:(NSString *)nickname
                error:(NSError **)error;

/// Stop current session
- (void)stopNetplay;

/// Query current session status (for HUD)
- (NSDictionary *)sessionStatus;

@end
```

Implementation calls into `retroarch.c`'s `command_event(CMD_EVENT_NETPLAY_INIT_DIRECT, ...)` and related command events.

### 5.4 Room Discovery via Bonjour

Since `HAVE_NETPLAYDISCOVERY_NSNET` is already compiled in, RetroArch hosts advertise themselves via Bonjour under the `_retroarch._tcp` service type. We can discover these from Swift:

```swift
// PVNetplayDiscovery.swift

final class PVNetplayDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private(set) var rooms: [NetplayRoom] = []

    func startDiscovery() {
        browser.delegate = self
        browser.searchForServices(ofType: "_retroarch._tcp", inDomain: "local.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Parse TXT record for game name, hash, player count
    }
}
```

For MultipeerConnectivity (Bluetooth + P2P Wi-Fi), a separate `PVNetplayMCDiscovery` handles non-Wi-Fi scenarios.

### 5.5 Module Structure

New `PVNetplay` SPM package:

```
PVNetplay/
  Package.swift
  Sources/
    PVNetplay/
      PVNetplayManager.swift         (actor, coordinates everything)
      PVNetplaySession.swift         (active session state)
      PVNetplayRoom.swift            (room model)
      PVNetplaySettings.swift        (user preferences)
      Discovery/
        PVNetplayBonjourDiscovery.swift
        PVNetplayMCDiscovery.swift
      Bridges/
        PVNetplayRetroArchBridge.swift  (wraps ObjC bridge)
        PVNetplayNativeCoreBridge.swift (protocol for native cores)
```

PVUI adds:
```
PVUI/Sources/PVSwiftUI/Netplay/
  NetplayLobbyView.swift
  NetplayRoomBrowserView.swift
  NetplayRoomCreateView.swift
  NetplayInGameOverlay.swift
  NetplaySettingsView.swift
```

---

## 6. UI Flow & Wireframes

### 6.1 Entry Points

**Option A — From Game Library:**
```
Game long-press context menu
  └── "Netplay" → NetplayLobbyView
```

**Option B — From In-Game pause menu:**
```
Pause menu
  └── "Network Play" → NetplayLobbyView
```

### 6.2 Lobby View (Main Netplay Screen)

```
┌─────────────────────────────────┐
│         Network Play            │
│                                 │
│  Playing: Super Mario World     │
│  Core: RetroArch (snes9x)       │
│                                 │
│  ┌──────────────────────────┐   │
│  │   Host a Room            │   │
│  │   Invite friends to play │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │   Browse Rooms           │   │
│  │   Join a game in progress│   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │   Spectate               │   │
│  │   Watch without playing  │   │
│  └──────────────────────────┘   │
│                                 │
│  [?] Core support: Full         │  ← badge: Full / Partial / None
└─────────────────────────────────┘
```

### 6.3 Room Browser

```
┌─────────────────────────────────┐
│  ← Browse Rooms   [Refresh]     │
│                                 │
│  LOCAL NETWORK ──────────────   │
│                                 │
│  ┌──────────────────────────┐   │
│  │ JoeMatt's Room           │   │
│  │ Chrono Trigger • SNES    │   │
│  │ 1/2 players • LAN • 2ms  │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │ RetroNight Session       │   │
│  │ Street Fighter II • SNES │   │
│  │ 2/2 players • spectate   │   │
│  └──────────────────────────┘   │
│                                 │
│  WAN / RELAY ────────────────   │
│  (requires RA.ME — future)      │
│                                 │
└─────────────────────────────────┘
```

### 6.4 Create Room Flow

```
Step 1: Room Settings
┌─────────────────────────────────┐
│  ← Create Room                  │
│                                 │
│  Room Name: [JoeMatt's Room   ] │
│  Max Players: [2] [3] [4]       │
│  Frame Delay: [0 (rollback)]    │
│  Allow Spectators: [ON]         │
│  Password: [Optional          ] │
│  Network: [LAN Only ▾]         │
│                                 │
│  [Start Hosting]                │
└─────────────────────────────────┘

Step 2: Waiting for Players
┌─────────────────────────────────┐
│  Hosting: JoeMatt's Room        │
│                                 │
│  P1: JoeMatt (you)   ✓         │
│  P2: Waiting...      ○         │
│                                 │
│  Share link: [Copy] [AirDrop]  │
│                                 │
│  [Start Game] (disabled)        │
│  [Cancel]                       │
└─────────────────────────────────┘
```

### 6.5 In-Game Overlay (HUD)

Minimal non-intrusive overlay in corner:

```
[NET] P2 ████░ 18ms  ⊠
```

Expands on tap:
```
┌──────────────────────┐
│ Network Play         │
│ P1: You    (local)   │
│ P2: Friend   18ms    │
│ Frame delay: 2       │
│ Rollbacks: 3         │
│ [Chat]  [Disconnect] │
└──────────────────────┘
```

### 6.6 Join Flow

```
Tap room → ROM verification check
  ├── Hash matches → "Join as Player 2?" → confirm → connect → game starts
  └── Hash mismatch → "ROM mismatch. Ensure you have the same ROM file."
```

---

## 7. Phased Implementation Plan

### Phase 0: Enable RetroArch Netplay (1-2 days)

**Goal:** Enable `HAVE_NETPLAY` in Provenance's RetroArch build, allowing all 60+ RA cores to use netplay through the existing RA in-game menu.

**Changes:**
1. Add `-DHAVE_NETPLAY` to `OTHER_CFLAGS` and `OTHER_DEBUG_CFLAGS` in `CoresRetro/RetroArch/BuildFlags.xcconfig`
2. Verify `mbedTLS` (already present as `HAVE_BUILTINMBEDTLS`) links correctly
3. Verify build succeeds on iOS simulator; test LAN session between two devices

**Risk:** Low. RetroArch netplay code is mature and already compiles on other Apple platforms.

**Deliverable:** All RetroArch cores gain netplay via RA menu. No native UI yet.

---

### Phase 1: Native Room Discovery (1-2 weeks)

**Goal:** List available LAN netplay rooms in the native Provenance UI. No need to enter RA menu.

**Changes:**
1. Create `PVNetplay` SPM package (Tier 5-6)
2. Implement `PVNetplayBonjourDiscovery` using `NetServiceBrowser` to find `_retroarch._tcp` services
3. Add `NetplayRoomBrowserView` to PVUI with room listing
4. Add "Browse Rooms" entry to pause menu for RetroArch-backed games

**No bridge changes required** — we're just reading what RetroArch already advertises.

**Deliverable:** Users can see available LAN rooms in native UI; joining still opens RA menu.

---

### Phase 2: Native Host & Join (2-4 weeks)

**Goal:** Start and join netplay sessions from native SwiftUI without touching the RA menu.

**Changes:**
1. Implement `PVNetplayRetroArchBridge` (ObjC) wrapping RA command API
2. Implement `NetplayLobbyView`, `NetplayRoomCreateView` in SwiftUI
3. Wire "Host" and "Join" actions to bridge calls
4. Implement `PVNetplayManager` Swift actor for session lifecycle
5. Add in-game HUD overlay (`NetplayInGameOverlay`) showing ping/status
6. MultipeerConnectivity for Bluetooth/P2P Wi-Fi discovery as fallback

**Deliverable:** Full native SwiftUI netplay UI for RetroArch cores on LAN.

---

### Phase 3: WAN Support (2-4 weeks, post v1)

**Goal:** Connect over the internet via relay servers.

**Options:**
- A. Use RA.ME (RetroArch's existing relay) — no infrastructure cost, no App Store requirement
- B. Host a Provenance relay server — full control, requires backend
- C. GameKit for App Store builds — Apple relay, matchmaking

**Recommendation:** Option A first (lowest cost, works with `HAVE_NETPLAY`). Option C long-term for App Store distribution.

---

### Phase 4: Native Core Netplay (3-6 months, future)

**Priority order based on popularity and implementation effort:**

1. **Mednafen** — netplay.cpp already compiled; expose via bridge (Medium effort)
2. **Dolphin** — mature netplay, high demand for GC/Wii (High effort)
3. **PPSSPP** — Adhoc emulation, needs second-device coordination (High effort)

Each requires:
- ObjC bridge layer to call core's netplay APIs
- `PVNetplayNativeCoreBridge` protocol implementation
- UI integration with `PVNetplayManager`

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| `HAVE_NETPLAY` causes build failures | Low | High | Gradual flag addition; test in CI on each PR |
| App Store rejection (network features) | Medium | High | Use only documented Apple APIs; no VPN-like behavior |
| RA.ME relay reliability | Medium | Medium | Allow direct P2P as primary path; relay as fallback |
| ROM piracy surface area (sharing ROM hashes) | Medium | High | Only verify hash, never transfer ROM data |
| Latency unplayable for high-speed games | High | Medium | Show estimated latency in room browser; let users choose |
| MultipeerConnectivity adds latency | Medium | Medium | Use MC only for discovery/handshake; hand off to UDP |
| Core state desync | Medium | High | Leverage RetroArch's mature desync detection; surface errors clearly in HUD |
| Phase 0 RA menu UX friction remains | High | Low | Acceptable; Phase 2 resolves this |
| GameKit requires App Store distribution | High | Low | Only use for App Store builds; degrade gracefully |

---

## 9. Open Questions

1. **Port conflicts:** RetroArch netplay defaults to port 55435. Are there firewall/carrier conflicts on iOS cellular? Consider making port configurable.

2. **Background networking:** Apple restricts background network activity. Netplay sessions must remain in-foreground. Should we warn users before starting?

3. **Save state sync:** RetroArch syncs save state at session start. For native cores, we need an equivalent. Serialize current state before connecting.

4. **Chat:** Text chat during netplay (RA supports it). Should we add voice via WebRTC or GameKit voice channels?

5. **Spectator stream:** RA supports up to 11 spectators. Should we add a "Watch live" mode in the room browser?

6. **tvOS:** MultipeerConnectivity works on tvOS. Netplay on tvOS (game room on TV) is a compelling use case. Should Phase 2 target tvOS simultaneously?

7. **Controller assignment:** When 2 players join, who is P1? Host is always P1 in RA. Should we allow swapping post-connect?

8. **Relay infrastructure:** If we host a Provenance relay, what's the operational cost? RA.ME handles ~10KB/s per session pair; even 1000 concurrent sessions is manageable.

---

## References

- RetroArch netplay source: `PVCoreBridgeRetro/Sources/retro/tasks/task_netplay_*.c`
- Current build flags: `CoresRetro/RetroArch/BuildFlags.xcconfig`
- Mednafen netplay: `Cores/Mednafen/Package.swift` line 824 (`netplay.cpp` compiled)
- FCEU netplay stub: `Cores/FCEU/fceux-netplay-server/`
- RetroArch netplay documentation: https://docs.libretro.com/guides/netplay-guide/
- MultipeerConnectivity: https://developer.apple.com/documentation/multipeerconnectivity
- GameKit real-time matches: https://developer.apple.com/documentation/gamekit/finding_multiple_players_for_a_game
