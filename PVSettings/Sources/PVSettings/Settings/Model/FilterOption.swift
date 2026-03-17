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

    /// Whether this filter exposes user-adjustable shader parameters.
    /// `simpleCRT` and `complexCRT` are legacy names kept for source compatibility.
    public var hasCRTParameters: Bool { hasEditableParameters }

    /// Whether this filter exposes user-adjustable shader parameters.
    public var hasEditableParameters: Bool {
        switch self {
        case .none: return false
        default: return true
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

    // MARK: - LCD Filter Parameters
    /// Pixel grid density — controls how visible the LCD grid is (0.5–2.0, default: 0.8)
    static let lcdGridDensity = Key<Float>("lcdGridDensity", default: 0.8)
    /// Grid line brightness/darkness (0.0–1.0, default: 0.2)
    static let lcdGridBrightness = Key<Float>("lcdGridBrightness", default: 0.2)
    /// Contrast enhancement (1.0–2.0, default: 1.1)
    static let lcdContrast = Key<Float>("lcdContrast", default: 1.1)
    /// Color saturation (0.0–2.0, default: 1.0)
    static let lcdSaturation = Key<Float>("lcdSaturation", default: 1.0)
    /// LCD ghosting / response-time blur (0.0–1.0, default: 0.05)
    static let lcdGhosting = Key<Float>("lcdGhosting", default: 0.05)
    /// Scanline depth / inter-row darkness (0.0–1.0, default: 0.15)
    static let lcdScanlineDepth = Key<Float>("lcdScanlineDepth", default: 0.15)
    /// Bloom / glow bleed (0.0–1.0, default: 0.2)
    static let lcdBloomAmount = Key<Float>("lcdBloomAmount", default: 0.2)
    /// Subpixel low-channel multiplier (0.0–1.0, default: 0.6)
    static let lcdColorLow = Key<Float>("lcdColorLow", default: 0.6)
    /// Subpixel high-channel multiplier (0.0–1.0, default: 0.95)
    static let lcdColorHigh = Key<Float>("lcdColorHigh", default: 0.95)

    // MARK: - Mega Tron Parameters
    /// Shadow mask type — 0=none, 1=RGB, 2=RGB(2), 3=RGB(3) (default: 1)
    static let megaTronMask = Key<Float>("megaTronMask", default: 1.0)
    /// Shadow mask intensity (0.0–1.0, default: 0.2)
    static let megaTronMaskIntensity = Key<Float>("megaTronMaskIntensity", default: 0.2)
    /// Scanline thinness (0.0–1.0, default: 0.3)
    static let megaTronScanlineThinness = Key<Float>("megaTronScanlineThinness", default: 0.3)
    /// Scanline blur amount (-2.0–0.0, default: -0.5)
    static let megaTronScanBlur = Key<Float>("megaTronScanBlur", default: -0.5)
    /// Screen curvature (0.0–0.3, default: 0.06)
    static let megaTronCurvature = Key<Float>("megaTronCurvature", default: 0.06)
    /// Trinitron-style curve (0.0–1.0, default: 0.1)
    static let megaTronTrinitronCurve = Key<Float>("megaTronTrinitronCurve", default: 0.1)
    /// Corner rounding size (0.0–0.05, default: 0.01)
    static let megaTronCorner = Key<Float>("megaTronCorner", default: 0.01)
    /// CRT gamma (1.8–2.6, default: 2.2)
    static let megaTronCRTGamma = Key<Float>("megaTronCRTGamma", default: 2.2)

    // MARK: - ulTron Parameters
    /// Scanline hardness (-8.0–0.0, default: -3.0)
    static let ulTronHardScan = Key<Float>("ulTronHardScan", default: -3.0)
    /// Pixel hardness (-3.0–0.0, default: -1.5)
    static let ulTronHardPix = Key<Float>("ulTronHardPix", default: -1.5)
    /// Horizontal warp (0.0–0.05, default: 0.006)
    static let ulTronWarpX = Key<Float>("ulTronWarpX", default: 0.006)
    /// Vertical warp (0.0–0.05, default: 0.01)
    static let ulTronWarpY = Key<Float>("ulTronWarpY", default: 0.01)
    /// Shadow mask dark value (0.0–1.0, default: 0.65)
    static let ulTronMaskDark = Key<Float>("ulTronMaskDark", default: 0.65)
    /// Shadow mask light value (0.0–2.0, default: 1.1)
    static let ulTronMaskLight = Key<Float>("ulTronMaskLight", default: 1.1)
    /// Shadow mask type (0.0–4.0, default: 2.0)
    static let ulTronShadowMask = Key<Float>("ulTronShadowMask", default: 2.0)
    /// Brightness boost (0.5–1.5, default: 0.95)
    static let ulTronBrightBoost = Key<Float>("ulTronBrightBoost", default: 0.95)
    /// Bloom scanline hardness (-4.0–0.0, default: -0.8)
    static let ulTronHardBloomScan = Key<Float>("ulTronHardBloomScan", default: -0.8)
    /// Bloom pixel hardness (-2.0–0.0, default: -0.7)
    static let ulTronHardBloomPix = Key<Float>("ulTronHardBloomPix", default: -0.7)
    /// Bloom bleed amount (0.0–0.3, default: 0.08)
    static let ulTronBloomAmount = Key<Float>("ulTronBloomAmount", default: 0.08)
    /// Pixel shape (1.0–2.0, default: 1.5)
    static let ulTronShape = Key<Float>("ulTronShape", default: 1.5)

    // MARK: - Game Boy Parameters
    /// Dot matrix intensity (0.0–1.0, default: 0.7)
    static let gameBoyDotMatrix = Key<Float>("gameBoyDotMatrix", default: 0.7)
    /// Screen contrast (0.5–2.0, default: 1.2)
    static let gameBoyContrast = Key<Float>("gameBoyContrast", default: 1.2)
    /// Horizontal ghosting (0.0–1.0, default: 0.35)
    static let gameBoyGhost = Key<Float>("gameBoyGhost", default: 0.35)
    /// Scanline depth (0.0–1.0, default: 0.2)
    static let gameBoyScanlineDepth = Key<Float>("gameBoyScanlineDepth", default: 0.2)

    // MARK: - VHS Parameters
    /// Static noise intensity (0.0–0.3, default: 0.05)
    static let vhsNoiseAmount = Key<Float>("vhsNoiseAmount", default: 0.05)
    /// Horizontal scanline jitter (0.0–0.02, default: 0.002)
    static let vhsScanlineJitter = Key<Float>("vhsScanlineJitter", default: 0.002)
    /// Vertical color bleed (0.5–3.0, default: 1.2)
    static let vhsColorBleed = Key<Float>("vhsColorBleed", default: 1.2)
    /// Tracking noise bands (0.0–0.5, default: 0.15)
    static let vhsTrackingNoise = Key<Float>("vhsTrackingNoise", default: 0.15)
    /// Tape wobble / horizontal waver (0.0–0.01, default: 0.003)
    static let vhsTapeWobble = Key<Float>("vhsTapeWobble", default: 0.003)
    /// Double-image ghosting (0.0–1.0, default: 0.3)
    static let vhsGhosting = Key<Float>("vhsGhosting", default: 0.3)
    /// Edge vignette (0.0–1.0, default: 0.4)
    static let vhsVignette = Key<Float>("vhsVignette", default: 0.4)
}
