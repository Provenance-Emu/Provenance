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
    public static let title: LocalizedStringResource = "Play Random Game"
    public static let description = IntentDescription(
        "Picks a random game from your Provenance library and launches it.",
        categoryName: "Games"
    )

    public static let openAppWhenRun: Bool = true

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
            throw AppIntentError.noGamesFound(in: systemName)
        }

        // Hand off the selected game to the host app via App Group UserDefaults.
        // `PVAppDelegate.processPendingIntents()` reads and clears this key in
        // `applicationDidBecomeActive`, then routes to `AppState.appOpenAction`.
        pvAppGroupDefaults?.set(picked.id, forKey: "pendingLaunchGameID")

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

// MARK: - AppIntentError

/// Typed errors thrown by PVAppIntents intents.
public enum AppIntentError: LocalizedError {
    case noGamesFound(in: String)
    /// No emulation session is currently active (no game is running).
    case noActiveSession
    /// The supplied cheat code string is empty or malformed.
    case invalidCheatCode(String)

    public var errorDescription: String? {
        switch self {
        case .noGamesFound(let source):
            return "No games found in \(source)."
        case .noActiveSession:
            return "No game is currently running in Provenance."
        case .invalidCheatCode(let code):
            return "The cheat code \"\(code)\" is invalid or empty."
        }
    }
}
#endif
