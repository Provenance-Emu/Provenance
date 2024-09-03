//
//  EmulatorCoreSavesDataSource.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation

@objc
public protocol EmulatorCoreSavesDataSource {
    @objc optional dynamic var saveStatesPath: String? { get }
    @objc optional dynamic var batterySavesPath: String? { get }
    @objc optional dynamic var supportsSaveStates: Bool { get }
}

//public extension EmulatorCoreSavesDataSource {
//    public var saveStatesPath: String {
//        #warning("saveStatesPath incomplete")
//        // WARN: Copy from PVEMulatorConfiguration or refactor it here?
//        return ""
//    }
//
//    public var batterySavesPath: String {
//        #warning("batterySavesPath incomplete")
//
//        return ""
//    }

//    public var supportsSaveStates: Bool { true }
//}
