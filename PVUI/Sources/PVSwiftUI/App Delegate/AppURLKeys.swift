//
//  AppURLKeys.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/1/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - Skin Install Notifications

public extension Notification.Name {
    /// Posted after a skin deep-link install succeeds. userInfo key: "skinName" (String).
    static let skinInstallDidSucceed = Notification.Name("PVSkinInstallDidSucceed")
    /// Posted after a skin deep-link install fails. userInfo key: "error" (String).
    static let skinInstallDidFail = Notification.Name("PVSkinInstallDidFail")
    /// Posted when a `provenance://netplay/join` deep link is received.
    /// userInfo keys: "host" (String), "port" (UInt16), "relay" (String?), "game" (String?).
    static let netplayJoinRequest = Notification.Name("PVNetplayJoinRequest")
}

public enum AppURLKeys: String, Codable {
    case open
    case save
    /// Screen navigation: provenance://screen/<path>
    case screen
    /// Debug/automation actions: provenance://debug/<action>
    case debug
    /// Install a remote skin: provenance://install-skin?url=<encoded-url>
    case installSkin = "install-skin"
    /// Netplay invite join: provenance://netplay/join?host=…&port=…&relay=…&game=…
    case netplay

    public enum OpenKeys: String, Codable {
        case md5Key = "PVGameMD5Key"
        /// Direct md5 parameter for simplified URL format (provenance://open?md5=...)
        case md5 = "md5"
        /// Save state primary key (provenance://open?saveStateId=...)
        case saveStateId = "saveStateId"
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
    public enum InstallSkinKeys: String, Codable {
        /// The URL of the skin file to download and install.
        case url = "url"
    }
    public enum NetplayJoinKeys: String, Codable {
        /// The host IP or hostname to connect to.
        case host
        /// The port number (1–65535). Port 0 is rejected and falls back to the default (55435).
        case port
        /// Optional relay server hostname for NAT traversal.
        case relay
        /// Optional game name for display purposes.
        case game
    }
}
