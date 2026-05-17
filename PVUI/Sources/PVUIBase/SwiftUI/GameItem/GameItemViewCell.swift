//
//  GameItemViewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PVThemes
import PVSettings
import Defaults

/// A view that displays a game item in a cell layout
struct GameItemViewCell<Presentable: GameItemPresentable>: View, Equatable {
    /// Implement Equatable to prevent unnecessary redraws.
    ///
    /// **Performance note.** Earlier this implementation compared
    /// `lhs.artwork?.hashValue == rhs.artwork?.hashValue`. `UIImage.hashValue`
    /// walks the entire pixel buffer — hashing megabytes per cell — and
    /// `LazyVGrid` evaluates `==` per visible cell on every scroll tick.
    /// That single comparison was the main source of scroll stutter in the
    /// library grid. Use a cheap identity + size proxy instead: if the
    /// `UIImage` reference and dimensions are the same, the rendered pixels
    /// are the same as far as this cell cares about. `@State` fields like
    /// `hoverScale` / `glowIntensity` are intentionally NOT compared here —
    /// SwiftUI re-renders the body via state invalidation regardless of what
    /// this Equatable returns, so including them is both a no-op for
    /// correctness and a slowdown per scroll tick.
    static func == (lhs: GameItemViewCell<Presentable>, rhs: GameItemViewCell<Presentable>) -> Bool {
        lhs.game.id == rhs.game.id &&
        lhs.game.title == rhs.game.title &&
        lhs.game.trueArtworkURL == rhs.game.trueArtworkURL &&
        lhs.game.publishDate == rhs.game.publishDate &&
        lhs.game.rating == rhs.game.rating &&
        lhs.game.hasCloudAssets == rhs.game.hasCloudAssets &&
        lhs.game.isDownloaded == rhs.game.isDownloaded &&
        lhs.game.boxartAspectRatio == rhs.game.boxartAspectRatio &&
        lhs.artwork === rhs.artwork &&
        lhs.artwork?.size == rhs.artwork?.size &&
        lhs.shelfRowHeightScale == rhs.shelfRowHeightScale &&
        lhs.constrainHeight == rhs.constrainHeight &&
        lhs.viewType == rhs.viewType
    }

    /// Use plain property instead of @ObservedRealmObject for performance
    let game: Presentable
    @Default(.showGameTitles) private var showGameTitles
    @Default(.iCloudSync) private var iCloudSyncEnabled
    var artwork: SwiftImage?
    var constrainHeight: Bool = false
    /// Scales the fixed shelf height (`PVRowHeight`) when `constrainHeight` is true; favorites/recent shelves use `PVCompactShelfRowHeightScale`.
    var shelfRowHeightScale: CGFloat = 1.0
    var viewType: GameItemViewType
    /// Optional so the title `MarqueeText` only lays out once — after the
    /// real artwork width is measured. Previously this defaulted to
    /// `PVRowHeight`, which caused MarqueeText to set up its scrolling
    /// animation at the wrong width, then immediately re-lay-out + restart
    /// when the preference key delivered the actual width. With LazyVGrid
    /// scrolling many cells through these two-pass layouts per recycle, the
    /// duplicate setup + animation churn produced visible scroll hitches.
    @State private var textMaxWidth: CGFloat? = nil
    @State private var hoverScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.0
    @State private var needsSync: Bool = false
    @State private var isDownloading: Bool = false

    /// Track if this cell is currently visible on screen
    @State private var isVisible: Bool = false

    @ObservedObject private var themeManager = ThemeManager.shared

    private var textColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    private var discCount: Int {
        game.discCount
    }

    private var shouldShowCloudIndicator: Bool {
        game.hasCloudAssets
    }

    /// Drives iCloud badge and spacing so compact shelves (e.g. half `PVRowHeight`) are not dominated by chrome.
    private var compactShelfChromeFactor: CGFloat {
        guard constrainHeight else { return 1.0 }
        return min(1.0, shelfRowHeightScale)
    }

    private var cloudSyncIndicatorSize: CGFloat {
        max(14, 24 * compactShelfChromeFactor)
    }

    private var cloudSyncIndicatorOuterPadding: CGFloat {
        max(2, 6 * compactShelfChromeFactor)
    }

    private var artworkToTitleSpacing: CGFloat {
        max(2, 8 * compactShelfChromeFactor)
    }

    private var glowColor: Color {
        switch themeManager.currentPalette {
        case is DarkThemePalette:
            return .cyan
        case is LightThemePalette:
            return .blue
        default:
            return .purple
        }
    }

