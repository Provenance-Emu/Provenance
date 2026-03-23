//
//  RetroMenuView+ShaderParameters.swift
//  PVUI
//
//  Created for issue #3185 / #3242 - Metal filter shader parameters in pause menu
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
                    #if os(tvOS)
                    .font(.system(size: 22, weight: .medium))
                    #else
                    .font(.system(size: 14, weight: .medium))
                    #endif
                    .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(formattedValue)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .regular).monospacedDigit())
                    #else
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
                    #endif
                    .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
            }
            #if os(tvOS)
            HStack(spacing: 16) {
                Button(action: {
                    adjustValue(by: -tvStep)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(palette.defaultTintColor.swiftUIColor)
                }
                .retroFocusButtonStyle(
                    focusScale: 1.15,
                    cornerRadius: 22,
                    primaryColor: palette.defaultTintColor.swiftUIColor,
                    secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                    glowRadius: 8,
                    showBorder: false,
                    showGlow: true,
                    showScale: true
                )
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
                .allowsHitTesting(false)

                Button(action: {
                    adjustValue(by: tvStep)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(palette.defaultTintColor.swiftUIColor)
                }
                .retroFocusButtonStyle(
                    focusScale: 1.15,
                    cornerRadius: 22,
                    primaryColor: palette.defaultTintColor.swiftUIColor,
                    secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                    glowRadius: 8,
                    showBorder: false,
                    showGlow: true,
                    showScale: true
                )
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

// MARK: - Filter Preview (color bars)

/// A compact SMPTE color-bar strip used as a preview thumbnail for a shader filter.
/// It overlays a CSS-style visual hint matching the filter's most recognisable effect
/// (scanlines for CRT, grid for LCD, etc.) so users can distinguish filters at a glance.
struct FilterPreviewBarsView: View {
    let filter: MetalFilterSelectionOption
    let palette: UXThemePalette

    /// Cached noise line positions so VHS preview is stable during slider interaction.
    @State private var vhsNoiseLines: [(y: CGFloat, dy: CGFloat)] = {
        (0..<6).map { _ in
            (y: CGFloat.random(in: 0..<1), dy: CGFloat.random(in: -2...2))
        }
    }()

    /// NTSC 75% color bar palette
    private let barColors: [Color] = [
        Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 0.75, green: 0.75, blue: 0),
        Color(red: 0, green: 0.75, blue: 0.75),
        Color(red: 0, green: 0.75, blue: 0),
        Color(red: 0.75, green: 0, blue: 0.75),
        Color(red: 0.75, green: 0, blue: 0),
        Color(red: 0, green: 0, blue: 0.75)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base color bars
                HStack(spacing: 0) {
                    ForEach(barColors.indices, id: \.self) { index in
                        Rectangle().fill(barColors[index])
                    }
                }

                // Filter-specific overlay hint
                filterOverlay(size: geometry.size)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func filterOverlay(size _: CGSize) -> some View {
        switch filter {
        case .simpleCRT, .complexCRT, .megaTron, .ulTron:
            // Scanline overlay
            Canvas { context, canvasSize in
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    }
                    context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 1)
                    y += 3
                }
            }
            .allowsHitTesting(false)

        case .lcd:
            // Vertical LCD grid
            Canvas { context, canvasSize in
                var x: CGFloat = 0
                while x < canvasSize.width {
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: canvasSize.height))
                    }
                    context.stroke(path, with: .color(.black.opacity(0.2)), lineWidth: 1)
                    x += 3
                }
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    }
                    context.stroke(path, with: .color(.black.opacity(0.15)), lineWidth: 1)
                    y += 3
                }
            }
            .allowsHitTesting(false)

        case .gameBoy:
            // Green tint + dot matrix hint
            Color.green.opacity(0.25)
            Canvas { context, canvasSize in
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    }
                    context.stroke(path, with: .color(.black.opacity(0.25)), lineWidth: 1)
                    y += 4
                }
            }
            .allowsHitTesting(false)

        case .vhs:
            // Noise / wobble hint — use cached positions to avoid flicker during slider interaction
            Color.white.opacity(0.08)
            Canvas { context, canvasSize in
                for line in vhsNoiseLines {
                    let y = line.y * canvasSize.height
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: canvasSize.width, y: y + line.dy))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)

        case .none:
            EmptyView()
        }
    }
}

// MARK: - tvOS filter toggles

