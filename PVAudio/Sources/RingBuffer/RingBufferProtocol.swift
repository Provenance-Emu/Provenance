//
//  RingBufferProtocol.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Foundation

public typealias RingBufferSize = Int

#if canImport(ObjectiveC)
@objc
#endif
public protocol RingBufferProtocol {

    init?(withLength: RingBufferSize)

    var availableBytesForWriting: RingBufferSize { get }
    var availableBytesForReading: RingBufferSize { get }

    @discardableResult func write(_ buffer: UnsafeRawPointer, size: RingBufferSize) -> RingBufferSize
    @discardableResult func read(_ buffer: UnsafeMutableRawPointer, preferredSize: RingBufferSize) -> RingBufferSize

    func reset()

    /// Drains all pending bytes without reallocating the backing buffer.
    /// Safe to call while a consumer is paused; prefer this over `reset()` when
    /// the producer (emulator core) may still be running.
    func clear()

    var availableBytes: RingBufferSize { get }
}

public extension RingBufferProtocol {
    /// Default implementation: drain by consuming all available bytes via `read`.
    /// Concrete types should override with a more efficient implementation.
    func clear() {
        let bytes = availableBytesForReading
        guard bytes > 0 else { return }
        let scratch = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 1)
        defer { scratch.deallocate() }
        read(scratch, preferredSize: bytes)
    }
}
