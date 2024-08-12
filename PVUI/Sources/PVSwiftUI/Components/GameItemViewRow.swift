//
//  GameItemViewRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI

@available(iOS 14, tvOS 14, *)
struct GameItemViewRow: SwiftUI.View {

    var game: PVGame

    var artwork: SwiftImage?
    @State private var textMaxWidth: CGFloat = PVRowHeight

    var constrainHeight: Bool = false

    var viewType: GameItemViewType

    var body: some SwiftUI.View {
        HStack(alignment: .center, spacing: 10) {
            GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
            VStack(alignment: .leading, spacing: 0) {
                GameItemTitle(text: game.title, viewType: viewType)
                GameItemSubtitle(text: game.publishDate, viewType: viewType)
            }
        }
        .frame(height: 50.0)
    }
}
