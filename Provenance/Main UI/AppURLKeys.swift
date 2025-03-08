//
//  AppURLKeys.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/1/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//


public enum AppURLKeys: String, Codable {
    case open
    case save

    public enum OpenKeys: String, Codable {
        case md5Key = "PVGameMD5Key"
        /// Direct md5 parameter for simplified URL format (provenance://open?md5=...)
        case md5 = "md5"
        /// System identifier or name for fuzzy search
        case system = "system"
        /// Game title for fuzzy search
        case title = "title"
    }
    public enum SaveKeys: String, Codable {
        case lastQuickSave
        case lastAnySave
        case lastManualSave
    }
}
