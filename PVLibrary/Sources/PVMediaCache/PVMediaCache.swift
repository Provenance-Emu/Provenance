//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVMediaCache.swift
//
//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

import PVSupport
import PVLogging
import PVHashing
import PVFileSystem

#if canImport(UIKit)
import UIKit
#else
import AppKit

extension NSImage {
    func scaled(withMaxResolution maxResolution: Int) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(maxResolution), pixelsHigh: Int(maxResolution),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = NSSize(width: maxResolution, height: maxResolution)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: maxResolution, height: maxResolution), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: NSSize(width: maxResolution, height: maxResolution))
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }

    func jpegData(compressionQuality: Double) -> Data {
            let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:])!
            return jpegData
        }
}

#endif


#if os(tvOS)
    public let PVThumbnailMaxResolution: Float = 800.0
#else
    public let PVThumbnailMaxResolution: Float = 600.0
#endif

let kPVCachePath = "PVCache"

public extension Notification.Name {
    static let PVMediaCacheWasEmptied = Notification.Name("PVMediaCacheWasEmptiedNotification")
}

public enum MediaCacheError: Error {
    case keyWasEmpty
    case failedToScaleImage
}

public final class PVMediaCache: NSObject, Sendable {
#if canImport(UIKit)
    @MainActor static let memCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        /// Set reasonable memory limits to prevent excessive memory usage
        cache.countLimit = 100 // Maximum number of images to keep in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit (approximate)
        return cache
    }()
    #else
    static let memCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        /// Set reasonable memory limits to prevent excessive memory usage
        cache.countLimit = 100 // Maximum number of images to keep in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit (approximate)
        return cache
    }()
    #endif

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        /// Limit concurrent operations to prevent overwhelming the system
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Track recently accessed keys for LRU-like behavior
    private var recentlyAccessedKeys = LRUTracker(capacity: 50)

    /// Simple LRU tracker to help with cache management
    private class LRUTracker {
        private var orderedKeys: [String] = []
        private let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
        }

        /// Add or move a key to the front of the list
        func access(_ key: String) {
            /// Remove if exists
            if let index = orderedKeys.firstIndex(of: key) {
                orderedKeys.remove(at: index)
            }

            /// Add to front
            orderedKeys.insert(key, at: 0)

            /// Trim if needed
            if orderedKeys.count > capacity {
                orderedKeys.removeLast()
            }
        }

        /// Get the least recently used keys
        func getLeastRecentlyUsed(count: Int) -> [String] {
            let endIndex = min(count, orderedKeys.count)
            if endIndex <= 0 { return [] }
            return Array(orderedKeys.suffix(endIndex))
        }
    }

    // MARK: - Object life cycle

    static let _sharedInstance: PVMediaCache = PVMediaCache()
    public class func shareInstance() -> PVMediaCache {
        return _sharedInstance
    }

    static var cachePath: URL {
//        #if os(tvOS)
//        let cachesDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
//        #else
//        let cachesDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//        #endif
        let cachesDir = URL.documentsPath
        let cachePath = cachesDir.appendingPathComponent(kPVCachePath)

        do {
            try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Error creating cache directory at \(cachePath) : \(error.localizedDescription)")
        }

        return cachePath
    }

    @objc
    public class func filePath(forKey key: String) -> URL? {
        if key.isEmpty {
            return nil
        }

        let keyHash: String = key.md5Hash
        let filePath = cachePath.appendingPathComponent(keyHash, isDirectory: false)
//        let fileExists: Bool = FileManager.default.fileExists(atPath: filePath.path)

        return filePath // (fileExists ? filePath : nil)
    }

    @objc
    public class func fileExists(forKey key: String) -> Bool {
        if key.isEmpty {
            return false
        }

        let keyHash: String = key.md5Hash
        let filePath = cachePath.appendingPathComponent(keyHash, isDirectory: false)
        return FileManager.default.fileExists(atPath: filePath.path)
    }
    
    /// Find existing custom artwork files with a specific MD5 prefix
    /// - Parameter md5: The MD5 hash of the game to search for
    /// - Returns: The key of the most recently modified custom artwork file, if any
    @objc public static func findExistingCustomArtwork(forMD5 md5: String) -> String? {
        guard !md5.isEmpty else { return nil }
        
        let prefix = "artwork_\(md5)_"
        DLOG("Searching for existing custom artwork with prefix: \(prefix)")
        
        // Get the cache directory
        let cachesDir = URL.documentsPath
        let cachePath = cachesDir.appendingPathComponent(kPVCachePath)
        
        do {
            // Get all files in the cache directory
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            
            // Filter files that match our prefix
            let matchingFiles = files.filter { url in
                let filename = url.lastPathComponent
                let key: String = (filename as NSString).deletingPathExtension
                return key.hasPrefix(prefix)
            }
            
            DLOG("Found \(matchingFiles.count) matching custom artwork files")
            
            if matchingFiles.isEmpty {
                return nil
            }
            
            // Sort by modification date (newest first)
            let sortedFiles = try matchingFiles.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: Set([URLResourceKey.contentModificationDateKey])).contentModificationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: Set([URLResourceKey.contentModificationDateKey])).contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Return the key of the most recently modified file
            if let mostRecentFile = sortedFiles.first {
                let filename = mostRecentFile.lastPathComponent
                let key: String = (filename as NSString).deletingPathExtension
                DLOG("Found most recent custom artwork: \(key)")
                return key
            }
        } catch {
            ELOG("Error finding existing custom artwork: \(error)")
        }
        
        return nil
    }

    #if canImport(UIKit)
    @objc
    @discardableResult
    public class func writeImage(toDisk image: UIImage, withKey key: String) throws -> URL {
        DLOG("Attempting to write image to disk with key: \(key)")
        if key.isEmpty {
            DLOG("Error: Key was empty")
            throw MediaCacheError.keyWasEmpty
        }

        if let newImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)),
            let imageData = newImage.jpegData(compressionQuality: 0.95) {
            DLOG("Image scaled and converted to JPEG data")
            return try writeData(toDisk: imageData, withKey: key)
        } else {
            DLOG("Error: Failed to scale image or convert to JPEG data")
            throw MediaCacheError.failedToScaleImage
        }
    }
    #else
    @objc
    @discardableResult
    public class func writeImage(toDisk image: NSImage, withKey key: String) throws -> URL {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        if let newImage = image.scaled(withMaxResolution: Int(PVThumbnailMaxResolution)) {
            let imageData = newImage.jpegData(compressionQuality: 0.95)
            return try writeData(toDisk: imageData, withKey: key)
        } else {
            throw MediaCacheError.failedToScaleImage
        }
    }
    #endif

    @discardableResult
    public class func writeData(toDisk data: Data, withKey key: String) throws -> URL {
        DLOG("Attempting to write data to disk with key: \(key)")
        if key.isEmpty {
            DLOG("Error: Key was empty")
            throw MediaCacheError.keyWasEmpty
        }

        let keyHash: String = key.md5Hash
        let cachePath = self.cachePath.appendingPathComponent(keyHash, isDirectory: false)
        DLOG("Cache path for key: \(cachePath.path)")

        do {
            try FileManager.default.createDirectory(at: self.cachePath, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: cachePath, options: [.atomic])
            DLOG("Data successfully written to cache path")
            return cachePath
        } catch {
            ELOG("Failed to write image to cache path \(cachePath.path) : \(error.localizedDescription)")
            throw error
        }
    }

    public class func deleteImage(forKey key: String) throws {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        let keyHash: String = key.md5Hash
        let cachePath = self.cachePath.appendingPathComponent(keyHash, isDirectory: false)

        Task { @MainActor in
            memCache.removeObject(forKey: keyHash as NSString)

            if FileManager.default.fileExists(atPath: cachePath.path) {
                do {
                    try FileManager.default.removeItem(at: cachePath)
                } catch {
                    DLOG("Unable to delete cache item: \(cachePath.path) because: \(error.localizedDescription)")
                    throw error
                }
            }
        }
    }

    @objc
    public class func empty() throws {
        DLOG("Emptying Cache")

        DispatchQueue.global(qos: .utility).async {
            let cachePath = self.cachePath.path
            if FileManager.default.fileExists(atPath: cachePath) {
                try? FileManager.default.removeItem(atPath: cachePath)
            }

            Task { @MainActor in
                memCache.removeAllObjects()
                ILOG("Cache emptied")
                NotificationCenter.default.post(name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
            }
        }
    }

    #if os(macOS)
    @discardableResult
    public func image(forKey key: String, completion: ((_ key: String, _ image: NSImage?) -> Void)? = nil) -> BlockOperation? {
        if key.isEmpty {
            completion?(key, nil)
            return nil
        }

        let operation = BlockOperation(block: { () -> Void in
            let cacheDir = PVMediaCache.cachePath
            let keyHash = key.md5Hash

            let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false).path

            var image: NSImage?
            image = PVMediaCache.memCache.object(forKey: keyHash as NSString)

            if image == nil, FileManager.default.fileExists(atPath: cachePath) {
                image = NSImage(contentsOfFile: cachePath)

                if let image = image {
                    PVMediaCache.memCache.setObject(image, forKey: keyHash as NSString)
                }
            }

            DispatchQueue.main.async(execute: { () -> Void in
                completion?(key, image)
            })
        })

        operationQueue.addOperation(operation)
        return operation
    }
    #else
    public typealias ImageFetchCompletion = @Sendable (_ key: String, _ image: UIImage?) -> Void

    /// Store in memory cache with cost calculation
    @MainActor private func storeInMemoryCache(image: UIImage, forKey keyHash: String) {
        /// Calculate approximate memory cost based on image dimensions and bit depth
        let bytesPerPixel = 4 // Assuming RGBA
        let cost = Int(image.size.width * image.size.height) * bytesPerPixel

        PVMediaCache.memCache.setObject(image, forKey: keyHash as NSString, cost: cost)
        recentlyAccessedKeys.access(keyHash)
        DLOG("Image added to memory cache with cost: \(cost)")
    }

    /// Trim disk cache to prevent excessive storage usage
    public func trimDiskCache() {
        #if false
        // TODO: Fix me to only delete files we're not using anymore
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let cachePath = PVMediaCache.cachePath

            do {
                let contents = try fileManager.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])

                /// Sort by modification date (oldest first)
                let sortedFiles = try contents.sorted { file1, file2 in
                    let date1 = try file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    let date2 = try file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    return date1 < date2
                }

                /// Calculate total size
                var totalSize: UInt64 = 0
                for file in sortedFiles {
                    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    totalSize += UInt64(size)
                }

                /// If total size exceeds 100MB, remove oldest files until under 80MB
                let maxSize: UInt64 = 100 * 1024 * 1024 // 100MB
                let targetSize: UInt64 = 80 * 1024 * 1024 // 80MB

                if totalSize > maxSize {
                    DLOG("Trimming disk cache from \(totalSize/1024/1024)MB to \(targetSize/1024/1024)MB")

                    for file in sortedFiles {
                        if totalSize <= targetSize {
                            break
                        }

                        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        try fileManager.removeItem(at: file)
                        totalSize -= UInt64(size)

                        DLOG("Removed cached file: \(file.lastPathComponent), saved \(size/1024)KB")
                    }
                }
            } catch {
                ELOG("Error trimming disk cache: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Async version of image fetching with improved caching
    public func image(forKey key: String) async -> UIImage? {
        guard !key.isEmpty else {
            DLOG("Error: Key was empty")
            return nil
        }

        DLOG("Attempting to fetch image for key: \(key)")
        let keyHash = key.md5Hash
        let cacheDir = PVMediaCache.cachePath
        let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false).path

        // Check memory cache first
        if let cachedImage = await MainActor.run(body: {
            /// Update access tracking
            recentlyAccessedKeys.access(keyHash)
            return PVMediaCache.memCache.object(forKey: keyHash as NSString)
        }) {
            DLOG("Image found in memory cache")
            return cachedImage
        }

        // Check disk cache
        guard FileManager.default.fileExists(atPath: cachePath) else {
            DLOG("Image not found on disk")
            return nil
        }

        DLOG("Attempting to load image from disk")
        guard let image = UIImage(contentsOfFile: cachePath) else {
            DLOG("Failed to load image from disk")
            return nil
        }

        // Store in memory cache with cost calculation
        await MainActor.run {
            storeInMemoryCache(image: image, forKey: keyHash)
        }

        // Update file modification date to track LRU on disk
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: cachePath)

        return image
    }

    /// Preload multiple images into the cache with improved batching
    public func preloadImages(forKeys keys: [String]) async {
        /// Deduplicate keys
        let uniqueKeys = Array(Set(keys))

        /// Process in smaller batches to avoid overwhelming the system
        let batchSize = 5

        /// Track successful loads to avoid redundant work
        var loadedKeys = Set<String>()

        /// First check which images are already in memory cache
        for key in uniqueKeys {
            let keyHash = key.md5Hash
            if Thread.isMainThread, PVMediaCache.memCache.object(forKey: keyHash as NSString) != nil {
                loadedKeys.insert(key)
            }
        }

        /// Filter out already loaded keys
        let keysToLoad = uniqueKeys.filter { !loadedKeys.contains($0) }

        /// Process remaining keys in batches
        for i in stride(from: 0, to: keysToLoad.count, by: batchSize) {
            let end = min(i + batchSize, keysToLoad.count)
            let batch = Array(keysToLoad[i..<end])

            /// Create a task group for concurrent loading within the batch
            await withTaskGroup(of: Void.self) { group in
                for key in batch {
                    group.addTask {
                        /// Check if the file exists on disk before loading
                        let keyHash = key.md5Hash
                        let cachePath = PVMediaCache.cachePath.appendingPathComponent(keyHash, isDirectory: false).path

                        if FileManager.default.fileExists(atPath: cachePath) {
                            /// If on disk, just load it into memory cache
                            if let image = UIImage(contentsOfFile: cachePath) {
                                await MainActor.run {
                                    self.storeInMemoryCache(image: image, forKey: keyHash)
                                }
                            }
                        } else {
                            /// Otherwise load from network
                            _ = await self.image(forKey: key)
                        }
                    }
                }
            }

            /// Small delay between batches to avoid overwhelming the system
            if end < keysToLoad.count {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay between batches
            }
        }

        /// Trim disk cache after large preload operations
        if uniqueKeys.count > 10 {
            trimDiskCache()
        }
    }
    #endif

    /// Invalidate the cache for a specific URL
    /// - Parameter url: The URL to invalidate in the cache
    public static func invalidateCache(forURL url: String) {
        guard !url.isEmpty else { return }

        /// Get the shared instance and remove the item from the cache
        let cache = PVMediaCache.shareInstance()
        cache.removeFromCache(forKey: url)

        /// Log the invalidation
        DLOG("Invalidated cache for URL: \(url)")
    }

    /// Remove an item from the cache
    /// - Parameter key: The key to remove from the cache
    private func removeFromCache(forKey key: String) {
        guard !key.isEmpty else { return }

        let keyHash = key.md5Hash
        Task { @MainActor in
            PVMediaCache.memCache.removeObject(forKey: keyHash as NSString)
        }

        // Also remove from disk if needed
        let cachePath = PVMediaCache.cachePath.appendingPathComponent(keyHash, isDirectory: false)
        if FileManager.default.fileExists(atPath: cachePath.path) {
            try? FileManager.default.removeItem(at: cachePath)
        }
    }

    /// Write an image to disk with optimized compression
    private func writeImage(toDisk image: UIImage, withKey key: String) -> Bool {
        guard !key.isEmpty else {
            DLOG("Error: Key was empty")
            return false
        }

        let keyHash = key.md5Hash
        let cacheDir = PVMediaCache.cachePath
        let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false)

        /// Create cache directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ELOG("Failed to create cache directory: \(error.localizedDescription)")
                return false
            }
        }

        /// Determine if we need to scale the image
        let maxDimension: CGFloat = 1024 // Maximum dimension for cached images
        let needsScaling = image.size.width > maxDimension || image.size.height > maxDimension

        /// Use the original image if no scaling needed
        let finalImage = needsScaling ? image.scaledToFit(maxDimension) : image

        /// Determine optimal compression quality based on image size
        let compressionQuality: CGFloat
        let pixelCount = finalImage.size.width * finalImage.size.height

        if pixelCount > 1_000_000 { // > 1MP
            compressionQuality = 0.7
        } else if pixelCount > 500_000 { // > 0.5MP
            compressionQuality = 0.8
        } else {
            compressionQuality = 0.9
        }

        /// Choose between JPEG and PNG based on image characteristics
        let hasAlpha = finalImage.hasAlphaChannel
        let isSmall = pixelCount < 100_000 // < 0.1MP

        do {
            let data: Data?

            if hasAlpha || isSmall {
                /// Use PNG for images with transparency or small images
                data = finalImage.pngData()
                DLOG("Using PNG format for image with key: \(key)")
            } else {
                /// Use JPEG for most images
                data = finalImage.jpegData(compressionQuality: compressionQuality)
                DLOG("Using JPEG format (quality: \(compressionQuality)) for image with key: \(key)")
            }

            guard let imageData = data else {
                ELOG("Failed to convert image to data")
                return false
            }

            try imageData.write(to: cachePath)
            DLOG("Successfully wrote image to disk: \(cachePath.path)")
            return true
        } catch {
            ELOG("Failed to write image to disk: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Background Cache Maintenance

    /// Setup background maintenance tasks
    public func setupBackgroundMaintenance() {
        /// Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        /// Schedule periodic cache maintenance
        scheduleCacheMaintenance()
    }

    /// Schedule periodic cache maintenance
    private func scheduleCacheMaintenance() {
        /// Schedule maintenance to run every 30 minutes
        let timer = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.performBackgroundMaintenance()
        }
        RunLoop.main.add(timer, forMode: .common)

        /// Perform initial maintenance
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performBackgroundMaintenance()
        }
    }

    /// Perform background maintenance tasks
    private func performBackgroundMaintenance() {
        DLOG("Starting background cache maintenance")

        /// Trim disk cache
        trimDiskCache()

        /// Remove any corrupted files
        removeCorruptedFiles()

        DLOG("Completed background cache maintenance")
    }

    /// Handle memory warning by clearing memory cache
    @objc private func handleMemoryWarning() {
        DLOG("Received memory warning, clearing memory cache")
        Task { @MainActor in
            PVMediaCache.memCache.removeAllObjects()
        }
    }

    /// Remove any corrupted image files from the cache
    private func removeCorruptedFiles() {
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let cachePath = PVMediaCache.cachePath

            do {
                let contents = try fileManager.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: nil)
                var corruptedCount = 0

                for fileURL in contents {
                    /// Skip directories
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        continue
                    }

                    /// Check if file is a valid image
                    if !self.isValidImageFile(at: fileURL) {
                        do {
                            try fileManager.removeItem(at: fileURL)
                            corruptedCount += 1
                            DLOG("Removed corrupted image file: \(fileURL.lastPathComponent)")
                        } catch {
                            ELOG("Failed to remove corrupted file: \(error.localizedDescription)")
                        }
                    }
                }

                if corruptedCount > 0 {
                    DLOG("Removed \(corruptedCount) corrupted image files during maintenance")
                }
            } catch {
                ELOG("Error checking for corrupted files: \(error.localizedDescription)")
            }
        }
    }

    /// Check if a file is a valid image
    private func isValidImageFile(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
            return false
        }

        #if canImport(UIKit)
        return UIImage(data: data) != nil
        #else
        return NSImage(data: data) != nil
        #endif
    }

    /// Legacy completion handler version that internally uses the async version
    /// Optimized to avoid unnecessary operations for cached images
    @discardableResult
    public func image(forKey key: String, completion: ImageFetchCompletion? = nil) -> BlockOperation? {
        guard !key.isEmpty else {
            DLOG("Error: Key was empty")
            completion?(key, nil)
            return nil
        }

        let keyHash = key.md5Hash

        /// Check memory cache first to avoid creating an operation
        if let cachedImage = Thread.isMainThread ? PVMediaCache.memCache.object(forKey: keyHash as NSString) : nil {
            DLOG("Image found in memory cache (sync)")
            completion?(key, cachedImage)
            return nil
        }

        /// Check if the file exists on disk before creating an operation
        let cacheDir = PVMediaCache.cachePath
        let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false).path

        if FileManager.default.fileExists(atPath: cachePath) {
            /// If we're on the main thread and the image is on disk, load it in a background operation
            let operation = BlockOperation { [weak self] in
                guard let self = self else { return }

                guard let image = UIImage(contentsOfFile: cachePath) else {
                    DLOG("Failed to load image from disk")
                    DispatchQueue.main.async {
                        completion?(key, nil)
                    }
                    return
                }

                /// Store in memory cache
                Task { @MainActor in
                    self.storeInMemoryCache(image: image, forKey: keyHash)
                }

                DispatchQueue.main.async {
                    completion?(key, image)
                }
            }

            operationQueue.addOperation(operation)
            return operation
        }

        /// If not in memory or on disk, use the async version
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }

            Task {
                let image = await self.image(forKey: key)
                await MainActor.run {
                    completion?(key, image)
                }
            }
        }

        operationQueue.addOperation(operation)
        return operation
    }
}
