//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import os
import PVSupport
import RealmSwift
import PVLogging
import PVPrimitives
import PVMediaCache

@objcMembers
public final class PVSaveState: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {
    @Persisted(wrappedValue: UUID().uuidString, primaryKey: true) public var id: String
    @Persisted public var game: PVGame!
    @Persisted public var core: PVCore!
    @Persisted public var file: PVFile?
    @Persisted public var date: Date = Date()
    @Persisted public var lastOpened: Date?
    @Persisted public var image: PVImageFile?
    @Persisted public var isAutosave: Bool = false

    @Persisted public var isPinned: Bool = false
    @Persisted public var isFavorite: Bool = false

    @Persisted public var userDescription: String? = nil
    
    // CloudKit sync properties
    @Persisted public var cloudRecordID: String? // CloudKit record ID for on-demand downloads
    @Persisted public var isDownloaded: Bool = true // Whether the file is downloaded locally
    @Persisted public var fileSize: Int = 0 // File size in bytes
    @Persisted public var lastUploadedDate: Date?
    
    @Persisted public var createdWithCoreVersion: String!

    /// Cache for size calculations, protected by ``sizeCacheLock``.
    nonisolated(unsafe) private static var sizeCache = [String: UInt64]()
    /// Thread-safe guard for `sizeCache`. Uses `OSAllocatedUnfairLock` (iOS 16+) for
    /// lower overhead than `NSLock` and guaranteed deadlock-free `withLock` semantics.
    private static let sizeCacheLock = OSAllocatedUnfairLock<Void>()

    public convenience init(withGame game: PVGame, core: PVCore, file: PVFile, date: Date = Date(), image: PVImageFile? = nil, isAutosave: Bool = false, isPinned: Bool = false, isFavorite: Bool = false, userDescription: String? = nil, createdWithCoreVersion: String? = nil) {
        self.init()
        self.game = game
        self.file = file
        self.image = image
        self.date = date
        self.isAutosave = isAutosave
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.userDescription = userDescription
        self.core = core
        self.createdWithCoreVersion = createdWithCoreVersion ?? core.projectVersion
    }

    public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
        return lhs.file?.url == rhs.file?.url
    }
}

public extension PVSaveState {
    /// Synchronous size calculation - returns the combined size of the save state file and image
    var size: UInt64 {
        // Check cache first
        if let cachedSize = PVSaveState.sizeCacheLock.withLock({ PVSaveState.sizeCache[id] }) {
            return cachedSize
        }

        // Calculate size if not cached
        let calculatedSize = (file?.size ?? 0) + (image?.size ?? 0)

        // Store in cache
        PVSaveState.sizeCacheLock.withLock { PVSaveState.sizeCache[id] = calculatedSize }

        return calculatedSize
    }

    /// Asynchronous size calculation - calculates the size on a background thread
    /// - Returns: The combined size of the save state file and image
    func sizeAsync() async -> UInt64 {
        // Check cache first (synchronously)
        if let cachedSize = PVSaveState.sizeCacheLock.withLock({ PVSaveState.sizeCache[id] }) {
            return cachedSize
        }

        @ThreadSafe var threadsafeSelf: PVSaveState? = self
        /// Use Task to move the calculation to a background thread
        let calculatedSize: UInt64 = await Task.detached(priority: .utility) { [weak threadsafeSelf] () -> UInt64 in
            guard let threadsafeSelf = threadsafeSelf else { return 0 }

            /// Calculate the size on a background thread
            let fileSize = threadsafeSelf.file?.size ?? 0
            let imageSize = threadsafeSelf.image?.size ?? 0

            return fileSize + imageSize
        }.value

        // Store in cache
        PVSaveState.sizeCacheLock.withLock { PVSaveState.sizeCache[id] = UInt64(calculatedSize) }

        return calculatedSize
    }

    /// Clear the size cache for this save state
    func clearSizeCache() {
        PVSaveState.sizeCacheLock.withLock { PVSaveState.sizeCache.removeValue(forKey: id) }
    }

    /// Clear the entire size cache
    static func clearAllSizeCaches() {
        PVSaveState.sizeCacheLock.withLock { PVSaveState.sizeCache.removeAll() }
    }
}