#if os(tvOS)
/// Replaces `Toggle` for shader flags on tvOS so focus uses `retroFocusButtonStyle` instead of the system card fill that obscures labels.
private struct RetroFilterToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let palette: UXThemePalette

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(isOn ? String(localized: "ON") : String(localized: "OFF"))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(isOn ? palette.defaultTintColor.swiftUIColor : Color.gray.opacity(0.55))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(palette.dark ? 0.78 : 0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(isOn ? 0.8 : 0.3), lineWidth: 2)
                    )
            )
        }
        .retroFocusButtonStyle(
            focusScale: 1.04,
            cornerRadius: 12,
            primaryColor: palette.defaultTintColor.swiftUIColor,
            secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
            glowRadius: 8,
            showBorder: false,
            showGlow: true,
            showScale: true
        )
    }
}
#endif

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
                #if os(tvOS)
                .font(.system(size: 20, weight: .bold))
                #else
                .font(.system(size: 14, weight: .bold))
                #endif
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            // Feature toggles
            #if os(tvOS)
            RetroFilterToggleRow(title: String(localized: "Scanlines"), isOn: $useScanlines, palette: palette)
            RetroFilterToggleRow(title: String(localized: "Shadow Mask"), isOn: $useShadowMask, palette: palette)
            RetroFilterToggleRow(title: String(localized: "Screen Warp"), isOn: $useWarp, palette: palette)
            #else
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
            #endif

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
                #if os(tvOS)
                .font(.system(size: 20, weight: .medium))
                #else
                .font(.system(size: 14, weight: .medium))
                #endif
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
            #if os(tvOS)
            .retroFocusButtonStyle(
                focusScale: 1.04,
                cornerRadius: 12,
                primaryColor: .red,
                secondaryColor: palette.defaultTintColor.swiftUIColor,
                glowRadius: 8,
                showBorder: false,
                showGlow: true,
                showScale: true
            )
            #endif
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - LCD Parameters View

struct LCDParametersView: View {
    let palette: UXThemePalette

