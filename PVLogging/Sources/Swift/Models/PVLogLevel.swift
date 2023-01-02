//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

public struct PVLogLevel: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let U = PVLogLevel(rawValue: 1 << 0)
    public static let Error = PVLogLevel(rawValue: 1 << 1)
    public static let Warn = PVLogLevel(rawValue: 1 << 2)
    public static let Info = PVLogLevel(rawValue: 1 << 3)
    public static let Debug = PVLogLevel(rawValue: 1 << 4)
}
