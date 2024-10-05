//
//  PVFCEUEmulatorCore.swift
//  PVFCEU
//
//  Created by Joseph Mattiello on 3/9/18.
//  Copyright © 2018 JamSoft. All rights reserved.
//

import Foundation
import PVSupport
import PVEmulatorCore

//
//  PVJaguarGameCore.swift
//  PVVirtualJaguar
//
//  Created by Joseph Mattiello on 5/21/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
#if canImport(GameController)
import GameController
#endif
#if canImport(OpenGLES)
import OpenGLES
import OpenGLES.ES3
#endif
import PVLogging
import PVAudio
import PVEmulatorCore
import PVCoreObjCBridge

@objc
@objcMembers
open class PVFCEUEmulatorCore: PVEmulatorCore, @unchecked Sendable {
//    
//    // PVEmulatorCoreBridged
//    public typealias Bridge = PVFCEUEmulatorCoreBridge
//    public override let bridge: any ObjCBridgedCoreBridge = {
//        let core = PVFCEUEmulatorCoreBridge()
//        return core
//    }()

//    @MainActor
//    @objc public var jagVideoBuffer: UnsafeMutablePointer<JagBuffer>?
//    @MainActor
//    @objc public var videoWidth: UInt32 = UInt32(VIDEO_WIDTH)
//    @MainActor
//    @objc public var videoHeight: Int = Int(VIDEO_HEIGHT)
//    @MainActor
//    @objc public var frameTime: Float = 0.0
//    @objc public var multithreaded: Bool { virtualjaguar_mutlithreaded }

    // MARK: Audio
//    @objc public override var sampleRate: Double {
//        get { Double(AUDIO_SAMPLERATE) }
//        set {}
//    }

//    @objc dynamic public override var audioBufferCount: UInt { 1 }

//    @MainActor
//    @objc public var audioBufferSize: Int16 = 0

    // MARK: Queues
//    @objc  public let audioQueue: DispatchQueue = .init(label: "com.provenance.jaguar.audio", qos: .userInteractive, autoreleaseFrequency: .inherit)
//    @objc public let videoQueue: DispatchQueue = .init(label: "com.provenance.jaguar.video", qos: .userInteractive, autoreleaseFrequency: .inherit)
//    @objc public let renderGroup: DispatchGroup = .init()

//    @objc  public let waitToBeginFrameSemaphore: DispatchSemaphore = .init(value: 0)

    // MARK: Video

//    @objc public override var isDoubleBuffered: Bool {
//        // TODO: Fix graphics tearing when this is on
//        // return self.virtualjaguar_double_buffer
//        return false
//    }
    
//    @objc public override dynamic var rendersToOpenGL: Bool { false }


//    @MainActor
//    @objc public override var videoBufferSize: CGSize { .init(width: Int(videoWidth), height: videoHeight) }

//    @MainActor
//    @objc public override var aspectSize: CGSize { .init(width: Int(TOMGetVideoModeWidth()), height: Int(TOMGetVideoModeHeight())) }

    // MARK: Lifecycle

    public required init() {
        super.init()
        self.bridge = (PVFCEUEmulatorCoreBridge() as! any ObjCBridgedCoreBridge)
    }
}

extension PVFCEUEmulatorCore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)

    }
    
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVFCEUEmulatorCoreBridge: DiscSwappable {
    public var numberOfDiscs: UInt {
        return 2
    }

    public var currentGameSupportsMultipleDiscs: Bool {
        return true
    }

    public func swapDisc(number: UInt) {
        internalSwapDisc(number)
    }
}

extension PVFCEUEmulatorCoreBridge: ArchiveSupport {
    public var supportedArchiveFormats: ArchiveSupportOptions {
        return [.gzip, .zip]
    }
}
