//
//  TestAppleRingBuffer.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Testing
import PVLogging
@testable import AppleRingBuffer
@testable import PVAudio

// MARK: - Initialization Tests

struct TestAppleRingBufferInit {

    @Test func testInitWithCapacity() {
        let buffer = AppleRingBuffer<Int>(capacity: 16)
        #expect(buffer.capacity == 16)
    }

    @Test func testInitiallyEmpty() {
        let buffer = AppleRingBuffer<Int>(capacity: 8)
        #expect(buffer.isEmpty)
        #expect(!buffer.isFull)
        #expect(buffer.count == 0)
    }

    @Test func testInitialCountIsZero() {
        let buffer = AppleRingBuffer<UInt8>(capacity: 32)
        #expect(buffer.count == 0)
    }
}

// MARK: - Offer / Take Tests

struct TestAppleRingBufferOfferTake {

    @Test func testOfferSucceeds() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        let result = buffer.offer(element: 42)
        #expect(result == true)
    }

    @Test func testOfferUpdatesCount() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 1)
        #expect(buffer.count == 1)
    }

    @Test func testOfferMakesNotEmpty() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 10)
        #expect(!buffer.isEmpty)
    }

    @Test func testOfferToFullReturnsFalse() {
        let buffer = AppleRingBuffer<Int>(capacity: 2)
        buffer.offer(element: 1)
        buffer.offer(element: 2)
        #expect(buffer.isFull)

        let result = buffer.offer(element: 3)
        #expect(result == false)
    }

    @Test func testTakeReturnsOfferedElement() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 99)
        let result = buffer.take()
        #expect(result == 99)
    }

    @Test func testTakeFromEmptyReturnsNil() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        let result = buffer.take()
        #expect(result == nil)
    }

    @Test func testTakeUpdatesCount() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 1)
        buffer.offer(element: 2)
        buffer.take()
        #expect(buffer.count == 1)
    }

    @Test func testTakeAllMakesEmpty() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 1)
        buffer.take()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test func testFIFOOrdering() {
        let buffer = AppleRingBuffer<Int>(capacity: 8)
        let values = [10, 20, 30, 40, 50]

        for v in values {
            buffer.offer(element: v)
        }

        for expected in values {
            let actual = buffer.take()
            #expect(actual == expected, "Expected \(expected), got \(String(describing: actual))")
        }
    }

    @Test func testMultipleOfferTakeCycles() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)

        for cycle in 0..<20 {
            let value = cycle * 7
            let offered = buffer.offer(element: value)
            #expect(offered == true)
            let taken = buffer.take()
            #expect(taken == value)
        }
    }
}

// MARK: - Peek Tests

struct TestAppleRingBufferPeek {

    @Test func testPeekReturnsNextElement() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 42)
        let result = buffer.peek()
        #expect(result == 42)
    }

    @Test func testPeekDoesNotRemoveElement() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 42)
        buffer.peek()
        #expect(buffer.count == 1)
        #expect(!buffer.isEmpty)
    }

    @Test func testPeekFromEmptyReturnsNil() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        let result = buffer.peek()
        #expect(result == nil)
    }

    @Test func testPeekThenTakeReturnSameValue() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 77)
        let peeked = buffer.peek()
        let taken = buffer.take()
        #expect(peeked == taken)
    }

    @Test func testPeekDoesNotAffectOrder() {
        let buffer = AppleRingBuffer<Int>(capacity: 8)
        buffer.offer(element: 1)
        buffer.offer(element: 2)
        buffer.offer(element: 3)

        // Peek multiple times
        _ = buffer.peek()
        _ = buffer.peek()

        // Take should still return in FIFO order
        #expect(buffer.take() == 1)
        #expect(buffer.take() == 2)
        #expect(buffer.take() == 3)
    }
}

// MARK: - Full / Empty State Tests

struct TestAppleRingBufferState {

    @Test func testIsFullWhenCapacityReached() {
        let capacity = 4
        let buffer = AppleRingBuffer<Int>(capacity: capacity)

        for i in 0..<capacity {
            buffer.offer(element: i)
        }
        #expect(buffer.isFull)
    }

    @Test func testIsNotFullAfterOneTake() {
        let capacity = 4
        let buffer = AppleRingBuffer<Int>(capacity: capacity)

        for i in 0..<capacity {
            buffer.offer(element: i)
        }
        buffer.take()
        #expect(!buffer.isFull)
    }

    @Test func testIsEmptyAfterAllTaken() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 1)
        buffer.offer(element: 2)
        buffer.take()
        buffer.take()
        #expect(buffer.isEmpty)
    }

    @Test func testCountMatchesOffersMinusTakes() {
        let buffer = AppleRingBuffer<Int>(capacity: 16)
        let offerCount = 6
        let takeCount = 3

        for i in 0..<offerCount {
            buffer.offer(element: i)
        }
        for _ in 0..<takeCount {
            buffer.take()
        }
        #expect(buffer.count == offerCount - takeCount)
    }
}

// MARK: - Iterator Tests

struct TestAppleRingBufferIterator {

    @Test func testIteratorDrainsBuffer() {
        let buffer = AppleRingBuffer<Int>(capacity: 8)
        let values = [1, 2, 3, 4]
        for v in values { buffer.offer(element: v) }

        let iter = buffer.iterator
        var results: [Int] = []
        while let val = iter.next() {
            results.append(val)
        }
        #expect(results == values)
    }

    @Test func testIteratorNextReturnsNilWhenExhausted() {
        let buffer = AppleRingBuffer<Int>(capacity: 4)
        buffer.offer(element: 1)
        let iter = buffer.iterator
        iter.next()  // consume the one element
        let result = iter.next()
        #expect(result == nil)
    }
}

// MARK: - Type Compatibility Tests

struct TestAppleRingBuffer {

    @Test func testLargeRingBuffer() async throws {
        let bufferSize = 16384 * 8
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testSmallRingBuffer() async throws {
        let bufferSize = 1024
        try await testRingBuffer(ofSize: bufferSize)
    }

    @Test func testWithUInt8Type() {
        let buffer = AppleRingBuffer<UInt8>(capacity: 256)
        for i: UInt8 in 0..<10 {
            buffer.offer(element: i)
        }
        for i: UInt8 in 0..<10 {
            let result = buffer.take()
            #expect(result == i)
        }
    }
}

extension TestAppleRingBuffer {
    func testRingBuffer(ofSize size: Int) async throws {
        let bufferSize = size
        let testSize = 512

        let ringBuffer = AppleRingBuffer<UInt8>(capacity: bufferSize)

        #expect(ringBuffer.isEmpty)
        #expect(!ringBuffer.isFull)
        #expect(ringBuffer.count == 0)

        // Create a buffer for testing
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
        defer { buffer.deallocate() }

        // Offer testSize elements
        let bytes = buffer.bindMemory(to: UInt8.self)
        for i in 0..<testSize {
            buffer[i] = UInt8(i % 256)
            ringBuffer.offer(element: bytes[i])
        }

        #expect(ringBuffer.count == testSize)
        #expect(!ringBuffer.isEmpty)

        // Peek at first element
        let firstByte: UInt8 = UInt8(0 % 256)
        let peeked = ringBuffer.peek()
        #expect(peeked == firstByte)

        // Take all elements and verify
        for i in 0..<testSize {
            let taken = ringBuffer.take()
            #expect(taken == UInt8(i % 256), "Mismatch at index \(i)")
        }

        #expect(ringBuffer.isEmpty)
        #expect(ringBuffer.count == 0)
    }
}
