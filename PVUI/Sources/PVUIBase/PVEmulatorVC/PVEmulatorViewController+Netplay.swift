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

#if canImport(PVNetplay)
import PVNetplay
import PVLogging
import ObjectiveC

// MARK: - Associated-object storage

private enum NetplayAssociatedKeys {
    static var startTask = "netplayStartTask"
}

/// Box wrapper so a Swift Task value can be stored via objc_setAssociatedObject.
private final class TaskBox {
    let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
}

public extension PVEmulatorViewController {

    // MARK: - Stored start-task handle (via associated object)

    private var netplayStartTaskBox: TaskBox? {
        get { objc_getAssociatedObject(self, &NetplayAssociatedKeys.startTask) as? TaskBox }
        set { objc_setAssociatedObject(self, &NetplayAssociatedKeys.startTask, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

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
        let task = Task {
            await PVNetplayManager.shared.setActiveBridge(bridge)
            ILOG("Netplay: registered \(bridge.netplayEngineName) bridge with PVNetplayManager.")
        }
        netplayStartTaskBox = TaskBox(task)
    }

    /// Deregister the active netplay bridge when the core stops.
    ///
    /// Call this before `core.stopEmulation()`.
    /// Cancels any in-flight start task to prevent a stale bridge from being
    /// registered after the stop completes.
    func stopNetplayBridge() {
        guard core is any PVNetplayCapable else { return }
        // Cancel any pending start task so it cannot re-register after we clear.
        netplayStartTaskBox?.task.cancel()
        netplayStartTaskBox = nil
        Task {
            await PVNetplayManager.shared.disconnect()
            await PVNetplayManager.shared.setActiveBridge(nil)
            ILOG("Netplay: deregistered bridge from PVNetplayManager.")
        }
    }
}
#endif
