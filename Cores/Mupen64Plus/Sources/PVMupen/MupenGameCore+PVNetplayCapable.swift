//
//  MupenGameCore+PVNetplayCapable.swift
//  PVMupenGameCore
//
//  Created by Joseph Mattiello on 3/24/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adopts PVNetplayCapable on MupenGameCore (native Mupen64Plus).
//
//  Current status: supportsNetplay = false
//
//  Native N64 netplay via mupen64plus-netplay plugin is not yet integrated.
//  The plugin implements rollback netcode over UDP and is available at:
//    https://github.com/Provenance-Emu/mupen64plus-netplay
//
//  To implement Option A (native rollback netplay):
//    1. Add mupen64plus-netplay as a submodule under Cores/Mupen64Plus/
//    2. Compile it into the PVMupenBridge target
//    3. Expose netplay_init()/netplay_sync()/netplay_deinit() via ObjC in
//       PVMupenBridge (MupenBridge+Netplay.h/.mm)
//    4. Set supportsNetplay = true here and call through to the bridge
//
//  For immediate N64 netplay use the RetroArch path:
//    - mupen64plus_next (RA core) — HAVE_NETPLAY enabled, works today
//    - parallel_n64 (RA core)    — HAVE_NETPLAY enabled, works today
//  These route through PVRetroArchCoreBridge which already conforms to
//  PVNetplayCapable with supportsNetplay = true.
//

#if canImport(PVNetplay)
import Combine
import PVNetplay

// MARK: - PVNetplayCapable
// Note: MupenGameCore is already declared `@unchecked Sendable` in its class
// definition (MupenGameCore.swift). PVNetplayCapable methods must serialize
// state mutations onto MainActor or the core's dedicated mupen run-loop thread
// internally — callers (e.g. PVNetplayManager actor) are not required to hop
// to MainActor before calling these methods.

extension MupenGameCore: PVNetplayCapable {

    /// Native Mupen64Plus netplay is not yet implemented.
    ///
    /// Set to `true` once the mupen64plus-netplay plugin is compiled into
    /// PVMupenBridge and the start/stop/state bridge methods are wired up.
    public var supportsNetplay: Bool { false }

    public var netplayEngineName: String { "Mupen64Plus" }

    // MARK: - Control

    /// Throws `.unsupported` because the mupen64plus-netplay plugin is not
    /// yet compiled into PVMupenBridge.
    ///
    /// Once native support lands, replace this with calls to the ObjC bridge
    /// methods that wrap mupen64plus-netplay plugin APIs.
    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        throw NetplayError.unsupported
    }

    /// No-op — no session to stop when native netplay is not supported.
    public func stopNetplay() async {
        // No-op until mupen64plus-netplay plugin is integrated.
    }

    // MARK: - State

    public var netplayState: NetplayState { .idle }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        // Emit .idle once and complete. A real implementation would poll the
        // mupen64plus-netplay plugin's connection state via a timer, similar to
        // how melonDS (LocalMP) and PPSSPP (Ad Hoc) publishers work.
        Just(.idle).eraseToAnyPublisher()
    }
}
#endif // canImport(PVNetplay)
