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
//        #if os(tvOS)
        .onChange(of: game.trueArtworkURL) { newValue in
            updateArtwork()
        }
//        #else
//        .onChange(of: game.trueArtworkURL) { _, newValue in
//            updateArtwork()
//        }
//        #endif
    }

    private func updateArtwork() {
        PVMediaCache.shareInstance().image(forKey: game.trueArtworkURL, completion: { _, image in
            Task { @MainActor in
                self.artwork = image
            }
        })
    }
}
