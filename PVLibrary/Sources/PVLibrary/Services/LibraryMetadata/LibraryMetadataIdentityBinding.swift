import Foundation
import PVLibraryMetadata
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Observed reader fields, never a filename, guessed serial, or defaulted optional.
/// DiscIO emits six alphanumeric bytes, or a WAD TMD's nonzero 16-digit title ID.
public struct VerifiedDiscIdentity: Sendable {
    public let gameID: String
    public let discNumber: Int
    public let revision: Int

    public init?(gameID: String, discNumber: Int, revision: Int) {
        guard gameID.utf8.count == 6 || gameID.utf8.count == 16 else { return nil }
        let bytes = Array(gameID.utf8)
        let alphanumeric = bytes.count == 6 && bytes.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
        let titleID = bytes.count == 16 && bytes.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
        guard (alphanumeric || titleID), bytes.contains(where: { $0 != 48 }),
              (0...255).contains(discNumber), (0...65535).contains(revision) else { return nil }
        self.gameID = gameID
        self.discNumber = discNumber
        self.revision = revision
    }

    fileprivate var canonical: LibraryMetadataStore.Identity? {
        LibraryMetadataStore.Identity.game(gameID: gameID, discNumber: discNumber, revision: revision)
    }
}

/// Durable local-to-canonical bindings. Own one actor per persistence URL.
/// Callers own collection lifetime and foreground/emulation eligibility. Lookup
/// only checks cached bindings and file evidence; it never invokes a ROM reader.
/// Invalidating a binding never removes custom edits from LibraryMetadataStore.
/// IO failure or cancellation preserves the previously committed binding. Callers
/// must invalidate before independently reassigning/deleting a collection entry;
/// a failed bind does not authorize changing its associated file URL.
/// Stat/traversal equality detects normal filesystem changes, including symlink
/// replacement. It is not an atomic filesystem snapshot or cryptographic proof
/// against malicious concurrent path-component substitution or stat rewriting.
public actor LibraryMetadataIdentityBinding {
    /// Receives a resolved URL pinned to the admitted traversal, rather than the
    /// original potentially symlinked URL. It must read that supplied URL.
    public typealias Reader = @Sendable (URL) async throws -> VerifiedDiscIdentity?
    /// Must synchronously replace the whole file atomically, or throw without
    /// changing it. The default writer uses Foundation's atomic replacement.
    public typealias Writer = @Sendable (Data, URL) throws -> Void

    /// Generous local-library limits, also enforced before decoding records.
    public static let maxDocumentBytes = 16 * 1024 * 1024
    public static let maxRecords = 20_000
    private static let maxLocalIDBytes = 1024
    private static let maxPathBytes = 16 * 1024
    private static let maxSymlinks = 40

    public enum BindingError: Error {
        case invalidInput, corruptPersistence, capacityExceeded
    }

    private struct FileEvidence: Codable, Equatable {
        let device: UInt64
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
        let changedSeconds: Int64
        let changedNanoseconds: Int64

        static func read(_ url: URL) -> FileEvidence? {
            var info = stat()
            guard url.isFileURL, !url.path.utf8.contains(0), stat(url.path, &info) == 0,
                  (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), info.st_size >= 0 else { return nil }
            return FileEvidence(info)
        }

        init(_ info: stat) {
            #if canImport(Darwin)
            let modified = info.st_mtimespec
            let changed = info.st_ctimespec
            #else
            let modified = info.st_mtim
            let changed = info.st_ctim
            #endif
            device = UInt64(truncatingIfNeeded: info.st_dev)
            inode = UInt64(info.st_ino)
            size = Int64(info.st_size)
            modifiedSeconds = Int64(modified.tv_sec)
            modifiedNanoseconds = Int64(modified.tv_nsec)
            changedSeconds = Int64(changed.tv_sec)
            changedNanoseconds = Int64(changed.tv_nsec)
        }

        var valid: Bool {
            size >= 0 && (0..<1_000_000_000).contains(modifiedNanoseconds) && (0..<1_000_000_000).contains(changedNanoseconds)
        }
    }

    private struct SymlinkWitness: Codable, Equatable {
        let path: String
        let target: String
        let evidence: FileEvidence
    }

    private struct TraversalEvidence: Codable, Equatable {
        let resolvedPath: String
        let symlinks: [SymlinkWitness]

        init(resolvedPath: String, symlinks: [SymlinkWitness]) {
            self.resolvedPath = resolvedPath
            self.symlinks = symlinks
        }

        enum CodingKeys: String, CodingKey { case resolvedPath, symlinks }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            resolvedPath = try container.decode(String.self, forKey: .resolvedPath)
            var entries = try container.nestedUnkeyedContainer(forKey: .symlinks)
            if let count = entries.count, count > LibraryMetadataIdentityBinding.maxSymlinks { throw BindingError.capacityExceeded }
            var decoded: [SymlinkWitness] = []
            while !entries.isAtEnd {
                guard decoded.count < LibraryMetadataIdentityBinding.maxSymlinks else { throw BindingError.capacityExceeded }
                decoded.append(try entries.decode(SymlinkWitness.self))
            }
            symlinks = decoded
        }

        var valid: Bool {
            Self.validPath(resolvedPath) && symlinks.count <= LibraryMetadataIdentityBinding.maxSymlinks && symlinks.allSatisfy {
                Self.validPath($0.path) && !$0.target.isEmpty && $0.target.utf8.count <= LibraryMetadataIdentityBinding.maxPathBytes &&
                    !$0.target.utf8.contains(0) && $0.evidence.valid
            }
        }

        private static func validPath(_ path: String) -> Bool { LibraryMetadataIdentityBinding.validPath(path) }
    }

    private struct PathSnapshot: Equatable {
        let evidence: FileEvidence
        let traversal: TraversalEvidence

        /// Walk and expand symlinks ourselves so links inside another link's
        /// destination are witnessed too. Ordinary directory timestamps are not
        /// stored: sibling additions must not invalidate existing bindings.
        static func read(_ original: URL) -> PathSnapshot? {
            guard original.isFileURL, LibraryMetadataIdentityBinding.validPath(original.path) else { return nil }
            var pending = original.path.split(separator: "/").map(String.init).reversed().map { $0 }
            var resolved: [String] = []
            var symlinks: [SymlinkWitness] = []
            while let component = pending.popLast() {
                if component == "." { continue }
                if component == ".." {
                    if !resolved.isEmpty { resolved.removeLast() }
                    continue
                }
                let candidate = "/" + (resolved + [component]).joined(separator: "/")
                guard LibraryMetadataIdentityBinding.validPath(candidate) else { return nil }
                var info = stat()
                guard lstat(candidate, &info) == 0 else { return nil }
                let mode = info.st_mode & mode_t(S_IFMT)
                if mode == mode_t(S_IFLNK) {
                    guard symlinks.count < LibraryMetadataIdentityBinding.maxSymlinks else { return nil }
                    var buffer = [CChar](repeating: 0, count: LibraryMetadataIdentityBinding.maxPathBytes + 1)
                    let count = readlink(candidate, &buffer, buffer.count)
                    guard count > 0, count <= LibraryMetadataIdentityBinding.maxPathBytes,
                          let target = String(bytes: buffer.prefix(count).map({ UInt8(bitPattern: $0) }), encoding: .utf8),
                          !target.utf8.contains(0) else { return nil }
                    let witness = FileEvidence(info)
                    var after = stat()
                    guard lstat(candidate, &after) == 0, (after.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK),
                          witness == FileEvidence(after) else { return nil }
                    symlinks.append(SymlinkWitness(path: candidate, target: target, evidence: witness))
                    if target.hasPrefix("/") { resolved.removeAll(keepingCapacity: true) }
                    pending.append(contentsOf: target.split(separator: "/").map(String.init).reversed())
                    continue
                }
                resolved.append(component)
                if pending.isEmpty {
                    guard mode == mode_t(S_IFREG), info.st_size >= 0 else { return nil }
                    return PathSnapshot(evidence: FileEvidence(info), traversal: TraversalEvidence(resolvedPath: candidate, symlinks: symlinks))
                }
                guard mode == mode_t(S_IFDIR) else { return nil }
            }
            return nil
        }
    }

    private struct Record: Codable {
        let localGameID: String
        let canonicalIdentity: String
        // Keep the original standardized path, not its resolved symlink target.
        let originalPath: String
        let evidence: FileEvidence
        // Optional only for the earlier v1 records: without a traversal proof
        // they remain pending and require a fresh explicit bind.
        let traversal: TraversalEvidence?

        var identity: LibraryMetadataStore.Identity? {
            guard canonicalIdentity.utf8.count <= 128,
                  let parsed = LibraryMetadataStore.Identity.parseCanonical(canonicalIdentity) else { return nil }
            let parts = canonicalIdentity.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 4, parts[0] == "game", let data = Data(base64Encoded: String(parts[1])),
                  let gameID = String(data: data, encoding: .utf8), let disc = Int(parts[2]), let revision = Int(parts[3]),
                  let observed = VerifiedDiscIdentity(gameID: gameID, discNumber: disc, revision: revision),
                  observed.canonical == parsed else { return nil }
            return parsed
        }
    }

    private struct Document: Codable {
        let version: Int
        let records: [Record]
        init(records: [Record]) { self.version = 1; self.records = records }
        enum CodingKeys: String, CodingKey { case version, records }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(Int.self, forKey: .version)
            guard version == 1 else { throw BindingError.corruptPersistence }
            var entries = try container.nestedUnkeyedContainer(forKey: .records)
            if let count = entries.count, count > LibraryMetadataIdentityBinding.maxRecords { throw BindingError.capacityExceeded }
            var decoded: [Record] = []
            while !entries.isAtEnd {
                guard decoded.count < LibraryMetadataIdentityBinding.maxRecords else { throw BindingError.capacityExceeded }
                decoded.append(try entries.decode(Record.self))
            }
            records = decoded
        }
    }

    private let localPersistURL: URL
    private let reader: Reader
    private let writer: Writer
    private var records: [String: Record] = [:]
    private var loaded = false
    // Only active readers consume generation storage. A new UUID or removal
    // invalidates every suspended older result, without retaining historical IDs.
    private var active: [String: UUID] = [:]

    public init(localPersistURL: URL, reader: @escaping Reader, writer: @escaping Writer = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }) {
        self.localPersistURL = localPersistURL
        self.reader = reader
        self.writer = writer
    }

    /// Explicit reader admission. Unsupported, stale or changed files stay pending.
    /// A reader failure removes an earlier binding and propagates the reader error.
    public func bind(localGameID: String, fileURL: URL) async throws -> LibraryMetadataStore.Identity? {
        try Self.validate(localGameID)
        guard active[localGameID] != nil || active.count < Self.maxRecords else { throw BindingError.capacityExceeded }
        let generation = UUID()
        active[localGameID] = generation
        defer { if active[localGameID] == generation { active.removeValue(forKey: localGameID) } }
        try Task.checkCancellation()
        try load()
        guard fileURL.isFileURL else { throw BindingError.invalidInput }
        let url = fileURL.standardizedFileURL
        guard Self.validPath(url.path) else { throw BindingError.invalidInput }
        guard let before = PathSnapshot.read(url) else {
            try remove(localGameID)
            return nil
        }
        let readerURL = URL(fileURLWithPath: before.traversal.resolvedPath)
        guard before.evidence == FileEvidence.read(readerURL) else {
            try remove(localGameID)
            return nil
        }
        let observed: VerifiedDiscIdentity?
        do {
            observed = try await reader(readerURL)
        } catch {
            try Task.checkCancellation()
            guard active[localGameID] == generation else { return nil }
            try remove(localGameID)
            throw error
        }
        try Task.checkCancellation()
        guard active[localGameID] == generation else { return nil }
        guard let identity = observed?.canonical, before == PathSnapshot.read(url),
              before.evidence == FileEvidence.read(URL(fileURLWithPath: before.traversal.resolvedPath)) else {
            try remove(localGameID)
            return nil
        }
        var next = records
        next[localGameID] = Record(localGameID: localGameID, canonicalIdentity: identity.rawValue, originalPath: url.path,
                                   evidence: before.evidence, traversal: before.traversal)
        try persist(next)
        return identity
    }

    /// Revalidate the original file path without parsing or hashing the ROM.
    public func identity(forLocalGameID localGameID: String) async throws -> LibraryMetadataStore.Identity? {
        try Self.validate(localGameID)
        try Task.checkCancellation()
        try load()
        guard active[localGameID] == nil, let record = records[localGameID] else { return nil }
        guard let traversal = record.traversal, let current = PathSnapshot.read(URL(fileURLWithPath: record.originalPath)),
              record.evidence == current.evidence, traversal == current.traversal else {
            try remove(localGameID)
            return nil
        }
        return record.identity
    }

    /// Reject suspended readers even when there is no persisted record to remove.
    public func invalidate(localGameID: String) async throws {
        try Self.validate(localGameID)
        active.removeValue(forKey: localGameID)
        try Task.checkCancellation()
        try load()
        try remove(localGameID)
    }

    private static func validate(_ localGameID: String) throws {
        guard !localGameID.isEmpty, localGameID.utf8.count <= maxLocalIDBytes, !localGameID.utf8.contains(0) else { throw BindingError.invalidInput }
    }

    private static func validPath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.utf8.count <= maxPathBytes && !path.utf8.contains(0)
    }

    private func load() throws {
        guard !loaded else { return }
        guard localPersistURL.isFileURL, Self.validPath(localPersistURL.path) else { throw BindingError.invalidInput }
        // A bounded read avoids allocating an attacker-sized or growing file;
        // nonblocking open plus fstat also refuses FIFOs and other special files.
        let descriptor = open(localPersistURL.path, O_RDONLY | O_NONBLOCK)
        guard descriptor >= 0 else {
            if errno == ENOENT { loaded = true; return }
            throw BindingError.corruptPersistence
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              info.st_size >= 0, info.st_size <= Self.maxDocumentBytes else { throw BindingError.corruptPersistence }
        let data = try handle.read(upToCount: Self.maxDocumentBytes + 1) ?? Data()
        guard data.count <= Self.maxDocumentBytes else { throw BindingError.capacityExceeded }
        let document = try JSONDecoder().decode(Document.self, from: data)
        var decoded: [String: Record] = [:]
        for record in document.records {
            try Self.validate(record.localGameID)
            guard Self.validPath(record.originalPath), record.evidence.valid, record.identity != nil, record.traversal?.valid != false,
                  decoded[record.localGameID] == nil else { throw BindingError.corruptPersistence }
            decoded[record.localGameID] = record
        }
        records = decoded
        loaded = true
    }

    private func remove(_ localGameID: String) throws {
        guard records[localGameID] != nil else { return }
        var next = records
        next.removeValue(forKey: localGameID)
        try persist(next)
    }

    private func persist(_ next: [String: Record]) throws {
        guard next.count <= Self.maxRecords else { throw BindingError.capacityExceeded }
        let data = try JSONEncoder().encode(Document(records: Array(next.values)))
        guard data.count <= Self.maxDocumentBytes else { throw BindingError.capacityExceeded }
        // Cancellation admission precedes this synchronous atomic transaction.
        // There is no actor suspension between the write and cache publication.
        try Task.checkCancellation()
        try writer(data, localPersistURL)
        records = next
    }
}
