//
//  MissingArtworkGenerator.swift
//  PVMediaCache
//
//  Created to share the retrowave "missing artwork" placeholder across PVUIBase
//  and lightweight app extensions (e.g. TopShelfv2) without requiring the
//  PVThemes / PVSettings / Defaults dependency surface of PVUIBase.
//

import Foundation
import PVHashing
import PVFileSystem
import PVLogging

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Visual style options for generated "missing artwork" placeholders.
public enum RetroTestPattern: String, CaseIterable, Codable, Equatable, Sendable {
    case smpteColorBars
    case ntscTestPattern
    case retroGrid
    case rainbowNoise

    public var description: String {
        switch self {
        case .smpteColorBars:    return "SMPTE Color Bars"
        case .ntscTestPattern:   return "NTSC Test Pattern"
        case .retroGrid:         return "Retro Grid"
        case .rainbowNoise:      return "Rainbow Noise"
        }
    }

    public var subtitle: String {
        switch self {
        case .smpteColorBars:    return "Classic TV calibration pattern"
        case .ntscTestPattern:   return "Circular calibration pattern"
        case .retroGrid:         return "Cyberpunk-style grid with gradient"
        case .rainbowNoise:      return "Dynamic rainbow pattern with noise"
        }
    }
}

#if canImport(UIKit)

/// Shared styling constants for the retrowave placeholder generator.
public enum RetroStyle {
    public static let colorBars: [UIColor] = [
        .init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0),
        .init(red: 0.75, green: 0.75, blue: 0.0,  alpha: 1.0),
        .init(red: 0.0,  green: 0.75, blue: 0.75, alpha: 1.0),
        .init(red: 0.0,  green: 0.75, blue: 0.0,  alpha: 1.0),
        .init(red: 0.75, green: 0.0,  blue: 0.75, alpha: 1.0),
        .init(red: 0.75, green: 0.0,  blue: 0.0,  alpha: 1.0),
        .init(red: 0.0,  green: 0.0,  blue: 0.75, alpha: 1.0)
    ]

    public static let gridColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.3)
    public static let gridLineWidth: CGFloat = 1.0
    public static let gridSpacing: CGFloat = 20.0

    public static let noiseIntensity: CGFloat = 0.1
    public static let scanlineSpacing: CGFloat = 2.0
    public static let scanlineOpacity: CGFloat = 0.2

    /// Title font with graceful fallback chain. The classic "PressStart2P-Regular"
    /// is preferred but may be unavailable in extension targets that don't bundle it.
    public static let titleFont: UIFont = {
        let fontSize: CGFloat = 24.0
        let fontNames = [
            "PressStart2P-Regular",
            "Monaco",
            "Courier",
            "SF Mono",
            "Menlo"
        ]

        for fontName in fontNames {
            if let font = UIFont(name: fontName, size: fontSize) {
                return font
            }
        }
        return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    }()

    public static let titleShadowOffset = CGSize(width: 2, height: 2)
    public static let titleShadowBlur: CGFloat = 3.0
    public static let titleShadowColor = UIColor.black.withAlphaComponent(0.5)

    public static let textContainerPadding: CGFloat = 20.0
    public static let textBackgroundOpacity: CGFloat = 0.85
    public static let textGradientLocations: [CGFloat] = [0.0, 0.15, 0.85, 1.0]

    public static let maxLinesOfText: Int = 3
    public static let lineSpacing: CGFloat = 4.0
    public static let defaultMinFontSize: CGFloat = 12.0
    public static let maxFontSize: CGFloat = 24.0
}

/// Generates the shared "missing artwork" placeholder. Pure UIKit drawing with
/// no theme or user-defaults coupling so it can be used from app extensions.
public enum MissingArtworkGenerator {

    /// Render a placeholder image. This is a pure function — callers are
    /// responsible for any in-memory caching they wish to layer on top.
    public static func generate(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern,
        isDarkTheme: Bool,
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) -> UIImage {
        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let width: CGFloat = max(1, height * ratio)
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }

        switch pattern {
        case .smpteColorBars:  drawSMPTEColorBars(in: context, size: size)
        case .ntscTestPattern: drawNTSCTestPattern(in: context, size: size)
        case .retroGrid:       drawRetroGrid(in: context, size: size)
        case .rainbowNoise:    drawRainbowNoise(in: context, size: size)
        }

