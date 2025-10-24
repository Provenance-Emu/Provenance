//
//  AnimatedColorsGridGradientView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//


import SwiftUI
import PVThemes

@available(iOS 18.0, *)
struct AnimatedColorsGridGradientView: View {
    
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }
    
    // Computed properties for colors
    var color1: Color {
        currentPalette.gameLibraryBackground.swiftUIColor
    }
    
    var color2: Color {
        currentPalette.defaultTintColor.swiftUIColor
    }
    
    // Computed property for cell size
    var cellSize: CGFloat {
        50 // Adjust this value to change the size of the grid cells
    }
    
    // Line width for the grid
    var lineWidth: CGFloat {
        2 // Adjust this value to change the thickness of the grid lines
    }
    
    /// Animation state properties
    @State private var horizontalOffset: CGFloat = 0
    @State private var brightness: Double = 1.0
    
    /// Speed configurations for animations
    let horizontalSpeed: Double = 2 /// Adjust for faster/slower horizontal movement
    let brightnessSpeed: Double = 0.25 /// Adjust for faster/slower brightness changes
    
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let columns = Int(ceil(geometry.size.width / cellSize)) + 1
                let rows = Int(ceil(geometry.size.height / cellSize))
                
                ZStack {
                    // Background
                    color1
                    
                    // Vertical lines
                    ForEach(0..<columns, id: \.self) { column in
                        Rectangle()
                            .fill(color2)
                            .frame(width: lineWidth, height: geometry.size.height)
                            .position(x: CGFloat(column) * cellSize + horizontalOffset,
                                      y: geometry.size.height / 2)
                    }
                    
                    // Horizontal lines
                    ForEach(0..<rows, id: \.self) { row in
                        Rectangle()
                            .fill(color2)
                            .frame(width: geometry.size.width, height: lineWidth)
                            .position(x: geometry.size.width / 2,
                                      y: CGFloat(row) * cellSize + cellSize / 2)
                    }
                }
                .brightness(brightness - 1)
                .blendMode(.colorBurn)
                .colorInvert()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10 / horizontalSpeed).repeatForever(autoreverses: false)) {
                horizontalOffset = -cellSize
            }
            withAnimation(.easeInOut(duration: 2 / brightnessSpeed).repeatForever(autoreverses: true)) {
                brightness = 0.5
            }
        }
    }
}

@available(iOS 18.0, *)
#Preview {
    AnimatedColorsGridGradientView()
}
