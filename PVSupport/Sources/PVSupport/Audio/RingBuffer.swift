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
import Darwin.Mach.machine.vm_types

private func trunc_page(_ x: vm_size_t) -> vm_size_t
{
    return x & ~(vm_page_size - 1)
}

private func round_page(_ x: vm_size_t) -> vm_size_t
{
    return trunc_page(x + (vm_size_t(vm_page_size) - 1))
}

private let NUMBER_OF_BUFFERS = 3

@objc(OERingBuffer) @objcMembers
public class RingBuffer: NSObject
{
    public var isEnabled: Bool = true
    
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
    private var bufferLength = 0
    private var tailOffset = 0
    private var headOffset = 0
    private var usedBytesCount: Int32 = 0
    
    public init?(withLength length: Int)
    {
        assert(length > 0)
        
        // To handle race conditions, repeat initialization process up to 3 times before failing.
        for _ in 1...NUMBER_OF_BUFFERS
        {
            let length = round_page(vm_size_t(length))
            self.bufferLength = Int(length)
            
            var bufferAddress: vm_address_t = 0
            guard vm_allocate(mach_task_self_, &bufferAddress, vm_size_t(length * 2), VM_FLAGS_ANYWHERE) == ERR_SUCCESS else { continue }
            
            guard vm_deallocate(mach_task_self_, bufferAddress + length, length) == ERR_SUCCESS else {
                vm_deallocate(mach_task_self_, bufferAddress, length)
                continue
            }
            
            var virtualAddress: vm_address_t = bufferAddress + length
            var current_protection: vm_prot_t = 0
            var max_protection: vm_prot_t = 0
            
            guard vm_remap(mach_task_self_, &virtualAddress, length, 0, 0, mach_task_self_, bufferAddress, 0, &current_protection, &max_protection, VM_INHERIT_DEFAULT) == ERR_SUCCESS else {
                vm_deallocate(mach_task_self_, bufferAddress, length)
                continue
            }
            
            guard virtualAddress == bufferAddress + length else {
                vm_deallocate(mach_task_self_, virtualAddress, length)
                vm_deallocate(mach_task_self_, bufferAddress, length)
                
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
        vm_deallocate(mach_task_self_, vm_address_t(address), vm_size_t(self.bufferLength * 2))
    }
}

public extension RingBuffer
{
    /// Writes `size` bytes from `buffer` to ring buffer if possible. Otherwise, writes as many as possible.
    @objc(write:maxLength:)
    @discardableResult func write(_ buffer: UnsafeRawPointer, size: Int) -> Int
    {
        guard self.isEnabled else { return 0 }
        guard self.availableBytesForWriting > 0 else { return 0 }
        
        if size > self.availableBytesForWriting
        {
            WLOG("Ring Buffer Capacity reached. Available: \(self.availableBytesForWriting). Requested: \(size) Max: \(self.bufferLength). Filled: \(self.usedBytesCount).")
            
            self.reset()
        }
        
        let size = min(size, self.availableBytesForWriting)
        memcpy(self.head, buffer, size)
        
        self.decrementAvailableBytes(by: size)
        
        return size
    }
    
    /// Copies `size` bytes from ring buffer to `buffer` if possible. Otherwise, copies as many as possible.
    @objc(read:maxLength:)
    @discardableResult func read(into buffer: UnsafeMutableRawPointer, maxLength: Int) -> Int
    {
        guard self.isEnabled else { return 0 }
        guard self.availableBytesForReading > 0 else { return 0 }
        
        if maxLength > self.availableBytesForReading
        {
            WLOG("Ring Buffer Empty. Available: \(self.availableBytesForReading). Requested: \(maxLength) Max: \(self.bufferLength). Filled: \(self.usedBytesCount).")
            
            self.reset()
        }
        
        let size = min(maxLength, self.availableBytesForReading)
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
