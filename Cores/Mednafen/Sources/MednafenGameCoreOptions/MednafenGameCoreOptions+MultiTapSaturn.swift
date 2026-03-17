//
//  MednafenGameCoreOptions+MultiTapSaturn.swift
//  PVMednafen
//
//  Created by Claude on 2026-03-17.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation

@objc public extension MednafenGameCoreOptions {

    /// Saturn games that support the TeamTap multitap adapter.
    /// Key: Saturn product/game ID (from disc header), Value: max supported players.
    /// IDs match the format used in Mednafen's Saturn database (ss/db.cpp).
    @objc static var multiTapSaturnGames: [String: NSNumber] {
        struct Static {
            static let dict: [String: NSNumber] = [
                // ----- 3-player games -----
                "T-9521G"    : 3,  // Athlete Kings (Japan)
                "T-5711G"    : 3,  // Athlete Kings (Europe) / Decathlete
                "T-30601G"   : 3,  // Capcom Generation 4 (Japan)

                // ----- 4-player games -----
                "T-1216G"    : 4,  // Arcade Gears Vol. 1 - Pu-Li-Ru-La (Japan)
                "T-36101G"   : 4,  // Baku Baku Animal (Japan)
                "GS-9126"    : 4,  // Baku Baku Animal (Japan, alt)
                "T-8128G"    : 4,  // BioHazard (Japan) / Resident Evil (Saturn)
                "T-4518G"    : 4,  // Bust-A-Move 2 / Puzzle Bobble 2 (Japan)
                "T-18503G"   : 4,  // Capcom vs. SNK (Japan, later entry)
                "GS-9142"    : 4,  // Daytona USA (Japan, standard)
                "MK-81021"   : 4,  // Daytona USA (USA)
                "GS-9143"    : 4,  // Daytona USA Championship Circuit Edition (Japan)
                "MK-81060"   : 4,  // Daytona USA CCE (USA)
                "T-25405G"   : 4,  // DonPachi (Japan)
                "T-8129G"    : 4,  // Dungeons & Dragons Collection (Japan)
                "T-1241G"    : 4,  // Final Fight Revenge (Japan)
                "GS-9112"    : 4,  // Hang-On GP '95 (Japan)
                "GS-9191"    : 4,  // Hang-On GP '96 (Japan)
                "T-15913H"   : 4,  // Hexen (USA)
                "T-25432G"   : 4,  // King of Fighters '95 (Japan)
                "T-3117G"    : 4,  // King of Fighters '96 (Japan)
                "T-3119G"    : 4,  // King of Fighters '97 (Japan)
                "T-31501G"   : 4,  // Lode Runner (Japan)
                "T-30002G"   : 4,  // Magical Drop III (Japan)
                "MK-81018"   : 4,  // Manx TT Super Bike (USA)
                "GS-9018"    : 4,  // Manx TT Super Bike (Japan)
                "T-8134G"    : 4,  // Marvel Super Heroes (Japan)
                "T-7032H"    : 4,  // Micro Machines V3 (Europe)
                "T-7033H"    : 4,  // Micro Machines Military (Europe)
                "T-7034H"    : 4,  // Micro Machines Turbo Tournament 96 (Europe)
                "T-20114G"   : 4,  // Nights Into Dreams (Japan, later print)
                "GS-9047"    : 4,  // NiGHTS Into Dreams (Japan)
                "MK-81048"   : 4,  // NiGHTS Into Dreams (USA)
                "T-36802G"   : 4,  // Penky (Japan)
                "GS-9174"    : 4,  // Sega Rally Championship (Japan)
                "MK-81031"   : 4,  // Sega Rally Championship (USA)
                "GS-9115"    : 4,  // Virtua Fighter (Japan)
                "MK-81001"   : 4,  // Virtua Fighter (USA)
                "GS-9011"    : 4,  // Virtua Fighter 2 (Japan, early)
                "GS-9116"    : 4,  // Virtua Fighter 2 (Japan)
                "MK-81019"   : 4,  // Virtua Fighter 2 (USA)
                "T-14401G"   : 4,  // Virtua Fighter Kids (Japan)
                "MK-81055"   : 4,  // Virtua Fighter Kids (USA)
                "T-20102G"   : 4,  // Bulk Slash (Japan)
                "T-24504G"   : 4,  // Cotton 2 (Japan)
                "T-21502G"   : 4,  // Cotton Boomerang (Japan)
                "T-22204G"   : 4,  // Dodonpachi (Japan)
                "T-1211G"    : 4,  // Super Puzzle Fighter II Turbo (Japan)
                "T-1218G"    : 4,  // X-Men vs. Street Fighter (Japan, 2-4 player)

                // ----- 6-player games (TeamTap) -----
                "MK-81070"   : 6,  // Saturn Bomberman (USA/International — also 10-player but 6 w/ 1 tap)
                "T-17708G"   : 6,  // Saturn Bomberman (Japan)
                "T-6302G"    : 6,  // Super Bomberman (Japan variant)
                "T-1220G"    : 6,  // Marvel Super Heroes vs. Street Fighter (Japan)
                "T-12304H"   : 6,  // Marvel Super Heroes vs. Street Fighter (USA)
                "T-1230G"    : 6,  // Street Fighter Collection (Japan)
                "T-1231G"    : 6,  // Street Fighter Collection 2 (Japan)
                "T-1232G"    : 6,  // Street Fighter Zero 3 (Japan)
                "T-1233H"    : 6,  // Street Fighter Alpha 3 (USA)
                "T-21507G"   : 6,  // Groove on Fight (Japan)
                "T-1219G"    : 6,  // X-Men vs. Street Fighter Rev.A (Japan)
                "T-12301H"   : 6,  // X-Men vs. Street Fighter (USA)
                "T-10316G"   : 6,  // Winter Heat (Japan)
                "MK-81111"   : 6,  // Winter Heat (USA)
                "T-22401G"   : 6,  // Soukyugurentai / Terra Diver (Japan)
                "T-2501G"    : 6,  // Capcom Generation 5 (Japan)
            ]
        }
        return Static.dict
    }

    /// Saturn games where the multitap should be enabled on port 2 instead of port 1.
    /// Most games use port 1; list games here that specifically require port 2.
    @objc static var multiTapSaturnPort2Games: [String] {
        return []
    }
}
