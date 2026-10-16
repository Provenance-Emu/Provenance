//
//  PVEmulatorViewController+Netplay.swift
//  PVUIBase
//
//  Wires the PVNetplayManager session lifecycle into PVEmulatorViewController:
//
//    • startNetplayBridgeIfNeeded()  — called right after core.startEmulation()
//    • stopNetplayBridge()           — called before core.stopEmulation()
//
//  When the running core conforms to PVNetplayCapable (e.g. PVThinLibretroCore),
//  the bridge is registered with PVNetplayManager so that the manager can drive
//  host/join/stop netplay sessions natively.
//

#if canImport(PVNetplay)
import PVNetplay
import PVLogging
import ObjectiveC

// MARK: - Associated-object storage

private enum NetplayAssociatedKeys {
    static var startTask: UInt8 = 0
    static var openNetworkPlay: UInt8 = 0
}

private enum NetplayLaunchIntentDefaults {
    /// How long a thin core may take to register its netpacket interface.
    static let readyTimeout: Duration = .seconds(15)
    /// Let the boot settle (first frames, pause-menu hint) before opening the menu.
    static let hostMenuDelay: Duration = .seconds(1)
}

/// Box wrapper so a Swift Task value can be stored via objc_setAssociatedObject.
private final class TaskBox {
    let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
}

extension PVEmulatorViewController {

    // MARK: - Stored start-task handle (via associated object)

    private var netplayStartTaskBox: TaskBox? {
        get { objc_getAssociatedObject(self, &NetplayAssociatedKeys.startTask) as? TaskBox }
        set { objc_setAssociatedObject(self, &NetplayAssociatedKeys.startTask, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Lifecycle hooks

    /// Register the running core as the active netplay bridge.
    ///
    /// Call this immediately after `core.startEmulation()`.
    /// Does nothing if the core does not conform to `PVNetplayCapable`.
    ///
    /// `supportsNetplay` isn't checked here: a thin libretro core boots on its
    /// own thread and may not have registered its netpacket interface yet.
    /// `PVNetplayManager` checks it when a session starts, and the pause menu
    /// only offers netplay once it is true.
    func startNetplayBridgeIfNeeded() {
        guard let bridge = core as? any PVNetplayCapable else {
            DLOG("Netplay: core does not conform to PVNetplayCapable — skipping bridge registration.")
            return
        }
        // Cancel any prior start task before creating a new one so that a
        // re-entrant call (e.g. emulator restart) doesn't leave a stale task
        // that could register an outdated bridge after this call completes.
        netplayStartTaskBox?.task.cancel()
        netplayStartTaskBox = nil
        let task = Task { @MainActor [weak self] in
            // Guard against cancellation: if stopNetplayBridge() ran before this
            // task was scheduled, don't re-register a stale bridge.
            guard !Task.isCancelled else {
                DLOG("Netplay: start task cancelled before bridge registration — skipping.")
                return
            }
            await PVNetplayManager.shared.setActiveBridge(bridge)
            // Do NOT call setActiveBridge(nil) on cancellation here: a subsequent
            // startNetplayBridgeIfNeeded() call may have already registered a newer
            // bridge, and unconditionally clearing activeBridge would unintentionally
            // unregister it.  stopNetplayBridge() is responsible for clearing the
            // bridge on teardown.
            ILOG("Netplay: registered \(bridge.netplayEngineName) bridge with PVNetplayManager.")
            await self?.runNetplayLaunchIntentIfAny()
        }
        netplayStartTaskBox = TaskBox(task)
    }

    // MARK: - Lobby launch intent

    /// Whether the pause menu should open Network Play the next time it
    /// appears. Read once by `PauseTileMenuView`.
    private var opensNetworkPlayOnNextMenu: Bool {
        get { (objc_getAssociatedObject(self, &NetplayAssociatedKeys.openNetworkPlay) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &NetplayAssociatedKeys.openNetworkPlay, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// True once after the library lobby launched this game to host.
    func takeNetworkPlayMenuRequest() -> Bool {
        defer { opensNetworkPlayOnNextMenu = false }
        return opensNetworkPlayOnNextMenu
    }

    /// Carry out what the library's netplay lobby asked for when it launched
    /// this game: join a room, or open the room setup to host.
    @MainActor
    private func runNetplayLaunchIntentIfAny() async {
        guard let md5 = game?.md5Hash, !md5.isEmpty,
              let intent = await PVNetplayManager.shared.takeLaunchIntent(forGameMD5: md5) else { return }
        ILOG("Netplay: running lobby launch intent \(intent.action)")

        guard await PVNetplayManager.shared.waitUntilNetplayReady(timeout: NetplayLaunchIntentDefaults.readyTimeout) else {
            // Cancelled: the game stopped while waiting.
            guard !Task.isCancelled else { return }
            PVToastManager.post(
                String(localized: "This game's core doesn't support netplay."),
                type: .warning,
                icon: "antenna.radiowaves.left.and.right.slash"
            )
            return
        }

        switch intent.action {
        case .join(let room):
            do {
                try await PVNetplayManager.shared.join(room: room, settings: NetplaySettings.fromStoredDefaults())
                let message = (core as? any PVNetplayCapable)?.netplayHostStartsGame == true
                    ? String(localized: "Joined \(room.hostName). Waiting for the host to start.")
                    : String(localized: "Joined \(room.hostName).")
                PVToastManager.post(message, type: .success, icon: "antenna.radiowaves.left.and.right")
            } catch {
                ELOG("Netplay: lobby join failed: \(error.localizedDescription)")
                PVToastManager.post(
                    String(localized: "Couldn't join \(room.hostName): \(error.localizedDescription)"),
                    type: .error,
                    duration: 5
                )
            }
        case .host:
            try? await Task.sleep(for: NetplayLaunchIntentDefaults.hostMenuDelay)
            opensNetworkPlayOnNextMenu = true
            showMenu(nil)
        }
    }

    /// Deregister the active netplay bridge when the core stops.
    ///
    /// Call this before `core.stopEmulation()` and `await` it so that
    /// `PVNetplayManager.disconnect()` completes before `stopEmulation()`
    /// tears the core down.
    /// Cancels any in-flight start task to prevent a stale bridge from being
    /// registered after the stop completes.
    func stopNetplayBridge() async {
        guard core is any PVNetplayCapable else { return }
        // Cancel any pending start task so it cannot re-register after we clear.
        netplayStartTaskBox?.task.cancel()
        netplayStartTaskBox = nil
        // disconnect() stops netplay on the registered activeBridge and resets
        // PVNetplayManager.state to .idle, but does NOT clear the bridge reference.
        // setActiveBridge(nil) below explicitly drops the reference so callers
        // cannot rely on disconnect() to clear it implicitly.
        await PVNetplayManager.shared.disconnect()
        await PVNetplayManager.shared.setActiveBridge(nil)
        ILOG("Netplay: deregistered bridge from PVNetplayManager.")
    }
}
#endif
