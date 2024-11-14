//
//  FilterModel.swift
//  PVSettings
//
//  Created by Joseph Mattiello on 11/13/24.
//

import Foundation
import Defaults

public enum OpenGLFilterModeOption: String, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable, Defaults.Serializable {
    case none
    case CRT

    public static var defaultValue: Self { .none }

    public var description: String { rawValue.capitalized }
}

extension OpenGLFilterModeOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension OpenGLFilterModeOption: Equatable {
    public static func == (lhs: OpenGLFilterModeOption, rhs: OpenGLFilterModeOption) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

public enum MetalFilterModeOption: RawRepresentable, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable, Defaults.Serializable {

    case none
    case auto(crt: MetalFilterSelectionOption, lcd: MetalFilterSelectionOption)
    case always(filter: MetalFilterSelectionOption)
    public static var defaultValue: Self { .none }

    public init?(rawValue: String) {
        switch rawValue {
        case "None":
            self = .none
        case let str where str.hasPrefix("Auto("):
            // Extract content between parentheses
            let content = str.dropFirst(5).dropLast(1)
            let parts = content.split(separator: ",").map(String.init)
            guard parts.count == 2,
                  let crt = MetalFilterSelectionOption(rawValue: parts[0].trimmingCharacters(in: .whitespaces)),
                  let lcd = MetalFilterSelectionOption(rawValue: parts[1].trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            self = .auto(crt: crt, lcd: lcd)
        case let str where str.hasPrefix("Always("):
            // Extract content between parentheses
            let content = str.dropFirst(7).dropLast(1)
            guard let filter = MetalFilterSelectionOption(rawValue: content.trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            self = .always(filter: filter)
        default:
            return nil
        }
    }

    public static var allCases: [MetalFilterModeOption] { [
        .none,
        .auto(crt: .simpleCRT, lcd: .lcd),
        .auto(crt: .complexCRT, lcd: .lcd),
        .auto(crt: .simpleCRT, lcd: .none),
        .auto(crt: .complexCRT, lcd: .none),
        .auto(crt: .none, lcd: .lcd),
        .always(filter: .simpleCRT),
        .always(filter: .complexCRT),
        .always(filter: .lcd),
        .always(filter: .gameBoy)
    ]}


    public var rawValue: String {
        switch self {
        case .none:
            return "None"
        case .auto(crt: let crt, lcd: let lcd):
            return "Auto(\(crt.rawValue), \(lcd.rawValue))"
        case .always(filter: let filter):
            return "Always(\(filter.rawValue))"
        }
    }

    public var description: String { rawValue }
}

extension MetalFilterModeOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension MetalFilterModeOption: Equatable {
    public static func == (lhs: MetalFilterModeOption, rhs: MetalFilterModeOption) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

public enum MetalFilterSelectionOption: String, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable, Defaults.Serializable {
    case none
    case simpleCRT
    case complexCRT
    case lcd
    case lineTron
    case megaTron
    case ulTron
    case gameBoy
    case vhs
    public enum ScreenType: String, CaseIterable {
        case crt
        case lcd
    }

    public var screenType: ScreenType {
        switch self {
        case .none: return .crt
        case .simpleCRT: return .crt
        case .complexCRT: return .crt
        case .lcd: return .lcd
        case .lineTron: return .crt
        case .megaTron: return .crt
        case .ulTron: return .crt
        case .gameBoy: return .crt
        case .vhs: return .crt
        }
    }

    public static var defaultValue: Self { .none }

    public var description: String {
        switch self {
        case .none: return "None"
        case .simpleCRT: return "Simple CRT"
        case .complexCRT: return "Complex CRT"
        case .lcd: return "LCD"
        case .lineTron: return "Line Tron"
        case .megaTron: return "Mega Tron"
        case .ulTron: return "ulTron"
        case .gameBoy: return "Game Boy"
        case .vhs: return "VHS"
        }
    }
}

extension MetalFilterSelectionOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension MetalFilterSelectionOption: Equatable {
    public static func == (lhs: MetalFilterSelectionOption, rhs: MetalFilterSelectionOption) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

public extension Defaults.Keys {
    static let openGLFilterMode = Key<OpenGLFilterModeOption>("openGLFilterMode", default: .none)
    static let metalFilterMode = Key<MetalFilterModeOption>("metalFilterMode", default: .none)

    /// Legacy Settings
//    static let crtFilterEnabled = Key<Bool>("crtFilterEnabled", default: false)
//    static let lcdFilterEnabled = Key<Bool>("lcdFilterEnabled", default: false)
//    static let metalFilter = Key<String>("metalFilter", default: "")
}
