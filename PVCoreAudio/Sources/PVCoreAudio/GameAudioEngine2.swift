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
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio

@available(macOS 11.0, iOS 14.0, *)
final public class GameAudioEngine2: AudioEngineProtocol {


    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public var volume: Float {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()
    private var src: AVAudioSourceNode?
    private lazy var monoMixerNode: AVAudioMixerNode = {
        let node = AVAudioMixerNode()
        return node
    }()
    private weak var gameCore: EmulatorCoreAudioDataSource!
    private var isDefaultOutputDevice = true
    private var isRunning = false
    private(set) var isMonoOutput = false {
        didSet {
            if isRunning {
                audioSampleRateDidChange()
            }
        }
    }

    public init() {
        volume = 1
    }

    deinit {
        stopMonitoringEngineConfiguration()
    }

    @objc public func audioSampleRateDidChange() {
        guard isRunning else { return }

        engine.stop()
        updateSourceNode()
        updateSampleRateConversion()
        engine.prepare()
        performResumeAudio()
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) {
        self.gameCore = gameCore
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

        // Detach the source node to stop audio processing
        if let src = src {
            engine.detach(src)
            self.src = nil
        }

        // Detach the sample rate converter if it exists
        if let converter = sampleRateConverter {
            engine.detach(converter)
            sampleRateConverter = nil
        }

        isRunning = false
    }

    private func performResumeAudio() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 0.020) {
                self.resumeAudio()
            }
    }

    public func resumeAudio() {
        // Recreate and reattach the source node
        updateSourceNode()
        connectNodes()

        isRunning = true
        do {
            try engine.start()
        } catch {
            ELOG("Unable to start AVAudioEngine: \(error.localizedDescription)")
        }
    }

    typealias OEAudioBufferReadBlock = (UnsafeMutableRawPointer, Int) -> Int
    private func readBlockForBuffer(_ buffer: RingBufferProtocol) -> OEAudioBufferReadBlock {
        return { buf, max -> Int in
            let bytesAvailable = buffer.availableBytes
            let bytesToRead = min(bytesAvailable, max)

            if bytesToRead < max {
                // If we don't have enough data, fill the rest with silence
                let silence = Data(count: max - bytesToRead)
                silence.copyBytes(to: buf.assumingMemoryBound(to: UInt8.self).advanced(by: bytesToRead), count: max - bytesToRead)
            }

            return buffer.read(buf, preferredSize: bytesToRead)
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

    private var converter: AudioConverterRef?

    private var intermediateFormat: AVAudioFormat?

    private func updateSourceNode() {
        DLOG("Entering updateSourceNode")
        if let src {
            engine.detach(src)
            self.src = nil
            DLOG("Detached existing source node")
        }

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)
        let originalSD = streamDescription
        let channelCount = originalSD.mChannelsPerFrame

        DLOG("Original stream description: \(describeAudioFormat(originalSD))")

        // Create an intermediate 16-bit format for 8-bit audio
        var sd = originalSD
        if sd.mBitsPerChannel == 8 {
            sd.mBitsPerChannel = 16
            sd.mBytesPerPacket *= 2
            sd.mBytesPerFrame *= 2
            DLOG("Converting 8-bit to 16-bit format")
        }
        sd.mFormatID = kAudioFormatLinearPCM
        sd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked

        DLOG("Modified stream description: \(describeAudioFormat(sd))")

        guard let format = AVAudioFormat(streamDescription: &sd) else {
            ELOG("Failed to create AVAudioFormat from stream description")
            return
        }

        intermediateFormat = format
        DLOG("Created intermediate AVAudioFormat: \(format)")

        src = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for i in 0..<ablPointer.count {
                var audioBuffer = ablPointer[i]
                let bytesToRead = Int(frameCount) * Int(originalSD.mBytesPerFrame)
                var bytesRead = 0

                if originalSD.mBitsPerChannel == 8 {
                    // Read 8-bit data into a temporary buffer
                    let tempBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bytesToRead)
                    defer { tempBuffer.deallocate() }
                    bytesRead = read(tempBuffer, bytesToRead)

                    // Convert 8-bit to 16-bit
                    let output = audioBuffer.mData!.assumingMemoryBound(to: Int16.self)
                    for j in 0..<bytesRead {
                        output[j] = Int16(tempBuffer[j]) << 8
                    }
                    audioBuffer.mDataByteSize = UInt32(bytesRead * 2)
                } else {
                    bytesRead = read(audioBuffer.mData!, bytesToRead)
                    audioBuffer.mDataByteSize = UInt32(bytesRead)
                }

//                VLOG("Read \(bytesRead) bytes for buffer \(i)")
            }
            return noErr
        }

        if let src {
            engine.attach(src)
            DLOG("Attached new source node")
        } else {
            ELOG("Failed to create source node")
        }
        DLOG("Exiting updateSourceNode")
    }

    private func destroyNodes() {
        if let src {
            engine.detach(src)
        }
        src = nil
    }

    private var sampleRateConverter: AVAudioUnitVarispeed?

    private func connectNodes() {
        DLOG("Entering connectNodes")
        guard let src else {
            ELOG("Source node is nil")
            fatalError("Expected src node")
        }
        if isMonoOutput {
            updateMonoSetting()
            DLOG("Updated mono setting")
        }

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        DLOG("Output format: \(outputFormat)")

        // Use the intermediate format for connection
        if let intermediateFormat = intermediateFormat {
            do {
                DLOG("Attempting to connect with intermediate format: \(intermediateFormat)")
                try engine.connect(src, to: engine.mainMixerNode, format: intermediateFormat)
                DLOG("Successfully connected with intermediate format")
            } catch {
                ELOG("Failed to connect with intermediate format: \(error.localizedDescription)")
                return
            }
        } else {
            ELOG("Intermediate format is nil")
            return
        }

        engine.mainMixerNode.outputVolume = volume
        DLOG("Set main mixer node output volume to \(volume)")
        DLOG("Exiting connectNodes")
    }

    private func updateSampleRateConversion() {
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)

        if abs(renderFormat.sampleRate - outputFormat.sampleRate) > 1 {
            if sampleRateConverter == nil {
                sampleRateConverter = AVAudioUnitVarispeed()
                engine.attach(sampleRateConverter!)
            }

            sampleRateConverter?.rate = Float(outputFormat.sampleRate / renderFormat.sampleRate)
        } else {
            if let converter = sampleRateConverter {
                engine.detach(converter)
                sampleRateConverter = nil
            }
        }

        // Reconnect nodes to apply changes
        engine.disconnectNodeInput(engine.mainMixerNode)
        connectNodes()
    }

    private var token: NSObjectProtocol?

    private func startMonitoringEngineConfiguration() {
        token = NotificationCenter.default
            .addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                guard let self = self else { return }

                DLOG("AVAudioEngine configuration change")
                self.setOutputDeviceID(self.outputDeviceID)
            }
    }

    private func stopMonitoringEngineConfiguration() {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }

    private var defaultAudioOutputDeviceID: AudioDeviceID { 0 }

    func setOutputDeviceID(_ newOutputDeviceID: AudioDeviceID) {
        let id: AudioDeviceID
        if newOutputDeviceID == 0 {
            id = defaultAudioOutputDeviceID
            isDefaultOutputDevice = true
            DLOG("Using default audio device \(id)")
        } else {
            id = newOutputDeviceID
            isDefaultOutputDevice = false
        }

        engine.stop()

        do {
            try _setAudioOutputDevice(for: engine.outputNode.audioUnit!, deviceID: id)
        } catch {
            ELOG("Unable to set output device ID \(id): \(error.localizedDescription)")
        }

        connectNodes()

        if isRunning && !engine.isRunning {
            engine.prepare()
            performResumeAudio()
        }
    }

