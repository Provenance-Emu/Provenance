//
//  MupenGameCore+Resources.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLogging
#if canImport(PVMupen64PlusBridge)
import PVMupen64PlusBridge   // Xcode project: the bridge is a framework of this name
#else
import PVMupenBridge         // SwiftPM package: the ObjC bridge target
#endif

fileprivate let highResDirs: [String] = ["/hires_texture/", "/cache/", "/texture_dump/"]

@objc
public extension MupenGameCore {
    // The ini helper files are copied by PVMupenBridge's copyIniFiles: (PVMupenBridge+Resources.m).
    @objc func createHiResFolder(_ romFolder: String) throws {
        let subPaths: [String] = highResDirs.map { (romFolder as NSString).appendingPathComponent($0) as String}
        let fm = FileManager.default
        try subPaths.forEach { subPath in
            do {
                VLOG("Creating directory \(subPath)")
                if !fm.fileExists(atPath: subPath, isDirectory: nil) {
                    try fm.createDirectory(atPath: subPath, withIntermediateDirectories: true)
                }
            } catch {
                ELOG("Error creating hi res texture path: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
