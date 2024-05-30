//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging

@objc
extension PVEmulatorCore: EmulatorCoreControllerDataSource {
    public func controller(forPlayer player: UInt) -> GCController? {
        return (self as EmulatorCoreControllerDataSource).controller(forPlayer: player)
    }
}
