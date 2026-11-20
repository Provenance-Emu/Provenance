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

    /// Asks `sources` by rank, the hinted one first. Returns the first exact match, else the
    /// first stand-in seen, else nil. At most one manifest is requested from each source.
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

        var report = SearchReport()
        var standIn: FoundGame?
        for candidate in ordered {
            if Task.isCancelled { break }
            progress(candidate.name)
            guard let catalogue = await catalogue(of: candidate) else {
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
           let item = catalogue.items.first(where: { $0.id == hint.remoteItemID && $0.systemIdentifier == query.system }) {
            return FoundGame(source: candidate, item: item, manifest: nil, kind: .exact)
        }
        guard let item = MissingGameMatcher.nameCandidates(for: query, in: catalogue).first else { return nil }
        let source = candidate.source
        guard let manifest = try? await source.pullManifest(for: item, progress: { _ in }),
              let kind = MissingGameMatcher.classify(manifest, for: query) else { return nil }
        return FoundGame(source: candidate, item: item, manifest: manifest, kind: kind)
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
