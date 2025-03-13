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
#if canImport(ZipArchive)
@_exported import ZipArchive
#endif
import Combine


public enum ArchiveError: Error {
    case invalidArchive
    case fileTooLarge
    case extractionFailed(String)
}

public enum ArchiveType: String, CaseIterable {
    case zip
    case sevenZip = "7z"
    case bzip2 = "bz2"
    case tar
    case gzip = "gz"
    case rar
}

protocol ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error>
}

class BaseExtractor: ArchiveExtractor {
    func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performExtraction(from: path, to: destination) { extractedPath in
                        continuation.yield(extractedPath)
                    } progress: { progressValue in
                        progress(progressValue)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        fatalError("Subclasses must implement this method")
    }
}

class ZipExtractor: BaseExtractor {
#if true
    override func extract(at path: URL, to destination: URL, progress: @escaping (Double) -> Void) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await withCheckedThrowingContinuation { innerContinuation in
                        SSZipArchive.unzipFile(atPath: path.path,
                                               toDestination: destination.path,
                                               overwrite: true,
                                               password: nil,
                                               progressHandler: { entry, fileInfo, entryNumber, total in
                            if !entry.isEmpty {
                                let url = destination.appendingPathComponent(entry)
                                continuation.yield(url)
                            }
                            progress(Double(entryNumber) / Double(total))
                        },
                                               completionHandler: { _, succeeded, error in
                            if succeeded {
                                innerContinuation.resume()
                            } else if let error = error {
                                innerContinuation.resume(throwing: error)
                            } else {
                                innerContinuation.resume(throwing: ArchiveError.extractionFailed("Unknown error during ZIP extraction"))
                            }
                        })
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
#else
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        let container = try Data(contentsOf: path)
        let entries = try ZipContainer.open(container: container)
        
        for (index, item) in entries.enumerated() where item.info.type != .directory {
            let fullPath = destination.appendingPathComponent(item.info.name)
            if let data = item.data {
                try await data.write(to: fullPath, options: [.atomic, .noFileProtection])
                yieldPath(fullPath)
            }
            progress(Double(index + 1) / Double(entries.count))
        }
    }
#endif
}

class SevenZipExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        try autoreleasepool {
            let container = try Data(contentsOf: path)
            
            // TODO: Large 7-zips are crashing here, can we use another 7zip?
            guard !container.isEmpty else { return }
            
            // 128mb?
            guard container.count <= 128_000_000 else {
                throw ArchiveError.fileTooLarge
            }
            let entries = try SevenZipContainer.open(container: container)
            
            for (index, item) in entries.enumerated() where item.info.type != .directory {
                autoreleasepool {
                    let fullPath = destination.appendingPathComponent(item.info.name)
                    Task {
                        if let data = item.data {
                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                        }
                    }
                    yieldPath(fullPath)
                    progress(Double(index + 1) / Double(entries.count))
                }
            }
        }
    }
}

class BZip2Extractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        let container = try Data(contentsOf: path)
        let decompressedData = try BZip2.decompress(data: container)
        try await extractCompressedData(decompressedData, at: path, to: destination, yieldPath: yieldPath, progress: progress)
    }
}

class GZipExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        let container = try Data(contentsOf: path)
        let decompressedData = try GzipArchive.unarchive(archive: container)
        try await extractCompressedData(decompressedData, at: path, to: destination, yieldPath: yieldPath, progress: progress)
    }
}

class TarExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        try autoreleasepool {
            
            let container = try Data(contentsOf: path)
            let entries = try TarContainer.open(container: container)
            
            for (index, item) in entries.enumerated() where item.info.type != .directory {
                autoreleasepool {
                    let fullPath = destination.appendingPathComponent(item.info.name)
                    Task {
                        if let data = item.data {
                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                        }
                    }
                    yieldPath(fullPath)
                    progress(Double(index + 1) / Double(entries.count))
                }
            }
        }
    }
}

private func extractCompressedData(_ data: Data, at path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
    if let entries = try? TarContainer.open(container: data) {
        for (index, item) in entries.enumerated() where item.info.type != .directory {
            autoreleasepool {
                let fullPath = destination.appendingPathComponent(item.info.name)
                Task {
                    if let itemData = item.data {
                        try itemData.write(to: fullPath, options: [.atomic, .noFileProtection])
                    }
                }
                yieldPath(fullPath)
                progress(Double(index + 1) / Double(entries.count))
            }
        }
    } else {
        let fileName = path.deletingPathExtension().lastPathComponent
        let fullPath = destination.appendingPathComponent(fileName)
        try data.write(to: fullPath, options: [.atomic, .noFileProtection])
        yieldPath(fullPath)
        progress(1.0)
    }
}
