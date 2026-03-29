//
//  SaveStateIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Saves the current game state to the specified slot.
///
/// The actual save is performed by the host app via the shared App Group
/// UserDefaults suite. `PVAppDelegate.processPendingIntents()` reads and clears
/// `pendingSaveStateSlot` in `applicationDidBecomeActive` and forwards the
/// request to the active emulator core.
///
/// Usage: "Hey Siri, save my game on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct SaveStateIntent: AppIntent {
    public static let title: LocalizedStringResource = "Save Game State"
    public static let description = IntentDescription(
        "Saves the current game state in Provenance.",
        categoryName: "Emulation"
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Slot",
        description: "The save slot number. Use 0 for auto-save.",
        default: 0,
        inclusiveRange: (0, 99)
    )
    public var slot: Int

    // MARK: - Init

    public init() {}

    public init(slot: Int = 0) {
        self.slot = slot
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard pvGameIsActive else {
            throw AppIntentError.noActiveSession
        }
        pvAppGroupDefaults?.set(slot, forKey: "pendingSaveStateSlot")
        let slotLabel = slot == 0 ? "auto-save slot" : "slot \(slot)"
        return .result(dialog: "Saving game state to \(slotLabel).")
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Save game state to slot \(\.$slot)")
    }
}
#endif
