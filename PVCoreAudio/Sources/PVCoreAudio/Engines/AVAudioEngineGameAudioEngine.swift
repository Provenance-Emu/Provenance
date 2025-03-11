import Foundation
import AVFoundation
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio
import PVSettings
import Defaults

/// Audio context for managing buffer and performance metrics
private final class AudioEngineContext {
    var bufferUnderrunCount: Int = 0
    var currentBufferFrames: UInt32 = 4096
    private var performanceHistory: [Double] = []
    private let maxHistorySize = 10

    func trackPerformance(_ value: Double) {
        performanceHistory.append(value)
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }
    }

    var averagePerformance: Double {
        performanceHistory.reduce(0.0, +) / Double(performanceHistory.count)
    }
}

@available(macOS 11.0, iOS 14.0, *)
final public class AVAudioEngineGameAudioEngine: AudioEngineProtocol {
    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    private var src: AVAudioSourceNode?
    private weak var gameCore: EmulatorCoreAudioDataSource!
    private var isRunning = false
    private let context = AudioEngineContext()
    private let muteSwitchMonitor = PVMuteSwitchMonitor()

    /// Audio processing properties
    private let preferredBufferSize: UInt32 = 4096
    private let maxBufferSize: UInt32 = 8192
    private var lastProcessingTime: CFAbsoluteTime = 0

    public var volume: Float = 1.0 {
        didSet {
            updateOutputVolume()
        }
    }

    /// Filter support
    private let filterNode = AVAudioUnitEQ(numberOfBands: 1)
    public var filterEnabled: Bool = false {
        didSet {
            filterNode.bypass = !filterEnabled
        }
    }

    /// Delegate for audio sample rate changes
    public weak var delegate: PVAudioDelegate?

    /// Whether the audio engine is enabled
    public var isEnabled: Bool = true {
        didSet {
            updateOutputVolume()
        }
    }

    public init() {
        configureAudioSession()
        muteSwitchMonitor.startMonitoring { [weak self] isMuted in
            self?.updateOutputVolume()
        }

        // Observe changes to respectMuteSwitch setting
        Task {
            for await newValue in Defaults.updates(Defaults.Keys.respectMuteSwitch) {
                await MainActor.run { [weak self] in
                    self?.updateOutputVolume()
                }
            }
        }

        #if !os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }

    deinit {
        muteSwitchMonitor.stopMonitoring()
        stopAudio()
        #if !os(macOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    private func configureAudioSession() {
        #if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback category when ignoring mute switch, .ambient otherwise
            let category: AVAudioSession.Category = Defaults[.respectMuteSwitch] ? .ambient : .playback
            try session.setCategory(category,
                                  mode: .default,
                                  options: [.mixWithOthers])
            let bufferDuration = Defaults[.audioLatency] / 1000.0
            try session.setPreferredIOBufferDuration(bufferDuration)
            try session.setActive(true)
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func updateOutputVolume() {
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        if !isEnabled {
            engine.mainMixerNode.outputVolume = 0.0
        } else if Defaults[.respectMuteSwitch] {
            // Only mute if using internal speaker and mute switch is on
            if muteSwitchMonitor.isMuted && !currentRoute.isOutputtingToExternalDevice {
                engine.mainMixerNode.outputVolume = 0.0
            } else {
                engine.mainMixerNode.outputVolume = volume
            }
        } else {
            // Ignore mute switch
            engine.mainMixerNode.outputVolume = volume
        }
        #else
        engine.mainMixerNode.outputVolume = volume
        #endif
    }

    @objc private func handleAudioRouteChange(notification: Notification) {
        #if !os(macOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            do {
                try configureAudioSession()
                try startAudio()
                updateOutputVolume() // Update volume based on new route
            } catch {
                handleAudioError(error)
            }
        default:
            break
        }
        #endif
    }

    private func notifySampleRateChange() {
        delegate?.audioSampleRateDidChange()
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        self.gameCore = gameCore
        // Notify delegate when sample rate changes during setup
        notifySampleRateChange()
    }

