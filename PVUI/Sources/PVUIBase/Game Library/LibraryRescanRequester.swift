//
//  LibraryRescanRequester.swift
//  PVUIBase
//
//  Posts `.PVReimportLibrary` (the existing "Scan ROM Directories" path) at most once a minute, for the
//  triggers a picked folder needs: foregrounding and iCloud metadata updates (D17).
//

import Foundation
import PVLibrary
import PVLogging

@MainActor
public final class LibraryRescanRequester {
    public static let shared = LibraryRescanRequester()

    private var throttle = RescanThrottle()

    private init() {}

    /// Only while the library lives in a picked folder; App storage has no outside writers.
    public func requestRescan(reason: String) {
        guard LibraryLocation.current == .pickedFolder else { return }
        guard throttle.shouldFire() else {
            DLOG("LibraryRescan: \(reason) throttled")
            return
        }
        ILOG("LibraryRescan: \(reason)")
        NotificationCenter.default.post(name: .PVReimportLibrary, object: nil)
    }
}
