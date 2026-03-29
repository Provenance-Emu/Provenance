//
//  SevenZipBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging
import SWCompression
#if canImport(PLzmaSDK)
import PLzmaSDK
#endif

/// Backend selection for 7z extraction.
public enum SevenZipEngine: Sendable {
    /// SWCompression: pure Swift, loads archive into memory. Good for <500 MB.
    case swCompression
    /// PLzmaSDK: streaming C++ backend. Handles multi-GB archives.
    case plzmaSDK
}

public struct SevenZipBackend: ArchiveExtractorBackend, ArchiveListingBackend {
    public static let format = ArchiveFormat.sevenZip

    /// Which engine to prefer. Defaults to PLzmaSDK with SWCompression fallback.
    public var engine: SevenZipEngine

    public init(engine: SevenZipEngine = .plzmaSDK) {
        self.engine = engine
    }

    public func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    switch engine {
                    case .plzmaSDK:
                        do {
                            try extractPLzma(from: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                        } catch {
                            WLOG("PLzmaSDK failed: \(error.localizedDescription). Falling back to SWCompression.")
                            try extractSWCompression(from: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                        }
                    case .swCompression:
                        try extractSWCompression(from: source, to: destination, yield: { continuation.yield($0) }, progress: progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - PLzmaSDK

    private func extractPLzma(from source: URL, to destination: URL, yield: (URL) -> Void, progress: (Double) -> Void) throws {
        #if canImport(PLzmaSDK)
        try autoreleasepool {
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw ArchiveError.extractionFailed("7z file does not exist: \(source.path)")
            }
            let archivePath = try Path(source.path)
            let stream = try InStream(path: archivePath)
            let decoder = try Decoder(stream: stream, fileType: .sevenZ)
            guard try decoder.open() else {
                throw ArchiveError.extractionFailed("Failed to open 7z archive")
            }
            let total = try decoder.count()
            guard total > 0 else {
                throw ArchiveError.extractionFailed("7z archive is empty")
            }

            // First pass: create directories
            for i in 0..<total {
                let item = try decoder.item(at: i)
                if item.isDir {
                    let dir = destination.appendingPathComponent(try item.path().description)
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
            }
            // Second pass: extract files
            var extracted = 0
            for i in 0..<total {
                let item = try decoder.item(at: i)
                guard !item.isDir else { continue }
                let name = try item.path().description
                let fullPath = destination.appendingPathComponent(name)
                try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                let outStream = try OutStream(path: try Path(fullPath.path))
                let streams = try ItemOutStreamArray()
                try streams.add(item: item, stream: outStream)
                guard try decoder.extract(itemsToStreams: streams) else {
                    throw ArchiveError.extractionFailed("Failed to extract: \(name)")
                }
                yield(fullPath)
                extracted += 1
                progress(Double(extracted) / Double(total))
            }
        }
        #else
        throw ArchiveError.backendUnavailable("PLzmaSDK")
        #endif
    }

    // MARK: - SWCompression

    private func extractSWCompression(from source: URL, to destination: URL, yield: (URL) -> Void, progress: (Double) -> Void) throws {
        try autoreleasepool {
            let attrs = try FileManager.default.attributesOfItem(atPath: source.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size > 1_000_000_000 {
                throw ArchiveError.fileTooLarge(size)
            }
            let data = try Data(contentsOf: source)
            guard !data.isEmpty else { return }
            let entries = try SevenZipContainer.open(container: data)
            for (i, item) in entries.enumerated() where item.info.type != .directory {
                let fullPath = destination.appendingPathComponent(item.info.name)
                try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let itemData = item.data {
                    try itemData.write(to: fullPath, options: [.atomic, .noFileProtection])
                }
                yield(fullPath)
                progress(Double(i + 1) / Double(entries.count))
            }
        }
    }

    // MARK: - Listing

    public func listEntries(at source: URL) throws -> [ArchiveEntryInfo] {
        let data = try Data(contentsOf: source)
        let entries = try SevenZipContainer.open(container: data)
        return entries.map { entry in
            ArchiveEntryInfo(
                name: entry.info.name,
                size: entry.info.size.map { Int64($0) },
                isDirectory: entry.info.type == .directory,
                crc: entry.info.crc
            )
        }
    }
}
