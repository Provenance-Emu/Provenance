//
//  GameItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import PVMediaCache
import RealmSwift
import PVThemes

/// Padding and scale for `DiscIndicatorView` on compact horizontal shelves (reduced `shelfRowHeightScale`).
private enum CompactShelfDiscOverlay {
    static let compactPadding: CGFloat = 2
    static let fullPadding: CGFloat = 4
    static let compactScale: CGFloat = 0.82

    static func padding(constrainHeight: Bool, shelfRowHeightScale: CGFloat) -> CGFloat {
        constrainHeight && shelfRowHeightScale < 1.0 ? compactPadding : fullPadding
    }

    static func scale(constrainHeight: Bool, shelfRowHeightScale: CGFloat) -> CGFloat {
        constrainHeight && shelfRowHeightScale < 1.0 ? compactScale : 1.0
    }
}

@available(iOS 16, tvOS 16, *)
public struct GameItemView: SwiftUI.View {

    /// Use plain property instead of @ObservedRealmObject to avoid creating
    /// thousands of Realm subscriptions for large libraries
    public let game: PVGame
    public var constrainHeight: Bool = false
    /// Scales shelf cell height relative to `PVRowHeight` when using `.cell` with `constrainHeight`.
    public var shelfRowHeightScale: CGFloat = 1.0
    public var viewType: GameItemViewType = .cell
    /// The section context this GameItemView is being rendered in
    public let sectionContext: HomeSectionType

    @Binding public var isFocused: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @State private var artwork: SwiftImage?
    @State private var isVisible: Bool = false
    /// Cancellable handle for the current artwork load so scrolling away cancels stale work.
    @State private var artworkTask: Task<Void, Never>?
    /// Cached on first appear — avoids re-running relatedFiles.toArray() on every body evaluation.
    @State private var cachedDiscCount: Int = 1
    public var action: () -> Void

    public init(
        game: PVGame,
        constrainHeight: Bool = false,
        shelfRowHeightScale: CGFloat = 1.0,
        viewType: GameItemViewType = .cell,
        sectionContext: HomeSectionType = .allGames,
        isFocused: Binding<Bool> = .constant(false),
        themeManager: ThemeManager = ThemeManager.shared,
        gamepadManager: GamepadManager = GamepadManager.shared,
        artwork: SwiftImage? = nil,
        isVisible: Bool = false,
        action: @escaping () -> Void
    ) {
        self.game = game
        self.constrainHeight = constrainHeight
        self.shelfRowHeightScale = shelfRowHeightScale
        self.viewType = viewType
        self.sectionContext = sectionContext
        self._isFocused = isFocused
        self.themeManager = themeManager
        self.gamepadManager = gamepadManager
        self.artwork = artwork
        self.isVisible = isVisible
        self.action = action
    }

    private var shouldShowDiscIndicator: Bool {
        cachedDiscCount > 1
    }

    private var shouldShowFocus: Bool {
        gamepadManager.isControllerConnected && isFocused
    }