#warning("TODO: Implement output device ID")
    var outputDeviceID: AudioDeviceID {
        isDefaultOutputDevice ? 0 : 0 //engine.outputNode.auAudioUnit.deviceID
    }

    //    private func configureEngineForLowLatency() {
    //        engine.outputNode.voiceProcessingEnabled = false
    //        engine.outputNode.installTap(onBus: 0, bufferSize: 512, format: nil) { (buffer, time) in
    //            // Process buffer if needed
    //        }
    //    }

    private func adjustBufferSize() {
        let desiredLatency = 0.005 // 5ms
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let bufferSize = AVAudioFrameCount(sampleRate * desiredLatency)
        engine.reset()
        engine.prepare()
        try? engine.enableManualRenderingMode(.realtime, format: engine.outputNode.outputFormat(forBus: 0), maximumFrameCount: bufferSize)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pauseAudio()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumeAudio()
            }
        @unknown default:
            break
        }
    }

    public func enableMetering() {
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer, time) in
            buffer.frameLength = 1024
            let channelDataValue = buffer.floatChannelData!.pointee
            let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map{ channelDataValue[$0] }
            let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            // Use avgPower for visualization or other purposes
        }
    }

    private var sourceNodes: [AVAudioSourceNode] = []

    private func setupMultipleBuffers() {
        for i in 0..<gameCore.audioBufferCount {
            guard let buffer = gameCore.ringBuffer(atIndex: i) else { continue }

            let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for i in 0..<ablPointer.count {
                    var audioBuffer = ablPointer[i]
                    let bytesToRead = Int(frameCount) * MemoryLayout<Float>.size
                    let bytesRead = buffer.read(audioBuffer.mData!, preferredSize: bytesToRead)
                    audioBuffer.mDataByteSize = UInt32(bytesRead)
                }
                return noErr
            }

            sourceNodes.append(sourceNode)
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: renderFormat)
        }
    }

    private func describeAudioFormat(_ format: AudioStreamBasicDescription) -> String {
        return """
        Sample Rate: \(format.mSampleRate),
        Format ID: \(format.mFormatID),
        Format Flags: \(format.mFormatFlags),
        Bytes Per Packet: \(format.mBytesPerPacket),
        Frames Per Packet: \(format.mFramesPerPacket),
        Bytes Per Frame: \(format.mBytesPerFrame),
        Channels Per Frame: \(format.mChannelsPerFrame),
        Bits Per Channel: \(format.mBitsPerChannel)
        """
    }
}

