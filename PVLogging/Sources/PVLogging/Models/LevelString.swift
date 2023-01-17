//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

@objc
public enum LevelString: Int {
    case U
    case Error
    case Warn
    case Info
    case Debug
    
    var string: String {
        switch self {
        case .U: return "U"
        case .Error: return "**Error**"
        case .Warn: return "**Warn**"
        case .Info: return "I"
        case .Debug: return "D"
        }
    }
}
