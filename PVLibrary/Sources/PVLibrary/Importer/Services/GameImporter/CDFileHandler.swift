//
//  File.swift
//  PVLibrary
//
//  Created by David Proskin on 11/14/24.
//

import Foundation

protocol CDFileHandling {
    func findAssociatedBinFiles(for cueFileItem: ImportQueueItem) throws -> [URL]
    func readM3UFileContents(from url: URL) throws -> [String]
    func fileExistsAtPath(_ path: URL) -> Bool
}

class DefaultCDFileHandler: CDFileHandling {
    func findAssociatedBinFiles(for cueFileItem: ImportQueueItem) throws -> [URL] {
        // Read the contents of the .cue file
        let cueContents = try String(contentsOf: cueFileItem.url, encoding: .utf8)
        let lines = cueContents.components(separatedBy: .newlines)
        
        // Array to hold multiple .bin file URLs
        var binFiles: [URL] = []
        
        // Look for each line with FILE "something.bin" BINARY
        for line in lines {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: "\"")
            
            guard components.count >= 2,
                  line.lowercased().contains("file") && line.lowercased().contains("binary") else {
                continue
            }
            
            // Extract the .bin file name
            let binFileName = components[1]
            let binPath = cueFileItem.url.deletingLastPathComponent().appendingPathComponent(binFileName)
            binFiles.append(binPath)
        }
        
        // Return all found .bin file URLs, or an empty array if none found
        return binFiles
    }
    
    func readM3UFileContents(from url: URL) throws -> [String] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let files = contents.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        return files
    }
    
    func fileExistsAtPath(_ path: URL) -> Bool {
        return FileManager.default.fileExists(atPath: path.path)
    }
}
