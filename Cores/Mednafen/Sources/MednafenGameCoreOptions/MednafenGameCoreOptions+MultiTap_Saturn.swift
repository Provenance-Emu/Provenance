//
//  MednafenGameCoreOptions+MultiTap_Saturn.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/17/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//
//  Saturn TeamTap games — keyed by product number (serial) found in the
//  disc volume header (same field used by the Provenance ROM database).
//  Values are the expected maximum player count.

import Foundation

@objc public extension MednafenGameCoreOptions {
    /// Saturn games that use the 6-player multitap (TeamTap).
    /// Keys are product / serial strings; values are max player count (≤6).
    @objc static var multiTapSaturnGames: [String: NSNumber] {
        struct Static {
            static let dict: [String: NSNumber] = [
                // Saturn Bomberman (Japan)
                "T-14404G"      : 6,
                // Saturn Bomberman (Japan Rev 1)
                "T-14404H"      : 6,
                // Saturn Bomberman (Europe)
                "MK-81081-50"   : 6,
                // Saturn Bomberman (USA)
                "80211"         : 6,
                // Bomberman Fight!! (Japan)
                "T-14405G"      : 6,
                // Bomberman Wars (Japan)
                "T-14409G"      : 5,
                // NBA Action '98 (Japan)
                "T-8130G"       : 4,
                // NBA Action '98 (USA)
                "T-8130H"       : 4,
                // Athlete Kings (Europe) / Decathlete (Europe)
                "MK-81036-50"   : 6,
                // Athlete Kings (Japan) / Decathlete (Japan)
                "GS-9028"       : 6,
                // Athlete Kings (USA)
                "81036"         : 6,
                // Winter Heat (Japan)
                "GS-9174"       : 4,
                // Winter Heat (USA)
                "81301"         : 4,
                // Steep Slope Sliders (Japan)
                "T-18503G"      : 4,
                // Steep Slope Sliders (USA)
                "T-18503H"      : 4,
                // Virtual Volleyball (Japan)
                "T-8117G"       : 4,
                // Fever FIFA Soccer (Japan)
                "T-17725G"      : 4,
                // NBA Live 97 (Japan)
                "T-22403G"      : 4,
                // NBA Live 97 (USA)
                "T-22403H"      : 4,
                // FIFA 97 (USA)
                "T-5024H"       : 4,
                // FIFA 97 (Europe)
                "MK-81082-50"   : 4,
                // Sega Worldwide Soccer 98 (Japan)
                "GS-9175"       : 4,
                // Sega Worldwide Soccer 98 (Europe)
                "MK-81101-50"   : 4,
                // Winning Post 3 Premium (Japan)
                "T-18606G"      : 6,
                // Game no Tatsujin (Japan)
                "T-14402G"      : 6,
                // Taisen Mahjong Haoto DX (Japan)
                "T-14408G"      : 6,
            ]
        }
        return Static.dict
    }
}
