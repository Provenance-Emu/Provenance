//
//  GameItemViewCell.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVRealm
import RealmSwift

struct GameItemViewCell: SwiftUI.View {
    @ObservedRealmObject var game: PVGame
    @Default(.showGameTitles) private var showGameTitles

    var artwork: SwiftImage?
    var constrainHeight: Bool = false
    var viewType: GameItemViewType
    @State private var textMaxWidth: CGFloat = PVRowHeight

    var body: some SwiftUI.View {
        if !game.isInvalidated {
            VStack(alignment: .leading, spacing: 3) {
                Spacer(minLength: 0)

                GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                    .frame(maxWidth: .infinity)
                    .alignmentGuide(.bottom) { d in d[.bottom] }

                if showGameTitles {
                    VStack(alignment: .leading, spacing: 0) {
                        GameItemTitle(text: game.title, viewType: viewType)
                            .frame(width: textMaxWidth)
                            .clipped()
                        GameItemSubtitle(text: game.publishDate, viewType: viewType)
                    }
                    .frame(width: textMaxWidth)
                    .alignmentGuide(.bottom) { d in d[.bottom] }
                }
            }
            .if(constrainHeight) { view in
                view.frame(height: PVRowHeight, alignment: .bottom)
            }
            .onPreferenceChange(ArtworkDynamicWidthPreferenceKey.self) {
                textMaxWidth = $0
            }
        }
    }
}
