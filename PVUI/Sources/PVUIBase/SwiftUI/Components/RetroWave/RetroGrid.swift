//
//  RetroGrid.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI

// Retro grid component
public struct RetroGrid: View {
    public let lineSpacing: CGFloat
    public let lineColor: Color
    public let lines: Int
    public let lineWidth: CGFloat
    
    public init(lineSpacing: CGFloat = 15, lineColor: Color = .white.opacity(0.07), lines: Int = 20, lineWidth: CGFloat = 1) {
        self.lineSpacing = lineSpacing
        self.lineColor = lineColor
        self.lines = lines
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        ZStack {
            // Horizontal lines
            VStack(spacing: lineSpacing) {
                ForEach(0..<lines) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(height: lineWidth)
                }
            }
            
            // Vertical lines
            HStack(spacing: lineSpacing) {
                ForEach(0..<lines) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: lineWidth)
                }
            }
        }
    }
}

// RetroGrid creates a grid background for retrowave aesthetic
public struct RetroGridForSettings: View {
    
    public let lines: Int
    public let lineWidth: CGFloat

    public init(lines: Int = 20, lineWidth: CGFloat = 1) {
        self.lines = lines
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color(red: 0.1, green: 0.0, blue: 0.2),
                        Color(red: 0.2, green: 0.0, blue: 0.3)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                // Horizontal grid lines
                VStack(spacing: CGFloat(lines)) {
                    ForEach(0..<Int(geometry.size.height / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.clear, .retroPink.opacity(0.3), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: lineWidth)
                    }
                }
                
                // Vertical grid lines
                HStack(spacing: CGFloat(lines)) {
                    ForEach(0..<Int(geometry.size.width / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.clear, .retroPink.opacity(0.2), .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: lineWidth)
                    }
                }
            }
        }
    }
}
