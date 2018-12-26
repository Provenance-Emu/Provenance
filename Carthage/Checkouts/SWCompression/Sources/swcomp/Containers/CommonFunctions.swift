// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

func isValidOutputDirectory(_ outputPath: String, create: Bool) throws -> Bool {
    let fileManager = FileManager.default
    var isDir: ObjCBool = false

    if fileManager.fileExists(atPath: outputPath, isDirectory: &isDir) {
        return isDir.boolValue
    } else if create {
        try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
    }
    return true
}

func printInfo(_ entries: [ContainerEntryInfo]) {
    for entry in entries {
        print(entry)
        print("------------------\n")
    }
}

func write<T: ContainerEntry>(_ entries: [T], _ outputPath: String, _ verbose: Bool) throws {
    let fileManager = FileManager.default
    let outputURL = URL(fileURLWithPath: outputPath)

    if verbose {
        print("d = directory, f = file, l = symbolic link")
    }

    var directoryAttributes = [(attributes: [FileAttributeKey: Any], path: String)]()

    // First, we create directories.
    for entry in entries where entry.info.type == .directory {
        let entryName = entry.info.name
        let entryFullURL = outputURL.appendingPathComponent(entryName, isDirectory: true)

        if verbose {
            print("d: \(entryName)")
        }
        try fileManager.createDirectory(at: entryFullURL, withIntermediateDirectories: true)

        var attributes = [FileAttributeKey: Any]()

        #if !os(Linux) // On linux only permissions attribute is supported.
            if let mtime = entry.info.modificationTime {
                attributes[FileAttributeKey.modificationDate] = mtime
            }

            if let ctime = entry.info.creationTime {
                attributes[FileAttributeKey.creationDate] = ctime
            }
        #endif

        if let permissions = entry.info.permissions?.rawValue, permissions > 0 {
            attributes[FileAttributeKey.posixPermissions] = NSNumber(value: permissions)
        }

        // We apply attributes to directories later, because extracting files into them changes mtime.
        directoryAttributes.append((attributes, entryFullURL.path))
    }

    // Now, we create the rest of files.
    for entry in entries where entry.info.type != .directory {
        let entryName = entry.info.name
        let entryFullURL = outputURL.appendingPathComponent(entryName, isDirectory: false)

        if entry.info.type == .symbolicLink {
            let destinationPath: String?
            if let tarEntry = entry as? TarEntry {
                destinationPath = tarEntry.info.linkName
            } else {
                guard let entryData = entry.data else {
                    print("ERROR: Unable to get destination path for symbolic link \(entryName).")
                    exit(1)
                }
                destinationPath = String(data: entryData, encoding: .utf8)
            }
            guard destinationPath != nil else {
                print("ERROR: Unable to get destination path for symbolic link \(entryName).")
                exit(1)
            }
            let endURL = entryFullURL.deletingLastPathComponent().appendingPathComponent(destinationPath!)
            if verbose {
                print("l: \(entryName) -> \(endURL.path)")
            }
            try fileManager.createSymbolicLink(atPath: entryFullURL.path, withDestinationPath: endURL.path)
            // We cannot apply attributes to symbolic link.
            continue
        } else if entry.info.type == .regular {
            if verbose {
                print("f: \(entryName)")
            }
            guard let entryData = entry.data else {
                print("ERROR: Unable to get data for the entry \(entryName).")
                exit(1)
            }
            try entryData.write(to: entryFullURL)
        } else {
            print("WARNING: Unknown file type \(entry.info.type) for entry \(entryName). Skipping this entry.")
            continue
        }

        var attributes = [FileAttributeKey: Any]()

        #if !os(Linux) // On linux only permissions attribute is supported.
            if let mtime = entry.info.modificationTime {
                attributes[FileAttributeKey.modificationDate] = mtime
            }

            if let ctime = entry.info.creationTime {
                attributes[FileAttributeKey.creationDate] = ctime
            }
        #endif

        if let permissions = entry.info.permissions?.rawValue, permissions > 0 {
            attributes[FileAttributeKey.posixPermissions] = NSNumber(value: permissions)
        }

        try fileManager.setAttributes(attributes, ofItemAtPath: entryFullURL.path)
    }

    for tuple in directoryAttributes {
        try fileManager.setAttributes(tuple.attributes, ofItemAtPath: tuple.path)
    }
}
