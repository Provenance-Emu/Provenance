//
//  PatchReplacement.swift
//  PVLibrary
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVFileSystem

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

        public init(romURL: URL?, hasRelatedFiles: Bool, isDownloaded: Bool, cloudSyncEnabled: Bool) {
            self.romURL = romURL
            self.hasRelatedFiles = hasRelatedFiles
            self.isDownloaded = isDownloaded
            self.cloudSyncEnabled = cloudSyncEnabled
        }
    }

    /// Index files and set formats a single-file patch cannot replace.
    static let multiFileExtensions: Set<String> = Extensions.playlistExtensions.union(["gdi", "ccd"])

    /// Why the original cannot be replaced, or nil when it can.
    public static func blocker(for target: Target, fileManager: FileManager = .default) -> Blocker? {
        if target.cloudSyncEnabled { return .cloudSyncOn }
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
