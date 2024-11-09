//
//  RingBuffer.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 11/7/24.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//
//

import Foundation
import RingBuffer
import PVLogging
import Atomics

@preconcurrency import Darwin

// Create constant wrappers for vm_page_size and mach_task_self_
private let VM_PAGE_SIZE: vm_size_t = {
    var size: vm_size_t = 0
    Darwin.host_page_size(Darwin.mach_host_self(), &size)
    return size
}()

private let MACH_TASK_SELF: mach_port_t = {
    mach_task_self_
}()

private func trunc_page(_ x: vm_size_t) -> vm_size_t {
    @Sendable func truncate() -> vm_size_t {
        return x & ~(VM_PAGE_SIZE - 1)
    }
    return truncate()
}

private func round_page(_ x: vm_size_t) -> vm_size_t {
    return trunc_page(x + (vm_size_t(VM_PAGE_SIZE) - 1))
}
/// Ring buffer implementation optimized for audio processing
@objc
public final class PVRingBuffer: NSObject, RingBufferProtocol, @unchecked Sendable {
    /// Cache line size for modern processors
    private let cacheLineSize = 64
    private let pageSize: Int = Int(VM_PAGE_SIZE)

    /// Actual buffer storage
    private let buffer: UnsafeMutableRawPointer
    private let bufferLength: Int

    /// Use atomic properties for thread-safe access
    private var _readPosition: ManagedAtomic<Int>
    private var _writePosition: ManagedAtomic<Int>
    private var _bytesInBuffer: ManagedAtomic<Int>

    public var isEnabled: Bool = true

    /// Protocol conformance for available bytes properties
    public var availableBytesForWriting: RingBufferSize {
        let currentBytes = _bytesInBuffer.load(ordering: .acquiring)
        return bufferLength - currentBytes
    }

    public var availableBytesForReading: RingBufferSize {
        return _bytesInBuffer.load(ordering: .acquiring)
    }

    @objc public var availableBytes: RingBufferSize {
        return availableBytesForReading
    }

    public required init?(withLength length: RingBufferSize) {
        guard length > 0 else { return nil }

        /// Round up to nearest page size
        let alignedLength = round_page(vm_size_t(length))
        self.bufferLength = Int(alignedLength)

        /// Allocate page-aligned memory
        guard let aligned = aligned_alloc(pageSize, Int(alignedLength)) else {
            return nil
        }
        self.buffer = aligned

        /// Initialize atomic properties
        self._readPosition = ManagedAtomic<Int>(0)
        self._writePosition = ManagedAtomic<Int>(0)
        self._bytesInBuffer = ManagedAtomic<Int>(0)

        super.init()

        /// Zero the buffer
        memset(self.buffer, 0, Int(alignedLength))
    }

    deinit {
        /// Free the buffer memory
        free(buffer)
    }

    /// Thread-safe read with atomic operations
    @discardableResult
    public func read(_ buffer: UnsafeMutableRawPointer, preferredSize size: Int) -> Int {
        guard isEnabled, size > 0 else { return 0 }

        /// Check if buffer is empty
        if _bytesInBuffer.load(ordering: .acquiring) == 0 {
            DLOG("Buffer underrun - filling with silence")
            memset(buffer, 0, size)
            return size
        }

        /// Get current state
        let currentBytes = _bytesInBuffer.load(ordering: .acquiring)
        let readSize = min(size, currentBytes)
        let currentRead = _readPosition.load(ordering: .acquiring)

        /// First chunk: from read position to end of buffer
        let firstChunkSize = min(readSize, bufferLength - currentRead)
        optimizedCopy(from: self.buffer.advanced(by: currentRead),
                     to: buffer,
                     count: firstChunkSize)

        /// Second chunk: wrap around to start if needed
        if firstChunkSize < readSize {
            let secondChunkSize = readSize - firstChunkSize
            optimizedCopy(from: self.buffer,
                         to: buffer.advanced(by: firstChunkSize),
                         count: secondChunkSize)
        }

        /// Fill remaining with silence if needed
        if readSize < size {
            DLOG("Partial read: \(readSize)/\(size) bytes - filling rest with silence")
            memset(buffer.advanced(by: readSize), 0, size - readSize)
        }

        /// Update positions atomically
        let newRead = fastMod(currentRead + readSize, bufferLength)
        _readPosition.store(newRead, ordering: .releasing)

        /// Update bytes in buffer atomically
        var expected = currentBytes
        while !_bytesInBuffer.compareExchange(
            expected: expected,
            desired: expected - readSize,
            ordering: .releasing
        ).exchanged {
            expected = _bytesInBuffer.load(ordering: .acquiring)
        }

        return size
    }

