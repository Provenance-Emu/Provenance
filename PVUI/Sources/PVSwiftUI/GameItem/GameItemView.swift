//
//  GameItemView 2.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI

@available(iOS 14, tvOS 14, *)
struct GameItemView: SwiftUI.View {

    var game: PVGame
    var constrainHeight: Bool = false
    var viewType: GameItemViewType = .cell

    @State var artwork: SwiftImage?
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
            PVMediaCache.shareInstance().image(forKey: game.trueArtworkURL, completion: { _, image in
                Task { @MainActor in
                    self.artwork = image
                }
            })
        }
    }
}

