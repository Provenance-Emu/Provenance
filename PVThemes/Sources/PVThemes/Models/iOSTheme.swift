//
//  iOSTheme.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 7/22/24.
//

import Foundation
import SwiftMacros

//public struct iOSTheme: UXThemePalette, Codable, Sendable, Hashable, Observable {
//
//    public let name: String
//    public let palette: any UXThemePalette
//
//    public init(name: String, palette: any UXThemePalette) {
//        self.name = name
//        self.palette = palette
//    }
//
//    // Custom init from Decoder
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        name = try container.decode(String.self, forKey: .name)
//        palette = try container.decode(iOSTheme.self, forKey: .palette)
//    }
//
//    // Custom encode to Encoder
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(name, forKey: .name)
//        try container.encode(palette, forKey: .palette)
//    }
//
//    enum CodingKeys: String, CodingKey {
//        case name
//        case palette
//    }
//}
