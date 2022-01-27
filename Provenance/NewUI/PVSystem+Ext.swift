//
//  PVSystem+Ext.swift
//  Provenance
//
//  Created by Ian Clawson on 1/26/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public enum GameArtworkType {
    case tall
    case square
    case wide
    
    var defaultWidth: CGFloat { // untested, may not be the right approach just yet
        switch self {
        case .tall: return 50
        case .square: return 100
        case .wide: return 150
        }
    }
    
    var emptyViewName: String {  // TODO: populate this correctly
        switch self {
        case .tall: return "prov_game_ff"
        case .square: return "prov_game_fft"
        case .wide: return "prov_game_ff3"
        }
    }
}

public extension PVSystem {
    var gameArtworkType: GameArtworkType {
        switch self.enumValue {
        case .DS, .Dreamcast, .GB, .GBA, .GBC, .PCE, .PSX:
            return .square
        case .N64, .NGP, .NGPC, .SNES:
            return .wide
        default:
            return .tall
        }
    }
}
