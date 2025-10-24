//
//  PVSaveState+Artwork.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/25/24.
//

import PVLibrary
import UIKit
import PVMediaCache

public extension PVSaveState {
    /// Fetch the UI image for the save state
    /// This is a convenience method that uses the PVImageFile+Artwork extension
    /// - Returns: The image if available, nil otherwise
    func fetchUIImage() -> UIImage? {
        // If there's no image file, return nil
        guard let imageFile = image else {
            return nil
        }

        // Use the pathOfCachedImage property from PVImageFile+Artwork
        if let cachedImagePath = imageFile.pathOfCachedImage {
            return UIImage(contentsOfFile: cachedImagePath.path)
        }

        // If not in cache, try to load directly from the file
        guard let url = imageFile.url else {
            return nil
        }

        let image = UIImage(contentsOfFile: url.path)

        // If we loaded an image, store it in the cache for future use
        if let image = image {
            try? PVMediaCache.writeImage(toDisk: image, withKey: "savestate_image_\(url.absoluteString)")
        }

        return image
    }

    /// Fetch the UI image for the save state asynchronously
    /// This is a convenience method that uses the PVImageFile+Artwork extension
    /// - Returns: The image if available, nil otherwise
    func fetchUIImageAsync() async -> UIImage? {
        // If there's no image file, return nil
        guard let imageFile = image else {
            return nil
        }

        // Use the PVImageFile+Artwork extension to fetch from cache
        return await imageFile.fetchArtworkFromCache()
    }
}