    public var body: some SwiftUI.View {
        if !game.isInvalidated {
            Button {
                action()
            } label: {
                switch viewType {
                case .cell:
                    GameItemViewCell(game: game, artwork: artwork, constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale, viewType: viewType)
                        .overlay(alignment: .topTrailing) {
                            if shouldShowDiscIndicator {
                                DiscIndicatorView(count: cachedDiscCount)
                                    .padding(CompactShelfDiscOverlay.padding(constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale))
                                    .scaleEffect(CompactShelfDiscOverlay.scale(constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale), anchor: .topTrailing)
                            }
                        }
                case .row:
                    GameItemViewRow(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                }
            }
            .onAppear {
                isVisible = true
                loadArtworkIfNeeded()
                refreshCachedDiscCount()
            }
            .onDisappear {
                isVisible = false
                artworkTask?.cancel()
                artworkTask = nil
                ArtworkLoader.shared.cancelLoading(for: game.id)
            }
            .onChange(of: game.relatedFiles.count) { _ in
                /// Keep disc count in sync if related files change while cell is on screen
                /// (e.g. a second disc is imported after the initial appear).
                refreshCachedDiscCount()
            }
            .onChange(of: isFocused) { newValue in
                /// Prioritize loading artwork for focused items
                if newValue && artwork == nil {
                    loadArtworkWithPriority(.high)
                }
            }
            .onChange(of: game.trueArtworkURL) { _ in
                /// Clear cached artwork and reload when URL changes (e.g., custom artwork set)
                artworkTask?.cancel()
                artwork = nil
                loadArtworkIfNeeded()
            }
            .onReceive(ArtworkLoader.shared.artworkBecameAvailable) { ids in
                guard artwork == nil, isVisible, !game.isInvalidated, ids.contains(game.id) else { return }
                loadArtworkWithPriority(.high)
            }
            #if os(tvOS)
            /// On tvOS, use card button style for native focus effects (bloom/lift)
            .buttonStyle(.card)
            #else
            /// On non-tvOS, apply custom focus effects
            .modifier(FocusEffectsModifier(isFocused: shouldShowFocus))
            #endif
        }
    }

    private func refreshCachedDiscCount() {
        guard !game.isInvalidated else { return }
        let files = game.relatedFiles.toArray()
        cachedDiscCount = Set(files.compactMap { $0.url?.path }).count
    }

    private func loadArtworkIfNeeded() {
        guard isVisible && !game.isInvalidated else { return }

        // If artwork is already loaded, no need to reload
        if artwork != nil { return }

        // Determine priority based on focus and visibility
        let priority: TaskPriority = isFocused ? .high : .medium

        loadArtworkWithPriority(priority)
    }

    private func loadArtworkWithPriority(_ priority: TaskPriority) {
        artworkTask?.cancel()

        guard !game.isInvalidated else { return }
        let gameId = game.id
        let artworkURL = game.trueArtworkURL
        let gameTitle = game.title

        artworkTask = Task(priority: priority) {
            guard !Task.isCancelled else { return }

            let image = await ArtworkLoader.shared.loadArtwork(
                gameId: gameId,
                artworkURL: artworkURL,
                gameTitle: gameTitle,
                priority: priority,
                isVisible: true
            )

            guard !Task.isCancelled else { return }
            self.artwork = image
        }
    }
}

// MARK: - Snapshot-driven rendering
@available(iOS 16, tvOS 16, *)
public struct GameItemPresentableView<Presentable: GameItemPresentable>: SwiftUI.View {
    public let game: Presentable
    public var constrainHeight: Bool = false
    /// Scales shelf cell height relative to `PVRowHeight` when using `.cell` with `constrainHeight`.
    public var shelfRowHeightScale: CGFloat = 1.0
    public var viewType: GameItemViewType = .cell
    public let sectionContext: HomeSectionType

    @Binding public var isFocused: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @State private var artwork: SwiftImage?
    @State private var isVisible: Bool = false
    /// Cancellable handle for the current artwork load so scrolling away cancels stale work.
    @State private var artworkTask: Task<Void, Never>?
    public var action: () -> Void

    public init(
        game: Presentable,
        constrainHeight: Bool = false,
        shelfRowHeightScale: CGFloat = 1.0,
        viewType: GameItemViewType = .cell,
        sectionContext: HomeSectionType = .allGames,
        isFocused: Binding<Bool> = .constant(false),
        themeManager: ThemeManager = ThemeManager.shared,
        gamepadManager: GamepadManager = GamepadManager.shared,
        artwork: SwiftImage? = nil,
        isVisible: Bool = false,
        action: @escaping () -> Void
    ) {
        self.game = game
        self.constrainHeight = constrainHeight
        self.shelfRowHeightScale = shelfRowHeightScale
        self.viewType = viewType
        self.sectionContext = sectionContext
        self._isFocused = isFocused
        self.themeManager = themeManager
        self.gamepadManager = gamepadManager
        self.artwork = artwork
        self.isVisible = isVisible
        self.action = action
    }

