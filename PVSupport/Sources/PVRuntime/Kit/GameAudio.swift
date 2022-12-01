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
import AudioToolbox
import AVFoundation
@_implementationOnly import os.log

extension OSLog {
    static let audio = OSLog(subsystem: "org.openemu.OpenEmuKit", category: "OEGameAudio")
}

@objc
final public class GameAudio: NSObject {
    @objc public var volume: Float {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }
    
    private let engine = AVAudioEngine()
    private var gen: AVAudioUnitGenerator?
    private weak var gameCore: OEGameCore!
    private var isDefaultOutputDevice = true
    private var isRunning = false
    
    @objc public init(withCore gameCore: OEGameCore) {
        self.gameCore = gameCore
        volume = 1.0
        super.init()
        AudioUnit.register()
    }
    
    deinit {
        stopMonitoringEngineConfiguration()
    }
    
    @objc public func audioSampleRateDidChange() {
        guard isRunning else { return }
        
        engine.stop()
        configureNodes()
        engine.prepare()
        performResumeAudio()
    }
    
    @objc public func startAudio() {
        precondition(gameCore.audioBufferCount == 1,
                     "Only one buffer supported; got \(gameCore.audioBufferCount)")
        
        createNodes()
        configureNodes()
        attachNodes()
#if os(macOS)
        setOutputDeviceID(outputDeviceID)
#endif
        
        engine.prepare()
        // per the following, we need to wait before resuming to allow devices to start 🤦🏻‍♂️
        //  https://github.com/AudioKit/AudioKit/blob/f2a404ff6cf7492b93759d2cd954c8a5387c8b75/Examples/macOS/OutputSplitter/OutputSplitter/Audio/Output.swift#L88-L95
        performResumeAudio()
        startMonitoringEngineConfiguration()
    }
    
    @objc public func stopAudio() {
        engine.stop()
        detachNodes()
        destroyNodes()
        isRunning = true
    }
    
    @objc public func pauseAudio() {
        engine.pause()
        isRunning = false
    }
    
    private func performResumeAudio() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 0.020) {
                self.resumeAudio()
            }
    }
    
    @objc public func resumeAudio() {
        isRunning = true
        do {
            try engine.start()
        } catch {
            os_log(.error, log: .audio, "Unable to start AVAudioEngine: %{public}s",
                   error.localizedDescription)
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
    
    private var renderFormat: AVAudioFormat {
        let channelCount    = UInt32(gameCore.channelCount(forBuffer: 0))
        let bytesPerSample  = UInt32(gameCore.audioBitDepth / 8)
        
        let formatFlags: AudioFormatFlags = bytesPerSample == 4
        // assume 32-bit float
        ? kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked
        : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian
        
        var desc = AudioStreamBasicDescription(mSampleRate: gameCore.audioSampleRate(forBuffer: 0),
                                               mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: formatFlags,
                                               mBytesPerPacket: bytesPerSample * channelCount,
                                               mFramesPerPacket: 1,
                                               mBytesPerFrame: bytesPerSample * channelCount,
                                               mChannelsPerFrame: channelCount,
                                               mBitsPerChannel: 8 * bytesPerSample,
                                               mReserved: 0)
        return AVAudioFormat(streamDescription: &desc)!
        
    }
    
    // MARK: - Helpers
    
    private func createNodes() {
        gen = AVAudioUnitGenerator(audioComponentDescription: .init(componentType: kAudioUnitType_Generator,
                                                                    componentSubType: AudioUnit.kAudioUnitSubType_Emulator,
                                                                    componentManufacturer: AudioUnit.kAudioUnitManufacturer_OpenEmu,
                                                                    componentFlags: 0,
                                                                    componentFlagsMask: 0))
    }

    private func configureNodes() {
        guard let au = gen?.auAudioUnit as? AudioUnit
        else {
            fatalError("Expected AudioUnit")
        }
        let bus = au.inputBusses[0]
        let renderFormat = renderFormat
        do {
            try bus.setFormat(renderFormat)
        } catch {
            os_log(.error, log: .audio, "Unable to set input bus render format %{public}s: %{public}s",
                   renderFormat.description, error.localizedDescription)
            return
        }
        
        let read = readBlockForBuffer(gameCore.audioBuffer(at: 0))
        let src  = renderFormat.streamDescription.pointee
        let bytesPerFrame = src.mBytesPerFrame
        let channelCount  = src.mChannelsPerFrame
        
        au.outputProvider = { _, _, frameCount, _, inputData -> AUAudioUnitStatus in
            let bytesRequested = UInt(frameCount * bytesPerFrame)
            let bytesCopied    = read(inputData.pointee.mBuffers.mData, bytesRequested)
            
            inputData.pointee.mBuffers.mDataByteSize    = UInt32(bytesCopied)
            inputData.pointee.mBuffers.mNumberChannels  = channelCount
            
            return noErr
        }
    }
    
    private func destroyNodes() {
        gen = nil
    }
    
    private func connectNodes() {
        engine.connect(gen!, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = volume
    }
    
    private func attachNodes() {
        engine.attach(gen!)
    }
    
    private func detachNodes() {
        engine.detach(gen!)
    }
    
#if os(macOS)
    
    private var token: NSObjectProtocol?
    
    private func startMonitoringEngineConfiguration() {
        token = NotificationCenter.default
            .addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                
                os_log(.info, log: .audio, "AVAudioEngine configuration change")
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
                                              mElement: kAudioObjectPropertyElementMaster)
        var deviceID = AudioObjectID()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return deviceID
    }
   
    @objc public func setOutputDeviceID(_ newOutputDeviceID: AudioDeviceID) {
        let id: AudioDeviceID
        if newOutputDeviceID == 0 {
            id = defaultAudioOutputDeviceID
            isDefaultOutputDevice = true
            os_log(.info, log: .audio, "Using default audio device %d", id)
        } else {
            id = newOutputDeviceID
            isDefaultOutputDevice = false
        }
        
        engine.stop()
        
        do {
            try engine.outputNode.auAudioUnit.setDeviceID(id)
        } catch {
            os_log(.error, log: .audio, "Unable to set output device ID %d: %{public}s",
                   id, error.localizedDescription)
        }
        
        connectNodes()
        
        if isRunning && !engine.isRunning {
            engine.prepare()
            performResumeAudio()
        }
    }
    
    @objc public var outputDeviceID: AudioDeviceID {
        isDefaultOutputDevice ? 0 : engine.outputNode.auAudioUnit.deviceID
    }
    
#else
    private func startMonitoringEngineConfiguration() {}
    private func stopMonitoringEngineConfiguration() {}
#endif
}
