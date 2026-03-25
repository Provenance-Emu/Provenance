//
//  MednafenGameCoreOptions+LightGun.swift
//  PVMednafen
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation

/// PSX GunCon (Namco NPC-103) light gun game database.
/// Keys are BIOS serial strings; value is ignored (use the key set for membership tests).
@objc public extension MednafenGameCoreOptions {
    /// Set of known PSX serial IDs that use a GunCon light gun.
    /// Caller should check `[MednafenGameCoreOptions psxLightGunGames][serial] != nil`.
    @objc static var psxLightGunGames: [String: NSNumber] {
        struct Static {
            static let dict: [String: NSNumber] = [
                // ---- Time Crisis ----
                "SLUS-00405" : 1, // Time Crisis (USA)
                "SLES-00284" : 1, // Time Crisis (Europe)
                "SLPM-86012" : 1, // Time Crisis (Japan)
                "SLPS-00931" : 1, // Time Crisis (Japan, alt)

                // ---- Time Crisis: Project Titan ----
                "SLUS-01336" : 1, // Time Crisis: Project Titan (USA)
                "SLES-03330" : 1, // Time Crisis: Project Titan (Europe)

                // ---- Point Blank (GunBullet) ----
                "SLUS-00481" : 1, // Point Blank (USA)
                "SLES-00297" : 1, // Point Blank (Europe)
                "SLPS-00434" : 1, // GunBullet (Japan)

                // ---- Point Blank 2 (GunBullet 2) ----
                "SLUS-00879" : 1, // Point Blank 2 (USA)
                "SLES-01399" : 1, // Point Blank 2 (Europe)
                "SLPS-01508" : 1, // GunBullet 2 (Japan)

                // ---- Point Blank 3 ----
                "SLUS-01061" : 1, // Point Blank 3 (USA)
                "SLES-03490" : 1, // Point Blank 3 (Europe)

                // ---- Lethal Enforcers ----
                "SLUS-00293" : 1, // Lethal Enforcers (USA)
                "SLES-00214" : 1, // Lethal Enforcers (Europe)

                // ---- Lethal Enforcers I & II: Gun Fighters ----
                "SLUS-00573" : 1, // Lethal Enforcers I & II (USA)
                "SLES-00889" : 1, // Lethal Enforcers I & II (Europe)

                // ---- Die Hard Trilogy (gun stages use GunCon) ----
                "SLUS-00119" : 1, // Die Hard Trilogy (USA)
                "SCES-00004" : 1, // Die Hard Trilogy (Europe)
                "SLPS-00553" : 1, // Die Hard Trilogy (Japan)

                // ---- Die Hard Trilogy 2 ----
                "SLUS-00790" : 1, // Die Hard Trilogy 2 (USA)
                "SLES-02274" : 1, // Die Hard Trilogy 2 (Europe)

                // ---- Crypt Killer ----
                "SLUS-00397" : 1, // Crypt Killer (USA)
                "SLES-00503" : 1, // Crypt Killer (Europe)

                // ---- Area 51 ----
                "SLUS-00132" : 1, // Area 51 (USA)

                // ---- Maximum Force ----
                "SLUS-00503" : 1, // Maximum Force (USA)

                // ---- Judge Dredd ----
                "SLUS-00630" : 1, // Judge Dredd (USA)
                "SLES-01196" : 1, // Judge Dredd (Europe)

                // ---- Elemental Gearbolt ----
                "SLUS-00654" : 1, // Elemental Gearbolt (USA)
                "SLPS-01166" : 1, // Elemental Gearbolt (Japan)
                "SLES-01353" : 1, // Elemental Gearbolt (Europe)

                // ---- GunFighter: The Legend of Jesse James ----
                "SLUS-00895" : 1, // GunFighter (USA)
                "SLES-02808" : 1, // GunFighter (Europe)

                // ---- Mighty Hits: Special (Japan) ----
                "SLPS-00887" : 1,

                // ---- Horned Owl ----
                "SLPS-00170" : 1, // Horned Owl (Japan)

                // ---- Policenauts (Japan) ----
                // Does not actually use a light gun; omitted intentionally.

                // ---- Steel Dragon EX ----
                "SLPS-01180" : 1, // Steel Dragon EX (Japan)
            ]
        }
        return Static.dict
    }
}
