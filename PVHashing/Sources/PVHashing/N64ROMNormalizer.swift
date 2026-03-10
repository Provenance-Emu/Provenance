import CryptoKit
import Foundation

/// N64 ROM byte-order formats
public enum N64ROMFormat {
    case z64   // Big-endian (native N64, canonical)
    case v64   // Word-swapped (every 2 bytes swapped)
    case n64   // Little-endian (every 4-byte group reversed)
    case unknown

    /// Magic bytes at start of file for each format:
    /// - z64: 0x80 0x37 0x12 0x40 (native N64 header)
    /// - v64: 0x37 0x80 0x40 0x12 (word-swapped)
    /// - n64: 0x40 0x12 0x37 0x80 (little-endian)
    public init(magicBytes: [UInt8]) {
        guard magicBytes.count >= 4 else {
            self = .unknown
            return
        }

        // Check for z64 format (big-endian, canonical)
        if magicBytes[0] == 0x80 && magicBytes[1] == 0x37 &&
           magicBytes[2] == 0x12 && magicBytes[3] == 0x40 {
            self = .z64
            return
        }

        // Check for v64 format (word-swapped)
        if magicBytes[0] == 0x37 && magicBytes[1] == 0x80 &&
           magicBytes[2] == 0x40 && magicBytes[3] == 0x12 {
            self = .v64
            return
        }

        // Check for n64 format (little-endian)
        if magicBytes[0] == 0x40 && magicBytes[1] == 0x12 &&
           magicBytes[2] == 0x37 && magicBytes[3] == 0x80 {
            self = .n64
            return
        }

        self = .unknown
    }
}

/// Normalizer for N64 ROM files to convert various byte-order formats
/// to the canonical .z64 (big-endian) format for MD5 hashing.
public enum N64ROMNormalizer {
    /// Detects the ROM format from the first 4 bytes of the file.
    public static func detectFormat(from data: Data) -> N64ROMFormat {
        guard data.count >= 4 else { return .unknown }
        let magicBytes = [data[0], data[1], data[2], data[3]]
        return N64ROMFormat(magicBytes: magicBytes)
    }

    /// Converts ROM data to canonical .z64 (big-endian) format.
    /// - Parameter data: The raw ROM data
    /// - Returns: Data in .z64 format, or nil if conversion fails
    public static func normalizeToZ64(_ data: Data) -> Data? {
        let format = detectFormat(from: data)

        switch format {
        case .z64:
            // Already in canonical format
            return data
        case .v64:
            return convertV64ToZ64(data)
        case .n64:
            return convertN64ToZ64(data)
        case .unknown:
            // Return as-is for unknown formats
            return data
        }
    }

    /// Converts v64 (word-swapped) format to z64 (big-endian).
    /// v64 swaps every 2 bytes: [A B C D] -> [B A D C]
    private static func convertV64ToZ64(_ data: Data) -> Data? {
        var result = Data(capacity: data.count)
        result.count = data.count

        data.withUnsafeBytes { sourceBytes in
            result.withUnsafeMutableBytes { destBytes in
                guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                      let dest = destBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                // Swap every pair of bytes: [B A] from [A B]
                for i in stride(from: 0, to: data.count, by: 2) {
                    if i + 1 < data.count {
                        dest[i] = source[i + 1]
                        dest[i + 1] = source[i]
                    } else {
                        // Odd byte at end, copy as-is
                        dest[i] = source[i]
                    }
                }
            }
        }

        return result
    }

