//
//  PVGame+Paths.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation

// MARK: - PVGame convenience extension

public extension PVGame {
    // TODO: See above TODO, this should be based on the ROM systemid/md5
    var batterSavesPath: URL { get async {
        return await PVEmulatorConfiguration.batterySavesPath(forGame: self)
    }}

    var saveStatePath: URL { get async {
        return await PVEmulatorConfiguration.saveStatePath(forGame: self)
    }}
}
