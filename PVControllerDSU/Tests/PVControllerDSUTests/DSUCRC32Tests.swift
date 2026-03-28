import Testing
import Foundation
@testable import PVControllerDSU

/// Tests for the DSUCRC32 utility.
///
/// Reference values from the CRC-32/ISO-HDLC (zlib) algorithm.
struct DSUCRC32Tests {

    // MARK: - Known-value tests

    @Test("CRC32 of empty data is 0")
    func testEmptyData() {
        let result = DSUCRC32.compute(Data())
        #expect(result == 0x00000000)
    }

    @Test("CRC32 of ASCII digits '123456789' matches reference 0xCBF43926")
    func testKnownDigits() {
        // Standard CRC-32 check value for "123456789"
        let bytes: [UInt8] = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
        let result = DSUCRC32.compute(Data(bytes))
        #expect(result == 0xCBF43926)
    }

    @Test("CRC32 of a single zero byte")
    func testSingleZeroByte() {
        let result = DSUCRC32.compute(Data([0x00]))
        // Known value: crc32 of [0x00] = 0xD202EF8D
        #expect(result == 0xD202EF8D)
    }

    @Test("CRC32 of 0xFF byte matches reference value 0xFF000000")
    func testSingleFFByte() {
        let result = DSUCRC32.compute(Data([0xFF]))
        // CRC-32/ISO-HDLC of a single 0xFF byte:
        //   crc = 0xFFFFFFFF; index = (0xFFFFFFFF ^ 0xFF) & 0xFF = 0x00
        //   crc = (0xFFFFFFFF >> 8) ^ table[0] = 0x00FFFFFF ^ 0 = 0x00FFFFFF
        //   return 0x00FFFFFF ^ 0xFFFFFFFF = 0xFF000000
        #expect(result == 0xFF000000)
    }

    // MARK: - Stamp and verify round-trip

    @Test("Stamp+Verify round-trip on a minimal 12-byte buffer")
    func testStampVerifyRoundTrip() {
        // Create a buffer large enough for a minimal DSU header (20 bytes)
        var buffer = Data(repeating: 0xAB, count: 20)
        // Clear the CRC field first
        buffer[8] = 0
        buffer[9] = 0
        buffer[10] = 0
        buffer[11] = 0

        DSUCRC32.stamp(into: &buffer)

        // The CRC field must no longer be zero (extremely unlikely to be zero)
        let storedCRC = UInt32(buffer[8])
            | (UInt32(buffer[9]) << 8)
            | (UInt32(buffer[10]) << 16)
            | (UInt32(buffer[11]) << 24)
        #expect(storedCRC != 0)

        // Verify must succeed
        #expect(DSUCRC32.verify(buffer) == true)
    }

    @Test("Verify fails after flipping a byte")
    func testVerifyFailsOnCorruption() {
        var buffer = Data(Array(0..<20).map { UInt8($0) })

        DSUCRC32.stamp(into: &buffer)
        #expect(DSUCRC32.verify(buffer) == true)

        // Corrupt a byte outside the CRC field
        buffer[5] ^= 0xFF

        #expect(DSUCRC32.verify(buffer) == false)
    }

    @Test("Stamp is idempotent when called twice")
    func testStampIsIdempotent() {
        var buffer1 = Data(Array(0..<20).map { UInt8($0) })
        var buffer2 = buffer1

        DSUCRC32.stamp(into: &buffer1)
        DSUCRC32.stamp(into: &buffer1)   // call a second time

        DSUCRC32.stamp(into: &buffer2)

        #expect(buffer1 == buffer2)
    }

    @Test("Stamp on buffer shorter than 12 bytes is a no-op")
    func testStampShortBuffer() {
        var shortBuffer = Data([0x01, 0x02, 0x03])
        let originalBuffer = shortBuffer
        DSUCRC32.stamp(into: &shortBuffer)
        #expect(shortBuffer == originalBuffer)
    }

    @Test("Verify on buffer shorter than 12 bytes returns false")
    func testVerifyShortBuffer() {
        let shortBuffer = Data([0x01, 0x02])
        #expect(DSUCRC32.verify(shortBuffer) == false)
    }

    // MARK: - Consistency

    @Test("Two identical buffers produce the same CRC")
    func testDeterminism() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE])
        #expect(DSUCRC32.compute(data) == DSUCRC32.compute(data))
    }

    @Test("Different buffers (almost certainly) produce different CRCs")
    func testDifferentBuffers() {
        let a = Data([0x01, 0x02, 0x03, 0x04])
        let b = Data([0x01, 0x02, 0x03, 0x05])
        #expect(DSUCRC32.compute(a) != DSUCRC32.compute(b))
    }

    // MARK: - Data slice safety

    @Test("Stamp+Verify works correctly on a Data slice (non-zero startIndex)")
    func testStampVerifyOnDataSlice() {
        // Build a 40-byte buffer; our "packet" lives at bytes 10..<30 (a slice).
        var outer = Data(repeating: 0xAA, count: 40)
        // Write recognisable non-zero values into the packet region.
        for i in 10..<30 { outer[i] = UInt8(i) }
        // Zero out the CRC field (bytes 8-11 relative to the slice start = outer[18..<22]).
        for i in 18..<22 { outer[i] = 0 }

        var slice = outer[10..<30]     // Data slice: startIndex == 10, count == 20

        DSUCRC32.stamp(into: &slice)

        // The stamped CRC in the slice must be non-zero.
        let storedCRC = UInt32(slice[slice.startIndex + 8])
            | (UInt32(slice[slice.startIndex + 9]) << 8)
            | (UInt32(slice[slice.startIndex + 10]) << 16)
            | (UInt32(slice[slice.startIndex + 11]) << 24)
        #expect(storedCRC != 0)

        // verify() must succeed on the same slice.
        #expect(DSUCRC32.verify(slice) == true)

        // Stamping again must be idempotent.
        var sliceCopy = slice
        DSUCRC32.stamp(into: &sliceCopy)
        #expect(sliceCopy == slice)
    }

    @Test("Verify rejects a corrupted Data slice")
    func testVerifyRejectsCorruptedSlice() {
        var outer = Data(repeating: 0xBB, count: 40)
        for i in 8..<12 { outer[i + 10] = 0 }   // zero CRC region in slice
        var slice = outer[10..<30]
        DSUCRC32.stamp(into: &slice)
        #expect(DSUCRC32.verify(slice) == true)

        // Corrupt a non-CRC byte
        slice[slice.startIndex + 5] ^= 0xFF
        #expect(DSUCRC32.verify(slice) == false)
    }
}
