//
//  UIImage+BoxArt.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/8/24.
//

import PVThemes
import PVLibrary

public extension UIImage {
    public class func image(withText text: String,
                            ratio: CGFloat = 1.0,
                            maxResolution: CGFloat = CGFloat(PVThumbnailMaxResolution),
                            foregroundColor: UIColor? = nil,
                            backgroundColor: UIColor? = nil) -> UIImage? {
        #if os(iOS)
            let backgroundColor: UIColor = backgroundColor ?? UIColor.systemGray5
        #else
            let backgroundColor: UIColor = backgroundColor ?? UIColor(white: 0.9, alpha: 0.9)
        #endif
        if text == "" {
            return UIImage.image(withSize: CGSize(width: CGFloat(maxResolution), height: CGFloat(maxResolution)), color: backgroundColor, text: NSAttributedString(string: ""))
        }
        // TODO: To be replaced with the correct system placeholder
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let foregroundColor: UIColor = foregroundColor ?? ThemeManager.shared.currentPalette.settingsCellText ?? UIColor.white

        #if os(iOS)
            let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0), NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.foregroundColor: foregroundColor])
        #else
            let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30.0), NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.foregroundColor: UIColor.gray])
        #endif

        let height: CGFloat = CGFloat(maxResolution)
        let ratio: CGFloat = ratio
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage
    }
}
