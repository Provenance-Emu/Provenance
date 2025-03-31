//
//  RetroPalettePreview.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import PVThemes
import SwiftUI

// Retrowave version of the palette preview
public struct RetroPalettePreview: View {
    public let palette: any UXThemePalette
    @State private var glowOpacity: Double = 0.7
    
    public init(palette: any UXThemePalette) {
        self.palette = palette
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text("COLOR PALETTE")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.retroPink)
                .shadow(color: .retroBlue.opacity(0.8), radius: 2, x: 1, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RetroColorSwatch(color: palette.defaultTintColor.swiftUIColor, name: "TINT")
                RetroColorSwatch(color: palette.gameLibraryBackground.swiftUIColor, name: "BG")
                RetroColorSwatch(color: palette.gameLibraryText.swiftUIColor, name: "TEXT")
                RetroColorSwatch(color: palette.gameLibraryHeaderText.swiftUIColor, name: "HEADER")
                RetroColorSwatch(color: palette.gameLibraryHeaderBackground.swiftUIColor, name: "HDR BG")
                RetroColorSwatch(color: palette.gameLibraryCellBackground?.swiftUIColor ?? .retroBlack, name: "CELL")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroBlack.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .retroBlue.opacity(glowOpacity * 0.3), radius: 8, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}
