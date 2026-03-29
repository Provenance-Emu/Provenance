//
//  LoadSaveStateIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Sentinel slot value that instructs the host app to load the most recently
/// created save state for the running game.
private let mostRecentSaveSlot: Int = -1

/// Loads a previously saved game state.
///
/// If `slot` is nil the host app loads the most recently created save state for
/// the running game. The actual load is delegated to `PVAppDelegate` via the
/// shared App Group UserDefaults suite.
///
/// Usage: "Hey Siri, load my saved game on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct LoadSaveStateIntent: AppIntent {
    public static let title: LocalizedStringResource = "Load Game State"
    public static let description = IntentDescription(
        "Loads a saved game state in Provenance.",
        categoryName: "Emulation"
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Slot",
        description: "The save slot to load. Leave empty to load the most recent save.",
        inclusiveRange: (0, 99)
    )
    public var slot: Int?

    // MARK: - Init

    public init() {}

    public init(slot: Int? = nil) {
        self.slot = slot
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard pvGameIsActive else {
            throw AppIntentError.noActiveSession
        }
        if let slot {
            pvAppGroupDefaults?.set(slot, forKey: "pendingLoadStateSlot")
        } else {
            // Sentinel value -1 signals the host app to load the most recently created save.
            pvAppGroupDefaults?.set(mostRecentSaveSlot, forKey: "pendingLoadStateSlot")
        }
        let slotLabel = slot.map { $0 == 0 ? "auto-save" : "slot \($0)" } ?? "most recent save"
        return .result(dialog: "Loading game state from \(slotLabel).")
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Load game state from slot \(\.$slot)")
    }
}
#endif
