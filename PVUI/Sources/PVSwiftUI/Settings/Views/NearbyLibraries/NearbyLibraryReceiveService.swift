#if os(iOS) || os(tvOS)
import Combine
import Darwin
import Foundation
import PVLibrary
import PVLibrarySharing
import PVRealm
import PVSystems
import RealmSwift

/// A receipt belongs to an actual Realm registration and the verified local bytes.
/// Stat checks on later passes avoid rehashing large images while detecting cache eviction.
struct NearbyLibraryReceipt: Codable, Sendable {
    struct File: Codable, Equatable, Sendable {
        let url: URL
        let size: Int64
        let device: Int64
        let inode: UInt64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
        let changedSeconds: Int64
        let changedNanoseconds: Int64
        init?(_ url: URL) {
            var info = stat()
            let result = url.withUnsafeFileSystemRepresentation { path in
                guard let path else { return Int32(-1) }
                return Darwin.lstat(path, &info)
            }
            guard result == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
            self.url = url
            self.size = Int64(info.st_size)
            self.device = Int64(info.st_dev)
            self.inode = UInt64(info.st_ino)
            self.modifiedSeconds = Int64(info.st_mtimespec.tv_sec)
            self.modifiedNanoseconds = Int64(info.st_mtimespec.tv_nsec)
            self.changedSeconds = Int64(info.st_ctimespec.tv_sec)
            self.changedNanoseconds = Int64(info.st_ctimespec.tv_nsec)
        }
    }
    let gameID: String
    let system: String
    let sourceFiles: [RemoteFile]
    let files: [File]

    @MainActor func isPresent(manifest: RemoteManifest) -> Bool {
        guard sourceFiles == manifest.gameFiles, !files.isEmpty,
              let registered = NearbyLibraryReceiveService.registeredFiles(gameID: gameID, system: system),
              registered == files.map(\.url) else { return false }
        return files.allSatisfy { File($0.url) == $0 }
    }
}

/// Shares a physical transfer/import lease with manual copies from iCube.
@MainActor enum NearbyLibraryReceiveService {
    enum ReceiveError: LocalizedError {
        case unsupportedManifest, importNotQueued, incompleteImport
        var errorDescription: String? {
            switch self {
            case .unsupportedManifest: return "This iCube game does not provide one supported ROM image."
            case .importNotQueued: return "The importer could not queue this game. Finish other imports, then retry."
            case .incompleteImport: return "The imported game could not be verified in the local library."
            }
        }
    }

