//
//  CDFileHandler.swift
//  PVLibrary
//
//  Created by David Proskin on 11/14/24.
//

import Foundation
import PVPrimitives

protocol CDFileHandling {
    func parseCueSheet(cueFileURL: URL) throws -> [String]
    func candidateBinUrls(for binFileNames:[String], in directories: [URL]) -> [URL]
    func readM3UFileContents(from url: URL) throws -> [String]
    func fileExistsAtPath(_ path: URL) -> Bool
}

class DefaultCDFileHandler: CDFileHandling {
    
    func parseCueSheet(cueFileURL: URL) throws -> [String] {
        // Read the contents of the .cue file
        let cueContents = try String(contentsOf: cueFileURL, encoding: .utf8)
        let lines = cueContents.components(separatedBy: .newlines)
        
        // Array to hold file names
        var fileNames: [String] = []
        
        // Look for each line like: FILE "filename.ext" SOME_TYPE
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ensure the line starts with FILE (case-insensitive) and has quotes for the filename
            if trimmedLine.uppercased().hasPrefix("FILE") && trimmedLine.contains("\"") {
                let components = trimmedLine.components(separatedBy: "\"")
                // The filename should be the second component, e.g., after the first quote
                if components.count >= 2 {
                    let fileName = components[1]
                    // Basic validation: ensure filename is not empty and seems reasonable (e.g., has an extension)
                    if !fileName.isEmpty && fileName.contains(".") {
                        fileNames.append(fileName)
                    }
                }
            }
        }
        
        // Return the file names
        return fileNames
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
