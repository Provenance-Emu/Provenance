// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import AVFoundation
@_implementationOnly import os
import OpenEmuBase.OEGameCore

@available(macOS 11.0, iOS 14.0, *)
private var log = Logger(subsystem: "org.openemu.OpenEmuKit", category: "GameAudio2")

@available(macOS 11.0, iOS 14.0, *)
final public class GameAudio2: GameAudioProtocol {
    public var volume: Float {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }
    
    private let engine = AVAudioEngine()
    private var src: AVAudioSourceNode?
    private weak var gameCore: OEGameCore!
    private var isDefaultOutputDevice = true
    private var isRunning = false
    
    public init(withCore gameCore: OEGameCore) {
        self.gameCore = gameCore
        volume = 1.0
    }
    
    deinit {
        stopMonitoringEngineConfiguration()
    }
    
    @objc public func audioSampleRateDidChange() {
        guard isRunning else { return }
        
        engine.stop()
        updateSourceNode()
        connectNodes()
        engine.prepare()
        performResumeAudio()
    }
    
    public func startAudio() {
        precondition(gameCore.audioBufferCount == 1,
                     "nly one buffer supported; got \(gameCore.audioBufferCount)")
        
        updateSourceNode()
        connectNodes()
        setOutputDeviceID(outputDeviceID)
        
        engine.prepare()
        // per the following, we need to wait before resuming to allow devices to start 🤦🏻‍♂️
        //  https://github.com/AudioKit/AudioKit/blob/f2a404ff6cf7492b93759d2cd954c8a5387c8b75/Examples/macOS/OutputSplitter/OutputSplitter/Audio/Output.swift#L88-L95
        performResumeAudio()
        startMonitoringEngineConfiguration()
    }
    
    public func stopAudio() {
        engine.stop()
        destroyNodes()
        isRunning = true
    }
    
    public func pauseAudio() {
        engine.pause()
        isRunning = false
    }
    
    private func performResumeAudio() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 0.020) {
                self.resumeAudio()
            }
    }
    
    public func resumeAudio() {
        isRunning = true
        do {
            try engine.start()
        } catch {
            log.error("Unable to start AVAudioEngine: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func readBlockForBuffer(_ buffer: OEAudioBuffer) -> OEAudioBufferReadBlock {
        if buffer.responds(to: #selector(OEAudioBuffer.readBlock)) {
            return buffer.readBlock!()
        }
        return { buf, max -> UInt in
            buffer.read(buf, maxLength: max)
        }
    }
    
    private var streamDescription: AudioStreamBasicDescription {
        let channelCount    = UInt32(gameCore.channelCount(forBuffer: 0))
        let bytesPerSample  = UInt32(gameCore.audioBitDepth / 8)
        
        let formatFlags: AudioFormatFlags = bytesPerSample == 4
            // assume 32-bit float
            ? kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked
            : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian
        
        return AudioStreamBasicDescription(mSampleRate: gameCore.audioSampleRate(forBuffer: 0),
                                           mFormatID: kAudioFormatLinearPCM,
                                           mFormatFlags: formatFlags,
                                           mBytesPerPacket: bytesPerSample * channelCount,
                                           mFramesPerPacket: 1,
                                           mBytesPerFrame: bytesPerSample * channelCount,
                                           mChannelsPerFrame: channelCount,
                                           mBitsPerChannel: 8 * bytesPerSample,
                                           mReserved: 0)
    }
    
    private var renderFormat: AVAudioFormat {
        var desc = streamDescription
        return AVAudioFormat(streamDescription: &desc)!
        
    }
    
    // MARK: - Helpers
    
    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }
        
        let read = readBlockForBuffer(gameCore.audioBuffer(at: 0))
        let sd   = streamDescription
        let bytesPerFrame = sd.mBytesPerFrame
        let channelCount  = sd.mChannelsPerFrame
        
        src = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, inputData in
            let bytesRequested = UInt(frameCount * bytesPerFrame)
            let bytesCopied    = read(inputData.pointee.mBuffers.mData, bytesRequested)
            
            inputData.pointee.mBuffers.mDataByteSize    = UInt32(bytesCopied)
            inputData.pointee.mBuffers.mNumberChannels  = channelCount
            
            return noErr
        }
        
        if let src {
            engine.attach(src)
        }
    }
    
    private func destroyNodes() {
        if let src {
            engine.detach(src)
        }
        src = nil
    }
    
    private func connectNodes() {
        guard let src else { fatalError("Expected src node") }
        engine.connect(src, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = volume
    }
    
    private var token: NSObjectProtocol?
    
    private func startMonitoringEngineConfiguration() {
        token = NotificationCenter.default
            .addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                
                log.debug("AVAudioEngine configuration change")
                self.setOutputDeviceID(self.outputDeviceID)
            }
    }
    
    private func stopMonitoringEngineConfiguration() {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
    
    private var defaultAudioOutputDeviceID: AudioDeviceID {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioObjectID()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return deviceID
    }
    
    func setOutputDeviceID(_ newOutputDeviceID: AudioDeviceID) {
        let id: AudioDeviceID
        if newOutputDeviceID == 0 {
            id = defaultAudioOutputDeviceID
            isDefaultOutputDevice = true
            log.debug("Using default audio device \(id)")
        } else {
            id = newOutputDeviceID
            isDefaultOutputDevice = false
        }
        
        engine.stop()
        
        do {
            try engine.outputNode.auAudioUnit.setDeviceID(id)
        } catch {
            log.error("Unable to set output device ID \(id): \(error.localizedDescription, privacy: .public)")
        }
        
        connectNodes()
        
        if isRunning && !engine.isRunning {
            engine.prepare()
            performResumeAudio()
        }
    }
    
    var outputDeviceID: AudioDeviceID {
        isDefaultOutputDevice ? 0 : engine.outputNode.auAudioUnit.deviceID
    }
}
