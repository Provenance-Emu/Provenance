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
import PVArchiving
import PVSettings
import Defaults

/// Where a patch applied from the Patch Applier goes in the library. The same choice is offered
/// in iCube and iFly.
public enum PatchPlacement: String, Sendable, CaseIterable, Identifiable {
    /// The patched copy is a library entry of its own: listed under the base game's
    /// "Patches & Mods", and an item of its own in the grid when "Show patched versions as
    /// separate library items" is on.
    case newLibraryEntry
    /// The patched copy takes the original's place: the base game's entry launches it and it gets
    /// no entry of its own. The original ROM file is kept and stays playable from "Play Original".
    /// (iCube's "Replace the Original" deletes the original; doing that here needs the base game's
    /// MD5 identity re-keyed, so the UI calls this "Use instead of the original".)
    case replaceOriginal

    public var id: String { rawValue }
}

/// Owns patch import, matching, variant lifecycle, and launch preparation.
@MainActor
// swiftlint:disable:next type_body_length
public final class PatchRepository {
    public static let shared = PatchRepository()

    private let inspector = PatchInspector()
    private let applier = PatchApplier()

    private var settingsObservation: Task<Void, Never>?

    private init() {}

    // MARK: - Settings

    /// Applies "Show patched versions as separate library items" to every variant now and whenever
    /// it changes. Idempotent; call once the database is open (AppState does, after
    /// `RomDatabase.initDefaultDatabase()`).
    public func startObservingSettings() {
        guard settingsObservation == nil else { return }
        settingsObservation = Task { @MainActor [weak self] in
            for await _ in Defaults.updates(.showPatchedVersionsAsSeparateItems) {
                self?.reconcileVariantVisibility()
            }
        }
    }

    /// Whether a variant is hidden from the library grid.
    ///
    /// The default launch version plays from the base game's entry, so it never gets a second one.
    /// Otherwise the global setting shows every variant, and with it off a patch's own
    /// `showAsLibraryTile` still does.
    public nonisolated static func isVariantHidden(
        showAsLibraryTile: Bool,
        isDefaultLaunch: Bool,
        showPatchedSeparately: Bool
    ) -> Bool {
        if isDefaultLaunch { return true }
        return !(showPatchedSeparately || showAsLibraryTile)
    }

    private func isVariantHidden(for patch: PVPatch?) -> Bool {
        Self.isVariantHidden(
            showAsLibraryTile: patch?.showAsLibraryTile ?? false,
            isDefaultLaunch: patch?.isDefaultLaunch ?? false,
            showPatchedSeparately: Defaults[.showPatchedVersionsAsSeparateItems]
        )
    }

