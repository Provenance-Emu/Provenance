//
//  SaveStateEntity.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// An `AppEntity` representing a save state for a specific game.
///
/// Exposed to the Shortcuts app so users can automate "Continue [game] from slot 1".
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SaveStateEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Save State")
    public static var defaultQuery = SaveStateEntityQuery()

    // MARK: - Stored Properties

    /// Unique identifier for this save state (file name or UUID).
    public var id: String

    /// Title of the associated game.
    public var gameTitle: String

    /// MD5 hash of the associated game — used for deep links.
    public var gameMD5: String

    /// Save slot number, if applicable. 0 = auto-save.
    public var slot: Int

    /// URL of the save state screenshot thumbnail.
    public var screenshotURL: URL?

    /// Date the save state was created or last modified.
    public var date: Date

    // MARK: - Computed

    /// Deep-link URL that opens the game and loads this save state.
    /// The main app handles `loadSaveState` by looking up via the save state `id`.
    public var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "provenance"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "md5", value: gameMD5),
            URLQueryItem(name: "saveStateId", value: id)
        ]
        return components.url ?? URL(string: "provenance://")!
    }

    // MARK: - AppEntity Display Representation

    public var displayRepresentation: DisplayRepresentation {
        let slotLabel = slot == 0 ? "Auto-save" : "Slot \(slot)"
        let dateFormatter = RelativeDateTimeFormatter()
        let relativeDate = dateFormatter.localizedString(for: date, relativeTo: .now)
        return DisplayRepresentation(
            title: "\(gameTitle)",
            subtitle: "\(slotLabel) · \(relativeDate)",
            image: screenshotURL.map { .init(url: $0) }
        )
    }

    // MARK: - Init

    public init(
        id: String,
        gameTitle: String,
        gameMD5: String,
        slot: Int,
        screenshotURL: URL? = nil,
        date: Date
    ) {
        self.id = id
        self.gameTitle = gameTitle
        self.gameMD5 = gameMD5
        self.slot = slot
        self.screenshotURL = screenshotURL
        self.date = date
    }
}

// MARK: - SaveStateEntityQuery

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SaveStateEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SaveStateEntity] {
        let store = SaveStateEntityStore.shared
        return identifiers.compactMap { store.entity(for: $0) }
    }

    public func suggestedEntities() async throws -> [SaveStateEntity] {
        SaveStateEntityStore.shared.recentEntities(limit: 10)
    }
}
#endif
