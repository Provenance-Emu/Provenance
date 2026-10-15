//
//  FileDigest.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
#if canImport(zlib)
import zlib
#endif

/// Digests of a file computed in one streamed pass, so a multi-gigabyte disc image is never
/// loaded or mapped whole. The values equal the whole-file digests (`PatchHashing.sha256Hex`,
/// `md5Hex`, `patchCRC32`), which keeps cache keys and variant MD5s stable.
struct FileDigest: Sendable, Equatable {
    struct Kinds: OptionSet, Sendable {
        let rawValue: Int
        static let sha256 = Kinds(rawValue: 1 << 0)
        static let md5 = Kinds(rawValue: 1 << 1)
        static let crc32 = Kinds(rawValue: 1 << 2)
        static let all: Kinds = [.sha256, .md5, .crc32]
    }

    /// Lowercase hex, like `PatchHashing.sha256Hex`.
    var sha256: String?
    /// Uppercase hex, like `PatchHashing.md5Hex`.
    var md5: String?
    var crc32: UInt32?
    var size: UInt64

    /// Bytes read per chunk; matches the engine's copy buffer.
    static let chunkSize = 2 * 1024 * 1024

    /// - Parameter progress: called with the number of bytes read so far.
    static func compute(
        _ url: URL,
        kinds: Kinds,
        progress: ((UInt64) -> Void)? = nil
    ) throws -> FileDigest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

#if canImport(CryptoKit) || canImport(Crypto)
        var sha = kinds.contains(.sha256) ? SHA256() : nil
        var md5 = kinds.contains(.md5) ? Insecure.MD5() : nil
#endif
        var crc = CRC32Accumulator()
        var total: UInt64 = 0

        while true {
            try Task.checkCancellation()
            let done: Bool = try autoreleasepool {
                guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { return true }
#if canImport(CryptoKit) || canImport(Crypto)
                sha?.update(data: chunk)
                md5?.update(data: chunk)
#endif
                if kinds.contains(.crc32) { crc.update(chunk) }
                total += UInt64(chunk.count)
                return false
            }
            if done { break }
            progress?(total)
        }

        var digest = FileDigest(size: total)
#if canImport(CryptoKit) || canImport(Crypto)
        digest.sha256 = sha.map { $0.finalize().map { String(format: "%02x", $0) }.joined() }
        digest.md5 = md5.map { $0.finalize().map { String(format: "%02X", $0) }.joined() }
#else
        if kinds.contains(.sha256) || kinds.contains(.md5) {
            // Same fallback as PatchHashing: deterministic, not cryptographic.
            let data = try Data(contentsOf: url)
            digest.sha256 = PatchHashing.sha256Hex(data)
            digest.md5 = PatchHashing.md5Hex(data)
        }
#endif
        if kinds.contains(.crc32) { digest.crc32 = crc.value }
        return digest
    }
}

/// CRC-32/ISO-HDLC, the CRC that BPS, UPS and PPF use. zlib where the SDK has it (fast enough
/// for disc images); the table-driven `patchCRC32` loop otherwise.
struct CRC32Accumulator: Sendable {
    private var state: UInt32 = 0

    var value: UInt32 { state }

    mutating func update(_ data: Data) {
#if canImport(zlib)
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: Bytef.self).baseAddress else { return }
            var remaining = raw.count
            var pointer = base
            // zlib's length is a uInt; feed it in pieces that always fit.
            while remaining > 0 {
                let step = min(remaining, Int(Int32.max))
                state = UInt32(zlib.crc32(uLong(state), pointer, uInt(step)))
                pointer += step
                remaining -= step
            }
        }
#else
        state = patchCRC32Continue(state, data)
#endif
    }
}
