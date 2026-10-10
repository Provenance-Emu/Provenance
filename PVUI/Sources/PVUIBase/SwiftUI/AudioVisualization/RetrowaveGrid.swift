//
//  RetrowaveGrid.swift
//  PVUIBase
//
//  Perspective grid behind the retrowave audio visualizer.
//

import SwiftUI

/// Retrowave grid with perspective effect
struct RetrowaveGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let horizonY = height * 0.6
                let centerX = width / 2

                // Horizontal grid lines
                for i in 0..<20 {
                    let y = horizonY + CGFloat(i) * CGFloat(i) * 2.0
                    if y < height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }

                // Vertical grid lines with perspective
                for i in 0..<20 {
                    let spacing = width / 20
                    let x = centerX + spacing * CGFloat(i)
                    if x < width {
                        path.move(to: CGPoint(x: x, y: horizonY))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }

                    let x2 = centerX - spacing * CGFloat(i)
                    if x2 > 0 {
                        path.move(to: CGPoint(x: x2, y: horizonY))
                        path.addLine(to: CGPoint(x: 0, y: height))
                    }
                }
            }
            .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.3), lineWidth: 1)
        }
    }
}
