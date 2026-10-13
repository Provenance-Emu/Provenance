//
//  NativeShaderParameters.swift
//  PVShaders
//
//  Parameter descriptors for the hand-written Provenance filters. Values live in
//  the existing `Defaults` keys (FilterOption.swift), which the renderer reads,
//  so the descriptor `name` is the key name.
//

import Foundation
import Defaults
import PVSettings

enum NativeShaderParameters {
    static func descriptors(for option: MetalFilterSelectionOption) -> [ShaderParameterDescriptor] {
        func slider(_ key: Defaults.Key<Float>, _ label: String, _ range: ClosedRange<Float>,
                    step: Float = 0) -> ShaderParameterDescriptor {
            ShaderParameterDescriptor(name: key.name, label: label, initial: key.defaultValue,
                                      minimum: range.lowerBound, maximum: range.upperBound, step: step)
        }
        func toggle(_ key: Defaults.Key<Bool>, _ label: String) -> ShaderParameterDescriptor {
            ShaderParameterDescriptor(name: key.name, label: label, initial: key.defaultValue ? 1 : 0,
                                      minimum: 0, maximum: 1, step: 1, isToggle: true)
        }
        switch option {
        case .none:
            return []
        case .simpleCRT:
            return [
                slider(.simpleCRTCurvVert, "Curvature (Vertical)", 1...10),
                slider(.simpleCRTCurvHoriz, "Curvature (Horizontal)", 1...10),
                slider(.simpleCRTCurvStrength, "Curvature Strength", 0...1),
                slider(.simpleCRTLightBoost, "Light Boost", 0.1...3),
                slider(.simpleCRTVignStrength, "Vignette", 0...1),
                slider(.simpleCRTZoomOut, "Zoom Out", 0.5...2),
                slider(.simpleCRTBrightness, "Brightness", 0.5...1.5)
            ]
        case .complexCRT:
            return [
                toggle(.complexCRTUseScanlines, "Scanlines"),
                toggle(.complexCRTUseShadowMask, "Shadow Mask"),
                toggle(.complexCRTUseWarp, "Screen Warp"),
                slider(.complexCRTBloomAmount, "Bloom Amount", 0...6),
                slider(.complexCRTScanlineHardness, "Scanline Hardness", 1...12),
                slider(.complexCRTRowsOfResolution, "CRT Resolution (lines)", 240...1080, step: 1),
                slider(.complexCRTShadowMaskHardness, "Shadow Mask Hardness", 4...32),
                slider(.complexCRTTVL, "TV Lines (mask density)", 400...1200, step: 1),
                slider(.complexCRTWarpX, "Warp Horizontal", 0...0.05),
                slider(.complexCRTWarpY, "Warp Vertical", 0...0.1),
                slider(.complexCRTDisplayGamma, "Display Gamma", 1.8...2.6)
            ]
        case .lcd:
            return [
                slider(.lcdGridDensity, "Grid Density", 0.25...2),
                slider(.lcdGridBrightness, "Grid Brightness", 0...1),
                slider(.lcdContrast, "Contrast", 1...2),
                slider(.lcdSaturation, "Saturation", 0...2),
                slider(.lcdGhosting, "Ghosting", 0...1),
                slider(.lcdScanlineDepth, "Scanline Depth", 0...1),
                slider(.lcdBloomAmount, "Bloom", 0...1),
                slider(.lcdColorLow, "Subpixel Low", 0...1),
                slider(.lcdColorHigh, "Subpixel High", 0.5...1)
            ]
        case .megaTron:
            return [
                slider(.megaTronMask, "Shadow Mask Type", 0...3, step: 1),
                slider(.megaTronMaskIntensity, "Mask Intensity", 0...1),
                slider(.megaTronScanlineThinness, "Scanline Thinness", 0...1),
                slider(.megaTronScanBlur, "Scan Blur", -2...0),
                slider(.megaTronCurvature, "Curvature", 0...0.3),
                slider(.megaTronTrinitronCurve, "Trinitron Curve", 0...1),
                slider(.megaTronCorner, "Corner Size", 0...0.05),
                slider(.megaTronCRTGamma, "CRT Gamma", 1.8...2.6)
            ]
        case .ulTron:
            return [
                slider(.ulTronHardScan, "Scanline Hardness", -8...0),
                slider(.ulTronHardPix, "Pixel Hardness", -3...0),
                slider(.ulTronWarpX, "Warp Horizontal", 0...0.05),
                slider(.ulTronWarpY, "Warp Vertical", 0...0.05),
                slider(.ulTronMaskDark, "Mask Dark", 0...1),
                slider(.ulTronMaskLight, "Mask Light", 0...2),
                slider(.ulTronShadowMask, "Shadow Mask Type", 0...4, step: 1),
                slider(.ulTronBrightBoost, "Brightness Boost", 0.5...1.5),
                slider(.ulTronHardBloomScan, "Bloom Scan", -4...0),
                slider(.ulTronHardBloomPix, "Bloom Pixel", -2...0),
                slider(.ulTronBloomAmount, "Bloom Amount", 0...0.3),
                slider(.ulTronShape, "Pixel Shape", 1...2)
            ]
        case .gameBoy:
            return [
                slider(.gameBoyDotMatrix, "Dot Matrix", 0...1),
                slider(.gameBoyContrast, "Contrast", 0.5...2),
                slider(.gameBoyGhost, "Ghosting", 0...1),
                slider(.gameBoyScanlineDepth, "Scanline Depth", 0...1)
            ]
        case .vhs:
            return [
                slider(.vhsNoiseAmount, "Noise Amount", 0...0.3),
                slider(.vhsScanlineJitter, "Scanline Jitter", 0...0.02),
                slider(.vhsColorBleed, "Color Bleed", 0.5...3),
                slider(.vhsTrackingNoise, "Tracking Noise", 0...0.5),
                slider(.vhsTapeWobble, "Tape Wobble", 0...0.01),
                slider(.vhsGhosting, "Ghosting", 0...1),
                slider(.vhsVignette, "Vignette", 0...1)
            ]
        }
    }

    /// Reads a native parameter from its `Defaults` key.
    static func value(of descriptor: ShaderParameterDescriptor) -> Float {
        if descriptor.isToggle {
            return Defaults[Defaults.Key<Bool>(descriptor.name, default: descriptor.initial != 0)] ? 1 : 0
        }
        return Defaults[Defaults.Key<Float>(descriptor.name, default: descriptor.initial)]
    }

    /// Writes a native parameter to its `Defaults` key; `nil` resets it to the default.
    static func set(_ value: Float?, for descriptor: ShaderParameterDescriptor) {
        if descriptor.isToggle {
            let key = Defaults.Key<Bool>(descriptor.name, default: descriptor.initial != 0)
            if let value { Defaults[key] = value != 0 } else { Defaults.reset(key) }
        } else {
            let key = Defaults.Key<Float>(descriptor.name, default: descriptor.initial)
            if let value { Defaults[key] = descriptor.clamp(value) } else { Defaults.reset(key) }
        }
    }
}
