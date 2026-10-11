//
//  PatchRepository.swift
//  PVLibrary
//
//  Created by Provenance Emu on 2026-10-10.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
import PVLogging
import PVPatching
import PVRealm
import PVFileSystem
import PVPrimitives

/// Owns patch import, matching, variant lifecycle, and launch preparation.
@MainActor
public final class PatchRepository {
    public static let shared = PatchRepository()

    private let inspector = PatchInspector()
    private let applier = PatchApplier()

    private init() {}

    // MARK: - Queries

    public func patches(forGameMD5 md5: String) -> Results<PVPatch> {
        RomDatabase.sharedInstance.realm.objects(PVPatch.self)
            .filter("baseGameMD5 == %@ OR game.md5Hash == %@", md5, md5)
            .sorted(byKeyPath: "date", ascending: false)
    }

    public func pendingPatches() -> Results<PVPatch> {
        RomDatabase.sharedInstance.realm.objects(PVPatch.self)
            .filter("matchState == %@", PVPatchMatchState.pending.rawValue)
            .sorted(byKeyPath: "date", ascending: false)
    }

    public func visibleLibraryGames(excludingHiddenVariants from: Results<PVGame>) -> Results<PVGame> {
        from.filter("isHiddenPatchVariant == false")
    }

    public func defaultPatch(forGameMD5 md5: String) -> PVPatch? {
        patches(forGameMD5: md5).first(where: { $0.isDefaultLaunch && !$0.isInvalidated })
    }

    // MARK: - Import

    /// Import a patch file already moved to `Paths.patchesPath`.
    @discardableResult
    public func importPatch(
        at url: URL,
        preferredGame: PVGame? = nil,
        autoMatch: Bool = true
    ) async throws -> PVPatch {
        guard let format = PatchFormat.detect(from: url) else {
            throw PatchError.unsupportedFormat(url.pathExtension)
        }

        let inspection = try inspector.inspect(patchURL: url)
        let database = RomDatabase.sharedInstance
        let realm = database.realm

        let pvFile = PVFile(withURL: url)
        let existingID = !pvFile.partialPath.isEmpty ? pvFile.partialPath : url.path
        let patch: PVPatch
        if let existing = realm.object(ofType: PVPatch.self, forPrimaryKey: existingID) {
            patch = existing
        } else {
            patch = PVPatch(
                file: pvFile,
                game: preferredGame,
                format: format,
                title: inspection.title ?? url.deletingPathExtension().lastPathComponent,
                author: inspection.author,
                version: inspection.version,
                patchDescription: inspection.patchDescription,
                matchState: preferredGame == nil ? .pending : .manual
            )
            try database.add(patch, update: true)
        }

        try database.writeTransaction {
            guard let live = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) else { return }
            live.formatRawValue = format.rawValue
            live.title = inspection.title ?? live.title
            live.author = inspection.author ?? live.author
            live.version = inspection.version ?? live.version
            live.patchDescription = inspection.patchDescription ?? live.patchDescription
            live.patchSHA256 = inspection.patchSHA256
            if let crc = inspection.sourceCRC32 {
                live.hasSourceCRC32 = true
                live.sourceCRC32 = Int(Int32(bitPattern: crc))
            }
            if live.outputStem == nil || live.outputStem?.isEmpty == true {
                live.outputStem = PatchApplier.defaultOutputStem(
                    romURL: preferredGame?.file?.url ?? url,
                    patchURL: url
                )
            }
            if let preferredGame {
                live.game = preferredGame.thaw() ?? preferredGame
                live.baseGameMD5 = preferredGame.md5Hash
                live.matchState = .manual
                live.matchConfidenceRaw = PatchMatchConfidence.exact.rawValue
                live.matchScore = 1
            }
        }

        if preferredGame == nil, autoMatch {
            _ = try await matchPatch(patch)
        } else if let preferredGame {
            _ = try await ensureVariant(for: patch, baseGame: preferredGame)
        }

