//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVMediaCache.m
//
//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

let kPVCachePath = "PVCache"

public extension Notification.Name {
    static let PVMediaCacheWasEmptied = Notification.Name("PVMediaCacheWasEmptiedNotification")
}

extension String {
    var md5Hash: String {
        return (self as NSString).md5Hash()
    }
}

public enum MediaCacheError: Error {
    case keyWasEmpty
    case failedToScaleImage
}

public class PVMediaCache: NSObject {

	static let memCache : NSCache<NSString, UIImage> = {
		let cache = NSCache<NSString, UIImage>()
		return cache
	}()

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
        let cachesDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!

        let cachePath = URL(fileURLWithPath: cachesDir).appendingPathComponent(kPVCachePath)

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

        return filePath //(fileExists ? filePath : nil)
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

    @objc
    @discardableResult
    public class func writeImage(toDisk image: UIImage, withKey key: String) throws -> URL {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        if let newImage = image.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)),
            let imageData = UIImagePNGRepresentation(newImage) {
                return try self.writeData(toDisk: imageData, withKey: key)
            } else {
                throw MediaCacheError.failedToScaleImage
            }
    }

    @discardableResult
    public class func writeData(toDisk data: Data, withKey key: String) throws -> URL {
        if key.isEmpty {
            throw MediaCacheError.keyWasEmpty
        }

        let keyHash: String = key.md5Hash()
        let cachePath = self.cachePath.appendingPathComponent(keyHash, isDirectory: false)

        do {
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

		DispatchQueue.global(qos: .background).async {
			let cachePath = self.cachePath.path
			if FileManager.default.fileExists(atPath: cachePath) {
				try? FileManager.default.removeItem(atPath: cachePath)
			}

			memCache.removeAllObjects()
			ILOG("Cache emptied")
			NotificationCenter.default.post(name: NSNotification.Name.PVMediaCacheWasEmptied, object: nil)
		}
    }

    @discardableResult
	public func image(forKey key: String, completion: ((_ key: String, _ image: UIImage?) -> Void)? = nil) -> BlockOperation? {
        if key.isEmpty {
            completion?(key, nil)
            return nil
        }

        let operation = BlockOperation(block: {() -> Void in
            let cacheDir = PVMediaCache.cachePath
            let keyHash = key.md5Hash

            let cachePath = cacheDir.appendingPathComponent(keyHash, isDirectory: false).path

            var image: UIImage? = nil
			image = PVMediaCache.memCache.object(forKey: keyHash as NSString)

			if image == nil, FileManager.default.fileExists(atPath: cachePath) {
                image = UIImage(contentsOfFile: cachePath)

				if let image = image {
					PVMediaCache.memCache.setObject(image, forKey: keyHash as NSString)
				}
            }

            DispatchQueue.main.async(execute: {() -> Void in
                completion?(key, image)
            })
        })

        operationQueue.addOperation(operation)
        return operation
    }
}
