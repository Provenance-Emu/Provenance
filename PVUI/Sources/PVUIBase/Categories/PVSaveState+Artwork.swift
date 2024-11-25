//
//  PVSaveState+Artwork.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/25/24.
//

import PVLibrary
import UIKit

public extension PVSaveState {
    public func fetchArtworkFromCache() async -> UIImage?  {
        await image?.fetchArtworkFromCache()
    }
}
