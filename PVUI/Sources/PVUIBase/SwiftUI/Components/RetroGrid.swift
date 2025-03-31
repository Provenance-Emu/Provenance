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
