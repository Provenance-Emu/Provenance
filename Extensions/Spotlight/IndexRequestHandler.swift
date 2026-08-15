//
//  IndexRequestHandler.swift
//  Spotlight
//
//  Created by Joseph Mattiello on 2/12/18.
//  Copyright © 2018,2025 Joseph Mattiello. All rights reserved.
//

import CoreSpotlight
import CoreServices
import PVLibrary
import PVPrimitives
import PVSupport
import RealmSwift
import UniformTypeIdentifiers

public enum SpotlightError: Error {
    case appGroupsNotSupported
    case dontHandleDatatype
    case notFound
    case realmError(Error)
    case configurationError
}

public final class IndexRequestHandler: CSIndexExtensionRequestHandler {
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"

    /// Records that an indexing pass started so the host app can detect this
    /// process being jetsammed mid-index. Spotlight index extensions run under a
    /// memory ceiling of tens of MB and the kill is a SIGKILL, so nothing
    /// in-process can report it — see `ExtensionRunMarker`.
    private let runMarker = ExtensionRunMarker(extensionName: IndexRequestHandler.markerName)

    /// Extension name used for the marker file and the Sentry tag value.
    private static let markerName = "Spotlight"

    /// Flag to use mock data instead of real data
    private let useMockData = false
    
    /// Mock data driver for testing
    private var mockDriver: MockSpotlightDataDriver?
    
    /// Opens the shared library Realm, propagating a failure instead of trapping.
    ///
    /// `RomDatabase.sharedInstance.realm` is a non-throwing property implemented
    /// as `try! Realm(configuration:)`. In an extension running against a hard
    /// memory ceiling, a failed open is therefore a hard crash rather than the
    /// graceful degradation the surrounding `do/catch` blocks implied. Opening
    /// the same configuration with `try` keeps the identical database while
    /// letting the caller report and recover.
    private func openRealm() throws -> Realm {
        try Realm(configuration: RealmConfiguration.realmConfig)
    }

