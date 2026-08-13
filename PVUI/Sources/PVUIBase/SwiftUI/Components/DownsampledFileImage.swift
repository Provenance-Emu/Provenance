//
//  DownsampledFileImage.swift
//  PVUIBase
//
//  Shared, bounded loader for images read off disk and drawn small.
//
//  Screenshots and save-state images are captured at full device resolution
//  and stored without downscaling, so each one decodes to roughly 12 MB.
//  Views that draw them at 44-96pt were calling `UIImage(contentsOfFile:)`
//  directly — sometimes inside `body`, re-decoding on every evaluation — which
//  is what filled the "Image IO" VM region.
//
//  Use `FileThumbnailCache` (or the `DownsampledFileImage` view) instead of
//  `UIImage(contentsOfFile:)` anywhere the result is displayed at a known,
//  small size.
//

import SwiftUI
import PVMediaCache

#if canImport(UIKit)
import UIKit

/// Process-wide cache of downsampled on-disk images, keyed by path *and*
/// decode budget.
public final class FileThumbnailCache: @unchecked Sendable {

    public static let shared = FileThumbnailCache()

    private let cache = ImageMemoryCache(
        name: "FileThumbnailCache",
        totalCostLimit: ImageCacheBudget.saveStateThumbnails,
        countLimit: ImageCacheBudget.defaultCountLimit
    )

    private init() {}

    private func key(path: String, maxPixelSize: Int) -> String {
        "\(path)@\(maxPixelSize)"
    }

    /// Synchronous cache probe. Safe to call from `body`.
    public func cachedImage(atPath path: String, maxPixelSize: Int) -> UIImage? {
        cache.image(forKey: key(path: path, maxPixelSize: maxPixelSize))
    }

    /// Decode (off the calling actor) at `maxPixelSize` and cache the result.
    public func image(atPath path: String, maxPixelSize: Int) async -> UIImage? {
        let cacheKey = key(path: path, maxPixelSize: maxPixelSize)
        if let cached = cache.image(forKey: cacheKey) { return cached }

        let image = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                ArtworkDownsampler.image(atPath: path, maxPixelSize: maxPixelSize)
            }
        }.value

        if let image {
            cache.setImage(image, forKey: cacheKey)
        }
        return image
    }

    /// Pixel budget for drawing at `pointSize` on a display of `scale`.
    public static func maxPixelSize(for pointSize: CGSize, scale: CGFloat) -> Int {
        let longest = max(pointSize.width, pointSize.height) * scale
        return Int(max(longest, 1).rounded(.up))
    }
}

/// Draws an on-disk image downsampled to the frame it occupies.
///
/// Renders `placeholder` until the decode completes.
public struct DownsampledFileImage<Placeholder: View>: View {

    private let url: URL?
    private let pointSize: CGSize
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    public init(
        url: URL?,
        pointSize: CGSize,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.pointSize = pointSize
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }
        let budget = FileThumbnailCache.maxPixelSize(for: pointSize, scale: displayScale)
        if let cached = FileThumbnailCache.shared.cachedImage(atPath: url.path, maxPixelSize: budget) {
            image = cached
            return
        }
        image = await FileThumbnailCache.shared.image(atPath: url.path, maxPixelSize: budget)
    }
}
#endif
