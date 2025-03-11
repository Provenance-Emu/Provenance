//
//  PVImageFile+Artwork.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/25/24.
//
import PVLibrary
import UIKit
import PVMediaCache

public extension PVImageFile {
    public func fetchArtworkFromCache() async -> UIImage?  {
        guard let url = url else { return nil }
        return await PVMediaCache.shareInstance().image(forKey: url.path())
    }
    
    var pathOfCachedImage: URL? {
        guard let url = url else { return nil }

        let artworkKey = url.lastPathComponent
        if !PVMediaCache.fileExists(forKey: artworkKey) {
            return nil
        }
        let artworkURL = PVMediaCache.filePath(forKey: artworkKey)
        return artworkURL
    }
}
