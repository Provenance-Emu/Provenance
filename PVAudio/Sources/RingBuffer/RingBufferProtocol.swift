//
//  RingBufferProtocol.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Foundation

public typealias RingBufferSize = Int

@objc public protocol RingBufferProtocol {

    init?(withLength: RingBufferSize)

    var availableBytesForWriting: RingBufferSize { get }
    var availableBytesForReading: RingBufferSize { get }

    @discardableResult func write(_ buffer: UnsafeRawPointer, size: RingBufferSize) -> RingBufferSize
    @discardableResult func read(_ buffer: UnsafeMutableRawPointer, preferredSize: RingBufferSize) -> RingBufferSize

    func reset()
//    func set(length: RingBufferSize)

    @objc var availableBytes: RingBufferSize { get }
}
