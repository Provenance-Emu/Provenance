//
//  RingBuffer.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//
//  Heavily based on Michael Tyson's TPCircularBuffer (https://github.com/michaeltyson/TPCircularBuffer)
//

import Foundation
import RingBuffer
import PVLogging
//@preconcurrency import Darwin.Mach.machine.vm_types
@preconcurrency import Darwin

// Create constant wrappers for vm_page_size and mach_task_self_
private let VM_PAGE_SIZE: vm_size_t = {
    var size: vm_size_t = 0
    Darwin.host_page_size(Darwin.mach_host_self(), &size)
    return size
}()

//@Sendable
//private func getMachTaskSelf() -> mach_port_t {
//    Darwin.mach_task_self_
////    var task_info: mach_task_basic_info_t = mach_task_basic_info_t()
//    //    Darwin.mach_task_flavor_t(MACH_TASK_BASIC_INFO, &task_info, MemoryLayout<mach_task_basic_info_t>.size)
//
//    //    Darwin.task_identity_token_get_task_port(token, flavor, port)
//
////    var task_info: thread_act_array_t = thread_act_array_t()
////    Darwin.task_threads(mach_task_self(), &task_info, MemoryLayout<mach_task_basic_info_t>.size)
//
//}

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
/// Ring buffer implementation
public final class PVRingBuffer: NSObject, RingBufferProtocol {
    private var buffer: UnsafeMutableRawPointer
    private let bufferLength: Int

    /// Read position in buffer
    private var readPosition: Int = 0

    /// Write position in buffer
    private var writePosition: Int = 0

    /// Number of bytes currently used in buffer
    private var bytesInBuffer: Int = 0

    public var isEnabled: Bool = true

    /// Required initializer from RingBufferProtocol
    public required init?(withLength length: RingBufferSize) {
        guard length > 0 else { return nil }
        self.bufferLength = length

        /// Allocate and zero out the buffer
        self.buffer = malloc(length)
        memset(self.buffer, 0, length)

        super.init()
    }

    deinit {
        free(buffer)
    }

    /// Available space for writing
    public var availableBytesForWriting: RingBufferSize {
        return bufferLength - bytesInBuffer
    }

    /// Available bytes for reading (matches protocol requirement)
    public var availableBytesForReading: RingBufferSize {
        return bytesInBuffer
    }

    /// Objective-C compatible property (matches protocol requirement)
    @objc public var availableBytes: RingBufferSize {
        return availableBytesForReading
    }

    /// Write data to buffer
    @discardableResult
    public func write(_ buffer: UnsafeRawPointer, size: Int) -> Int {
        guard isEnabled, size > 0 else { return 0 }

        let available = availableBytesForWriting
        guard available > 0 else {
            WLOG("Buffer full - resetting")
            debugBufferState()
            reset()
            return 0
        }

        let writeSize = min(size, available)

        /// First chunk: from write position to end of buffer
        let firstChunkSize = min(writeSize, bufferLength - writePosition)
        memcpy(self.buffer.advanced(by: writePosition), buffer, firstChunkSize)

        /// Second chunk: wrap around to start if needed
        if firstChunkSize < writeSize {
            let secondChunkSize = writeSize - firstChunkSize
            memcpy(self.buffer, buffer.advanced(by: firstChunkSize), secondChunkSize)
        }

        writePosition = (writePosition + writeSize) % bufferLength
        bytesInBuffer += writeSize

        return writeSize
    }

    /// Read data from buffer
    @discardableResult
    public func read(_ buffer: UnsafeMutableRawPointer, preferredSize size: Int) -> Int {
        guard isEnabled, bytesInBuffer > 0, size > 0 else { return 0 }

        let readSize = min(size, bytesInBuffer)

        /// First chunk: from read position to end of buffer
        let firstChunkSize = min(readSize, bufferLength - readPosition)
        memcpy(buffer, self.buffer.advanced(by: readPosition), firstChunkSize)

        /// Second chunk: wrap around to start if needed
        if firstChunkSize < readSize {
            let secondChunkSize = readSize - firstChunkSize
            memcpy(buffer.advanced(by: firstChunkSize), self.buffer, secondChunkSize)
        }

        readPosition = (readPosition + readSize) % bufferLength
        bytesInBuffer -= readSize

        return readSize
    }

    /// Reset buffer state
    public func reset() {
        readPosition = 0
        writePosition = 0
        bytesInBuffer = 0
    }

    /// Debug current buffer state
    public func debugBufferState() {
        DLOG("Buffer State - Read: \(readPosition), Write: \(writePosition), Used: \(bytesInBuffer), Length: \(bufferLength)")
        DLOG("Available for writing: \(availableBytesForWriting), Available for reading: \(bytesInBuffer)")
    }
}
