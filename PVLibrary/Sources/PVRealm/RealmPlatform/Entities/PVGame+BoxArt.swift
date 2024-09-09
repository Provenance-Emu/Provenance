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
import Systems

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
