//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVMediaCache.swift
//
//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

import PVSupport
#if canImport(UIKit)
import UIKit
#else
import AppKit
import PVLogging

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

let kPVCachePath = "PVCache"

public extension Notification.Name {
    static let PVMediaCacheWasEmptied = Notification.Name("PVMediaCacheWasEmptiedNotification")
}

public extension String {
    var md5Hash: String {
        return (self as NSString).md5Hash()
    }
}

public enum MediaCacheError: Error {
    case keyWasEmpty
    case failedToScaleImage
}

public final class PVMediaCache: NSObject {
#if canImport(UIKit)
    static let memCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        return cache
    }()
    #else
    static let memCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        return cache
    }()
    #endif

    private var operationQueue: OperationQueue = {
        let queue = OperationQueue() // Was this meant to be a serial queue?
        queue.qualityOfService = .userInitiated
        return queue
    }()

    // MARK: - Object life cycle

    static var _sharedInstance: PVMediaCache = PVMediaCache()
    public class func shareInstance() -> PVMediaCache {
        return _sharedInstance
    }

    static var cachePath: URL = {
//        #if os(tvOS)
//        let cachesDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
//        #else
//        let cachesDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//        #endif
        let cachesDir = PVEmulatorConfiguration.documentsPath
        let cachePath = cachesDir.appendingPathComponent(kPVCachePath)

        do {
            try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Error creating cache directory at \(cachePath) : \(error.localizedDescription)")
        }

        return cachePath
    }()

    @objc
    public class func filePath(forKey key: String) -> URL? {
        if key.isEmpty {
            return nil
        }

        let keyHash: String = key.md5Hash()
        let filePath = cachePath.appendingPathComponent(keyHash, isDirectory: false)
//        let fileExists: Bool = FileManager.default.fileExists(atPath: filePath.path)

        return filePath // (fileExists ? filePath : nil)
    }

    @objc
    public class func fileExists(forKey key: String) -> Bool {
        if key.isEmpty {
            return false
        }

        let keyHash: String = key.md5Hash()
        let filePath = cachePath.appendingPathComponent(keyHash, isDirectory: false)
        return FileManager.default.fileExists(atPath: filePath.path)
    }

    #if canImport(UIKit)
    @objc
    @discardableResult
    public class func writeImage(toDisk image: UIImage, withKey key: String) throws -> URL {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        if let newImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)),
            let imageData = newImage.jpegData(compressionQuality: 0.85) {
            return try writeData(toDisk: imageData, withKey: key)
        } else {
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
            let imageData = newImage.jpegData(compressionQuality: 0.85)
            return try writeData(toDisk: imageData, withKey: key)
        } else {
            throw MediaCacheError.failedToScaleImage
        }
    }
    #endif

    @discardableResult
    public class func writeData(toDisk data: Data, withKey key: String) throws -> URL {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        let keyHash: String = key.md5Hash()
        let cachePath = self.cachePath.appendingPathComponent(keyHash, isDirectory: false)

        do {
            try FileManager.default.createDirectory(at: self.cachePath, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: cachePath, options: [.atomic])
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

        let keyHash: String = key.md5Hash()
        let cachePath = self.cachePath.appendingPathComponent(keyHash, isDirectory: false)

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

    @objc
    public class func empty() throws {
        DLOG("Emptying Cache")

        DispatchQueue.global(qos: .utility).async {
            let cachePath = self.cachePath.path
            if FileManager.default.fileExists(atPath: cachePath) {
                try? FileManager.default.removeItem(atPath: cachePath)
            }

            memCache.removeAllObjects()
            ILOG("Cache emptied")
            NotificationCenter.default.post(name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
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
    @discardableResult
    public func image(forKey key: String, completion: ((_ key: String, _ image: UIImage?) -> Void)? = nil) -> BlockOperation? {
        if key.isEmpty {
            completion?(key, nil)
            return nil
        }

        let operation = BlockOperation(block: { () -> Void in
            let cacheDir = PVMediaCache.cachePath
            let keyHash = key.md5Hash

            let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false).path

            var image: UIImage?
            image = PVMediaCache.memCache.object(forKey: keyHash as NSString)

            if image == nil, FileManager.default.fileExists(atPath: cachePath) {
                image = UIImage(contentsOfFile: cachePath)

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
    #endif
}
