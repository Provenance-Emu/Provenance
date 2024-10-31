//
//  SystemIdentifier+PVSystem.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import PVRealm
import Systems

public extension SystemIdentifier {
    var system: PVSystem? {
        return PVEmulatorConfiguration.system(forIdentifier: self)
    }
}
