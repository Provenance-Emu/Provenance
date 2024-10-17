//
//  CheatsStateError.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//


public enum CheatsStateError: Error {
    case coreCheatsError(Error?)
    case coreNoCheatError(Error?)
    case cheatsUnsupportedByCore
    case noCoreFound(String)
    case realmWriteError(Error)
    case realmDeletionError(Error)

    var localizedDescription: String {
        switch self {
        case let .coreCheatsError(coreError): return "Core failed to Apply Cheats: \(coreError?.localizedDescription ?? "No reason given.")"
        case let .coreNoCheatError(coreError): return "Core failed to Disable Cheats: \(coreError?.localizedDescription ?? "No reason given.")"
        case .cheatsUnsupportedByCore: return "This core does not support Cheats"
        case let .noCoreFound(id): return "No core found to match id: \(id)"
        case let .realmWriteError(realmError): return "Unable to write Cheats State to realm: \(realmError.localizedDescription)"
        case let .realmDeletionError(realmError): return "Unable to delete old Cheats States from database: \(realmError.localizedDescription)"
        }
    }
}
