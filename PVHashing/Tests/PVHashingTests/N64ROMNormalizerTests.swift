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

    func testDetectN64MirroredFormat() {
        // n64 byte-mirrored variant: 0x12 0x40 0x80 0x37
        let magicBytes: [UInt8] = [0x12, 0x40, 0x80, 0x37]
        let format = N64ROMFormat(magicBytes: magicBytes)
        XCTAssertEqual(format, .n64)
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

        guard let result = N64ROMNormalizer.normalizeToZ64(data) else {
            XCTFail("Normalization failed")
            return
        }

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

        guard let result = N64ROMNormalizer.normalizeToZ64(v64Data) else {
            XCTFail("Normalization failed")
            return
        }

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

        guard let result = N64ROMNormalizer.normalizeToZ64(n64Data) else {
            XCTFail("Normalization failed")
            return
        }

        XCTAssertEqual(result[0], 0x80)
        XCTAssertEqual(result[1], 0x37)
        XCTAssertEqual(result[2], 0x12)
        XCTAssertEqual(result[3], 0x40)
        XCTAssertEqual(result[4], 0xDD)
        XCTAssertEqual(result[5], 0xCC)
        XCTAssertEqual(result[6], 0xBB)
        XCTAssertEqual(result[7], 0xAA)
    }

    func testV64OddByteCount() {
        // Test v64 conversion with odd number of bytes
        var v64Data = Data(count: 5)
        v64Data[0] = 0x37  // will become 0x80
        v64Data[1] = 0x80  // will become 0x37
        v64Data[2] = 0x40  // will become 0x12
        v64Data[3] = 0x12  // will become 0x40
        v64Data[4] = 0xAA  // stays as 0xAA (odd byte)

        guard let result = N64ROMNormalizer.normalizeToZ64(v64Data) else {
            XCTFail("Normalization failed")
            return
        }

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

        guard let result = N64ROMNormalizer.normalizeToZ64(n64Data) else {
            XCTFail("Normalization failed")
            return
        }

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

        guard let result = N64ROMNormalizer.normalizeToZ64(unknownData) else {
            XCTFail("Normalization failed")
            return
        }

        XCTAssertEqual(result, unknownData)
    }

    func testEmptyData() {
        // Empty data should be handled
        let emptyData = Data()

        guard let result = N64ROMNormalizer.normalizeToZ64(emptyData) else {
            XCTFail("Normalization failed")
            return
        }

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

        // Create equivalent v64 data (word-swapped)
        var v64Data = Data(count: 16)
        v64Data[0] = 0x37
        v64Data[1] = 0x80
        v64Data[2] = 0x40
        v64Data[3] = 0x12
        for i in 4..<16 {
            // Swap pairs: index 4 becomes 5, 5 becomes 4, etc.
            v64Data[i] = (i % 2 == 0) ? UInt8(i + 1) : UInt8(i - 1)
        }

        // Normalize v64 to z64
        guard let normalizedV64 = N64ROMNormalizer.normalizeToZ64(v64Data) else {
            XCTFail("Normalization failed")
            return
        }

        // Both should have the same MD5
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

        // Normalize n64 to z64
        guard let normalizedN64 = N64ROMNormalizer.normalizeToZ64(n64Data) else {
            XCTFail("Normalization failed")
            return
        }

        // Both should have the same MD5
        let z64MD5 = z64Data.md5
        let normalizedMD5 = normalizedN64.md5

        XCTAssertEqual(z64MD5, normalizedMD5, "n64 normalized to z64 should produce same MD5 as original z64")
    }
}
