import XCTest
@testable import PVHashing

class N64ROMNormalizerTests: XCTestCase {

    // MARK: - Format Detection Tests

    func testDetectZ64Format() {
        // z64 magic bytes: 0x80 0x37 0x12 0x40
        let magicBytes: [UInt8] = [0x80, 0x37, 0x12, 0x40]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .z64)
    }

    func testDetectV64Format() {
        // v64 magic bytes: 0x37 0x80 0x40 0x12
        let magicBytes: [UInt8] = [0x37, 0x80, 0x40, 0x12]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .v64)
    }

    func testDetectN64Format() {
        // n64 magic bytes: 0x40 0x12 0x37 0x80
        let magicBytes: [UInt8] = [0x40, 0x12, 0x37, 0x80]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .n64)
    }

    func testDetectN64ByteSwappedFormat() {
        // Byte-mirrored variant: 0x12 0x40 0x80 0x37
        // 16-bit half-words swapped within each 32-bit word relative to z64
        let magicBytes: [UInt8] = [0x12, 0x40, 0x80, 0x37]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .n64ByteSwapped)
    }

    func testDetectUnknownFormat() {
        // Unknown format
        let magicBytes: [UInt8] = [0x00, 0x00, 0x00, 0x00]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .unknown)
    }

    func testDetectFormatWithInsufficientBytes() {
        // Less than 4 bytes
        let magicBytes: [UInt8] = [0x80, 0x37]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .unknown)
    }

    func testDetectFormatFromData() {
        var data = Data(count: 4)
        data[0] = 0x80
        data[1] = 0x37
        data[2] = 0x12
        data[3] = 0x40

        let format = N64ROMNormalizer.detectFormat(from: data)
        XCTAssertEqual(format, .z64)
    }

    // MARK: - Swap Alignment Tests

    func testSwapAlignmentValues() {
        XCTAssertEqual(N64ROMFormat.z64.swapAlignment, 1)
        XCTAssertEqual(N64ROMFormat.v64.swapAlignment, 2)
        XCTAssertEqual(N64ROMFormat.n64.swapAlignment, 4)
        XCTAssertEqual(N64ROMFormat.n64ByteSwapped.swapAlignment, 4)
        XCTAssertEqual(N64ROMFormat.unknown.swapAlignment, 1)
    }

    // MARK: - Conversion Tests

    func testZ64NoConversionNeeded() {
        // z64 data should remain unchanged
        var data = Data(count: 8)
        data[0] = 0x80
        data[1] = 0x37
        data[2] = 0x12
        data[3] = 0x40
        data[4] = 0xAA
        data[5] = 0xBB
        data[6] = 0xCC
        data[7] = 0xDD

        let result = N64ROMNormalizer.normalizeToZ64(data)
        XCTAssertEqual(result, data)
    }

    func testV64ToZ64Conversion() {
        // v64 format: every 2 bytes are swapped
        // Input:  [0x37, 0x80, 0x40, 0x12, 0xAA, 0xBB, 0xCC, 0xDD]
        // Output: [0x80, 0x37, 0x12, 0x40, 0xBB, 0xAA, 0xDD, 0xCC]
        var v64Data = Data(count: 8)
        v64Data[0] = 0x37  // will become 0x80
        v64Data[1] = 0x80  // will become 0x37
        v64Data[2] = 0x40  // will become 0x12
        v64Data[3] = 0x12  // will become 0x40
        v64Data[4] = 0xAA  // will become 0xBB
        v64Data[5] = 0xBB  // will become 0xAA
        v64Data[6] = 0xCC  // will become 0xDD
        v64Data[7] = 0xDD  // will become 0xCC

        let result = N64ROMNormalizer.normalizeToZ64(v64Data)

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xBB)
        XCTAssertEqual(result[5], 0xAA)
        XCTAssertEqual(result[6], 0xDD)
        XCTAssertEqual(result[7], 0xCC)
    }

    func testN64ToZ64Conversion() {
        // n64 format: every 4-byte group is reversed
        // Input:  [0x40, 0x12, 0x37, 0x80, 0xAA, 0xBB, 0xCC, 0xDD]
        // Output: [0x80, 0x37, 0x12, 0x40, 0xDD, 0xCC, 0xBB, 0xAA]
        var n64Data = Data(count: 8)
        n64Data[0] = 0x40  // will become 0x80
        n64Data[1] = 0x12  // will become 0x37
        n64Data[2] = 0x37  // will become 0x12
        n64Data[3] = 0x80  // will become 0x40
        n64Data[4] = 0xAA  // will become 0xDD
        n64Data[5] = 0xBB  // will become 0xCC
        n64Data[6] = 0xCC  // will become 0xBB
        n64Data[7] = 0xDD  // will become 0xAA

        let result = N64ROMNormalizer.normalizeToZ64(n64Data)

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xDD)
        XCTAssertEqual(result[5], 0xCC)
        XCTAssertEqual(result[6], 0xBB)
        XCTAssertEqual(result[7], 0xAA)
    }

    func testN64ByteSwappedToZ64Conversion() {
        // Byte-mirrored: 16-bit half-words swapped within each 32-bit word
        // [C D A B] → [A B C D]
        // Input:  [0x12, 0x40, 0x80, 0x37, 0xCC, 0xDD, 0xAA, 0xBB]
        // Output: [0x80, 0x37, 0x12, 0x40, 0xAA, 0xBB, 0xCC, 0xDD]
        var bsData = Data(count: 8)
        bsData[0] = 0x12
        bsData[1] = 0x40
        bsData[2] = 0x80
        bsData[3] = 0x37
        bsData[4] = 0xCC
        bsData[5] = 0xDD
        bsData[6] = 0xAA
        bsData[7] = 0xBB

        let result = N64ROMNormalizer.normalizeToZ64(bsData)

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xAA)
        XCTAssertEqual(result[5], 0xBB)
        XCTAssertEqual(result[6], 0xCC)
        XCTAssertEqual(result[7], 0xDD)
    }

    func testV64OddByteCount() {
        // Test v64 conversion with odd number of bytes
        var v64Data = Data(count: 5)
        v64Data[0] = 0x37  // will become 0x80
        v64Data[1] = 0x80  // will become 0x37
        v64Data[2] = 0x40  // will become 0x12
        v64Data[3] = 0x12  // will become 0x40
        v64Data[4] = 0xAA  // stays as 0xAA (odd byte)

        let result = N64ROMNormalizer.normalizeToZ64(v64Data)

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xAA)
    }

    func testN64PartialGroup() {
        // Test n64 conversion with partial 4-byte group at end
        var n64Data = Data(count: 6)
        n64Data[0] = 0x40  // will become 0x80
        n64Data[1] = 0x12  // will become 0x37
        n64Data[2] = 0x37  // will become 0x12
        n64Data[3] = 0x80  // will become 0x40
        n64Data[4] = 0xAA  // stays as 0xAA (partial group)
        n64Data[5] = 0xBB  // stays as 0xBB (partial group)

        let result = N64ROMNormalizer.normalizeToZ64(n64Data)

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xAA)
        XCTAssertEqual(result[5], 0xBB)
    }

    func testUnknownFormatPassthrough() {
        // Unknown format should pass through unchanged
        let unknownData = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        let result = N64ROMNormalizer.normalizeToZ64(unknownData)
        XCTAssertEqual(result, unknownData)
    }

    func testEmptyData() {
        // Empty data should be handled
        let emptyData = Data()

        let result = N64ROMNormalizer.normalizeToZ64(emptyData)
        XCTAssertEqual(result, emptyData)
    }

    // MARK: - Round-trip MD5 Tests

    func testV64ProducesSameMD5AsZ64() {
        // Create z64 canonical data
        var z64Data = Data(count: 16)
        z64Data[0] = 0x80
        z64Data[1] = 0x37
        z64Data[2] = 0x12
        z64Data[3] = 0x40
        for i in 4..<16 {
            z64Data[i] = UInt8(i)
        }

        // Create equivalent v64 data (byte-swapped within 16-bit words)
        var v64Data = Data(count: 16)
        v64Data[0] = 0x37
        v64Data[1] = 0x80
        v64Data[2] = 0x40
        v64Data[3] = 0x12
        for i in 4..<16 {
            // Swap pairs: index 4 becomes 5, 5 becomes 4, etc.
            v64Data[i] = (i % 2 == 0) ? UInt8(i + 1) : UInt8(i - 1)
        }

        let normalizedV64 = N64ROMNormalizer.normalizeToZ64(v64Data)

        let z64MD5 = z64Data.md5
        let normalizedMD5 = normalizedV64.md5

        XCTAssertEqual(z64MD5, normalizedMD5, "v64 normalized to z64 should produce same MD5 as original z64")
    }

    func testN64ProducesSameMD5AsZ64() {
        // Create z64 canonical data
        var z64Data = Data(count: 16)
        z64Data[0] = 0x80
        z64Data[1] = 0x37
        z64Data[2] = 0x12
        z64Data[3] = 0x40
        for i in 4..<16 {
            z64Data[i] = UInt8(i)
        }

        // Create equivalent n64 data (4-byte groups reversed)
        var n64Data = Data(count: 16)
        n64Data[0] = 0x40
        n64Data[1] = 0x12
        n64Data[2] = 0x37
        n64Data[3] = 0x80
        for i in stride(from: 4, to: 16, by: 4) {
            n64Data[i] = UInt8(i + 3)
            n64Data[i + 1] = UInt8(i + 2)
            n64Data[i + 2] = UInt8(i + 1)
            n64Data[i + 3] = UInt8(i)
        }

        let normalizedN64 = N64ROMNormalizer.normalizeToZ64(n64Data)

        let z64MD5 = z64Data.md5
        let normalizedMD5 = normalizedN64.md5

        XCTAssertEqual(z64MD5, normalizedMD5, "n64 normalized to z64 should produce same MD5 as original z64")
    }

    func testN64ByteSwappedProducesSameMD5AsZ64() {
        // Create z64 canonical data
        var z64Data = Data(count: 16)
        z64Data[0] = 0x80
        z64Data[1] = 0x37
        z64Data[2] = 0x12
        z64Data[3] = 0x40
        for i in 4..<16 {
            z64Data[i] = UInt8(i)
        }

        // Create equivalent byte-mirrored data (16-bit half-words swapped within 32-bit words)
        // z64 [A B C D] → byteSwapped [C D A B]
        var bsData = Data(count: 16)
        bsData[0] = 0x12   // z64[2]
        bsData[1] = 0x40   // z64[3]
        bsData[2] = 0x80   // z64[0]
        bsData[3] = 0x37   // z64[1]
        for i in stride(from: 4, to: 16, by: 4) {
            bsData[i] = UInt8(i + 2)       // z64[i+2]
            bsData[i + 1] = UInt8(i + 3)   // z64[i+3]
            bsData[i + 2] = UInt8(i)       // z64[i]
            bsData[i + 3] = UInt8(i + 1)   // z64[i+1]
        }

        let normalizedBS = N64ROMNormalizer.normalizeToZ64(bsData)

        let z64MD5 = z64Data.md5
        let normalizedMD5 = normalizedBS.md5

        XCTAssertEqual(z64MD5, normalizedMD5, "byte-mirrored normalized to z64 should produce same MD5 as original z64")
    }

    // MARK: - File-based MD5 Tests

    func testMD5ForZ64File() throws {
        // Create a z64 file and verify MD5
        var z64Data = Data(count: 32)
        z64Data[0] = 0x80
        z64Data[1] = 0x37
        z64Data[2] = 0x12
        z64Data[3] = 0x40
        for i in 4..<32 { z64Data[i] = UInt8(i & 0xFF) }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_z64_\(UUID().uuidString).z64")
        try z64Data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let md5 = N64ROMNormalizer.md5ForN64ROM(at: tempURL)
        XCTAssertNotNil(md5)

        // MD5 of z64 file should match MD5 of the raw data
        let expectedMD5 = z64Data.md5.uppercased()
        XCTAssertEqual(md5, expectedMD5)
    }

    func testMD5ForV64FileMatchesZ64() throws {
        // Create equivalent z64 and v64 files, verify they produce the same MD5
        var z64Data = Data(count: 32)
        z64Data[0] = 0x80; z64Data[1] = 0x37; z64Data[2] = 0x12; z64Data[3] = 0x40
        for i in 4..<32 { z64Data[i] = UInt8(i & 0xFF) }

        // Build v64 by pair-swapping the z64 data
        var v64Data = Data(count: 32)
        for i in stride(from: 0, to: 32, by: 2) {
            v64Data[i] = z64Data[i + 1]
            v64Data[i + 1] = z64Data[i]
        }

        let z64URL = FileManager.default.temporaryDirectory.appendingPathComponent("test_z64_match_\(UUID().uuidString).z64")
        let v64URL = FileManager.default.temporaryDirectory.appendingPathComponent("test_v64_match_\(UUID().uuidString).v64")
        try z64Data.write(to: z64URL)
        try v64Data.write(to: v64URL)
        defer {
            try? FileManager.default.removeItem(at: z64URL)
            try? FileManager.default.removeItem(at: v64URL)
        }

        let z64MD5 = N64ROMNormalizer.md5ForN64ROM(at: z64URL)
        let v64MD5 = N64ROMNormalizer.md5ForN64ROM(at: v64URL)

        XCTAssertNotNil(z64MD5)
        XCTAssertNotNil(v64MD5)
        XCTAssertEqual(z64MD5, v64MD5, "v64 file should produce same MD5 as equivalent z64 file")
    }

    func testMD5ForN64ByteSwappedFileMatchesZ64() throws {
        var z64Data = Data(count: 32)
        z64Data[0] = 0x80; z64Data[1] = 0x37; z64Data[2] = 0x12; z64Data[3] = 0x40
        for i in 4..<32 { z64Data[i] = UInt8(i & 0xFF) }

        // Build byte-mirrored data by swapping 16-bit halves within each 32-bit word
        var bsData = Data(count: 32)
        for i in stride(from: 0, to: 32, by: 4) {
            bsData[i] = z64Data[i + 2]
            bsData[i + 1] = z64Data[i + 3]
            bsData[i + 2] = z64Data[i]
            bsData[i + 3] = z64Data[i + 1]
        }

        let z64URL = FileManager.default.temporaryDirectory.appendingPathComponent("test_z64_bs_\(UUID().uuidString).z64")
        let bsURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_bs_\(UUID().uuidString).n64")
        try z64Data.write(to: z64URL)
        try bsData.write(to: bsURL)
        defer {
            try? FileManager.default.removeItem(at: z64URL)
            try? FileManager.default.removeItem(at: bsURL)
        }

        let z64MD5 = N64ROMNormalizer.md5ForN64ROM(at: z64URL)
        let bsMD5 = N64ROMNormalizer.md5ForN64ROM(at: bsURL)

        XCTAssertNotNil(z64MD5)
        XCTAssertNotNil(bsMD5)
        XCTAssertEqual(z64MD5, bsMD5, "byte-mirrored file should produce same MD5 as equivalent z64 file")
    }
}
