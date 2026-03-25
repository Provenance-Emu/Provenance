//
//  ROMTitleNormalizer.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Normalizes ROM display titles by stripping region tags, revision tags,
/// disc/side markers, and other parenthetical noise commonly found in
/// No-Intro and Redump catalogues.
///
/// All methods are pure functions — no Realm or file-system access occurs here.
public enum ROMTitleNormalizer {

    // MARK: - Public API

    /// Returns a normalized version of the given ROM title.
    /// If no change is required the original string is returned unchanged.
    public static func normalize(_ title: String) -> String {
        var result = title

        result = stripParentheticals(result)
        result = stripBracketedTags(result)
        result = fixArticle(result)
        result = collapseWhitespace(result)

        return result
    }

    /// Returns `true` when `normalize(_:)` would produce a different string.
    public static func needsNormalization(_ title: String) -> Bool {
        return normalize(title) != title
    }

    // MARK: - Private helpers

    /// Remove common parenthetical groups such as:
    ///   (USA), (Europe), (Japan), (World), (En,Fr,De), (Rev A), (Rev 1),
    ///   (v1.1), (Disc 1), (Disk 2), (Side A), (Proto), (Beta), (Demo),
    ///   (Unl), (Pirate), (Hack), (Homebrewː), (Aftermarket), (Sample),
    ///   (Alt), (Alt 1), (Kiosk), (Limited Edition), (Collector's Edition),
    ///   (BIOS), (Program), (Data), (Edu), (Test Program), (Check Program)
    private static func stripParentheticals(_ title: String) -> String {
        // Patterns matched inside ( … )
        let noisePatterns: [String] = [
            // Regions
            "USA", "Europe", "Japan", "World", "Australia", "Brazil", "Canada",
            "China", "France", "Germany", "Italy", "Korea", "Netherlands",
            "Russia", "Spain", "Sweden", "En", "Ja", "Fr", "De", "Es", "It",
            "Pt", "Nl", "Sv", "Ko", "Zh", "Ru", "Pl", "No", "Da", "Fi",
            // Multi-language comma-separated lists, e.g. "En,Fr,De"
            // handled by a separate regex below

            // Versions / revisions
            "Rev [A-Z0-9]+", "Rev[A-Z]", "v[0-9]+\\.[0-9]+", "v[0-9]+",
            "Version [0-9]+", "Version [0-9]+\\.[0-9]+",
            "[0-9]+\\.[0-9]+",

            // Disc / side markers
            "Disc [0-9]+", "Disk [0-9]+", "Side [AB]", "Side [0-9]+",
            "CD [0-9]+", "Volume [0-9]+", "Vol\\. [0-9]+", "Vol [0-9]+",

            // Release status
            "Proto", "Prototype", "Beta", "Alpha", "Demo", "Sample",
            "Preview", "Pre-release", "Pre\\-release",
            "Aftermarket", "Unl", "Pirate", "Hack", "Homebrewː?",
            "Kiosk", "Limited Edition", "Collector's Edition",
            "Collector.s Edition",

            // Technical/program tags
            "BIOS", "Program", "Data", "Edu", "Test Program", "Check Program",
            "Enhancement Chip", "CGB", "SGB", "GBA Enhanced", "NES Enhanced",

            // Miscellaneous
            "Alt", "Alt [0-9]+", "En Espa.ol",
            "Bonus Disc", "Bonus Disk",
        ]

        var result = title

        // Strip multi-language tag, e.g. (En,Fr,De)
        result = result.replacingOccurrences(
            of: "\\([A-Za-z]{2}(?:,[A-Za-z]{2})+\\)",
            with: "",
            options: .regularExpression
        )

        // Strip each noise pattern
        for pattern in noisePatterns {
            result = result.replacingOccurrences(
                of: "\\(\\s*\(pattern)\\s*\\)",
                with: "",
                options: .regularExpression
            )
        }

        return result
    }

    /// Remove bracketed tags, e.g. [!], [T-En], [h1], [a1], [b], [T+En1.0],
    /// used heavily in GoodTools-style naming.
    private static func stripBracketedTags(_ title: String) -> String {
        title.replacingOccurrences(
            of: "\\[[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
    }

    /// Move leading article to the end if it's in a "The, Article" / "A, Article"
    /// pattern, or move a trailing ", The" / ", A" back to the front.
    ///
    /// Examples:
    ///   "Legend of Zelda, The" → "The Legend of Zelda"
    ///   "Incredible Crash Dummies, The" → "The Incredible Crash Dummies"
    ///   "Adventures of Lolo, The" → "The Adventures of Lolo"
    ///
    /// **Note:** We do NOT move "The" from the front to the back — that would
    /// conflict with the actual display title users see in-app.
    private static func fixArticle(_ title: String) -> String {
        let pattern = "^(.+),\\s+(The|A|An)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return title
        }
        let range = NSRange(title.startIndex..., in: title)
        if let match = regex.firstMatch(in: title, range: range),
           match.numberOfRanges == 3,
           let bodyRange = Range(match.range(at: 1), in: title),
           let articleRange = Range(match.range(at: 2), in: title) {
            let body = String(title[bodyRange])
            let article = String(title[articleRange])
            // Capitalise article correctly
            return "\(article) \(body)"
        }
        return title
    }

    /// Collapse multiple spaces and trim leading/trailing whitespace.
    private static func collapseWhitespace(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
