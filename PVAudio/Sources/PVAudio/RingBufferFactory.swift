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

@objc
public enum RingBufferType: Int {
    case provenance
    case openEMU
}

@objc
public final class RingBufferFactory: NSObject {
    @objc
    public static func make(type: RingBufferType = .openEMU, withLength length: Int) -> RingBufferProtocol? {
        switch type {
            case .openEMU:
            return OERingBuffer(withLength: length)
            case .provenance:
            return PVRingBuffer(withLength: length)
        }
    }
}

extension OERingBuffer: RingBufferProtocol {

}
