import Foundation
import AVFoundation
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio
import PVSettings

@available(macOS 11.0, iOS 14.0, *)
final public class GameAudioEngine2: AudioEngineProtocol {

    /// Add time pitch node for better rate control
    private lazy var timePitchNode: AVAudioUnitTimePitch = {
        let node = AVAudioUnitTimePitch()
        node.rate = 1.0
        return node
    }()

    /// Internal format for consistent processing
    private lazy var internalFormat: AVAudioFormat = {
        /// Use same sample rate as input but with float32 format
        let sampleRate = gameCore.audioSampleRate(forBuffer: 0)
        return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }()

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
        configureAudioSession()
        setupInterruptionHandling()
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
        let channelCount = UInt32(gameCore.channelCount(forBuffer: 0))
        let sampleRate = gameCore.audioSampleRate(forBuffer: 0)
        let bitDepth = gameCore.audioBitDepth
        let bufferSize = gameCore.audioBufferSize(forBuffer: 0)
        let bytesPerSample = bitDepth / 8

        DLOG("Core audio properties - Channels: \(channelCount), Rate: \(sampleRate), Bits: \(bitDepth)")
        DLOG("Buffer size: \(bufferSize), Bytes per sample: \(bytesPerSample)")

        /// Check if audio is interleaved:
        /// - Reports 1 channel but writes pairs of samples
        /// - Uses 16-bit samples
        /// - Buffer size must accommodate pairs of samples
        let isInterleaved = channelCount == 1 &&
                           bitDepth == 16 &&
                           bufferSize % (bytesPerSample * 2) == 0

