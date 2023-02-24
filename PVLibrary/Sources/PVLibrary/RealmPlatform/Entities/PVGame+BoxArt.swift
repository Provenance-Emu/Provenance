//
//  PVGame+BoxArt.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import CoreGraphics
import Foundation
import RealmSwift

public enum PVGameBoxArtAspectRatio: CGFloat {
    case square = 1.0
    case wide = 1.45
    case tall = 0.72
    case tg16 = 0.8497494768
    case pce = 1.00176208
    case sgx = 1.12
    case gbJAPAN = 0.8566003203
    case gbUSA = 1.0028730846
    case snesUSA = 1.3889901527
    case snesJAPAN = 0.5595619918
    case genmd = 0.719651472
    case smsUSA = 0.716864397
    case nesUSA = 0.7251925801
    case saturnUSA = 0.625
    case saturnJAPAN = 1.136
    case ggUSA = 0.7201
    case ggJAPAN = 0.86
    case Sega32XUSA = 0.7194636596
}

public extension PVGame {
    var boxartAspectRatio: PVGameBoxArtAspectRatio {
        guard let system = system else { return .square }
        switch system.enumValue {
        case .SGFX:
            return .sgx
        case .PCE:
            switch regionName {
            case "Japan":
                return .square
            default:
                return .tg16
            }
        case .GB:
            switch regionName {
            case "Japan":
                return .gbJAPAN
            default:
                return .square
            }
        case .SNES:
            switch regionName {
            case "Japan":
                return .snesJAPAN
            default:
                return .snesUSA
            }
		case .N64:
            return .snesUSA
        case .Genesis:
            return .genmd
        case .GameGear:
            switch regionName {
            case "Japan":
                return .ggJAPAN
            default:
                return .ggUSA
            }
		case .NES, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .AtariJaguarCD, .WonderSwan, .WonderSwanColor,
                .MasterSystem, .SG1000, .FDS, .GameCube, .PS2, .Intellivision, .ColecoVision, ._3DO, .Odyssey2, .DOS, .MSX, .MSX2, .C64, .Wii, .PalmOS, .TIC80:
            return .tall
        case .GBA, .GBC, .Lynx, .NeoGeo, .NGP, .NGPC, .PCECD, .PCFX, .PokemonMini, .PSX, .SegaCD, .VirtualBoy, .DS, .Music, ._3DS, .MegaDuck:
            return .square
        case .Saturn:
            switch regionName {
            case "Japan":
                return .saturnJAPAN
            default:
                return .saturnUSA
            }
        default:
            return .square
        }
    }
}
