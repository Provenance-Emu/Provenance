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
    
    public init(lineSpacing: CGFloat = 15, lineColor: Color = .white.opacity(0.07)) {
        self.lineSpacing = lineSpacing
        self.lineColor = lineColor
    }
    
    public var body: some View {
        ZStack {
            // Horizontal lines
            VStack(spacing: lineSpacing) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(height: 1)
                }
            }
            
            // Vertical lines
            HStack(spacing: lineSpacing) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 1)
                }
            }
        }
    }
}

// RetroGrid creates a grid background for retrowave aesthetic
public struct RetroGridForSettings: View {
    
    public init() {}
    
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
                VStack(spacing: 20) {
                    ForEach(0..<Int(geometry.size.height / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.clear, .retroPink.opacity(0.3), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: 1)
                    }
                }
                
                // Vertical grid lines
                HStack(spacing: 20) {
                    ForEach(0..<Int(geometry.size.width / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.clear, .retroPink.opacity(0.2), .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: 1)
                    }
                }
            }
        }
    }
}
