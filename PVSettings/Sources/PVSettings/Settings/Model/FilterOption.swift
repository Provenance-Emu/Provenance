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
//    case lineTron
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
//        case .lineTron: return .crt
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
//        case .lineTron: return "Line Tron"
        case .megaTron: return "Mega Tron"
        case .ulTron: return "ulTron"
        case .gameBoy: return "Game Boy"
        case .vhs: return "VHS"
        }
    }

    /// Whether this filter exposes user-adjustable CRT shader parameters.
    /// Only `simpleCRT` and `complexCRT` have dedicated parameter UIs.
    public var hasCRTParameters: Bool {
        switch self {
        case .simpleCRT, .complexCRT: return true
        default: return false
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

    // MARK: - Simple CRT Shader Parameters
    /// Vertical curvature amount (range: 1.0–10.0, default: 5.0)
    static let simpleCRTCurvVert = Key<Float>("simpleCRTCurvVert", default: 5.0)
    /// Horizontal curvature amount (range: 1.0–10.0, default: 4.0)
    static let simpleCRTCurvHoriz = Key<Float>("simpleCRTCurvHoriz", default: 4.0)
    /// Curvature blend strength (range: 0.0–1.0, default: 0.25)
    static let simpleCRTCurvStrength = Key<Float>("simpleCRTCurvStrength", default: 0.25)
    /// Light boost/gamma compensation (range: 0.1–3.0, default: 1.3)
    static let simpleCRTLightBoost = Key<Float>("simpleCRTLightBoost", default: 1.3)
    /// Vignette darkness at screen edges (range: 0.0–1.0, default: 0.05)
    static let simpleCRTVignStrength = Key<Float>("simpleCRTVignStrength", default: 0.05)
    /// Zoom-out factor to show screen curvature (range: 0.5–2.0, default: 1.1)
    static let simpleCRTZoomOut = Key<Float>("simpleCRTZoomOut", default: 1.1)
    /// Overall brightness multiplier (range: 0.5–1.5, default: 1.0)
    static let simpleCRTBrightness = Key<Float>("simpleCRTBrightness", default: 1.0)

    // MARK: - Complex CRT Shader Parameters
    /// Bloom/glow amount around bright pixels (range: 0.0–6.0, default: 2.0)
    static let complexCRTBloomAmount = Key<Float>("complexCRTBloomAmount", default: 2.0)
    /// Scanline sharpness/hardness (range: 1.0–12.0, default: 4.0)
    static let complexCRTScanlineHardness = Key<Float>("complexCRTScanlineHardness", default: 4.0)
    /// Shadow mask dot hardness (range: 4.0–32.0, default: 16.0)
    static let complexCRTShadowMaskHardness = Key<Float>("complexCRTShadowMaskHardness", default: 16.0)
    /// Simulated CRT rows of resolution (range: 240.0–1080.0, default: 480.0)
    static let complexCRTRowsOfResolution = Key<Float>("complexCRTRowsOfResolution", default: 480.0)
    /// TV lines (shadow mask density, range: 400.0–1200.0, default: 800.0)
    static let complexCRTTVL = Key<Float>("complexCRTTVL", default: 800.0)
    /// Horizontal warp amount (range: 0.0–0.05, default: ~0.0104)
    static let complexCRTWarpX = Key<Float>("complexCRTWarpX", default: 1.0 / 96.0)
    /// Vertical warp amount (range: 0.0–0.1, default: ~0.0278)
    static let complexCRTWarpY = Key<Float>("complexCRTWarpY", default: 1.0 / 36.0)
    /// Display gamma (range: 1.8–2.6)
    /// tvOS defaults to 2.4 per ITU-R BT.1886; iOS defaults to 2.2 (measured OLED response)
    #if os(tvOS)
    static let complexCRTDisplayGamma = Key<Float>("complexCRTDisplayGamma", default: 2.4)
    #else
    static let complexCRTDisplayGamma = Key<Float>("complexCRTDisplayGamma", default: 2.2)
    #endif
    /// Enable CRT scanlines
    static let complexCRTUseScanlines = Key<Bool>("complexCRTUseScanlines", default: true)
    /// Enable phosphor shadow mask pattern
    static let complexCRTUseShadowMask = Key<Bool>("complexCRTUseShadowMask", default: true)
    /// Enable screen curvature warp
    static let complexCRTUseWarp = Key<Bool>("complexCRTUseWarp", default: true)
}