        if isInterleaved {
            DLOG("Using interleaved stereo format")
            return AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,  // 2 bytes * 2 channels
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,   // 2 bytes * 2 channels
                mChannelsPerFrame: 2,  // Force stereo for interleaved data
                mBitsPerChannel: 16,
                mReserved: 0)
        }

        DLOG("Using standard format")
        let formatFlags: AudioFormatFlags = bitDepth == 32
            ? kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
            : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked

        return AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: formatFlags,
            mBytesPerPacket: UInt32(bytesPerSample) * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSample) * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: UInt32(bitDepth),
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

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)
        var sd = streamDescription
        let bytesPerFrame = sd.mBytesPerFrame

        DLOG("Audio format - Rate: \(sd.mSampleRate), Channels: \(sd.mChannelsPerFrame), Bits: \(sd.mBitsPerChannel)")

        guard let format = AVAudioFormat(streamDescription: &sd) else {
            ELOG("Failed to create AVAudioFormat")
            return
        }

        src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, inputData in
            guard let self = self else { return noErr }

            let bytesRequested = Int(frameCount * bytesPerFrame)
            let bytesCopied = read(inputData.pointee.mBuffers.mData!, bytesRequested)

            /// Only update if we actually got data
            if bytesCopied > 0 {
                inputData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied)
                inputData.pointee.mBuffers.mNumberChannels = sd.mChannelsPerFrame
                DLOG("Requested: \(bytesRequested) bytes, Copied: \(bytesCopied) bytes")
            }

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

    private var sampleRateConverter: AVAudioUnitVarispeed?

    private func connectNodes() {
        guard let src else { fatalError("Expected src node") }

        if isMonoOutput {
            updateMonoSetting()
            return
        }

        /// Let updateSampleRateConversion handle the connections
        updateSampleRateConversion()
    }

    private func updateSampleRateConversion() {
        guard let src = src else { return }

        /// Clean up existing connections
        engine.disconnectNodeOutput(src)

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)

        if abs(renderFormat.sampleRate - outputFormat.sampleRate) > 1 {
            if usesPitchConversion {
                /// Clean up sample rate converter if it exists
                if let converter = sampleRateConverter {
                    engine.detach(converter)
                    sampleRateConverter = nil
                }

                /// Ensure time pitch node is attached
                if !engine.attachedNodes.contains(timePitchNode) {
                    engine.attach(timePitchNode)
                }

                timePitchNode.rate = Float(outputFormat.sampleRate / renderFormat.sampleRate)

                /// Use source node's output format for first connection
                engine.connect(src, to: timePitchNode, format: src.outputFormat(forBus: 0))
                engine.connect(timePitchNode, to: engine.mainMixerNode, format: outputFormat)

                DLOG("Using pitch conversion with rate: \(timePitchNode.rate)")
            } else {
                /// Clean up time pitch node
                if engine.attachedNodes.contains(timePitchNode) {
                    engine.detach(timePitchNode)
                }

                /// Setup sample rate converter
                if sampleRateConverter == nil {
                    sampleRateConverter = AVAudioUnitVarispeed()
                    engine.attach(sampleRateConverter!)
                }

                sampleRateConverter?.rate = Float(outputFormat.sampleRate / renderFormat.sampleRate)
                engine.connect(src, to: sampleRateConverter!, format: src.outputFormat(forBus: 0))
                engine.connect(sampleRateConverter!, to: engine.mainMixerNode, format: outputFormat)

                DLOG("Using sample rate conversion with rate: \(sampleRateConverter?.rate ?? 0)")
            }
        } else {
            /// Direct connection if rates match
            if let converter = sampleRateConverter {
                engine.detach(converter)
                sampleRateConverter = nil
            }
            if engine.attachedNodes.contains(timePitchNode) {
                engine.detach(timePitchNode)
            }

            engine.connect(src, to: engine.mainMixerNode, format: src.outputFormat(forBus: 0))
        }

        engine.mainMixerNode.outputVolume = volume
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
        /// Use user-configurable latency setting
        let desiredLatency = Defaults[.audioLatency] / 100.0
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let bufferSize = AVAudioFrameCount(sampleRate * desiredLatency)

        engine.reset()
        engine.prepare()
        try? engine.enableManualRenderingMode(.realtime,
                                            format: engine.outputNode.outputFormat(forBus: 0),
                                            maximumFrameCount: bufferSize)
    }

    private func configureAudioSession() {
        do {
            /// Use ambient category for better iOS behavior
            try AVAudioSession.sharedInstance().setCategory(.ambient,
                                                          mode: .default)
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

    /// Add property to track current conversion mode
    private var usesPitchConversion: Bool {
        return Defaults[.usePitchConversionInsteadOfSampleRate]
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

        /// Clean up any existing connections and taps first
        engine.disconnectNodeOutput(src)
        engine.disconnectNodeOutput(monoMixerNode)
        monoMixerNode.removeTap(onBus: 0)

        /// Get system output format
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)

        /// Create intermediate format for consistent processing
        guard let intermediateFormat = AVAudioFormat(standardFormatWithSampleRate: renderFormat.sampleRate,
                                                   channels: 2) else {
            ELOG("Failed to create intermediate format")
            return
        }

        /// Ensure mono mixer is attached
        if !engine.attachedNodes.contains(monoMixerNode) {
            engine.attach(monoMixerNode)
        }

        /// Check if we need rate conversion
        if abs(renderFormat.sampleRate - outputFormat.sampleRate) > 1 {
            if usesPitchConversion {
                /// Use time pitch node for rate conversion
                if sampleRateConverter != nil {
                    engine.detach(sampleRateConverter!)
                    sampleRateConverter = nil
                }

                /// Ensure time pitch node is attached
                if !engine.attachedNodes.contains(timePitchNode) {
                    engine.attach(timePitchNode)
                }

                /// Connect through time pitch node first
                timePitchNode.rate = Float(outputFormat.sampleRate / renderFormat.sampleRate)
                engine.connect(src, to: timePitchNode, format: renderFormat)
                engine.connect(timePitchNode, to: monoMixerNode, format: intermediateFormat)

                DLOG("Using pitch conversion for mono with rate: \(timePitchNode.rate)")
            } else {
                /// Use sample rate converter
                if sampleRateConverter == nil {
                    sampleRateConverter = AVAudioUnitVarispeed()
                    engine.attach(sampleRateConverter!)
                }

                timePitchNode.rate = 1.0
                sampleRateConverter?.rate = Float(outputFormat.sampleRate / renderFormat.sampleRate)
                engine.connect(src, to: sampleRateConverter!, format: renderFormat)
                engine.connect(sampleRateConverter!, to: monoMixerNode, format: intermediateFormat)

                DLOG("Using sample rate conversion for mono with rate: \(sampleRateConverter?.rate ?? 0)")
            }
        } else {
            /// Direct connection if rates match
            if let converter = sampleRateConverter {
                engine.detach(converter)
                sampleRateConverter = nil
            }
            timePitchNode.rate = 1.0
            engine.connect(src, to: monoMixerNode, format: intermediateFormat)
        }

        /// Connect mono mixer to main mixer with proper format
        engine.connect(monoMixerNode, to: engine.mainMixerNode, format: outputFormat)

        /// Set volumes
        monoMixerNode.outputVolume = 1.0
        engine.mainMixerNode.outputVolume = volume

        do {
            /// Install mono processing tap with error handling
            monoMixerNode.installTap(onBus: 0, bufferSize: 4096, format: intermediateFormat) { [weak self] buffer, _ in
                guard let channelData = buffer.floatChannelData,
                      buffer.format.channelCount == 2 else { return }

                let frameLength = Int(buffer.frameLength)
                let leftChannel = channelData[0]
                let rightChannel = channelData[1]

                /// Process in chunks for better performance
                let chunkSize = 256
                for frameOffset in stride(from: 0, to: frameLength, by: chunkSize) {
                    let currentChunkSize = min(chunkSize, frameLength - frameOffset)
                    for frame in 0..<currentChunkSize {
                        let monoValue = (leftChannel[frameOffset + frame] + rightChannel[frameOffset + frame]) * 0.5
                        leftChannel[frameOffset + frame] = monoValue
                        rightChannel[frameOffset + frame] = monoValue
                    }
                }
            }

            DLOG("Successfully set up mono processing")
        } catch {
            ELOG("Failed to install mono tap: \(error.localizedDescription)")
        }
    }

    private func startEngineWithErrorHandling() throws {
        do {
            try engine.start()
        } catch {
            ELOG("Failed to start audio engine: \(error.localizedDescription)")
            throw AudioEngineError.engineStartFailed
        }
    }
}
