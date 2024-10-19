//
//  ArchiveExtractor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/19/24.
//

import Foundation
import PVLogging
import PVFileSystem
@_exported import PVSupport
import SWCompression
@_exported import ZipArchive
import Combine

package enum ArchiveType: String {
    case zip
    case sevenZip = "7z"
//    case rar
//    case bzip2
    case tar
//    case gzip
}

package protocol ArchiveExtractor {
    func extract(at path: URL, to destination: URL) async throws -> [URL]
}

package struct ZipExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        try await withCheckedThrowingContinuation { continuation in
            SSZipArchive.unzipFile(atPath: path.path,
                                   toDestination: destination.path,
                                   overwrite: true,
                                   password: nil,
                                   progressHandler: { entry, _, entryNumber, total in
                                       if !entry.isEmpty {
                                           let url = destination.appendingPathComponent(entry)
                                           extractedFiles.append(url)
                                       }
                                   },
                                   completionHandler: { _, succeeded, error in
                                       if succeeded {
                                           continuation.resume(returning: ())
                                       } else if let error = error {
                                           continuation.resume(throwing: error)
                                       } else {
                                           continuation.resume(throwing: NSError(domain: "ZipExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during ZIP extraction"]))
                                       }
                                   })
        }

        return extractedFiles
    }
}

package struct SevenZipExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        let container = try Data(contentsOf: path)
        let entries = try SevenZipContainer.open(container: container)

        for item in entries where item.info.type != .directory {
            let fullPath = destination.appendingPathComponent(item.info.name)
            extractedFiles.append(fullPath)

            if let data = item.data {
                try data.write(to: fullPath, options: [.atomic, .noFileProtection])
            }
        }

        return extractedFiles
    }
}

package struct GZipExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        let container = try Data(contentsOf: path)
        let decompressedData = try GzipArchive.unarchive(archive: container)

        // Check if the decompressed data is a tar archive
        if let entries = try? TarContainer.open(container: decompressedData){
            // If it's a tar archive, use TarContainer to extract its contents
            for item in entries where item.info.type != .directory {
                let fullPath = destination.appendingPathComponent(item.info.name)

                if let data = item.data {
                    do {
                        try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                        extractedFiles.append(fullPath)
                    } catch {
                        ELOG("Extraction error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // If it's not a tar archive, assume it's a single file
            let fileName = path.deletingPathExtension().lastPathComponent
            let fullPath = destination.appendingPathComponent(fileName)

            try decompressedData.write(to: fullPath, options: [.atomic, .noFileProtection])
            extractedFiles.append(fullPath)
        }

        return extractedFiles
    }
}

package struct TarExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) async throws -> [URL] {
        var extractedFiles: [URL] = []

        let container = try Data(contentsOf: path)
        let entries = try TarContainer.open(container: container)

        for item in entries where item.info.type != .directory {
            let fullPath = destination.appendingPathComponent(item.info.name)
            extractedFiles.append(fullPath)

            if let data = item.data {
                try data.write(to: fullPath, options: [.atomic, .noFileProtection])
            }
        }

        return extractedFiles
    }
}
