//
//  SystemEntity.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// An `AppEntity` representing an emulated console / system.
///
/// Used as a filter parameter in `PlayRandomGameIntent`
/// so users can say "Play a random Super Nintendo game on Provenance".
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SystemEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "System")
    public static var defaultQuery = SystemEntityQuery()

    // MARK: - Stored Properties

    /// The system identifier raw value (e.g. "com.provenance.snes").
    public var id: String

    /// Human-readable name (e.g. "Super Nintendo").
    public var name: String

    /// Manufacturer name (e.g. "Nintendo").
    public var manufacturer: String

    /// Number of games in the library for this system.
    public var gameCount: Int

    // MARK: - AppEntity Display Representation

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(manufacturer) · \(gameCount) game\(gameCount == 1 ? "" : "s")"
        )
    }

    // MARK: - Init

    public init(id: String, name: String, manufacturer: String, gameCount: Int) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.gameCount = gameCount
    }
}

// MARK: - SystemEntityQuery

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SystemEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SystemEntity] {
        let store = SystemEntityStore.shared
        return identifiers.compactMap { store.entity(for: $0) }
    }

    public func suggestedEntities() async throws -> [SystemEntity] {
        SystemEntityStore.shared.allEntities()
    }
}
#endif
