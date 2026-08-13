//
//  ImageMemoryCache.swift
//  PVMediaCache
//
//  A bounded, memory-pressure-aware in-memory image cache.
//
//  Several caches in the app were plain `Dictionary<String, UIImage>` values
//  capped only by entry count, or `NSCache`s with a `countLimit` but no
//  `totalCostLimit` and no cost supplied at `setObject` time. Both forms let
//  resident decoded-image memory grow without any byte budget, and — unlike
//  `NSCache` used correctly — a `Dictionary` is never purged under memory
//  pressure.
//
//  Use this type instead of hand-rolling either.
//

import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// An `NSCache` of images with a real byte budget and automatic purge on
/// memory warnings.
///
/// Costs are the *decoded* byte size of each image (see
/// `ArtworkDownsampler.decodedByteCost(of:)`), so `totalCostLimit` corresponds
/// to actual resident memory rather than an entry count.
public final class ImageMemoryCache: @unchecked Sendable {

    #if canImport(UIKit)
    public typealias PlatformImage = UIImage
    #else
    public typealias PlatformImage = NSImage
    #endif

    private let cache = NSCache<NSString, PlatformImage>()
    private var memoryWarningObserver: NSObjectProtocol?

    /// - Parameters:
    ///   - name: Debug label, also used as the `NSCache` name.
    ///   - totalCostLimit: Maximum decoded bytes retained.
    ///   - countLimit: Maximum entries. A secondary guard — `totalCostLimit` is
    ///     the one that actually bounds memory.
    public init(name: String, totalCostLimit: Int, countLimit: Int) {
        cache.name = name
        cache.totalCostLimit = totalCostLimit
        cache.countLimit = countLimit
        observeMemoryPressure()
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    /// `NSCache` already evicts under pressure, but only opportunistically and
    /// only for its own objects. Purging explicitly on the memory warning frees
    /// the whole budget at the moment the system asks for it.
    private func observeMemoryPressure() {
        #if canImport(UIKit) && !os(watchOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.removeAll()
        }
        #endif
    }

    public func image(forKey key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    /// Insert an image, costed by its decoded byte size.
    public func setImage(_ image: PlatformImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString, cost: ArtworkDownsampler.decodedByteCost(of: image))
    }

    public func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    public func removeAll() {
        cache.removeAllObjects()
    }
}

/// Shared byte budgets for the app's image caches.
///
/// Kept together so the total in-memory image footprint is visible in one
/// place rather than spread across a dozen `countLimit` values.
public enum ImageCacheBudget {

    private static let megabyte = 1024 * 1024

    /// Save-state / screenshot thumbnails shown in Home shelves and browsers.
    public static let saveStateThumbnails = 16 * megabyte

    /// Generated "missing artwork" placeholders.
    public static let missingArtwork = 24 * megabyte

    /// Controller-skin preview renders.
    public static let skinPreviews = 24 * megabyte

    /// Decoded controller-skin assets.
    public static let skinAssets = 32 * megabyte

    /// Entry-count guards. `totalCostLimit` is the real bound; these just stop
    /// a pathological number of tiny entries.
    public static let defaultCountLimit = 100
}
