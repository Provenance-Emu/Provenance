//
//  RetroColorSwatch.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import SwiftUI

// Retrowave color swatch
public struct RetroColorSwatch: View {
    public let color: Color
    public let name: String
    
    public var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
        }
    }
}
