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
struct GameItemView: SwiftUI.View {

    @ObservedRealmObject var game: PVGame
    var constrainHeight: Bool = false
    var viewType: GameItemViewType = .cell
    /// The section context this GameItemView is being rendered in
    let sectionContext: HomeSectionType

    @Binding var isFocused: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @State private var artwork: SwiftImage?
    @State private var isVisible: Bool = false
    var action: () -> Void

    private var discCount: Int {
        let allFiles = game.relatedFiles.toArray()
        let uniqueFiles = Set(allFiles.compactMap { $0.url?.path })
        return uniqueFiles.count
    }

    private var shouldShowDiscIndicator: Bool {
        discCount > 1
    }

    private var shouldShowFocus: Bool {
        gamepadManager.isControllerConnected && isFocused
    }

    var body: some SwiftUI.View {
        if !game.isInvalidated {
            Button {
                action()
            } label: {
                switch viewType {
                case .cell:
                    GameItemViewCell(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                        .overlay(alignment: .topTrailing) {
                            if shouldShowDiscIndicator {
                                DiscIndicatorView(count: discCount)
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
                // Cancel artwork loading if it's still in progress when view disappears
                ArtworkLoader.shared.cancelLoading(for: game.id)
            }
            .onChange(of: game.trueArtworkURL) { _ in
                loadArtworkIfNeeded()
            }
            .onChange(of: isFocused) { newValue in
                // Prioritize loading artwork for focused items
                if newValue && artwork == nil {
                    loadArtworkWithPriority(.high)
                }
            }
            // Apply focus effects conditionally to improve performance
            .modifier(FocusEffectsModifier(isFocused: shouldShowFocus))
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
        Task {
            let image = await ArtworkLoader.shared.loadArtwork(
                for: game,
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

/// Separate modifier for focus effects to improve performance
struct FocusEffectsModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        if isFocused {
            content
                .scaleEffect(1.05)
                .brightness(0.1)
            #if os(tvOS)
                .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
            #endif
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        } else {
            content
        }
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
