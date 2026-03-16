//
//  RetroMenuView+ShaderParameters.swift
//  PVUI
//
//  Created for issue #3185 - Metal filter shader parameters in pause menu
//

import SwiftUI
import PVSettings
import PVThemes
import Defaults

// MARK: - Shader Parameter Slider

/// A slider row styled for the RetroMenuView filter picker, showing a label, value, and slider.
struct ShaderParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float? = nil
    let palette: UXThemePalette

    private var tvStep: Float {
        if let step = step {
            return step
        }

        let span = range.upperBound - range.lowerBound
        switch span {
        case ..<1.0:
            return 0.01
        case ..<10.0:
            return 0.1
        case ..<100.0:
            return 1.0
        default:
            return 10.0
        }
    }

    private var canDecrease: Bool {
        value > range.lowerBound
    }

    private var canIncrease: Bool {
        value < range.upperBound
    }

    private func adjustValue(by delta: Float) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }

    private var formattedValue: String {
        if let step = step, step >= 1.0 {
            return String(format: "%.0f", value)
        } else if range.upperBound - range.lowerBound >= 10 {
            return String(format: "%.0f", value)
        } else if range.upperBound - range.lowerBound >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(formattedValue)
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
                    .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
            }
            #if os(tvOS)
            HStack(spacing: 16) {
                Button(action: {
                    adjustValue(by: -tvStep)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(palette.defaultTintColor.swiftUIColor)
                .disabled(!canDecrease)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.45))
                        Capsule()
                            .fill(palette.defaultTintColor.swiftUIColor)
                            .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / max(range.upperBound - range.lowerBound, 0.0001)))
                    }
                }
                .frame(height: 10)

                Button(action: {
                    adjustValue(by: tvStep)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(palette.defaultTintColor.swiftUIColor)
                .disabled(!canIncrease)
            }
            #else
            RetroWaveSlider(value: $value, in: range, step: Float.Stride(step ?? 0))
            #endif
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Simple CRT Parameters View

/// Displays adjustable parameters for the Simple CRT shader.
struct SimpleCRTParametersView: View {
    let palette: UXThemePalette

    @Default(.simpleCRTCurvVert) private var curvVert
    @Default(.simpleCRTCurvHoriz) private var curvHoriz
    @Default(.simpleCRTCurvStrength) private var curvStrength
    @Default(.simpleCRTLightBoost) private var lightBoost
    @Default(.simpleCRTVignStrength) private var vignStrength
    @Default(.simpleCRTZoomOut) private var zoomOut
    @Default(.simpleCRTBrightness) private var brightness

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SIMPLE CRT PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Curvature (Vertical)", value: $curvVert, range: 1.0...10.0, palette: palette)
            ShaderParameterSlider(label: "Curvature (Horizontal)", value: $curvHoriz, range: 1.0...10.0, palette: palette)
            ShaderParameterSlider(label: "Curvature Strength", value: $curvStrength, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Light Boost", value: $lightBoost, range: 0.1...3.0, palette: palette)
            ShaderParameterSlider(label: "Vignette", value: $vignStrength, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Zoom Out", value: $zoomOut, range: 0.5...2.0, palette: palette)
            ShaderParameterSlider(label: "Brightness", value: $brightness, range: 0.5...1.5, palette: palette)

            Button(action: {
                Defaults.reset(
                    .simpleCRTCurvVert, .simpleCRTCurvHoriz, .simpleCRTCurvStrength,
                    .simpleCRTLightBoost, .simpleCRTVignStrength, .simpleCRTZoomOut,
                    .simpleCRTBrightness
                )
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Complex CRT Parameters View

/// Displays adjustable parameters for the Complex CRT shader.
struct ComplexCRTParametersView: View {
    let palette: UXThemePalette

    @Default(.complexCRTUseScanlines) private var useScanlines
    @Default(.complexCRTUseShadowMask) private var useShadowMask
    @Default(.complexCRTUseWarp) private var useWarp
    @Default(.complexCRTBloomAmount) private var bloomAmount
    @Default(.complexCRTScanlineHardness) private var scanlineHardness
    @Default(.complexCRTShadowMaskHardness) private var shadowMaskHardness
    @Default(.complexCRTRowsOfResolution) private var rowsOfResolution
    @Default(.complexCRTTVL) private var tvl
    @Default(.complexCRTWarpX) private var warpX
    @Default(.complexCRTWarpY) private var warpY
    @Default(.complexCRTDisplayGamma) private var displayGamma

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLEX CRT PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            // Feature toggles
            Toggle("Scanlines", isOn: $useScanlines)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                .tint(palette.defaultTintColor.swiftUIColor)

            Toggle("Shadow Mask", isOn: $useShadowMask)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                .tint(palette.defaultTintColor.swiftUIColor)

            Toggle("Screen Warp", isOn: $useWarp)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                .tint(palette.defaultTintColor.swiftUIColor)

            ShaderParameterSlider(label: "Bloom Amount", value: $bloomAmount, range: 0.0...6.0, palette: palette)

            if useScanlines {
                ShaderParameterSlider(label: "Scanline Hardness", value: $scanlineHardness, range: 1.0...12.0, palette: palette)
                ShaderParameterSlider(label: "CRT Resolution (lines)", value: $rowsOfResolution, range: 240.0...1080.0, step: 1.0, palette: palette)
            }

            if useShadowMask {
                ShaderParameterSlider(label: "Shadow Mask Hardness", value: $shadowMaskHardness, range: 4.0...32.0, palette: palette)
                ShaderParameterSlider(label: "TV Lines (mask density)", value: $tvl, range: 400.0...1200.0, step: 1.0, palette: palette)
            }

            if useWarp {
                ShaderParameterSlider(label: "Warp Horizontal", value: $warpX, range: 0.0...0.05, palette: palette)
                ShaderParameterSlider(label: "Warp Vertical", value: $warpY, range: 0.0...0.1, palette: palette)
            }

            ShaderParameterSlider(label: "Display Gamma", value: $displayGamma, range: 1.8...2.6, palette: palette)

            Button(action: {
                Defaults.reset(
                    .complexCRTUseScanlines, .complexCRTUseShadowMask, .complexCRTUseWarp,
                    .complexCRTBloomAmount, .complexCRTScanlineHardness, .complexCRTShadowMaskHardness,
                    .complexCRTRowsOfResolution, .complexCRTTVL,
                    .complexCRTWarpX, .complexCRTWarpY, .complexCRTDisplayGamma
                )
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 4)
    }
}
