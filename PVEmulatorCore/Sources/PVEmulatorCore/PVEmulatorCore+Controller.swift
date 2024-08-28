//
//  PVEmulatorCore.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

#if canImport(GameController)
import GameController

import Foundation
import PVCoreBridge
import PVLogging

@objc
extension PVEmulatorCore: EmulatorCoreControllerDataSource {
    public func controller(forPlayer player: UInt) -> GCController? {
        return (self as EmulatorCoreControllerDataSource).controller(forPlayer: player)
    }
}
#endif
