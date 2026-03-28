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
#if canImport(PLzmaSDK)
import PLzmaSDK
#endif
#if canImport(LzhArchive)
import LzhArchive
#endif
#if canImport(Unrar)
import Unrar
#endif
import Combine


public enum ArchiveError: Error, LocalizedError, Sendable {
    case invalidArchive
    case fileTooLarge
    case extractionFailed(String)
    /// Thrown when one or more extracted files could not be moved to the import
    /// directory.  The archive and temp directory are preserved so the user can
    /// retry.  `succeeded` is the number of files that were moved successfully;
    /// `total` is the total number of files that were extracted.
    case batchMoveFailed(succeeded: Int, total: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The archive file is invalid or in an unsupported format."
        case .fileTooLarge:
            return "The archive file is too large to extract."
        case .extractionFailed(let message):
            return message
        case .batchMoveFailed(let succeeded, let total):
            let failed = total - succeeded
            return "Failed to move \(failed) of \(total) extracted file(s) to the import directory. "
                + "The archive and extracted files have been preserved for retry."
        }
    }
}

public enum ArchiveType: String, CaseIterable, Sendable {
    case zip
    case sevenZip = "7z"
    case bzip2 = "bz2"
    case tar
    case gzip = "gz"
    case rar
    case lzh  // covers both .lzh and .lha extensions
    case xz

    /// Additional file extensions that map to this archive type (beyond the rawValue).
    var alternateExtensions: [String] {
        switch self {
        case .bzip2: return ["bzip2"]
        case .gzip: return ["gzip"]
        case .lzh: return ["lha"]
        default: return []
        }
    }

    static func from(fileExtension ext: String) -> ArchiveType? {
        let lower = ext.lowercased()
        return ArchiveType.allCases.first {
            $0.rawValue == lower || $0.alternateExtensions.contains(lower)
        }
    }
}

/// Backend selection for 7z archive extraction
public enum SevenZipBackend: Sendable {
    case swCompression
    case plzmaSDK
}

