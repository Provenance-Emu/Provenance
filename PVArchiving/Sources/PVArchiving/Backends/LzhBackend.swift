//
//  LzhBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging
#if canImport(LzhArchive)
import LzhArchive
#endif

public struct LzhBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.lzh
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
                        throw ArchiveError.extractionFailed("LZH file does not exist: \(source.path)")
                    }
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    #if canImport(LzhArchive)
                    let succeeded = LzhArchive.unLzhFile(atPath: source.path, toDestination: destination.path, overwrite: true)
                    guard succeeded else {
                        throw ArchiveError.extractionFailed("LZH extraction failed: \(source.lastPathComponent)")
                    }
                    let files = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
                    for file in files { continuation.yield(file) }
                    progress(1.0)
                    #else
                    throw ArchiveError.backendUnavailable("LzhArchive")
                    #endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
