//
//  BezelProjectService.swift
//  PVUI
//
//  The Bezel Project's artwork, fetched from its GitHub repositories on demand.
//

import Foundation
import PVFileSystem
import PVLogging
import PVSettings

/// The running game as the bezel options and The Bezel Project's lists know it.
public struct ExternalDisplayGameContext: Equatable, Sendable {
    public let md5: String
    /// A `SystemIdentifier` raw value.
    public let systemID: String
    /// The ROM's file name without its extension: what artwork is named after.
    public let romName: String
    public let title: String

    public init(md5: String, systemID: String, romName: String, title: String) {
        self.md5 = md5
        self.systemID = systemID
        self.romName = romName
        self.title = title
    }
}

/// The artwork found for the game being played, kept between updates of the display so the
/// lookup runs once per game and style.
@MainActor
final class ExternalDisplayGameArtwork {
    static let shared = ExternalDisplayGameArtwork()

    private var game: String?
    private var style: BezelProjectStyle?
    private var bezelID: String?

    /// Notes that a lookup for `game` in `style` starts now. `false` when that lookup was
    /// already started, whether or not it has finished.
    func begin(game: String, style: BezelProjectStyle) -> Bool {
        guard self.game != game || self.style != style else { return false }
        self.game = game
        self.style = style
        bezelID = nil
        return true
    }

    /// Keeps what a lookup found. `false` when another game or style has been looked up since.
    func finish(game: String, style: BezelProjectStyle, bezelID: String) -> Bool {
        guard self.game == game, self.style == style else { return false }
        self.bezelID = bezelID
        return true
    }

    /// The artwork for `game` (a `TVBezel` id), once found.
    func bezelID(forGame game: String?) -> String? {
        game != nil && game == self.game ? bezelID : nil
    }
}

