//
//  ArtworkMatchingService.swift
//  PVLibrary
//
//  Created on 2026-03-25.
//

import Foundation
import PVLogging
import PVLookup
import PVLookupTypes
import PVSystems

// MARK: - Protocol

/// Defines the artwork-search contract used by both the import pipeline and the manual batch UI.
public protocol ArtworkMatchingServiceProtocol: Sendable {
    /// Search for artwork using a progressive fallback strategy.
    ///
    /// The strategy, in order:
    /// 1. Exact title + system identifier (most precise)
    /// 2. Cleaned title — region/revision tags stripped
    /// 3. Filename-based search
    /// 4. MD5 ROM lookup → derived title search
    ///
    /// Returns the first non-empty result set found, or `nil` if all strategies fail.
    func searchWithFallback(
        title: String,
        filename: String?,
        systemID: SystemIdentifier?,
        md5Hash: String?
    ) async throws -> [ArtworkMetadata]?
}

// MARK: - Actor implementation

/// Actor-based service that searches for game artwork using a progressive fallback strategy.
///
/// Shared by ``ArtworkSearchQueue`` (background import flow) and `BatchArtworkMatchingView`
/// (manual batch flow) to ensure consistent search behaviour across the app.
public actor ArtworkMatchingService: ArtworkMatchingServiceProtocol {
    public static let shared = ArtworkMatchingService()

    private let lookup: PVLookup

    public init(lookup: PVLookup = .shared) {
        self.lookup = lookup
    }

    // MARK: ArtworkMatchingServiceProtocol

    public func searchWithFallback(
        title: String,
        filename: String? = nil,
        systemID: SystemIdentifier?,
        md5Hash: String? = nil
    ) async throws -> [ArtworkMetadata]? {

        let originalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle  = title.cleanedForArtworkSearch()
        let cleanedFile   = (filename ?? "").cleanedForArtworkSearch()
        let upperMD5      = (md5Hash ?? "").uppercased()

        // Build search terms in preference order.
        // Deduplicate: drop "cleaned title" when it is identical to the original.
        var terms: [(label: String, term: String)] = [
            ("original title", originalTitle),
            ("cleaned title", cleanedTitle),
            ("filename", cleanedFile)
        ].filter { !$0.term.isEmpty }

        if cleanedTitle.lowercased() == originalTitle.lowercased() {
            terms.removeAll { $0.label == "cleaned title" }
        }

        var broadResults: [ArtworkMetadata]?

        // Steps 1–3: iterate terms, prefer matches that include the system identifier.
        for (label, term) in terms {
            // a. With systemID — more precise, stop immediately if found.
            if let sysID = systemID {
                if let results = try await lookup.searchArtwork(
                    byGameName: term,
                    systemID: sysID,
                    artworkTypes: .defaults
                ), !results.isEmpty {
                    ILOG("ArtworkMatchingService: \(results.count) result(s) for \(label) '\(term)' with system \(sysID.rawValue)")
                    return results
                }
            }

            // b. Without systemID — broader; keep as fallback and continue looking
            //    for a systemID match from a subsequent term.
            if broadResults == nil || broadResults!.isEmpty {
                if let results = try await lookup.searchArtwork(
                    byGameName: term,
                    systemID: nil,
                    artworkTypes: .defaults
                ), !results.isEmpty {
                    ILOG("ArtworkMatchingService: \(results.count) result(s) for \(label) '\(term)' (no system filter)")
                    broadResults = results
                }
            } else {
                // Already have broad results and no systemID hits — stop iterating.
                break
            }
        }

        if let results = broadResults, !results.isEmpty {
            return results
        }

        // Step 4: MD5 ROM lookup → derive a title and retry.
        guard !upperMD5.isEmpty else { return nil }
        ILOG("ArtworkMatchingService: No name results for '\(title)', trying MD5 lookup")

        if let romMeta = try? await lookup.searchROM(byMD5: upperMD5) {
            let romTitle = romMeta.gameTitle.cleanedForArtworkSearch()
            guard !romTitle.isEmpty else { return nil }

            var md5Results: [ArtworkMetadata]?
            if let sysID = systemID {
                md5Results = try? await lookup.searchArtwork(
                    byGameName: romTitle,
                    systemID: sysID,
                    artworkTypes: .defaults
                )
            }
            if md5Results == nil || md5Results!.isEmpty {
                md5Results = try? await lookup.searchArtwork(
                    byGameName: romTitle,
                    systemID: nil,
                    artworkTypes: .defaults
                )
            }
            if let results = md5Results, !results.isEmpty {
                ILOG("ArtworkMatchingService: \(results.count) result(s) via MD5 ROM title '\(romTitle)'")
                return results
            }
        }

        return nil
    }
}

// MARK: - String helpers (internal to PVLibrary)

extension String {
    /// Strip region/revision tags and surrounding special characters to produce a
    /// cleaner search term.  This is intentionally narrower than the more comprehensive
    /// `cleanedForSearch()` defined in PVUI — it only removes noise that reliably hurts
    /// artwork lookup precision.
    func cleanedForArtworkSearch() -> String {
        var cleaned = self

        // Remove text in brackets: [], (), {}
        let bracketPatterns = ["\\[.*?\\]", "\\(.*?\\)", "\\{.*?\\}"]
        for pattern in bracketPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        // Remove isolated special characters surrounded by spaces.
        // Hyphen ('-') is placed last in the character class so the regex engine treats it
        // as a literal character, not a range operator.  This preserves the same effective
        // character set as the original cleanedForSearch() implementation this refactors.
        let charsToRemove = ",:;!^%&*+/-"   // '-' is last → literal, no range formed
        cleaned = cleaned.replacingOccurrences(
            of: "\\s[\(charsToRemove)]\\s",
            with: " ",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
