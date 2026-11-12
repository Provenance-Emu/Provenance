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

public protocol ThemeOptions: CustomStringConvertible, CaseIterable {}

public struct ThemeOptionBridge: Defaults.Bridge, Sendable {
    public typealias Value = ThemeOption
    public typealias Serializable = [String: String]
    
    public func serialize(_ value: ThemeOption?) -> [String: String]? {
        guard let value else { return nil }
        switch value {
        case .standard(let option):
            return ["type": "standard", "value": option.rawValue]
        case .retrowave:
            return ["type": "retrowave", "value": "retrowave"]
        case .cga(let option):
            return ["type": "cga", "value": option.rawValue]
        case .console(let preset):
            return ["type": "console", "value": preset.rawValue]
        case .custom:
            return ["type": "custom", "value": "custom"]
        }
    }
    
    public func deserialize(_ object: [String: String]?) -> ThemeOption? {
        guard let object, let type = object["type"], let value = object["value"] else { return nil }
        switch type {
        case "standard":
            return .standard(ThemeOptionsStandard(rawValue: value) ?? .dark)
        case "retrowave":
            return .retrowave
        case "cga":
            return .cga(ThemeOptionsCGA(rawValue: value) ?? .blue)
        case "console":
            return ConsoleThemePreset(rawValue: value).map(ThemeOption.console)
        case "custom":
            return .custom
        default:
            return nil
        }
    }
}

public enum ThemeOption: Defaults.Serializable, Equatable, CustomStringConvertible {
    case standard(ThemeOptionsStandard)
    case cga(ThemeOptionsCGA)
    case retrowave
    case console(ConsoleThemePreset)
    case custom
    
    public static let bridge = ThemeOptionBridge()
    
    public var description: String {
        switch self {
        case .standard(let option): return "Standard " + option.description
        case .retrowave: return "RetroWave"
        case .console(let preset): return preset.theme.name
        case .custom: return "Custom Theme"
        case .cga(let option): return "CGA " + option.description
        }
    }
    
    public static var allCases: [ThemeOption] {
        return ThemeOptionsStandard.allCases.map { ThemeOption.standard($0) } +
               ThemeOptionsCGA.allCases.map { ThemeOption.cga($0) } +
               ConsoleThemePreset.allCases.map { ThemeOption.console($0) } + [.retrowave, .custom]
    }
    
    public static func == (lhs: ThemeOption, rhs: ThemeOption) -> Bool {
        switch (lhs, rhs) {
        case (.standard(let l), .standard(let r)): return l == r
        case (.cga(let l), .cga(let r)): return l == r
        case (.retrowave, .retrowave), (.custom, .custom): return true
        case (.console(let l), .console(let r)): return l == r
        default: return false
        }
    }
}

public enum ThemeOptionsStandard: String, ThemeOptions {
    case light
    case dark
    case auto
    
    public var description: String {
        rawValue.capitalized
    }
}

public enum ThemeOptionsCGA: String, ThemeOptions {
    case blue
    case cyan
    case green
    case magenta
    case red
    case yellow
    case purple
    
    public var description: String {
        rawValue.capitalized
    }
}

public extension Defaults.Keys {
    static let theme = Key<ThemeOption>("theme", default: .standard(.dark))
}
