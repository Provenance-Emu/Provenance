//
//  PVBIOS+Paths.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import PVRealm

public extension PVBIOS {
    var expectedPath: URL { get {
        return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
    }}
}
