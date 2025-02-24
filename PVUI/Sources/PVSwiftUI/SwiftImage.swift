//
//  SwiftImage.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes
import PVSettings
import Defaults

#if os(macOS)
public typealias SwiftImage = NSImage
#else
public typealias SwiftImage = UIImage
#endif

public extension Defaults.Keys {
    static let showFavorites = Key<Bool>("showFavorites", default: true)

    // Missing artwork style setting
    static let missingArtworkStyle = Key<RetroTestPattern>("missingArtworkStyle", default: .rainbowNoise)
}

/// RetroTestPattern styles for missing artwork
public enum RetroTestPattern: String, CaseIterable, Codable, Equatable, UserDefaultsRepresentable, Defaults.Serializable {
    case smpteColorBars
    case ntscTestPattern
    case retroGrid
    case rainbowNoise

    public var description: String {
        switch self {
        case .smpteColorBars:
            return "SMPTE Color Bars"
        case .ntscTestPattern:
            return "NTSC Test Pattern"
        case .retroGrid:
            return "Retro Grid"
        case .rainbowNoise:
            return "Rainbow Noise"
        }
    }

    public var subtitle: String {
        switch self {
        case .smpteColorBars:
            return "Classic TV calibration pattern"
        case .ntscTestPattern:
            return "Circular calibration pattern"
        case .retroGrid:
            return "Cyberpunk-style grid with gradient"
        case .rainbowNoise:
            return "Dynamic rainbow pattern with noise"
        }
    }
}

extension SwiftImage {
    /// Constants for styling
    private enum RetroStyle {
        static let colorBars: [UIColor] = [
            .init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0), // Gray
            .init(red: 0.75, green: 0.75, blue: 0.0, alpha: 1.0),  // Yellow
            .init(red: 0.0, green: 0.75, blue: 0.75, alpha: 1.0),  // Cyan
            .init(red: 0.0, green: 0.75, blue: 0.0, alpha: 1.0),   // Green
            .init(red: 0.75, green: 0.0, blue: 0.75, alpha: 1.0),  // Magenta
            .init(red: 0.75, green: 0.0, blue: 0.0, alpha: 1.0),   // Red
            .init(red: 0.0, green: 0.0, blue: 0.75, alpha: 1.0)    // Blue
        ]

