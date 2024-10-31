//
//  EmulatorCoreSavesDataSource.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation

@objc
public protocol EmulatorCoreSavesDataSource {
    @objc dynamic var saveStatesPath: String? { get set }
    @objc dynamic var batterySavesPath: String? { get set }
    @objc optional dynamic var supportsSaveStates: Bool { get }
}
