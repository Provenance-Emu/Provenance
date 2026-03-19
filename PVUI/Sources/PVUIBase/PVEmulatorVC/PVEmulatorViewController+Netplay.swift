//
//  PVEmulatorViewController+Netplay.swift
//  PVUIBase
//
//  Wires the PVNetplayManager session lifecycle into PVEmulatorViewController:
//
//    • startNetplayBridgeIfNeeded()  — called right after core.startEmulation()
//    • stopNetplayBridge()           — called before core.stopEmulation()
//
//  When the running core conforms to PVNetplayCapable (e.g. PVRetroArchCoreCore),
//  the bridge is registered with PVNetplayManager so that the manager can drive
//  host/join/stop netplay sessions natively.
//

import PVNetplay
import PVLogging

public extension PVEmulatorViewController {

    // MARK: - Lifecycle hooks

    /// Register the running core as the active netplay bridge if it supports netplay.
    ///
    /// Call this immediately after `core.startEmulation()`.
    /// Does nothing if the core does not conform to `PVNetplayCapable`.
    func startNetplayBridgeIfNeeded() {
        guard let bridge = core as? any PVNetplayCapable else {
            DLOG("Netplay: core does not conform to PVNetplayCapable — skipping bridge registration.")
            return
        }
        Task {
            await PVNetplayManager.shared.setActiveBridge(bridge)
            ILOG("Netplay: registered \(bridge.netplayEngineName) bridge with PVNetplayManager.")
        }
    }

    /// Deregister the active netplay bridge when the core stops.
    ///
    /// Call this before `core.stopEmulation()`.
    func stopNetplayBridge() {
        guard core is any PVNetplayCapable else { return }
        Task {
            await PVNetplayManager.shared.disconnect()
            await PVNetplayManager.shared.setActiveBridge(nil)
            ILOG("Netplay: deregistered bridge from PVNetplayManager.")
        }
    }
}
