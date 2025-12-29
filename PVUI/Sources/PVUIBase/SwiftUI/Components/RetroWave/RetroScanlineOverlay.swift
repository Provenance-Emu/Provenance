//
//  RetroScanlineOverlay.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/29/25.
//

import SwiftUI
import PVThemes

/// Scanline overlay effect
public struct RetroScanlineOverlay: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 2
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.black), lineWidth: 1)
                y += lineSpacing
            }
        }
    }
}
