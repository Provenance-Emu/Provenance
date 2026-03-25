import Foundation
import PVLogging
import PVSettings

#if os(iOS) || targetEnvironment(macCatalyst)
import Defaults

/// Observes physical case controller connection events and auto-loads a compatible
/// DeltaSkin session skin when `Defaults[.autoLoadCaseSkin]` is enabled.
///
/// ## Lifecycle
///
/// Create one instance (e.g. from `AppDelegate` or a root SwiftUI view) and keep it
/// alive for the duration of the app session:
///
/// ```swift
/// let caseSkinCoordinator = CaseControllerSkinCoordinator()
/// caseSkinCoordinator.start()
/// ```
///
/// ## What it does on case connect
///
/// 1. Reads `layout` from the notification's `userInfo`.
/// 2. Iterates `layout.knownSkinIdentifiers` looking for any installed skin.
/// 3. For each found skin, calls
///    `DeltaSkinManager.shared.setSessionSkin(_:for:orientation:)` for both
///    `.portrait` and `.landscape` orientations so the skin is active immediately.
/// 4. Posts a single success toast: `"[Case name] detected — loading compatible skin"`.
///    Falls back to `"[Case name] detected"` when no matching skin is installed.
@MainActor
public final class CaseControllerSkinCoordinator {

    // MARK: - State

    private var observerToken: NSObjectProtocol?

    // MARK: - Init / deinit

    public init() {}

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Begin observing `PVPhysicalCaseDidConnect` notifications.
    public func start() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: .PVPhysicalCaseDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleCaseConnect(note)
        }
        DLOG("CaseControllerSkinCoordinator: started")
    }

    /// Stop observing notifications.
    public func stop() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
    }

    // MARK: - Private

    private func handleCaseConnect(_ note: Notification) {
        guard let layout = note.userInfo?[CaseControllerDetectorKeys.layout] as? PhysicalCaseLayout else {
            WLOG("CaseControllerSkinCoordinator: notification missing layout userInfo key")
            return
        }

        guard Defaults[.autoLoadCaseSkin] else {
            PVToastManager.post(
                "\(layout.name) detected",
                type: .success,
                duration: 3.5,
                icon: "iphone.gen3.badged.gamecontroller"
            )
            return
        }

        // Attempt to find and load a compatible skin asynchronously.
        Task {
            await loadFirstAvailableSkin(for: layout)
        }
    }

    @MainActor
    private func loadFirstAvailableSkin(for layout: PhysicalCaseLayout) async {
        let skinManager = DeltaSkinManager.shared

        for skinIdentifier in layout.knownSkinIdentifiers {
            do {
                guard let skin = try await skinManager.skin(withIdentifier: skinIdentifier) else {
                    continue
                }

                // Resolve the system this skin targets.
                guard let systemId = skin.gameType.systemIdentifier else {
                    WLOG("CaseControllerSkinCoordinator: skin '\(skinIdentifier)' has unmapped gameType \(skin.gameType.rawValue)")
                    continue
                }

                // Apply as session skin for both orientations.
                skinManager.setSessionSkin(skinIdentifier, for: systemId, orientation: .portrait)
                skinManager.setSessionSkin(skinIdentifier, for: systemId, orientation: .landscape)

                ILOG("CaseControllerSkinCoordinator: loaded skin '\(skin.name)' for \(layout.name)")

                PVToastManager.post(
                    "\(layout.name) detected — loading compatible skin",
                    type: .success,
                    duration: 4.0,
                    icon: "iphone.gen3.badged.gamecontroller"
                )
                return

            } catch {
                WLOG("CaseControllerSkinCoordinator: error looking up skin '\(skinIdentifier)': \(error)")
            }
        }

        // No matching skin found — show simpler toast.
        PVToastManager.post(
            "\(layout.name) detected",
            type: .success,
            duration: 3.5,
            icon: "iphone.gen3.badged.gamecontroller"
        )
        ILOG("CaseControllerSkinCoordinator: no installed skin found for \(layout.name)")
    }
}
#endif
