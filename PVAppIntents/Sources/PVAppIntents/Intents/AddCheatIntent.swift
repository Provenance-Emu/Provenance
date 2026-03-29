//
//  AddCheatIntent.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Adds a cheat code to the currently running game.
///
/// The intent encodes the cheat parameters as a JSON payload in the shared App
/// Group UserDefaults under `pendingAddCheat`. `PVAppDelegate.processPendingIntents()`
/// decodes the payload, persists the cheat via `PVCheatsManager`, and enables it
/// on the active emulator core.
///
/// Usage: "Hey Siri, add a cheat code on Provenance"
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
public struct AddCheatIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Cheat Code"
    public static let description = IntentDescription(
        "Adds a cheat code to the current game in Provenance.",
        categoryName: "Emulation"
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Code", description: "The cheat code string (e.g. 007-000-000).")
    public var code: String

    @Parameter(title: "Description", description: "A human-readable label for the cheat.")
    public var cheatDescription: String

    @Parameter(
        title: "Type",
        description: "Cheat format (e.g. GameShark, Game Genie, Pro Action Replay).",
        default: "GameShark"
    )
    public var type: String

    // MARK: - Init

    public init() {}

    public init(code: String, cheatDescription: String, type: String = "GameShark") {
        self.code = code
        self.cheatDescription = cheatDescription
        self.type = type
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw AppIntentError.invalidCheatCode(trimmedCode)
        }
        guard pvGameIsActive else {
            throw AppIntentError.noActiveSession
        }

        // Encode the cheat as a JSON dict so the host app can decode it
        // without pulling in PVAppIntents' types.
        let payload: [String: String] = [
            "code": trimmedCode,
            "description": cheatDescription,
            "type": type
        ]
        if let data = try? JSONEncoder().encode(payload) {
            pvAppGroupDefaults?.set(data, forKey: "pendingAddCheat")
        }

        return .result(dialog: "Added cheat \"\(cheatDescription)\" to the current game.")
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Add cheat \(\.$cheatDescription) (\(\.$code)) to the current game")
    }
}
#endif
