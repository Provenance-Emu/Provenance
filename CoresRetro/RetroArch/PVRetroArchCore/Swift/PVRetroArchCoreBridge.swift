//
//  PVRetroArchCoreBridge.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 2/19/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Unrar
import PVLogging

@objc public extension PVRetroArchCoreBridge {
    @objc func extractRAR(atPath: String, toDestination destination: String, overwrite: Bool) -> Bool {
        do {
            let archive: Unrar.Archive = try .init(fileURL: URL(fileURLWithPath: atPath))
            let filesInArchive: [Unrar.Entry] = try archive.entries()
            
            let files = filesInArchive.map(\.fileName).joined(separator: ", ")
            DLOG("Archived files: \(files)")
            
            let fileManager = FileManager.default
            
            for entry in filesInArchive {
                
                let fileName = entry.fileName
                let fullPath = (destination as NSString).appendingPathComponent(fileName)
                
                let fileExists = fileManager.fileExists(atPath: fullPath)
                /// Check if the file already exists
                if fileExists {
                    /// If overwrite is false and file exists, skip this file
                    if !overwrite {
                        WLOG("Skipping existing file: \(fileName)")
                        continue
                    }
                }
                
                try autoreleasepool {
                    /// Extract the file data
                    let extractedData = try archive.extract(entry)
                    
                    /// Ensure the directory exists
                    try fileManager.createDirectory(atPath: (fullPath as NSString).deletingLastPathComponent,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
                    
                    if fileExists && !overwrite {
                        /// If overwrite is true, remove the existing file
                        try fileManager.removeItem(atPath: fullPath)
                    }

                    /// Write the file to destination
                    try extractedData.write(to: URL(fileURLWithPath: fullPath))
                }
                ILOG("Extracted file: \(fileName)")
            }
            
            return true
        } catch {
            ELOG("Error: \(error.localizedDescription)")
            return false
        }
    }
}

