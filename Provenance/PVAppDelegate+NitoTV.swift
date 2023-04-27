//
//  PVAppDelegate+NitoTV.swift
//  ProvenanceTV
//
//  Created by Joseph Mattiello on 10/5/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVSupport

@objc
extension PVAppDelegate {
    public func importFile(atURL url: URL) {

        let man = FileManager.default
        ILOG("[Provenance] host: \(url.host ?? "nil") path: \(url.path)")
        let cache = uploadDirectory
        do {
            let attrs = try man.attributesOfItem(atPath: cache.path)
            ILOG("[Provenance] cache attrs: \(attrs),  cache path: \(cache)")
            let last = url.lastPathComponent
            let newPath = cache.appendingPathComponent(last)
            let originalPath = url
            ILOG("[Provenance] copying \(originalPath.path) to \(newPath.path)")
            //try man.copyItem(at: originalPath, to: newPath)
            try man.copyItem(atPath: originalPath.path, toPath: newPath.path)
        } catch {
            
            ELOG("\(error.localizedDescription)")
        }
    }

    var uploadDirectory: URL {
        let man = FileManager.default
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let first: URL = URL(string: paths.first!)!
        let cache: URL = first.appendingPathComponent("Imports")
        let path = cache.path
        if !man.fileExists(atPath: path) {
            WLOG("this path wasnt found; \(cache)")
            let folderAttrs: [FileAttributeKey: Any] = [
                .groupOwnerAccountName: "staff",
                .ownerAccountName: "mobile"
            ]
            do {
                try man.createDirectory(at: cache, withIntermediateDirectories: true, attributes: folderAttrs)
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        }
        return cache
    }
}