    /// Safe database access methods using the shared library configuration
    private func getGame(byMD5 md5: String) throws -> PVGame? {
        let realm = try openRealm()

        // Get the game and freeze it so it can be used across threads
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())?.freeze()
    }

    /// How many games are turned into `CSSearchableItem`s at a time.
    ///
    /// A Spotlight index extension runs under a memory ceiling of tens of MB.
    /// The previous implementation materialised **every** `PVGame` into a frozen
    /// array and built one `CSSearchableItem` per game before submitting any of
    /// them, so peak memory scaled with library size — a large library would get
    /// the extension jetsammed before it indexed anything. Batching keeps peak
    /// memory flat regardless of how many games the user has.
    private static let indexBatchSize = 50

    /// Index the whole library in bounded batches.
    ///
    /// Realm `Results` are lazy, so slicing them only faults in the objects for
    /// the current batch; each batch is wrapped in an `autoreleasepool` so the
    /// Objective-C `CSSearchableItem` / attribute-set objects are released
    /// between batches instead of accumulating for the whole run.
    private func indexAllGamesInBatches() throws {
        let realm = try openRealm()
        /// Sorted by primary key so the batch windows are stable. An unsorted
        /// `Results` has no defined order, which would make paging by index
        /// liable to skip or repeat rows.
        let games = realm.objects(PVGame.self).sorted(byKeyPath: "md5Hash", ascending: true)
        let total = games.count

        guard total > 0 else {
            WLOG("Spotlight: No games found to index")
            return
        }

        ILOG("Spotlight: Found \(total) games to index (batches of \(IndexRequestHandler.indexBatchSize))")

        var start = 0
        while start < total {
            let end = min(start + IndexRequestHandler.indexBatchSize, total)
            autoreleasepool {
                /// Freeze only this slice — never the whole table. The explicit
                /// type pins `Sequence.map` on the `Results` slice.
                let batch: [PVGame] = games[start..<end].map { $0.freeze() }
                runMarker.checkpoint("reindex-all[\(end)/\(total)]")
                indexGames(batch)
            }
            start = end
        }
    }

    /// Get games matching specific identifiers
    private func getGames(withIdentifiers identifiers: [String]) throws -> [PVGame] {
        let realm = try openRealm()

        // Identifiers are in the format "org.provenance-emu.game.MD5HASH" — extract just the MD5
        let md5Hashes = identifiers.compactMap { id -> String? in
            guard id.hasPrefix("org.provenance-emu.game.") else { return nil }
            return String(id.dropFirst("org.provenance-emu.game.".count)).uppercased()
        }

        guard !md5Hashes.isEmpty else { return [] }

        let predicate = NSPredicate(format: "md5Hash IN %@", md5Hashes)
        return realm.objects(PVGame.self).filter(predicate).map { $0.freeze() }
    }
    
    public override init() {
        super.init()

        /// No run marker here: `init` no longer opens Realm (see below), so
        /// there is nothing left that can die. The marker brackets the reindex
        /// entry points, which are where the memory-heavy work now lives.
        if useMockData {
            // Initialize mock driver
            ILOG("Spotlight: Using mock data driver for testing")
            mockDriver = MockSpotlightDataDriver()
            Task {
                do {
                    try await mockDriver?.initialize()
                    ILOG("Spotlight: Mock driver initialized successfully")
                } catch {
                    ELOG("Spotlight: Error initializing mock driver: \(error)")
                }
            }
        } else {
            /// Deliberately does NOT touch `RomDatabase.sharedInstance` here.
            ///
            /// The previous code opened the full Realm in `init()` wrapped in a
            /// `do/catch`, but `RomDatabase.realm` is a non-throwing property, so
            /// the `catch` was unreachable dead code — a Realm open failure was
            /// always a hard crash, never the graceful degradation it looked
            /// like. Opening it eagerly also paid the memory cost on every
            /// invocation, including the many that only need `fileURL(for:)`.
            /// The database is now opened lazily by whichever entry point
            /// actually needs it.
            ILOG("Spotlight: Ready (Realm opened lazily per request)")
        }
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing all searchable items")
        
        if useMockData, let mockDriver = mockDriver {
            do {
                // Get all games from mock driver
                let allGames = try mockDriver.getAllGames()
                
                if allGames.isEmpty {
                    WLOG("Spotlight: No mock games found to index")
                } else {
                    ILOG("Spotlight: Found \(allGames.count) mock games to index")
                    indexGames(allGames)
                }
            } catch {
                ELOG("Spotlight: Error getting mock games: \(error)")
            }
            
            acknowledgementHandler()
        } else if RealmConfiguration.supportsAppGroups {
            /// Full-library reindex is the heaviest thing this extension does and
            /// the most likely point of a memory-limit kill.
            runMarker.begin(phase: "reindex-all")
            Task {
                /// Cleared in the acknowledgement path, not `deinit` — extensions
                /// are killed rather than deallocated.
                defer { runMarker.finish() }
                do {
                    try indexAllGamesInBatches()
                } catch {
                    ELOG("Spotlight: Error getting games: \(error)")
                }

                // Always call the acknowledgement handler
                acknowledgementHandler()
            }
        } else {
            WLOG("Spotlight: App Groups not setup, cannot reindex all items")
            acknowledgementHandler()
        }
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing items with identifiers: \(identifiers)")
        
        if useMockData, let mockDriver = mockDriver {
            do {
                // Get matching games from mock driver
                let matchingGames = try mockDriver.getGames(withIdentifiers: identifiers)
                
                if matchingGames.isEmpty {
                    WLOG("Spotlight: No matching mock games found for identifiers")
                } else {
                    ILOG("Spotlight: Found \(matchingGames.count) matching mock games to reindex")
                    indexGames(matchingGames)
                }
            } catch {
                ELOG("Spotlight: Error getting mock games with identifiers: \(error)")
            }
            
            acknowledgementHandler()
        } else if RealmConfiguration.supportsAppGroups {
            runMarker.begin(phase: "reindex-identifiers")
            Task {
                defer { runMarker.finish() }
                do {
                    // Get specific games using the shared RomDatabase instance
                    let games = try getGames(withIdentifiers: identifiers)

                    if games.isEmpty {
                        WLOG("Spotlight: No matching games found for identifiers")
                    } else {
                        ILOG("Spotlight: Found \(games.count) matching games to reindex")
                        indexGames(games)
                    }
                } catch {
                    ELOG("Spotlight: Error getting games with identifiers: \(error)")
                }

                // Always call the acknowledgement handler
                acknowledgementHandler()
            }
        } else {
            WLOG("Spotlight: App Groups not setup, cannot reindex")
            acknowledgementHandler()
        }
    }
    
    public override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data {
        /// This method is called when Spotlight needs data for a particular item
        ILOG("Spotlight: Request for data with itemIdentifier: \(itemIdentifier), typeIdentifier: \(typeIdentifier)")
        
        if !RealmConfiguration.supportsAppGroups {
            ELOG("Spotlight: App Groups not supported")
            throw SpotlightError.appGroupsNotSupported
        }
        
        if typeIdentifier == (kUTTypeImage as String) {
            do {
                let url = try fileURL(for: searchableIndex, itemIdentifier: itemIdentifier, typeIdentifier: typeIdentifier, inPlace: true)
                ILOG("Spotlight: Returning image data from URL: \(url.path)")
                return try Data(contentsOf: url)
            } catch {
                ELOG("Spotlight: Error getting image data: \(error)")
                throw error
            }
        } else {
            WLOG("Spotlight: Unsupported type identifier: \(typeIdentifier)")
            throw SpotlightError.dontHandleDatatype
        }
    }
    
    public override func fileURL(for _: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace _: Bool) throws -> URL {
        ILOG("Spotlight: Request for fileURL with itemIdentifier: \(itemIdentifier), typeIdentifier: \(typeIdentifier)")
        
        // We're assuming the typeIndentifier is the game one since that's all we've been using so far
        if typeIdentifier == UTType.rom.identifier {
            // Extract MD5 hash from the identifier (format: org.provenance-emu.game.MD5HASH)
            let md5 = itemIdentifier.components(separatedBy: ".").last ?? ""
            
            if useMockData, let mockDriver = mockDriver {
                // Use mock driver to get the game
                if let game = try mockDriver.getGame(byMD5: md5) {
                    // For mock games, we don't have real artwork URLs, so return a placeholder
                    ILOG("Spotlight: Using mock artwork for game with md5: \(md5)")
                    
                    // Create a temporary URL for testing
                    let tempDir = FileManager.default.temporaryDirectory
                    let artworkURL = tempDir.appendingPathComponent("\(game.title).png")
                    
                    // If the file doesn't exist, create a simple placeholder
                    if !FileManager.default.fileExists(atPath: artworkURL.path) {
                        // Create a simple placeholder image
                        let placeholderText = "Mock Artwork for \(game.title)"
                        let placeholderData = placeholderText.data(using: .utf8)
                        try? placeholderData?.write(to: artworkURL)
                    }
                    
                    return artworkURL
                } else {
                    WLOG("Spotlight: No mock game found with md5: \(md5)")
                    throw SpotlightError.notFound
                }
            } else {
                if !RealmConfiguration.supportsAppGroups {
                    ELOG("Spotlight: App Groups not supported")
                    throw SpotlightError.appGroupsNotSupported
                }
                
                // Synchronous method — open the shared library Realm directly.
                // Previously this used a bare `try Realm()`, which resolves to
                // `Realm.Configuration.defaultConfiguration`; nothing in this
                // extension ever calls `setDefaultRealmConfig()`, so that opened
                // an empty per-extension database instead of the App Group one.
                let realm = try openRealm()
                let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())

                // Only return a local file URL — remote URLs would trigger a
                // synchronous network request inside the extension which is
                // disallowed and causes timeouts.
                if let game = game,
                   let artworkURL = game.pathOfCachedImage,
                   artworkURL.isFileURL {
                    ILOG("Spotlight: Found local artwork for game with md5: \(md5)")
                    return artworkURL
                } else {
                    WLOG("Spotlight: No local artwork found for game with md5: \(md5)")
                    throw SpotlightError.notFound
                }
            }
        } else {
            WLOG("Spotlight: Unsupported type identifier: \(typeIdentifier)")
            throw SpotlightError.dontHandleDatatype
        }
    }
    
    private func indexGames(_ games: [PVGame]) {
        ILOG("Spotlight: Indexing \(games.count) games")
        
        let items: [CSSearchableItem] = games.compactMap({ (game) -> CSSearchableItem? in
            if !game.md5Hash.isEmpty {
                let uniqueIdentifier = "org.provenance-emu.game.\(game.md5Hash)"
                let attributeSet = game.spotlightContentSet
                
                // Add additional keywords for better searchability
                if var keywordsArray = attributeSet.keywords {
                    if let systemName = game.system?.name, !keywordsArray.contains(systemName) {
                        keywordsArray.append(systemName)
                    }
                    if let manufacturer = game.system?.manufacturer, !keywordsArray.contains(manufacturer) {
                        keywordsArray.append(manufacturer)
                    }
                    attributeSet.keywords = keywordsArray
                }
                
                // Make sure the items can appear in Siri suggestions
                attributeSet.domainIdentifier = self.domainIdentifier
                
                /// Per-game logging at info level buffers one entry per game in a
                /// memory-capped process — debug level keeps it off the hot path.
                DLOG("Spotlight: Created searchable item for \(game.title)")
                return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: self.domainIdentifier, attributeSet: attributeSet)
            } else {
                WLOG("Spotlight: Skipping game with empty md5Hash: \(game.title)")
                return nil
            }
        })
        
        if items.isEmpty {
            WLOG("Spotlight: No valid items to index")
            return
        }
        
        ILOG("Spotlight: Indexing \(items.count) searchable items")
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                ELOG("Spotlight: Indexing error: \(error)")
            } else {
                ILOG("Spotlight: Successfully indexed \(items.count) items")
            }
        }
    }
}
