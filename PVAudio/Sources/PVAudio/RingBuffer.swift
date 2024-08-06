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

@objc(OERingBuffer) @objcMembers
public final class RingBuffer: NSObject, Sendable
{
    public var isEnabled: Bool = true

    @objc(availableBytes)
    public var availableBytesForWriting: Int {
        return Int(self.bufferLength - Int(self.usedBytesCount))
    }

    public var availableBytesForReading: Int {
        return Int(self.usedBytesCount)
    }

    private var head: UnsafeMutableRawPointer {
        let head = self.buffer.advanced(by: self.headOffset)
        return head
    }

    private var tail: UnsafeMutableRawPointer {
        let head = self.buffer.advanced(by: self.tailOffset)
        return head
    }

    private let buffer: UnsafeMutableRawPointer
    public private(set) var bufferLength = 0
    public private(set) var tailOffset = 0
    public private(set) var headOffset = 0
    public private(set) var usedBytesCount: Int32 = 0

    public init?(withLength length: Int)
    {
        assert(length > 0)

        // To handle race conditions, repeat initialization process up to 3 times before failing.
        for _ in 1...3
        {
            let length = round_page(vm_size_t(length))
            self.bufferLength = Int(length)

            var bufferAddress: vm_address_t = 0
            guard vm_allocate(MACH_TASK_SELF, &bufferAddress, vm_size_t(length * 2), VM_FLAGS_ANYWHERE) == ERR_SUCCESS else { continue }

            guard vm_deallocate(MACH_TASK_SELF, bufferAddress + length, length) == ERR_SUCCESS else {
                vm_deallocate(MACH_TASK_SELF, bufferAddress, length)
                continue
            }

            var virtualAddress: vm_address_t = bufferAddress + length
            var current_protection: vm_prot_t = 0
            var max_protection: vm_prot_t = 0

            guard vm_remap(MACH_TASK_SELF, &virtualAddress, length, 0, 0, MACH_TASK_SELF, bufferAddress, 0, &current_protection, &max_protection, VM_INHERIT_DEFAULT) == ERR_SUCCESS else {
                vm_deallocate(MACH_TASK_SELF, bufferAddress, length)
                continue
            }

            guard virtualAddress == bufferAddress + length else {
                vm_deallocate(MACH_TASK_SELF, virtualAddress, length)
                vm_deallocate(MACH_TASK_SELF, bufferAddress, length)

                continue
            }

            self.buffer = UnsafeMutableRawPointer(bitPattern: UInt(bufferAddress))!

            return
        }

        return nil
    }

    deinit
    {
        let address = UInt(bitPattern: self.buffer)
        vm_deallocate(MACH_TASK_SELF, vm_address_t(address), vm_size_t(self.bufferLength * 2))
    }
}

public extension RingBuffer
{
    /// Writes `size` bytes from `buffer` to ring buffer if possible. Otherwise, writes as many as possible.
    @objc(writeBuffer:maxLength:)
    @discardableResult func write(_ buffer: UnsafeRawPointer, size: Int) -> Int
    {
        guard self.isEnabled else { return 0 }
        guard self.availableBytesForWriting > 0 else { return 0 }

        if size > self.availableBytesForWriting
        {
            print("Ring Buffer Capacity reached. Available: \(self.availableBytesForWriting). Requested: \(size) Max: \(self.bufferLength). Filled: \(self.usedBytesCount).")

            self.reset()
        }

        let size = min(size, self.availableBytesForWriting)
        memcpy(self.head, buffer, size)

        self.decrementAvailableBytes(by: size)

        return size
    }

    /// Copies `size` bytes from ring buffer to `buffer` if possible. Otherwise, copies as many as possible.
    @objc(read:maxLength:)
    @discardableResult func read(into buffer: UnsafeMutableRawPointer, preferredSize: Int) -> Int
    {
        guard self.isEnabled else { return 0 }
        guard self.availableBytesForReading > 0 else { return 0 }

        if preferredSize > self.availableBytesForReading
        {
            print("Ring Buffer Empty. Available: \(self.availableBytesForReading). Requested: \(preferredSize) Max: \(self.bufferLength). Filled: \(self.usedBytesCount).")

            self.reset()
        }

        let size = min(preferredSize, self.availableBytesForReading)
        memcpy(buffer, self.tail, size)

        self.incrementAvailableBytes(by: size)

        return size
    }

    func reset()
    {
        let size = self.availableBytesForReading
        self.incrementAvailableBytes(by: size)
    }
}

private extension RingBuffer
{
    func incrementAvailableBytes(by size: Int)
    {
        self.tailOffset = (self.tailOffset + size) % self.bufferLength
        OSAtomicAdd32(-Int32(size), &self.usedBytesCount)
    }

    func decrementAvailableBytes(by size: Int)
    {
        self.headOffset = (self.headOffset + size) % self.bufferLength
        OSAtomicAdd32(Int32(size), &self.usedBytesCount)
    }
}
