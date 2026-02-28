//
//  TestRingBufferFactory.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 2/28/25.
//

import Testing
@testable import PVAudio
@testable import PVRingBuffer
@testable import OERingBuffer

// MARK: - RingBufferFactory Tests

struct TestRingBufferFactory {

    // MARK: - Type Creation

    @Test func testMakeProvenanceType() {
        let buffer = RingBufferFactory.make(type: .provenance, withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer is PVRingBuffer)
    }

    @Test func testMakeOpenEMUType() {
        let buffer = RingBufferFactory.make(type: .openEMU, withLength: 4096)
        #expect(buffer != nil)
        #expect(buffer is OERingBuffer)
    }

    @Test func testDefaultTypeIsProvenance() {
        #expect(RingBufferType.default == .provenance)
    }

    @Test func testAllTypesCreateValidBuffers() {
        for type_ in RingBufferType.allCases {
            let buffer = RingBufferFactory.make(type: type_, withLength: 4096)
            #expect(buffer != nil, "Failed to create buffer of type \(type_.description)")
        }
    }

    // MARK: - Buffer Validity

    @Test func testCreatedBuffersAreUsable() {
        for type_ in RingBufferType.allCases {
            guard let buffer = RingBufferFactory.make(type: type_, withLength: 4096) else {
                Issue.record("Could not create buffer for type \(type_.description)")
                continue
            }

            let capacity = buffer.availableBytesForWriting
            let writeSize = min(256, Int(capacity) / 2)
            let data = [UInt8](repeating: 0xAB, count: writeSize)

            data.withUnsafeBytes { ptr in
                buffer.write(ptr.baseAddress!, size: writeSize)
            }
            #expect(buffer.availableBytesForReading == writeSize,
                    "Type \(type_.description) did not update readable bytes after write")
        }
    }

    @Test func testCreatedBuffersHaveNoDataInitially() {
        for type_ in RingBufferType.allCases {
            let buffer = RingBufferFactory.make(type: type_, withLength: 4096)!
            #expect(buffer.availableBytesForReading == 0,
                    "Type \(type_.description) should start with 0 readable bytes")
            #expect(buffer.availableBytes == 0,
                    "Type \(type_.description) should start with 0 available bytes")
        }
    }

    @Test func testCreatedBuffersHavePositiveWriteCapacity() {
        for type_ in RingBufferType.allCases {
            let buffer = RingBufferFactory.make(type: type_, withLength: 4096)!
            #expect(buffer.availableBytesForWriting > 0,
                    "Type \(type_.description) should have positive write capacity")
        }
    }

    // MARK: - RingBufferType Properties

    @Test func testRingBufferTypeDescriptions() {
        #expect(!RingBufferType.openEMU.description.isEmpty)
        #expect(!RingBufferType.provenance.description.isEmpty)
    }

    @Test func testAllCasesCount() {
        // Currently openEMU and provenance
        #expect(RingBufferType.allCases.count >= 2)
    }

    // MARK: - Type-via-make Convenience

    @Test func testTypeMakeConvenienceCreatesCorrectType() {
        let provenanceBuffer = RingBufferType.provenance.make(withLength: 4096)
        #expect(provenanceBuffer != nil)
        #expect(provenanceBuffer is PVRingBuffer)

        let oeBuffer = RingBufferType.openEMU.make(withLength: 4096)
        #expect(oeBuffer != nil)
        #expect(oeBuffer is OERingBuffer)
    }
}
