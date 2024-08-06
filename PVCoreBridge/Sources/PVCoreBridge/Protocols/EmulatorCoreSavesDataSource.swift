//
//  EmulatorCoreSavesDataSource.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation

@objc
public protocol EmulatorCoreSavesDataSource {
    var saveStatesPath: String? { get }
    var batterySavesPath: String? { get }
    var supportsSaveStates: Bool { get }
}
