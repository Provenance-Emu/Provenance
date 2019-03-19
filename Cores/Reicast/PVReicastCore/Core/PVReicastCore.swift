//
//  PVReicastCore.swift
//  PVReicast
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

@objc
@objcMembers
public final class PVReicastCore : EmulatorCore, GLCore {

//    uint8_t padData[4][PVDreamcastButtonCount];
//    int8_t xAxis[4];
//    int8_t yAxis[4];
//    //    int videoWidth;
//    //    int videoHeight;
//    //    int videoBitDepth;
//    int videoDepthBitDepth; // eh
//
//    float sampleRate;
//
//    BOOL isNTSC;
//    @public
//    dispatch_queue_t _callbackQueue;

    public var padData: [[UInt8]] = Array(repeating: Array(repeating: UInt8(0), count: PVDreamcastButton.allCases.count), count: 4)
    public var xAxis = [Int8](repeating: 0, count: 4)
    public var yAxis = [Int8](repeating: 0, count: 4)
    public var videoWidth = 640
    public var videoHeight = 480
    public var videoBitDepth = 32
    public var videoDepthBitDepth: Int = 0 // eh
    public var isNTSC = true
    public var callbackQueue: DispatchQueue = {
//        let attr : DispatchQueue.Attributes = []
        let q = DispatchQueue(label: "org.openemu.Reicast.CallbackHandlerQueue")
        return q
    }()

    override public var sampleRate: Double {
        return 44100
    }

    public let mupenWaitToBeginFrameSemaphore = DispatchSemaphore(value: 0)
    public let coreWaitToEndFrameSemaphore = DispatchSemaphore(value: 0)
    public let coreWaitForExitSemaphore = DispatchSemaphore(value: 0)

    public var callbackHandlers = [String:Any]()

    // MARK: - Video
    public override
    var frameInterval: TimeInterval {
        return isNTSC ? 60 : 50
    }

    public
    func videoInterrupt() {
        //dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        //dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
    }

    @objc public
    func swapBuffers() {
        renderDelegate?.didRenderFrameOnAlternateThread()
    }

    func executeFrameSkippingFrame(_ skip: Bool) {
        //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

        //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
    }

    override public func executeFrame() {
        executeFrameSkippingFrame(false)
    }

    // MARK: - Properties

    public override
    var bufferSize: CGSize {
        return CGSize(width: 1024, height: 512)
    }

    public override
    var  screenRect: CGRect {
        return CGRect(x: 0, y: 0, width: CGFloat(videoWidth), height: CGFloat(videoHeight))
    }

    public override
    var  aspectSize: CGSize {
        return CGSize(width: CGFloat(videoWidth), height: CGFloat(videoHeight))
    }

    public override
    var rendersToOpenGL: Bool {
        return true
    }

    public override
    var videoBuffer: Void? {
        return nil
    }

    public override
    var pixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }

    public override
    var pixelType: GLenum {
        return GLenum(GL_UNSIGNED_BYTE)
    }

    public override
    var internalPixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }

    public override
    var depthFormat: GLenum {
        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
        return GLenum(GL_DEPTH_COMPONENT24)
    }

    // MARK: - Audio
    public override
    var channelCount: UInt {
        return 2
    }

    public override
    var audioSampleRate: Double {
        return sampleRate
    }
}
