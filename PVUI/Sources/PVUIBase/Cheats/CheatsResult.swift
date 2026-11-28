//
//  CheatsResult.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

public enum CheatsResult {
    case success
    case error(CheatsStateError)
}

public typealias CheatsCompletion = (CheatsResult) -> Void

/// Applies a cheat to the running core and saves it: code, name, code type,
/// index, enabled. Returns whether the core accepted it and it was saved.
public typealias CheatSaveHandler = @MainActor (String, String, String, UInt8, Bool) async -> Bool
