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
    /// - n64 mirrored: 0x12 0x40 0x80 0x37 (byte-mirrored variant)
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

        // Check for n64 byte-mirrored variant
        if magicBytes[0] == 0x12 && magicBytes[1] == 0x40 &&
           magicBytes[2] == 0x80 && magicBytes[3] == 0x37 {
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
    /// - Parameters:
    ///   - url: URL of the ROM file
    ///   - offset: Byte offset to start reading from (usually 0 for N64)
    /// - Returns: The MD5 hash string, or nil if calculation fails
    static func md5ForN64ROM(at url: URL, fromOffset offset: UInt = 0) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }

        let dataToHash: Data
        if offset > 0 && offset < data.count {
            dataToHash = data.subdata(in: Int(offset)..<data.count)
        } else {
            dataToHash = data
        }

        guard let normalizedData = normalizeToZ64(dataToHash) else {
            return nil
        }

        return normalizedData.md5.uppercased()
    }

    /// Async version of MD5 calculation for N64 ROMs.
    static func md5ForN64ROMAsync(at url: URL, fromOffset offset: UInt = 0) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let hash = md5ForN64ROM(at: url, fromOffset: offset)
                continuation.resume(returning: hash)
            }
        }
    }
}
