//
//  GameItemThumbnail.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVMediaCache

struct GameItemThumbnail: SwiftUI.View {

    @ObservedObject private var themeManager = ThemeManager.shared

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    let radius: CGFloat = 3.0

    var body: some SwiftUI.View {
        Group {
            if let artwork = artwork {
                /// Use the natural aspect ratio of the artwork image
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                /// Fallback to text-based artwork with the specified aspect ratio
                ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5), lineWidth: 1))
        .background(GeometryReader { geometry in
            Color.clear.preference(
                key: ArtworkDynamicWidthPreferenceKey.self,
                value: geometry.size.width
            )
        })
        .cornerRadius(radius)
    }
}
