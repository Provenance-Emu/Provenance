//
//  PVLogLevel.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

@objc
public enum PVLogLevel: Int, CaseIterable {
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

extension PVLogLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case .U: return "U"
        case .Error: return "Error"
        case .Warn: return "Warn"
        case .Info: return "Info"
        case .Debug: return "Debug"
        }
    }
}

extension PVLogLevel: RawRepresentable {
}
