//
//  UIImage+BoxArt.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/8/24.
//

import PVThemes
import PVLibrary
import PVSystems

public extension UIImage {

    /// Primary `ratio` when valid; otherwise ``PVGame/boxartAspectRatio``-style enum; then ``PVGame/boxArtAspectPlaceholder(systemIdentifier:regionName:)`` from persisted ids; finally square.
    private static func resolvedPlaceholderAspectRatio(
        ratio: CGFloat,
        consoleAspect: PVGameBoxArtAspectRatio?,
        systemIdentifierFallback: String?,
        regionNameFallback: String?
    ) -> CGFloat {
        if ratio.isFinite && ratio > 0 { return ratio }
        if let consoleAspect {
            return consoleAspect.rawValue
        }
        if let sid = systemIdentifierFallback, !sid.isEmpty {
            return PVGame.boxArtAspectPlaceholder(systemIdentifier: sid, regionName: regionNameFallback).rawValue
        }
        return PVGameBoxArtAspectRatio.square.rawValue
    }

    public class func image(withText text: String,
                            ratio: CGFloat = 1.0,
                            consoleAspect: PVGameBoxArtAspectRatio? = nil,
                            systemIdentifierFallback: String? = nil,
                            regionNameFallback: String? = nil,
                            maxResolution: CGFloat = CGFloat(PVThumbnailMaxResolution),
                            foregroundColor: UIColor? = nil,
                            backgroundColor: UIColor? = nil) -> UIImage? {
        #if os(iOS)
            let backgroundColor: UIColor = backgroundColor ?? UIColor.systemGray5
        #else
            let backgroundColor: UIColor = backgroundColor ?? UIColor(white: 0.9, alpha: 0.9)
        #endif
        // `UIGraphicsBeginImageContextWithOptions` asserts on non-finite or non-positive sizes; clamp bad callers / data.
        let safeMax = maxResolution.isFinite && maxResolution > 0 ? maxResolution : CGFloat(PVThumbnailMaxResolution)
        let safeRatio = resolvedPlaceholderAspectRatio(
            ratio: ratio,
            consoleAspect: consoleAspect,
            systemIdentifierFallback: systemIdentifierFallback,
            regionNameFallback: regionNameFallback
        )
        if text == "" {
            return UIImage.image(withSize: CGSize(width: safeMax, height: safeMax), color: backgroundColor, text: NSAttributedString(string: ""))
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

        let height: CGFloat = safeMax
        let width: CGFloat = height * safeRatio
        let size = CGSize(width: width, height: height)
        let missingArtworkImage = UIImage.image(withSize: size, color: backgroundColor, text: attributedText)
        return missingArtworkImage
    }
}
