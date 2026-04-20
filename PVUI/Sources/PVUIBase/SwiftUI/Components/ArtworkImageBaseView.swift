//
//  ArtworkImageBaseView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVMediaCache
import Defaults

public struct ArtworkImageBaseView: SwiftUI.View {
    /// Observe theme changes to trigger re-renders
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.missingArtworkStyle) private var missingArtworkStyle

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio

    public init(artwork: SwiftImage?, gameTitle: String, boxartAspectRatio: PVGameBoxArtAspectRatio) {
        self.artwork = artwork
        self.gameTitle = gameTitle
        self.boxartAspectRatio = boxartAspectRatio
    }

    public var body: some SwiftUI.View {
        if let artwork = artwork {
            SwiftUI.Image(uiImage: artwork)
                .resizable()
                .aspectRatio(artwork.size.width / artwork.size.height, contentMode: .fit)
        } else {
            MissingArtworkAsyncView(
                gameTitle: gameTitle,
                ratio: boxartAspectRatio.rawValue,
                pattern: missingArtworkStyle,
                themeKey: "\(themeManager.currentPalette.name)_\(missingArtworkStyle.rawValue)"
            )
            .aspectRatio(boxartAspectRatio.rawValue, contentMode: .fit)
        }
    }
}

/// Async missing-artwork loader that generates placeholders off the main thread.
private struct MissingArtworkAsyncView: View {
    let gameTitle: String
    let ratio: CGFloat
    let pattern: RetroTestPattern
    let themeKey: String

    @State private var image: SwiftImage?
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Group {
            if let image {
                SwiftUI.Image(uiImage: image)
                    .resizable()
            } else {
                placeholderView
                    .task(id: themeKey + gameTitle + "\(ratio)") {
                        /// Check cache synchronously first for instant display
                        let isDarkTheme = ThemeManager.shared.currentPalette.dark
                        if let cached = MissingArtworkCacheManager.shared.getImage(
                            gameTitle: gameTitle,
                            ratio: ratio,
                            pattern: pattern,
                            minFontSize: RetroStyle.defaultMinFontSize,
                            isDarkTheme: isDarkTheme
                        ) {
                            self.image = cached
                            return
                        }

                        /// Only generate async if not in cache
                        self.image = await SwiftImage.missingArtworkImageAsync(
                            gameTitle: gameTitle,
                            ratio: ratio,
                            pattern: pattern
                        )
                    }
            }
        }
    }

    /// Simple placeholder that matches theme instead of black
    private var placeholderView: some View {
        Rectangle()
            .fill(
                themeManager.currentPalette.dark
                    ? Color.black.opacity(0.3)
                    : Color.gray.opacity(0.2)
            )
            .overlay(
                Rectangle()
                    .strokeBorder(
                        themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.3),
                        lineWidth: 1
                    )
            )
    }
}