        return realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) ?? patch
    }

    /// Attempt to auto-match a pending patch to a library ROM.
    @discardableResult
    public func matchPatch(_ patch: PVPatch) async throws -> PVGame? {
        let realm = RomDatabase.sharedInstance.realm
        guard let livePatch = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id),
              let patchURL = livePatch.file?.url else {
            return nil
        }

        let patchID = livePatch.id
        let needsSourceCRC = livePatch.hasSourceCRC32
        let patchFilename = patchURL.lastPathComponent

        // Snapshot lightweight game metadata on the main actor, then do any
        // disk CRC work off-main so large libraries can't stall the UI.
        struct GameSnapshot: Sendable {
            let md5: String
            let title: String
            let filename: String
            let storedCRC: String
            let filePath: String?
        }
        let snapshots: [GameSnapshot] = realm.objects(PVGame.self)
            .filter("isPatchVariant == false AND contentless == false")
            .compactMap { game in
                guard let filename = game.file?.fileName else { return nil }
                return GameSnapshot(
                    md5: game.md5Hash,
                    title: game.title,
                    filename: filename,
                    storedCRC: game.crc,
                    filePath: game.file?.url?.path
                )
            }

        let inspection = try await Task.detached(priority: .userInitiated) {
            try PatchInspector().inspect(patchURL: patchURL)
        }.value

        let candidates: [PatchMatchCandidate] = await Task.detached(priority: .userInitiated) {
            snapshots.map { snap in
                var crc: UInt32?
                if !snap.storedCRC.isEmpty, let value = UInt32(snap.storedCRC, radix: 16) {
                    crc = value
                } else if needsSourceCRC, let path = snap.filePath,
                          let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                    crc = patchCRC32(data)
                }
                return PatchMatchCandidate(
                    id: snap.md5,
                    title: snap.title,
                    md5: snap.md5,
                    crc32: crc,
                    filename: snap.filename,
                    confidence: .none,
                    score: 0
                )
            }
        }.value

        let ranked = inspector.rank(
            candidates: candidates,
            inspection: inspection,
            patchFilename: patchFilename
        )
        guard let best = inspector.unambiguousMatch(from: ranked),
              let game = realm.object(ofType: PVGame.self, forPrimaryKey: best.md5) else {
            try RomDatabase.sharedInstance.writeTransaction {
                guard let p = realm.object(ofType: PVPatch.self, forPrimaryKey: patchID) else { return }
                p.matchState = .pending
                if let top = ranked.first {
                    p.matchConfidenceRaw = top.confidence.rawValue
                    p.matchScore = top.score
                }
            }
            return nil
        }

        try RomDatabase.sharedInstance.writeTransaction {
            guard let p = realm.object(ofType: PVPatch.self, forPrimaryKey: patchID) else { return }
            p.game = game
            p.baseGameMD5 = game.md5Hash
            p.matchState = .matched
            p.matchConfidenceRaw = best.confidence.rawValue
            p.matchScore = best.score
            p.title = p.title ?? inspection.title
            p.author = p.author ?? inspection.author
            p.version = p.version ?? inspection.version
            p.patchDescription = p.patchDescription ?? inspection.patchDescription
        }

        guard let refreshed = realm.object(ofType: PVPatch.self, forPrimaryKey: patchID) else { return game }
        _ = try await ensureVariant(for: refreshed, baseGame: game)
        return game
    }

    /// Rematch every pending patch — call after a new ROM import.
    public func rematchPendingPatches() async {
        let pending = Array(pendingPatches().freeze())
        for patch in pending {
            do {
                _ = try await matchPatch(patch)
            } catch {
                WLOG("Failed to rematch patch \(patch.id): \(error.localizedDescription)")
            }
        }
    }

    /// Manually link a patch to a base game.
    public func link(_ patch: PVPatch, to game: PVGame) async throws {
        let realm = RomDatabase.sharedInstance.realm
        try RomDatabase.sharedInstance.writeTransaction {
            guard let p = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id),
                  let g = game.thaw() ?? realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) else { return }
            p.game = g
            p.baseGameMD5 = g.md5Hash
            p.matchState = .manual
            p.matchConfidenceRaw = PatchMatchConfidence.exact.rawValue
            p.matchScore = 1
        }
        _ = try await ensureVariant(for: patch, baseGame: game)
    }

    // MARK: - Variant lifecycle

    /// Ensure a hidden/visible variant `PVGame` exists for the patch.
    @discardableResult
    public func ensureVariant(for patch: PVPatch, baseGame: PVGame) async throws -> PVGame {
        let realm = RomDatabase.sharedInstance.realm
        if let existingMD5 = patch.variantGameMD5,
           let existing = realm.object(ofType: PVGame.self, forPrimaryKey: existingMD5),
           let existingURL = existing.file?.url,
           FileManager.default.fileExists(atPath: existingURL.path) {
            // Reuse only when the on-disk artifact (or standalone ROM) is still present.
            return existing
        }

        guard let patchURL = patch.file?.url, let romURL = baseGame.file?.url else {
            throw PatchError.sourceROMNotFound(baseGame.file?.url ?? URL(fileURLWithPath: "/"))
        }

        let stem = patch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL)
        let artifact = try await applier.apply(patchURL: patchURL, to: romURL, outputStem: stem)
        let variantMD5 = artifact.patchedMD5
        let patchedCRC: String = {
            if let data = try? Data(contentsOf: artifact.url, options: .mappedIfSafe) {
                return String(format: "%08X", patchCRC32(data))
            }
            return ""
        }()

        var result: PVGame?
        try RomDatabase.sharedInstance.writeTransaction {
            let livePatch = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id)
            let liveBase = baseGame.thaw() ?? realm.object(ofType: PVGame.self, forPrimaryKey: baseGame.md5Hash)

            if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: variantMD5) {
                livePatch?.variantGame = existing
                livePatch?.variantGameMD5 = variantMD5
                livePatch?.sourceSHA256 = artifact.sourceSHA256
                livePatch?.outputStem = artifact.outputStem
                if existing.isPatchVariant || existing.patchID == livePatch?.id {
                    // Our managed variant — refresh metadata / file pointer.
                    existing.isPatchVariant = true
                    existing.isHiddenPatchVariant = !(livePatch?.showAsLibraryTile ?? false)
                    existing.baseGameMD5 = liveBase?.md5Hash
                    existing.patchID = livePatch?.id
                    existing.file = Self.makeVariantFile(for: artifact.url)
                    existing.romPath = artifact.url.lastPathComponent
                    existing.isDownloaded = true
                }
                // Else: a standalone library ROM already has this content hash.
                // Link the patch to it for launch, but do not absorb / re-flag it.
                result = existing
                return
            }

            let variant = PVGame()
            variant.md5Hash = variantMD5
            variant.title = "\(liveBase?.title ?? "Game") — \(livePatch?.displayTitle ?? "Patch")"
            variant.systemIdentifier = liveBase?.systemIdentifier ?? ""
            variant.system = liveBase?.system
            variant.isPatchVariant = true
            variant.isHiddenPatchVariant = !(livePatch?.showAsLibraryTile ?? false)
            variant.baseGameMD5 = liveBase?.md5Hash
            variant.patchID = livePatch?.id
            variant.originalArtworkURL = liveBase?.originalArtworkURL ?? ""
            variant.customArtworkURL = liveBase?.customArtworkURL ?? ""
            variant.userPreferredCoreID = liveBase?.userPreferredCoreID
            variant.isDownloaded = true
            variant.file = Self.makeVariantFile(for: artifact.url)
            variant.romPath = artifact.url.lastPathComponent
            variant.crc = patchedCRC

            realm.add(variant, update: .modified)
            livePatch?.variantGame = variant
            livePatch?.variantGameMD5 = variantMD5
            livePatch?.sourceSHA256 = artifact.sourceSHA256
            livePatch?.outputStem = artifact.outputStem
            livePatch?.baseGameMD5 = liveBase?.md5Hash
            livePatch?.game = liveBase
            result = variant
        }
        guard let result else {
            throw PatchError.patchApplicationFailed("Failed to persist patch variant")
        }
        return result
    }

    public func setShowAsLibraryTile(_ show: Bool, for patch: PVPatch) throws {
        let realm = RomDatabase.sharedInstance.realm
        try RomDatabase.sharedInstance.writeTransaction {
            guard let p = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) else { return }
            p.showAsLibraryTile = show
            if let variant = p.variantGame {
                variant.isHiddenPatchVariant = !show
            }
        }
    }

    public func setDefaultLaunch(_ enabled: Bool, for patch: PVPatch) throws {
        let realm = RomDatabase.sharedInstance.realm
        try RomDatabase.sharedInstance.writeTransaction {
            guard let p = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) else { return }
            if enabled, let md5 = p.baseGameMD5 {
                realm.objects(PVPatch.self)
                    .filter("baseGameMD5 == %@ AND isDefaultLaunch == true", md5)
                    .forEach {
                        $0.isDefaultLaunch = false
                        $0.isEnabled = false
                    }
            }
            p.isDefaultLaunch = enabled
            p.isEnabled = enabled
        }
    }

    // MARK: - Launch preparation

    /// Prepare a patched variant for launch and return it.
    public func prepareForLaunch(
        patch: PVPatch,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> PVGame {
        let realm = RomDatabase.sharedInstance.realm
        guard let livePatch = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) else {
            throw PatchError.patchFileNotFound(URL(fileURLWithPath: "/"))
        }
        guard let baseMD5 = livePatch.baseGameMD5 ?? livePatch.game?.md5Hash,
              let baseGame = realm.object(ofType: PVGame.self, forPrimaryKey: baseMD5) else {
            throw PatchError.sourceROMMismatch
        }
        guard let patchURL = livePatch.file?.url, let romURL = baseGame.file?.url else {
            throw PatchError.sourceROMNotFound(baseGame.file?.url ?? URL(fileURLWithPath: "/"))
        }

        let stem = livePatch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL)
        let artifact = try await applier.apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: stem,
            progress: progress
        )

        var result: PVGame?
        try RomDatabase.sharedInstance.writeTransaction {
            let p = livePatch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: livePatch.id)
            let base = baseGame.thaw() ?? realm.object(ofType: PVGame.self, forPrimaryKey: baseMD5)
            let variantMD5 = artifact.patchedMD5

            if let existing = realm.object(ofType: PVGame.self, forPrimaryKey: variantMD5) {
                p?.variantGame = existing
                p?.variantGameMD5 = variantMD5
                p?.sourceSHA256 = artifact.sourceSHA256
                p?.outputStem = artifact.outputStem
                if existing.isPatchVariant || existing.patchID == p?.id {
                    existing.file = Self.makeVariantFile(for: artifact.url)
                    existing.romPath = artifact.url.lastPathComponent
                    existing.isDownloaded = true
                    existing.isPatchVariant = true
                    existing.isHiddenPatchVariant = !(p?.showAsLibraryTile ?? false)
                    existing.baseGameMD5 = baseMD5
                    existing.patchID = p?.id
                }
                // Standalone ROM with matching content: launch as-is, don't absorb.
                result = existing
                return
            }

            let variant = PVGame()
            variant.md5Hash = variantMD5
            variant.title = "\(base?.title ?? "Game") — \(p?.displayTitle ?? "Patch")"
            variant.systemIdentifier = base?.systemIdentifier ?? ""
            variant.system = base?.system
            variant.isPatchVariant = true
            variant.isHiddenPatchVariant = !(p?.showAsLibraryTile ?? false)
            variant.baseGameMD5 = baseMD5
            variant.patchID = p?.id
            variant.originalArtworkURL = base?.originalArtworkURL ?? ""
            variant.customArtworkURL = base?.customArtworkURL ?? ""
            variant.userPreferredCoreID = base?.userPreferredCoreID
            variant.file = Self.makeVariantFile(for: artifact.url)
            variant.romPath = artifact.url.lastPathComponent
            variant.isDownloaded = true
            realm.add(variant, update: .modified)

            p?.variantGame = variant
            p?.variantGameMD5 = variantMD5
            p?.sourceSHA256 = artifact.sourceSHA256
            p?.outputStem = artifact.outputStem
            result = variant
        }
        guard let result else {
            throw PatchError.patchApplicationFailed("Failed to prepare patch variant for launch")
        }
        return result
    }

    /// Build a `PVFile` rooted at the platform documents/caches directory so
    /// `FileLocationResolver` can find patched artifacts under `PatchedROMs/`.
    private static func makeVariantFile(for artifactURL: URL) -> PVFile {
        PVFile(withURL: artifactURL, relativeRoot: .platformDefault)
    }

    /// Export a collision-safe patched ROM copy into Documents/PatchedROMs (or provided dir).
    public func exportPatchedCopy(
        patch: PVPatch,
        to directory: URL? = nil,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> URL {
        let realm = RomDatabase.sharedInstance.realm
        guard let livePatch = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id),
              let patchURL = livePatch.file?.url,
              let baseMD5 = livePatch.baseGameMD5 ?? livePatch.game?.md5Hash,
              let baseGame = realm.object(ofType: PVGame.self, forPrimaryKey: baseMD5),
              let romURL = baseGame.file?.url else {
            throw PatchError.sourceROMMismatch
        }
        let dest = directory ?? URL.documentsPath
            .appendingPathComponent("PatchedROMs", isDirectory: true)
        let preferred = "\(livePatch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL)).\(romURL.pathExtension)"
        return try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: dest,
            preferredName: preferred,
            progress: progress
        )
    }

    public func reapply(_ patch: PVPatch, progress: (@Sendable (PatchProgress) -> Void)? = nil) async throws -> PVGame {
        let realm = RomDatabase.sharedInstance.realm
        guard let livePatch = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id),
              let patchURL = livePatch.file?.url,
              let baseMD5 = livePatch.baseGameMD5 ?? livePatch.game?.md5Hash,
              let baseGame = realm.object(ofType: PVGame.self, forPrimaryKey: baseMD5),
              let romURL = baseGame.file?.url else {
            throw PatchError.sourceROMMismatch
        }
        try await applier.invalidateCache(patchURL: patchURL, romURL: romURL)
        return try await prepareForLaunch(patch: livePatch, progress: progress)
    }

    /// Whether deleting a patch should also remove the linked `PVGame`.
    /// Standalone same-MD5 library ROMs may be linked for launch but must not be deleted.
    public nonisolated static func shouldDeleteVariantGame(isPatchVariant: Bool?) -> Bool {
        isPatchVariant == true
    }

    /// Delete a patch and its managed variant/cache. Never deletes the original ROM
    /// or a standalone library game that happens to share the patched content hash.
    public func deletePatch(_ patch: PVPatch, deleteVariantSaves: Bool = true) throws {
        let realm = RomDatabase.sharedInstance.realm
        guard let live = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id) else { return }

        if let patchURL = live.file?.url,
           let baseMD5 = live.baseGameMD5 ?? live.game?.md5Hash,
           let base = realm.object(ofType: PVGame.self, forPrimaryKey: baseMD5),
           let romURL = base.file?.url {
            let applier = self.applier
            Task {
                try? await applier.invalidateCache(patchURL: patchURL, romURL: romURL)
            }
        }

        // Only remove PVGame rows we created as patch variants. A same-MD5 standalone
        // ROM may be linked for launch — never absorb or delete it here.
        let managedVariant = Self.shouldDeleteVariantGame(isPatchVariant: live.variantGame?.isPatchVariant)
            ? live.variantGame
            : nil
        let variantFileURL = managedVariant?.file?.url
        let patchFileURL = live.file?.url

        try RomDatabase.sharedInstance.writeTransaction {
            if let managedVariant, !managedVariant.isInvalidated {
                if deleteVariantSaves {
                    managedVariant.saveStates.forEach { realm.delete($0) }
                    managedVariant.cheats.forEach { realm.delete($0) }
                    managedVariant.recentPlays.forEach { realm.delete($0) }
                }
                realm.delete(managedVariant)
            }
            if !live.isInvalidated {
                realm.delete(live)
            }
        }

        if let patchFileURL, FileManager.default.fileExists(atPath: patchFileURL.path) {
            try? FileManager.default.removeItem(at: patchFileURL)
        }
        if let variantFileURL, FileManager.default.fileExists(atPath: variantFileURL.path) {
            let path = variantFileURL.path
            if path.contains("/PatchedROMs/") || path.contains("/PVPatchedROMs/") {
                try? FileManager.default.removeItem(at: variantFileURL)
            }
        }
    }

    /// Delete every patch / variant owned by a base game. Never deletes the base ROM itself.
    public func deletePatches(forBaseGameMD5 md5: String) throws {
        let owned = Array(patches(forGameMD5: md5).freeze())
        for patch in owned {
            try deletePatch(patch)
        }
    }
}

/// Local CRC32 for matching (mirrors PVPatching's internal `patchCRC32`).
private func patchCRC32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc >> 1) ^ (0xEDB8_8320 * (crc & 1))
        }
    }
    return ~crc
}