    private var shouldShowFocus: Bool {
        gamepadManager.isControllerConnected && isFocused
    }

    private var shouldShowDiscIndicator: Bool {
        game.discCount > 1
    }

    public var body: some SwiftUI.View {
        if !game.isInvalidated {
            Button {
                action()
            } label: {
                switch viewType {
                case .cell:
                    GameItemViewCell(game: game, artwork: artwork, constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale, viewType: viewType)
                        .overlay(alignment: .topTrailing) {
                            if shouldShowDiscIndicator {
                                DiscIndicatorView(count: game.discCount)
                                    .padding(CompactShelfDiscOverlay.padding(constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale))
                                    .scaleEffect(CompactShelfDiscOverlay.scale(constrainHeight: constrainHeight, shelfRowHeightScale: shelfRowHeightScale), anchor: .topTrailing)
                            }
                        }
                case .row:
                    GameItemViewRow(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                }
            }
            .onAppear {
                isVisible = true
                loadArtworkIfNeeded()
            }
            .onDisappear {
                isVisible = false
                artworkTask?.cancel()
                artworkTask = nil
                ArtworkLoader.shared.cancelLoading(for: game.id)
            }
            .onChange(of: isFocused) { newValue in
                if newValue && artwork == nil {
                    loadArtworkWithPriority(.high)
                }
            }
            .onChange(of: game.trueArtworkURL) { _ in
                /// Clear cached artwork and reload when URL changes (e.g., custom artwork set)
                artworkTask?.cancel()
                artwork = nil
                loadArtworkIfNeeded()
            }
            .onReceive(ArtworkLoader.shared.artworkBecameAvailable) { ids in
                guard artwork == nil, isVisible, !game.isInvalidated, ids.contains(game.id) else { return }
                loadArtworkWithPriority(.high)
            }
            #if os(tvOS)
            .buttonStyle(.card)
            #else
            .modifier(FocusEffectsModifier(isFocused: shouldShowFocus))
            #endif
        }
    }

    private func loadArtworkIfNeeded() {
        guard isVisible && !game.isInvalidated else { return }
        if artwork != nil { return }
        let priority: TaskPriority = isFocused ? .high : .medium
        loadArtworkWithPriority(priority)
    }

    private func loadArtworkWithPriority(_ priority: TaskPriority) {
        // Cancel any in-flight load for this cell — the new request takes priority
        artworkTask?.cancel()

        let gameId = game.id
        let artworkURL = game.trueArtworkURL
        let gameTitle = game.title

        artworkTask = Task(priority: priority) {
            guard !Task.isCancelled else { return }

            let image = await ArtworkLoader.shared.loadArtwork(
                gameId: gameId,
                artworkURL: artworkURL,
                gameTitle: gameTitle,
                priority: priority,
                isVisible: true
            )

            guard !Task.isCancelled else { return }
            self.artwork = image
        }
    }
}

/// Separate modifier for focus effects to improve performance
/// On tvOS, we rely on the native focus system instead of custom effects
/// to avoid conflicts between native bloom and custom styling
struct FocusEffectsModifier: ViewModifier {
    let isFocused: Bool
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Accent color for the focus ring, derived from the current theme
    private var focusAccent: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .retroCyan
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(tvOS)
        /// On tvOS, let the native focus system handle all focus effects
        content
        #else
        if isFocused {
            content
                .scaleEffect(1.05)
                .brightness(0.1)
                .overlay(
                    RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
                        .stroke(focusAccent, lineWidth: 2)
                        .shadow(color: focusAccent.opacity(0.5), radius: 6)
                )
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        } else {
            content
        }
        #endif
    }
}

struct DiscIndicatorView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "opticaldisc")
            Text("\(count)")
        }
        .font(.system(size: 12, weight: .bold))
        .padding(4)
        .background(Material.ultraThin)
        .clipShape(Capsule())
    }
}
