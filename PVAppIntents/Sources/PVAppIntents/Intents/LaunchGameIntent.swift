//
//  LaunchGameIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Launches a specific game in Provenance.
///
/// Replaces the legacy `PVOpenIntent` with full `AppIntents` entity support,
/// dynamic suggestions from the game library, and natural-language Siri phrases.
///
/// Usage: "Hey Siri, play Super Mario Bros on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct LaunchGameIntent: AppIntent, CustomIntentMigratedAppIntent {
    public static let intentClassName = "PVOpenIntent"

    public static var title: LocalizedStringResource = "Launch Game"
    public static var description = IntentDescription(
        "Opens a game in Provenance.",
        categoryName: "Games"
    )

    public static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "Game", description: "The game to launch.")
    public var game: GameEntity

    // MARK: - Init

    public init() {}

    public init(game: GameEntity) {
        self.game = game
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Write the game ID to the shared app group so the host app
        // can launch it when it comes to the foreground.
        let defaults = UserDefaults(suiteName: "group.org.provenance-emu.provenance")
        defaults?.set(game.id, forKey: "pendingLaunchGameID")
        return .result(dialog: "Launching \(game.title).")
    }

    // MARK: - AppIntent URL handling

    /// Deep-link URL opened by the system when this intent runs.
    /// Provenance's `application(_:open:options:)` handles `provenance://open?md5=`.
    public static var parameterSummary: some ParameterSummary {
        Summary("Launch \(\.$game)")
    }
}
#endif
