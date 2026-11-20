//
//  MissingROMRecoveryService.swift
//  PVSwiftUI
//
//  Gets a library game's missing file back from a paired nearby app or a saved server.
//  tvOS keeps the library in Caches and purges it; iCloud holds no copy of large games.
//

import Defaults
import Foundation
import PVFileSystem
import PVLibrary
import PVLibrarySharing
import PVLogging
import PVRealm
import PVSettings
import PVSystems
import PVUIBase
import RealmSwift

@MainActor
public final class MissingROMRecoveryService: MissingROMRecovering {
    public static let shared = MissingROMRecoveryService()

    /// Makes launches use this service. Call once at startup.
    public static func register() {
        MissingROMRecovery.recoverer = shared
    }

    private let directory = RecoverySourceDirectory()
    /// One search, so games missing at the same time share the fetched game lists.
    private let search = MissingGameSearch()
    private let staging = NearbyLibrariesModel.incomingStaging
    private lazy var hints = GameSourceHints(fileURL: Self.hintsURL)
    /// Recoveries in flight by game MD5: a second launch of the same game joins the first.
    private var running: [String: Task<MissingROMRecoveryOutcome, Never>] = [:]

    private static var hintsURL: URL {
        let folder = RealmConfiguration.realmConfig.fileURL?.deletingLastPathComponent() ?? LibrarySharingService.supportFolder
        return folder.appendingPathComponent(GameSourceHints.fileName)
    }

    /// What recovery needs to know about the game, read once from the database.
    private struct Target {
        let query: MissingGameQuery
        let files: [RestoreTarget]
        var primaryURL: URL? { files.first(where: \.file.isPrimary)?.url ?? files.first?.url }
    }