        static let gridColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.3)
        static let gridLineWidth: CGFloat = 1.0
        static let gridSpacing: CGFloat = 20.0

        static let noiseIntensity: CGFloat = 0.1
        static let scanlineSpacing: CGFloat = 2.0
        static let scanlineOpacity: CGFloat = 0.2

        /// Font styling
        static let titleFont: UIFont = {
            // Try to get the preferred retro font, fall back to system monospaced if not available
            let fontSize = 24.0
            let fontNames = [
                "PressStart2P-Regular",     // Classic 8-bit style
                "Monaco",                   // Clean monospaced
                "Courier",                  // Another good monospaced option
                "SF Mono",                  // Apple's monospaced font
                "Menlo"                     // Another good monospaced option
            ]

            // Try each font in order
            for fontName in fontNames {
                if let font = UIFont(name: fontName, size: fontSize) {
                    return font
                }
            }

            // Fall back to system monospaced
            return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        }()

        static let titleShadowOffset = CGSize(width: 2, height: 2)
        static let titleShadowBlur: CGFloat = 3.0
        static let titleShadowColor = UIColor.black.withAlphaComponent(0.5)

        // Text container styling
        static let textContainerPadding: CGFloat = 20.0
        static let textBackgroundOpacity: CGFloat = 0.85
        static let textGradientLocations: [CGFloat] = [0.0, 0.15, 0.85, 1.0]

        // Text layout
        static let maxLinesOfText: Int = 3
        static let lineSpacing: CGFloat = 4.0
        static let defaultMinFontSize: CGFloat = 12.0
        static let maxFontSize: CGFloat = 24.0
    }

    private static func calculateOptimalFontSize(
        for text: String,
        in rect: CGRect,
        with font: UIFont,
        minFontSize: CGFloat
    ) -> (UIFont, Int) {
        let maxWidth = rect.width - (RetroStyle.textContainerPadding * 2)
        let maxHeight = rect.height - (RetroStyle.textContainerPadding * 2)

        // Start with max font size and reduce until it fits
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

            // Calculate number of lines
            lineCount = Int(ceil(textRect.height / (finalFont.lineHeight + RetroStyle.lineSpacing)))

            // Check if text fits within constraints
            if textRect.width <= maxWidth &&
               textRect.height <= maxHeight &&
               lineCount <= RetroStyle.maxLinesOfText {
                break
            }

            currentFontSize -= 2
        }

        // Ensure we don't go below minimum font size
        if currentFontSize < minFontSize {
            finalFont = font.withSize(minFontSize)
        }

        return (finalFont, lineCount)
    }

    static func missingArtworkImage(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = .smpteColorBars,
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) -> SwiftImage {
        let height: CGFloat = CGFloat(PVThumbnailMaxResolution)
        let width: CGFloat = height * ratio
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return SwiftImage() }

        // Draw background pattern
        switch pattern {
        case .smpteColorBars:
            drawSMPTEColorBars(in: context, size: size)
        case .ntscTestPattern:
            drawNTSCTestPattern(in: context, size: size)
        case .retroGrid:
            drawRetroGrid(in: context, size: size)
        case .rainbowNoise:
            drawRainbowNoise(in: context, size: size)
        }

        // Add scanlines
        drawScanlines(in: context, size: size)

        // Draw text container with gradient edges
        let containerHeight = size.height * 0.25 // Increased height for larger font
        let textRect = CGRect(x: 0,
                            y: size.height * 0.4,
                            width: size.width,
                            height: containerHeight)

        // Draw darkened background first
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.fill(textRect)

        // Create gradient for faded edges with more opacity
        let gradientColors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(RetroStyle.textBackgroundOpacity).cgColor,
            UIColor.black.withAlphaComponent(RetroStyle.textBackgroundOpacity).cgColor,
            UIColor.clear.cgColor
        ]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors as CFArray,
            locations: RetroStyle.textGradientLocations
        ) else { return SwiftImage() }

        // Draw gradient background
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

        // Calculate optimal font size and line count
        let (font, lineCount) = calculateOptimalFontSize(
            for: gameTitle,
            in: textRect,
            with: RetroStyle.titleFont,
            minFontSize: minFontSize
        )

        // Create paragraph style for multi-line text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = RetroStyle.lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Draw text with shadow
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0,
            .paragraphStyle: paragraphStyle
        ]

        let shadowAttributes = titleAttributes.merging([
            .foregroundColor: UIColor.black.withAlphaComponent(0.5)
        ]) { $1 }

        let attributedTitle = NSAttributedString(string: gameTitle, attributes: titleAttributes)
        let shadowTitle = NSAttributedString(string: gameTitle, attributes: shadowAttributes)

        // Calculate text bounds
        let textSize = attributedTitle.boundingRect(
            with: CGSize(width: textRect.width - (RetroStyle.textContainerPadding * 2), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size

        // Center text vertically and horizontally
        let textX = textRect.minX + RetroStyle.textContainerPadding
        let textY = textRect.minY + (textRect.height - textSize.height) / 2
        let finalTextRect = CGRect(
            x: textX,
            y: textY,
            width: textRect.width - (RetroStyle.textContainerPadding * 2),
            height: textSize.height
        )

        // Draw shadow
        let shadowRect = finalTextRect.offsetBy(
            dx: RetroStyle.titleShadowOffset.width,
            dy: RetroStyle.titleShadowOffset.height
        )
        shadowTitle.draw(in: shadowRect)

        // Draw main text
        attributedTitle.draw(in: finalTextRect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image ?? SwiftImage()
    }

    private static func drawSMPTEColorBars(in context: CGContext, size: CGSize) {
        let barWidth = size.width / CGFloat(RetroStyle.colorBars.count)

        for (index, color) in RetroStyle.colorBars.enumerated() {
            let rect = CGRect(x: CGFloat(index) * barWidth,
                            y: 0,
                            width: barWidth,
                            height: size.height)
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
    }

    private static func drawNTSCTestPattern(in context: CGContext, size: CGSize) {
        // Draw circular pattern
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

        // Draw crosshair
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)

        // Vertical line
        context.move(to: CGPoint(x: center.x, y: 0))
        context.addLine(to: CGPoint(x: center.x, y: size.height))

        // Horizontal line
        context.move(to: CGPoint(x: 0, y: center.y))
        context.addLine(to: CGPoint(x: size.width, y: center.y))

        context.strokePath()
    }

    private static func drawRetroGrid(in context: CGContext, size: CGSize) {
        context.setStrokeColor(RetroStyle.gridColor.cgColor)
        context.setLineWidth(RetroStyle.gridLineWidth)

        // Draw vertical lines
        for x in stride(from: 0, to: size.width, by: RetroStyle.gridSpacing) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: size.height))
        }

        // Draw horizontal lines
        for y in stride(from: 0, to: size.height, by: RetroStyle.gridSpacing) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.strokePath()

        // Add gradient background
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor.purple.cgColor, UIColor.blue.cgColor] as CFArray,
                                locations: [0, 1])!

        context.drawLinearGradient(gradient,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: size.width, y: size.height),
                                 options: [])
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

        // Add scanline overlay
        context.setFillColor(UIColor.black.withAlphaComponent(RetroStyle.scanlineOpacity).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
    }
}

// Add a new SwiftUI View for missing artwork with pattern selection
struct MissingArtworkView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let gameTitle: String
    let ratio: CGFloat
    let pattern: RetroTestPattern

    init(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern = .smpteColorBars) {
        self.gameTitle = gameTitle
        self.ratio = ratio
        self.pattern = pattern
    }

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: SwiftImage.missingArtworkImage(
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern
            ))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.height * ratio, height: geometry.size.height)
        }
        .frame(height: CGFloat(PVThumbnailMaxResolution))
    }
}

// Extension to SwiftUI Image to create a missing artwork image
extension Image {
    static func missingArtwork(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = .smpteColorBars
    ) -> some View {
        MissingArtworkView(gameTitle: gameTitle, ratio: ratio, pattern: pattern)
    }
}
