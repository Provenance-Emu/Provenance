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
    ///
    /// The backup's name carries `newMD5`, the MD5 the game is about to be re-keyed to. If the app
    /// dies before the database update lands, `recoverInterruptedSwaps` reads it back to decide
    /// whether the file or the database moved.
    public static func beginSwap(replacing original: URL, withContentsOf replacement: URL, newMD5: String) throws -> PendingSwap {
        let fileManager = FileManager.default
        let directory = original.deletingLastPathComponent()
        let staged = directory.appendingPathComponent("\(stagedPrefix(for: original.lastPathComponent))\(UUID().uuidString)")
        let token = UUID().uuidString.prefix(backupTokenLength)
        let backupName = "\(backupPrefix(for: original.lastPathComponent))\(newMD5.uppercased())-\(token)"
        do {
            try fileManager.copyItem(at: replacement, to: staged)
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

    // MARK: - Recovery

    private static let backupTokenLength = 8
    private static let md5HexLength = 32

    private static func backupPrefix(for fileName: String) -> String { ".\(fileName).original-" }
    private static func stagedPrefix(for fileName: String) -> String { ".\(fileName).patched-" }

    /// `.<name>.original-<MD5>-<token>` -> (`<name>`, `<MD5>`).
    private static let backupPattern = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: "^\\.(.+)\\.original-([0-9A-Fa-f]{\(md5HexLength)})-[0-9A-Fa-f]{\(backupTokenLength)}$"
    )
    /// `.<name>.patched-<UUID>`.
    private static let stagedPattern = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: "^\\..+\\.patched-[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$"
    )

    private static func firstMatch(_ pattern: NSRegularExpression, in name: String) -> NSTextCheckingResult? {
        pattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name))
    }

    /// Finishes a Replace the Original the app was killed in the middle of. The swap and the
    /// database update are two steps, so a backup left beside its ROM means one of two things,
    /// told apart by the MD5 in its name:
    /// - the database already holds a game with that MD5: the update landed, the backup is spare;
    /// - it does not: the update never ran, so the ROM holds bytes the database does not know and
    ///   the original is put back.
    /// A half-copied `.patched-` file is dropped. Only hidden siblings with these exact names are
    /// touched, one directory level at a time. Returns how many files it restored or removed.
    @discardableResult
    public static func recoverInterruptedSwaps(in directories: [URL], realm: Realm, fileManager: FileManager = .default) -> Int {
        var handled = 0
        for directory in directories {
            let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
            for name in names where name.hasPrefix(".") {
                let url = directory.appendingPathComponent(name)
                if let match = firstMatch(backupPattern, in: name),
                   let nameRange = Range(match.range(at: 1), in: name),
                   let md5Range = Range(match.range(at: 2), in: name) {
                    let md5 = String(name[md5Range])
                    let target = directory.appendingPathComponent(String(name[nameRange]))
                    let landed = realm.objects(PVGame.self).filter("md5Hash ==[c] %@", md5).first != nil
                    if landed {
                        do {
                            try fileManager.removeItem(atPath: url.path)
                            ILOG("PatchReplacement: dropped the spare original \(name), the database already holds \(md5)")
                            handled += 1
                        } catch {
                            ELOG("PatchReplacement: could not drop \(name): \(error)")
                        }
                    } else {
                        do {
                            if fileManager.fileExists(atPath: target.path) {
                                _ = try fileManager.replaceItemAt(target, withItemAt: url)
                            } else {
                                try fileManager.moveItem(at: url, to: target)
                            }
                            ILOG("PatchReplacement: restored \(target.lastPathComponent) from an interrupted replacement, the database never moved to \(md5)")
                            handled += 1
                        } catch {
                            ELOG("PatchReplacement: could not restore \(target.lastPathComponent) from \(name): \(error)")
                        }
                    }
                } else if firstMatch(stagedPattern, in: name) != nil {
                    do {
                        try fileManager.removeItem(atPath: url.path)
                        ILOG("PatchReplacement: removed the unfinished copy \(name)")
                        handled += 1
                    } catch {
                        ELOG("PatchReplacement: could not remove \(name): \(error)")
                    }
                }
            }
        }
        return handled
    }

    /// `recoverInterruptedSwaps` over the ROMs folder and each system folder in it, against the
    /// library database. Meant for launch, after the database opens; call it off the main thread.
    @discardableResult
    public static func recoverInterruptedSwapsInLibrary() -> Int {
        let fileManager = FileManager.default
        let root = Paths.romsPath
        let children = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let systemFolders = children.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        guard let realm = try? Realm(configuration: RealmConfiguration.realmConfig) else {
            ELOG("PatchReplacement: could not open the database to recover interrupted replacements")
            return 0
        }
        return recoverInterruptedSwaps(in: [root] + systemFolders, realm: realm, fileManager: fileManager)
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
