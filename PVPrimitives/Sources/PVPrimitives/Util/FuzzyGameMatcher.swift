// FuzzyGameMatcher.swift
// PVPrimitives
//
// Fuzzy title matching and candidate ranking for game library lookups.
// Uses Levenshtein edit distance and token-set overlap to score how closely
// a search query matches a candidate title, after normalizing ROM annotation
// tags via `normalizedROMTitle()`.
//
// Usage:
//   let score = FuzzyGameMatcher.similarity("Castlevania", "Castlevania (USA)")
//   // → 1.0  (exact after normalization)
//
//   let ranked = FuzzyGameMatcher.rank(query: "Super Mario", candidates: titles)
//   // → sorted highest-score first

import Foundation

/// Fuzzy title matching utility for game library searches.
///
/// Normalizes titles using `normalizedROMTitle()` (strips region, revision,
/// disc, and version tags), then scores similarity via Levenshtein distance
/// and token-set overlap.
public enum FuzzyGameMatcher: Sendable {

    // MARK: - Public API

    /// Normalizes a game title for comparison by stripping ROM annotation tags.
    ///
    /// Delegates to `String.normalizedROMTitle()` which removes:
    /// - Region tags: `(USA)`, `(Japan)`, `(Europe)`, `(World)`, etc.
    /// - Revision markers: `(Rev 1)`, `(Rev A)`, `(v1.1)`, `(Beta)`, `(Proto)`
    /// - Disc labels: `(Disc 1)`, `(Disk 2)`, `(CD1)`, `(Track 3)`
    /// - No-Intro flags: `[!]`, `[b]`, `[h]`, `[o]`, `[T-Eng]`, etc.
    ///
    /// If stripping all tags would produce an empty string, the original title is
    /// returned unchanged so matchers always receive a non-empty value.
    ///
    ///     FuzzyGameMatcher.normalize("Sonic (USA) (Rev 1)")  // "Sonic"
    ///     FuzzyGameMatcher.normalize("Final Fantasy VII [!]") // "Final Fantasy VII"
    ///     FuzzyGameMatcher.normalize("(USA)")                 // "(USA)" — fallback to original
    public static func normalize(_ title: String) -> String {
        title.normalizedROMTitle()
    }

    /// Computes the Levenshtein edit distance between two strings.
    ///
    /// Returns `0` for identical strings. Operates on Unicode scalars for
    /// correctness with multi-byte characters.
    ///
    /// - Complexity: O(m × n) time and O(min(m, n)) space.
    public static func editDistance(_ a: String, _ b: String) -> Int {
        var aScalars = Array(a.unicodeScalars)
        var bScalars = Array(b.unicodeScalars)
        var m = aScalars.count
        var n = bScalars.count

        guard m > 0 else { return n }
        guard n > 0 else { return m }

        // Ensure b is the shorter string so the DP rows are O(min(m,n)) space.
        if n > m {
            swap(&aScalars, &bScalars)
            swap(&m, &n)
        }

        // Two-row DP to keep memory at O(min(m,n))
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if aScalars[i - 1] == bScalars[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + Swift.min(prev[j], curr[j - 1], prev[j - 1])
                }
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    /// Returns a similarity score in `[0.0, 1.0]` between `query` and `candidate`.
    ///
    /// Both strings are normalized before comparison. The final score is the
    /// maximum of:
    /// - **Edit-distance ratio**: `1 − (editDistance / max(|a|, |b|))`
    /// - **Token-set overlap**: Jaccard similarity on lowercase word sets,
    ///   which is robust against word-order differences.
    ///
    ///     FuzzyGameMatcher.similarity("Castlevania", "Castlevania")     // 1.0
    ///     FuzzyGameMatcher.similarity("Castlevania", "Castlevan1a")     // > 0.85
    ///     FuzzyGameMatcher.similarity("Mario", "Zelda")                 // < 0.3
    public static func similarity(_ query: String, _ candidate: String) -> Double {
        let a = normalize(query).lowercased()
        let b = normalize(candidate).lowercased()
        return score(a, b)
    }

    /// Ranks `candidates` by their similarity to `query`, highest score first.
    ///
    /// Results with a score of `0` are excluded from the output.
    ///
    ///     let results = FuzzyGameMatcher.rank(query: "Mega Man", candidates: titles)
    ///     // results[0] is the closest match
    public static func rank(query: String, candidates: [String]) -> [(title: String, score: Double)] {
        let a = normalize(query).lowercased()
        return candidates
            .map { title in (title: title, score: score(a, normalize(title).lowercased())) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
    }

    /// Returns the single best-matching candidate, or `nil` if there are no
    /// candidates with a positive similarity score (including when `candidates`
    /// is empty).
    public static func bestMatch(query: String, candidates: [String]) -> String? {
        let a = normalize(query).lowercased()
        var bestTitle: String?
        var bestScore: Double = 0.0
        for title in candidates {
            let s = score(a, normalize(title).lowercased())
            if s > bestScore {
                bestScore = s
                bestTitle = title
            }
        }
        return bestTitle
    }

    // MARK: - Private

    /// Scores two already-normalized, lowercased strings using edit-distance ratio
    /// and token-set Jaccard overlap, returning the higher of the two.
    private static func score(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return a == b ? 1.0 : 0.0 }
        guard a != b else { return 1.0 }

        let dist = editDistance(a, b)
        let maxLen = max(a.unicodeScalars.count, b.unicodeScalars.count)
        let editRatio = 1.0 - Double(dist) / Double(maxLen)

        let aTokens = Set(a.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let bTokens = Set(b.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let intersection = aTokens.intersection(bTokens).count
        let union = aTokens.union(bTokens).count
        let tokenScore = union > 0 ? Double(intersection) / Double(union) : 0.0

        return max(editRatio, tokenScore)
    }
}
