//
//  RingBufferType.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 11/8/24.
//

import Foundation
import PVLogging
@_exported import RingBuffer
@_exported import PVRingBuffer
@_exported import OERingBuffer
@_exported import AppleRingBuffer
import PVLogging

@objc public enum RingBufferType: Int, CaseIterable {
    case provenance
    case openEMU
    //    case appleRingBuffer
    //    case caRingBuffer
    
    public static var `default`: Self { .provenance }
}

extension RingBufferType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .provenance:
            return "Provenance"
        case .openEMU:
            return "OpenEMU"
        }
    }
}

public extension RingBufferType {
    func make(withLength length: Int) -> RingBufferProtocol? {
        // Log the requested buffer creation
        DLOG("Creating \(self.description) ring buffer with length: \(length)")
        
        let buffer: RingBufferProtocol?
        switch self {
        case .openEMU:
            buffer = OERingBuffer(withLength: length)
        case .provenance:
            buffer = PVRingBuffer(withLength: length)
        }
        
        // Log the result
        if buffer == nil {
            ELOG("Failed to create \(self.description) ring buffer")
        } else {
            DLOG("Successfully created \(self.description) ring buffer")
        }
        
        return buffer
    }
}

/// Conformance
extension OERingBuffer: RingBufferProtocol { }
