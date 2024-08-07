//
//  SystemProtocol+Paths.swift
//  
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation

// MARK: - PVSystem convenience extension

public extension SystemProtocol {
    var biosDirectory: URL { get async {
        return await PVEmulatorConfiguration.biosPath(forSystemIdentifier: identifier)
    }}

    var romsDirectory: URL { get async {
        return await PVEmulatorConfiguration.romDirectory(forSystemIdentifier: identifier)
    }}
}