    /// Thread-safe write with atomic operations
    @discardableResult
    public func write(_ buffer: UnsafeRawPointer, size: Int) -> Int {
        guard isEnabled, size > 0 else { return 0 }

        /// Handle buffer full condition
        let currentBytes = _bytesInBuffer.load(ordering: .acquiring)
        if currentBytes == bufferLength {
            let currentRead = _readPosition.load(ordering: .acquiring)
            _readPosition.store(fastMod(currentRead + size, bufferLength),
                              ordering: .releasing)

            var expected = currentBytes
            while !_bytesInBuffer.compareExchange(
                expected: expected,
                desired: expected - size,
                ordering: .releasing
            ).exchanged {
                expected = _bytesInBuffer.load(ordering: .acquiring)
            }

            WLOG("Buffer overrun - overwriting oldest \(size) bytes")
        }

        let currentWrite = _writePosition.load(ordering: .acquiring)

        /// Write first chunk
        let firstChunkSize = min(size, bufferLength - currentWrite)
        optimizedCopy(from: buffer,
                     to: self.buffer.advanced(by: currentWrite),
                     count: firstChunkSize)

        /// Write second chunk if needed
        if firstChunkSize < size {
            let secondChunkSize = size - firstChunkSize
            optimizedCopy(from: buffer.advanced(by: firstChunkSize),
                         to: self.buffer,
                         count: secondChunkSize)
        }

        /// Update write position atomically
        let newWrite = fastMod(currentWrite + size, bufferLength)
        _writePosition.store(newWrite, ordering: .releasing)

        /// Update bytes in buffer atomically
        var expected = currentBytes
        while !_bytesInBuffer.compareExchange(
            expected: expected,
            desired: expected + size,
            ordering: .releasing
        ).exchanged {
            expected = _bytesInBuffer.load(ordering: .acquiring)
        }

        return size
    }

    /// Reset with atomic operations
    public func reset() {
        _readPosition.store(0, ordering: .releasing)
        _writePosition.store(0, ordering: .releasing)
        _bytesInBuffer.store(0, ordering: .releasing)
    }

    /// Fast power of 2 check
    private func isPowerOf2(_ value: Int) -> Bool {
        return value > 0 && (value & (value - 1)) == 0
    }

    /// Optimized modulo for power of 2 sizes
    private func fastMod(_ value: Int, _ modulus: Int) -> Int {
        if isPowerOf2(modulus) {
            return value & (modulus - 1)
        }
        return value % modulus
    }

    /// SIMD-optimized memory copy
    private func optimizedCopy(from source: UnsafeRawPointer,
                             to destination: UnsafeMutableRawPointer,
                             count: Int) {
        let alignment = MemoryLayout<Float>.alignment

        if count >= 32 && Int(bitPattern: source) % alignment == 0 &&
           Int(bitPattern: destination) % alignment == 0 {
            /// Use SIMD for larger, aligned copies
            let simdSource = source.assumingMemoryBound(to: SIMD8<Float>.self)
            let simdDest = destination.assumingMemoryBound(to: SIMD8<Float>.self)
            let simdCount = count / 32

            for i in 0..<simdCount {
                simdDest[i] = simdSource[i]
            }

            /// Handle remaining bytes
            let remaining = count % 32
            if remaining > 0 {
                memcpy(destination.advanced(by: simdCount * 32),
                       source.advanced(by: simdCount * 32),
                       remaining)
            }
        } else {
            /// Fall back to regular memcpy for small or unaligned copies
            memcpy(destination, source, count)
        }
    }
}