    static func registeredFiles(gameID: String, system: String) -> [URL]? {
        guard let realm = try? Realm(configuration: RealmConfiguration.realmConfig),
              let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID),
              game.systemIdentifier == system, let primary = game.file?.url else { return nil }
        let urls = [primary] + game.relatedFiles.compactMap(\.url).filter { $0 != primary }
        guard urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else { return nil }
        return urls
    }

    static func receive(_ item: RemoteLibraryItem, source: ICubeContinuitySource, peerKey: String,
                        staging: LibraryStaging, manifest: RemoteManifest? = nil,
                        checkEligibility: @escaping @MainActor @Sendable () throws -> Void = {},
                        progress: @escaping @Sendable (LibraryPullProgress) -> Void) async throws -> NearbyLibraryReceipt {
        try await LibraryReceiveSerialExecutor.shared.withPermit {
            try await perform(item, source: source, peerKey: peerKey, staging: staging, manifest: manifest,
                              checkEligibility: checkEligibility, progress: progress)
        }
    }

    private static func perform(_ item: RemoteLibraryItem, source: ICubeContinuitySource, peerKey: String,
                                staging: LibraryStaging, manifest: RemoteManifest?,
                                checkEligibility: @escaping @MainActor @Sendable () throws -> Void,
                                progress: @escaping @Sendable (LibraryPullProgress) -> Void) async throws -> NearbyLibraryReceipt {
        try Task.checkCancellation()
        try checkEligibility()
        let fresh: RemoteManifest
        if let manifest {
            fresh = manifest
        } else {
            fresh = try await source.pullManifest(for: item) { progress(.preparing($0)) }
        }
        guard fresh.itemId == item.id, fresh.gameFiles.count == 1,
              let system = item.systemIdentifier else { throw ReceiveError.unsupportedManifest }
        try Task.checkCancellation()
        try checkEligibility()
        // An already registered identical image is a verified no-op, including after a restart.
        if let md5 = item.md5?.uppercased(),
           let receipt = try await confirmedReceipt(gameID: md5, system: system, manifest: fresh) {
            try checkEligibility()
            return receipt
        }
        let pulled = try await LibraryPuller(staging: staging, peerKey: peerKey).pull(item, from: source, manifest: fresh, progress: progress)
        try Task.checkCancellation()
        try checkEligibility()
        guard !GameImporter.shared.isPausedForEmulation else { throw CancellationError() }
        let queued = ImportQueueItem(url: pulled.primaryFile)
        queued.userChosenSystem = system
        queued.requiresContentBasedDuplicateCheck = true
        let accepted = try await withTaskCancellationHandler {
            await GameImporter.shared.addImport(queued)
            var eligibilityError: Error?
            do { try checkEligibility() } catch {
                eligibilityError = error
                queued.cancelPendingProcessing()
                await GameImporter.shared.cancelPendingImports(withIDs: [queued.id])
            }
            let accepted = await GameImporter.shared.importQueue.contains { $0.id == queued.id }
            if accepted {
                // Even after cancellation, keep the lease until a claimed import terminates.
                let completion = NearbyImportCompletion(item: queued)
                GameImporter.shared.startProcessing()
                try await completion.wait()
            } else {
                try Task.checkCancellation()
            }
            if let eligibilityError { throw eligibilityError }
            return accepted
        } onCancel: {
            // No actor hop: a running worker must see this before it can claim a late admission.
            queued.cancelPendingProcessing()
        }
        let computedMD5 = await queued.gameMD5Async()
        let identity = queued.gameDatabaseID ?? computedMD5?.uppercased()
        guard let identity,
              let receipt = try await confirmedReceipt(gameID: identity, system: system, manifest: fresh) else {
            throw accepted ? ReceiveError.incompleteImport : ReceiveError.importNotQueued
        }
        try Task.checkCancellation()
        try checkEligibility()
        staging.markHandedOff(pulled.folder)
        return receipt
    }

    private static func confirmedReceipt(gameID: String, system: SystemIdentifier, manifest: RemoteManifest) async throws -> NearbyLibraryReceipt? {
        guard let urls = registeredFiles(gameID: gameID, system: system.rawValue),
              let primary = urls.first, let descriptor = manifest.gameFiles.first,
              let before = NearbyLibraryReceipt.File(primary), before.size == descriptor.size else { return nil }
        let digest = try await Task.detached(priority: .utility) { try FileSHA256.hex(of: primary) }.value
        try Task.checkCancellation()
        guard digest.caseInsensitiveCompare(descriptor.sha256) == .orderedSame,
              NearbyLibraryReceipt.File(primary) == before else { return nil }
        let stamps = urls.compactMap(NearbyLibraryReceipt.File.init)
        guard stamps.count == urls.count else { return nil }
        return NearbyLibraryReceipt(gameID: gameID, system: system.rawValue, sourceFiles: manifest.gameFiles, files: stamps)
    }
}

/// Observes the actual item. Cancelling a pending item removes only our stable ID;
/// an already claimed import retains its files and lease until its real terminal state.
@MainActor final class NearbyImportCompletion {
    private let item: ImportQueueItem
    private var observer: AnyCancellable?
    private var continuation: CheckedContinuation<Void, Error>?
    private var cancelled = false
    private var cleanupFinished = true
    init(item: ImportQueueItem) { self.item = item }

    func wait() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                observer = item.objectWillChange.sink { [weak self] in
                    Task { @MainActor in self?.evaluate() }
                }
                if Task.isCancelled { cancel() }
                evaluate()
            }
        } onCancel: {
            item.cancelPendingProcessing()
            Task { @MainActor in self.cancel() }
        }
    }

    private func cancel() {
        guard !cancelled else { return }
        cancelled = true
        cleanupFinished = false
        Task {
            await GameImporter.shared.cancelPendingImports(withIDs: [item.id])
            cleanupFinished = true
            evaluate()
        }
    }

    private func evaluate() {
        guard let continuation, cleanupFinished else { return }
        let result: Result<Void, Error>
        switch item.status {
        case .success: result = cancelled ? .failure(CancellationError()) : .success(())
        case .failure(let error): result = .failure(cancelled ? CancellationError() : error)
        case .conflict, .partial: result = .failure(cancelled ? CancellationError() : NearbyLibraryReceiveService.ReceiveError.incompleteImport)
        case .queued, .processing, .extracting: return
        }
        self.continuation = nil
        observer = nil
        continuation.resume(with: result)
    }
}
#endif
