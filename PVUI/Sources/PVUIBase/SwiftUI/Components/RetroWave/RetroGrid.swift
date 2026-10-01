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
    
    /// Fixed cell pitch used to decide how many lines fit; the on-screen spacing between lines is `lines`.
    private static let lineCountDivisor: CGFloat = 20

    private static let horizontalLineGradient = Gradient(colors: [.clear, .retroPink.opacity(0.3), .clear])
    private static let verticalLineGradient = Gradient(colors: [.clear, .retroPink.opacity(0.2), .clear])

    /// Drawn with a single `Canvas` (one layer) instead of ~100 gradient `Rectangle` views, since this
    /// is the always-on Settings background.
    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.2, green: 0.0, blue: 0.3)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )

            Canvas { context, size in
                let spacing = CGFloat(lines)

                // Lines are laid out like a centered stack, so the overflow is split evenly on both edges.
                let rowCount = Int(size.height / Self.lineCountDivisor) + 1
                let rowsTotal = CGFloat(rowCount) * lineWidth + CGFloat(rowCount - 1) * spacing
                var y = (size.height - rowsTotal) / 2
                for _ in 0..<rowCount {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineWidth)
                    context.fill(
                        Path(rect),
                        with: .linearGradient(
                            Self.horizontalLineGradient,
                            startPoint: CGPoint(x: 0, y: y),
                            endPoint: CGPoint(x: size.width, y: y)
                        )
                    )
                    y += lineWidth + spacing
                }

                let columnCount = Int(size.width / Self.lineCountDivisor) + 1
                let columnsTotal = CGFloat(columnCount) * lineWidth + CGFloat(columnCount - 1) * spacing
                var x = (size.width - columnsTotal) / 2
                for _ in 0..<columnCount {
                    let rect = CGRect(x: x, y: 0, width: lineWidth, height: size.height)
                    context.fill(
                        Path(rect),
                        with: .linearGradient(
                            Self.verticalLineGradient,
                            startPoint: CGPoint(x: x, y: 0),
                            endPoint: CGPoint(x: x, y: size.height)
                        )
                    )
                    x += lineWidth + spacing
                }
            }
        }
    }
}
