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
    /// - Parameter game: The game to validate
    /// - Returns: Validation result indicating readiness or what action is needed
    public func validateGameReady(_ game: PVGame) async -> ValidationResult {
        // 1. Check if file exists locally
        guard let fileURL = game.file?.url else {
            return .error("Game file URL is missing")
        }

        let fileExists = fileManager.fileExists(atPath: fileURL.path)

        // 2. If file exists, verify it's readable
        if fileExists {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return .error("Game file path points to a directory")
            }

            // File exists and is valid - ready to launch
            return .ready
        }

        // 3. File doesn't exist - check if we can download it
        guard Defaults[.iCloudSync] else {
            return .error("Game file not found and iCloud sync is disabled")
        }

        // 4. Check if game has cloud record
        let md5 = game.md5Hash
        guard !md5.isEmpty else {
            return .error("Game missing MD5 hash - cannot sync")
        }

        // 5. Try to download the game
        return await downloadAndValidateGame(game: game, md5: md5)
    }

    /// Downloads a game and validates it's ready
    private func downloadAndValidateGame(game: PVGame, md5: String) async -> ValidationResult {
        guard let romsSyncer = cloudSyncManager.romsSyncer else {
            return .error("Cloud sync syncer not available")
        }

        // Check if record exists in cloud
        let hasCloudRecord = await checkCloudRecordExists(md5: md5, syncer: romsSyncer)

        if !hasCloudRecord {
            // No cloud record - check if we should upload local file (if it was moved/deleted)
            if game.isDownloaded {
                // Game was marked as downloaded but file is missing
                // Try to upload if we have the file somewhere
                return .needsUpload
            }
            return .error("Game file not found and no cloud record exists")
        }

        // Record exists - download it
        do {
            ILOG("Downloading game \(game.title) from cloud before launch...")
            try await romsSyncer.downloadGame(md5: md5)

            // Verify file exists after download
            guard let fileURL = game.file?.url,
                  fileManager.fileExists(atPath: fileURL.path) else {
                return .error("Download completed but file not found at expected location")
            }

            ILOG("Successfully downloaded and validated game \(game.title)")
            return .ready
        } catch {
            ELOG("Failed to download game \(game.title): \(error.localizedDescription)")
            return .error("Download failed: \(error.localizedDescription)")
        }
    }

    /// Checks if a cloud record exists for the game
    private func checkCloudRecordExists(md5: String, syncer: RomsSyncing) async -> Bool {
        guard let cloudKitSyncer = syncer as? CloudKitRomsSyncer else {
            // For non-CloudKit syncers, assume record exists if sync is enabled
            return Defaults[.iCloudSync]
        }

        let recordID = CloudKitSchema.RecordIDGenerator.romRecordID(md5: md5)
        do {
            let record = try await cloudKitSyncer.fetchRecord(recordID: recordID)
            return record != nil
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return false
            }
            WLOG("Error checking cloud record: \(error.localizedDescription)")
            return false
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

        let result = await validateGameReady(game)

        switch result {
        case .ready:
            progressCallback?("Game ready")
            return true

        case .needsDownload:
            progressCallback?("Downloading from iCloud...")
            // Retry validation which will trigger download
            let retryResult = await validateGameReady(game)
            switch retryResult {
            case .ready:
                progressCallback?("Download complete")
                return true
            default:
                return false
            }

        case .needsUpload:
            progressCallback?("Uploading to iCloud...")
            // Try to upload if possible
            do {
                try await cloudSyncManager.uploadROM(for: game)
                // Verify file exists after upload attempt
                return await validateGameReady(game) == .ready
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
