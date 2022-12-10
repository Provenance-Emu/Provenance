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

#if os(tvOS) || targetEnvironment(macCatalyst) || os(macOS)
    public let PVRowHeight: CGFloat = 300.0
#else
    public let PVRowHeight: CGFloat = 150.0
#endif

#if os(macOS)
public typealias SwiftImage = NSImage
#else
public typealias SwiftImage = UIImage
#endif

enum GameItemViewType {
    case cell
    case row

    var titleFontSize: CGFloat {
        switch self {
        case .cell:
            return 11
        case .row:
            return 15
        }
    }

    var subtitleFontSize: CGFloat {
        switch self {
        case .cell:
            return 8
        case .row:
            return 12
        }
    }
}

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
                self.artwork = image
            })
        }
    }
}

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

@available(iOS 14, tvOS 14, *)
struct GameItemThumbnail: SwiftUI.View {
    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio
    let radius: CGFloat = 3.0
    var body: some SwiftUI.View {
        ArtworkImageBaseView(artwork: artwork, gameTitle: gameTitle, boxartAspectRatio: boxartAspectRatio)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.currentTheme.gameLibraryText.swiftUIColor.opacity(0.5), lineWidth: 1))
            .background(GeometryReader { geometry in
                Color.clear.preference(
                    key: ArtworkDynamicWidthPreferenceKey.self,
                    value: geometry.size.width
                )
            })
            .cornerRadius(radius)
    }
}

@available(iOS 14, tvOS 14, *)
struct ArtworkImageBaseView: SwiftUI.View {

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio

    init(artwork: SwiftImage?, gameTitle: String, boxartAspectRatio: PVGameBoxArtAspectRatio) {
        self.artwork = artwork
        self.gameTitle = gameTitle
        self.boxartAspectRatio = boxartAspectRatio
    }

    var body: some SwiftUI.View {
        if let artwork = artwork {
            SwiftUI.Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            SwiftUI.Image(uiImage: UIImage.missingArtworkImage(gameTitle: gameTitle, ratio: boxartAspectRatio.rawValue))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemTitle: SwiftUI.View {
    var text: String
    var viewType: GameItemViewType

    var body: some SwiftUI.View {
        Text(text)
            .font(.system(size: viewType.titleFontSize))
            .foregroundColor(Color.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemSubtitle: SwiftUI.View {
    var text: String?
    var viewType: GameItemViewType

    var body: some SwiftUI.View {
        Text(text ?? "blank")
            .font(.system(size: viewType.subtitleFontSize))
            .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
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

extension SwiftImage {
    static func missingArtworkImage(gameTitle: String, ratio: CGFloat) -> SwiftImage {
        #if os(tvOS)
        let backgroundColor: UIColor = UIColor(white: 0.18, alpha: 1.0)
        #else
        let backgroundColor: UIColor = Theme.currentTheme.settingsCellBackground!
        #endif

        #if os(tvOS)
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 60.0),
            NSAttributedString.Key.foregroundColor: UIColor.gray])
        #else
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0),
            NSAttributedString.Key.foregroundColor: Theme.currentTheme.settingsCellText!])
        #endif

        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = SwiftImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage ?? SwiftImage()
    }
}
