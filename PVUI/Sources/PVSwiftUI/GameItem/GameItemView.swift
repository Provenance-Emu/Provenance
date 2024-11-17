//
//  GameItemView 2.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import PVMediaCache
import RealmSwift

@available(iOS 16, tvOS 16, *)
struct GameItemView: SwiftUI.View {

    @ObservedRealmObject var game: PVGame
    var constrainHeight: Bool = false
    var viewType: GameItemViewType = .cell

    @State private var artwork: SwiftImage?
    var action: () -> Void
    @Environment(\.isFocused) private var isFocused: Bool

    var body: some SwiftUI.View {
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
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .brightness(isFocused ? 0.1 : 0)
#if os(tvOS)
.shadow(color: isFocused ? .white.opacity(0.5) : .clear, radius: isFocused ? 10 : 0)
#endif
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private func updateArtwork() {
        PVMediaCache.shareInstance().image(forKey: game.trueArtworkURL, completion: { _, image in
            Task { @MainActor in
                self.artwork = image
            }
        })
    }
}
