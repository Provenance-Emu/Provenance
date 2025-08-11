//
//  CreateEmulatorError.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/17/24.
//

public enum CreateEmulatorError: Error, LocalizedError {
    case couldNotCreateCore
    case gameHasNilRomPath
    case fileDoesNotExist(path: String?)
    case insufficientSpace

    var description: String {
        switch self {
        case .couldNotCreateCore:
            return "Could not create core."
        case .gameHasNilRomPath:
            return "Game has a nil rom path."
        case let .fileDoesNotExist(path):
            return "File does not exist at path: \(path ?? "nil")"
        case .insufficientSpace:
            return "Insufficient storage space for download."
        }
    }

    public var errorDescription: String? { description }

    public var failureReason: String? { description }

    public var recoverySuggestion: String? {
        switch self {
        case .couldNotCreateCore:
            "Check core settings."
        case .gameHasNilRomPath:
            "Check for a rom path in the game."
        case .fileDoesNotExist(path: let path):
            "Check for file at path: \(path ?? "nil")"
        case .insufficientSpace:
            "Free up storage space and try again."
        }
    }
}