    public func recover(
        gameMD5: String,
        status: @escaping @MainActor (String) -> Void,
        ask: @escaping @MainActor (MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer
    ) async -> MissingROMRecoveryOutcome {
        let key = gameMD5.uppercased()
        if let existing = running[key] { return await existing.value }
        // A game list fetched for an earlier recovery may be minutes or hours old. Games missing
        // together still share one fetch.
        let startsFresh = running.isEmpty
        let task = Task { @MainActor in
            if startsFresh { await self.search.reset() }
            return await self.run(md5: key, status: status, ask: ask)
        }
        running[key] = task
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        running[key] = nil
        return outcome
    }

    private func run(
        md5: String,
        status: @escaping @MainActor (String) -> Void,
        ask: @escaping @MainActor (MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer
    ) async -> MissingROMRecoveryOutcome {
        guard let target = target(forMD5: md5) else {
            return .failed(message: "The game is no longer in the library.")
        }
        let query = target.query
        let fileList = query.files.map { "\($0.name) (\($0.size))" }.joined(separator: ", ")
        ILOG("Missing ROM recovery: \(query.title) [\(query.system.rawValue)] md5 \(query.md5), files: \(fileList), single file: \(query.isSingleFileImage)")
        let available = await directory.sources(for: query.system)
        if Task.isCancelled { return .declined }
        var needsSignIn = available.needsSignIn
        if available.localNetworkDenied { needsSignIn.append("Local Network access (Settings › Privacy)") }

        let byIdentity = Dictionary(available.sources.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
        let candidates = available.sources.map {
            SearchSource(source: $0.source, name: $0.name, identity: $0.identity, rank: $0.rank)
        }
        let hint = await hints.hint(forMD5: md5)
        let (found, report) = await search.find(query, hint: hint, in: candidates) { name in
            Task { @MainActor in status("Asking \(name)…") }
        }
        if Task.isCancelled { return .declined }
        guard let found, let origin = byIdentity[found.source.identity] else {
            return .notFound(asked: report.asked, unreachable: report.unreachable, needsSignIn: needsSignIn)
        }

        ILOG("Missing ROM recovery: \(origin.name) has \(found.item.title) (md5 \(found.item.md5 ?? "none"), \(found.item.sizeBytes) bytes) as \(found.kind)")
        switch found.kind {
        case .exact:
            if !Defaults[.missingROMRecoveryAlwaysAllow] {
                switch await ask(.copy(title: query.title, source: origin.name)) {
                case .cancel: return .declined
                case .alwaysAllow: Defaults[.missingROMRecoveryAlwaysAllow] = true
                case .allow: break
                }
            }
        case .standIn:
            let fileName = found.manifest?.primaryGameFile?.fileName ?? found.item.title
            guard await ask(.standIn(title: query.title, fileName: fileName, source: origin.name)) != .cancel else {
                return .declined
            }
        }

        do {
            status("Copying from \(origin.name)…")
            let puller = LibraryPuller(staging: staging, peerKey: origin.peerKey)
            let pulled = try await puller.pull(found.item, from: origin.source, manifest: found.manifest) { progress in
                guard case let .downloading(_, _, _, bytesDone, totalBytes) = progress, totalBytes > 0 else { return }
                let percent = Int(Double(bytesDone) / Double(totalBytes) * 100)
                Task { @MainActor in status("Copying from \(origin.name): \(percent)%") }
            }
            try Task.checkCancellation()
            let result = try MissingGameRestorer.restore(pulled, to: target.files, kind: found.kind, staging: staging)
            ILOG("Missing ROM recovery: restored \(result.restored.count) file(s) of \(query.title) from \(origin.name)")
            if let primary = target.primaryURL {
                await GameFileStatusService.shared.markDownloaded(md5: md5, at: primary)
            }
            await hints.record(GameSourceHint(
                app: origin.source.app, sourceIdentity: origin.identity, remoteItemID: found.item.id,
                files: query.files, standInMD5: found.kind == .standIn ? (found.item.md5 ?? "") : nil
            ), forMD5: md5)
            return .restored
        } catch is CancellationError {
            return .declined
        } catch {
            ELOG("Missing ROM recovery: copying \(query.title) from \(origin.name) failed: \(error)")
            return .failed(message: error.localizedDescription)
        }
    }

    /// True when the game's primary file is not on disk, for showing "Restore Missing File".
    public func isFileMissing(gameMD5: String) -> Bool {
        guard let target = target(forMD5: gameMD5.uppercased()), let primary = target.primaryURL else { return false }
        return !FileManager.default.fileExists(atPath: primary.path)
    }

    private func target(forMD5 md5: String) -> Target? {
        guard let game = RomDatabase.sharedInstance.game(withMD5: md5),
              let system = SystemIdentifier(rawValue: game.systemIdentifier), system != .Unknown,
              let primaryPath = game.file?.partialPath, !primaryPath.isEmpty else { return nil }
        let resolver = FileLocationResolver.shared
        let primaryURL = resolver.bestURL(for: primaryPath)
        // The importer does not fill `fileSize`; the file's own last measured size is the fallback.
        let primarySize = game.fileSize > 0 ? game.fileSize : (game.file?.lastKnownSize ?? 0)
        var files = [RestoreTarget(
            file: MissingGameFile(name: primaryURL.lastPathComponent, size: Int64(primarySize), isPrimary: true),
            url: primaryURL
        )]
        // The related list holds the primary file again, under another form of its path that
        // resolves elsewhere while the file is missing. Files are matched by name, so a name
        // counts once.
        var seen: Set<String> = [primaryURL.lastPathComponent.lowercased()]
        for related in game.relatedFiles where !related.partialPath.isEmpty {
            let url = resolver.bestURL(for: related.partialPath)
            guard seen.insert(url.lastPathComponent.lowercased()).inserted else { continue }
            // 0 means the size is unknown to the matcher.
            files.append(RestoreTarget(
                file: MissingGameFile(name: url.lastPathComponent, size: Int64(related.lastKnownSize), isPrimary: false),
                url: url
            ))
        }
        let single = LocalLibraryEntry.isSingleFileImage(
            primaryFileExtension: (primaryPath as NSString).pathExtension, relatedFileCount: files.count - 1
        )
        let query = MissingGameQuery(
            md5: game.md5Hash, system: system, title: game.title, files: files.map(\.file), isSingleFileImage: single
        )
        return Target(query: query, files: files)
    }
}
