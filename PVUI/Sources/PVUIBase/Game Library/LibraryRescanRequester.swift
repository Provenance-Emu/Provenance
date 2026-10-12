//
//  LibraryRescanRequester.swift
//  PVUIBase
//
//  Posts `.PVReimportLibrary` (the existing "Scan ROM Directories" path) at most once a minute, for the
//  triggers a picked folder needs: foregrounding and iCloud metadata updates (D17). A request inside the
//  window is not dropped: one trailing rescan runs when the window ends, so a change that arrived during it is seen.
//

import Foundation
import PVLibrary
import PVLogging
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class LibraryRescanRequester {
    public static let shared = LibraryRescanRequester()

    private var throttle = RescanThrottle()
    /// The one coalesced rescan waiting for the window to end.
    private var trailingRescan: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    private init() {}

    /// Rescans whenever the app returns to the foreground. The app runs on a window-scene delegate, so
    /// `UIApplicationDelegate.applicationWillEnterForeground` never fires; the notification does. Idempotent.
    public func startObservingForeground() {
        #if canImport(UIKit) && !os(tvOS)
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.requestRescan(reason: "foreground")
            }
        }
        #endif
    }

    /// Only while the library lives in a picked folder; App storage has no outside writers.
    public func requestRescan(reason: String) {
        guard LibraryLocation.current == .pickedFolder else { return }
        if throttle.shouldFire() {
            post(reason: reason)
            return
        }
        guard trailingRescan == nil else {
            DLOG("LibraryRescan: \(reason) throttled; a trailing rescan is already scheduled")
            return
        }
        let delay = throttle.remainingInterval()
        DLOG("LibraryRescan: \(reason) throttled; rescanning in \(Int(delay.rounded(.up))) s")
        trailingRescan = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.trailingRescan = nil
            guard LibraryLocation.current == .pickedFolder else { return }
            _ = self.throttle.shouldFire()
            self.post(reason: "\(reason), after the throttle window")
        }
    }

    private func post(reason: String) {
        ILOG("LibraryRescan: \(reason)")
        NotificationCenter.default.post(name: .PVReimportLibrary, object: nil)
    }
}
