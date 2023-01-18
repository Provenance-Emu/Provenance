//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

public enum PVLogLevel: String {
    case U
    case Error
    case Warn
    case Info
    case Debug

    #if DEBUG
    public static let defaultDebugLevel: PVLogLevel = .Debug
    #else
    public static let defaultDebugLevel: PVLogLevel = .Warn
    #endif
}
