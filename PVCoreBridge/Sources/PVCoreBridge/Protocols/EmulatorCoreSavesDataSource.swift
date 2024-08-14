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
