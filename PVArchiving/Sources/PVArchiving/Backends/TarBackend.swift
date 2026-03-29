//
//  TarBackend.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation
import PVLogging
import SWCompression

public struct TarBackend: ArchiveExtractorBackend {
    public static let format = ArchiveFormat.tar
    public init() {}

    public func extract(
        at source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try autoreleasepool {
                        let data = try Data(contentsOf: source)
                        let entries = try TarContainer.open(container: data)
                        for (i, item) in entries.enumerated() where item.info.type != .directory {
                            let fullPath = destination.appendingPathComponent(item.info.name)
                            try FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                            if let itemData = item.data {
                                try itemData.write(to: fullPath, options: [.atomic, .noFileProtection])
                            }
                            continuation.yield(fullPath)
                            progress(Double(i + 1) / Double(entries.count))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