    var body: some View {
        if !game.isInvalidated {
            VStack(alignment: .leading, spacing: 3) {
                Spacer(minLength: 0) /// Push content to bottom

                /// Use a ViewBuilder function to cache the artwork view
                artworkView
                    .overlay(alignment: .topTrailing) {
                        if shouldShowCloudIndicator {
                            CloudSyncIndicatorView(
                                isDownloaded: game.isDownloaded,
                                hasCloudAssets: game.hasCloudAssets,
                                isDownloading: isDownloading,
                                syncEnabled: iCloudSyncEnabled,
                                size: cloudSyncIndicatorSize
                            )
                            .padding(cloudSyncIndicatorOuterPadding)
                        }
                    }
                    .padding(.bottom, artworkToTitleSpacing) /// Add padding between artwork and text

                if showGameTitles {
                    /// Use a ViewBuilder function to cache the text view
                    textView
                }
            }
            .if(constrainHeight) { view in
                view.frame(height: PVRowHeight * shelfRowHeightScale, alignment: .bottom)
            }
            .onPreferenceChange(ArtworkDynamicWidthPreferenceKey.self) { width in
                // `GameItemThumbnail.measuredWidth` defaults to 0 and publishes
                // `.preference(value: 0)` on first render before its
                // GeometryReader / onGeometryChange callback fires. Drop the
                // bogus 0 so the title doesn't render at zero width, and
                // dedupe identical writes so SwiftUI doesn't re-invalidate
                // the cell body on every layout pass during scroll.
                guard width > 0, textMaxWidth != width else { return }
                textMaxWidth = width
            }
            .onAppear {
                isVisible = true
                /// Narrower shelf cells imply narrower artwork; seed width before `ArtworkDynamicWidthPreferenceKey` fires.
                if constrainHeight, shelfRowHeightScale < 1.0, textMaxWidth == nil {
                    textMaxWidth = PVRowHeight * shelfRowHeightScale
                }
            }
            .onDisappear {
                isVisible = false
                /// Reset effects when not visible to save resources
                if hoverScale != 1.0 {
                    hoverScale = 1.0
                }
                if glowIntensity != 0.0 {
                    glowIntensity = 0.0
                }
            }
        }
    }

    /// Cached artwork view
    @ViewBuilder
    private var artworkView: some View {
        ZStack {
            /// Only show glow effects when hovering or when explicitly needed
            /// This significantly reduces rendering overhead
            if let artwork = artwork, glowIntensity > 0 {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .blur(radius: 10)
                    .opacity(glowIntensity * 0.3)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                glowColor.opacity(0.3 * glowIntensity),
                                .clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    )
            }

            /// Main artwork - always shown
            GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                .scaleEffect(hoverScale)
                .overlay(alignment: .topTrailing) {
                    if iCloudSyncEnabled && needsSync {
                        cloudSyncStatusIndicator
                            .padding(8)
                    }
                }
                /// Only apply overlay when hovering
                .overlay(
                    Group {
                        if glowIntensity > 0 {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            glowColor.opacity(0.8),
                                            glowColor.complementary().opacity(0.8),
                                            glowColor.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .opacity(glowIntensity)
                                .scaleEffect(hoverScale)
                        }
                    }
                )
                /// Only apply shadow when hovering
                .shadow(color: glowIntensity > 0 ? glowColor.opacity(0.5 * glowIntensity) : .clear,
                        radius: glowIntensity > 0 ? 10 : 0,
                        x: 0, y: 0)
            #if !os(tvOS)
                .onHover { hovering in
                    /// Only animate if the view is visible
                    guard isVisible else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoverScale = hovering ? 1.05 : 1.0
                        glowIntensity = hovering ? 1.0 : 0.0
                    }
                }
            #endif
        }
    }

    /// Cached text view
    @ViewBuilder
    private var textView: some View {
        // Title and date container
        VStack(alignment: .leading, spacing: 0) { /// No spacing between title and date
            // Only build MarqueeText once we know its target width.
            // Otherwise MarqueeText is laid out + animation-restarted at the
            // wrong width when the real measurement arrives, which causes
            // visible scroll hitches in LazyVGrid as cells recycle.
            if let textMaxWidth, textMaxWidth > 0 {
                MarqueeText(text: game.title,
                            font: .system(size: viewType.titleFontSize, weight: .bold, design: .monospaced),
                            delay: 1.0,
                            speed: 50.0,
                            loop: true)
                .foregroundColor(textColor)
                .shadow(color: glowColor, radius: 3, x: 0, y: 0)
                .frame(maxWidth: textMaxWidth, alignment: .leading)
                .padding(.bottom, -2) /// Negative padding to remove default spacing
            } else {
                // Reserve the slot so the cell's vertical layout doesn't
                // jump when the title appears on the next frame.
                Color.clear
                    .frame(height: viewType.titleFontSize * 1.2)
            }

            // Date and rating container
            HStack {
                Text(game.publishDate ?? " ")
                    .font(.system(size: viewType.subtitleFontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                /// Only show stars if game is rated
                if game.rating >= 0 {
                    Text(String(repeating: "⭐️", count: game.rating))
                        .font(.system(size: viewType.subtitleFontSize - 2))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, -2) /// Negative padding to remove default spacing
        }
        .frame(height: viewType.subtitleFontSize + 2) /// Reduced fixed height for text container
    }
}

/// Cloud sync indicator view
private extension GameItemViewCell {
    var cloudSyncStatusIndicator: some View {
        Image(systemName: "icloud")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(6)
            .background(
                Circle()
                    .fill(Color.retroPink.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            )
    }

    /// Check if the game file needs to be synced to iCloud
    func checkSyncStatus() {
        // Snapshot-driven rendering: do not inspect file state here.
        // (Avoids requiring PVFile / Realm objects on the render path.)
        needsSync = false
    }
}

extension Color {
    func isDarkColor() -> Bool {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        /// Handle different color spaces safely
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil) {
            let brightness = (red * 299 + green * 587 + blue * 114) / 1000
            return brightness < 0.5
        } else if let components = uiColor.cgColor.components {
            /// Handle grayscale colors
            let brightness = components[0] * (components.count > 1 ? 1.0 : 1.0)
            return brightness < 0.5
        }

        /// Default to dark if we can't determine
        return true
    }

    func complementary() -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1.0),
                     saturation: saturation,
                     brightness: brightness,
                     opacity: alpha)
    }
}
