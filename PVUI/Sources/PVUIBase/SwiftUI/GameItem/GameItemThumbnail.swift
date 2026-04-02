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

    /// The aspect ratio for the artwork image. Uses the image's natural ratio when
    /// artwork is loaded, and falls back to the system-defined ratio for placeholders.
    /// This shows cover art in its true proportions while keeping placeholders predictable.
    private var artworkAspectRatio: CGFloat {
        if let artwork = artwork {
            let w = artwork.size.width
            let h = artwork.size.height
            if w > 0 && h > 0 {
                return w / h
            }
        }
        return boxartAspectRatio.rawValue
    }

    var body: some SwiftUI.View {
        Group {
            if let artwork = artwork {
                /// Use the artwork's natural aspect ratio so cover art displays
                /// in its true proportions. The system ratio is only used for placeholders.
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(artworkAspectRatio, contentMode: .fit)
                    .blur(radius: obfuscateArtwork ? obfuscationBlurRadius : 0)
            } else {
                /// Fallback to text-based artwork with the system-defined aspect ratio
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
