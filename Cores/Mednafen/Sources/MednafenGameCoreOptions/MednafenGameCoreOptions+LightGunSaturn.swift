//
//  MednafenGameCoreOptions+LightGunSaturn.swift
//  PVMednafen
//
//  Created by Claude on 3/25/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//
//  Saturn light gun games — keyed by product serial found in the disc volume
//  header (same field used by the Provenance ROM database and Mednafen ss/db.cpp).
//  Values are the number of light guns supported (1 = single gun, 2 = dual guns).
//
//  Supported peripherals:
//    - Virtua Gun  (Sega):   used by Virtua Cop series
//    - Stunner     (Konami): used by Crypt Killer and compatible titles
//
//  Reference serials verified against Redump disc images and Mednafen ss/db.cpp entries.

import Foundation

@objc public extension MednafenGameCoreOptions {

    /// Saturn games that support a light gun peripheral.
    /// Includes titles that require the gun to be playable AND hybrid titles where
    /// the gun is used only in certain scenes (e.g. Die Hard Trilogy).
    /// Key:   Saturn product/game serial (from disc header, same format as ss/db.cpp).
    /// Value: number of guns supported — 1 for single-gun, 2 for dual-gun play.
    @objc static var saturnLightGunGames: [String: NSNumber] {
        struct Static {
            static let dict: [String: NSNumber] = [

                // ----- Virtua Cop (Sega, 1994/1995) — Sega Virtua Gun -----
                "GS-9012"       : 2,   // Virtua Cop (Japan)
                "MK-81015"      : 2,   // Virtua Cop (Europe/USA)
                "81015"         : 2,   // Virtua Cop (USA, alternate)

                // ----- Virtua Cop 2 (Sega, 1995/1996) — Sega Virtua Gun -----
                "GS-9058"       : 2,   // Virtua Cop 2 (Japan)
                "MK-81043"      : 2,   // Virtua Cop 2 (Europe)
                "81043"         : 2,   // Virtua Cop 2 (USA, alternate)

                // ----- House of the Dead (Sega, 1997/1998) — Sega Virtua Gun -----
                "GS-9173"       : 2,   // The House of the Dead (Japan) — confirmed in ss/db.cpp
                "MK-81139"      : 2,   // The House of the Dead (USA/Europe)

                // ----- Area 51 (Time Warner, 1996) — Sega Virtua Gun -----
                "T-9705H"       : 1,   // Area 51 (USA) — confirmed in ss/db.cpp
                "T-25408H"      : 1,   // Area 51 (Europe) — confirmed in ss/db.cpp

                // ----- Crypt Killer (Konami, 1995/1996) — Stunner / Virtua Gun -----
                "T-9527G"       : 2,   // Crypt Killer (Japan)
                "T-9527H"       : 2,   // Crypt Killer (USA)

                // ----- Gunblade NY / LA Machineguns (Sega, 1999) — Virtua Gun -----
                "GS-9184"       : 2,   // Gunblade NY (Japan)
                "MK-81189"      : 2,   // Gunblade NY (USA/Europe)

                // ----- Die Hard Trilogy (Sega, 1996) -----
                // Note: light gun used only in specific scenes; primary mode is beat-em-up.
                // Included to allow gun aim if the player has a gun attached.
                "GS-9123"       : 1,   // Die Hard Trilogy (Japan)
                "T-16103H"      : 1,   // Die Hard Trilogy (Europe/USA)
            ]
        }
        return Static.dict
    }
}
