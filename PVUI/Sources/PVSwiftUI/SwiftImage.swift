//
//  SwiftImage.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes

#if os(macOS)
public typealias SwiftImage = NSImage
#else
public typealias SwiftImage = UIImage
#endif

extension SwiftImage {
    static func missingArtworkImage(gameTitle: String, ratio: CGFloat) -> SwiftImage {
        #if os(tvOS)
        let backgroundColor: UIColor = UIColor(white: 0.18, alpha: 1.0)
        #else
        let backgroundColor: UIColor = ThemeManager.shared.currentPalette.settingsCellBackground ?? .systemBackground
        #endif

        #if os(tvOS)
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 60.0),
            NSAttributedString.Key.foregroundColor: UIColor.gray])
        #else
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0),
            NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentPalette.settingsCellText ?? .placeholderText])
        #endif

        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = SwiftImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage ?? SwiftImage()
    }
}

// Add a new SwiftUI View for missing artwork
struct MissingArtworkView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let gameTitle: String
    let ratio: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(tvOS)
                Color(white: 0.18)
                #else
                themeManager.currentPalette.settingsCellBackground.map(Color.init) ?? Color(.systemBackground)
                #endif

                Text(gameTitle)
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .tv ? 60 : 30))
                    .foregroundColor(
                        themeManager.currentPalette.settingsCellText.map(Color.init) ?? Color(.placeholderText)
                    )
            }
            .frame(width: geometry.size.height * ratio, height: geometry.size.height)
        }
        .frame(height: CGFloat(PVThumbnailMaxResolution))
    }
}

// Extension to SwiftUI Image to create a missing artwork image
extension Image {
    static func missingArtwork(gameTitle: String, ratio: CGFloat) -> some View {
        MissingArtworkView(gameTitle: gameTitle, ratio: ratio)
    }
}
