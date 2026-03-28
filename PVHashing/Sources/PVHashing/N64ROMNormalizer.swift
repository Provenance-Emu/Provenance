import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// N64 ROM byte-order formats
public enum N64ROMFormat: Equatable {
    case z64              // Big-endian (native N64, canonical)
    case v64              // Byte-swapped within 16-bit words
    case n64              // Little-endian (every 4-byte group reversed)
    case n64ByteSwapped   // Byte-mirrored variant (16-bit half-words swapped within each 32-bit word)
    case unknown

    /// Magic bytes at start of file for each format:
    /// - z64: 0x80 0x37 0x12 0x40 (native N64 header)
    /// - v64: 0x37 0x80 0x40 0x12 (byte-swapped within 16-bit words)
    /// - n64: 0x40 0x12 0x37 0x80 (little-endian, 4-byte reversal)
    /// - n64ByteSwapped: 0x12 0x40 0x80 0x37 (16-bit half-word swap of z64)
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

        // Check for v64 format (byte-swapped within 16-bit words)
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

        // Check for byte-mirrored variant (16-bit half-words swapped within 32-bit words)
        if magicBytes[0] == 0x12 && magicBytes[1] == 0x40 &&
           magicBytes[2] == 0x80 && magicBytes[3] == 0x37 {
            self = .n64ByteSwapped
            return
        }

        self = .unknown
    }

    /// The swap alignment boundary in bytes required for correct normalization.
    var swapAlignment: UInt {
        switch self {
        case .v64: return 2
        case .n64, .n64ByteSwapped: return 4
        case .z64, .unknown: return 1
        }
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
    /// For unknown formats, the input data is returned unchanged.
    /// - Parameter data: The raw ROM data
    /// - Returns: Data in .z64 format
    public static func normalizeToZ64(_ data: Data) -> Data {
        let format = detectFormat(from: data)

        switch format {
        case .z64:
            return data
        case .v64:
            return convertV64ToZ64(data)
        case .n64:
            return convertN64ToZ64(data)
        case .n64ByteSwapped:
            return convertN64ByteSwappedToZ64(data)
        case .unknown:
            return data
        }
    }

    /// Converts v64 (byte-swapped) format to z64 (big-endian).
    /// v64 swaps bytes within each 16-bit word: [A B C D] -> [B A D C]
    private static func convertV64ToZ64(_ data: Data) -> Data {
        var result = Data(count: data.count)

        data.withUnsafeBytes { sourceBytes in
            result.withUnsafeMutableBytes { destBytes in
                guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                      let dest = destBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                for i in stride(from: 0, to: data.count, by: 2) {
                    if i + 1 < data.count {
                        dest[i] = source[i + 1]
                        dest[i + 1] = source[i]
                    } else {
                        dest[i] = source[i]
                    }
                }
            }
        }

        return result
    }

    /// Converts n64 (little-endian) format to z64 (big-endian).
    /// n64 reverses every 4-byte group: [A B C D] -> [D C B A]
    private static func convertN64ToZ64(_ data: Data) -> Data {
        var result = Data(count: data.count)

        data.withUnsafeBytes { sourceBytes in
            result.withUnsafeMutableBytes { destBytes in
                guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                      let dest = destBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                for i in stride(from: 0, to: data.count, by: 4) {
                    let remaining = data.count - i
                    if remaining >= 4 {
                        dest[i] = source[i + 3]
                        dest[i + 1] = source[i + 2]
                        dest[i + 2] = source[i + 1]
                        dest[i + 3] = source[i]
                    } else {
                        for j in 0..<remaining {
                            dest[i + j] = source[i + j]
                        }
                    }
                }
            }
        }

        return result
    }

    /// Converts byte-mirrored variant to z64 (big-endian).
    /// Swaps the two 16-bit halves within each 32-bit word:
    /// [C D A B] -> [A B C D]
    private static func convertN64ByteSwappedToZ64(_ data: Data) -> Data {
        var result = Data(count: data.count)

        data.withUnsafeBytes { sourceBytes in
            result.withUnsafeMutableBytes { destBytes in
                guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress,
                      let dest = destBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }

                for i in stride(from: 0, to: data.count, by: 4) {
                    let remaining = data.count - i
                    if remaining >= 4 {
                        dest[i] = source[i + 2]
                        dest[i + 1] = source[i + 3]
                        dest[i + 2] = source[i]
                        dest[i + 3] = source[i + 1]
                    } else {
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
    ///   - offset: Byte offset to start reading from (typically 0 for N64).
    ///     Must be aligned to the format's swap boundary (2 for v64, 4 for n64/byte-mirrored).
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

        // Validate offset alignment for swap-based formats
        let alignment = format.swapAlignment
        guard offset % alignment == 0 else {
            return nil
        }

        // Seek to hash start offset
        do {
            try fileHandle.seek(toOffset: UInt64(offset))
        } catch {
            return nil
        }

        var hasher = Insecure.MD5()
        // 1 MB buffer, divisible by 4 — keeps chunk alignment correct for
        // v64 (2-byte swap), n64 (4-byte swap), and byte-mirrored (4-byte swap).
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
                case .n64ByteSwapped:
                    hasher.update(data: swapHalfWordsInChunk(chunk))
                }
            }
        } catch {
            return nil
        }

        let result = hasher.finalize()
        return result.map { String(format: "%02X", $0) }.joined()
    }

    /// Async version of MD5 calculation for N64 ROMs.
    static func md5ForN64ROMAsync(at url: URL, fromOffset offset: UInt = 0) async -> String? {
        await Task.detached(priority: .utility) {
            md5ForN64ROM(at: url, fromOffset: offset)
        }.value
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

    /// Swaps 16-bit half-words within each 32-bit word for byte-mirrored→z64 conversion: [C D A B] → [A B C D]
    private static func swapHalfWordsInChunk(_ data: Data) -> Data {
        var result = data
        result.withUnsafeMutableBytes { bytes in
            guard let ptr = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = bytes.count
            var i = 0
            while i + 3 < count {
                let a = ptr[i], b = ptr[i + 1]
                ptr[i] = ptr[i + 2]; ptr[i + 1] = ptr[i + 3]
                ptr[i + 2] = a; ptr[i + 3] = b
                i += 4
            }
        }
        return result
    }
}
