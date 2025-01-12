//
//  ArtworkImageBaseView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes

struct ArtworkImageBaseView: SwiftUI.View {
    /// Observe theme changes to trigger re-renders
    @ObservedObject private var themeManager = ThemeManager.shared

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio

    init(artwork: SwiftImage?, gameTitle: String, boxartAspectRatio: PVGameBoxArtAspectRatio) {
        self.artwork = artwork
        self.gameTitle = gameTitle
        self.boxartAspectRatio = boxartAspectRatio
    }

    var body: some SwiftUI.View {
        if let artwork = artwork {
            SwiftUI.Image(uiImage: artwork)
                .resizable()
                .aspectRatio(artwork.size.width / artwork.size.height, contentMode: .fit)
        } else {
            /// Use id modifier with theme to force re-render when theme changes
            SwiftUI.Image(uiImage: UIImage.missingArtworkImage(gameTitle: gameTitle, ratio: boxartAspectRatio.rawValue))
                .resizable()
                .aspectRatio(boxartAspectRatio.rawValue, contentMode: .fit)
                .id(themeManager.currentPalette.name)
        }
    }
}
