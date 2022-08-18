//
//  Extractor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
@_exported import PVSupport
import RxSwift
import SWCompression
import Compression

public enum CompressionFormats {
    case lzma
    case zlib
}

public enum ArchiveFormats {
    case bzip
    case gzip
    case sevenZip
    case tar
    case xz
}

public struct DecompressedEntry {
    let data: Data?
    let info: ContainerEntryInfo
}

public enum ExtractionError: Error {
    case unknownCompressionMethod
}

public protocol Compressor {
    class func compress(data: Data) throws -> Data
//    class func decompress(data: Data) async throws -> Data
}

public protocol Decompressor {
    class func decompress(data: Data) throws -> Data
//    class func decompress(data: Data) async throws -> Data
}
//
//public final class ZLIB: Decompressor {
//    class func decompress(data: Data) throws -> Data {
//        return try data.decompressed(using: .zlib)
//    }
//}
//
//public final class LZ4: Decompressor {
//    class func decompress(data: Data) throws -> Data {
//        return try data.decompressed(using: .lz4)
//    }
//}
//
//public final class LZFSE: Decompressor {
//    class func decompress(data: Data) throws -> Data {
//        return try data.decompressed(using: .lz4)
//    }
//}
//
//public final class LZMA: Decompressor {
//    class func decompress(data: Data) throws -> Data {
//        data.decompressed(using: .lzma)
//    }
//}
//
//public final class LZMA2: Decompressor {
//    class func decompress(data: Data) throws -> Data {
//
//    }
//}

extension SWCompression.CompressionMethod {
    func decompress(data: Data) throws -> Data {
        let decompressedData: Data
        switch self {
        case .bzip2:
            decompressedData = try BZip2.decompress(data: data)
        case .copy:
            decompressedData = data
        case .deflate:
            decompressedData = try Deflate.decompress(data: data)
        case .lzma:
            decompressedData = try LZMA.decompress(data: data)
        case .lzma2:
            decompressedData = try LZMA2.decompress(data: data)
        case .other:
            throw ExtractionError.unknownCompressionMethod
        }
        return decompressedData
    }
}

/// WIP Class. SWCompression supports multiple containers and compression types, but it's very
/// unclear how to decompress containers with mutliple files. It's very manual in compresspressing
/// and decompressing single instances of Data.
public final class Extractor {
    let queueLabel = "com.provenance.extractor"
    static let shared: Extractor = Extractor()

    let dispatchQueue = DispatchQueue(label: queueLabel, qos: .utility)
    let queue: OperationQueueScheduler = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let scheduler = OperationQueueScheduler(operationQueue: operationQueue, queuePriority: .low)
        return scheduler
    }()

    private func data(at path: URL) async -> Data {
//        return try await Data(contentsOf: path, options: .mappedIfSafe)
        return Task {
            return try Data(contentsOf: path, options: .mappedIfSafe)
        }
    }

    // MAR: - 7Zip
    private func openSevenZip(with data: Data) -> Promise<[SevenZipEntry]> {
        return Promise<[SevenZipEntry]> {
            try SevenZipContainer.open(container: data)
        }
    }

    private func decompress(entries: [SevenZipEntry]) -> Promise<[DecompressedEntry]> {
        return Promise<[DecompressedEntry]> { () -> [DecompressedEntry] in
            entries.compactMap {
                guard let data = $0.data else {
                    ELOG("Nil data")
                    return nil
                }

                return DecompressedEntry(data: data, info: $0.info)
            }
        }
    }

    // MARK: - Zip

    private func openZip(with data: Data) -> Promise<[ZipEntry]> {
        return Promise(on: dispatchQueue, { () -> [ZipEntry] in
            try ZipContainer.open(container: data)
        })
    }

    private func decompress(entries: [ZipEntry]) -> Promise<[DecompressedEntry]> {
        return Promise<[DecompressedEntry]> { () -> [DecompressedEntry] in
            entries.compactMap {
                guard let data = $0.data else {
                    ELOG("Nil data")
                    return nil
                }

                do {
                    let decompressedData: Data = try $0.info.compressionMethod.decompress(data: data)
                    return DecompressedEntry(data: decompressedData, info: $0.info)
                } catch let error as ZipError {
                    ELOG("ZipError failed: \(error)")
                    return nil
                } catch {
                    ELOG("Decompression failed: \(error)")
                    return nil
                }
            }
        }
    }
}
