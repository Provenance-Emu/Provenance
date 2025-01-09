//
//  TestPVRingBuffer 2.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//


//
//  Test.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Testing
import PVLogging
@testable import AppleRingBuffer
@testable import PVAudio

struct TestAppleRingBuffer {
    
    @Test func testLargeRingBuffer() async throws {
        let bufferSize = 16384 * 8
        try await testRingBuffer(ofSize: bufferSize)
    }
    
    @Test func testSmallRingBuffer() async throws {
        let bufferSize = 1024
        try await testRingBuffer(ofSize: bufferSize)
    }
}

extension TestAppleRingBuffer {
    func testRingBuffer(ofSize size: Int) async throws {
        let bufferSize = size
        let testSize = 512
        let leftOverSize = bufferSize - testSize
        
        let ringBuffer = AppleRingBuffer<UInt8>(capacity: bufferSize)
        
        #expect(ringBuffer.isEmpty)
        #expect(!ringBuffer.isFull)
        #expect(ringBuffer.count == 0)
        
        // Create a buffer for testing
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
        defer { buffer.deallocate() }
        
        
        let written = ringBuffer.offer(element: buffer.bindMemory(to: UInt8.self).first!)

        #expect(written)
        
        #expect(ringBuffer.count == 1)
        #expect(!ringBuffer.isEmpty)
        
        var bytesRead: UInt8?

        /// Test iterator
//        var bytesRead = ringBuffer.iterator.next()
//        #expect(bytesRead == buffer.bindMemory(to: UInt8.self).first!)
        
        /// Test peak
        bytesRead = ringBuffer.peek()
        #expect(bytesRead == buffer.bindMemory(to: UInt8.self).first!)

        /// Test take()
        bytesRead = ringBuffer.take()
        #expect(bytesRead == buffer.bindMemory(to: UInt8.self).first!)

        #expect(ringBuffer.isEmpty)
        #expect(ringBuffer.count == 0)
    }
}
