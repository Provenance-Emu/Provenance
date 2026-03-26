//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  kICadeControllerSetting.h
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

import Defaults

#if canImport(UIKit)
import UIKit

@objc
public enum iCadeControllerSetting: Int, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable, Defaults.Serializable {
    case disabled
    case standard
    case eightBitdo
    case eightBitdoZero
    case steelSeries
    case mocute
    case eightBitdoSNES30
    case eightBitdoSN30Pro

    public var description: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .standard:
            return "Standard Controller"
        case .eightBitdo:
            return "8BitDo Controller"
        case .eightBitdoZero:
            return "8BitDo Zero Controller"
        case .steelSeries:
            return "SteelSeries Free Controller"
        case .mocute:
            return "Mocute Controller"
        case .eightBitdoSNES30:
            return "8BitDo SNES30 Controller"
        case .eightBitdoSN30Pro:
            return "8BitDo SN30 Pro (iCade Mode)"
        }
    }
}
#endif
