//
//  GameSyncValidator.swift
//  PVLibrary
//
//  Created on 2025-01-XX.
//

import Foundation
import CloudKit
import PVLogging
import PVRealm
import PVSupport
import PVFileSystem

/// Validates game file availability and handles syncing before launch
public actor GameSyncValidator {

    public enum ValidationResult: Equatable {
        case ready
        case needsDownload
        case needsUpload
        case error(String)

        public static func == (lhs: ValidationResult, rhs: ValidationResult) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready), (.needsDownload, .needsDownload), (.needsUpload, .needsUpload):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }

    private let cloudSyncManager: CloudSyncManager
    private let fileManager = FileManager.default

    public init(cloudSyncManager: CloudSyncManager) {
        self.cloudSyncManager = cloudSyncManager
    }

    /// Validates that a game is ready to launch, downloading if necessary
    /// - Parameters:
    ///   - game: The game to validate
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Validation result indicating readiness or what action is needed
    public func validateGameReady(_ game: PVGame, progressHandler: ((String) -> Void)? = nil) async -> ValidationResult {
        let safeGame: PVGame = await MainActor.run {
            if game.isFrozen {
                return game
            } else if game.realm != nil {
                return game.freeze()
            } else {
                return game
            }
        }

        progressHandler?("Checking local file...")

        // 1. Check if file exists locally (handling missing PVFile entries)
        let localURL = safeGame.file?.url
        var fileExists = localURL.map { fileManager.fileExists(atPath: $0.path) } ?? false

        // 2. If file doesn't exist at PVFile path, check expected path (race condition fix)
        if !fileExists {
            let foundAtExpectedPath = await checkAndUpdateExpectedPath(game: safeGame, progressHandler: progressHandler)
            if foundAtExpectedPath {
                fileExists = true
            }
        }

        // 3. If file exists, verify it's readable
        if fileExists {
            // Re-check the URL in case it was updated
            let refreshedGame = RomDatabase.sharedInstance.game(withMD5: safeGame.md5Hash) ?? safeGame
            let currentURL = refreshedGame.file?.url ?? localURL

            var isDirectory: ObjCBool = false
            if let fileURL = currentURL,
               fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                // File exists and is valid - ready to launch
                return .ready
            }
        }

        // 4. File doesn't exist - check if we can download it
        guard Defaults[.iCloudSync] else {
            return .error("Game file not found and iCloud sync is disabled")
        }

        // 5. Check if game has cloud record
        let md5 = safeGame.md5Hash
        guard !md5.isEmpty else {
            return .error("Game missing MD5 hash - cannot sync")
        }

        // 6. Try to download the game
        return await downloadAndValidateGame(game: safeGame, md5: md5, progressHandler: progressHandler)
    }

    /// Checks if file exists at expected path and updates database if found
    /// This fixes race conditions where CloudKit creates PVGame before local scan completes
    /// - Parameters:
    ///   - game: The game to check
    ///   - progressHandler: Optional progress callback
    /// - Returns: True if file was found at expected path
    private func checkAndUpdateExpectedPath(game: PVGame, progressHandler: ((String) -> Void)? = nil) async -> Bool {
        guard let systemIdentifier = game.system?.identifier else {
            return false
        }

        progressHandler?("Checking expected path...")

        // Calculate expected path
        let systemRomsPath = Paths.romsPath(forSystemIdentifier: systemIdentifier)

        // Try multiple filename sources
        let possibleFilenames: [String] = [
            game.file?.fileName,
            game.romPath.isEmpty ? nil : URL(fileURLWithPath: game.romPath).lastPathComponent
        ].compactMap { $0 }.filter { !$0.isEmpty }

        for filename in possibleFilenames {
            let expectedPath = systemRomsPath.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: expectedPath.path) {
                ILOG("[SYNC VALIDATOR] Found ROM at expected path: \(expectedPath.path) for game: \(game.title)")

                // Update database with found file
                await MainActor.run {
                    let realm = RomDatabase.sharedInstance.realm
                    let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash)

                    do {
                        try realm.write {
                            if let liveGame = liveGame {
                                if liveGame.file == nil {
                                    let pvFile = PVFile(withURL: expectedPath)
                                    liveGame.file = pvFile
                                } else if let existingFile = liveGame.file {
                                    let relativePath = "\(systemIdentifier)/\(filename)"
                                    if existingFile.partialPath != relativePath {
                                        existingFile.partialPath = relativePath
                                    }
                                }
                                liveGame.isDownloaded = true
                            }
                        }
                        ILOG("[SYNC VALIDATOR] Updated database for game: \(game.title)")
                    } catch {
                        ELOG("[SYNC VALIDATOR] Failed to update database: \(error.localizedDescription)")
                    }
                }

                return true
            }
        }

        return false
    }

    /// Downloads a game and validates it's ready
    /// - Parameters:
    ///   - game: The game to download
    ///   - md5: The game's MD5 hash
    ///   - progressHandler: Optional callback for progress updates
    private func downloadAndValidateGame(game: PVGame, md5: String, progressHandler: ((String) -> Void)? = nil) async -> ValidationResult {
        guard let romsSyncer = cloudSyncManager.romsSyncer else {
            return .error("Cloud sync syncer not available")
        }

        // Check if record exists in cloud
        progressHandler?("Checking iCloud...")
        let cloudStatus = await checkCloudRecordExists(game: game, syncer: romsSyncer)

        switch cloudStatus {
        case .notFound:
            if game.isDownloaded {
                return .needsUpload
            }
            return .error("Game file not found and no cloud record exists")
        case .networkError(let message):
            return .error(message)
        case .exists:
            break
        }

        // Record exists - download it with progress
        do {
            ILOG("Downloading game \(game.title) from cloud before launch...")

            // Use CloudKitRomsSyncer's progress-enabled download if available
            if let cloudKitSyncer = romsSyncer as? CloudKitRomsSyncer {
                try await cloudKitSyncer.downloadGame(md5: md5) { progress, status in
                    progressHandler?(status)
                }
            } else {
                progressHandler?("Downloading...")
                try await romsSyncer.downloadGame(md5: md5)
            }

            // Verify file exists after download
            progressHandler?("Verifying download...")
            let refreshedGame = RomDatabase.sharedInstance.game(withMD5: md5) ?? game
            guard let refreshedURL = refreshedGame.file?.url,
                  fileManager.fileExists(atPath: refreshedURL.path) else {
                return .error("Download completed but file not found at expected location")
            }

            ILOG("Successfully downloaded and validated game \(game.title)")
            return .ready
        } catch {
            ELOG("Failed to download game \(game.title): \(error.localizedDescription)")
            return .error("Download failed: \(error.localizedDescription)")
        }
    }

    /// Result of cloud record check
    private enum CloudRecordStatus {
        case exists
        case notFound
        case networkError(String)
    }

    /// Checks if a cloud record exists for the game
    private func checkCloudRecordExists(game: PVGame, syncer: RomsSyncing) async -> CloudRecordStatus {
        guard let cloudKitSyncer = syncer as? CloudKitRomsSyncer else {
            // For non-CloudKit syncers, assume record exists if sync is enabled
            return Defaults[.iCloudSync] ? .exists : .notFound
        }

        if !game.hasCloudAssets {
            return .notFound
        }

        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: game.md5Hash)
        do {
            let record = try await cloudKitSyncer.fetchRecord(recordID: recordID)
            return record != nil ? .exists : .notFound
        } catch {
            if let ckError = error as? CKError {
                switch ckError.code {
                case .unknownItem:
                    return .notFound
                case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
                    WLOG("Network error checking cloud record: \(ckError.localizedDescription)")
                    return .networkError("iCloud is temporarily unavailable. Check your network connection.")
                default:
                    break
                }
            }
            WLOG("Error checking cloud record: \(error.localizedDescription)")
            return .networkError("Could not check iCloud: \(error.localizedDescription)")
        }
    }

    /// Ensures a game is ready for launch, showing progress if needed
    /// - Parameters:
    ///   - game: The game to prepare
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: True if ready, false if failed
    public func ensureGameReady(
        _ game: PVGame,
        progressCallback: ((String) -> Void)? = nil
    ) async -> Bool {
        progressCallback?("Checking game file...")

        let result = await validateGameReady(game, progressHandler: progressCallback)

        switch result {
        case .ready:
            progressCallback?("Game ready!")
            return true

        case .needsDownload:
            progressCallback?("Downloading from iCloud...")
            // Retry validation which will trigger download with progress
            let retryResult = await validateGameReady(game, progressHandler: progressCallback)
            switch retryResult {
            case .ready:
                progressCallback?("Download complete!")
                return true
            default:
                return false
            }

        case .needsUpload:
            progressCallback?("Uploading to iCloud...")
            // Try to upload if possible
            do {
                let liveGame = game.thaw() ?? game
                try await cloudSyncManager.uploadROM(for: liveGame)
                // Verify file exists after upload attempt
                return await validateGameReady(game, progressHandler: progressCallback) == .ready
            } catch {
                ELOG("Failed to upload game: \(error.localizedDescription)")
                return false
            }

        case .error(let message):
            ELOG("Game validation error: \(message)")
            progressCallback?("Error: \(message)")
            return false
        }
    }
}