    /// Stream description computed property for audio format configuration
    private var streamDescription: AudioStreamBasicDescription {
        let channelCount = UInt32(gameCore.channelCount(forBuffer: 0))
        let sampleRate = gameCore.audioSampleRate(forBuffer: 0)
        let bitDepth = gameCore.audioBitDepth
        let bytesPerSample = bitDepth / 8

        DLOG("Core audio properties - Channels: \(channelCount), Rate: \(sampleRate), Bits: \(bitDepth)")

        return AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(bytesPerSample) * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSample) * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: UInt32(bitDepth),
            mReserved: 0)
    }

    typealias OEAudioBufferReadBlock = (UnsafeMutableRawPointer, Int) -> Int
    private func readBlockForBuffer(_ buffer: RingBufferProtocol) -> OEAudioBufferReadBlock {
        return { buf, max -> Int in
            let bytesAvailable = buffer.availableBytes
            let bytesPerSample = self.gameCore.audioBitDepth / 8
            let is8Bit = bytesPerSample == 1
            let sourceChannels = self.gameCore.channelCount(forBuffer: 0)

            // For 8-bit audio, we need to read half as many bytes since we'll expand to 16-bit
            let bytesToRead = min(bytesAvailable, is8Bit ? max / 2 : max)

            if bytesToRead == 0 {
                memset(buf, 0, max)
                return max
            }

            if is8Bit {
                // Create a temporary buffer for 8-bit data
                var source8 = [Int8](repeating: 0, count: bytesToRead)
                let bytesRead = buffer.read(UnsafeMutableRawPointer(&source8), preferredSize: bytesToRead)
                let samplesRead = bytesRead
                let output = buf.assumingMemoryBound(to: Int16.self)

                if sourceChannels == 1 {
                    // Process 8 samples at a time for mono
                    let simdCount = samplesRead / 8
                    for i in 0..<simdCount {
                        // Load 8 samples
                        let monoVector = SIMD8<Int8>(
                            source8[i * 8 + 0],
                            source8[i * 8 + 1],
                            source8[i * 8 + 2],
                            source8[i * 8 + 3],
                            source8[i * 8 + 4],
                            source8[i * 8 + 5],
                            source8[i * 8 + 6],
                            source8[i * 8 + 7]
                        )

                        // Convert Int8 to Int16 and shift
                        let monoVector16 = SIMD8<Int16>(
                            Int16(monoVector[0]) << 8,
                            Int16(monoVector[1]) << 8,
                            Int16(monoVector[2]) << 8,
                            Int16(monoVector[3]) << 8,
                            Int16(monoVector[4]) << 8,
                            Int16(monoVector[5]) << 8,
                            Int16(monoVector[6]) << 8,
                            Int16(monoVector[7]) << 8
                        )

                        // Interleave mono samples to stereo
                        for j in 0..<8 {
                            let outputIndex = (i * 16) + (j * 2)
                            output[outputIndex] = monoVector16[j]     // Left
                            output[outputIndex + 1] = monoVector16[j] // Right
                        }
                    }

                    // Handle remaining samples
                    let remaining = samplesRead % 8
                    if remaining > 0 {
                        let startIdx = simdCount * 8
                        for i in 0..<remaining {
                            let sample = Int16(source8[startIdx + i]) << 8
                            let outputIndex = (simdCount * 16) + (i * 2)
                            output[outputIndex] = sample     // Left
                            output[outputIndex + 1] = sample // Right
                        }
                    }
                } else {
                    // Process 16 samples at a time for stereo
                    let simdCount = (samplesRead / 16) * 2  // Process pairs for stereo
                    for i in 0..<simdCount {
                        let stereoVector = SIMD8<Int8>(
                            source8[i * 8 + 0],
                            source8[i * 8 + 1],
                            source8[i * 8 + 2],
                            source8[i * 8 + 3],
                            source8[i * 8 + 4],
                            source8[i * 8 + 5],
                            source8[i * 8 + 6],
                            source8[i * 8 + 7]
                        )

                        let stereoVector16 = SIMD8<Int16>(
                            Int16(stereoVector[0]) << 8,
                            Int16(stereoVector[1]) << 8,
                            Int16(stereoVector[2]) << 8,
                            Int16(stereoVector[3]) << 8,
                            Int16(stereoVector[4]) << 8,
                            Int16(stereoVector[5]) << 8,
                            Int16(stereoVector[6]) << 8,
                            Int16(stereoVector[7]) << 8
                        )

                        // Store converted stereo samples
                        for j in 0..<8 {
                            output[i * 8 + j] = stereoVector16[j]
                        }
                    }

                    // Handle remaining samples
                    let remaining = (samplesRead % 16) / 2
                    if remaining > 0 {
                        let startIdx = simdCount * 8
                        for i in 0..<remaining {
                            output[startIdx + i] = Int16(source8[startIdx * 2 + i * 2]) << 8
                            output[startIdx + i + 1] = Int16(source8[startIdx * 2 + i * 2 + 1]) << 8
                        }
                    }
                }

                if bytesRead * 2 < max {
                    memset(buf.advanced(by: bytesRead * 2), 0, max - (bytesRead * 2))
                }

                return max
            } else {
                // Handle 16-bit normally
                let bytesRead = buffer.read(buf, preferredSize: bytesToRead)

                if bytesRead < max {
                    memset(buf.advanced(by: bytesRead), 0, max - bytesRead)
                }

                return max
            }
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        guard let ringBuffer = gameCore.ringBuffer(atIndex: 0) else {
            ELOG("Failed to get ring buffer")
            return
        }

        let read = readBlockForBuffer(ringBuffer)
        var sd = streamDescription

        /// Create format with explicit settings for iOS compatibility
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sd.mSampleRate,
            channels: sd.mChannelsPerFrame,
            interleaved: true
        ) else {
            ELOG("Failed to create AVAudioFormat")
            return
        }

        src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, inputData in
            guard let self = self else { return noErr }

            let startTime = CFAbsoluteTimeGetCurrent()
            let bytesPerFrame = sd.mBytesPerFrame
            let bytesRequested = Int(frameCount * bytesPerFrame)

            let bytesCopied = read(inputData.pointee.mBuffers.mData!, bytesRequested)

            /// Track performance and adjust buffer size if needed
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            self.context.trackPerformance(processingTime)
            self.adjustBufferSizeIfNeeded(processingTime: processingTime)

            if bytesCopied < bytesRequested {
                self.context.bufferUnderrunCount += 1
                DLOG("Buffer underrun detected: \(self.context.bufferUnderrunCount)")
            }

            inputData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied)
            inputData.pointee.mBuffers.mNumberChannels = sd.mChannelsPerFrame

            return noErr
        }

        guard let src = src else {
            ELOG("Failed to create source node")
            return
        }

        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)
        DLOG("Source node updated and connected successfully")
    }

    /// Adjusts buffer size based on performance metrics
    private func adjustBufferSizeIfNeeded(processingTime: Double) {
        if context.bufferUnderrunCount > 5 {
            let optimalFrames = min(context.currentBufferFrames * 2, maxBufferSize)
            if optimalFrames != context.currentBufferFrames {
                context.currentBufferFrames = optimalFrames
                DLOG("Adjusted buffer size to: \(optimalFrames) frames")
            }
        }
    }

    /// Logs detailed audio format information
    private func logAudioFormat(_ format: AudioStreamBasicDescription, label: String) {
        DLOG("\(label):")
        DLOG("- Sample Rate: \(format.mSampleRate)")
        DLOG("- Channels: \(format.mChannelsPerFrame)")
        DLOG("- Bits: \(format.mBitsPerChannel)")
        DLOG("- Bytes/Frame: \(format.mBytesPerFrame)")
        DLOG("- Format ID: \(format.mFormatID)")
    }

    public func startAudio() {
        precondition(gameCore.audioBufferCount == 1,
                    "Only one buffer supported; got \(gameCore.audioBufferCount)")

        updateSourceNode()
        engine.prepare()

        isRunning = true
        do {
            try engine.start()
        } catch {
            ELOG("Unable to start AVAudioEngine: \(error.localizedDescription)")
        }
    }

    public func stopAudio() {
        engine.stop()
        if let src {
            engine.detach(src)
        }
        src = nil
        isRunning = false
    }

    public func pauseAudio() {
        guard isRunning else { return }
        engine.pause()
        isRunning = false
    }

    /// Enhanced error handling
    private func handleAudioError(_ error: Error) {
        ELOG("Audio error occurred: \(error.localizedDescription)")

        do {
            stopAudio()
            Thread.sleep(forTimeInterval: 0.1)

            #if !os(macOS)
            configureAudioSession()
            #endif

            try engine.start()
            DLOG("Successfully recovered from audio error")
        } catch {
            ELOG("Failed to recover from audio error: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioEngineErrorNotification"),
                object: self,
                userInfo: ["error": error]
            )
        }
    }
}
