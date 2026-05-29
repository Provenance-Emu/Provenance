# Thin-Wrapper Netplay (libretro netpacket) — Design

**Status: draft for review**
**Date: 2026-05-29**
**Author: agent investigation for maintainer review**

---

## 0. TL;DR (read this first — the premise has moved)

The task premise was: *"thin-wrapper cores report `supportsNetplay=false`; we want to
expose libretro netplay (`RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE`) through the thin
wrapper, PPSSPP in particular."*

That premise is **partly stale**. Investigation found:

1. **The netpacket plumbing is already ~90% built** — env-78 handler, the ObjC
   callback storage on `PVThinLibretroFrontend`, the static C `send`/`poll_receive`
   trampolines, a `NetpacketTransport` (Network.framework) in PVNetplay, and the
   `PVThinLibretroCore: PVNetpacketCapable / PVNetplayCapable` conformance. None of
   this is hypothetical; it is on `develop` today.

2. `supportsNetplay` for thin cores is **not hard-coded false**. It returns
   `hasNetpacketInterface`, which is correctly `false` *until a core registers an
   interface via env 78* — and stays false because (see #3) no core does.

3. **The receive path is not wired.** Outbound packets work (core → transport).
   Inbound packets dead-end: `NetpacketTransport.dequeueReceived()` and the bridge's
   `-enqueueNetpacketData:fromClient:` both exist but **nothing calls either**.
   This is the one real code gap and it is small (one callback wire-up).

4. **No core I could find uses netpacket — and PPSSPP definitely does not.**
   PPSSPP specifically is **solid**: no core in `Cores/` calls
   `RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE`, and PPSSPP's PSP multiplayer is its
   own AdHoc/PRO netcode, not the libretro netpacket API. The broader "no core
   anywhere" claim is **weaker** — `gh api search/code` is non-exhaustive (caps
   results, doesn't index every repo/branch); the only non-header hit in the
   libretro org was RetroArch's own `runloop.c` (the frontend side). So even with a
   perfect thin implementation, for PPSSPP and every core checked so far,
   **PPSSPP would still report `supportsNetplay=false`** because PPSSPP's libretro
   core never offers the interface. PPSSPP netplay is handled by PPSSPP's own
   ad-hoc/PRO netcode, which is not surfaced through the libretro netpacket API.

**Bottom line:** the honest deliverable is two-part. (a) Finishing the netpacket
receive path is a real, small, worthwhile fix that makes the existing scaffolding
actually functional for *any future* netpacket-capable core. (b) Getting **PPSSPP**
netplay specifically is a *different, much larger* problem that netpacket does not
solve. The doc covers both and is explicit about which is which.

---

## 1. Purpose

Make the thin libretro wrapper a working frontend for libretro's native
netpacket multiplayer interface (env command 78,
`RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE`), reusing PVNetplay's transport and
session layer rather than reinventing it, and have `supportsNetplay` reflect
real capability. Keep everything iOS/tvOS-safe.

---

## 2. Current state

### 2.1 Where `supportsNetplay` comes from

- Protocol: `PVNetplayCapable.supportsNetplay: Bool { get }`
  — `PVNetplay/Sources/PVNetplay/Protocols/PVNetplayCapable.swift:23`
- Sub-protocol for netpacket cores: `PVNetpacketCapable`
  — `PVNetplay/Sources/PVNetplay/Protocols/PVNetpacketCapable.swift:21-28`
- Thin-wrapper conformance:
  `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Netplay.swift:42-44`

  ```swift
  var supportsNetplay: Bool {
      hasNetpacketInterface
  }
  ```

  and `hasNetpacketInterface` forwards to the ObjC bridge
  (`PVThinLibretroCore+Netplay.swift:27-29` → `PVThinLibretroFrontend.hasNetpacketInterface`).

- Bridge implementation:
  `PVThinLibretroFrontend.mm:3878-3880`
  ```objc
  - (BOOL)hasNetpacketInterface { return _netpacketCallback != NULL; }
  ```

So `supportsNetplay` is `true` **iff** the loaded core called env 78 with a valid
`retro_netpacket_callback` (non-null `start` + `receive`). It is *not* a stub
`false`. It is false in practice only because no core registers the interface
(§2.4).

### 2.2 What is already implemented in the thin wrapper

`PVThinLibretroFrontend.mm` / `.h`:

- **State** (`.mm:833-838`): `_netpacketCallback`, `_netpacketSessionActive`,
  `_netpacketIncomingQueue`, `_netpacketIncomingClientIDs`, `_netpacketQueueLock`
  (an `os_unfair_lock`).
- **Env-78 handler** (`.mm:5894-5913`, in the same `switch` as every other
  `SET_*`): validates `cb->start && cb->receive`, deep-copies the callback struct
  via `malloc`/`memcpy`, allocates the incoming queues, logs `protocol_version`.
- **Static C trampolines** (`.mm:968-982`): `thin_netpacket_send` and
  `thin_netpacket_poll_receive`, resolved through the per-thread `_thinCurrentTLS`
  instance pointer.
- **Send path** (`.mm:3849-3854`): `-_thinNetpacketSendWithFlags:buf:len:clientID:`
  forwards to the `netpacketSendBlock` property when a session is active.
- **Poll-receive path** (`.mm:3856-3874`): `-_thinNetpacketPollReceive` drains
  `_netpacketIncomingQueue` (under the lock) and calls the core's `receive` fn for
  each packet. This runs on the emu thread because the core calls
  `poll_receive_fn` itself.
- **Session lifecycle** (`.mm:3887-3911`): `-startNetpacketSessionWithClientID:`
  invokes `_netpacketCallback->start(clientID, send, poll_receive)`;
  `-stopNetpacketSession` invokes `stop` and clears queues.
- **Inbound enqueue (unused)** (`.mm:3913-3920`): `-enqueueNetpacketData:fromClient:`
  appends to `_netpacketIncomingQueue` under the lock. **No caller.**
- **Peer notifications** (`.mm:3922-3936`): `-netpacketPeerConnected:` /
  `-netpacketPeerDisconnected:` call the core's optional `connected`/`disconnected`.
  Note: `connected` returns `bool` (accept/reject) per the API; the return is
  currently ignored.
- **Teardown** (`.mm:3373-3374`, `3417-3420`): stops session and frees the callback
  on core unload.
- **Header surface** (`.h:327-352`): `hasNetpacketInterface`,
  `netpacketProtocolVersion`, `netpacketSendBlock`, start/stop/enqueue/peer methods.

### 2.3 What is already implemented in PVNetplay

- `NetpacketTransport` — `PVNetplay/Sources/PVNetplay/Transport/NetpacketTransport.swift`
  - Network.framework, UDP (unreliable) + optional TCP sideband on `port+1`
    (reliable). Host assigns sequential client IDs (host = 0); 6-byte
    `"PVNP" + bigEndian(uint16 clientID)` handshake.
  - `func send(data:to:flags:)` (`:195`) — outbound, maps `RETRO_NETPACKET_RELIABLE`
    to TCP.
  - `func dequeueReceived() -> [NetpacketMessage]` (`:222`) — drains the *transport's*
    incoming queue. **No caller.**
  - `onPeerConnected` / `onPeerDisconnected` (`:92-95`) — fired on the network queue.
  - There is **no** `onPacketReceived` callback; inbound packets only land in the
    private `incomingQueue` (`:112`, filled by `enqueue` at `:463`).
- `PVNetplayManager` (actor) — `PVNetplay/Sources/PVNetplay/PVNetplayManager.swift`
  - `host` / `join` / `spectate` / `disconnect`, all guarded by
    `bridge.supportsNetplay` (`:70,100,128`). Owns `NetplayState`. `ObservableNetplayManager`
    is the `@MainActor` SwiftUI wrapper.
- Swift bridge glue —
  `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Netplay.swift`
  - `startNetplay(role:settings:)` (`:50-104`): creates the transport, wires
    `onPeerConnected/Disconnected` → `_bridge.netpacketPeerConnected/Disconnected`,
    wires `_bridge.netpacketSendBlock` → `transport.send`, `await transport.start()`,
    then `_bridge.startNetpacketSession(withClientID:)`.
  - `stopNetplay()` (`:107-113`).

> Note on confidence: the PPSSPP-specific finding is solid (submodule grep + known
> AdHoc/PRO netcode). The general "no core uses env 78" is a *best-effort* result of
> a non-exhaustive `gh` code search and may miss cores; see §7.1.

### 2.4 The two concrete gaps

**Gap A — inbound packets never reach the core (the real bug).**
`startNetplay` wires *send* and *peer* callbacks but never connects the transport's
inbound stream to the bridge's inbound queue. There are two disjoint incoming
queues that were built to two different models and never joined:

| Queue | Filled by | Drained by | Status |
|-------|-----------|------------|--------|
| `NetpacketTransport.incomingQueue` | `receiveLoop` → `enqueue` (`NetpacketTransport.swift:463`) | `dequeueReceived()` (`:222`) | drain has **no caller** |
| `_netpacketIncomingQueue` (bridge) | `-enqueueNetpacketData:fromClient:` (`.mm:3915`) | `-_thinNetpacketPollReceive` (emu thread, `.mm:3856`) | fill has **no caller** |

Result: the core calls `poll_receive_fn` every frame, the bridge drains an
always-empty queue, and packets the network actually received sit forever in the
transport. **Outbound works; inbound is dead.**

**Gap B — the core's optional `poll` callback is never invoked.**
`retro_netpacket_callback.poll` (optional) is meant to be called by the frontend
once per frame so the core can flush/advance its netcode independent of incoming
data. `executeFrame` (`.mm:4146-4149`) only does `runFrame` + `tickAchievements`.
Not fatal (cores that need it can work off `poll_receive`), but it is part of the
contract and some cores rely on it.

### 2.5 UI / lifecycle wiring (already present)

- `PVEmulatorViewController+Netplay.swift` registers/deregisters the running core
  as the active bridge (`startNetplayBridgeIfNeeded` `:47`, `stopNetplayBridge` `:86`),
  guarded by `supportsNetplay` (`:52`).
- `PauseTileMenuViewModel.swift:1053-1057` gates the netplay menu entry on
  `(core as? any PVNetplayCapable)?.supportsNetplay`.

So the moment a core registers env 78 *and* Gap A is closed, the existing menu and
manager paths light up with no further UI work.

---

## 3. The libretro netpacket API (quoted from the bundled header)

Source: `PVCoreBridgeRetro/Sources/retro/libretro-common/include/libretro.h`
(this is the header the thin wrapper actually compiles against; it is current —
it already defines env 78 and the full struct).

**Environment command number** (`:1795-1803`):

```c
#define RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE 78
/* const struct retro_netpacket_callback * --
 * When set, a core gains control over network packets sent and
 * received during a multiplayer session. ...
 * Should be set in either retro_init or retro_load_game, but not both.
 */
```

(Env 76 was an obsolete earlier version, removed; `:1786-1787`.)

**Flags + broadcast constant** (`:3848-3853`):

```c
#define RETRO_NETPACKET_UNRELIABLE  0
#define RETRO_NETPACKET_RELIABLE    (1 << 0)
#define RETRO_NETPACKET_UNSEQUENCED (1 << 1)
#define RETRO_NETPACKET_FLUSH_HINT  (1 << 2)
#define RETRO_NETPACKET_BROADCAST   0xFFFF
```

**Function-pointer typedefs** (`:3855-3862`):

```c
typedef void (RETRO_CALLCONV *retro_netpacket_send_t)(int flags, const void* buf, size_t len, uint16_t client_id);
typedef void (RETRO_CALLCONV *retro_netpacket_poll_receive_t)(void);
typedef void (RETRO_CALLCONV *retro_netpacket_start_t)(uint16_t client_id, retro_netpacket_send_t send_fn, retro_netpacket_poll_receive_t poll_receive_fn);
typedef void (RETRO_CALLCONV *retro_netpacket_receive_t)(const void* buf, size_t len, uint16_t client_id);
typedef void (RETRO_CALLCONV *retro_netpacket_stop_t)(void);
typedef void (RETRO_CALLCONV *retro_netpacket_poll_t)(void);
typedef bool (RETRO_CALLCONV *retro_netpacket_connected_t)(uint16_t client_id);
typedef void (RETRO_CALLCONV *retro_netpacket_disconnected_t)(uint16_t client_id);
```

**The callback struct** (`:3864-3873`):

```c
struct retro_netpacket_callback
{
   retro_netpacket_start_t        start;
   retro_netpacket_receive_t      receive;
   retro_netpacket_stop_t         stop;         /* Optional - may be NULL */
   retro_netpacket_poll_t         poll;         /* Optional - may be NULL */
   retro_netpacket_connected_t    connected;    /* Optional - may be NULL */
   retro_netpacket_disconnected_t disconnected; /* Optional - may be NULL */
   const char* protocol_version; /* Optional - if not NULL ... decide if communication is compatible */
};
```

**Contract semantics (from the typedefs + RetroArch's `runloop.c` usage):**
- Frontend calls `start(client_id, send_fn, poll_receive_fn)` when a session
  begins; passes its own `send`/`poll_receive` trampolines and the assigned id.
- Core calls `send_fn(flags, buf, len, client_id)` to transmit; `client_id =
  0xFFFF` means broadcast.
- Core calls `poll_receive_fn()` (typically each frame) to ask the frontend to
  deliver queued packets; the frontend responds by invoking the core's `receive`
  for each queued packet.
- Frontend may call `poll()` each frame, and `connected`/`disconnected` on peer
  join/leave. `connected` returns `bool` to accept/reject the peer.
- `protocol_version`, if set, gates compatibility instead of core version.

These map 1:1 onto the existing thin implementation (§2.2). The implementation is
faithful to the header; the only missing wire is inbound delivery.

---

## 4. How thick / PVNetplay netplay works today

- The **thick** RetroArch wrapper does *not* use netpacket. It runs the full
  RetroArch runtime in-process, so it gets RetroArch's classic deterministic
  lockstep/rollback netplay "for free" via RetroArch's own netplay subsystem
  (`runloop.c` is where upstream consumes env 78 — i.e. RetroArch is itself the
  netpacket *frontend* for cores that offer it, plus it has its own input-relay
  netplay for cores that don't).
- `PVRetroArchCoreCore+PVNetplayCapable.swift` / `…Bridge+PVNetplayCapable.swift`
  expose `supportsNetplay` from the thick bridge (`netplaySupported`).
- PVNetplay's higher layers — `PVNetplayManager`, room model, Bonjour discovery,
  the RetroArch WAN lobby service — are **transport-agnostic** and already drive
  both wrappers through the same `PVNetplayCapable` protocol. They do **not**
  expose a raw-packet API themselves; raw packets are the `NetpacketTransport`'s
  job, which is thin-specific.

**Implication for the thin design:** reuse is already in place. The thin wrapper
plugs into PVNetplay at the `PVNetplayCapable`/`startNetplay` level, and owns its
own `NetpacketTransport` for the byte pipe. We do *not* need to add raw-packet
APIs to the manager. The only thing missing is joining the transport's inbound
stream to the bridge.

---

## 5. Proposed thin-wrapper design

### 5.1 Component / data-flow map

```
            ┌─────────────────────────── emu thread ───────────────────────────┐
            │  core.retro_run()                                                 │
            │     ├─ send_fn(flags,buf,len,id) ──► thin_netpacket_send          │
            │     │        └─ -_thinNetpacketSendWithFlags ─► netpacketSendBlock │
            │     │                 └─ transport.send(data:to:flags:)  ─────────┼──► network
            │     └─ poll_receive_fn() ──► thin_netpacket_poll_receive          │
            │              └─ -_thinNetpacketPollReceive                        │
            │                   └─ drains _netpacketIncomingQueue ─► core.receive│
            └───────────────────────────────────────────────────────────────────┘
                                          ▲
                  (GAP A — add this)       │  -enqueueNetpacketData:fromClient:
            ┌──────────────── network queue ┴────────────────┐
            │  NetpacketTransport.receiveLoop                  │
            │     └─ NEW: onPacketReceived(data, fromClient) ──┘
            └──────────────────────────────────────────────────┘
```

### 5.2 (a) Advertising the interface to the core — already done

No change needed. The env-78 case in `handleEnvironmentCommand`
(`PVThinLibretroFrontend.mm:5894-5913`) already accepts and stores the callback,
sitting alongside every other `SET_*` handler. This is exactly where the maintainer
expected it.

### 5.3 (b) Storing the core's callbacks — already done

`_netpacketCallback` is a heap copy of the struct (`.mm:5902-5903`); freed on
teardown (`.mm:3417-3420`). Static trampolines resolve the live instance via
`_thinCurrentTLS`. No change needed.

### 5.4 (c) Bridging send/receive to PVNetplay's transport

- **Send: done.** `netpacketSendBlock` → `transport.send` is wired in
  `startNetplay` (`+Netplay.swift:74-78`).
- **Receive: the fix (Gap A).** Recommended **push model**, mirroring the existing
  `onPeerConnected` pattern:
  1. Add `public var onPacketReceived: (@Sendable (Data, UInt16) -> Void)?` to
     `NetpacketTransport`. In `receiveLoop` (`NetpacketTransport.swift:451-469`),
     after the handshake-skip check, call `onPacketReceived?(data, clientID)`
     instead of (or in addition to) `enqueue(...)`.
  2. In `startNetplay` (`+Netplay.swift`, alongside the existing `onPeerConnected`
     wiring), add:
     ```swift
     transport.onPacketReceived = { [weak self] data, clientID in
         data.withUnsafeBytes { raw in
             self?._bridge.enqueueNetpacketData(Data(raw), fromClient: clientID)
         }
     }
     ```
     (or pass `data` straight through — it is already a `Data`).
  3. The emu thread continues to drain `_netpacketIncomingQueue` via the existing
     `-_thinNetpacketPollReceive`. Thread-safety holds: `-enqueueNetpacketData:`
     already takes `_netpacketQueueLock` (`os_unfair_lock`), and the drain takes
     the same lock — network-queue enqueue vs. emu-thread drain is safe.
  4. `NetpacketTransport.dequeueReceived()` and `incomingQueue` become dead code →
     remove (or keep `dequeueReceived` only if a pull model is preferred; see §7).

  **Why push over pull:** the bridge already owns the emu-thread-drained queue with
  the right lock. A pull model would require the emu thread to reach into the
  transport actor each frame (actor-hop / sync bridging from a C callback), which
  is awkward and slower. Push keeps the C `poll_receive` path lock-local.

### 5.5 (d) Flipping `supportsNetplay` true — already correct

`supportsNetplay == hasNetpacketInterface == (_netpacketCallback != NULL)`. It
flips automatically when a core registers env 78. No special-casing per core.
**Do not** hard-code it true for PPSSPP or anyone — that would surface a netplay
menu that does nothing.

### 5.6 (e) Optional: invoke `poll` per frame (Gap B)

Add to `executeFrame` (`.mm:4146`), only while a session is active:
```objc
if (_netpacketSessionActive && _netpacketCallback && _netpacketCallback->poll) {
    _netpacketCallback->poll();
}
```
Guarded so it is a no-op outside netplay. Low risk.

### 5.7 iOS/tvOS safety

- `NetpacketTransport` is Network.framework only — available and identical on iOS
  and tvOS. No `#if os()` needed.
- No UIKit/AppKit, no DragGesture/haptics — the gap fix is model-layer.
- Listening sockets on tvOS are allowed; LAN discovery via Bonjour already exists
  in PVNetplay. Confirm the app has the **Local Network** usage description /
  entitlement for LAN host/discover (see §7).

---

## 6. MVP vs. full scope

### 6.1 MVP (small — finishes existing scaffolding)

1. Add `onPacketReceived` to `NetpacketTransport`; wire it to
   `enqueueNetpacketData:fromClient:` in `startNetplay`. **(Gap A — the only real
   code bug.)**
2. Remove the now-dead `dequeueReceived()` / `incomingQueue` (or keep one model
   consistently).
3. (Optional, cheap) invoke `poll` per frame (Gap B).
4. Add a unit/integration test: stand up host + client `NetpacketTransport`, send a
   packet, assert it arrives at `enqueueNetpacketData` (PVNetplay already has
   `NetpacketTransportTests.swift`).

This MVP makes the thin wrapper a *correct, functional* netpacket frontend for
**any** core that offers env 78. It does **not** by itself enable any currently
shipping core, because none offer the interface (§2.4).

### 6.2 Full scope (large — to get an actual playable core)

- **Find/produce a netpacket-capable core.** No core in `Cores/` uses env 78, and
  in the upstream libretro org only RetroArch's `runloop.c` references it (it is the
  frontend). Netpacket-using *cores* are rare. This is the gating unknown: without a
  core that calls env 78, the feature has no user-visible effect.
- **Session orchestration & matchmaking** beyond raw transport: room exchange of
  `protocol_version`, ROM-hash match enforcement, spectator semantics, reconnection,
  NAT traversal for WAN (current transport is LAN-oriented).
- **`connected` accept/reject** handling (currently ignored), max-player enforcement,
  client-id reuse after disconnect.
- **Reliability/ordering correctness** for the TCP sideband under load; the current
  `port+1` TCP channel is best-effort.

### 6.3 PPSSPP specifically (the maintainer's headline ask) — separate problem

- PPSSPP's libretro core **does not** implement netpacket (verified: the only
  `netpacket` token in its tree is the Linux system header `<netpacket/packet.h>`
  in `compat_ifaddrs.c`; no `SET_NETPACKET_INTERFACE` call). PSP multiplayer in
  PPSSPP is its own ad-hoc/PRO-online netcode, not exposed via libretro.
- Therefore PPSSPP will report `supportsNetplay=false` no matter how complete the
  thin netpacket frontend is. There is **no netpacket path to PPSSPP netplay.**
- Separately, PPSSPP currently follows thin-by-default routing again
  (`PVCoreFactory.swift:39-43` — the earlier force-to-thick was reverted; the
  CLAUDE.md "PPSSPP force-routed to thick" note is itself stale), and the thin PSP
  boot path has been under active Vulkan repair as of 2026-05-29. Netplay is moot
  until PSP runs cleanly.
- Options for PPSSPP netplay, all out of scope here and all large: (i) patch the
  PPSSPP libretro core to expose its netcode through env 78; (ii) use the thick
  RetroArch wrapper + RetroArch's input-relay netplay (not netpacket); (iii) a
  bespoke PPSSPP-online bridge. Recommend tracking PPSSPP netplay as its own epic.

---

## 7. Open questions / risks

1. **Which core, if any, will exercise this?** (Highest priority.) The MVP is
   correct but inert without a netpacket-capable core. Need the maintainer to name
   a target core (or accept this as forward-looking infrastructure). Action: survey
   recent upstream cores for `SET_NETPACKET_INTERFACE` adoption.
2. **Does the core register env 78 in `retro_init` or `retro_load_game`?** Header
   says "either, not both." The thin handler works for both, but `supportsNetplay`
   is only meaningful *after* the core registers. The UI gate
   (`startNetplayBridgeIfNeeded` after `startEmulation`) runs post-load, so both
   timings are covered — verify with a real core.
3. **Push vs. pull receive model.** §5.4 recommends push (callback) to keep the C
   `poll_receive` path lock-local. Confirm with maintainer before deleting
   `dequeueReceived()`.
4. **`@Sendable` / actor boundaries.** `onPacketReceived` fires on the transport's
   `NWConnection` queue; `enqueueNetpacketData:` is plain ObjC under an
   `os_unfair_lock`, so it is safe to call from there. `_bridge` capture must be
   `[weak self]` to avoid a retain cycle through the associated-object transport.
5. **Local Network entitlement (iOS/tvOS).** Hosting a listener and Bonjour
   discovery require the Local Network usage description and may interact with the
   pending multicast entitlement (see memory `multicast-entitlement.md`). Confirm
   device-build entitlements before claiming LAN netplay works on-device.
6. **WAN / NAT.** `NetpacketTransport` is LAN-first (direct host:port). WAN play
   needs relay/punch-through; out of MVP scope.
7. **`connected` return value ignored.** Peer accept/reject is not honored; fine
   for MVP LAN, must be handled before any public/WAN session.
8. **Header currency.** The bundled `libretro.h` already matches upstream for the
   netpacket API (env 78 + full struct), so no header bump is required for this
   work. If a future core needs a newer libretro API, re-verify against
   libretro-common upstream.

---

## 8. Sources

- Thin frontend: `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.mm`
  (lines cited inline), `…/PVThinLibretroFrontend.h:327-352`.
- Thin Swift conformance:
  `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Netplay.swift`.
- libretro API: `PVCoreBridgeRetro/Sources/retro/libretro-common/include/libretro.h:1786-1803, 3846-3873`.
- PVNetplay: `…/Transport/NetpacketTransport.swift`, `…/PVNetplayManager.swift`,
  `…/Protocols/PVNetplayCapable.swift`, `…/Protocols/PVNetpacketCapable.swift`.
- UI/lifecycle: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+Netplay.swift`,
  `…/PauseTileMenuViewModel.swift:1053-1057`.
- Routing: `PVUI/Sources/PVUIBase/Emulator/PVCoreFactory.swift:28-68`.
- Core survey: `grep` across `Cores/` (no `SET_NETPACKET_INTERFACE` usage; PPSSPP's
  only hit is `<netpacket/packet.h>` in `compat_ifaddrs.c`); `gh api search/code
  q='RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE org:libretro'` → only non-header hit
  is `RetroArch/runloop.c`.
