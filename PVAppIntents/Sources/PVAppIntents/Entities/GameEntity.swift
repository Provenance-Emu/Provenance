//
//  GameEntity.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// An `AppEntity` representing a game in the Provenance library.
///
/// This entity is used by `LaunchGameIntent`, `ToggleFavoriteIntent`,
/// and the widget timeline provider to surface games in Siri, Spotlight,
/// and the Shortcuts app.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct GameEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Game")
    public static var defaultQuery = GameEntityQuery()

    // MARK: - Stored Properties

    /// The ROM's MD5 hash — used as the stable, unique identifier.
    public var id: String

    /// Human-readable game title.
    public var title: String

    /// Name of the emulated system (e.g. "Super Nintendo").
    public var systemName: String

    /// System identifier raw value (e.g. "com.provenance.snes").
    public var systemIdentifier: String

    /// Whether the user has marked this game as a favourite.
    public var isFavorite: Bool

    /// Last date/time the game was played, if any.
    public var lastPlayedDate: Date?

    /// URL of the cached box-art image, suitable for display in widget / Shortcuts UI.
    public var artworkURL: URL?

    /// Deep-link URL that opens this game in the main app.
    public var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "provenance"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "md5", value: id)]
        return components.url ?? URL(string: "provenance://")!
    }

    // MARK: - AppEntity Display Representation

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(systemName)",
            image: artworkURL.map { .init(url: $0) }
        )
    }

    // MARK: - Init

    public init(
        id: String,
        title: String,
        systemName: String,
        systemIdentifier: String,
        isFavorite: Bool,
        lastPlayedDate: Date? = nil,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.isFavorite = isFavorite
        self.lastPlayedDate = lastPlayedDate
        self.artworkURL = artworkURL
    }
}

// MARK: - GameEntityQuery

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct GameEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [GameEntity] {
        let store = GameEntityStore.shared
        return identifiers.compactMap { store.entity(for: $0) }
    }

    public func suggestedEntities() async throws -> [GameEntity] {
        GameEntityStore.shared.recentEntities(limit: 20)
    }
}
#endif
