//
//  RingBuffer 2.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//


//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// FIXME(nio): remove and use NIO's CircularBuffer
@usableFromInline
final class AppleRingBuffer<A> {
    @usableFromInline
    var elements: [A?]
    @usableFromInline
    var readCounter: Int
    @usableFromInline
    var writeCounter: Int
    @usableFromInline
    let capacity: Int

    init(capacity: Int) {
        self.elements = [A?](repeating: nil, count: capacity)
        self.readCounter = 0
        self.writeCounter = 0
        self.capacity = capacity
    }

    @inlinable
    func offer(element: A) -> Bool {
        if let index = writeIndex {
            self.writeCounter += 1
            self.elements[index] = element
            return true
        }

        return false
    }

    @inlinable
    func take() -> A? {
        if let index = readIndex {
            defer { elements[index] = nil }
            self.readCounter += 1
            return self.elements[index]
        }

        return nil
    }

    @inlinable
    func peek() -> A? {
        if let index = readIndex {
            return self.elements[index]
        }

        return nil
    }

    @inlinable
    var writeIndex: Int? {
        if self.isFull {
            return nil
        }

        return self.writeCounter % self.capacity
    }

    @inlinable
    var readIndex: Int? {
        if self.isEmpty {
            return nil
        }

        return self.readCounter % self.capacity
    }

    @inlinable
    public var count: Int {
        self.writeCounter - self.readCounter
    }

    @inlinable
    public var isEmpty: Bool {
        self.readCounter == self.writeCounter
    }

    @inlinable
    public var isFull: Bool {
        (self.writeCounter - self.readCounter) == self.capacity
    }

    @inlinable
    public var iterator: AppleRingBufferIterator<A> {
        AppleRingBufferIterator(buffer: self, count: self.count)
    }
}

@usableFromInline
class AppleRingBufferIterator<Element>: IteratorProtocol {
    @usableFromInline
    let buffer: AppleRingBuffer<Element>
    @usableFromInline
    var count: Int

    @usableFromInline
    init(buffer: AppleRingBuffer<Element>, count: Int) {
        assert(count >= 0, "count can't be less than 0")
        self.buffer = buffer
        self.count = count
    }

    @inlinable
    func next() -> Element? {
        if self.count == 0 {
            return nil
        }

        self.count -= 1

        return self.buffer.take()
    }

    @inlinable
    func take(_ count: Int) -> AppleRingBufferIterator {
        AppleRingBufferIterator(buffer: self.buffer, count: min(self.count, count))
    }
}
