//
//  EmulationError.swift
//  PVEmulatorCore
//
//  Created by Joseph Mattiello on 9/2/24.
//

import Foundation

public enum EmulationError: Error, CustomStringConvertible, CustomNSError {
    
    case failedToLoadFile
    case coreDoesNotImplimentLoadFile
    
    public var description: String {
        switch self {
        case .failedToLoadFile: return "Failed to load file"
        case .coreDoesNotImplimentLoadFile: return "Core does not implement loadFile:error: method"
        }
    }

    public var errorUserInfo: [String: Any] {
        return ["description": description]
    }
}
