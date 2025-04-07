//
//  InputMaps.swift
//  PVCoreMednafen
//
//  Created by Joseph Mattiello on 10/1/24.
//

import Foundation

// Input maps
@objc
@objcMembers
public class InputMaps: NSObject {
    @objc public static let PCEMap: [Int32] = [4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12]
    @objc public static let PCFXMap: [Int32] = [8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6, 12]
    @objc public static let SNESMap: [Int32] = [4, 5, 6, 7, 8, 0, 9, 1, 10, 11, 3, 2]
    @objc public static let GBMap: [Int32] = [6, 7, 5, 4, 0, 1, 3, 2]
    @objc public static let GBAMap: [Int32] = [6, 7, 5, 4, 0, 1, 9, 8, 3, 2]
    @objc public static let NESMap: [Int32] = [4, 5, 6, 7, 0, 1, 3, 2]
    @objc public static let LynxMap: [Int32] = [6, 7, 4, 5, 0, 1, 3, 2, 8]
    @objc public static let PSXMap: [Int32] = [4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17]
    @objc public static let VBMap: [Int32] = [9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11]
    @objc public static let WSMap: [Int32] = [0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11]
    @objc public static let NeoMap: [Int32] = [0, 1, 2, 3, 4, 5, 6]
    @objc public static let SSMap: [Int32] = [4, 5, 6, 7, 10, 8, 9, 2, 1, 0, 15, 3, 11]
    @objc public static let GenesisMap: [Int32] = [5, 7, 11, 10, 0, 1, 2, 3, 4, 6, 8, 9]
}
