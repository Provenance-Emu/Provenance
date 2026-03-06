// String+ROMTitle.swift
// PVPrimitives
//
// Utilities for normalising ROM/game titles before database lookups.
// ROM filenames commonly include parenthetical and bracketed annotations
// (region, revision, language, format flags, etc.) that are absent from
// the canonical titles stored in cheat/metadata databases.

import Foundation

public extension String {

    // MARK: - ROM Tag Patterns

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
        let cleaned = self
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\[[^\]]*\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? self : cleaned
    }

    /// Returns `true` when the string contains at least one parenthetical or
    /// bracketed ROM annotation tag (e.g. `(USA)`, `[!]`).
    var hasROMTags: Bool {
        range(of: #"\([^)]*\)|\[[^\]]*\]"#, options: .regularExpression) != nil
    }
}
