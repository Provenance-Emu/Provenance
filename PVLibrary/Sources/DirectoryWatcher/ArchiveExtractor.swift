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

package enum ArchiveType: String {
    case zip
    case sevenZip = "7z"
    case bzip2 = "bz2"
    case tar
    case gzip = "gz"
}

package protocol ArchiveExtractor {
    func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error>
}

package struct ZipExtractor: ArchiveExtractor {
    #if canImport(ZipArchive)
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await withCheckedThrowingContinuation { innerContinuation in
                        SSZipArchive.unzipFile(atPath: path.path,
                                               toDestination: destination.path,
                                               overwrite: true,
                                               password: nil,
                                               progressHandler: { entry, _, _, _ in
                                                   if !entry.isEmpty {
                                                       let url = destination.appendingPathComponent(entry)
                                                       continuation.yield(url)
                                                   }
                                               },
                                               completionHandler: { _, succeeded, error in
                                                   if succeeded {
                                                       innerContinuation.resume()
                                                   } else if let error = error {
                                                       innerContinuation.resume(throwing: error)
                                                   } else {
                                                       innerContinuation.resume(throwing: NSError(domain: "ZipExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during ZIP extraction"]))
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
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try Data(contentsOf: path)
                    let entries = try ZipContainer.open(container: container)

                    for item in entries where item.info.type != .directory {
                        let fullPath = destination.appendingPathComponent(item.info.name)
                        if let data = item.data {
                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                            continuation.yield(fullPath)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    #endif
}

package struct SevenZipExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try Data(contentsOf: path)
                    let entries = try SevenZipContainer.open(container: container)

                    for item in entries where item.info.type != .directory {
                        let fullPath = destination.appendingPathComponent(item.info.name)
                        if let data = item.data {
                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                            continuation.yield(fullPath)
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

package struct BZip2Extractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try Data(contentsOf: path)
                    let decompressedData = try BZip2.decompress(data: container)

                    if let entries = try? TarContainer.open(container: decompressedData) {
                        for item in entries where item.info.type != .directory {
                            let fullPath = destination.appendingPathComponent(item.info.name)
                            if let data = item.data {
                                try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                                continuation.yield(fullPath)
                            }
                        }
                    } else {
                        let fileName = path.deletingPathExtension().lastPathComponent
                        let fullPath = destination.appendingPathComponent(fileName)
                        try decompressedData.write(to: fullPath, options: [.atomic, .noFileProtection])
                        continuation.yield(fullPath)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

package struct GZipExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try Data(contentsOf: path)
                    let decompressedData = try GzipArchive.unarchive(archive: container)

                    if let entries = try? TarContainer.open(container: decompressedData) {
                        for item in entries where item.info.type != .directory {
                            let fullPath = destination.appendingPathComponent(item.info.name)
                            if let data = item.data {
                                try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                                continuation.yield(fullPath)
                            }
                        }
                    } else {
                        let fileName = path.deletingPathExtension().lastPathComponent
                        let fullPath = destination.appendingPathComponent(fileName)
                        try decompressedData.write(to: fullPath, options: [.atomic, .noFileProtection])
                        continuation.yield(fullPath)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

package struct TarExtractor: ArchiveExtractor {
    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let container = try Data(contentsOf: path)
                    let entries = try TarContainer.open(container: container)

                    for item in entries where item.info.type != .directory {
                        let fullPath = destination.appendingPathComponent(item.info.name)
                        if let data = item.data {
                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
                            continuation.yield(fullPath)
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

//package struct RarExtractor: ArchiveExtractor {
//    package func extract(at path: URL, to destination: URL) -> AsyncThrowingStream<URL, Error> {
//        AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let container = try Data(contentsOf: path)
//                    let entries = try TarContainer.open(container: container)
//
//                    for item in entries where item.info.type != .directory {
//                        let fullPath = destination.appendingPathComponent(item.info.name)
//                        if let data = item.data {
//                            try data.write(to: fullPath, options: [.atomic, .noFileProtection])
//                            continuation.yield(fullPath)
//                        }
//                    }
//                    continuation.finish()
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
//    }
//}