    /// Re-derives `isHiddenPatchVariant` for every managed variant from the current setting.
    public func reconcileVariantVisibility() {
        guard RomDatabase.databaseInitialized else { return }
        let realm = RomDatabase.sharedInstance.realm
        let patches = realm.objects(PVPatch.self).filter("variantGame != nil")
        let stale = patches.filter { patch in
            guard let variant = patch.variantGame, variant.isPatchVariant else { return false }
            return variant.isHiddenPatchVariant != self.isVariantHidden(for: patch)
        }
        guard !stale.isEmpty else { return }
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                for patch in stale {
                    patch.variantGame?.isHiddenPatchVariant = isVariantHidden(for: patch)
                }
            }
            ILOG("PatchRepository: updated library visibility of \(stale.count) patched version(s)")
        } catch {
            WLOG("PatchRepository: could not update patched-version visibility: \(error.localizedDescription)")
        }
    }

    // MARK: - "Apply anyway"

    /// Patch IDs the user chose to apply to a ROM they were not made for. Every later apply of the
    /// patch (import, launch, a rebuilt cache after tvOS purges Caches) has to repeat the choice, or
    /// the variant made a moment ago fails its source check on the next cache miss. Kept in
    /// UserDefaults so the Realm schema does not change.
    nonisolated static let ignoreSourceChecksumKey = "PatchRepository.patchesIgnoringSourceChecksum"

    public func ignoresSourceChecksum(patchID: String) -> Bool {
        Self.patchIDsIgnoringSourceChecksum().contains(patchID)
    }

    public func setIgnoresSourceChecksum(_ ignore: Bool, patchID: String) {
        var ids = Self.patchIDsIgnoringSourceChecksum()
        if ignore { ids.insert(patchID) } else { ids.remove(patchID) }
        UserDefaults.standard.set(ids.sorted(), forKey: Self.ignoreSourceChecksumKey)
    }

    private nonisolated static func patchIDsIgnoringSourceChecksum() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: ignoreSourceChecksumKey) ?? [])
    }

    private func applyOptions(for patchID: String) -> PatchApplyOptions {
        PatchApplyOptions(ignoreSourceChecksum: ignoresSourceChecksum(patchID: patchID))
    }

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
        autoMatch: Bool = true,
        ignoreSourceChecksum: Bool? = nil
    ) async throws -> PVPatch {
        guard let format = PatchFormat.detect(fileAt: url) else {
            throw PatchError.unsupportedFormat(url.pathExtension)
        }

        let inspection = try inspector.inspect(patchURL: url)
        let database = RomDatabase.sharedInstance
        let realm = database.realm
        // Callers hand us frozen games from the UI; a new PVPatch cannot link to a frozen
        // object (Realm rejects objects owned by another Realm on add).
        let linkedGame: PVGame? = preferredGame.flatMap { game in
            guard !game.isInvalidated else { return nil }
            return game.isFrozen ? game.thaw() : game
        }

        let pvFile = PVFile(withURL: url)
        let existingID = !pvFile.partialPath.isEmpty ? pvFile.partialPath : url.path
        let patch: PVPatch
        if let existing = realm.object(ofType: PVPatch.self, forPrimaryKey: existingID) {
            patch = existing
        } else {
            patch = PVPatch(
                file: pvFile,
                game: linkedGame,
                format: format,
                title: inspection.title ?? url.deletingPathExtension().lastPathComponent,
                author: inspection.author,
                version: inspection.version,
                patchDescription: inspection.patchDescription,
                matchState: linkedGame == nil ? .pending : .manual
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
                    romURL: linkedGame?.file?.url ?? url,
                    patchURL: url
                )
            } else if let romURL = linkedGame?.file?.url, let stem = live.outputStem {
                // Same-filename patches (Game.ips for Game.gba) must not share the base
                // game's save directories.
                live.outputStem = PatchApplier.variantSafeStem(stem, romURL: romURL)
            }
            if let linkedGame {
                live.game = linkedGame.thaw() ?? linkedGame
                live.baseGameMD5 = linkedGame.md5Hash
                live.matchState = .manual
                live.matchConfidenceRaw = PatchMatchConfidence.exact.rawValue
                live.matchScore = 1
            }
        }

        if let ignoreSourceChecksum {
            setIgnoresSourceChecksum(ignoreSourceChecksum, patchID: patch.id)
        }

        if linkedGame == nil, autoMatch {
            _ = try await matchPatch(patch)
        } else if let linkedGame {
            _ = try await ensureVariant(for: patch, baseGame: linkedGame)
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
                } else if needsSourceCRC, let path = snap.filePath {
                    // Streamed: a disc image is never loaded whole.
                    crc = try? PatchCRCValidator.crc32(ofFileAt: URL(fileURLWithPath: path))
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

        let stem = PatchApplier.variantSafeStem(
            patch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL),
            romURL: romURL
        )
        let artifact = try await applier.apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: stem,
            options: applyOptions(for: patch.id)
        )
        let variantMD5 = artifact.patchedMD5
        let patchedCRC = try await Self.crcString(for: artifact)

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
                    existing.isHiddenPatchVariant = isVariantHidden(for: livePatch)
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
            variant.isHiddenPatchVariant = isVariantHidden(for: livePatch)
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
            if let variant = p.variantGame, variant.isPatchVariant {
                variant.isHiddenPatchVariant = isVariantHidden(for: p)
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
                        if let variant = $0.variantGame, variant.isPatchVariant {
                            variant.isHiddenPatchVariant = isVariantHidden(for: $0)
                        }
                    }
            }
            p.isDefaultLaunch = enabled
            p.isEnabled = enabled
            if let variant = p.variantGame, variant.isPatchVariant {
                variant.isHiddenPatchVariant = isVariantHidden(for: p)
            }
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

        let stem = PatchApplier.variantSafeStem(
            livePatch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL),
            romURL: romURL
        )
        let artifact = try await applier.apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: stem,
            options: applyOptions(for: livePatch.id),
            progress: progress
        )
        let patchedCRC = try await Self.crcString(for: artifact)

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
                    existing.isHiddenPatchVariant = isVariantHidden(for: p)
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
            variant.isHiddenPatchVariant = isVariantHidden(for: p)
            variant.baseGameMD5 = baseMD5
            variant.patchID = p?.id
            variant.originalArtworkURL = base?.originalArtworkURL ?? ""
            variant.customArtworkURL = base?.customArtworkURL ?? ""
            variant.userPreferredCoreID = base?.userPreferredCoreID
            variant.file = Self.makeVariantFile(for: artifact.url)
            variant.romPath = artifact.url.lastPathComponent
            variant.isDownloaded = true
            variant.crc = patchedCRC
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

    /// The patched ROM's CRC32 as stored in `PVGame.crc`. Artifacts recorded before streaming
    /// patching carry none; those are hashed off the main actor, in chunks.
    private nonisolated static func crcString(for artifact: PatchArtifact) async throws -> String {
        if let crc = artifact.patchedCRC32 {
            return String(format: "%08X", crc)
        }
        let url = artifact.url
        let crc = try await Task.detached(priority: .userInitiated) {
            try PatchCRCValidator.crc32(ofFileAt: url)
        }.value
        return String(format: "%08X", crc)
    }

    /// Build a `PVFile` rooted at the platform documents/caches directory so
    /// `FileLocationResolver` can find patched artifacts under `PatchedROMs/`.
    private static func makeVariantFile(for artifactURL: URL) -> PVFile {
        PVFile(withURL: artifactURL, relativeRoot: .platformDefault)
    }

    /// Result of a one-shot Patch Applier run (manual patch + ROM selection).
    /// Not `Sendable` — `importedPatch` is a Realm object confined to the calling thread.
    public struct StandaloneApplyResult {
        public var inspection: PatchInspection
        public var crcValidation: PatchCRCValidation
        public var exportURL: URL
        public var importedPatch: PVPatch?
        /// Whether applying checked the ROM or the result against the patch and it matched.
        /// False for IPS, for patches made without checks, and when the source check was ignored.
        public var checkedAgainstSource: Bool
    }

    /// Apply `patchURL` to `romURL` for the Patch Applier UI.
    ///
    /// Writes under `Documents/PatchedROMs/`, optionally imports/links the patch
    /// into the library. Throws on CRC mismatch unless `allowCRCMismatch` is set; with it set the
    /// patch is applied with its source check off (BPS/UPS/PPF/xdelta), and the choice is
    /// remembered for the imported patch so its variant keeps launching.
    ///
    /// - Parameter placement: where the imported patch's variant goes in the library.
    public func applyStandalone(
        patchURL: URL,
        romURL: URL,
        preferredGame: PVGame? = nil,
        importToLibrary: Bool = true,
        allowCRCMismatch: Bool = false,
        placement: PatchPlacement = .newLibraryEntry,
        progress: (@Sendable (PatchProgress) -> Void)? = nil
    ) async throws -> StandaloneApplyResult {
        let inspection = try await Task.detached(priority: .userInitiated) {
            try PatchInspector().inspect(patchURL: patchURL)
        }.value
        let crcValidation = try await Task.detached(priority: .userInitiated) {
            try PatchCRCValidator.validate(romURL: romURL, inspection: inspection)
        }.value
        if crcValidation.isMismatch, !allowCRCMismatch {
            if case .mismatched(let expected, let actual) = crcValidation {
                throw PatchError.crcMismatch(expected: expected, actual: actual)
            }
        }

        let dest = URL.documentsPath.appendingPathComponent("PatchedROMs", isDirectory: true)
        let preferred = "\(PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL)).\(romURL.pathExtension)"
        let options = PatchApplyOptions(ignoreSourceChecksum: allowCRCMismatch)
        let artifact = try await applier.apply(
            patchURL: patchURL,
            to: romURL,
            outputStem: (preferred as NSString).deletingPathExtension,
            options: options,
            progress: progress
        )
        let exportURL = try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: dest,
            preferredName: preferred,
            options: options
        )

        var imported: PVPatch?
        if importToLibrary {
            // Copy patch into the patches directory for stable library identity.
            let patchDest = try copyIntoPatchesDirectory(patchURL, sha256: inspection.patchSHA256)
            imported = try await importPatch(
                at: patchDest,
                preferredGame: preferredGame,
                autoMatch: preferredGame == nil,
                ignoreSourceChecksum: allowCRCMismatch
            )
            if let patch = imported {
                try setPlacement(placement, for: patch)
            }
        }

        return StandaloneApplyResult(
            inspection: inspection,
            crcValidation: crcValidation,
            exportURL: exportURL,
            importedPatch: imported,
            checkedAgainstSource: artifact.checkedAgainstSource ?? false
        )
    }

    /// Puts a linked patch's variant where `placement` says. Replacing the original makes the patch
    /// the base game's default launch; a new entry leaves the default as it was.
    public func setPlacement(_ placement: PatchPlacement, for patch: PVPatch) throws {
        switch placement {
        case .newLibraryEntry:
            return
        case .replaceOriginal:
            let realm = RomDatabase.sharedInstance.realm
            guard let live = patch.thaw() ?? realm.object(ofType: PVPatch.self, forPrimaryKey: patch.id),
                  live.baseGameMD5 != nil else {
                // Not linked to a game yet: nothing to take the place of.
                return
            }
            try setDefaultLaunch(true, for: live)
        }
    }

    /// Copy `patchURL` into `Paths.patchesPath` without clobbering a different patch that
    /// happens to share its filename. Same bytes reuse the existing file (so the existing
    /// `PVPatch` row is reused); different bytes get a short content-hash suffix.
    public func copyIntoPatchesDirectory(_ patchURL: URL, sha256: String? = nil) throws -> URL {
        let patchesDir = Paths.patchesPath
        try FileManager.default.createDirectory(at: patchesDir, withIntermediateDirectories: true)
        var dest = patchesDir.appendingPathComponent(patchURL.lastPathComponent)
        guard patchURL.standardizedFileURL != dest.standardizedFileURL else { return dest }

        if FileManager.default.fileExists(atPath: dest.path) {
            let incoming = try sha256 ?? inspector.inspect(patchURL: patchURL).patchSHA256
            let existing = try? inspector.inspect(patchURL: dest).patchSHA256
            if existing == incoming {
                return dest
            }
            let stem = dest.deletingPathExtension().lastPathComponent
            let ext = dest.pathExtension
            dest = patchesDir.appendingPathComponent("\(stem)-\(incoming.prefix(8)).\(ext)")
        }
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: patchURL, to: dest)
        }
        return dest
    }

    /// Import a downloaded or picked file that may be a bare patch *or* an archive
    /// (RomHacking.net serves ZIPs). Archives are extracted and every supported patch
    /// inside is imported; the first one is returned.
    @discardableResult
    public func importPatchFile(
        at url: URL,
        preferredGame: PVGame? = nil,
        autoMatch: Bool = true
    ) async throws -> PVPatch {
        let manager = ArchiveManager.shared
        guard manager.isArchive(at: url) else {
            let dest = try copyIntoPatchesDirectory(url)
            return try await importPatch(at: dest, preferredGame: preferredGame, autoMatch: autoMatch)
        }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchArchive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        // atPath: — the URL overload is shadowed by PVLibrary's async extension, and defer can't await.
        defer { try? FileManager.default.removeItem(atPath: scratch.path) }

        let extracted = try await manager.extractAll(at: url, to: scratch)
        let patches = extracted
            .filter { PatchFormat.implementedFileExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        guard !patches.isEmpty else {
            throw PatchError.unsupportedFormat("\(url.lastPathComponent) contains no supported patch file")
        }

        var imported: [PVPatch] = []
        for extractedPatch in patches {
            let dest = try copyIntoPatchesDirectory(extractedPatch)
            let patch = try await importPatch(at: dest, preferredGame: preferredGame, autoMatch: autoMatch)
            imported.append(patch)
        }
        // The archive itself has been consumed; keep Patches/ free of stray zips.
        if url.standardizedFileURL.path.hasPrefix(Paths.patchesPath.standardizedFileURL.path) {
            // PVLibrary's FileManager.removeItem(at:) is the async overload (DirectoryWatcher.swift).
            try? await FileManager.default.removeItem(at: url)
        }
        guard let first = imported.first else {
            throw PatchError.unsupportedFormat("\(url.lastPathComponent) contains no supported patch file")
        }
        return first
    }

    /// Snapshot library ROMs for batch patch matching.
    public func batchROMCandidates() -> [BatchPatchApplier.ROMCandidate] {
        let realm = RomDatabase.sharedInstance.realm
        return realm.objects(PVGame.self)
            .filter("isPatchVariant == false AND contentless == false")
            .compactMap { game in
                guard let fileURL = game.file?.url,
                      let filename = game.file?.fileName,
                      FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
                var crc: UInt32?
                if !game.crc.isEmpty {
                    crc = UInt32(game.crc, radix: 16)
                }
                return BatchPatchApplier.ROMCandidate(
                    id: game.md5Hash,
                    title: game.title,
                    filename: filename,
                    fileURL: fileURL,
                    crc32: crc
                )
            }
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
        let exportStem = PatchApplier.variantSafeStem(
            livePatch.outputStem ?? PatchApplier.defaultOutputStem(romURL: romURL, patchURL: patchURL),
            romURL: romURL
        )
        let preferred = "\(exportStem).\(romURL.pathExtension)"
        return try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: dest,
            preferredName: preferred,
            options: applyOptions(for: livePatch.id),
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
        setIgnoresSourceChecksum(false, patchID: live.id)

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
