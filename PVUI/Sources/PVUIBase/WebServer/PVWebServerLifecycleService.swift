//
//  PVWebServerLifecycleService.swift
//  PVUI
//
//  @MainActor bridge that hooks `PVWebServerManager` into
//  `BackgroundServiceRegistry` so the web server stops while the emulator
//  is active and restarts when the user returns to the library.
//
//  Symmetric with `DirectoryWatcherService` and `CloudSyncManager`.
//

import Foundation
import PVLibrary
import PVLogging
import PVPrimitives

#if canImport(PVWebServer)
import PVWebServer

@MainActor
public final class PVWebServerLifecycleService: PausableService {

    /// Shared singleton. Created on first access and immediately self-registers
    /// with `BackgroundServiceRegistry`. Idempotent — safe to reference from
    /// `PVAppDelegate` boot at every launch.
    public static let shared = PVWebServerLifecycleService()

    public let serviceName = "WebServer"

    public private(set) var activePauseReasons = Set<ServiceLifecycleReason>()

    private init() {
        BackgroundServiceRegistry.shared.register(self)
    }

    // MARK: - PausableService

    public func pause(reason: ServiceLifecycleReason) {
        guard !activePauseReasons.contains(reason) else { return }
        activePauseReasons.insert(reason)
        if activePauseReasons.count == 1 {
            ILOG("PVWebServerLifecycleService: Pausing web server (reason: \(reason.rawValue))")
            Task { await PVWebServerManager.shared.stop() }
        }
    }

    public func resume(reason: ServiceLifecycleReason) {
        guard activePauseReasons.contains(reason) else { return }
        activePauseReasons.remove(reason)
        if activePauseReasons.isEmpty {
            ILOG("PVWebServerLifecycleService: Resuming web server (reason: \(reason.rawValue))")
            Task {
                await PVWebServerManager.shared.refreshFeatureFlag()
                do {
                    _ = try await PVWebServerManager.shared.start()
                } catch {
                    ELOG("PVWebServerLifecycleService: resume failed — \(error.localizedDescription)")
                }
            }
        }
    }
}
#endif
