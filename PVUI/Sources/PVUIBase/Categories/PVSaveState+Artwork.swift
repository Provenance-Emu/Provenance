//
//  PVSaveState+Artwork.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/25/24.
//

import PVLibrary
import UIKit

public extension PVSaveState {
    public func fetchUIImage() -> UIImage?  {
        guard let url = image?.url else { return nil }
        let path: String = url.standardizedFileURL.path
        return  UIImage(contentsOfFile: path)
    }
}
