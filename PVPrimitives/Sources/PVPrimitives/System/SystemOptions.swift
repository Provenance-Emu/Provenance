//
//  SystemOptions.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation

public struct SystemOptions: OptionSet, Codable, Sendable {
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int

    public static let cds = SystemOptions(rawValue: 1 << 0)
    public static let portable = SystemOptions(rawValue: 1 << 1)
    public static let rumble = SystemOptions(rawValue: 1 << 2)
}
