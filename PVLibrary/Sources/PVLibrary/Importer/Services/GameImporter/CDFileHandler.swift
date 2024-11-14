//
//  File.swift
//  PVLibrary
//
//  Created by David Proskin on 11/14/24.
//

import Foundation

protocol CDFileHandling {
    func findAssociatedBinFileNames(for cueFileItem: ImportQueueItem) throws -> [String]
    func candidateBinUrls(for binFileNames:[String], in directories: [URL]) -> [URL]
    func readM3UFileContents(from url: URL) throws -> [String]
    func fileExistsAtPath(_ path: URL) -> Bool
}

class DefaultCDFileHandler: CDFileHandling {
    
    func findAssociatedBinFileNames(for cueFileItem: ImportQueueItem) throws -> [String] {
        // Read the contents of the .cue file
        let cueContents = try String(contentsOf: cueFileItem.url, encoding: .utf8)
        let lines = cueContents.components(separatedBy: .newlines)
        
        // Array to hold .bin file names
        var binFileNames: [String] = []
        
        // Look for each line with FILE "something.bin" BINARY
        for line in lines {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: "\"")
            
            guard components.count >= 2,
                  line.lowercased().contains("file") && line.lowercased().contains("binary") else {
                continue
            }
            
            // Extract and add the .bin file name
            let binFileName = components[1]
            binFileNames.append(binFileName)
        }
        
        // Return the .bin file names
        return binFileNames
    }
    
    func candidateBinUrls(for binFileNames:[String], in directories: [URL]) -> [URL] {
        // Array to hold potential .bin file URLs
        var binFiles: [URL] = []
        
        for binFileName in binFileNames {
            for directory in directories {
                binFiles.append(directory.appendingPathComponent(binFileName))
            }
        }
        
        // Return all possible .bin file URLs
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
