//
//  PVImageFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift

@objcMembers
public final class PVImageFile: PVFile {
    public internal(set) dynamic var _cgsize: String!
    public dynamic var ratio: Float = 0.0
    public dynamic var width: Int = 0
    public dynamic var height: Int = 0
    public dynamic var layout: String = ""

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
        calculateSizeData()
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        partialPath = relativeRoot.createRelativePath(fromURL: url)
        calculateSizeData()
    }

    private func calculateSizeData() {
        guard let image = UIImage(contentsOfFile: url.path) else {
            ELOG("Failed to create UIImage from path <\(url.path)>")
            return
        }

        let size = image.size
        cgsize = size
    }

    public private(set) var cgsize: CGSize {
        get {
            return NSCoder.cgSize(for: _cgsize)
        }
        set {
            width = Int(newValue.width)
            height = Int(newValue.height)
            layout = newValue.width > newValue.height ? "landscape" : "portrait"
            ratio = Float(max(newValue.width, newValue.height) / min(newValue.width, newValue.height))
            _cgsize = NSCoder.string(for: newValue)
        }
    }
}
