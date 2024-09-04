//
//  GameItemViewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI

@available(iOS 14, tvOS 14, *)
struct GameItemViewCell: SwiftUI.View {

    var game: PVGame

    var artwork: SwiftImage?

    var constrainHeight: Bool = false

    var viewType: GameItemViewType

    @State private var textMaxWidth: CGFloat = PVRowHeight

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 3) {
            GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
            VStack(alignment: .leading, spacing: 0) {
                GameItemTitle(text: game.title, viewType: viewType)
                GameItemSubtitle(text: game.publishDate, viewType: viewType)
            }
            .frame(width: textMaxWidth)
        }
        .if(constrainHeight) { view in
            view.frame(height: PVRowHeight)
        }
        .onPreferenceChange(ArtworkDynamicWidthPreferenceKey.self) {
            textMaxWidth = $0
        }
    }
}
