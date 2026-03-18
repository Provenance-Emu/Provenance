//
//  MednafenGameCoreOptions+MultiTapSaturn.swift
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/17/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//
//  Saturn TeamTap games — keyed by product serial found in the disc volume
//  header (same field used by the Provenance ROM database and Mednafen ss/db.cpp).
//  Values are the max supported player count with one TeamTap on sport1.

import Foundation

@objc public extension MednafenGameCoreOptions {

    /// Saturn games that support the TeamTap multitap adapter.
    /// Key: Saturn product/game ID (from disc header), Value: max supported players.
    /// IDs match the format used in Mednafen's Saturn database (ss/db.cpp).
    @objc static var multiTapSaturnGames: [String: NSNumber] {
        struct Static {
            static let dict: [String: NSNumber] = [

                // ----- 3-player games -----
                "T-9521G"      : 3,  // Athlete Kings / Decathlete (Japan, early print)
                "T-5711G"      : 3,  // Athlete Kings / Decathlete (Europe, early print)
                "T-30601G"     : 3,  // Capcom Generation 4 (Japan)

                // ----- 4-player games -----
                "T-1216G"      : 4,  // Arcade Gears Vol. 1 - Pu-Li-Ru-La (Japan)
                "T-36101G"     : 4,  // Baku Baku Animal (Japan)
                "GS-9126"      : 4,  // Baku Baku Animal (Japan, alt)
                "T-8128G"      : 4,  // BioHazard (Japan) / Resident Evil (Saturn)
                "T-4518G"      : 4,  // Bust-A-Move 2 / Puzzle Bobble 2 (Japan)
                "T-18503G"     : 4,  // Capcom vs. SNK / Steep Slope Sliders (Japan)
                "T-18503H"     : 4,  // Steep Slope Sliders (USA)
                "GS-9142"      : 4,  // Daytona USA (Japan, standard)
                "MK-81021"     : 4,  // Daytona USA (USA)
                "GS-9143"      : 4,  // Daytona USA Championship Circuit Edition (Japan)
                "MK-81060"     : 4,  // Daytona USA CCE (USA)
                "T-25405G"     : 4,  // DonPachi (Japan)
                "T-8129G"      : 4,  // Dungeons & Dragons Collection (Japan)
                "T-17725G"     : 4,  // Fever FIFA Soccer (Japan)
                "T-1241G"      : 4,  // Final Fight Revenge (Japan)
                "T-5024H"      : 4,  // FIFA 97 (USA)
                "MK-81082-50"  : 4,  // FIFA 97 (Europe)
                "GS-9112"      : 4,  // Hang-On GP '95 (Japan)
                "GS-9191"      : 4,  // Hang-On GP '96 (Japan)
                "T-15913H"     : 4,  // Hexen (USA)
                "T-25432G"     : 4,  // King of Fighters '95 (Japan)
                "T-3117G"      : 4,  // King of Fighters '96 (Japan)
                "T-3119G"      : 4,  // King of Fighters '97 (Japan)
                "T-31501G"     : 4,  // Lode Runner (Japan)
                "T-30002G"     : 4,  // Magical Drop III (Japan)
                "MK-81018"     : 4,  // Manx TT Super Bike (USA)
                "GS-9018"      : 4,  // Manx TT Super Bike (Japan)
                "T-8134G"      : 4,  // Marvel Super Heroes (Japan)
                "T-7032H"      : 4,  // Micro Machines V3 (Europe)
                "T-7033H"      : 4,  // Micro Machines Military (Europe)
                "T-7034H"      : 4,  // Micro Machines Turbo Tournament 96 (Europe)
                "T-8130G"      : 4,  // NBA Action '98 (Japan)
                "T-8130H"      : 4,  // NBA Action '98 (USA)
                "T-22403G"     : 4,  // NBA Live 97 (Japan)
                "T-22403H"     : 4,  // NBA Live 97 (USA)
                "T-20114G"     : 4,  // NiGHTS Into Dreams (Japan, later print)
                "GS-9047"      : 4,  // NiGHTS Into Dreams (Japan)
                "MK-81048"     : 4,  // NiGHTS Into Dreams (USA)
                "T-36802G"     : 4,  // Penky (Japan)
                "GS-9174"      : 4,  // Sega Rally Championship (Japan)
                "MK-81031"     : 4,  // Sega Rally Championship (USA)
                "GS-9175"      : 4,  // Sega Worldwide Soccer 98 (Japan)
                "MK-81101-50"  : 4,  // Sega Worldwide Soccer 98 (Europe)
                "T-8117G"      : 4,  // Virtual Volleyball (Japan)
                "GS-9115"      : 4,  // Virtua Fighter (Japan)
                "MK-81001"     : 4,  // Virtua Fighter (USA)
                "GS-9011"      : 4,  // Virtua Fighter 2 (Japan, early)
                "GS-9116"      : 4,  // Virtua Fighter 2 (Japan)
                "MK-81019"     : 4,  // Virtua Fighter 2 (USA)
                "T-14401G"     : 4,  // Virtua Fighter Kids (Japan)
                "MK-81055"     : 4,  // Virtua Fighter Kids (USA)
                "T-20102G"     : 4,  // Bulk Slash (Japan)
                "T-24504G"     : 4,  // Cotton 2 (Japan)
                "T-21502G"     : 4,  // Cotton Boomerang (Japan)
                "T-22204G"     : 4,  // Dodonpachi (Japan)
                "T-1211G"      : 4,  // Super Puzzle Fighter II Turbo (Japan)
                "T-1218G"      : 4,  // X-Men vs. Street Fighter (Japan, 2-4 player)

                // ----- 5-player games -----
                "T-14409G"     : 5,  // Bomberman Wars (Japan)

                // ----- 6-player games (TeamTap) -----
                "MK-81036-50"  : 6,  // Athlete Kings / Decathlete (Europe)
                "GS-9028"      : 6,  // Athlete Kings / Decathlete (Japan)
                "81036"        : 6,  // Athlete Kings / Decathlete (USA)
                "T-14402G"     : 6,  // Game no Tatsujin (Japan)
                "T-21507G"     : 6,  // Groove on Fight (Japan)
                "T-1220G"      : 6,  // Marvel Super Heroes vs. Street Fighter (Japan)
                "T-12304H"     : 6,  // Marvel Super Heroes vs. Street Fighter (USA)
                "T-14404G"     : 6,  // Saturn Bomberman (Japan)
                "T-14404H"     : 6,  // Saturn Bomberman (Japan Rev 1)
                "MK-81081-50"  : 6,  // Saturn Bomberman (Europe)
                "80211"        : 6,  // Saturn Bomberman (USA, alt)
                "MK-81070"     : 6,  // Saturn Bomberman (USA/International)
                "T-17708G"     : 6,  // Saturn Bomberman (Japan, alt)
                "T-14405G"     : 6,  // Bomberman Fight!! (Japan)
                "T-22401G"     : 6,  // Soukyugurentai / Terra Diver (Japan)
                "T-1230G"      : 6,  // Street Fighter Collection (Japan)
                "T-1231G"      : 6,  // Street Fighter Collection 2 (Japan)
                "T-1232G"      : 6,  // Street Fighter Zero 3 (Japan)
                "T-1233H"      : 6,  // Street Fighter Alpha 3 (USA)
                "T-6302G"      : 6,  // Super Bomberman (Japan variant)
                "T-14408G"     : 6,  // Taisen Mahjong Haoto DX (Japan)
                "T-10316G"     : 6,  // Winter Heat (Japan)
                "MK-81111"     : 6,  // Winter Heat (USA)
                "T-18606G"     : 6,  // Winning Post 3 Premium (Japan)
                "T-1219G"      : 6,  // X-Men vs. Street Fighter Rev.A (Japan)
                "T-12301H"     : 6,  // X-Men vs. Street Fighter (USA)
                "T-2501G"      : 6,  // Capcom Generation 5 (Japan)
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
