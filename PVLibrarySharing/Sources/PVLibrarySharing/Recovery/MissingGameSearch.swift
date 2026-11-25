//
//  MissingGameSearch.swift
//  PVLibrarySharing
//
//  Asks known libraries, in order, for a game whose files are gone.
//

import Foundation

/// A library to ask, with the name shown to the user.
public struct SearchSource: Sendable {
    public var source: any LibrarySource
    public var name: String
    /// The peer's id or a content server's URL string; matches `GameSourceHint.sourceIdentity`.
    public var identity: String
    /// 0 same device, 1 nearby device, 2 server. Lower is asked first.
    public var rank: Int

    public init(source: any LibrarySource, name: String, identity: String, rank: Int) {
        self.source = source
        self.name = name
        self.identity = identity
        self.rank = rank
    }
}

public struct FoundGame: Sendable {
    public var source: SearchSource
    public var item: RemoteLibraryItem
    /// The manifest when the search had to fetch one; the copy reuses it so a metered host
    /// is asked once.
    public var manifest: RemoteManifest?
    public var kind: RecoveryMatchKind
}

public struct SearchReport: Sendable, Equatable {
    /// Names of the sources that answered.
    public var asked: [String] = []
    /// Names of the sources that timed out or failed.
    public var unreachable: [String] = []
}

public actor MissingGameSearch {
    public static let defaultCatalogueTimeout: Duration = .seconds(8)

    private let catalogueTimeout: Duration
    private var catalogues: [String: RemoteCatalogue] = [:]

    public init(catalogueTimeout: Duration = MissingGameSearch.defaultCatalogueTimeout) {
        self.catalogueTimeout = catalogueTimeout
    }

    /// Looks up candidates in parallel, then considers the hinted source first and the rest
    /// by rank. Pull manifests remain sequential because hosts may meter or prompt for them.
    public func find(
        _ query: MissingGameQuery,
        hint: GameSourceHint?,
        in sources: [SearchSource],
        progress: @escaping @Sendable (String) -> Void
    ) async -> (found: FoundGame?, report: SearchReport) {
        let ordered = sources.enumerated().sorted { lhs, rhs in
            let left = (lhs.element.identity == hint?.sourceIdentity ? 0 : 1, lhs.element.rank, lhs.offset)
            let right = (rhs.element.identity == hint?.sourceIdentity ? 0 : 1, rhs.element.rank, rhs.offset)
            return left < right
        }.map(\.element)

        let timeout = catalogueTimeout
        return await withTaskGroup(of: (Int, LookupResult).self) { group in
            for (index, candidate) in ordered.enumerated() {
                group.addTask { (index, await Self.lookup(query, from: candidate.source, timeout: timeout)) }
            }
            defer { group.cancelAll() }

            var lookups: [Int: LookupResult] = [:]
            var report = SearchReport()
            var standIn: FoundGame?
            for (index, candidate) in ordered.enumerated() {
                if Task.isCancelled { break }
                progress(candidate.name)
                while lookups[index] == nil, let (finished, result) = await group.next() {
                    lookups[finished] = result
                }
                let catalogue: RemoteCatalogue?
                switch lookups.removeValue(forKey: index) ?? .failed {
                case .answered(let narrowed) where !narrowed.items.isEmpty || candidate.identity != hint?.sourceIdentity:
                    catalogue = narrowed
                case .answered, .unsupported:
                    catalogue = await self.catalogue(of: candidate)
                case .failed:
                    catalogue = nil
                }
                guard let catalogue else {
                    report.unreachable.append(candidate.name)
                    continue
                }
                report.asked.append(candidate.name)
                guard let found = await match(query, hint: hint, in: catalogue, from: candidate) else { continue }
                if found.kind == .exact { return (found, report) }
                if standIn == nil { standIn = found }
            }
            return (standIn, report)
        }
    }

    private enum LookupResult: Sendable {
        case answered(RemoteCatalogue)
        case unsupported
        case failed
    }

    private static func lookup(_ query: MissingGameQuery, from source: any LibrarySource, timeout: Duration) async -> LookupResult {
        let result = await withTimeout(timeout) {
            if let catalogue = try await source.lookup(query) {
                return LookupResult.answered(catalogue)
            }
            return .unsupported
        }
        return result ?? .failed
    }

    /// Forgets cached catalogues, for a library that changed.
    public func reset() {
        catalogues = [:]
    }

    private func catalogue(of candidate: SearchSource) async -> RemoteCatalogue? {
        if let cached = catalogues[candidate.identity] { return cached }
        let source = candidate.source
        let fetched = await Self.withTimeout(catalogueTimeout) {
            try await source.catalogue { _ in }
        }
        if let fetched { catalogues[candidate.identity] = fetched }
        return fetched
    }

    private func match(
        _ query: MissingGameQuery, hint: GameSourceHint?, in catalogue: RemoteCatalogue, from candidate: SearchSource
    ) async -> FoundGame? {
        if let item = MissingGameMatcher.hashMatches(for: query, in: catalogue).first {
            return FoundGame(source: candidate, item: item, manifest: nil, kind: .exact)
        }
        if let hint, hint.sourceIdentity == candidate.identity, hint.standInMD5 == nil,
           let item = catalogue.items.first(where: { $0.id == hint.remoteItemID && $0.systemIdentifier == query.system
               && (!query.isSingleFileImage || $0.md5 == nil || $0.md5?.caseInsensitiveCompare(query.md5) == .orderedSame) }) {
            return FoundGame(source: candidate, item: item, manifest: nil, kind: .exact)
        }
        guard let item = MissingGameMatcher.nameCandidates(for: query, in: catalogue).first else { return nil }
        let source = candidate.source
        guard let manifest = try? await source.pullManifest(for: item, progress: { _ in }),
              let kind = MissingGameMatcher.classify(manifest, for: query) else { return nil }
        // A comparable hash that differs takes precedence over an equal filename and size.
        let hashDiffers = query.isSingleFileImage && !query.md5.isEmpty
            && item.md5.map { $0.caseInsensitiveCompare(query.md5) != .orderedSame } == true
        return FoundGame(source: candidate, item: item, manifest: manifest, kind: hashDiffers ? .standIn : kind)
    }

    /// `operation`'s value, or nil when it throws or outlasts `timeout`. Returns at the timeout
    /// even when the operation ignores cancellation.
    static func withTimeout<T: Sendable>(
        _ timeout: Duration, _ operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        let gate = OnceGate<T?>()
        let work = Task { await gate.finish(try? await operation()) }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            work.cancel()
            await gate.finish(nil)
        }
        let value = await withTaskCancellationHandler {
            await gate.value()
        } onCancel: {
            work.cancel()
            Task { await gate.finish(nil) }
        }
        timer.cancel()
        return value
    }
}

/// Hands the first value given to `finish` to whoever awaits `value`.
private actor OnceGate<T: Sendable> {
    private var result: T?
    private var finished = false
    private var waiter: CheckedContinuation<T, Never>?

    func finish(_ value: T) {
        guard !finished else { return }
        finished = true
        result = value
        waiter?.resume(returning: value)
        waiter = nil
    }

    func value() async -> T {
        if finished, let result { return result }
        return await withCheckedContinuation { waiter = $0 }
    }
}
