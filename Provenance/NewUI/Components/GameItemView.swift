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
import PVLibrary

#if os(tvOS)
    public let PVRowHeight: CGFloat = 300.0
#else
    public let PVRowHeight: CGFloat = 150.0
#endif

@available(iOS 14, tvOS 14, *)
struct GameItemView: SwiftUI.View {
    
    @ObservedRealmObject var game: PVGame
    
    var constrainHeight: Bool = false
    @State var artwork: UIImage? = nil
    @State private var textMaxWidth: CGFloat = 150
    
    var action: () -> Void
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                GameItemThumbnail(artwork: artwork, gameTitle: game.title, boxartAspectRatio: game.boxartAspectRatio)
                VStack(alignment: .leading, spacing: 0) {
                    GameItemTitle(text: game.title)
                    GameItemSubtitle(text: game.publishDate)
                }
                .frame(width: textMaxWidth)
            }
            .if(constrainHeight) { view in
                view.frame(height: PVRowHeight)
            }
            .onPreferenceChange(ArtworkDynamicWidthPreferenceKey.self) {
                textMaxWidth = $0
            }
            .onAppear {
                PVMediaCache.shareInstance().image(forKey: game.trueArtworkURL, completion: { _, image in
                    self.artwork = image
                })
            }
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemThumbnail: SwiftUI.View {
    var artwork: UIImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    var body: some SwiftUI.View {
        ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            .background(GeometryReader { geometry in
                Color.clear.preference(
                    key: ArtworkDynamicWidthPreferenceKey.self,
                    value: geometry.size.width
                )
            })
            .cornerRadius(3.0)
    }
}

@available(iOS 14, tvOS 14, *)
struct ArtworkImageBaseView: SwiftUI.View {

    var artwork: UIImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio

    init(artwork: UIImage?, gameTitle: String, boxartAspectRatio: PVGameBoxArtAspectRatio) {
        self.artwork = artwork
        self.gameTitle = gameTitle
        self.boxartAspectRatio = boxartAspectRatio
    }
    
    func missingArtworkImage() -> UIImage {
    #if os(iOS)
        let backgroundColor: UIColor = Theme.currentTheme.settingsCellBackground!
    #else
        let backgroundColor: UIColor = UIColor(white: 0.18, alpha: 1.0)
    #endif
        
    #if os(iOS)
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0),
            NSAttributedString.Key.foregroundColor: Theme.currentTheme.settingsCellText!])
    #else
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 60.0),
            NSAttributedString.Key.foregroundColor: UIColor.gray])
    #endif
        
        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let ratio: CGFloat = boxartAspectRatio.rawValue
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage ?? UIImage()
    }
    
    var body: some SwiftUI.View {
        if let artwork = artwork {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(uiImage: missingArtworkImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemTitle: SwiftUI.View {
    var text: String
    var body: some SwiftUI.View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Color.white) // TOOD: theme colors
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemSubtitle: SwiftUI.View {
    var text: String?
    var body: some SwiftUI.View {
        Text(text ?? "blank")
            .font(.system(size: 8))
            .foregroundColor(Color.gray) // TOOD: theme colors
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(text != nil ? 1.0 : 0.0) // hide rather than not render so that cell keeps consistent height
    }
}

@available(iOS 14, tvOS 14, *)
struct ArtworkDynamicWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat,
                       nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#endif

extension PVGame {
    var trueArtworkURL: String {
        return (customArtworkURL.isEmpty) ? originalArtworkURL : customArtworkURL
    }
}
