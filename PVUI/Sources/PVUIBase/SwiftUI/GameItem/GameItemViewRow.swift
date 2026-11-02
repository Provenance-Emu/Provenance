//
//  GameItemViewRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import Defaults
import PVSettings
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GameItemViewRow<Presentable: GameItemPresentable>: SwiftUI.View, Equatable {
    /// Implement Equatable to prevent unnecessary redraws
    static func == (lhs: GameItemViewRow<Presentable>, rhs: GameItemViewRow<Presentable>) -> Bool {
        /// Only redraw if these key properties change
        lhs.game.id == rhs.game.id &&
        lhs.game.title == rhs.game.title &&
        lhs.game.trueArtworkURL == rhs.game.trueArtworkURL &&
        lhs.game.publishDate == rhs.game.publishDate &&
        lhs.game.rating == rhs.game.rating &&
        lhs.game.lastPlayed == rhs.game.lastPlayed &&
        lhs.game.playCount == rhs.game.playCount &&
        lhs.game.hasCloudAssets == rhs.game.hasCloudAssets &&
        lhs.game.isDownloaded == rhs.game.isDownloaded &&
        lhs.game.boxartAspectRatio == rhs.game.boxartAspectRatio &&
        lhs.game.systemShortName == rhs.game.systemShortName &&
        lhs.game.discCount == rhs.game.discCount &&
        lhs.game.isPatchVariant == rhs.game.isPatchVariant &&
        lhs.artwork === rhs.artwork &&
        lhs.artwork?.size == rhs.artwork?.size &&
        lhs.hoverScale == rhs.hoverScale &&
        lhs.glowIntensity == rhs.glowIntensity
    }

    /// Use plain property instead of @ObservedRealmObject for performance
    let game: Presentable
    @ScaledMetric(relativeTo: .caption) private var textScale: CGFloat = 1
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Default(.iCloudSync) private var iCloudSyncEnabled

    var artwork: SwiftImage?
    var constrainHeight: Bool = false
    var viewType: GameItemViewType

    @State private var textMaxWidth: CGFloat = PVRowHeight
    @State private var hoverScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.0
    @State private var isVisible: Bool = false
    @State private var isDownloading: Bool = false

    @ObservedObject private var themeManager = ThemeManager.shared

    private var discCount: Int {
        game.discCount
    }

    private var shouldShowDiscIndicator: Bool {
        discCount > 1
    }

    private var shouldShowCloudIndicator: Bool {
        game.hasCloudAssets
    }

    private var textColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    private var glowColor: Color {
        Color.retroPurple
    }

    private var secondaryColor: Color {
        Color.retroBlue
    }

    var body: some SwiftUI.View {
        if !game.isInvalidated {
            HStack(alignment: .center, spacing: 12) {
                // Game cover image with effects
                ZStack {
                    // Glow effect behind the image
                    if let artwork = artwork, glowIntensity > 0 {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: 8)
                            .opacity(glowIntensity * 0.3)
                            .frame(width: 60, height: 60)
                    }

                    // Main artwork
                    GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                        .frame(width: 60, height: 60)
                        .scaleEffect(hoverScale)
                        .overlay(alignment: .bottomLeading) {
                            PatchTileBadge(isPatchVariant: game.isPatchVariant, md5: game.md5, compact: true)
                                .padding(2)
                        }
                        .overlay(alignment: .topTrailing) {
                            if shouldShowCloudIndicator {
                                CloudSyncIndicatorView(
                                    isDownloaded: game.isDownloaded,
                                    hasCloudAssets: game.hasCloudAssets,
                                    isDownloading: isDownloading,
                                    syncEnabled: iCloudSyncEnabled,
                                    size: 20
                                )
                                .padding(2)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            glowColor.opacity(0.8),
                                            secondaryColor.opacity(0.8),
                                            glowColor.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .opacity(glowIntensity > 0 ? glowIntensity : 0)
                        )
                        .shadow(color: glowIntensity > 0 ? glowColor.opacity(0.5 * glowIntensity) : .clear,
                                radius: glowIntensity > 0 ? 8 : 0,
                                x: 0, y: 0)
                }
                .overlay(alignment: .bottomTrailing) {
                    if shouldShowDiscIndicator {
                        DiscIndicatorView(count: discCount, compact: true)
                            .padding(2)
                    }
                }

                // Game details
                VStack(alignment: .leading, spacing: 4) {
                    // Title with marquee effect for long titles
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            Text(game.title)
                                .font(.system(size: 13 * textScale, weight: .medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            MarqueeText(text: game.title,
                                        font: .system(size: 13 * textScale, weight: .medium),
                                        delay: 1.0,
                                        speed: 50.0,
                                        loop: true)
                        }
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Game metadata row
                    HStack(spacing: 12) {
                        // System name
                        if let systemShortName = game.systemShortName, !systemShortName.isEmpty {
                            Text(systemShortName.uppercased())
                                .font(.system(size: viewType.subtitleFontSize * textScale, weight: .semibold))
                                .foregroundColor(secondaryColor)
                        }

                        // Release date
                        if let publishDate = game.publishDate, !publishDate.isEmpty {
                            Text(publishDate)
                                .font(.system(size: (viewType.subtitleFontSize - 1) * textScale, weight: .medium))
                                .foregroundColor(textColor.opacity(0.7))
                        }

                        Spacer()

                        // Rating stars
                        if game.rating > 0 {
                            HStack(spacing: 1) {
                                ForEach(0..<min(5, game.rating), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                }
                            }
                            .font(.system(size: 9))
                            .foregroundStyle(Color.retroYellow)
                            .accessibilityLabel("Rating: \(game.rating) stars")
                        }
                    }

                    // Additional game info row
                    HStack {
                        // Last played date
                        if let lastPlayed = game.lastPlayed {
                            Text("PLAYED: \(lastPlayed.formatted(date: .numeric, time: .shortened))")
                                .font(.system(size: (viewType.subtitleFontSize - 2) * textScale, weight: .medium))
                                .foregroundColor(textColor.opacity(0.65))
                        }

                        Spacer()

                        // Play count
                        if game.playCount > 0 {
                            Text("\(game.playCount)x")
                                .font(.system(size: (viewType.subtitleFontSize - 2) * textScale, weight: .bold))
                                .foregroundColor(secondaryColor.opacity(0.8))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 78)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroDarkBlue.opacity(0.78))

                    // Border gradient
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    glowColor.opacity(glowIntensity > 0 ? 0.6 : 0.2),
                                    secondaryColor.opacity(glowIntensity > 0 ? 0.6 : 0.28)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                }
            )
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
                // Reset effects when not visible
                if hoverScale != 1.0 {
                    hoverScale = 1.0
                }
                if glowIntensity != 0.0 {
                    glowIntensity = 0.0
                }
            }
            #if !os(tvOS)
            .onHover { hovering in
                // Only animate if the view is visible
                guard isVisible else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoverScale = hovering ? 1.05 : 1.0
                    glowIntensity = hovering ? 1.0 : 0.0
                }
            }
            #endif
        }
    }
}