    /// Converts n64 (little-endian) format to z64 (big-endian).
    /// n64 reverses every 4-byte group: [A B C D] -> [D C B A]
    private static func convertN64ToZ64(_ data: Data) -> Data? {
        var result = Data(capacity: data.count)
        result.count = data.count

        data.withUnsafeBytes { sourceBytes in
            result.withUnsafeMutableBytes { destBytes in
                guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                      let dest = destBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                // Reverse every 4-byte group: [D C B A] from [A B C D]
                for i in stride(from: 0, to: data.count, by: 4) {
                    let remaining = data.count - i
                    if remaining >= 4 {
                        dest[i] = source[i + 3]
                        dest[i + 1] = source[i + 2]
                        dest[i + 2] = source[i + 1]
                        dest[i + 3] = source[i]
                    } else {
                        // Less than 4 bytes remaining, copy as-is
                        for j in 0..<remaining {
                            dest[i + j] = source[i + j]
                        }
                    }
                }
            }
        }

        return result
    }
}

// MARK: - MD5 Calculation with Normalization

public extension N64ROMNormalizer {
    /// Calculates MD5 hash of an N64 ROM file, normalizing to .z64 format first.
    ///
    /// Streams the file in 1 MB chunks to avoid loading the entire ROM (up to 64 MB)
    /// into memory at once. Each chunk is byte-swap normalized before hashing.
    ///
    /// - Parameters:
    ///   - url: URL of the ROM file
    ///   - offset: Byte offset to start reading from (usually 0 for N64)
    /// - Returns: The MD5 hash string, or nil if calculation fails
    static func md5ForN64ROM(at url: URL, fromOffset offset: UInt = 0) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? fileHandle.close() }

        // Read first 4 bytes to detect format before seeking to the hash offset
        guard let headerData = try? fileHandle.read(upToCount: 4), headerData.count >= 4 else {
            return nil
        }
        let format = detectFormat(from: headerData)

        // Seek to hash start offset
        do {
            try fileHandle.seek(toOffset: UInt64(offset))
        } catch {
            return nil
        }

        var hasher = Insecure.MD5()
        // 1 MB buffer, divisible by 4 — keeps chunk alignment correct for
        // both v64 (2-byte swap) and n64 (4-byte swap).
        let bufferSize = 1024 * 1024

        do {
            while true {
                guard let chunk = try fileHandle.read(upToCount: bufferSize), !chunk.isEmpty else {
                    break
                }
                switch format {
                case .z64, .unknown:
                    hasher.update(data: chunk)
                case .v64:
                    hasher.update(data: swapBytePairsInChunk(chunk))
                case .n64:
                    hasher.update(data: reverseByteQuadsInChunk(chunk))
                }
            }
        } catch {
            return nil
        }

        let result = hasher.finalize()
        return result.map { String(format: "%02x", $0) }.joined().uppercased()
    }

    /// Async version of MD5 calculation for N64 ROMs.
    static func md5ForN64ROMAsync(at url: URL, fromOffset offset: UInt = 0) async -> String? {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let hash = md5ForN64ROM(at: url, fromOffset: offset)
                continuation.resume(returning: hash)
            }
        }
    }

    // MARK: - Private Chunk-Level Byte Swap Helpers

    /// Swaps byte pairs within a chunk for v64→z64 conversion: [A B C D] → [B A D C]
    private static func swapBytePairsInChunk(_ data: Data) -> Data {
        var result = data
        result.withUnsafeMutableBytes { bytes in
            guard let ptr = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = bytes.count
            var i = 0
            while i + 1 < count {
                let tmp = ptr[i]
                ptr[i] = ptr[i + 1]
                ptr[i + 1] = tmp
                i += 2
            }
        }
        return result
    }

    /// Reverses every 4-byte group within a chunk for n64→z64 conversion: [A B C D] → [D C B A]
    private static func reverseByteQuadsInChunk(_ data: Data) -> Data {
        var result = data
        result.withUnsafeMutableBytes { bytes in
            guard let ptr = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = bytes.count
            var i = 0
            while i + 3 < count {
                let a = ptr[i], b = ptr[i + 1], c = ptr[i + 2], d = ptr[i + 3]
                ptr[i] = d; ptr[i + 1] = c; ptr[i + 2] = b; ptr[i + 3] = a
                i += 4
            }
        }
        return result
    }
}
