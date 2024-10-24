//
//  Test.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Testing
import PVLogging
@testable import PVAudio

struct TestPVRingBuffer {

    @Test func testLargeRingBuffer() async throws {
        let bufferSize = 16384 * 8
        try await testRingBuffer(ofSize: bufferSize)
    }
    
    @Test func testSmallRingBuffer() async throws {
        let bufferSize = 1024
        try await testRingBuffer(ofSize: bufferSize)
    }
}

extension TestPVRingBuffer {
    func testRingBuffer(ofSize size: Int) async throws {
       let bufferSize = size
       let testSize = 512
       let leftOverSize = bufferSize - testSize
       
        let ringBuffer = RingBufferFactory.make(type: .provenance, withLength: bufferSize) as! PVRingBuffer

       #expect(ringBuffer.isEnabled)
       #expect(ringBuffer.availableBytesForWriting == bufferSize)
       #expect(ringBuffer.availableBytesForReading == 0)

       // Create a buffer for testing
       let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
       defer { buffer.deallocate() }
       
       
       let writtenBytes = ringBuffer.write(buffer.baseAddress!, size: testSize)
       
       #expect(writtenBytes == testSize)
       
       #expect(ringBuffer.availableBytesForWriting == leftOverSize)
       #expect(ringBuffer.availableBytesForReading == testSize)
   }
}
