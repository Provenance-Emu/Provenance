//
//  ThemeOption.swift
//  PVSupport
//
//  Created by Dave Nicolson on 20.11.22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

@objc
public enum ThemeOptions: UInt, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable {
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

    public var row: UInt {
        return rawValue
    }

    public static var themes: [ThemeOptions] {
        return allCases
    }

    public static func optionForRow(_ row: UInt) -> ThemeOptions {
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
