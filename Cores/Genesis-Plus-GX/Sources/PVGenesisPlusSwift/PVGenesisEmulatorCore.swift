//
//  PVJaguarGameCore.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore
import libgenesisplus;

@objc
@objcMembers
open class PVGenesisEmulatorCore: PVEmulatorCore {

//
//    public var videoWidth: UInt32 = UInt32(VIDEO_WIDTH)
//    public var videoHeight: Int = Int(VIDEO_HEIGHT)
//    public var frameTime: Float = 0.0
//    public var multithreaded: Bool { virtualjaguar_mutlithreaded }
//
//    // MARK: Audio
//    public override var sampleRate: Double { Double(AUDIO_SAMPLERATE) }
//    public var audioBufferSize: Int16 = 0
//
//    // MARK: Queues
//    public var audioQueue: DispatchQueue = .init(label: "com.provenance.jaguar.audio", qos: .userInteractive, autoreleaseFrequency: .inherit)
//    public var videoQueue: DispatchQueue = .init(label: "com.provenance.jaguar.video", qos: .userInteractive, autoreleaseFrequency: .inherit)
//    public var renderGroup: DispatchGroup = .init()
//
//    public var waitToBeginFrameSemaphore: DispatchSemaphore = .init(value: 0)
//
//    // MARK: Controls
//
//    public init(valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil) {
//        self.valueChangedHandler = valueChangedHandler
//    }
//
//    public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? = nil
//
//    // MARK: Video
//
//    public override var isDoubleBuffered: Bool {
//        // TODO: Fix graphics tearing when this is on
//        // return self.virtualjaguar_double_buffer
//        return false
//    }
//
//    open override var videoBufferSize: CGSize {
//        return .init(width: Int(videoWidth), height: videoHeight)
//    }
//
//    open override var aspectSize: CGSize {
//        return .init(width: Int(videoWidth), height: videoHeight)
//    }

    // MARK: Lifecycle

    public required init() {
        super.init()
    }
}
