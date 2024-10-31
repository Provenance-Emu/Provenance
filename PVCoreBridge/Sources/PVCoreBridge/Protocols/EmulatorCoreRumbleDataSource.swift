//
//  EmulatorCoreRumbleDataSource.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public protocol EmulatorCoreRumbleDataSource: EmulatorCoreControllerDataSource {
    var supportsRumble: Bool { get }
}
