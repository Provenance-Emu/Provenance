//
//  RetroAlertGridPattern.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/29/25.
//

import SwiftUI
import PVThemes

/// A grid pattern view for retrowave aesthetic
public struct RetroAlertGridPattern: View {
    public init() {}
    public var body: some View {
        Canvas { context, size in
            // Horizontal lines
            let hSpacing: CGFloat = 20
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.retroBlue.opacity(0.3)), lineWidth: 1)
                y += hSpacing
            }

            // Vertical lines
            let vSpacing: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.retroBlue.opacity(0.3)), lineWidth: 1)
                x += vSpacing
            }
        }
    }
}
