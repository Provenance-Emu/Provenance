//
//  iCadeSettings+Factory.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/8/24.
//

import PVSettings

#if canImport(UIKit) && canImport(GameController)

public extension iCadeControllerSetting {
    nonisolated
    func createController() -> PViCadeController? {
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
