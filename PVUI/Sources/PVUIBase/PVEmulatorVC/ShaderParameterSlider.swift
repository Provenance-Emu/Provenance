//
//  ShaderParameterSlider.swift
//  PVUI
//
//  Created for issue #3185 / #3242 - Metal filter shader parameters
//

import SwiftUI
import PVSettings
import PVThemes
import Defaults

// MARK: - Shader Parameter Slider

/// A slider row for a shader parameter: label, value and slider.
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
                    .foregroundStyle(.primary)
                    #else
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                    #endif
                Spacer()
                Text(formattedValue)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .regular).monospacedDigit())
                    .foregroundStyle(.secondary)
                    #else
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
                    .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
                    #endif
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