extension GameAudioEngine2 {
    @discardableResult
    func _setAudioOutputDevice(for audioUnit: AudioUnit, deviceID: AudioDeviceID) throws -> OSStatus {
        var deviceIDCopy = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            propertySize
        )

        if status != noErr {
            throw AudioEngineError.failedToCreateAudioEngine(status)
        }

        return status
    }
}

extension GameAudioEngine2: MonoAudioEngine {
    public func setMono(_ isMono: Bool) {
        isMonoOutput = isMono
    }

    public func toggleMonoOutput() {
        isMonoOutput = !isMonoOutput
    }
    private func updateMonoSetting() {
        guard let src = src else { return }
        let format = renderFormat
        if isMonoOutput {
            // Remove any existing connection to mainMixerNode
            engine.disconnectNodeOutput(src)

            // Connect playerNode to monoMixerNode
            engine.connect(src, to: monoMixerNode, format: format)

            // Create mono format
            let monoFormat = AVAudioFormat(commonFormat: format.commonFormat,
                                           sampleRate: format.sampleRate,
                                           channels: 1,
                                           interleaved: format.isInterleaved)

            // Install tap on the monoMixerNode to convert stereo to mono
            monoMixerNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { (buffer, time) in
                guard let channelData = buffer.floatChannelData else { return }

                let frameLength = buffer.frameLength
                let channelCount = buffer.format.channelCount

                // If input is already mono, no need to process
                guard channelCount == 2 else { return }

                let leftChannel = channelData[0]
                let rightChannel = channelData[1]

                // Mix down to mono
                for frame in 0..<Int(frameLength) {
                    leftChannel[frame] = (leftChannel[frame] + rightChannel[frame]) / 2
                    rightChannel[frame] = leftChannel[frame]
                }
            }
        } else {
            // Remove the tap and reconnect playerNode directly to mainMixerNode
            monoMixerNode.removeTap(onBus: 0)
            engine.disconnectNodeInput(monoMixerNode)
            engine.connect(src, to: engine.mainMixerNode, format: format)
        }
    }

    private func startEngineWithErrorHandling() throws {
        do {
            try engine.start()
        } catch {
            throw AudioEngineError.engineStartFailed
        }
    }
}
