//
//  SkinCatalogService.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2514)
//

import Foundation
import PVLogging

// MARK: - Errors

/// Errors that can occur when working with the skin catalog.
public enum SkinCatalogError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noCachedData
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid catalog URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode catalog: \(error.localizedDescription)"
        case .noCachedData:
            return "No cached catalog data available."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - SkinCatalogService

/// Actor-based service for fetching, caching, and querying the remote skin catalog.
///
/// Usage:
/// ```swift
/// let catalog = try await SkinCatalogService.shared.fetchCatalog()
/// let gbaSkins = try await SkinCatalogService.shared.filterSkins(system: "gba")
/// ```
///
/// The service maintains both an in-memory cache and a disk cache at
/// `<Caches>/skin_catalog.json`. The disk cache is used as a fallback when
/// the network is unavailable.
public actor SkinCatalogService {

    // MARK: - Singleton

    public static let shared = SkinCatalogService()

    // MARK: - Configuration

    /// The remote URL where the catalog JSON is hosted.
    private let catalogURL: URL

    /// How long the in-memory cache is considered fresh (24 hours).
    private let cacheTTL: TimeInterval

    /// Custom URLSession (injectable for testing).
    private let urlSession: URLSession

    // MARK: - State

    /// In-memory cached catalog.
    private var cachedCatalog: SkinCatalog?

    /// When the in-memory cache was last populated.
    private var lastFetchDate: Date?

    // MARK: - Init

    public init(
        catalogURL: URL = URL(string: "https://raw.githubusercontent.com/Provenance-Emu/skins/main/catalog.json")!,
        cacheTTL: TimeInterval = 24 * 60 * 60,
        urlSession: URLSession = .shared
    ) {
        self.catalogURL = catalogURL
        self.cacheTTL = cacheTTL
        self.urlSession = urlSession
    }

    // MARK: - Public API

    /// Fetch the full skin catalog.
    ///
    /// Returns the in-memory cached version if it is still fresh (< 24 hours old),
    /// unless `forceRefresh` is `true`.
    ///
    /// On network failure the service falls back to the on-disk cache. If no cache
    /// exists at all, the original error is thrown.
    ///
    /// - Parameter forceRefresh: When `true`, always fetches from the network.
    /// - Returns: The decoded `SkinCatalog`.
    public func fetchCatalog(forceRefresh: Bool = false) async throws -> SkinCatalog {
        // Return memory cache if fresh
        if !forceRefresh, let cached = cachedCatalog, let lastFetch = lastFetchDate {
            let age = Date().timeIntervalSince(lastFetch)
            if age < cacheTTL {
                DLOG("SkinCatalogService: Returning memory-cached catalog (\(cached.skins.count) skins, age: \(Int(age))s)")
                return cached
            }
        }

        // Try to load from disk cache first if no memory cache
        if !forceRefresh, cachedCatalog == nil {
            if let diskCatalog = loadFromDiskCache() {
                DLOG("SkinCatalogService: Loaded catalog from disk cache (\(diskCatalog.skins.count) skins)")
                cachedCatalog = diskCatalog
                lastFetchDate = Date()
                // Still attempt a background refresh if disk cache is old, but return immediately
            }
        }

        // Fetch from network
        do {
            let catalog = try await fetchFromNetwork()
            cachedCatalog = catalog
            lastFetchDate = Date()
            saveToDiskCache(catalog)
            DLOG("SkinCatalogService: Fetched catalog from network (\(catalog.skins.count) skins)")
            return catalog
        } catch {
            ELOG("SkinCatalogService: Network fetch failed: \(error.localizedDescription)")

            // Fall back to memory cache
            if let cached = cachedCatalog {
                WLOG("SkinCatalogService: Falling back to cached catalog (\(cached.skins.count) skins)")
                return cached
            }

            // Fall back to disk cache
            if let diskCatalog = loadFromDiskCache() {
                WLOG("SkinCatalogService: Falling back to disk cache (\(diskCatalog.skins.count) skins)")
                cachedCatalog = diskCatalog
                lastFetchDate = Date()
                return diskCatalog
            }

            // Fall back to bundled seed catalog
            if let bundledCatalog = loadBundledSeed() {
                WLOG("SkinCatalogService: Falling back to bundled seed catalog (\(bundledCatalog.skins.count) skins)")
                cachedCatalog = bundledCatalog
                lastFetchDate = Date()
                return bundledCatalog
            }

            // No cache available at all
            throw SkinCatalogError.networkError(error)
        }
    }

    /// Search skins by query string.
    ///
    /// Performs a case-insensitive search across skin name, author, tags, and source fields.
    ///
    /// - Parameters:
    ///   - query: The search text.
    ///   - system: Optional system short code to narrow results (e.g. "gba").
    /// - Returns: Matching catalog entries.
    public func searchSkins(query: String, system: String? = nil) async throws -> [SkinCatalogEntry] {
        let catalog = try await fetchCatalog()
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lowercasedQuery.isEmpty else {
            // Empty query: return all skins, optionally filtered by system
            if let system = system {
                return catalog.skins.filter { $0.systems.contains(system.lowercased()) }
            }
            return catalog.skins
        }

        return catalog.skins.filter { entry in
            // System filter
            if let system = system {
                guard entry.systems.contains(system.lowercased()) else { return false }
            }

            // Text search across name, author, tags, source
            if entry.name.lowercased().contains(lowercasedQuery) { return true }
            if let author = entry.author, author.lowercased().contains(lowercasedQuery) { return true }
            if let tags = entry.tags, tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) { return true }
            if let source = entry.source, source.lowercased().contains(lowercasedQuery) { return true }

            return false
        }
    }

    /// Filter and sort skins by various criteria.
    ///
    /// - Parameters:
    ///   - system: Optional system short code filter.
    ///   - tags: Optional tags to filter by (entries must contain at least one matching tag).
    ///   - deviceSupport: Optional device filters (e.g. ["iphone", "ipad"]).
    ///   - sortBy: How to sort the results.
    /// - Returns: Filtered and sorted catalog entries.
    public func filterSkins(
        system: String? = nil,
        tags: [String]? = nil,
        deviceSupport: [String]? = nil,
        sortBy: SkinSortOption = .popular
    ) async throws -> [SkinCatalogEntry] {
        let catalog = try await fetchCatalog()
        var results = catalog.skins

        // Filter by system
        if let system = system {
            let lowerSystem = system.lowercased()
            results = results.filter { $0.systems.contains(lowerSystem) }
        }

        // Filter by tags (match any)
        if let tags = tags, !tags.isEmpty {
            let lowerTags = Set(tags.map { $0.lowercased() })
            results = results.filter { entry in
                guard let entryTags = entry.tags else { return false }
                let entryLowerTags = Set(entryTags.map { $0.lowercased() })
                return !entryLowerTags.isDisjoint(with: lowerTags)
            }
        }

        // Filter by device support (match any).
        // Use prefix matching so broad filter tokens (e.g. "iphone") match
        // specific catalog variants (e.g. "iphone-x", "iphone-legacy").
        if let deviceSupport = deviceSupport, !deviceSupport.isEmpty {
            let lowerFilters = deviceSupport.map { $0.lowercased() }
            results = results.filter { entry in
                guard let entryDevices = entry.deviceSupport else { return true } // No restriction = all devices
                let entryLower = entryDevices.map { $0.lowercased() }
                return lowerFilters.contains { filter in
                    entryLower.contains { device in
                        device == filter || device.hasPrefix(filter + "-") || filter.hasPrefix(device + "-")
                    }
                }
            }
        }

        // Sort
        results = sortEntries(results, by: sortBy)

        return results
    }

    /// Get all unique system short codes that have at least one skin in the catalog.
    ///
    /// - Returns: Sorted array of system codes.
    public func availableSystems() async throws -> [String] {
        let catalog = try await fetchCatalog()
        let systems = Set(catalog.skins.flatMap { $0.systems })
        return systems.sorted()
    }

    /// Get all unique tags present in the catalog.
    ///
    /// - Returns: Sorted array of tags.
    public func availableTags() async throws -> [String] {
        let catalog = try await fetchCatalog()
        let tags = Set(catalog.skins.compactMap { $0.tags }.flatMap { $0 })
        return tags.sorted()
    }

    /// Invalidate both memory and disk caches, forcing the next fetch to go to the network.
    public func invalidateCache() {
        cachedCatalog = nil
        lastFetchDate = nil
        removeDiskCache()
        DLOG("SkinCatalogService: Cache invalidated")
    }

    // MARK: - Private Helpers

    /// Fetch the catalog JSON from the remote URL.
    private func fetchFromNetwork() async throws -> SkinCatalog {
        DLOG("SkinCatalogService: Fetching catalog from \(catalogURL)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(from: catalogURL)
        } catch {
            throw SkinCatalogError.networkError(error)
        }

        // Validate HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let urlError = URLError(.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"
                ])
                throw SkinCatalogError.networkError(urlError)
            }
        }

        // Decode
        do {
            let decoder = Self.makeDecoder()
            let catalog = try decoder.decode(SkinCatalog.self, from: data)
            return catalog
        } catch {
            ELOG("SkinCatalogService: Decoding error: \(error)")
            throw SkinCatalogError.decodingError(error)
        }
    }

    /// Sort entries by the given option.
    private func sortEntries(_ entries: [SkinCatalogEntry], by option: SkinSortOption) -> [SkinCatalogEntry] {
        switch option {
        case .popular:
            return entries.sorted { ($0.downloadCount ?? 0) > ($1.downloadCount ?? 0) }
        case .recent:
            return entries.sorted { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }
        case .alphabetical:
            return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .rating:
            return entries.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    // MARK: - Disk Cache

    /// Path to the on-disk catalog cache file.
    private var diskCachePath: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("skin_catalog.json")
    }

    /// Load the catalog from the on-disk cache.
    private func loadFromDiskCache() -> SkinCatalog? {
        let path = diskCachePath
        guard FileManager.default.fileExists(atPath: path.path) else {
            DLOG("SkinCatalogService: No disk cache at \(path.path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: path)
            let decoder = Self.makeDecoder()
            let catalog = try decoder.decode(SkinCatalog.self, from: data)
            DLOG("SkinCatalogService: Loaded \(catalog.skins.count) skins from disk cache")
            return catalog
        } catch {
            ELOG("SkinCatalogService: Failed to load disk cache: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save the catalog to the on-disk cache.
    private func saveToDiskCache(_ catalog: SkinCatalog) {
        let path = diskCachePath
        do {
            let encoder = Self.makeEncoder()
            let data = try encoder.encode(catalog)
            try data.write(to: path, options: .atomic)
            DLOG("SkinCatalogService: Saved \(catalog.skins.count) skins to disk cache at \(path.path)")
        } catch {
            ELOG("SkinCatalogService: Failed to save disk cache: \(error.localizedDescription)")
        }
    }

    /// Remove the on-disk cache file.
    private func removeDiskCache() {
        let path = diskCachePath
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - Bundled Seed Catalog

    /// Load the bundled seed catalog from the app bundle as the ultimate fallback.
    private func loadBundledSeed() -> SkinCatalog? {
        guard let url = Bundle.module.url(forResource: "catalog_seed", withExtension: "json") else {
            DLOG("SkinCatalogService: No bundled catalog_seed.json found")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = Self.makeDecoder()
            let catalog = try decoder.decode(SkinCatalog.self, from: data)
            DLOG("SkinCatalogService: Loaded \(catalog.skins.count) skins from bundled seed")
            return catalog
        } catch {
            ELOG("SkinCatalogService: Failed to load bundled seed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - JSON Coding

    /// Create a JSONDecoder configured with ISO 8601 date strategy.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Create a JSONEncoder configured with ISO 8601 date strategy.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
