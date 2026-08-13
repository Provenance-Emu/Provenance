//
//  ArtworkDownsampler.swift
//  PVMediaCache
//
//  Decode-time downsampling for cover art.
//
//  `UIImage(contentsOfFile:)` / `UIImage(data:)` decode at the source
//  resolution regardless of how small the image is drawn. A 1000x1500 cover
//  costs ~6 MB of "Image IO" memory even when it is displayed in a 110pt grid
//  cell. Multiply that by every live cell across every console tab and the app
//  hits the jetsam high-watermark limit.
//
//  `CGImageSourceCreateThumbnailAtIndex` decodes *directly* into the requested
//  pixel budget, so the full-resolution bitmap is never materialised. Resizing
//  after the fact (`UIImage.scaledToFit(_:)` and friends in
//  `UIImage+Scaling.swift`) still pays the full decode cost and therefore does
//  not solve the problem — prefer this type for anything loaded from disk.
//

import Foundation
import CoreGraphics
import ImageIO

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Named decode budgets for artwork, expressed as a maximum pixel size on the
/// image's longest edge.
///
/// Sizes are deliberately platform-specific: tvOS renders artwork in a 1x
/// coordinate space but displays it far larger, while iOS renders small cells
/// on 2x/3x displays.
public enum ArtworkDownsampleTarget: String, CaseIterable, Sendable {

    /// Library grid cells, shelf carousels and collection-view thumbnails.
    ///
    /// iOS: the tallest thumbnail on screen is a `PVRowHeight` (150pt) shelf
    /// cell, which needs 450px on a 3x display — 512 leaves headroom for
    /// focus/zoom scaling without decoding a full-resolution cover.
    ///
    /// tvOS: `PVRowHeight` is 300pt at 1x, and focused cells scale up, so 768
    /// covers the largest cell with room to spare.
    case thumbnail

    /// Full-screen / detail "hero" artwork (game info, artwork preview).
    ///
    /// Chosen to exceed the largest hero presentation on each platform
    /// (iPad 1024pt @2x = 2048px is clamped to 1536 on the long edge of a
    /// portrait cover, which is taller than it is wide; tvOS heroes are 1x).
    /// Typical cover art (~1000x1500) is *below* these budgets, so the
    /// downsample is a no-op for it and quality is unchanged — the cap only
    /// bites on pathologically large scans.
    case detail

    /// Maximum pixel size for the image's longest edge.
    public var maxPixelSize: Int {
        switch self {
        case .thumbnail:
            #if os(tvOS)
            return 768
            #else
            return 512
            #endif
        case .detail:
            #if os(tvOS)
            return 2048
            #else
            return 1536
            #endif
        }
    }
}

/// Loads images from disk or memory at a bounded pixel size.
public enum ArtworkDownsampler {

    #if canImport(UIKit)
    public typealias PlatformImage = UIImage
    #else
    public typealias PlatformImage = NSImage
    #endif

    /// Options passed to `CGImageSourceCreateWithURL` / `WithData`.
    ///
    /// `kCGImageSourceShouldCache: false` keeps the *source* from holding a
    /// full-resolution decode alongside the thumbnail we actually want.
    private static let sourceOptions: CFDictionary = {
        [kCGImageSourceShouldCache: false] as CFDictionary
    }()

    /// Build the thumbnail options dictionary for a given pixel budget.
    ///
    /// - `FromImageAlways`: ignore any (usually tiny) embedded EXIF thumbnail.
    ///   Note ImageIO never *upscales*, so a source smaller than
    ///   `maxPixelSize` comes back at its native size.
    /// - `WithTransform`: honour EXIF orientation so rotated art is not flipped.
    /// - `ShouldCacheImmediately`: decode on this (background) thread rather
    ///   than lazily on the main thread at first draw.
    private static func thumbnailOptions(maxPixelSize: Int) -> CFDictionary {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return options as CFDictionary
    }

    /// Wrap a `CGImage` in the platform image type at scale 1.
    ///
    /// Scale 1 means `image.size` is reported in *pixels*, matching what
    /// `UIImage(contentsOfFile:)` produces for non-`@2x`-suffixed files. Call
    /// sites that derive an aspect ratio from `.size` are therefore unaffected.
    private static func platformImage(from cgImage: CGImage) -> PlatformImage {
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    /// Decode an image file at no more than `maxPixelSize` on its longest edge.
    /// - Returns: `nil` if the file is missing or not a decodable image.
    public static func image(atPath path: String, maxPixelSize: Int) -> PlatformImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, sourceOptions),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: maxPixelSize))
        else { return nil }
        return platformImage(from: cgImage)
    }

    /// Decode an image file at the budget for `target`.
    public static func image(atPath path: String, target: ArtworkDownsampleTarget) -> PlatformImage? {
        image(atPath: path, maxPixelSize: target.maxPixelSize)
    }

    /// Decode an image file sized for a known on-screen presentation.
    ///
    /// - Parameters:
    ///   - pointSize: The size the image will be drawn at, in points.
    ///   - scale: Display scale — pass the view's `displayScale`.
    public static func image(atPath path: String, fitting pointSize: CGSize, scale: CGFloat) -> PlatformImage? {
        let maxDimension = max(pointSize.width, pointSize.height) * scale
        return image(atPath: path, maxPixelSize: Int(maxDimension.rounded(.up)))
    }

    /// Decode in-memory image data at no more than `maxPixelSize` on its longest edge.
    public static func image(data: Data, maxPixelSize: Int) -> PlatformImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: maxPixelSize))
        else { return nil }
        return platformImage(from: cgImage)
    }

    /// Decoded byte cost of an image, for use as an `NSCache` cost value.
    ///
    /// Uses the backing `CGImage`'s pixel dimensions when available so the cost
    /// reflects the real bitmap rather than a point-size approximation.
    public static func decodedByteCost(of image: PlatformImage) -> Int {
        let bytesPerPixel = 4
        #if canImport(UIKit)
        if let cgImage = image.cgImage {
            return cgImage.width * cgImage.height * bytesPerPixel
        }
        return Int(image.size.width * image.size.height) * bytesPerPixel
        #else
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage.width * cgImage.height * bytesPerPixel
        }
        return Int(image.size.width * image.size.height) * bytesPerPixel
        #endif
    }

    /// Cheap validity check that reads only the container header — it never
    /// allocates a pixel buffer, unlike `UIImage(data:)`.
    public static func isDecodableImage(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, sourceOptions),
              CGImageSourceGetType(source) != nil,
              CGImageSourceGetCount(source) > 0
        else { return false }
        return CGImageSourceGetStatus(source) == .statusComplete
    }
}
