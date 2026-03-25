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

@available(iOS 16, tvOS 16, *)
public struct GameItemView: SwiftUI.View {

    /// Use plain property instead of @ObservedRealmObject to avoid creating
    /// thousands of Realm subscriptions for large libraries
    public let game: PVGame
    public var constrainHeight: Bool = false
    public var viewType: GameItemViewType = .cell
    /// The section context this GameItemView is being rendered in
    public let sectionContext: HomeSectionType

    @Binding public var isFocused: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @State private var artwork: SwiftImage?
    @State private var isVisible: Bool = false
    /// Cached on first appear — avoids re-running relatedFiles.toArray() on every body evaluation.
    @State private var cachedDiscCount: Int = 1
    public var action: () -> Void

    public init(game: PVGame, constrainHeight: Bool = false, viewType: GameItemViewType = .cell, sectionContext: HomeSectionType = .allGames, isFocused: Binding<Bool> = .constant(false), themeManager: ThemeManager = ThemeManager.shared, gamepadManager: GamepadManager = GamepadManager.shared, artwork: SwiftImage? = nil, isVisible: Bool = false, action: @escaping () -> Void) {
        self.game = game
        self.constrainHeight = constrainHeight
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
                    GameItemViewCell(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                        .overlay(alignment: .topTrailing) {
                            if shouldShowDiscIndicator {
                                DiscIndicatorView(count: cachedDiscCount)
                                    .padding(4)
                            }
                        }
                case .row:
                    GameItemViewRow(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                }
            }
            .onAppear {
                isVisible = true
                loadArtworkIfNeeded()
                if !game.isInvalidated {
                    let files = game.relatedFiles.toArray()
                    cachedDiscCount = Set(files.compactMap { $0.url?.path }).count
                }
            }
            .onDisappear {
                isVisible = false
                /// Cancel artwork loading if it's still in progress when view disappears
                ArtworkLoader.shared.cancelLoading(for: game.id)
            }
            .onChange(of: isFocused) { newValue in
                /// Prioritize loading artwork for focused items
                if newValue && artwork == nil {
                    loadArtworkWithPriority(.high)
                }
            }
            .onChange(of: game.trueArtworkURL) { _ in
                /// Clear cached artwork and reload when URL changes (e.g., custom artwork set)
                artwork = nil
                loadArtworkIfNeeded()
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

    private func loadArtworkIfNeeded() {
        guard isVisible && !game.isInvalidated else { return }

        // If artwork is already loaded, no need to reload
        if artwork != nil { return }

        // Determine priority based on focus and visibility
        let priority: TaskPriority = isFocused ? .high : .medium

        loadArtworkWithPriority(priority)
    }

    private func loadArtworkWithPriority(_ priority: TaskPriority) {
        /// Extract needed properties on main thread to avoid Realm thread issues
        /// Realm objects can only be accessed from the thread they were created on
        guard !game.isInvalidated else { return }
        let gameId = game.id
        let artworkURL = game.trueArtworkURL
        let gameTitle = game.title

        Task.detached(priority: priority) { [isVisible] in
            let image = await ArtworkLoader.shared.loadArtwork(
                gameId: gameId,
                artworkURL: artworkURL,
                gameTitle: gameTitle,
                priority: priority,
                isVisible: isVisible
            )

            // Only update if the view is still visible
            if isVisible {
                await MainActor.run {
                    self.artwork = image
                }
            }
        }
    }
}

// MARK: - Snapshot-driven rendering
@available(iOS 16, tvOS 16, *)
public struct GameItemPresentableView<Presentable: GameItemPresentable>: SwiftUI.View {
    public let game: Presentable
    public var constrainHeight: Bool = false
    public var viewType: GameItemViewType = .cell
    public let sectionContext: HomeSectionType

    @Binding public var isFocused: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @State private var artwork: SwiftImage?
    @State private var isVisible: Bool = false
    public var action: () -> Void

    public init(
        game: Presentable,
        constrainHeight: Bool = false,
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
                    GameItemViewCell(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                        .overlay(alignment: .topTrailing) {
                            if shouldShowDiscIndicator {
                                DiscIndicatorView(count: game.discCount)
                                    .padding(4)
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
                ArtworkLoader.shared.cancelLoading(for: game.id)
            }
            .onChange(of: isFocused) { newValue in
                if newValue && artwork == nil {
                    loadArtworkWithPriority(.high)
                }
            }
            .onChange(of: game.trueArtworkURL) { _ in
                /// Clear cached artwork and reload when URL changes (e.g., custom artwork set)
                artwork = nil
                loadArtworkIfNeeded()
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
        let gameId = game.id
        let artworkURL = game.trueArtworkURL
        let gameTitle = game.title

        Task.detached(priority: priority) { [isVisible] in
            let image = await ArtworkLoader.shared.loadArtwork(
                gameId: gameId,
                artworkURL: artworkURL,
                gameTitle: gameTitle,
                priority: priority,
                isVisible: isVisible
            )

            if isVisible {
                await MainActor.run {
                    self.artwork = image
                }
            }
        }
    }
}

/// Separate modifier for focus effects to improve performance
/// On tvOS, we rely on the native focus system instead of custom effects
/// to avoid conflicts between native bloom and custom styling
struct FocusEffectsModifier: ViewModifier {
    let isFocused: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(tvOS)
        /// On tvOS, let the native focus system handle all focus effects
        /// This provides consistent behavior with Siri Remote and game controllers
        content
        #else
        if isFocused {
            content
                .scaleEffect(1.05)
                .brightness(0.1)
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
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