        drawScanlines(in: context, size: size)

        let containerHeight = size.height * 0.25
        let textRect = CGRect(x: 0,
                              y: size.height * 0.4,
                              width: size.width,
                              height: containerHeight)

        let backgroundColor: UIColor
        let textColor: UIColor
        let shadowColor: UIColor

        if isDarkTheme {
            backgroundColor = UIColor.black
            textColor = UIColor.white
            shadowColor = UIColor.black
        } else {
            backgroundColor = UIColor.white
            textColor = UIColor.black
            shadowColor = UIColor.white
        }

        context.setFillColor(backgroundColor.withAlphaComponent(0.4).cgColor)
        context.fill(textRect)

        let gradientColors = [
            UIColor.clear.cgColor,
            backgroundColor.withAlphaComponent(RetroStyle.textBackgroundOpacity).cgColor,
            backgroundColor.withAlphaComponent(RetroStyle.textBackgroundOpacity).cgColor,
            UIColor.clear.cgColor
        ]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors as CFArray,
            locations: RetroStyle.textGradientLocations
        ) else { return UIImage() }

        context.saveGState()
        let cornerRadius: CGFloat = 12
        let path = UIBezierPath(roundedRect: textRect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.clip()

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: textRect.minY),
            end: CGPoint(x: size.width, y: textRect.minY),
            options: []
        )
        context.restoreGState()

        let (font, _) = calculateOptimalFontSize(
            for: gameTitle,
            in: textRect,
            with: RetroStyle.titleFont,
            minFontSize: minFontSize
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = RetroStyle.lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .strokeColor: isDarkTheme ? UIColor.black : UIColor.white,
            .strokeWidth: -2.0,
            .paragraphStyle: paragraphStyle
        ]

        let shadowAttributes = titleAttributes.merging([
            .foregroundColor: shadowColor.withAlphaComponent(0.5)
        ]) { $1 }

        let attributedTitle = NSAttributedString(string: gameTitle, attributes: titleAttributes)
        let shadowTitle = NSAttributedString(string: gameTitle, attributes: shadowAttributes)

        let textSize = attributedTitle.boundingRect(
            with: CGSize(width: textRect.width - (RetroStyle.textContainerPadding * 2),
                         height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        let textX = textRect.minX + RetroStyle.textContainerPadding
        let textY = textRect.minY + (textRect.height - textSize.height) / 2
        let finalTextRect = CGRect(
            x: textX,
            y: textY,
            width: textRect.width - (RetroStyle.textContainerPadding * 2),
            height: textSize.height
        )

        let shadowRect = finalTextRect.offsetBy(
            dx: RetroStyle.titleShadowOffset.width,
            dy: RetroStyle.titleShadowOffset.height
        )
        shadowTitle.draw(in: shadowRect)
        attributedTitle.draw(in: finalTextRect)

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    /// Returns a stable file URL for a generated placeholder inside the shared
    /// app-group `Caches/PVCache/{md5Hash}.png` directory. Generates and writes
    /// the PNG on first call. Safe to invoke from app extensions.
    @discardableResult
    public static func cachedPlaceholderURL(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern,
        isDarkTheme: Bool,
        appGroupIdentifier: String = PVAppGroupId,
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) -> URL? {
        guard !appGroupIdentifier.isEmpty,
              let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            ELOG("MissingArtworkGenerator: app group container unavailable for id \(appGroupIdentifier)")
            return nil
        }

        let key = "placeholder_\(gameTitle)_\(ratio)_\(pattern.rawValue)_\(isDarkTheme ? "dark" : "light")"
        let keyHash = key.md5Hash

        let cachesDir = groupURL.appendingPathComponent("Caches/PVCache", isDirectory: true)
        let fileURL = cachesDir.appendingPathComponent("\(keyHash).png")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let image = generate(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            isDarkTheme: isDarkTheme,
            minFontSize: minFontSize
        )

        guard let data = image.pngData() else {
            ELOG("MissingArtworkGenerator: failed to encode PNG for \(gameTitle)")
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            ELOG("MissingArtworkGenerator: failed writing placeholder to \(fileURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Drawing helpers

    private static func calculateOptimalFontSize(
        for text: String,
        in rect: CGRect,
        with font: UIFont,
        minFontSize: CGFloat
    ) -> (UIFont, Int) {
        let maxWidth = rect.width - (RetroStyle.textContainerPadding * 2)
        let maxHeight = rect.height - (RetroStyle.textContainerPadding * 2)

        var currentFontSize = RetroStyle.maxFontSize
        var finalFont = font.withSize(currentFontSize)
        var lineCount = 1

        while currentFontSize >= minFontSize {
            finalFont = font.withSize(currentFontSize)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = RetroStyle.lineSpacing
            paragraphStyle.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: finalFont,
                .paragraphStyle: paragraphStyle
            ]

            let textRect = text.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            lineCount = Int(ceil(textRect.height / (finalFont.lineHeight + RetroStyle.lineSpacing)))

            if textRect.width <= maxWidth &&
               textRect.height <= maxHeight &&
               lineCount <= RetroStyle.maxLinesOfText {
                break
            }

            currentFontSize -= 2
        }

        if currentFontSize < minFontSize {
            finalFont = font.withSize(minFontSize)
        }

        return (finalFont, lineCount)
    }

    private static func drawSMPTEColorBars(in context: CGContext, size: CGSize) {
        let barWidth = size.width / CGFloat(RetroStyle.colorBars.count)
        for (index, color) in RetroStyle.colorBars.enumerated() {
            let rect = CGRect(x: CGFloat(index) * barWidth, y: 0, width: barWidth, height: size.height)
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
    }

    private static func drawNTSCTestPattern(in context: CGContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        for i in 0...10 {
            let radius = maxRadius * CGFloat(10 - i) / 10
            let circle = UIBezierPath(arcCenter: center,
                                      radius: radius,
                                      startAngle: 0,
                                      endAngle: .pi * 2,
                                      clockwise: true)

            context.setStrokeColor(UIColor(
                hue: CGFloat(i) / 10,
                saturation: 0.8,
                brightness: 0.8,
                alpha: 1.0
            ).cgColor)
            context.setLineWidth(3.0)
            context.addPath(circle.cgPath)
            context.strokePath()
        }

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: center.x, y: 0))
        context.addLine(to: CGPoint(x: center.x, y: size.height))
        context.move(to: CGPoint(x: 0, y: center.y))
        context.addLine(to: CGPoint(x: size.width, y: center.y))
        context.strokePath()
    }

    private static func drawRetroGrid(in context: CGContext, size: CGSize) {
        context.setStrokeColor(RetroStyle.gridColor.cgColor)
        context.setLineWidth(RetroStyle.gridLineWidth)

        for x in stride(from: 0, to: size.width, by: RetroStyle.gridSpacing) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: size.height))
        }

        for y in stride(from: 0, to: size.height, by: RetroStyle.gridSpacing) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.strokePath()

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [UIColor.purple.cgColor, UIColor.blue.cgColor] as CFArray,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
        }
    }

    private static func drawRainbowNoise(in context: CGContext, size: CGSize) {
        let pixelSize: CGFloat = 4.0
        let cols = Int(size.width / pixelSize)
        let rows = Int(size.height / pixelSize)

        for row in 0..<rows {
            for col in 0..<cols {
                let hue = CGFloat(col) / CGFloat(cols)
                let brightness = 0.6 + CGFloat.random(in: -RetroStyle.noiseIntensity...RetroStyle.noiseIntensity)
                let color = UIColor(hue: hue,
                                    saturation: 0.8,
                                    brightness: brightness,
                                    alpha: 1.0)

                let rect = CGRect(x: CGFloat(col) * pixelSize,
                                  y: CGFloat(row) * pixelSize,
                                  width: pixelSize,
                                  height: pixelSize)

                context.setFillColor(color.cgColor)
                context.fill(rect)
            }
        }
    }

    private static func drawScanlines(in context: CGContext, size: CGSize) {
        context.setFillColor(UIColor.black.cgColor)
        for y in stride(from: 0, to: size.height, by: RetroStyle.scanlineSpacing) {
            let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
            context.fill(rect)
        }
        context.setFillColor(UIColor.black.withAlphaComponent(RetroStyle.scanlineOpacity).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
    }
}

#endif
