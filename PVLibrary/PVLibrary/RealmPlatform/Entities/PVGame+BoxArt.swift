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
    case tall = 0.7
}

public extension PVGame {
    var boxartAspectRatio: PVGameBoxArtAspectRatio {
        switch system.enumValue {
        case .SNES, .N64:
            return .wide
        case .NES, .Genesis, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .WonderSwan, .WonderSwanColor:
            return .tall
        default:
            return .square
        }
    }
}
