//
//  PlayRandomGameIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Picks and launches a random game, optionally filtered by system.
///
/// Usage: "Hey Siri, play a random SNES game on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct PlayRandomGameIntent: AppIntent {
    public static var title: LocalizedStringResource = "Play Random Game"
    public static var description = IntentDescription(
        "Picks a random game from your Provenance library and launches it.",
        categoryName: "Games"
    )

    public static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "System", description: "Filter to a specific system. Leave empty for any system.")
    public var system: SystemEntity?

    // MARK: - Init

    public init() {}

    public init(system: SystemEntity? = nil) {
        self.system = system
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<GameEntity> {
        let candidates: [GameEntity]
        if let system {
            candidates = GameEntityStore.shared.allEntities().filter {
                $0.systemIdentifier == system.id
            }
        } else {
            candidates = GameEntityStore.shared.allEntities()
        }

        guard let picked = candidates.randomElement() else {
            let systemName = system?.name ?? "your library"
            throw NSError(
                domain: "PVAppIntents",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No games found in \(systemName)."]
            )
        }

        return .result(
            value: picked,
            dialog: "Launching \(picked.title) on \(picked.systemName)."
        )
    }

    public static var parameterSummary: some ParameterSummary {
        When(\.$system, .hasAnyValue) {
            Summary("Play a random \(\.$system) game")
        } otherwise: {
            Summary("Play a random game")
        }
    }
}
#endif
