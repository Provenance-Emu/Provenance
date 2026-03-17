//
//  PVImageFile+Artwork.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/25/24.
//
import PVLibrary
import UIKit

public extension PVImageFile {
    /// Fetch the image from its local file URL asynchronously.
    /// PVImageFile stores the actual file path (screenshots, cached artwork),
    /// so we read directly — do not go through PVMediaCache which uses a
    /// different keying scheme (MD5 of the original remote URL).
    public func fetchArtworkFromCache() async -> UIImage?  {
        guard let url = url else { return nil }
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    /// Returns the URL of the image file if it exists on disk.
    /// Screenshots and PVMediaCache files are stored at their native paths,
    /// not keyed through PVMediaCache, so we just verify the file exists.
    var pathOfCachedImage: URL? {
        guard let url = url else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
