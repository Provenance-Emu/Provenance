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
import PVRealm
#if canImport(UIKit)
import UIKit
#else
import AppKit
import CoreGraphics
#endif
import PVLogging
import PVFileSystem

@objcMembers
public final class PVImageFile: PVFile {
    @Persisted public internal(set) dynamic var _cgsize: String!
    @Persisted public var ratio: Float = 0.0
    @Persisted public var width: Int = 0
    @Persisted public var height: Int = 0
    @Persisted public var layout: String = ""

    public convenience init(withPartialPath partialPath: String, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        self.partialPath = partialPath
//        Task {
//            await calculateSizeData()
//        }
        calculateSizeData()
    }

    public convenience init(withURL url: URL, relativeRoot: RelativeRoot = RelativeRoot.platformDefault) {
        self.init()
        self.relativeRoot = relativeRoot
        let partialPath = relativeRoot.createRelativePath(fromURL: url)
        self.partialPath = partialPath

        calculateSizeData()
//        Task{
//            await calculateSizeData()
//        }
    }

    private func calculateSizeData() { // async {
        guard let path = url?.path,
              FileManager.default.fileExists(atPath: path)
        else {
            cgsize = .zero
            return
        }

//        let size = await Task { () -> CGSize in
            #if canImport(UIKit)
            guard let image = UIImage(contentsOfFile: path) else {
                ELOG("Failed to create UIImage from path <\(path)>")
//                return .zero
                cgsize = .zero
                return
            }
            #else
            let path = await url.path
            guard let image = NSImage(contentsOfFile: path) else {
                ELOG("Failed to create UIImage from path <\(path)>")
                return .zero
            }
            #endif
            let size = image.size
//            return size
//        }.value
//#if !os(macOS)
//        try? await Realm().write {
            cgsize = size
//        }
//#endif
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
