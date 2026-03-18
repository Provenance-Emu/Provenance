//
//  GetLibraryStatsIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Returns a human-readable summary of the Provenance game library.
///
/// Usable in Shortcuts automations and as the data source for the
/// Library Stats widget timeline.
///
/// Usage: "Hey Siri, how many games do I have in Provenance?"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct GetLibraryStatsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Library Stats"
    public static var description = IntentDescription(
        "Returns the total game count, system count, and other library statistics from Provenance.",
        categoryName: "Library"
    )

    public static var openAppWhenRun: Bool = false

    // MARK: - Init

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let allGames = GameEntityStore.shared.allEntities()
        let totalGames = allGames.count
        let totalSystems = SystemEntityStore.shared.allEntities().count
        let favoriteCount = allGames.filter { $0.isFavorite }.count
        let summary = "\(totalGames) game\(totalGames == 1 ? "" : "s") across \(totalSystems) system\(totalSystems == 1 ? "" : "s"), \(favoriteCount) favourite\(favoriteCount == 1 ? "" : "s")."
        return .result(value: summary, dialog: "You have \(summary)")
    }
}

// MARK: - LibraryStatsResult

/// Structured result type for Shortcuts automations and widget timeline consumption.
public struct LibraryStatsResult: Codable, Sendable {
    public let totalGames: Int
    public let totalSystems: Int
    public let favoriteCount: Int
    public let generatedAt: Date

    public init(totalGames: Int, totalSystems: Int, favoriteCount: Int, generatedAt: Date = .now) {
        self.totalGames = totalGames
        self.totalSystems = totalSystems
        self.favoriteCount = favoriteCount
        self.generatedAt = generatedAt
    }
}
#endif
