// String+ROMTitle.swift
// PVPrimitives
//
// Utilities for normalising ROM/game titles before database lookups and display.
// ROM filenames commonly include parenthetical and bracketed annotations
// (region, revision, language, format flags, etc.) that are absent from
// the canonical titles stored in cheat/metadata databases.

import Foundation

// MARK: - Shared ROM Tag Regex Patterns

/// Regex that matches a parenthetical annotation tag — e.g. `(USA)`, `(Rev 1)`.
private let romParenTagPattern = #"\s*\([^)]*\)"#
/// Regex that matches a bracketed annotation tag — e.g. `[!]`, `[T-En]`.
private let romBracketTagPattern = #"\s*\[[^\]]*\]"#
/// Regex that matches any parenthetical **or** bracketed tag (for `hasROMTags`).
private let romTagDetectionPattern = #"\([^)]*\)|\[[^\]]*\]"#
/// Regex that matches a disc/disk/CD/Track number group — e.g. `(Disc 2)`, `(CD1)`.
private let romDiscTagPattern = #"\s*\((?:Disk|Disc|DISK|DISC|CD|Track|disc|track|cd|disk)\s*\d+\)"#
/// Regex that matches a trailing version suffix — e.g. `v1.0`, `V2`, `v1.2.3`.
private let romVersionSuffixPattern = #"\s+[Vv]\d+(?:\.\d+)*$"#

public extension String {

    // MARK: - ROM Tag Patterns

    /// Applies parenthetical and bracketed ROM tag removal regexes without trimming
    /// or empty-string safety. Used internally by both `strippingROMTags()` and
    /// `normalizedROMTitle()` to avoid duplicating the shared patterns.
    private func removingROMTagPatterns() -> String {
        self
            .replacingOccurrences(of: romParenTagPattern, with: "", options: .regularExpression)
            .replacingOccurrences(of: romBracketTagPattern, with: "", options: .regularExpression)
    }

    /// Strips common ROM annotation patterns from a game title, returning a
    /// clean title suitable for database lookups.
    ///
    /// The following patterns are removed in order:
    /// 1. Parenthetical tags — `(USA)`, `(Japan)`, `(Rev 1)`, `(En,Fr,De)`, etc.
    /// 2. Bracketed tags — `[!]`, `[a]`, `[h]`, `[T-En]`, etc.
    /// 3. Trailing whitespace
    ///
    /// If stripping would produce an empty string the original value is returned
    /// unchanged so callers never receive a useless empty query.
    ///
    ///     "Bomberman (USA)".strippingROMTags()     // "Bomberman"
    ///     "Tetris (Japan) [!]".strippingROMTags()  // "Tetris"
    ///     "(Bad Title)".strippingROMTags()          // "(Bad Title)"
    func strippingROMTags() -> String {
        let cleaned = removingROMTagPatterns()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? self : cleaned
    }

    /// Returns `true` when the string contains at least one parenthetical or
    /// bracketed ROM annotation tag (e.g. `(USA)`, `[!]`).
    var hasROMTags: Bool {
        range(of: romTagDetectionPattern, options: .regularExpression) != nil
    }

    // MARK: - Normalized ROM Title

    /// Returns a human-readable game title normalized from a raw ROM filename.
    ///
    /// Applied transformations (in order):
    /// 1. Strip disc/disk numbering — `(Disc 2)`, `(Disk 1)`, `(CD 2)`, `(Track 3)`, etc.
    /// 2. Strip all remaining parenthetical and bracketed ROM annotation tags
    /// 3. Strip trailing version strings — `v1.0`, `v1.23`, `V2`
    /// 4. Collapse internal runs of whitespace to a single space
    /// 5. Trim leading/trailing whitespace
    ///
    /// If all transformations produce an empty string the original value is
    /// returned unchanged so callers never receive a useless empty title.
    ///
    ///     "Bomberman (USA) [!]".normalizedROMTitle()              // "Bomberman"
    ///     "Final Fantasy VII (Disc 2) (USA)".normalizedROMTitle() // "Final Fantasy VII"
    ///     "Sonic the Hedgehog v1.0".normalizedROMTitle()          // "Sonic the Hedgehog"
    ///     "Game (Beta)".normalizedROMTitle()                      // "Game"
    func normalizedROMTitle() -> String {
        var result = self

        // 1. Strip disc/disk/CD/Track numbering (e.g. "(Disc 2)", "(CD1)", "(Track 03)")
        result = result.replacingOccurrences(of: romDiscTagPattern, with: "", options: .regularExpression)

        // 2. Strip all remaining parenthetical and bracketed ROM tags (shared patterns)
        result = result.removingROMTagPatterns()

        // 3. Strip trailing version strings — v1.0, v1.2.3, V2, etc.
        result = result.replacingOccurrences(of: romVersionSuffixPattern, with: "", options: .regularExpression)

        // 4. Collapse multiple spaces
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        // 5. Trim
        result = result.trimmingCharacters(in: .whitespaces)

        return result.isEmpty ? self : result
    }

    /// Returns `true` when the title would be changed by `normalizedROMTitle()`.
    /// Useful for previewing which library entries would be affected.
    var hasNormalizableROMTitle: Bool {
        normalizedROMTitle() != self
    }
}
