//
//  MupenGameCore+Resources.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/24/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

fileprivate let highResDirs: [String] = ["/hires_texture/", "/cache/", "/texture_dump/"]
fileprivate let iniFiles: [String] = ["GLideN64.ini", "GLideN64.custom.ini", "RiceVideoLinux.ini", "mupen64plus.ini"]

enum MupenGameCoreError: Error {
    case resourceNotFound
}

@objc
public extension MupenGameCore {
    @objc func copyIniFiles(_ romFolder: String) throws {
        let iniBundle = Bundle(for: type(of: self))
        let fm = FileManager.default
        
        // Copy default config files if they don't exist

        // Create destination folder if missing
        if !fm.fileExists(atPath: romFolder, isDirectory: nil) {
            do {
                try fm.createDirectory(atPath: romFolder, withIntermediateDirectories: true)
            } catch {
                throw error
            }
        }
        
        try iniFiles.forEach { iniFile in
            let destinationPath = (romFolder as NSString).appendingPathComponent(iniFile) as String
            guard !fm.fileExists(atPath: destinationPath) else {
                VLOG("File exists at path <\(destinationPath)>")
                return
            }
            
            let nsIniFile = iniFile as NSString
            let fileName = nsIniFile.deletingPathExtension
            let fileExtension = nsIniFile.pathExtension
            
            guard let sourcePath = iniBundle.path(forResource: fileName, ofType: fileExtension) else {
                throw MupenGameCoreError.resourceNotFound
            }

            try fm.copyItem(atPath: sourcePath, toPath: destinationPath)
        }
    }
    
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
