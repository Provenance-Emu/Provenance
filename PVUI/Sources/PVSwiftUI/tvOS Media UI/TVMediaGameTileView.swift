import SwiftUI
import PVLibrary
import PVUIBase
import PVThemes
import PVSettings
import Defaults

#if os(tvOS)

/// Premium game tile with divine RetroWave aesthetics
/// Scales elegantly on focus with neon glow effects
@available(tvOS 16.0, *)
struct TVMediaGameTileView: View {
    let game: PVGame
    let titleFont: Font
    let onPlay: () -> Void
    let contextMenu: () -> AnyView
    let isAtLeftEdge: Bool
    var focusCoordinator: TVMediaFocusCoordinator?

    @FocusState private var isFocused: Bool
    @State private var artwork: UIImage?
    @State private var artworkSize: CGSize?
    @State private var glowIntensity: Double = 0.0
    @State private var borderGlow: Double = 0.0
    /// Blur artwork when obfuscation is enabled.
    @Default(.obfuscateArtwork) private var obfuscateArtwork

    /// Base height for tiles - width adjusts based on artwork aspect ratio
    private let baseHeight: CGFloat = 220
    private let minWidth: CGFloat = 160
    private let maxWidth: CGFloat = 340
    /// Blur radius for artwork obfuscation.
    private let obfuscationBlurRadius: CGFloat = 6

    init(
        game: PVGame,
        titleFont: Font = .subheadline.weight(.semibold),
        onPlay: @escaping () -> Void,
        contextMenu: @escaping () -> AnyView,
        isAtLeftEdge: Bool = false,
        focusCoordinator: TVMediaFocusCoordinator? = nil
    ) {
        self.game = game
        self.titleFont = titleFont
        self.onPlay = onPlay
        self.contextMenu = contextMenu
        self.isAtLeftEdge = isAtLeftEdge
        self.focusCoordinator = focusCoordinator
    }

    private var tileWidth: CGFloat {
        guard let size = artworkSize, size.height > 0 else {
            return baseHeight * 0.75
        }
        let ratio = size.width / size.height
        let calculatedWidth = baseHeight * ratio
        return min(max(calculatedWidth, minWidth), maxWidth)
    }

    var body: some View {
        Button(action: onPlay) {
            VStack(spacing: 0) {
                // Artwork container with glow effects
                ZStack {
                    // Outer glow layer
                    if isFocused {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.retroPink.opacity(0.3),
                                        Color.retroBlue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 20)
                            .opacity(glowIntensity)
                    }

                    // Main artwork
                    artworkView
                        .frame(width: tileWidth, height: baseHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(focusBorder)
                }
                .shadow(color: isFocused ? Color.retroPink.opacity(glowIntensity * 0.6) : .clear, radius: 25, x: 0, y: 8)
                .shadow(color: isFocused ? Color.retroBlue.opacity(glowIntensity * 0.4) : .clear, radius: 35, x: 0, y: 12)

                // Title with refined typography
                Text(game.title)
                    .font(.system(size: 15, weight: isFocused ? .semibold : .medium, design: .default))
                    .tracking(0.3)
                    .foregroundStyle(
                        isFocused ?
                            AnyShapeStyle(LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )) :
                            AnyShapeStyle(Color.white.opacity(0.8))
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: tileWidth)
                    .padding(.top, 14)
                    .padding(.horizontal, 4)
                    .shadow(color: isFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 6)
            }
        }
        .buttonStyle(TVMediaTileButtonStyle(isFocused: isFocused))
        .focused($isFocused)
        .contextMenu { contextMenu() }
        .task(id: game.id) {
            await loadArtworkIfNeeded()
        }
        .onChange(of: isFocused) { focused in
            if focused {
                Task { await loadArtworkIfNeeded(priority: .userInitiated) }
                // Staggered glow animation for premium feel
                withAnimation(.easeOut(duration: 0.2)) {
                    borderGlow = 1.0
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    glowIntensity = 0.8
                }
                focusCoordinator?.contentItemFocused(id: game.id, isAtLeftEdge: isAtLeftEdge)
            } else {
                withAnimation(.easeIn(duration: 0.15)) {
                    glowIntensity = 0.0
                    borderGlow = 0.0
                }
            }
        }
        .onAppear {
            if isAtLeftEdge {
                focusCoordinator?.registerLeftEdgeItem(game.id)
            }
        }
        .onDisappear {
            focusCoordinator?.unregisterLeftEdgeItem(game.id)
        }
    }

    // MARK: - Artwork View

    private var artworkView: some View {
        Group {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .blur(radius: obfuscateArtwork ? obfuscationBlurRadius : 0)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else {
                SMPTEColorBarsView()
            }
        }
    }

    // MARK: - Focus Border

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: isFocused ? [
                        Color.retroPink.opacity(borderGlow),
                        Color.retroBlue.opacity(borderGlow * 0.8),
                        Color.retroPink.opacity(borderGlow * 0.6)
                    ] : [.clear, .clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isFocused ? 3 : 0
            )
            .animation(.easeOut(duration: 0.2), value: borderGlow)
    }

    // MARK: - Artwork Loading

    private func loadArtworkIfNeeded(priority: TaskPriority = .utility) async {
        guard artwork == nil else { return }
        guard !game.isInvalidated else { return }
        let image = await ArtworkLoader.shared.loadArtwork(for: game, priority: priority, isVisible: true)
        if let image {
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    artwork = image
                    artworkSize = image.size
                }
            }
        }
    }
}

// MARK: - SMPTE Color Bars

@available(tvOS 16.0, *)
struct SMPTEColorBarsView: View {
    private let colors: [Color] = [
        Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 0.75, green: 0.75, blue: 0.0),
        Color(red: 0.0, green: 0.75, blue: 0.75),
        Color(red: 0.0, green: 0.75, blue: 0.0),
        Color(red: 0.75, green: 0.0, blue: 0.75),
        Color(red: 0.75, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.0, blue: 0.75)
    ]

    var body: some View {
        // Lightweight placeholder without nested GeometryReader overlays
        LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Tile Button Style

@available(tvOS 16.0, *)
struct TVMediaTileButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#endif
