//
//  SaveStateError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/1/24.
//

public enum SaveStateError: Error {
    case coreSaveError(Error?)
    case coreLoadError(Error?)
    case saveStatesUnsupportedByCore
    case ineligibleError
    case noCoreFound(String)
    case realmWriteError(Error)
    case realmDeletionError(Error)

    var localizedDescription: String {
        switch self {
        case let .coreSaveError(coreError): return "Core failed to save: \(coreError?.localizedDescription ?? "No reason given.")"
        case let .coreLoadError(coreError): return "Core failed to load: \(coreError?.localizedDescription ?? "No reason given.")"
        case .saveStatesUnsupportedByCore: return "This core does not support save states."
        case .ineligibleError: return "Save states are currently ineligible."
        case let .noCoreFound(id): return "No core found to match id: \(id)"
        case let .realmWriteError(realmError): return "Unable to write save state to realm: \(realmError.localizedDescription)"
        case let .realmDeletionError(realmError): return "Unable to delete old auto-save from database: \(realmError.localizedDescription)"
        }
    }
}
