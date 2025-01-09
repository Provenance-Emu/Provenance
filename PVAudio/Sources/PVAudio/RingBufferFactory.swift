//
//  File.swift
//  PVAudio
//
//  Created by Joseph Mattiello on 9/24/24.
//

import Foundation
import RingBuffer
import PVRingBuffer
import OERingBuffer
import AppleRingBuffer
import PVLogging

@objc
public final class RingBufferFactory: NSObject {
    @objc
    public static func make(type: RingBufferType = .openEMU, withLength length: Int) -> RingBufferProtocol? {
        return type.make(withLength: length)
    }
}
