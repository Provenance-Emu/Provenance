//
//  PatchReplacement.swift
//  PVLibrary
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
import PVRealm
import PVFileSystem
import PVLogging

/// The rules of "Replace the Original", the destructive placement: what blocks it, how strongly
/// the confirmation warns, the file swap, and carrying per-game settings to the new MD5.
public enum PatchReplacement {

    // MARK: - Risk

    /// How sure applying is that the result is what the patch author shipped. Every level may
    /// replace the original; the confirmation warns harder as it drops. (iCube refuses the last two.)
    public enum Risk: Equatable, Sendable {
        /// The patch checks the ROM it is applied to (BPS, UPS, PPF, xdelta).
        case verified
        /// The patch carries no checksum (IPS), so a wrong ROM goes unnoticed.
        case unverifiable
        /// "Apply anyway": the ROM is known not to be the one the patch was made for.
        case knownMismatch

        public static func assess(canVerifyIntegrity: Bool, applyingAnyway: Bool) -> Risk {
            if applyingAnyway { return .knownMismatch }
            return canVerifyIntegrity ? .verified : .unverifiable
        }
    }

    // MARK: - Blockers

    public enum Blocker: Error, Equatable, LocalizedError {
        case notALibraryGame
        case cloudSyncOn
        case inICloud
        case multiFileGame
        case archive
        case notDownloaded
        case fileMissing
        case gameRunning
        case patchAlreadyAttached
        case alreadyInLibrary(title: String)

        public var errorDescription: String? {
            switch self {
            case .notALibraryGame:
                return "Pick the game from your library to replace it. A ROM picked from Files can only be patched into a copy."
            case .cloudSyncOn:
                return "Replacing the original is off while iCloud Sync is on: your other devices would delete the game and its saves. Save a patched copy instead, or turn iCloud Sync off first."
            case .inICloud:
                return "This game has a copy in iCloud. Replacing it here would bring the old version back from iCloud as a second game sharing the file. Save a patched copy instead."
            case .multiFileGame:
                return "This game is made of several files, so a patch cannot replace it. Save a patched copy instead."
            case .archive:
                return "This game is stored in an archive, so a patch cannot replace it. Save a patched copy instead."
            case .notDownloaded:
                return "This game is not downloaded to this device yet."
            case .fileMissing:
                return "The game's file could not be found."
            case .gameRunning:
                return "Quit the game before replacing its file."
            case .patchAlreadyAttached:
                return "This patch is already in the game's Patches & Mods. Delete it there first, or keep playing it from there."
            case .alreadyInLibrary(let title):
                return "The patched game is already in your library as “\(title)”."
            }
        }
    }

    /// What the blocker check needs to know about the target game.
    public struct Target: Equatable, Sendable {
        public var romURL: URL?
        public var hasRelatedFiles: Bool
        public var isDownloaded: Bool
        public var cloudSyncEnabled: Bool
        /// The game was uploaded to iCloud once (`cloudRecordID` or `hasCloudAssets`).
        public var isInICloud: Bool

        public init(romURL: URL?, hasRelatedFiles: Bool, isDownloaded: Bool, cloudSyncEnabled: Bool, isInICloud: Bool = false) {
            self.romURL = romURL
            self.hasRelatedFiles = hasRelatedFiles
            self.isDownloaded = isDownloaded
            self.cloudSyncEnabled = cloudSyncEnabled
            self.isInICloud = isInICloud
        }
    }

    /// Index files and set formats a single-file patch cannot replace.
    static let multiFileExtensions: Set<String> = Extensions.playlistExtensions.union(["gdi", "ccd"])

