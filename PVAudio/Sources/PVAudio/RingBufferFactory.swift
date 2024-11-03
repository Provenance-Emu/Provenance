//
//  File.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Foundation
@_exported import RingBuffer
import PVRingBuffer
import OERingBuffer
import AppleRingBuffer
import PVLogging

@objc
public enum RingBufferType: Int {
    case provenance
    case openEMU
}

@objc
public final class RingBufferFactory: NSObject {
    @objc
    public static func make(type: RingBufferType = .openEMU, withLength length: Int) -> RingBufferProtocol? {
        // Log the requested buffer creation
        DLOG("Creating \(type) ring buffer with length: \(length)")

        let buffer: RingBufferProtocol?
        switch type {
            case .openEMU:
                buffer = OERingBuffer(withLength: length)
            case .provenance:
                buffer = PVRingBuffer(withLength: length)
        }

        // Log the result
        if buffer == nil {
            ELOG("Failed to create \(type) ring buffer")
        } else {
            DLOG("Successfully created \(type) ring buffer")
        }

        return buffer
    }
}

extension OERingBuffer: RingBufferProtocol {

}
