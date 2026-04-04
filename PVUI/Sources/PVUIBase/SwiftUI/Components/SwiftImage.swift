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
import Foundation

#if os(macOS)
public typealias SwiftImage = NSImage
#else
public typealias SwiftImage = UIImage
#endif

/// Manages both memory and disk caching for missing artwork images
public class MissingArtworkCacheManager {
    /// Shared instance for the cache manager
    public static let shared = MissingArtworkCacheManager()

    /// In-memory cache for quick access
    private let memoryCache = NSCache<NSString, SwiftImage>()

    /// URL for the disk cache directory
    private let diskCacheURL: URL

    /// Maximum number of disk-cached images to keep - increased for better hit rates
    private let maxDiskCachedImages = 500

    private init() {
        // Set up memory cache limits - increased for better hit rates
        memoryCache.countLimit = 200

        // Create disk cache directory in the caches folder
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cachesDirectory.appendingPathComponent("MissingArtworkCache", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: diskCacheURL.path) {
            try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    /// Generate a cache key for missing artwork images
    private func cacheKey(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) -> String {
        let themeSuffix = isDarkTheme ? "dark" : "light"
        return "\(gameTitle)_\(ratio)_\(pattern.rawValue)_\(minFontSize)_\(themeSuffix)"
    }

    /// Get the disk URL for a cache key
    private func diskURL(for key: String) -> URL {
        // Create a safe filename from the key
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
                         .replacingOccurrences(of: ":", with: "_")
                         .replacingOccurrences(of: " ", with: "_")
        return diskCacheURL.appendingPathComponent("\(safeKey).png")
    }

    /// Get an image from cache (memory or disk)
    public func getImage(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) -> SwiftImage? {
        let key = cacheKey(gameTitle: gameTitle, ratio: ratio, pattern: pattern, minFontSize: minFontSize, isDarkTheme: isDarkTheme) as NSString

        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key) {
            return cachedImage
        }

        // If not in memory, check disk cache
        let fileURL = diskURL(for: key as String)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            /// Use background queue for disk reads to avoid blocking main thread
            if let data = try? Data(contentsOf: fileURL),
               let image = SwiftImage(data: data) {
                // Store in memory cache for faster access next time
                memoryCache.setObject(image, forKey: key)
                return image
            }
        }

        return nil
    }

    /// Store an image in both memory and disk cache
    public func storeImage(_ image: SwiftImage, gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern, minFontSize: CGFloat, isDarkTheme: Bool) {
        let key = cacheKey(gameTitle: gameTitle, ratio: ratio, pattern: pattern, minFontSize: minFontSize, isDarkTheme: isDarkTheme) as NSString

        // Store in memory cache
        memoryCache.setObject(image, forKey: key)

        // Store in disk cache — capture image strongly so it survives until write completes
        let fileURL = diskURL(for: key as String)
        Task.detached {
            if let data = image.pngData() {
                try? data.write(to: fileURL)
            }
        }

        // Clean up disk cache if needed (debounced, off main thread)
        scheduleDiskCacheCleanup()
    }

    /// Pending cleanup work item — coalesces rapid storeImage calls.
    private static var cleanupWorkItem: DispatchWorkItem?
    /// Protects `cleanupWorkItem` from concurrent access across threads.
    private static let cleanupLock = NSLock()

    /// Schedules a debounced disk cache cleanup on a background queue.
    /// Multiple storeImage calls within 2 seconds share one cleanup pass.
    private func scheduleDiskCacheCleanup() {
        let cacheURL = diskCacheURL
        let limit = maxDiskCachedImages
        Self.cleanupLock.lock()
        Self.cleanupWorkItem?.cancel()
        let work = DispatchWorkItem {
            Self.performDiskCacheCleanup(cacheURL: cacheURL, limit: limit)
        }
        Self.cleanupWorkItem = work
        Self.cleanupLock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Performs the actual disk cache cleanup. Runs on a background queue.
    private static func performDiskCacheCleanup(cacheURL: URL, limit: Int) {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        guard fileURLs.count > limit else { return }

        let sortedURLs = (try? fileURLs.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return date1 < date2
        }) ?? []

        let filesToRemove = sortedURLs.prefix(fileURLs.count - limit)
        for fileURL in filesToRemove {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Clear all caches (memory and disk)
    public func clearAllCaches() {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: diskCacheURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Error clearing disk cache: \(error)")
        }
    }

    /// Preload images for multiple games in background
    public func preloadImages(
        games: [(title: String, ratio: CGFloat)],
        pattern: RetroTestPattern,
        minFontSize: CGFloat = 12.0,
        isDarkTheme: Bool
    ) {
        Task.detached(priority: .utility) {
            for game in games {
                /// Check if already cached
                if self.getImage(
                    gameTitle: game.title,
                    ratio: game.ratio,
                    pattern: pattern,
                    minFontSize: minFontSize,
                    isDarkTheme: isDarkTheme
                ) != nil {
                    continue
                }

                /// Generate and cache
                let image = SwiftImage.missingArtworkImage(
                    gameTitle: game.title,
                    ratio: game.ratio,
                    pattern: pattern,
                    minFontSize: minFontSize
                )

                self.storeImage(
                    image,
                    gameTitle: game.title,
                    ratio: game.ratio,
                    pattern: pattern,
                    minFontSize: minFontSize,
                    isDarkTheme: isDarkTheme
                )
            }
        }
    }
}

// Add a cache for missing artwork images
private let missingArtworkCache = NSCache<NSString, SwiftImage>()

public extension Defaults.Keys {
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
    public enum RetroStyle {
        public static let colorBars: [UIColor] = [
            .init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0), // Gray
            .init(red: 0.75, green: 0.75, blue: 0.0, alpha: 1.0),  // Yellow
            .init(red: 0.0, green: 0.75, blue: 0.75, alpha: 1.0),  // Cyan
            .init(red: 0.0, green: 0.75, blue: 0.0, alpha: 1.0),   // Green
            .init(red: 0.75, green: 0.0, blue: 0.75, alpha: 1.0),  // Magenta
            .init(red: 0.75, green: 0.0, blue: 0.0, alpha: 1.0),   // Red
            .init(red: 0.0, green: 0.0, blue: 0.75, alpha: 1.0)    // Blue
        ]

