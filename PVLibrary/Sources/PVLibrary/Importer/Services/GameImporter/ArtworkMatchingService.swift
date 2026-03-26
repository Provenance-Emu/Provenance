//
//  FastArtworkLookupService.swift
//  PVLibrary
//
//  Fast, exact-match artwork lookup for use at ROM import time.
//  Uses a short timeout to avoid blocking the import pipeline.
//

import Foundation
import PVFeatureFlags
import PVLogging
import PVLookup
import PVLookupTypes
import PVSystems

// MARK: - Lookup Provider Protocol

/// Combined protocol used for dependency injection in `FastArtworkLookupService`.
/// Inherits the full `ArtworkLookupService` surface (`searchArtwork`, `getArtwork(forGameID:)`,
/// `getArtworkURLs(forRom:)`) and adds `searchROM(byMD5:)` for MD5-based fallback lookup.
public protocol ArtworkMatchingLookupProvider: ArtworkLookupService {
    /// Look up ROM metadata by MD5 hash.
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata?
}

extension PVLookup: ArtworkMatchingLookupProvider {}

// MARK: - FastArtworkLookupService

/// Performs a fast, exact-match artwork lookup during ROM import.
///
/// This service is called synchronously (with `await`) in the import pipeline so
/// that newly imported games get artwork as quickly as possible.  It is intentionally
/// limited to **exact-title matching only** — no fuzzy search, no title cleaning —
/// to stay within the ~2 second import-time budget.
///
/// If the fast lookup fails, the caller should fall back to `ArtworkSearchQueue`,
/// which runs a full multi-strategy search via `ArtworkMatchingService` in the background.
///
/// Feature-gated by the ``PVFeature/enhancedArtworkSearch`` flag.
public actor FastArtworkLookupService {

    // MARK: Singleton
    public static let shared = FastArtworkLookupService()

    // MARK: Private properties
    private let lookup: any ArtworkMatchingLookupProvider
    /// Timeout for the fast path (nanoseconds). Configurable via internal init for testing.
    private let fastTimeoutNanoseconds: UInt64

    // MARK: Init (private — use shared or inject for tests)
    private init() {
        self.lookup = PVLookup.shared
        self.fastTimeoutNanoseconds = 2_000_000_000 // 2 seconds
    }

    /// Internal init for dependency injection (used by tests).
    init(lookup: any ArtworkMatchingLookupProvider, timeoutNanoseconds: UInt64 = 2_000_000_000) {
        self.lookup = lookup
        self.fastTimeoutNanoseconds = timeoutNanoseconds
    }

    // MARK: Public API

    /// Finds the best artwork URL for a game using exact-title matching and optional MD5 lookup.
    ///
    /// - Parameters:
    ///   - exactTitle: The exact game title (from filename or database) — not cleaned or fuzzified.
    ///   - md5: The ROM's MD5 hash, used as a secondary lookup path.
    ///   - systemID: Optional system identifier to narrow results.
    /// - Returns: An artwork URL string if found within the timeout, otherwise `nil`.
    public func findArtwork(exactTitle: String, md5: String, systemID: SystemIdentifier?) async -> String? {
        guard await PVFeatureFlags.shared.isEnabled(.enhancedArtworkSearch) else { return nil }
        let title = exactTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        ILOG("FastArtworkLookupService: Fast lookup for '\(title)' (MD5: \(md5))")

        let timeoutNanoseconds = fastTimeoutNanoseconds

        // Use an unstructured Task for the search so it can be cancelled independently
        // once the timeout fires. withTaskGroup awaits all child tasks before returning,
        // so wrapping the unstructured task's value lets us return as soon as either
        // the search completes or the sentinel fires — then cancel the search task.
        let searchTask = Task {
            do {
                return try await self.performExactSearch(title: title, md5: md5, systemID: systemID)
            } catch {
                WLOG("FastArtworkLookupService: search error for '\(title)': \(error.localizedDescription)")
                return nil as String?
            }
        }

        return await withTaskGroup(of: String?.self) { group in
            // Wrap the unstructured search task so it participates in the race
            group.addTask { await searchTask.value }

            // Timeout sentinel — races against the search task
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            // Return whichever completes first (search result or timeout nil),
            // then cancel the search task so it doesn't linger in the background.
            let result = await group.next() ?? nil
            group.cancelAll()
            searchTask.cancel()
            return result
        }
    }

    // MARK: Private implementation

    /// Performs the actual exact-title + MD5 artwork lookup.
    /// Steps (in order of preference):
    ///   1. Exact title + system identifier
    ///   2. Exact title without system filter
    ///   3. ROM MD5 → ROM metadata title → artwork search
    private func performExactSearch(title: String, md5: String, systemID: SystemIdentifier?) async throws -> String? {

        // Step 1: exact title with system (most precise)
        if let sysID = systemID,
           let results = try await lookup.searchArtwork(byGameName: title, systemID: sysID, artworkTypes: .boxFront),
           !results.isEmpty {
            let best = results.first(where: { $0.type == .boxFront }) ?? results[0]
            ILOG("FastArtworkLookupService: Matched '\(title)' via exact title + system '\(sysID.rawValue)'")
            return best.url.absoluteString
        }

        // Step 2: exact title without system filter (broader)
        if let results = try await lookup.searchArtwork(byGameName: title, systemID: nil, artworkTypes: .boxFront),
           !results.isEmpty {
            let best = results.first(where: { $0.type == .boxFront }) ?? results[0]
            ILOG("FastArtworkLookupService: Matched '\(title)' via exact title (no system filter)")
            return best.url.absoluteString
        }

        // Step 3: MD5 → ROM metadata title → artwork search
        if !md5.isEmpty {
            if let romMetadata = try? await lookup.searchROM(byMD5: md5),
               !romMetadata.gameTitle.isEmpty {
                let romTitle = romMetadata.gameTitle
                if let sysID = systemID,
                   let results = try await lookup.searchArtwork(byGameName: romTitle, systemID: sysID, artworkTypes: .boxFront),
                   !results.isEmpty {
                    let best = results.first(where: { $0.type == .boxFront }) ?? results[0]
                    ILOG("FastArtworkLookupService: Matched MD5 '\(md5)' via ROM title '\(romTitle)' + system")
                    return best.url.absoluteString
                }
                if let results = try await lookup.searchArtwork(byGameName: romTitle, systemID: nil, artworkTypes: .boxFront),
                   !results.isEmpty {
                    let best = results.first(where: { $0.type == .boxFront }) ?? results[0]
                    ILOG("FastArtworkLookupService: Matched MD5 '\(md5)' via ROM title '\(romTitle)'")
                    return best.url.absoluteString
                }
            }
        }

        VLOG("FastArtworkLookupService: No exact match for '\(title)' (MD5: \(md5))")
        return nil
    }
}
