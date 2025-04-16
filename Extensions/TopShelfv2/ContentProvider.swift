//
//  ContentProvider.swift
//  TopShelfv2
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import TVServices
import os.log
import PVSupport
import PVLibrary

/// A basic implementation of a TopShelf extension for Provenance
class ContentProvider: TVTopShelfContentProvider {
    
    // Logger for debugging
    private let logger = OSLog(subsystem: "org.provenance-emu.provenance.topshelf", category: "ContentProvider")
    
    override init() {
        super.init()
        // Log that the extension is initializing
        os_log("TopShelfv2: ContentProvider initializing", log: logger, type: .debug)
        
        // Write to a file in the shared container to verify the extension ran
        let fileManager = FileManager.default
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.org.provenance-emu.provenance") {
            let logFileURL = containerURL.appendingPathComponent("topshelf_log.txt")
            let timestamp = Date().description
            let logMessage = "TopShelfv2 extension initialized at \(timestamp)\n"
            
            do {
                if fileManager.fileExists(atPath: logFileURL.path) {
                    // Append to existing file
                    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                        fileHandle.seekToEndOfFile()
                        if let data = logMessage.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                        fileHandle.closeFile()
                    }
                } else {
                    // Create new file
                    try logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
                }
                os_log("TopShelfv2: Wrote to log file at %@", log: logger, type: .debug, logFileURL.path)
            } catch {
                os_log("TopShelfv2: Failed to write to log file: %@", log: logger, type: .error, error.localizedDescription)
            }
        } else {
            os_log("TopShelfv2: Could not access app group container", log: logger, type: .error)
        }
    }
    
    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        os_log("TopShelfv2: loadTopShelfContent called", log: logger, type: .debug)
        
        // Create a simple static item that will always show up
        let items = (1...5).map { index -> TVTopShelfSectionedItem in
            let item = TVTopShelfSectionedItem(identifier: "test_item_\(index)")
            item.title = "Provenance Test Item \(index)"
            item.imageShape = .square
            
            // Set a deep link URL
            item.playAction = TVTopShelfAction(url: URL(string: "\(PVAppURLKey)://test/\(index)")!)
            
            return item
        }
        
        // Create a section with the test items
        let section = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        section.title = "Provenance TopShelf Test"  
        
        // Return the content with the section
        return TVTopShelfSectionedContent(sections: [section])
    }
}
