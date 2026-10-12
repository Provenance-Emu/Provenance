//
//  PickedLibraryFolder.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The folder the user picked for the library, as stored in the app's own defaults: the bookmark that
//  grants access, a name for Settings, and whether saves live there too (D10). Written only by
//  `LibraryLocation.switchStored(to:pickedFolder:)`.
//

import Foundation
import Defaults
import PVSettings

public struct PickedLibraryFolder: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var bookmark: Data
    public var displayName: String
    /// `Battery States`, `Save States`, `Screenshots`, `Cheats` and `Patches` live in the folder too.
    public var includesSaves: Bool
    /// When the user picked it. Tells two picks of one folder apart (bookmark bytes are not stable).
    public var pickedAt: Date

    public init(bookmark: Data, displayName: String, includesSaves: Bool, pickedAt: Date = Date()) {
        version = Self.currentVersion
        self.bookmark = bookmark
        self.displayName = displayName
        self.includesSaves = includesSaves
        self.pickedAt = pickedAt
    }
}

/// Reads and writes the one `PickedLibraryFolder`. Dates are stored as `timeIntervalSinceReferenceDate`
/// so `pickedAt` round-trips exactly (it is compared for equality).
public struct PickedLibraryFolderStore: Sendable {
    public static let shared = PickedLibraryFolderStore(read: { Defaults[.libraryPickedFolder] },
                                                        write: { Defaults[.libraryPickedFolder] = $0 })

    private let read: @Sendable () -> Data?
    private let write: @Sendable (Data?) -> Void

    public init(read: @escaping @Sendable () -> Data?, write: @escaping @Sendable (Data?) -> Void) {
        self.read = read
        self.write = write
    }

    /// A suite of its own, for tests.
    public init(defaults: UserDefaults, key: String) {
        self.init(read: { defaults.data(forKey: key) }, write: { defaults.set($0, forKey: key) })
    }

    public func load() -> PickedLibraryFolder? {
        guard let data = read() else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try? decoder.decode(PickedLibraryFolder.self, from: data)
    }

    public func save(_ folder: PickedLibraryFolder) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        write(try encoder.encode(folder))
    }

    public func clear() {
        write(nil)
    }
}
