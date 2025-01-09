//
//  SystemProtocol+Paths.swift
//  
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation
import PVPrimitives


// MARK: - PVSystem convenience extension

public extension SystemProtocol {
    var biosDirectory: URL { get {
        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: identifier)
    }}

    var romsDirectory: URL { get {
        return PVEmulatorConfiguration.romDirectory(forSystemIdentifier: identifier)
    }}
}

public extension SystemIdentifier {
    var biosDirectory: URL { get {
        return PVEmulatorConfiguration.biosPath(forSystemIdentifier: self)
    }}
    
    var romsDirectory: URL { get {
        return PVEmulatorConfiguration.romDirectory(forSystemIdentifier: self)
    }}
}
