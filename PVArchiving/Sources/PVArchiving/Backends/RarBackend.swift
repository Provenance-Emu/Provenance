//
//  RarBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging
#if canImport(Unrar)
import Unrar
#endif

public struct RarBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.rar
    public init() {}

    public func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard FileManager.default.fileExists(atPath: source.path) else {
                        throw ArchiveError.extractionFailed("RAR file does not exist: \(source.path)")
                    }
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    #if canImport(Unrar)
                    let archive = try Archive(path: source.path)
                    let entries = try archive.entries()
                    let total = entries.count
                    for (i, entry) in entries.enumerated() {
                        guard !entry.directory else { continue }
                        try autoreleasepool {
                            let sanitized = entry.fileName
                                .components(separatedBy: "/")
                                .filter { !$0.isEmpty && $0 != ".." && $0 != "." }
                                .joined(separator: "/")
                            guard !sanitized.isEmpty else { return }
                            let fullPath = destination.appendingPathComponent(sanitized)
                            guard fullPath.path.hasPrefix(destination.path) else { return }
                            try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                            let data = try archive.extract(entry)
                            try data.write(to: fullPath)
                            continuation.yield(fullPath)
                        }
                        progress(Double(i + 1) / Double(max(total, 1)))
                    }
                    #else
                    throw ArchiveError.backendUnavailable("Unrar")
                    #endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
