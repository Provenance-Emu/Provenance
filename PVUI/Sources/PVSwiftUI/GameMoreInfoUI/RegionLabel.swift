//
//  RegionLabel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI

public struct RegionLabel {
    public static let regionFlags: [String: String] = [
        "japan": "🇯🇵",
        "jp": "🇯🇵",
        "usa": "🇺🇸",
        "us": "🇺🇸",
        "na": "🇺🇸",
        "north america": "🇺🇸",
        "europe": "🇪🇺",
        "eu": "🇪🇺",
        "pal": "🇪🇺",
        "world": "🌎",
        "wld": "🌎",
        "asia": "🌏",
        "as": "🌏",
        "australia": "🇦🇺",
        "au": "🇦🇺",
        "brazil": "🇧🇷",
        "br": "🇧🇷",
        "china": "🇨🇳",
        "cn": "🇨🇳",
        "korea": "🇰🇷",
        "kr": "🇰🇷",
        "canada": "🇨🇦",
        "ca": "🇨🇦"
    ]

    public static func flag(for region: String) -> String {
        let normalizedRegion = region.lowercased().trimmingCharacters(in: .whitespaces)
        return regionFlags[normalizedRegion] ?? "🌐"
    }

    public static func format(_ region: String) -> String {
        let flag = flag(for: region)
        let name = region.trimmingCharacters(in: .whitespaces)
        return "\(flag) \(name)"
    }
}
