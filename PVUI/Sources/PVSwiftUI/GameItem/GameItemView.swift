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
    var action: () -> Void

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
                case .row:
                    GameItemViewRow(game: game, artwork: artwork, constrainHeight: constrainHeight, viewType: viewType)
                }
            }
            .onAppear {
                updateArtwork()
            }
            .onChange(of: game.trueArtworkURL) { _ in
                updateArtwork()
            }
            .scaleEffect(shouldShowFocus ? 1.05 : 1.0)
            .brightness(shouldShowFocus ? 0.1 : 0)
    #if os(tvOS)
            .shadow(color: shouldShowFocus ? .white.opacity(0.5) : .clear, radius: shouldShowFocus ? 10 : 0)
    #endif
            .overlay(
                Rectangle()
                    .stroke(shouldShowFocus ? themeManager.currentPalette.menuIconTint.swiftUIColor : .clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.15), value: shouldShowFocus)
        }
    }

    private func updateArtwork() {
        guard !game.isInvalidated else {
            return
        }
        PVMediaCache.shareInstance().image(forKey: game.trueArtworkURL, completion: { _, image in
            Task { @MainActor in
                self.artwork = image
            }
        })
    }
}
