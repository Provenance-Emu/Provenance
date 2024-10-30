//
//  DatabaseQueryError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import PVLogging
import PVRealm
import PVMediaCache
import Systems

// MARK: - ROM Lookup
public extension GameImporter {

    @discardableResult
    func lookupInfo(for game: PVGame, overwrite: Bool = true) throws -> PVGame {
        game.requiresSync = false

        // Handle MD5 calculation
        if game.md5Hash.isEmpty {
            let offset: UInt64 = game.systemIdentifier == "com.provenance.nes" ? 16 : 0
            let romFullPath = romsPath.appendingPathComponent(game.romPath).path

            guard let md5Hash = FileManager.default.md5ForFile(atPath: romFullPath, fromOffset: offset) else {
                throw GameImporterError.lookupFailed(.emptyMD5Hash)
            }
            game.md5Hash = md5Hash
        }

        guard !game.md5Hash.isEmpty else {
            throw GameImporterError.lookupFailed(.emptyMD5Hash)
        }

        // Try artwork cache first
        if let result = RomDatabase.getArtCache(game.md5Hash.uppercased(),
                                              systemIdentifier: game.systemIdentifier) {
            do {
                return updateGame(game, with: [result])
            } catch {
                throw GameImporterError.lookupFailed(.databaseError(error))
            }
        }

        // Try database search
        do {
            let results = try searchDatabase(usingKey: "romHashMD5",
                                           value: game.md5Hash.uppercased(),
                                           systemID: game.systemIdentifier)
            if let results = results, !results.isEmpty {
                return updateGame(game, with: results)
            }
            throw GameImporterError.lookupFailed(.cacheMiss("No results found for MD5 hash"))
        } catch let error as GameImporterError {
            throw error
        } catch {
            throw GameImporterError.lookupFailed(.databaseError(error))
        }
    }

    @discardableResult
    func getArtwork(forGame game: PVGame) async throws -> PVGame {
        var url = game.originalArtworkURL
        if url.isEmpty {
            throw GameImporterError.artworkImportFailed(.noMatchingGame(game.title))
        }

        if PVMediaCache.fileExists(forKey: url) {
            if let localURL = PVMediaCache.filePath(forKey: url) {
                let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
                game.originalArtworkFile = file
                return game
            }
        }

        DLOG("Starting Artwork download for \(url)")
        url = url.replacingOccurrences(of: "gamefaqs1.cbsistatic.com/box/",
                                     with: "gamefaqs.gamespot.com/a/box/")

        guard let artworkURL = URL(string: url) else {
            throw GameImporterError.artworkImportFailed(.invalidURL(url))
        }

        let request = URLRequest(url: artworkURL)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw GameImporterError.artworkImportFailed(.downloadFailed(artworkURL, URLError(.badServerResponse)))
            }

            #if os(macOS)
            guard let artwork = NSImage(data: data) else {
                throw GameImporterError.artworkImportFailed(.processingFailed(URLError(.cannotDecodeContentData)))
            }
            #elseif !os(watchOS)
            guard let artwork = UIImage(data: data) else {
                throw GameImporterError.artworkImportFailed(.processingFailed(URLError(.cannotDecodeContentData)))
            }
            #endif

            let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
            let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
            game.originalArtworkFile = file

            if let finishedArtworkHandler {
                await MainActor.run {
                    ILOG("Calling finishedArtworkHandler \(url)")
                    finishedArtworkHandler(url)
                }
            }

            return game
        } catch {
            throw GameImporterError.artworkImportFailed(.downloadFailed(artworkURL, error))
        }
    }

    func releaseID(forCRCs crcs: Set<String>) -> String? {
        return openVGDB.releaseID(forCRCs: crcs)
    }

    func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw GameImporterError.lookupFailed(.invalidSystemID(systemID))
        }

        do {
            let results = try openVGDB.searchDatabase(usingKey: key, value: value, systemID: systemIDInt)
            return results
        } catch {
            throw GameImporterError.lookupFailed(.databaseError(error))
        }
    }

    func searchDatabase(usingFilename filename: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw GameImporterError.lookupFailed(.invalidSystemID(systemID))
        }

        do {
            let results = try openVGDB.searchDatabase(usingFilename: filename, systemID: systemIDInt)
            return results
        } catch {
            throw GameImporterError.lookupFailed(.databaseError(error))
        }
    }

    func searchDatabase(usingFilename filename: String, systemIDs: [String]) throws -> [[String: NSObject]]? {
        let systemIDsInts: [Int] = systemIDs.compactMap { PVEmulatorConfiguration.databaseID(forSystemID: $0) }
        guard !systemIDsInts.isEmpty else {
            throw GameImporterError.lookupFailed(.invalidSystemID(systemIDs.joined(separator: ", ")))
        }

        do {
            let results = try openVGDB.searchDatabase(usingFilename: filename, systemIDs: systemIDsInts)
            return results
        } catch {
            throw GameImporterError.lookupFailed(.databaseError(error))
        }
    }

    static var charset: CharacterSet = {
        var c = CharacterSet.punctuationCharacters
        c.remove(charactersIn: ",-+&.'")
        return c
    }()

    private func updateGame(_ game: PVGame, with results: [[String: NSObject]]) throws -> PVGame {
        guard let result = results.first else {
            throw GameImporterError.lookupFailed(.cacheMiss("No results found"))
        }

        do {
            try database.writeTransaction {
                if let title = result["gameTitle"] as? String {
                    game.title = title
                }
                if let releaseDate = result["releaseDate"] as? String {
                    game.releaseDate = releaseDate
                }
                if let boxImageURL = result["boxImageURL"] as? String {
                    game.originalArtworkURL = boxImageURL
                }
            }
            return game
        } catch {
            throw GameImporterError.lookupFailed(.databaseError(error))
        }
    }
}
