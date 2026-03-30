//
//  GameItemThumbnail.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVMediaCache
import struct PVUIBase.ArtworkImageBaseView
import Defaults

struct GameItemThumbnail: SwiftUI.View {

    @ObservedObject private var themeManager = ThemeManager.shared
    /// When enabled, blur artwork for safe screenshots.
    @Default(.obfuscateArtwork) private var obfuscateArtwork
    /// Latest measured thumbnail width forwarded through preference.
    @State private var measuredWidth: CGFloat = 0

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    let radius: CGFloat = 3.0
    /// Blur radius for artwork obfuscation.
    private let obfuscationBlurRadius: CGFloat = 6

    /// The aspect ratio used for layout — consistent between placeholder and loaded artwork
    /// to prevent cell size jumps when artwork loads asynchronously.
    private var layoutAspectRatio: CGFloat {
        boxartAspectRatio.rawValue
    }

    var body: some SwiftUI.View {
        Group {
            if let artwork = artwork {
                /// Use the boxart aspect ratio for layout consistency, not the image's
                /// natural ratio. This prevents scroll jumps when artwork loads.
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(layoutAspectRatio, contentMode: .fit)
                    .blur(radius: obfuscateArtwork ? obfuscationBlurRadius : 0)
            } else {
                /// Fallback to text-based artwork with the specified aspect ratio
                ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5), lineWidth: 1))
        .background(widthReader)
        .preference(key: ArtworkDynamicWidthPreferenceKey.self, value: measuredWidth)
        .cornerRadius(radius)
    }

    /// Uses `onGeometryChange` when available, with a GeometryReader fallback.
    @ViewBuilder
    private var widthReader: some View {
        if #available(iOS 18.0, tvOS 18.0, *) {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    measuredWidth = width
                }
        } else {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        measuredWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { width in
                        measuredWidth = width
                    }
            }
        }
    }
}