/// Lists and downloads The Bezel Project's artwork. Nothing of theirs ships with the app.
///
/// A system's list is one GitHub API request, kept for `listLifetime`. GitHub allows 60 such
/// requests an hour from one address without an account; images are not counted. Matching a
/// game to its artwork happens here, on the device: GitHub sees only which lists and images
/// were fetched.
public actor BezelProjectService {

    public static let shared = BezelProjectService()

    public enum ServiceError: Error, Equatable {
        /// GitHub's hourly limit is used up until this time.
        case rateLimited(until: Date)
        /// GitHub answered with this status.
        case unavailable(status: Int)
        /// No answer at all.
        case offline
        /// The image is too large to take, or is not a bezel.
        case badImage(TVBezelLibrary.ImportProblem)

        public var message: String {
            switch self {
            case .rateLimited(let until):
                return String(localized: "GitHub is limiting requests from this network until \(until.formatted(date: .omitted, time: .shortened)).")
            case .unavailable(let status):
                return String(localized: "GitHub answered with an error (\(status)).")
            case .offline:
                return String(localized: "GitHub could not be reached.")
            case .badImage(let problem):
                return problem.message
            }
        }
    }

    /// How long a system's list is kept before it is fetched again.
    static let listLifetime: TimeInterval = 30 * 24 * 60 * 60
    /// How long a list that failed to load is left alone before the next automatic try.
    static let retryDelay: TimeInterval = 5 * 60
    /// Images larger than this are not downloaded.
    static let maximumImageBytes = 32 * 1024 * 1024
    private static let cacheFolder = "BezelProject"
    private static let tableFile = "bezel-project.json"
    private static let userAgent = "Provenance"
    private static let statusNotFound = 404

    private struct Table: Decodable {
        let systems: [String: [String]]
    }

    private struct CachedListing: Codable {
        let fetched: Date
        let listing: BezelProjectListing
    }

    /// System identifier to the repository suffixes that hold its artwork, in the order they
    /// are searched. Systems with two screens and systems the project does not cover are absent.
    public static let systems: [String: [String]] = {
        guard let url = TVBezelCatalog.folderURL?.appendingPathComponent(tableFile),
              let table = try? JSONDecoder().decode(Table.self, from: Data(contentsOf: url)) else {
            ELOG("Bezel Project: no system table in the bundle")
            return [:]
        }
        return table.systems
    }()

    public static func repositories(systemID: String, style: BezelProjectStyle) -> [BezelProjectRepository] {
        (systems[systemID] ?? []).map { BezelProjectRepository(style: style, suffix: $0) }
    }

    /// Where a repository's downloads live inside the bezel library.
    public static func libraryFolder(for repository: BezelProjectRepository) -> String {
        "\(TVBezelLibrary.bezelProjectFolder)/\(repository.name)"
    }

    static func libraryPath(for entry: BezelProjectListing.Entry, in repository: BezelProjectRepository) -> String {
        "\(libraryFolder(for: repository))/\(entry.path)"
    }

    private let session: URLSession
    private let library: TVBezelLibrary
    private let cacheURL: URL
    private var listings: [String: CachedListing] = [:]
    private var failures: [String: Date] = [:]

    init(session: URLSession = .shared, library: TVBezelLibrary = .shared,
         cacheURL: URL = URL.cachesPath.appendingPathComponent(BezelProjectService.cacheFolder, isDirectory: true)) {
        self.session = session
        self.library = library
        self.cacheURL = cacheURL
    }

    // MARK: - Lists

    /// A repository's artwork. From memory or disk while fresh, else from GitHub; when GitHub
    /// cannot answer, an old list is better than none.
    public func listing(for repository: BezelProjectRepository, forceRefresh: Bool = false) async throws -> BezelProjectListing {
        let cached = cachedListing(for: repository)
        if let cached, !forceRefresh, Date().timeIntervalSince(cached.fetched) < Self.listLifetime {
            return cached.listing
        }
        do {
            let listing = try await fetchListing(for: repository)
            store(CachedListing(fetched: Date(), listing: listing), for: repository)
            failures[repository.name] = nil
            return listing
        } catch {
            failures[repository.name] = Date()
            if let cached { return cached.listing }
            throw error
        }
    }

    private func fetchListing(for repository: BezelProjectRepository) async throws -> BezelProjectListing {
        guard let url = repository.listingURL else { throw ServiceError.offline }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await load { try await self.session.data(for: request) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // The project has no repository for this system in this style.
        if status == Self.statusNotFound { return BezelProjectListing(entries: []) }
        try check(response)
        do {
            let listing = try BezelProjectListing(treeJSON: data)
            ILOG("Bezel Project: \(repository.name) lists \(listing.entries.count) images")
            return listing
        } catch {
            ELOG("Bezel Project: \(repository.name) list could not be read: \(error)")
            throw ServiceError.unavailable(status: status)
        }
    }

    private func cachedListing(for repository: BezelProjectRepository) -> CachedListing? {
        if let cached = listings[repository.name] { return cached }
        guard let data = try? Data(contentsOf: cacheFile(for: repository)),
              let cached = try? JSONDecoder().decode(CachedListing.self, from: data) else { return nil }
        listings[repository.name] = cached
        return cached
    }

    private func store(_ cached: CachedListing, for repository: BezelProjectRepository) {
        listings[repository.name] = cached
        do {
            try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
            try JSONEncoder().encode(cached).write(to: cacheFile(for: repository), options: .atomic)
        } catch {
            WLOG("Bezel Project: could not keep the list of \(repository.name): \(error)")
        }
    }

    private func cacheFile(for repository: BezelProjectRepository) -> URL {
        cacheURL.appendingPathComponent(repository.name + ".json")
    }

    // MARK: - Images

    /// The bezel for `entry`, downloading its image when it is not on the device yet.
    ///
    /// - Parameters:
    ///   - systemID: the system a system bezel belongs to, so it can stand for that system.
    ///   - listed: show it in the picker. A bezel already there is never taken off it.
    public func bezel(for entry: BezelProjectListing.Entry, in repository: BezelProjectRepository,
                      systemID: String?, listed: Bool) async throws -> TVBezel {
        let relativePath = Self.libraryPath(for: entry, in: repository)
        if let existing = library.bezel(relativePath: relativePath) {
            guard listed, !existing.isListed else { return existing }
            library.update(id: existing.id, listed: true)
            return library.bezel(id: existing.id) ?? existing
        }
        guard entry.size <= Self.maximumImageBytes else { throw ServiceError.badImage(.tooLarge) }
        guard let url = repository.imageURL(path: entry.path) else { throw ServiceError.offline }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (file, response) = try await load { try await self.session.download(for: request) }
        defer { try? FileManager.default.removeItem(at: file) }
        try check(response)
        do {
            return try library.add(imageAt: file, relativePath: relativePath, name: Self.displayName(for: entry),
                                   system: entry.kind == .system ? systemID : nil, source: .bezelProject, listed: listed)
        } catch {
            throw ServiceError.badImage((error as? TVBezelLibrary.ImportProblem) ?? .init(error))
        }
    }

    /// Artwork made for a game: on the device already, or downloaded now. `nil` when the
    /// project has none for it, and when GitHub cannot be asked (tried again later).
    public func artwork(for game: ExternalDisplayGameContext, style: BezelProjectStyle) async -> TVBezel? {
        for repository in Self.repositories(systemID: game.systemID, style: style) {
            if let failed = failures[repository.name], Date().timeIntervalSince(failed) < Self.retryDelay,
               cachedListing(for: repository) == nil {
                continue
            }
            do {
                let listing = try await listing(for: repository)
                guard let entry = listing.entry(romName: game.romName, title: game.title) else { continue }
                return try await bezel(for: entry, in: repository, systemID: game.systemID, listed: false)
            } catch {
                ILOG("Bezel Project: no artwork for '\(game.romName)' from \(repository.name): \(error)")
            }
        }
        return nil
    }

    /// A system bezel is named with dashes (`Super-Nintendo-Entertainment-System`).
    static func displayName(for entry: BezelProjectListing.Entry) -> String {
        entry.kind == .system ? entry.name.replacingOccurrences(of: "-", with: " ") : entry.name
    }

    // MARK: - Network

    private func load<Value>(_ request: () async throws -> (Value, URLResponse)) async throws -> (Value, URLResponse) {
        do {
            return try await request()
        } catch {
            throw ServiceError.offline
        }
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ServiceError.offline }
        guard !(200 ..< 300).contains(http.statusCode) else { return }
        let headers = Dictionary(http.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let key = key as? String else { return nil }
            return (key, "\(value)")
        }) { first, _ in first }
        if let reset = BezelProjectRateLimit.resetDate(statusCode: http.statusCode, headers: headers) {
            throw ServiceError.rateLimited(until: reset)
        }
        throw ServiceError.unavailable(status: http.statusCode)
    }
}
