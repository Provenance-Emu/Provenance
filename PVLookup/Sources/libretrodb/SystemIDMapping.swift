import Foundation

/// Handles system ID mapping between OpenVGDB and libretrodb
public enum SystemIDMapping {
    /// Maps OpenVGDB system IDs to libretrodb platform IDs
    static let openVGDBToLibretroMap: [Int: Int] = [
        1: 73,    // 3DO -> 3DO
        2: 41,    // Arcade -> Arcade Games
        3: 38,    // Atari 2600 -> 2600
        4: 77,    // Atari 5200 -> 5200
        5: 34,    // Atari 7800 -> 7800
        6: 79,    // Atari Lynx -> Lynx
        7: 29,    // Atari Jaguar -> Jaguar
        9: 33,    // WonderSwan -> WonderSwan
        10: 109,  // WonderSwan Color -> WonderSwan Color
        11: 114,  // ColecoVision -> ColecoVision
        12: 69,   // Vectrex -> Vectrex
        13: 92,   // Intellivision -> Intellivision
        14: 108,  // PC Engine/TurboGrafx-16 -> PC Engine - TurboGrafx 16
        15: 12,   // PC Engine CD/TurboGrafx-CD -> PC Engine CD - TurboGrafx-CD
        16: 20,   // PC-FX -> PC-FX
        18: 40,   // Famicom Disk System -> Family Computer Disk System
        19: 75,   // Game Boy -> Game Boy
        20: 115,  // Game Boy Advance -> Game Boy Advance
        21: 86,   // Game Boy Color -> Game Boy Color
        22: 51,   // GameCube -> GameCube
        23: 22,   // Nintendo 64 -> Nintendo 64
        24: 90,   // Nintendo DS -> Nintendo DS
        25: 28,   // NES -> Nintendo Entertainment System
        26: 37,   // SNES -> Super Nintendo Entertainment System
        27: 113,  // Virtual Boy -> Virtual Boy
        28: 101,  // Wii -> Wii
        29: 14,   // 32X -> 32X
        30: 78,   // Game Gear -> Game Gear
        31: 83,   // Master System -> Master System - Mark III
        32: 2,    // Sega CD -> Mega-CD - Sega CD
        33: 15,   // Genesis/Mega Drive -> Mega Drive - Genesis
        34: 47,   // Saturn -> Saturn
        35: 76,   // SG-1000 -> SG-1000
        36: 9,    // Neo Geo Pocket -> Neo Geo Pocket
        37: 71,   // Neo Geo Pocket Color -> Neo Geo Pocket Color
        38: 6,    // PlayStation -> PlayStation
        39: 61,   // PSP -> PlayStation Portable
        40: 35,   // Odyssey2 -> Odyssey2
        42: 36,   // MSX -> MSX
        43: 63    // MSX2 -> MSX2
    ]

    /// Maps libretrodb platform IDs to OpenVGDB system IDs
    static let libretrotoOpenVGDBMap: [Int: Int] = {
        Dictionary(uniqueKeysWithValues: openVGDBToLibretroMap.map { ($1, $0) })
    }()

    /// Convert OpenVGDB system ID to libretrodb platform ID
    /// - Parameter openVGDBID: System ID from OpenVGDB
    /// - Returns: Corresponding platform ID for libretrodb, or nil if no mapping exists
    static func convertToLibretroID(_ openVGDBID: Int) -> Int? {
        return openVGDBToLibretroMap[openVGDBID]
    }

    /// Convert libretrodb platform ID to OpenVGDB system ID
    /// - Parameter libretroDB: Platform ID from libretrodb
    /// - Returns: Corresponding system ID for OpenVGDB, or nil if no mapping exists
    static func convertToOpenVGDBID(_ libretroDB: Int) -> Int? {
        return libretrotoOpenVGDBMap[libretroDB]
    }

    /// Convert array of OpenVGDB system IDs to libretrodb platform IDs
    /// - Parameter openVGDBIDs: Array of OpenVGDB system IDs
    /// - Returns: Array of corresponding libretrodb platform IDs (excluding any that couldn't be mapped)
    static func convertToLibretroIDs(_ openVGDBIDs: [Int]) -> [Int] {
        return openVGDBIDs.compactMap { convertToLibretroID($0) }
    }

    /// Convert array of libretrodb platform IDs to OpenVGDB system IDs
    /// - Parameter libretroDB: Array of libretrodb platform IDs
    /// - Returns: Array of corresponding OpenVGDB system IDs (excluding any that couldn't be mapped)
    static func convertToOpenVGDBIDs(_ libretroDB: [Int]) -> [Int] {
        return libretroDB.compactMap { convertToOpenVGDBID($0) }
    }
}