/// Global variable controlling which backend to use for 7z extraction
/// Defaults to PLzmaSDK for better large file support with streaming
public var sevenZipExtractionBackend: SevenZipBackend = .plzmaSDK

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
                    // Verify file exists and is readable before attempting extraction
                    guard FileManager.default.fileExists(atPath: path.path) else {
                        throw ArchiveError.extractionFailed("ZIP file does not exist: \(path.path)")
                    }

                    // Verify file size
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
                       let fileSize = attributes[.size] as? Int64 {
                        if fileSize == 0 {
                            throw ArchiveError.extractionFailed("ZIP file is empty: \(path.lastPathComponent)")
                        }
                        ILOG("Attempting to extract ZIP file: \(path.lastPathComponent) (size: \(fileSize) bytes)")
                    }

                    // Verify destination directory exists
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)

                    ILOG("Calling SSZipArchive.unzipFile with path: \(path.path), destination: \(destination.path)")

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
                                               completionHandler: { archivePath, succeeded, error in
                            if succeeded {
                                ILOG("SSZipArchive.unzipFile succeeded for: \(archivePath ?? path.path)")
                                innerContinuation.resume()
                            } else if let error = error {
                                let errorMsg = "SSZipArchive.unzipFile failed for \(archivePath ?? path.path): \(error.localizedDescription)"
                                ELOG(errorMsg)
                                innerContinuation.resume(throwing: error)
                            } else {
                                let errorMsg = "SSZipArchive.unzipFile failed for \(archivePath ?? path.path): Unknown error"
                                ELOG(errorMsg)
                                innerContinuation.resume(throwing: ArchiveError.extractionFailed(errorMsg))
                            }
                        })
                    }
                    continuation.finish()
                } catch {
                    ELOG("ZipExtractor error: \(error.localizedDescription)")
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

/// Extracts 7z archives using either SWCompression or PLzmaSDK based on backend selection
/// PLzmaSDK supports streaming extraction and can handle larger files without memory issues
class SevenZipExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        switch sevenZipExtractionBackend {
        case .plzmaSDK:
            do {
                try await performPLzmaSDKExtraction(from: path, to: destination, yieldPath: yieldPath, progress: progress)
            } catch {
                WLOG("PLzmaSDK extraction failed: \(error.localizedDescription). Falling back to SWCompression.")
                try await performSWCompressionExtraction(from: path, to: destination, yieldPath: yieldPath, progress: progress)
            }
        case .swCompression:
            try await performSWCompressionExtraction(from: path, to: destination, yieldPath: yieldPath, progress: progress)
        }
    }

    /// Extraction using PLzmaSDK with streaming support for large files
    private func performPLzmaSDKExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        #if canImport(PLzmaSDK)
        try autoreleasepool {
            guard FileManager.default.fileExists(atPath: path.path) else {
                throw ArchiveError.extractionFailed("7z file does not exist: \(path.path)")
            }

            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)

            let archivePath = try Path(path.path)
            let archiveInStream = try InStream(path: archivePath)
            let decoder = try Decoder(stream: archiveInStream, fileType: .sevenZ)

            guard try decoder.open() else {
                throw ArchiveError.extractionFailed("Failed to open archive")
            }

            let totalItems = try decoder.count()
            guard totalItems > 0 else {
                throw ArchiveError.extractionFailed("Archive is empty")
            }

            ILOG("Extracting 7z archive using PLzmaSDK: \(path.lastPathComponent) (\(totalItems) items)")

            var fileCount = 0
            var extractedCount = 0

            for itemIndex in 0..<totalItems {
                let item = try decoder.item(at: itemIndex)

                if item.isDir {
                    let itemPath = try item.path()
                    let itemPathString = itemPath.description
                    let fullPath = destination.appendingPathComponent(itemPathString)
                    try FileManager.default.createDirectory(at: fullPath, withIntermediateDirectories: true, attributes: nil)
                } else {
                    fileCount += 1
                }
            }

            for itemIndex in 0..<totalItems {
                let item = try decoder.item(at: itemIndex)

                guard !item.isDir else { continue }

                let itemPath = try item.path()
                let itemPathString = itemPath.description
                let fullPath = destination.appendingPathComponent(itemPathString)
                let parentDir = fullPath.deletingLastPathComponent()

                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)

                let itemsToStreams = try ItemOutStreamArray()
                let outputPath = try Path(fullPath.path)
                let outStream = try OutStream(path: outputPath)
                try itemsToStreams.add(item: item, stream: outStream)

                guard try decoder.extract(itemsToStreams: itemsToStreams) else {
                    throw ArchiveError.extractionFailed("Failed to extract item: \(itemPathString)")
                }

                yieldPath(fullPath)
                extractedCount += 1
                progress(Double(extractedCount) / Double(fileCount))
            }
        }
        #else
        throw ArchiveError.extractionFailed("PLzmaSDK is not available. Falling back to SWCompression.")
        #endif
    }

    /// Extraction using SWCompression (legacy method, loads entire archive into memory)
    private func performSWCompressionExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        try autoreleasepool {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            let maxSize: Int64 = 1_000_000_000 // 1GB
            guard fileSize <= maxSize else {
                let sizeMB = fileSize / 1_000_000
                let maxMB = maxSize / 1_000_000
                throw ArchiveError.extractionFailed("7z file is too large (\(sizeMB) MB). Maximum supported size is \(maxMB) MB. Please use PLzmaSDK backend for larger archives.")
            }

            if fileSize > 500_000_000 { // 500MB
                let sizeMB = fileSize / 1_000_000
                WLOG("Extracting large 7z file (\(sizeMB) MB) using SWCompression. This may use significant memory.")
            }

            let container = try Data(contentsOf: path)
            guard !container.isEmpty else { return }

            let entries = try SevenZipContainer.open(container: container)

            for (index, item) in entries.enumerated() where item.info.type != .directory {
                try autoreleasepool {
                    let fullPath = destination.appendingPathComponent(item.info.name)
                    if let data = item.data {
                        try data.write(to: fullPath, options: [.atomic, .noFileProtection])
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

class XZExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        // XZArchive loads the entire file into memory. Warn for large files.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
           let fileSize = attributes[.size] as? Int64, fileSize > 200_000_000 {
            WLOG("XZExtractor: loading \(fileSize / 1_000_000) MB XZ file into memory — consider chunked extraction for very large archives")
        }
        let container = try Data(contentsOf: path)
        let decompressedData = try XZArchive.unarchive(archive: container)
        try await extractCompressedData(decompressedData, at: path, to: destination, yieldPath: yieldPath, progress: progress)
    }
}

class LzhExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ArchiveError.extractionFailed("LZH file does not exist: \(path.path)")
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        #if canImport(LzhArchive)
        let succeeded = LzhArchive.unLzhFile(atPath: path.path, toDestination: destination.path, overwrite: true)
        guard succeeded else {
            throw ArchiveError.extractionFailed("LzhArchive failed to extract: \(path.lastPathComponent)")
        }
        let extractedFiles = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
        for file in extractedFiles {
            yieldPath(file)
        }
        progress(1.0)
        #else
        throw ArchiveError.extractionFailed("LzhArchive is not available")
        #endif
    }
}

class RarExtractor: BaseExtractor {
    override func performExtraction(from path: URL, to destination: URL, yieldPath: (URL) -> Void, progress: (Double) -> Void) async throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ArchiveError.extractionFailed("RAR file does not exist: \(path.path)")
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        #if canImport(Unrar)
        let archive = try Archive(path: path.path)
        let entries = try archive.entries()
        let total = entries.count
        for (index, entry) in entries.enumerated() {
            guard !entry.directory else { continue }
            // Sanitize entry filename to prevent path traversal (e.g. "../" components)
            let sanitizedName = entry.fileName
                .components(separatedBy: "/")
                .filter { !$0.isEmpty && $0 != ".." && $0 != "." }
                .joined(separator: "/")
            guard !sanitizedName.isEmpty else {
                WLOG("RarExtractor: skipping entry with unsafe path: \(entry.fileName)")
                continue
            }
            let fullPath = destination.appendingPathComponent(sanitizedName)
            // Verify the resolved path is still within the destination directory
            guard fullPath.path.hasPrefix(destination.path) else {
                WLOG("RarExtractor: skipping entry that escapes destination: \(entry.fileName)")
                continue
            }
            let parentDir = fullPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            let data = try archive.extract(entry)
            try data.write(to: fullPath)
            yieldPath(fullPath)
            progress(Double(index + 1) / Double(max(total, 1)))
        }
        #else
        throw ArchiveError.extractionFailed("Unrar is not available")
        #endif
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
