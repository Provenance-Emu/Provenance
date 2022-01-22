//
//  GameItemView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)

import Foundation
import SwiftUI

@available(iOS 13.0.0, *)
struct DynamicWidthGameItemView: SwiftUI.View {
    
    var artworkURL: String?
    @State var artwork: UIImage?
    var name: String
    var yearReleased: String?
    
    var thing = true
    
    @State private var textMaxWidth: CGFloat?
    
    var action: () -> Void
    
    var body: some SwiftUI.View {
        
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: ArtworkWidthPreferenceKey.self,
                                value: geometry.size.width
                            )
                        })
                } else {
                    Image("empty_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: ArtworkWidthPreferenceKey.self,
                                value: geometry.size.width
                            )
                        })
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    GameItemTitle(text: name)
                    if let yearReleased = yearReleased {
                        GameItemSubtitle(text: yearReleased)
                    }
                }
                .frame(width: textMaxWidth)
               
            }
            .frame(height: 150.0) // TODO: will likely want to make this platform-specific
            .onPreferenceChange(ArtworkWidthPreferenceKey.self) {
                textMaxWidth = $0
            }
            .onAppear {
                if let imageKey = artworkURL {
                    PVMediaCache.shareInstance().image(forKey: imageKey, completion: { _, image in
                        self.artwork = image
                    })
                }

            }
        }
    }
}



@available(iOS 13.0.0, *)
struct GameItemTitle: SwiftUI.View {
    var text: String
    var body: some SwiftUI.View {
        Text(text)
            .font(.headline)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 13.0.0, *)
struct GameItemSubtitle: SwiftUI.View {
    var text: String
    var body: some SwiftUI.View {
        Text(text)
            .font(.subheadline)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 13.0.0, *)
private extension DynamicWidthGameItemView {
    struct ArtworkWidthPreferenceKey: PreferenceKey {
        static let defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat,
                           nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
}

@available(iOS 13.0.0, *)
struct GameItemRow: SwiftUI.View {
    
    var body: some SwiftUI.View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                DynamicWidthGameItemView(
                    artworkURL: "",
                    artwork: UIImage(named: "prov_game_ff") ?? UIImage(),
                    name: "Final Fantasy",
                    yearReleased: "2019") {}
                DynamicWidthGameItemView(
                    artworkURL: "",
                    artwork: UIImage(named: "prov_game_ff3") ?? UIImage(),
                    name: "Final Fantasy III",
                    yearReleased: "2019") {}
                DynamicWidthGameItemView(
                    artworkURL: "",
                    artwork: UIImage(named: "prov_game_ff7s") ?? UIImage(),
                    name: "Final Fantasy III",
                    yearReleased: "2019") {}
                DynamicWidthGameItemView(
                    artworkURL: "",
                    artwork: UIImage(named: "prov_game_linktothepast") ?? UIImage(),
                    name: "The Legend of Zelda: A Link to The Past",
                    yearReleased: "2019") {}
                DynamicWidthGameItemView(
                    artworkURL: "",
                    artwork: UIImage(named: "prov_game_fft") ?? UIImage(),
                    name: "Final Fantasy Tactics Advance",
                    yearReleased: "2019") {}
            }
        }
    }
}

// previews

@available(iOS 13.0.0, *)
struct GameItemView_Previews: PreviewProvider {
    static var previews: some SwiftUI.View {
        if #available(iOS 15.0, *) {
            GameItemRow()
                .previewInterfaceOrientation(.landscapeLeft)
        } else {
            GameItemRow()
        }
    }
}

#endif
