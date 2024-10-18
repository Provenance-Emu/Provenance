//
//  ThemeOption.swift
//  PVSupport
//
//  Created by Dave Nicolson on 20.11.22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import Defaults

public typealias ThemeOptions = CustomStringConvertible & CaseIterable & UserDefaultsRepresentable & Defaults.Serializable

public enum ThemeOptionsStandard: String, ThemeOptions {
    case light
    case dark
    case auto

    public var description: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }

    public static var themes: [ThemeOptionsStandard] {
        return allCases
    }

    public static func optionForRow(_ row: UInt) -> ThemeOptionsStandard {
        switch row {
        case 0:
            return .light
        case 1:
            return .dark
        case 2:
            return .auto
        default:
            ELOG("Bad row \(row)")
            return .dark
        }
    }
}

public enum ThemeOptionsCGA: UInt, ThemeOptions {
    case blue
    case cyan
    case green
    case magenta
    case red
    case yellow

    public var description: String {
        switch self {
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .magenta: return "Magenta"
        case .red: return "Red"
        case .yellow: return "Yellow"
        }
    }

    public var row: UInt {
        return rawValue
    }

    public static var themes: [ThemeOptionsCGA] {
        return allCases
    }

    public static func optionForRow(_ row: UInt) -> ThemeOptionsCGA {
        switch row {
        case 0:
            return .blue
        case 1:
            return .cyan
        case 2:
            return .green
        case 3:
            return .magenta
        case 4:
            return .red
        case 5:
            return .yellow
        default:
            ELOG("Bad row \(row)")
            return .blue
        }
    }
}
