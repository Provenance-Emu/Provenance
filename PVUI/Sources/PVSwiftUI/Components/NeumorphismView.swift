//
//  NeumorphismView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//


import SwiftUI

struct NeumorphismView<Content: View>: View {
    let content: () -> Content
    let baseColor: Color

    /// Initialize with content and optional base color
    init(baseColor: Color = Color(red: 0.16290172934532166, green: 0.16290172934532166, blue: 0.16290172934532166),
         @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.baseColor = baseColor
    }

    var body: some View {
        content()
            .modifier(NeumorphismModifier(baseColor: baseColor))
    }
}

struct NeumorphismModifier: ViewModifier {
    let baseColor: Color

    /// Calculate shadow colors based on base color
    private var lightShadowColor: Color {
        baseColor.adjustBrightness(by: -0.48) /// Darken by 48%
    }

    private var darkShadowColor: Color {
        baseColor.adjustBrightness(by: 0.48) /// Lighten by 48%
    }

    private var foregroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [baseColor, baseColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundGradient)
            .shadow(color: lightShadowColor, radius: 2.99, x: 2.74, y: 2.74)
            .shadow(color: darkShadowColor, radius: 2.99, x: -2.74, y: -2.74)
    }
}

/// Helper extension to adjust color brightness
extension Color {
    /// Adjusts the brightness of a color by a given percentage
    /// - Parameter percentage: Amount to adjust (-1.0 to 1.0, where negative darkens and positive lightens)
    /// - Returns: Adjusted color
    func adjustBrightness(by percentage: Double) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        /// Adjust brightness while keeping it within 0...1
        let newBrightness = max(0, min(1, brightness * (1 + percentage)))

        return Color(hue: Double(hue),
                    saturation: Double(saturation),
                    brightness: Double(newBrightness),
                    opacity: Double(alpha))
    }
}
