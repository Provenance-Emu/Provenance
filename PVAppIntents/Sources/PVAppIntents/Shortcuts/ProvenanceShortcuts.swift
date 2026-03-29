//
//  ProvenanceShortcuts.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents

/// Registers Provenance's suggested Siri phrases via `AppShortcutsProvider`.
///
/// The system calls this at build time to populate Siri with suggested phrases.
/// Phrases must contain `\.applicationName` exactly once.
///
/// Call `ProvenanceShortcuts.updateAppShortcutParameters()` from the host app
/// whenever the game library changes significantly (e.g. after import) so that
/// Siri's entity suggestions stay fresh.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct ProvenanceShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            // MARK: Launch Game
            AppShortcut(
                intent: LaunchGameIntent(),
                phrases: [
                    "Play \(\.$game) on \(.applicationName)",
                    "Launch \(\.$game) in \(.applicationName)",
                    "Open \(\.$game) with \(.applicationName)"
                ],
                shortTitle: "Launch Game",
                systemImageName: "gamecontroller.fill"
            ),

            // MARK: Play Random Game
            AppShortcut(
                intent: PlayRandomGameIntent(),
                phrases: [
                    "Play a random game on \(.applicationName)",
                    "Surprise me on \(.applicationName)",
                    "Play a random \(\.$system) game on \(.applicationName)"
                ],
                shortTitle: "Random Game",
                systemImageName: "shuffle"
            ),

            // MARK: List Recent Games
            AppShortcut(
                intent: ListRecentGamesIntent(),
                phrases: [
                    "What did I play recently on \(.applicationName)",
                    "Show my recent games in \(.applicationName)"
                ],
                shortTitle: "Recent Games",
                systemImageName: "clock.arrow.circlepath"
            ),

            // MARK: Library Stats
            AppShortcut(
                intent: GetLibraryStatsIntent(),
                phrases: [
                    "How many games do I have in \(.applicationName)",
                    "Show my \(.applicationName) library stats"
                ],
                shortTitle: "Library Stats",
                systemImageName: "chart.bar.fill"
            ),

            // MARK: Toggle Favourite
            AppShortcut(
                intent: ToggleFavoriteIntent(),
                phrases: [
                    "Add \(\.$game) to my \(.applicationName) favourites",
                    "Remove \(\.$game) from my \(.applicationName) favourites"
                ],
                shortTitle: "Toggle Favourite",
                systemImageName: "star.fill"
            ),

            // MARK: Continue Most Recent
            AppShortcut(
                intent: ContinueMostRecentGameIntent(),
                phrases: [
                    "Continue my last game on \(.applicationName)",
                    "Resume \(.applicationName)",
                    "Keep playing on \(.applicationName)"
                ],
                shortTitle: "Continue Last Game",
                systemImageName: "play.fill"
            ),

            // MARK: Search Library
            AppShortcut(
                intent: SearchLibraryIntent(),
                phrases: [
                    "Search \(.applicationName) library",
                    "Find games in \(.applicationName)"
                ],
                shortTitle: "Search Games",
                systemImageName: "magnifyingglass"
            ),

            // MARK: Save Game State
            AppShortcut(
                intent: SaveStateIntent(),
                phrases: [
                    "Save my game on \(.applicationName)",
                    "Save state on \(.applicationName)",
                    "Save game state in \(.applicationName)"
                ],
                shortTitle: "Save State",
                systemImageName: "square.and.arrow.down"
            ),

            // MARK: Load Game State
            AppShortcut(
                intent: LoadSaveStateIntent(),
                phrases: [
                    "Load my saved game on \(.applicationName)",
                    "Load save state on \(.applicationName)",
                    "Continue from save on \(.applicationName)"
                ],
                shortTitle: "Load State",
                systemImageName: "square.and.arrow.up"
            ),

            // MARK: Take Screenshot
            AppShortcut(
                intent: TakeScreenshotIntent(),
                phrases: [
                    "Take a screenshot on \(.applicationName)",
                    "Screenshot my game in \(.applicationName)"
                ],
                shortTitle: "Take Screenshot",
                systemImageName: "camera.fill"
            ),

            // MARK: Add Cheat Code
            AppShortcut(
                intent: AddCheatIntent(),
                phrases: [
                    "Add a cheat code in \(.applicationName)",
                    "Enter cheat code on \(.applicationName)"
                ],
                shortTitle: "Add Cheat",
                systemImageName: "chevron.left.forwardslash.chevron.right"
            )
        ]
    }
}
#endif
