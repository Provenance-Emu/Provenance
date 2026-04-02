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
import PVSystems

public extension PVGame {
    
    var activeArtworkURL: String? {
        customArtworkURL.isEmpty ? (originalArtworkURL.isEmpty ? nil : originalArtworkURL) : customArtworkURL
    }
    
    var boxartAspectRatio: PVGameBoxArtAspectRatio {
        guard let system = system else { return .square }
        switch system.enumValue {

        // Region-dependent systems
        case .PCE:
            return regionName == "Japan" ? .square : .tg16
        case .GB:
            return regionName == "Japan" ? .gbJAPAN : .square
        case .SNES:
            return regionName == "Japan" ? .snesJAPAN : .snesUSA
        case .GameGear:
            return regionName == "Japan" ? .ggJAPAN : .ggUSA
        case .Saturn:
            return regionName == "Japan" ? .saturnJAPAN : .saturnUSA

        // Wide landscape boxes
        case .N64:
            return .n64USA

        // Mega Drive / Genesis clamshell
        case .Genesis:
            return .genmd
        case .Sega32X:
            return .Sega32XUSA

        // PC Engine variants
        case .SGFX:
            return .sgx

        // DVD-case systems
        case .PS2, .GameCube, .Wii:
            return .dvdCase

        // Blu-ray case
        case .PS3:
            return .blurayCase

        // UMD case
        case .PSP:
            return .umdCase

        // CD jewel case systems
        case .Dreamcast, .NeoGeoCD, .CDi:
            return .cdJewelCase
        case .PCECD, .PCFX, .SegaCD:
            return .square  // Standard jewel case front inserts are ~square

        // Long box / specialty tall
        case ._3DO:
            return .longBox3DO
        case .Vectrex:
            return .vectrex
        case .Supervision:
            return .supervision

        // Famicom Disk System sleeve
        case .FDS:
            return .fds

        // Specific cartridge box sizes
        case .Intellivision:
            return .intellivision
        case .Atari8bit:
            return .atari8bit

        // Systems with specific measured ratios
        case .NES:
            return .nesUSA
        case .MasterSystem:
            return .smsUSA

        // Standard tall cartridge/box systems (~0.72)
        case .Atari2600,
             .Atari5200,
             .Atari7800,
             .AtariJaguar,
             .AtariJaguarCD,
             .C64,
             .ColecoVision,
             .Odyssey2,
             .PalmOS,
             .SG1000,
             .MSX,
             .MSX2,
             .TIC80,
             .WonderSwan,
             .WonderSwanColor:
            return .tall

        // Computer floppy software boxes
        case .DOS, .DOOM, .Quake, .Quake2, .Wolf3D,
             .AppleII, .Macintosh:
            return .floppyBox
        case .AtariST:
            return .atariST
        case .PC98:
            return .pc98

        // Cassette-based computer systems
        case .ZXSpectrum, .EP128:
            return .cassetteBox

        // Lynx (5:6)
        case .Lynx:
            return .fiveBySix

        // Near-square / square systems
        case ._3DS, .DS,
             .GBA, .GBC,
             .MegaDuck,
             .Music,
             .NGP, .NGPC,
             .NeoGeo,
             .PSX,
             .PokemonMini,
             .VirtualBoy:
            return .square

        // Arcade — no retail box, use square flyer art
        case .CPS1, .CPS2, .CPS3, .MAME:
            return .square

        default:
            return .square
        }
    }
}
