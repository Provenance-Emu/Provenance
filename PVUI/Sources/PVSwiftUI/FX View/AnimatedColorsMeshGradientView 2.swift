//
//  AnimatedColorsMeshGradientView2.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//

import SwiftUI
import PVThemes

@available(iOS 18.0, tvOS 18.0, *)
struct AnimatedColorsMeshGradientView2: View {
    
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    private let colors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 1.00, green: 0.55, blue: 0.00),
        Color(red: 1.00, green: 0.27, blue: 0.00),
        
        Color(red: 1.00, green: 0.41, blue: 0.71),
        Color(red: 0.85, green: 0.44, blue: 0.84),
        Color(red: 0.54, green: 0.17, blue: 0.89),
        
        Color(red: 0.29, green: 0.00, blue: 0.51),
        Color(red: 0.00, green: 0.00, blue: 0.55),
        Color(red: 0.10, green: 0.10, blue: 0.44)
    ]
    
    private let cgaInspiredColors: [Color] = [
//        // Black to Dark Gray
//        Color(red: 0.00, green: 0.00, blue: 0.00),
//        Color(red: 0.33, green: 0.33, blue: 0.33),
//        Color(red: 0.66, green: 0.66, blue: 0.66),
        
        // Blue to Cyan
        Color(red: 0.00, green: 0.00, blue: 0.67),
        Color(red: 0.00, green: 0.33, blue: 0.83),
        Color(red: 0.00, green: 0.67, blue: 1.00),

        // Magenta to Light Magenta
        Color(red: 0.67, green: 0.67, blue: 0.67),
        Color(red: 0.83, green: 0.33, blue: 0.83),
        Color(red: 1.00, green: 0.67, blue: 1.00),

        // Green to Light Green
        Color(red: 0.00, green: 0.67, blue: 0.00),
        Color(red: 0.33, green: 0.83, blue: 0.33),
        Color(red: 0.67, green: 1.00, blue: 0.67),
        
        // Red to Light Red
        Color(red: 0.67, green: 0.00, blue: 0.00),
        Color(red: 0.83, green: 0.33, blue: 0.33),
        Color(red: 1.00, green: 0.67, blue: 0.67),
        
//        // Brown to Yellow
        Color(red: 0.83, green: 0.67, blue: 0.00),
        Color(red: 1.00, green: 1.00, blue: 0.00),
        Color(red: 0.00, green: 0.00, blue: 0.67)

    ]
    
    private let points3x3: [SIMD2<Float>] = [
        SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
        SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5),
        SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
    ]
    
    private let points5x5: [SIMD2<Float>] = [
        // Row 1
        SIMD2<Float>(0.00, 0.00), SIMD2<Float>(0.25, 0.00), SIMD2<Float>(0.50, 0.00), SIMD2<Float>(0.75, 0.00), SIMD2<Float>(1.00, 0.00),
        // Row 2
        SIMD2<Float>(0.00, 0.25), SIMD2<Float>(0.25, 0.25), SIMD2<Float>(0.50, 0.25), SIMD2<Float>(0.75, 0.25), SIMD2<Float>(1.00, 0.25),
        // Row 3
        SIMD2<Float>(0.00, 0.50), SIMD2<Float>(0.25, 0.50), SIMD2<Float>(0.50, 0.50), SIMD2<Float>(0.75, 0.50), SIMD2<Float>(1.00, 0.50),
        // Row 4
        SIMD2<Float>(0.00, 0.75), SIMD2<Float>(0.25, 0.75), SIMD2<Float>(0.50, 0.75), SIMD2<Float>(0.75, 0.75), SIMD2<Float>(1.00, 0.75),
        // Row 5
        SIMD2<Float>(0.00, 1.00), SIMD2<Float>(0.25, 1.00), SIMD2<Float>(0.50, 1.00), SIMD2<Float>(0.75, 1.00), SIMD2<Float>(1.00, 1.00)
    ]
}

@available(iOS 18.0, tvOS 18.0, *)
extension AnimatedColorsMeshGradientView2 {
    var body: some View {
        TimelineView(.animation) { timeline in
            MeshGradient(
                width: 3,
                height: 3,
                locations: .points(points3x3),
                colors: .colors(animatedColors(for: timeline.date)),
                background: .Provenance.blue,
                smoothsColors: true
            )
        }
        .ignoresSafeArea()
    }
}

@available(iOS 18.0, tvOS 18.0, *)
extension AnimatedColorsMeshGradientView2 {
    private func animatedColors(for date: Date) -> [Color] {
        let phase = CGFloat(date.timeIntervalSince1970)
        
        return cgaInspiredColors.enumerated().map { index, color in
            let hueShift = cos(phase + Double(index) * 0.9) * 0.05
            return shiftHue(of: color, by: hueShift)
        }
    }
    
    private func shiftHue(of color: Color, by amount: Double) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        hue += CGFloat(amount)
        hue = hue.truncatingRemainder(dividingBy: 1.0)
        
        if hue < 0 {
            hue += 1
        }
        
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness),
            opacity: Double(alpha))
    }
}

@available(iOS 18.0, tvOS 18.0, *)
#Preview {
    AnimatedColorsMeshGradientView2()
}
