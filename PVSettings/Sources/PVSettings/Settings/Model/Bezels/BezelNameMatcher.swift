//
//  BezelNameMatcher.swift
//  PVSettings
//
//  Which bezel artwork belongs to a game, by name.
//

import Foundation

/// Matches a game to per-game bezel artwork by name.
///
/// Artwork packs name each image after the ROM (`ActRaiser (USA).png`). A match is the same
/// name, or the same title with the closest set of tags. There is no fuzzy matching: wrong
/// artwork is worse than none.
public enum BezelNameMatcher {

    /// A name split into its title and its tags, both folded for comparison.
    struct Parsed: Equatable {
        /// The title with case, accents, punctuation and article order folded away.
        let titleKey: String
        /// The contents of every `(…)` and `[…]`, split at commas, folded.
        let tags: Set<String>
    }

    /// Region tags, most preferred first when nothing else decides.
    static let regions = ["usa", "world", "europe", "japan"]
    private static let articles = ["the", "a", "an"]

    /// The artwork for a game, or `nil`.
    ///
    /// - Parameters:
    ///   - romName: the ROM's file name without its extension.
    ///   - title: the game's title in the library, tried when the file name finds nothing.
    ///   - candidates: artwork names without extensions.
    ///   - exactOnly: only the same name matches (arcade sets, whose names are short codes).
    public static func match(romName: String, title: String? = nil, candidates: [String], exactOnly: Bool = false) -> String? {
        let wanted = fold(romName)
        guard !wanted.isEmpty else { return nil }
        if let exact = candidates.first(where: { fold($0) == wanted }) { return exact }
        guard !exactOnly else { return nil }
        let parsedCandidates = candidates.map { ($0, parse($0)) }
        if let best = bestTitleMatch(parse(romName), in: parsedCandidates) { return best }
        guard let title, !title.isEmpty else { return nil }
        return bestTitleMatch(parse(title), in: parsedCandidates)
    }

    /// Among candidates with the same title: the same region first, then the most tags in
    /// common, then the fewest tags the game does not have, then the preferred region.
    private static func bestTitleMatch(_ game: Parsed, in candidates: [(name: String, parsed: Parsed)]) -> String? {
        guard !game.titleKey.isEmpty else { return nil }
        let gameRegions = game.tags.intersection(regions)
        var best: (name: String, score: [Int])?
        for candidate in candidates where candidate.parsed.titleKey == game.titleKey {
            let tags = candidate.parsed.tags
            let regionRank = regions.firstIndex(where: tags.contains) ?? regions.count
            let score = [gameRegions.isDisjoint(with: tags) ? 0 : 1,
                         tags.intersection(game.tags).count,
                         -tags.subtracting(game.tags).count,
                         -regionRank]
            // Equal scores fall back to the name, so the answer does not depend on list order.
            let isBetter = best.map { current in
                current.score.lexicographicallyPrecedes(score) || (current.score == score && candidate.name < current.name)
            } ?? true
            if isBetter { best = (candidate.name, score) }
        }
        return best?.name
    }

    /// Case and accents folded, outer whitespace dropped.
    static func fold(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func parse(_ name: String) -> Parsed {
        var title = ""
        var tags: Set<String> = []
        var tag = ""
        var depth = 0
        for character in fold(name) {
            switch character {
            case "(", "[":
                depth += 1
            case ")", "]":
                guard depth > 0 else { continue }
                depth -= 1
                if depth == 0 {
                    for part in tag.split(separator: ",") {
                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { tags.insert(trimmed) }
                    }
                    tag = ""
                }
            default:
                if depth > 0 { tag.append(character) } else { title.append(character) }
            }
        }
        return Parsed(titleKey: titleKey(title), tags: tags)
    }

    /// `Addams Family, The` and `The Addams Family` give the same key; so do `&` and `and`,
    /// and any punctuation or spacing.
    private static func titleKey(_ title: String) -> String {
        // No-Intro puts the article before a subtitle: "Legend of Zelda, The - A Link to the Past".
        let segments = title.components(separatedBy: " - ").map { segment -> String in
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            for article in articles where trimmed.hasSuffix(", \(article)") {
                return "\(article) \(trimmed.dropLast(article.count + 2))"
            }
            return trimmed
        }
        return segments.joined(separator: " ")
            .replacingOccurrences(of: "&", with: " and ")
            .filter { $0.isLetter || $0.isNumber }
    }
}
