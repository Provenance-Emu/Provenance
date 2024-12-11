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
    
    var activeArtworkURL: String? {
        customArtworkURL.isEmpty ? (originalArtworkURL.isEmpty ? nil : originalArtworkURL) : customArtworkURL
    }
    
    var boxartAspectRatio: PVGameBoxArtAspectRatio {
        guard let system = system else { return .square }
        switch system.enumValue {
        case .Sega32X:
            return .Sega32XUSA
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
		case
                ._3DO,
                .Atari2600,
                .Atari5200,
                .Atari7800,
                .AtariJaguar,
                .AtariJaguarCD,
                .C64,
                .ColecoVision,
                .DOS,
                .FDS,
                .GameCube,
                .Intellivision,
                .MSX,
                .MSX2,
                .MasterSystem,
                .NES,
                .Odyssey2,
                .PS2,
                .PalmOS,
                .SG1000,
                .TIC80,
                .Wii,
                .WonderSwan,
                .WonderSwanColor:
            return .tall
        case .Lynx:
            return .fiveBySix
        case
                ._3DS,
                .DS,
                .GBA,
                .GBC,
                .MegaDuck,
                .Music,
                .NGP,
                .NGPC,
                .NeoGeo,
                .PCECD,
                .PCFX,
                .PSX,
                .PokemonMini,
                .SegaCD,
                .VirtualBoy:
            return .square
        case .Saturn:
            switch regionName {
            case "Japan":
                return .saturnJAPAN
            default:
                return .saturnUSA
            }
        case .AtariJaguar, .AtariJaguarCD:
            return .jaguar
        default:
            return .square
        }
    }
}
