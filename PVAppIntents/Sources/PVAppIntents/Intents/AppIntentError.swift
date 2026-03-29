//
//  AppIntentError.swift
//  PVAppIntents
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(AppIntents)
import Foundation

// MARK: - AppIntentError

/// Typed errors thrown by PVAppIntents intents.
public enum AppIntentError: LocalizedError {
    /// No games were found for the given source (library or system name).
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
            if code.isEmpty {
                return "The cheat code is empty or invalid."
            }
            return "The cheat code \"\(code)\" is invalid."
        }
    }
}
#endif