    @Default(.lcdGridDensity) private var gridDensity
    @Default(.lcdGridBrightness) private var gridBrightness
    @Default(.lcdContrast) private var contrast
    @Default(.lcdSaturation) private var saturation
    @Default(.lcdGhosting) private var ghosting
    @Default(.lcdScanlineDepth) private var scanlineDepth
    @Default(.lcdBloomAmount) private var bloomAmount
    @Default(.lcdColorLow) private var colorLow
    @Default(.lcdColorHigh) private var colorHigh

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LCD PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Grid Density", value: $gridDensity, range: 0.25...2.0, palette: palette)
            ShaderParameterSlider(label: "Grid Brightness", value: $gridBrightness, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Contrast", value: $contrast, range: 1.0...2.0, palette: palette)
            ShaderParameterSlider(label: "Saturation", value: $saturation, range: 0.0...2.0, palette: palette)
            ShaderParameterSlider(label: "Ghosting", value: $ghosting, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Scanline Depth", value: $scanlineDepth, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Bloom", value: $bloomAmount, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Subpixel Low", value: $colorLow, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Subpixel High", value: $colorHigh, range: 0.5...1.0, palette: palette)

            Button(action: {
                Defaults.reset(
                    .lcdGridDensity, .lcdGridBrightness, .lcdContrast, .lcdSaturation,
                    .lcdGhosting, .lcdScanlineDepth, .lcdBloomAmount, .lcdColorLow, .lcdColorHigh
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

// MARK: - Mega Tron Parameters View

struct MegaTronParametersView: View {
    let palette: UXThemePalette

    @Default(.megaTronMask) private var mask
    @Default(.megaTronMaskIntensity) private var maskIntensity
    @Default(.megaTronScanlineThinness) private var scanlineThinness
    @Default(.megaTronScanBlur) private var scanBlur
    @Default(.megaTronCurvature) private var curvature
    @Default(.megaTronTrinitronCurve) private var trinitronCurve
    @Default(.megaTronCorner) private var corner
    @Default(.megaTronCRTGamma) private var crtGamma

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEGA TRON PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Shadow Mask Type (0–3)", value: $mask, range: 0.0...3.0, step: 1.0, palette: palette)
            ShaderParameterSlider(label: "Mask Intensity", value: $maskIntensity, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Scanline Thinness", value: $scanlineThinness, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Scan Blur", value: $scanBlur, range: -2.0...0.0, palette: palette)
            ShaderParameterSlider(label: "Curvature", value: $curvature, range: 0.0...0.3, palette: palette)
            ShaderParameterSlider(label: "Trinitron Curve", value: $trinitronCurve, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Corner Size", value: $corner, range: 0.0...0.05, palette: palette)
            ShaderParameterSlider(label: "CRT Gamma", value: $crtGamma, range: 1.8...2.6, palette: palette)

            Button(action: {
                Defaults.reset(
                    .megaTronMask, .megaTronMaskIntensity, .megaTronScanlineThinness, .megaTronScanBlur,
                    .megaTronCurvature, .megaTronTrinitronCurve, .megaTronCorner, .megaTronCRTGamma
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

// MARK: - ulTron Parameters View

struct UlTronParametersView: View {
    let palette: UXThemePalette

    @Default(.ulTronHardScan) private var hardScan
    @Default(.ulTronHardPix) private var hardPix
    @Default(.ulTronWarpX) private var warpX
    @Default(.ulTronWarpY) private var warpY
    @Default(.ulTronMaskDark) private var maskDark
    @Default(.ulTronMaskLight) private var maskLight
    @Default(.ulTronShadowMask) private var shadowMask
    @Default(.ulTronBrightBoost) private var brightBoost
    @Default(.ulTronHardBloomScan) private var hardBloomScan
    @Default(.ulTronHardBloomPix) private var hardBloomPix
    @Default(.ulTronBloomAmount) private var bloomAmount
    @Default(.ulTronShape) private var shape

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ULTRON PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Scanline Hardness", value: $hardScan, range: -8.0...0.0, palette: palette)
            ShaderParameterSlider(label: "Pixel Hardness", value: $hardPix, range: -3.0...0.0, palette: palette)
            ShaderParameterSlider(label: "Warp Horizontal", value: $warpX, range: 0.0...0.05, palette: palette)
            ShaderParameterSlider(label: "Warp Vertical", value: $warpY, range: 0.0...0.05, palette: palette)
            ShaderParameterSlider(label: "Mask Dark", value: $maskDark, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Mask Light", value: $maskLight, range: 0.0...2.0, palette: palette)
            ShaderParameterSlider(label: "Shadow Mask Type (0–4)", value: $shadowMask, range: 0.0...4.0, step: 1.0, palette: palette)
            ShaderParameterSlider(label: "Brightness Boost", value: $brightBoost, range: 0.5...1.5, palette: palette)
            ShaderParameterSlider(label: "Bloom Scan", value: $hardBloomScan, range: -4.0...0.0, palette: palette)
            ShaderParameterSlider(label: "Bloom Pixel", value: $hardBloomPix, range: -2.0...0.0, palette: palette)
            ShaderParameterSlider(label: "Bloom Amount", value: $bloomAmount, range: 0.0...0.3, palette: palette)
            ShaderParameterSlider(label: "Pixel Shape", value: $shape, range: 1.0...2.0, palette: palette)

            Button(action: {
                Defaults.reset(
                    .ulTronHardScan, .ulTronHardPix, .ulTronWarpX, .ulTronWarpY,
                    .ulTronMaskDark, .ulTronMaskLight, .ulTronShadowMask, .ulTronBrightBoost,
                    .ulTronHardBloomScan, .ulTronHardBloomPix, .ulTronBloomAmount, .ulTronShape
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

// MARK: - Game Boy Parameters View

struct GameBoyParametersView: View {
    let palette: UXThemePalette

    @Default(.gameBoyDotMatrix) private var dotMatrix
    @Default(.gameBoyContrast) private var contrast
    @Default(.gameBoyGhost) private var ghost
    @Default(.gameBoyScanlineDepth) private var scanlineDepth

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GAME BOY PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Dot Matrix", value: $dotMatrix, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Contrast", value: $contrast, range: 0.5...2.0, palette: palette)
            ShaderParameterSlider(label: "Ghosting", value: $ghost, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Scanline Depth", value: $scanlineDepth, range: 0.0...1.0, palette: palette)

            Button(action: {
                Defaults.reset(.gameBoyDotMatrix, .gameBoyContrast, .gameBoyGhost, .gameBoyScanlineDepth)
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

// MARK: - VHS Parameters View

struct VHSParametersView: View {
    let palette: UXThemePalette

    @Default(.vhsNoiseAmount) private var noiseAmount
    @Default(.vhsScanlineJitter) private var scanlineJitter
    @Default(.vhsColorBleed) private var colorBleed
    @Default(.vhsTrackingNoise) private var trackingNoise
    @Default(.vhsTapeWobble) private var tapeWobble
    @Default(.vhsGhosting) private var ghosting
    @Default(.vhsVignette) private var vignette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VHS PARAMETERS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                .padding(.bottom, 4)

            ShaderParameterSlider(label: "Noise Amount", value: $noiseAmount, range: 0.0...0.3, palette: palette)
            ShaderParameterSlider(label: "Scanline Jitter", value: $scanlineJitter, range: 0.0...0.02, palette: palette)
            ShaderParameterSlider(label: "Color Bleed", value: $colorBleed, range: 0.5...3.0, palette: palette)
            ShaderParameterSlider(label: "Tracking Noise", value: $trackingNoise, range: 0.0...0.5, palette: palette)
            ShaderParameterSlider(label: "Tape Wobble", value: $tapeWobble, range: 0.0...0.01, palette: palette)
            ShaderParameterSlider(label: "Ghosting", value: $ghosting, range: 0.0...1.0, palette: palette)
            ShaderParameterSlider(label: "Vignette", value: $vignette, range: 0.0...1.0, palette: palette)

            Button(action: {
                Defaults.reset(
                    .vhsNoiseAmount, .vhsScanlineJitter, .vhsColorBleed,
                    .vhsTrackingNoise, .vhsTapeWobble, .vhsGhosting, .vhsVignette
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