        public static let gridColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.3)
        public static let gridLineWidth: CGFloat = 1.0
        public static let gridSpacing: CGFloat = 20.0

        public static let noiseIntensity: CGFloat = 0.1
        public static let scanlineSpacing: CGFloat = 2.0
        public static let scanlineOpacity: CGFloat = 0.2

        /// Font styling
        public static let titleFont: UIFont = {
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

        public static let titleShadowOffset = CGSize(width: 2, height: 2)
        public static let titleShadowBlur: CGFloat = 3.0
        public static let titleShadowColor = UIColor.black.withAlphaComponent(0.5)

        // Text container styling
        public static let textContainerPadding: CGFloat = 20.0
        public static let textBackgroundOpacity: CGFloat = 0.85
        public static let textGradientLocations: [CGFloat] = [0.0, 0.15, 0.85, 1.0]

        // Text layout
        public static let maxLinesOfText: Int = 3
        public static let lineSpacing: CGFloat = 4.0
        public static let defaultMinFontSize: CGFloat = 12.0
        public static let maxFontSize: CGFloat = 24.0
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

    /// Synchronous generator (kept for compatibility; may run on caller's thread).
    public static func missingArtworkImage(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = Defaults[.missingArtworkStyle],
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) -> SwiftImage {
        // Get current theme to determine if we should use light or dark colors
        let isDarkTheme = ThemeManager.shared.currentPalette.dark

        // Try to get the image from the cache manager first
        if let cachedImage = MissingArtworkCacheManager.shared.getImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            minFontSize: minFontSize,
            isDarkTheme: isDarkTheme
        ) {
            return cachedImage
        }

        // Generate the image if not in cache
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

        // Choose colors based on theme
        let backgroundColor: UIColor
        let textColor: UIColor
        let shadowColor: UIColor

        if isDarkTheme {
            // Dark theme: dark background with white text
            backgroundColor = UIColor.black
            textColor = UIColor.white
            shadowColor = UIColor.black
        } else {
            // Light theme: light background with dark text
            backgroundColor = UIColor.white
            textColor = UIColor.black
            shadowColor = UIColor.white
        }

        // Draw background first
        context.setFillColor(backgroundColor.withAlphaComponent(0.4).cgColor)
        context.fill(textRect)

        // Create gradient for faded edges with more opacity
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

        // Store in cache
        if let finalImage = image {
            // Store in both memory and disk cache
            MissingArtworkCacheManager.shared.storeImage(
                finalImage,
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern,
                minFontSize: minFontSize,
                isDarkTheme: isDarkTheme
            )
            return finalImage
        }

        return SwiftImage()
    }

    /// Async, worker-thread generation with caching.
    /// Note: Callers should check cache synchronously first for instant display
    public static func missingArtworkImageAsync(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = Defaults[.missingArtworkStyle],
        minFontSize: CGFloat = RetroStyle.defaultMinFontSize
    ) async -> SwiftImage {
        let isDarkTheme = ThemeManager.shared.currentPalette.dark

        /// Double-check cache in case it was populated between view check and async call
        if let cached = MissingArtworkCacheManager.shared.getImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern,
            minFontSize: minFontSize,
            isDarkTheme: isDarkTheme
        ) {
            return cached
        }

        return await Task.detached(priority: .utility) {
            /// Generate image off main thread
            let image = SwiftImage.missingArtworkImage(
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern,
                minFontSize: minFontSize
            )

            /// Store in cache
            MissingArtworkCacheManager.shared.storeImage(
                image,
                gameTitle: gameTitle,
                ratio: ratio,
                pattern: pattern,
                minFontSize: minFontSize,
                isDarkTheme: isDarkTheme
            )
            return image
        }.value
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
public struct MissingArtworkView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let gameTitle: String
    let ratio: CGFloat
    let pattern: RetroTestPattern

    public init(gameTitle: String, ratio: CGFloat, pattern: RetroTestPattern = .smpteColorBars) {
        self.gameTitle = gameTitle
        self.ratio = ratio
        self.pattern = pattern
    }

    public var body: some View {
        Image(uiImage: SwiftImage.missingArtworkImage(
            gameTitle: gameTitle,
            ratio: ratio,
            pattern: pattern
        ))
        .resizable()
        .aspectRatio(ratio, contentMode: .fit)
        .frame(height: CGFloat(PVThumbnailMaxResolution))
    }
}

// Extension to SwiftUI Image to create a missing artwork image
public extension Image {
    @ViewBuilder
    static func missingArtwork(
        gameTitle: String,
        ratio: CGFloat,
        pattern: RetroTestPattern = .smpteColorBars
    ) -> some View {
        MissingArtworkView(gameTitle: gameTitle, ratio: ratio, pattern: pattern)
    }
}
