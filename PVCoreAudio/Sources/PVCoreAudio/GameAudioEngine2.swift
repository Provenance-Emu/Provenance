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

    /// Add conversion state structure
    private struct ConversionState {
        var converter: AudioConverterRef?
        var inputFormat: AudioStreamBasicDescription
        var outputFormat: AudioStreamBasicDescription
        var ringBuffer: RingBufferProtocol?
    }

    /// Static C callback function
    private static let converterCallback: AudioConverterComplexInputDataProc = { (
        converter,
        ioNumberDataPackets,
        ioData,
        outDataPacketDescription,
        inUserData
    ) -> OSStatus in
        guard let contextPtr = inUserData else {
            return kAudio_ParamError
        }

        /// Get conversion state from context
        let state = contextPtr.assumingMemoryBound(to: ConversionState.self).pointee

        /// Read from ring buffer
        let bytesRequested = Int(ioNumberDataPackets.pointee) * Int(state.inputFormat.mBytesPerFrame)
        var buffer = [UInt8](repeating: 0, count: bytesRequested)

        let bytesCopied = state.ringBuffer?.read(&buffer, preferredSize: bytesRequested) ?? 0

        /// Setup buffer list
        ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: buffer)
        ioData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied)
        ioData.pointee.mBuffers.mNumberChannels = state.inputFormat.mChannelsPerFrame

        return noErr
    }

    /// Instance property to hold conversion state
    private var conversionState: ConversionState?

    /// Add time pitch node for better rate control
    private lazy var timePitchNode: AVAudioUnitTimePitch = {
        let node = AVAudioUnitTimePitch()
        node.rate = 1.0
        return node
    }()

    /// Add varispeed node for better rate control
    private lazy var varispeedNode: AVAudioUnitVarispeed = {
        let node = AVAudioUnitVarispeed()
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
        isRunning = false
    }

    public func pauseAudio() {
        engine.pause()

        // Detach the source node to stop audio processing
        if let src = src {
            engine.detach(src)
            self.src = nil
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
            /// Ensure we read complete frames
            let bytesPerFrame = Int(self.streamDescription.mBytesPerFrame)
            let bytesToRead = min(bytesAvailable, max) & ~(bytesPerFrame - 1)

            let bytesCopied = buffer.read(buf, preferredSize: bytesToRead)

            /// If we didn't read enough data, fill with silence
            if bytesCopied < max {
                let silence = Data(count: max - bytesCopied)
                silence.copyBytes(to: buf.assumingMemoryBound(to: UInt8.self).advanced(by: bytesCopied),
                                count: max - bytesCopied)
            }

            return bytesCopied
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
            let actualChannels: UInt32 = 2  /// Interleaved stereo
            let bytesPerFrame = UInt32(bytesPerSample) * actualChannels

            DLOG("Using interleaved stereo format")
            return AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
                mBytesPerPacket: bytesPerFrame,
                mFramesPerPacket: 1,
                mBytesPerFrame: bytesPerFrame,
                mChannelsPerFrame: actualChannels,
                mBitsPerChannel: UInt32(bitDepth),
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

        var inputFormat = streamDescription
        let outputRate = AVAudioSession.sharedInstance().sampleRate

        /// Setup output format (float32, stereo)
        var outputFormat = AudioStreamBasicDescription(
            mSampleRate: outputRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0)

        /// Create audio converter
        var audioConverter: AudioConverterRef?
        var status = AudioConverterNew(&inputFormat, &outputFormat, &audioConverter)
        guard status == noErr, let converter = audioConverter else {
            ELOG("Failed to create audio converter: \(status)")
            return
        }

        /// Setup conversion state
        conversionState = ConversionState(
            converter: converter,
            inputFormat: inputFormat,
            outputFormat: outputFormat,
            ringBuffer: gameCore.ringBuffer(atIndex: 0)
        )

        DLOG("Converter setup - Input rate: \(inputFormat.mSampleRate), Output rate: \(outputRate)")

        src = AVAudioSourceNode { [weak self] _, timeStamp, frameCount, audioBufferList in
            guard let self = self,
                  let state = self.conversionState else { return noErr }

            /// Calculate output frames needed
            let outputFrames = Int(frameCount)
            var outputBuffer = [Float32](repeating: 0, count: outputFrames * 2)

            /// Setup conversion
            var outputBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 2,
                    mDataByteSize: UInt32(outputFrames * 8),
                    mData: UnsafeMutableRawPointer(&outputBuffer)
                )
            )

            var packets = UInt32(outputFrames)
            withUnsafePointer(to: state) { statePtr in
                status = AudioConverterFillComplexBuffer(
                    state.converter!,
                    Self.converterCallback,
                    UnsafeMutableRawPointer(mutating: statePtr),
                    &packets,
                    &outputBufferList,
                    nil
                )
            }

            /// Copy converted data to output
            let outputPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
            outputPtr[0].mData?.copyMemory(
                from: outputBuffer,
                byteCount: Int(outputBufferList.mBuffers.mDataByteSize)
            )
            outputPtr[0].mDataByteSize = outputBufferList.mBuffers.mDataByteSize

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

        // Clean up all attached nodes
        if engine.attachedNodes.contains(varispeedNode) {
            engine.detach(varispeedNode)
        }
        if engine.attachedNodes.contains(timePitchNode) {
            engine.detach(timePitchNode)
        }
        if engine.attachedNodes.contains(monoMixerNode) {
            engine.detach(monoMixerNode)
        }
    }

    private func connectNodes() {
        guard let src else { fatalError("Expected src node") }

        let inputRate = gameCore.audioSampleRate(forBuffer: 0)
        let outputRate = AVAudioSession.sharedInstance().sampleRate

        /// Always convert to float32 format first at input rate
        let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputRate,
            channels: 2,
            interleaved: false)!

        /// Output format at device rate
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputRate,
            channels: 2,
            interleaved: false)!

        if inputRate != outputRate {
            DLOG("Sample rate conversion needed - Input: \(inputRate), Output: \(outputRate)")

            if Defaults[.usePitchConversionInsteadOfSampleRate] {
                /// Attach both nodes before connecting
                engine.attach(src)
                engine.attach(timePitchNode)

                /// Then adjust pitch to match rate difference
                let rateRatio = outputRate / inputRate  /// Inverted ratio for pitch
                timePitchNode.rate = Float(rateRatio)
                DLOG("Using pitch conversion with rate ratio: \(rateRatio)")

                /// Now connect the nodes
                engine.connect(src, to: timePitchNode, format: inputFormat)
                engine.connect(timePitchNode, to: engine.mainMixerNode, format: outputFormat)
            } else {
                /// For sample rate conversion, use mixer node's built-in converter
                engine.attach(src)
                /// Connect with input format, mixer will handle conversion to output rate
                engine.connect(src, to: engine.mainMixerNode, format: inputFormat)
                /// Connect mixer to output at the desired rate
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
            }
        } else {
            /// No conversion needed, but still use float32 format
            engine.attach(src)
            engine.connect(src, to: engine.mainMixerNode, format: inputFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
        }

        DLOG("Formats - Input: \(inputFormat), Output: \(engine.mainMixerNode.outputFormat(forBus: 0))")
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

        /// For mono, connect through mono mixer first
        engine.connect(src, to: timePitchNode, format: renderFormat)
        engine.connect(timePitchNode, to: monoMixerNode, format: internalFormat)
        engine.connect(monoMixerNode, to: engine.mainMixerNode, format: internalFormat)

        monoMixerNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = buffer.frameLength
            let channelCount = buffer.format.channelCount

            guard channelCount == 2 else { return }

            let leftChannel = channelData[0]
            let rightChannel = channelData[1]

            for frame in 0..<Int(frameLength) {
                leftChannel[frame] = (leftChannel[frame] + rightChannel[frame]) / 2
                rightChannel[frame] = leftChannel[frame]
            }
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
