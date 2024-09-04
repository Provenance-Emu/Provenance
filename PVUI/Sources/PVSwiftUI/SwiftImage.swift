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
        let backgroundColor: UIColor = ThemeManager.shared.currentTheme.settingsCellBackground ?? .systemBackground
        #endif

        #if os(tvOS)
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 60.0),
            NSAttributedString.Key.foregroundColor: UIColor.gray])
        #else
        let attributedText = NSAttributedString(string: gameTitle, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0),
            NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.settingsCellText ?? .placeholderText])
        #endif

        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = SwiftImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage ?? SwiftImage()
    }
}