    /// Why the original cannot be replaced, or nil when it can.
    public static func blocker(for target: Target, fileManager: FileManager = .default) -> Blocker? {
        if target.cloudSyncEnabled { return .cloudSyncOn }
        // Turning sync back on would recreate the old MD5's row from its record.
        if target.isInICloud { return .inICloud }
        guard let url = target.romURL else { return .fileMissing }
        let ext = url.pathExtension.lowercased()
        if target.hasRelatedFiles || multiFileExtensions.contains(ext) { return .multiFileGame }
        if Extensions.archiveExtensions.contains(ext) { return .archive }
        if !target.isDownloaded { return .notDownloaded }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return .fileMissing }
        if isDirectory.boolValue { return .multiFileGame }
        return nil
    }

    // MARK: - File swap

    /// The patched bytes are in place and the original waits beside them, hidden, until the
    /// database has moved the game to its new MD5.
    public struct PendingSwap: Sendable {
        public let original: URL
        public let backup: URL

        /// The database update succeeded: drop the original.
        public func commit() {
            try? FileManager.default.removeItem(atPath: backup.path)
        }

        /// The database update failed: put the original back.
        public func rollback() throws {
            _ = try FileManager.default.replaceItemAt(original, withItemAt: backup)
        }
    }

    /// Atomically puts a copy of `replacement` at `original`. The copy goes to a hidden sibling
    /// first (a clone on APFS), so a failure leaves the original untouched.
    public static func beginSwap(replacing original: URL, withContentsOf replacement: URL) throws -> PendingSwap {
        let fileManager = FileManager.default
        let directory = original.deletingLastPathComponent()
        let token = UUID().uuidString
        let staged = directory.appendingPathComponent(".\(original.lastPathComponent).patched-\(token)")
        let backupName = ".\(original.lastPathComponent).original-\(token)"
        try fileManager.copyItem(at: replacement, to: staged)
        do {
            _ = try fileManager.replaceItemAt(
                original,
                withItemAt: staged,
                backupItemName: backupName,
                options: .withoutDeletingBackupItem
            )
        } catch {
            try? fileManager.removeItem(atPath: staged.path)
            throw error
        }
        return PendingSwap(original: original, backup: directory.appendingPathComponent(backupName))
    }

    // MARK: - Database

    /// The game's library MD5 if its file were `url`: the importer's hash, which skips NES, Lynx,
    /// 7800 and SNES copier headers and normalises N64 byte order. `url` must resolve through
    /// `PVFile` (under Documents or Caches), as the patch cache does.
    public static func libraryMD5(ofFileAt url: URL, systemIdentifier: String) async -> String? {
        let probe = PVGame()
        probe.systemIdentifier = systemIdentifier
        probe.file = PVFile(withURL: url, relativeRoot: .platformDefault)
        return await GameImporterDatabaseService().calculateMD5(forGame: probe)?.uppercased()
    }

    /// Moves the game to its new MD5 once `swap` has put the patched bytes in place, then drops the
    /// original. Patches that were the game's default launch stop being it: the game now is what
    /// the player chose. On any failure the transaction is cancelled and the original restored.
    @discardableResult
    public static func commit(
        _ swap: PendingSwap,
        rekeying oldMD5: String,
        to newMD5: String,
        crc: String,
        fileSize: Int,
        showPatchedSeparately: Bool,
        in realm: Realm
    ) throws -> PVGame {
        do {
            realm.beginWrite()
            let game = try GameRekey.rekey(gameWithMD5: oldMD5, to: newMD5, crc: crc, fileSize: fileSize, in: realm)
            for patch in Array(game.patches) where patch.isDefaultLaunch {
                patch.isDefaultLaunch = false
                patch.isEnabled = false
                if let variant = patch.variantGame, variant.isPatchVariant {
                    variant.isHiddenPatchVariant = PatchRepository.isVariantHidden(
                        showAsLibraryTile: patch.showAsLibraryTile,
                        isDefaultLaunch: false,
                        showPatchedSeparately: showPatchedSeparately
                    )
                }
            }
            try realm.commitWrite()
            swap.commit()
            return game
        } catch {
            if realm.isInWriteTransaction { realm.cancelWrite() }
            do {
                try swap.rollback()
            } catch let rollbackError {
                ELOG("PatchReplacement: could not restore \(swap.original.lastPathComponent) from \(swap.backup.lastPathComponent): \(rollbackError)")
            }
            throw error
        }
    }

    // MARK: - Per-game settings

    /// Copies settings stored under the old MD5 to the new one: keys that contain it (core options,
    /// port devices, overrides) and dictionaries keyed by it (layout variants, JIT and light-gun
    /// preferences). The old entries stay. The case of each match is kept, since stores differ.
    /// JSON-encoded values (shader selections) are not rewritten.
    public static func copyPerGameSettings(fromMD5 oldMD5: String, toMD5 newMD5: String, in defaults: UserDefaults) {
        let pairs = [(oldMD5.uppercased(), newMD5.uppercased()), (oldMD5.lowercased(), newMD5.lowercased())]
        guard oldMD5.caseInsensitiveCompare(newMD5) != .orderedSame else { return }
        for (key, value) in defaults.dictionaryRepresentation() {
            for (from, to) in pairs where key.contains(from) {
                let newKey = key.replacingOccurrences(of: from, with: to)
                if defaults.object(forKey: newKey) == nil {
                    defaults.set(value, forKey: newKey)
                }
            }
            guard var dictionary = value as? [String: Any] else { continue }
            var changed = false
            for (from, to) in pairs {
                if let entry = dictionary[from], dictionary[to] == nil {
                    dictionary[to] = entry
                    changed = true
                }
            }
            if changed { defaults.set(dictionary, forKey: key) }
        }
    }
}
