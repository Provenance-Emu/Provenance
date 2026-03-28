//
//  ContinueMostRecentGameIntent.swift
//  PVAppIntents
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  "Hey Siri, continue my last game on Provenance"
//  Writes the most-recently-played game MD5 (from the EntityStore) to the
//  shared App Group so `processPendingAppIntents()` can open it on foreground.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Resumes the most recently played game in Provenance.
///
/// Usage:
/// - "Continue my last game on Provenance"
/// - "Resume Provenance"
/// - "Keep playing on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct ContinueMostRecentGameIntent: AppIntent {

    public static let title: LocalizedStringResource = "Continue Most Recent Game"
    public static let description = IntentDescription(
        "Resumes the last game you played in Provenance.",
        categoryName: "Games"
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<GameEntity> {
        guard let game = GameEntityStore.shared.recentEntities(limit: 1).first else {
            throw AppIntentError.noGamesFound(in: "your library")
        }
        pvAppGroupDefaults?.set(game.id, forKey: "pendingLaunchGameID")
        return .result(value: game, dialog: "Resuming \(game.title).")
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Continue most recent game")
    }
}
#endif
