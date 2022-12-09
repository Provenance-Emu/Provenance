//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  kICadeControllerSetting.h
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#if canImport(UIKit)
@objc
public enum iCadeControllerSetting: Int, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable {
    case disabled
    case standard
    case eightBitdo
    case eightBitdoZero
    case steelSeries
    case mocute

    public var description: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .standard:
            return "Standard Controller"
        case .eightBitdo:
            return "8Bitdo Controller"
        case .eightBitdoZero:
            return "8Bitdo Zero Controller"
        case .steelSeries:
            return "SteelSeries Free Controller"
        case .mocute:
            return "Mocute Controller"
        }
    }

    public func createController() -> PViCadeController? {
        switch self {
        case .disabled:
            return nil
        case .standard:
            return PViCadeController()
        case .eightBitdo:
            return PViCade8BitdoController()
        case .eightBitdoZero:
            return PViCade8BitdoZeroController()
        case .steelSeries:
            return PViCadeSteelSeriesController()
        case .mocute:
            return PViCadeMocuteController()
        }
    }
}
#endif
