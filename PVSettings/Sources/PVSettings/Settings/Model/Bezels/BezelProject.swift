//
//  BezelProject.swift
//  PVSettings
//
//  The Bezel Project's artwork on GitHub: where it is and how its lists are read.
//

import Foundation
import Defaults

/// The two families of artwork The Bezel Project publishes. Both use the same file names.
public enum BezelProjectStyle: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {
    /// Artwork themed on the game.
    case gameArt
    /// Artwork themed on the system.
    case systemArt

    public var displayName: String {
        switch self {
        case .gameArt: return String(localized: "Game Art")
        case .systemArt: return String(localized: "System Art")
        }
    }

    /// What a repository's name starts with.
    var repositoryPrefix: String {
        switch self {
        case .gameArt: return "bezelproject-"
        case .systemArt: return "bezelprojectSA-"
        }
    }
}

/// One of The Bezel Project's repositories: a system's artwork in one style.
public struct BezelProjectRepository: Equatable, Hashable, Sendable {
    /// The account that owns every repository.
    public static let owner = "thebezelproject"
    /// The project's page, for the credit.
    public static let projectURL = URL(string: "https://github.com/\(owner)")
    /// The folder of a repository that holds the artwork.
    static let overlayFolder = "retroarch/overlay"

    public let style: BezelProjectStyle
    /// The system part of the name (`SNES`, `MegaDrive`).
    public let suffix: String

    public init(style: BezelProjectStyle, suffix: String) {
        self.style = style
        self.suffix = suffix
    }

    public var name: String { style.repositoryPrefix + suffix }

    /// One request that lists every artwork file of the repository. `HEAD` follows the
    /// default branch, so a renamed branch keeps working.
    public var listingURL: URL? {
        URL(string: "https://api.github.com/repos/\(Self.owner)/\(name)/git/trees/HEAD:\(Self.overlayFolder)?recursive=1")
    }

    /// Where an image is downloaded from. Not an API request, so it is not rate limited.
    /// - Parameter path: the image's path inside the artwork folder (`BezelProjectListing.Entry.path`).
    public func imageURL(path: String) -> URL? {
        guard var url = URL(string: "https://raw.githubusercontent.com/\(Self.owner)/\(name)/HEAD/\(Self.overlayFolder)") else {
            return nil
        }
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        return url
    }
}

/// The artwork of one repository, from GitHub's tree listing.
public struct BezelProjectListing: Codable, Equatable, Sendable {

    public enum Kind: String, Codable, Sendable {
        /// The system's own bezel, at the top of the artwork folder.
        case system
        /// A game's bezel, named after the ROM.
        case game
        /// An arcade game's bezel, named after the romset.
        case arcade
    }

    public struct Entry: Codable, Equatable, Hashable, Identifiable, Sendable {
        /// The image's path inside the artwork folder.
        public let path: String
        public let kind: Kind
        /// Bytes.
        public let size: Int

        public var id: String { path }
        /// The file name without `.png`: a ROM name, a romset or the system's name.
        public var name: String {
            let file = path.split(separator: "/").last.map(String.init) ?? path
            return String(file.dropLast(BezelProjectListing.imageSuffix.count))
        }

        public init(path: String, kind: Kind, size: Int) {
            self.path = path
            self.kind = kind
            self.size = size
        }
    }

    static let imageSuffix = ".png"
    private static let gameFolder = "GameBezels/"
    private static let arcadeFolder = "ArcadeBezels/"

    /// Every image, in GitHub's order (by path).
    public let entries: [Entry]
    /// GitHub cut the list short. None of the repositories checked does.
    public let isTruncated: Bool

    public init(entries: [Entry], isTruncated: Bool = false) {
        self.entries = entries
        self.isTruncated = isTruncated
    }

    private struct Tree: Decodable {
        struct Node: Decodable {
            let path: String
            let type: String
            let size: Int?
        }
        let tree: [Node]
        let truncated: Bool?
    }

    /// Reads the answer of `BezelProjectRepository.listingURL`.
    public init(treeJSON: Data) throws {
        let tree = try JSONDecoder().decode(Tree.self, from: treeJSON)
        entries = tree.tree.compactMap { node in
            guard node.type == "blob", node.path.lowercased().hasSuffix(Self.imageSuffix) else { return nil }
            let kind: Kind
            if node.path.hasPrefix(Self.gameFolder) {
                kind = .game
            } else if node.path.hasPrefix(Self.arcadeFolder) {
                kind = .arcade
            } else if !node.path.contains("/") {
                kind = .system
            } else {
                return nil
            }
            return Entry(path: node.path, kind: kind, size: node.size ?? 0)
        }
        isTruncated = tree.truncated ?? false
    }

    /// The entry for a game, or `nil`. Arcade sets match on the exact name only.
    public func entry(romName: String, title: String?) -> Entry? {
        for kind in [Kind.game, .arcade] {
            let ofKind = entries.filter { $0.kind == kind }
            guard !ofKind.isEmpty else { continue }
            if let name = BezelNameMatcher.match(romName: romName, title: title, candidates: ofKind.map(\.name),
                                                 exactOnly: kind == .arcade) {
                return ofKind.first { $0.name == name }
            }
        }
        return nil
    }
}

/// GitHub's answer when requests without an account run out (60 an hour per address).
public enum BezelProjectRateLimit {
    static let remainingHeader = "x-ratelimit-remaining"
    static let resetHeader = "x-ratelimit-reset"

    /// When requests are allowed again, if this response says the limit is reached.
    /// - Parameter headers: the response's headers; names are compared without case.
    public static func resetDate(statusCode: Int, headers: [String: String]) -> Date? {
        guard statusCode == 403 || statusCode == 429 else { return nil }
        let lowered = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }) { first, _ in first }
        guard lowered[remainingHeader] == "0", let reset = lowered[resetHeader].flatMap(TimeInterval.init) else { return nil }
        return Date(timeIntervalSince1970: reset)
    }
}
