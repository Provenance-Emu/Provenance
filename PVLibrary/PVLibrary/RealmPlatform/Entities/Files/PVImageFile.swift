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
#if canImport(UIKit)
import UIKit
#else
import AppKit
import CoreGraphics
#endif
import PVLogging

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
        let partialPath = relativeRoot.createRelativePath(fromURL: url)
        self.partialPath = partialPath
        calculateSizeData()
    }

    private func calculateSizeData() {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else {
            ELOG("Failed to create UIImage from path <\(url.path)>")
            return
        }
        #else
        guard let image = NSImage(contentsOfFile: url.path) else {
            ELOG("Failed to create UIImage from path <\(url.path)>")
            return
        }
        #endif

        let size = image.size
#if !os(macOS)
        cgsize = size
#endif
    }

#if !os(macOS)
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
#endif
}
