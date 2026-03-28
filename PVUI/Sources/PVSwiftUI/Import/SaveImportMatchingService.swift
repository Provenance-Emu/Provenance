//
//  SaveImportMatchingService.swift
//  PVUI / PVSwiftUI
//
//  Created by Agent on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Matches a save-export bundle to a game in the local library.
//  Part of issue #3555 (Save Import UI with game-matching).
//

import Foundation
import PVLibrary
import PVRealm
import RealmSwift

// MARK: - SaveImportMatchResult

/// Result of a save bundle → game matching attempt.
///
/// Uses `SaveMatchConfidence` from `SaveImportExportProtocols` (shared with the
/// drag-drop delegate and future import services).
public struct SaveImportMatchResult {
    public let game: PVGame?
    /// How well the bundle matched a game in the library.
    public let confidence: SaveMatchConfidence

    public init(game: PVGame?, confidence: SaveMatchConfidence) {
        self.game = game
        self.confidence = confidence
    }
}

extension SaveImportMatchResult: Equatable {
    public static func == (lhs: SaveImportMatchResult, rhs: SaveImportMatchResult) -> Bool {
        lhs.confidence == rhs.confidence &&
            lhs.game?.md5Hash == rhs.game?.md5Hash
    }
}

// MARK: - SaveImportMatchingService

/// Attempts to match a save bundle to a game in the local Realm library.
///
/// Matching strategy (in order):
/// 1. **Exact MD5** — reads `manifest.json` from the `.zip` bundle and looks up the game
///    via `RomDatabase.sharedInstance.object(ofType:wherePrimaryKeyEquals:)`.
/// 2. **Filename heuristic** — strips region/revision annotations and computes Jaccard
///    token-similarity between the bundle filename and all game titles.
/// 3. **Manual** — returned when both automated strategies find nothing good enough.
///
/// `@unchecked Sendable` is safe: `SaveImportMatchingService` has no stored properties
/// (only a static singleton). All Realm access is gated to `@MainActor`.
public final class SaveImportMatchingService: @unchecked Sendable {

    public static let shared = SaveImportMatchingService()
    private init() {}

    // MARK: - Public API

    /// Attempt to match `url` to a game in the local library.
    ///
    /// Must be called on the MainActor (Realm access is main-thread only).
    ///
    /// - Parameter url: A `.zip` save-export bundle or a raw battery save file (`.sav`/`.srm`/`.ram`).
    /// - Returns: The best `SaveImportMatchResult` found.
    @MainActor
    public func match(bundleURL url: URL) async -> SaveImportMatchResult {
        // Step 1: MD5 exact match (meaningful only for .zip/.pvsave bundles with a manifest)
        let ext = url.pathExtension.lowercased()
        if ext == "zip" || ext == "pvsave" {
            let md5 = await Task.detached(priority: .userInitiated) {
                SaveExporter.shared.gameMD5(inBundleAt: url)
            }.value

            if let md5,
               let game = RomDatabase.sharedInstance.object(
                   ofType: PVGame.self,
                   wherePrimaryKeyEquals: md5.uppercased()
               ) {
                let frozen = game.isFrozen ? game : game.freeze()
                return SaveImportMatchResult(game: frozen, confidence: .exact)
            }
        }

        // Step 2: Filename heuristic across all library games
        let normalizedBundle = Self.normalize(url.deletingPathExtension().lastPathComponent)

        // Realm access must happen on the main thread (we are @MainActor here).
        // Freeze objects before handing off to the background matching task.
        let frozenGames: [PVGame] = PVGame.all.toArray().map { $0.isFrozen ? $0 : $0.freeze() }

        // CPU-intensive scoring is safe to run on a background thread with frozen objects.
        let (bestGame, bestScore) = await Task.detached(priority: .userInitiated) {
            var best: PVGame?
            var topScore = 0
            for game in frozenGames {
                let score = Self.similarity(normalizedBundle, Self.normalize(game.title))
                if score > topScore {
                    topScore = score
                    best = game
                }
            }
            return (best, topScore)
        }.value

        // Require ≥60% Jaccard token-overlap for a "probable" match
        if bestScore >= 60, let game = bestGame {
            return SaveImportMatchResult(game: game, confidence: .probable)
        }

        return SaveImportMatchResult(game: nil, confidence: .manual)
    }

    // MARK: - Helpers

    /// Normalise a title/filename for matching:
    /// lowercase → strip bracketed annotations → remove punctuation → collapse whitespace.
    static func normalize(_ input: String) -> String {
        var s = input.lowercased()
        // Strip parenthesised/bracketed annotations: "(USA)", "[!]", "(Rev A)", etc.
        s = s.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
        // Replace non-alphanumeric characters with spaces
        s = s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
        // Collapse whitespace and drop empty tokens
        return s.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Returns a Jaccard similarity score (0–100) between the token sets of two normalised strings.
    static func similarity(_ a: String, _ b: String) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let tokA = Set(a.components(separatedBy: " ").filter { !$0.isEmpty })
        let tokB = Set(b.components(separatedBy: " ").filter { !$0.isEmpty })
        let intersection = tokA.intersection(tokB).count
        let union = tokA.union(tokB).count
        guard union > 0 else { return 0 }
        return Int(Double(intersection) / Double(union) * 100)
    }
}
