//
//  GameItemThumbnail.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVMediaCache

@available(iOS 14, tvOS 14, *)
struct GameItemThumbnail: SwiftUI.View {
    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    let radius: CGFloat = 3.0
    var body: some SwiftUI.View {
        ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor.opacity(0.5), lineWidth: 1))
            .background(GeometryReader { geometry in
                Color.clear.preference(
                    key: ArtworkDynamicWidthPreferenceKey.self,
                    value: geometry.size.width
                )
            })
            .cornerRadius(radius)
    }
}
