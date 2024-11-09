import Foundation
import AVFoundation
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio
import PVSettings
import Accelerate

@available(macOS 11.0, iOS 14.0, *)
final public class AVAudioEngineGameAudioEngine: AudioEngineProtocol {

    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    private var src: AVAudioSourceNode?
    internal weak var gameCore: EmulatorCoreAudioDataSource!
    private var isRunning = false

    public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    private lazy var varispeedNode: AVAudioUnitVarispeed = {
        let node = AVAudioUnitVarispeed()
        return node
    }()

    private var audioConverter: AVAudioConverter?
    private var audioConverterRequiredFrameCount: AVAudioFrameCount?
    private var inputBuffer: AVAudioPCMBuffer?


    private lazy var audioFormat: AVAudioFormat? = {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2,
            interleaved: false
        )
    }()

    /// Pre-allocated output buffer
    private var outputBuffer: AVAudioPCMBuffer?
    private let maxFrameCapacity: AVAudioFrameCount = 2048  /// Safe maximum size

    public init() {
        configureAudioSession()
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        self.gameCore = gameCore
    }

    /// Type alias for the read block
    typealias OEAudioBufferReadBlock = (UnsafeMutableRawPointer, Int) -> Int

    /// Kaiser window helper function
    private func createKaiserWindow(size: Int, beta: Double) -> [Double] {
        var window = [Double](repeating: 0.0, count: size)
        let iZero = modifiedBessel0(beta)

        for i in 0..<size {
            let x = beta * sqrt(1.0 - pow(2.0 * Double(i) / Double(size - 1) - 1.0, 2))
            window[i] = modifiedBessel0(x) / iZero
        }

        return window
    }

    /// Modified Bessel function of the first kind, order 0
    private func modifiedBessel0(_ x: Double) -> Double {
        var sum = 1.0
        var term = 1.0

        for k in 1...20 {  // 20 terms is usually sufficient
            let xk = x / 2.0
            term *= (xk * xk) / (Double(k) * Double(k))
            sum += term

            if term < 1e-12 { break }
        }

        return sum
    }

    private func readBlockForBuffer(_ buffer: RingBufferProtocol) -> (AVAudioPCMBuffer) -> Int {
        /// Cache format information
        let sourceChannels: Int = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth: UInt = gameCore.audioBitDepth
        let sourceRate: Double = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame: Int = sourceChannels * (Int(sourceBitDepth) / 8)

        /// Pre-allocate conversion buffers - size for worst case
        let maxFrames: Int = 4096
        var sourceBuffer8: [Int8]? = nil
        var sourceBuffer16: [Int16]? = nil

        if sourceBitDepth == 8 {
            sourceBuffer8 = [Int8](repeating: 0, count: maxFrames * 2)
        } else {
            sourceBuffer16 = [Int16](repeating: 0, count: maxFrames * 2)
        }

        return { [sourceBitDepth, sourceChannels, sourceBytesPerFrame] (pcmBuffer: AVAudioPCMBuffer) -> Int in
            let availableBytes: Int = buffer.availableBytes
            if availableBytes == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            /// Calculate frames we can read
            let availableFrames: Int = availableBytes / sourceBytesPerFrame
            let framesToRead: Int = min(availableFrames, maxFrames)
            let bytesToRead: Int = framesToRead * sourceBytesPerFrame

            guard let outputData: UnsafeMutablePointer<Int16> = pcmBuffer.int16ChannelData?[0] else { return 0 }

            if sourceBitDepth == 8 {
                /// Handle 8-bit source
                guard var source8: [Int8] = sourceBuffer8 else { return 0 }

                let bytesRead: Int = buffer.read(
                    UnsafeMutableRawPointer(&source8),
                    preferredSize: bytesToRead
                )
                let samplesRead: Int = bytesRead

                if sourceChannels == 1 {
                    /// Process 8 samples at a time for mono
                    let simdCount: Int = samplesRead / 8
                    for i in 0..<simdCount {
                        /// Load 8 samples
                        let monoVector: SIMD8<Int8> = SIMD8<Int8>(
                            source8[i * 8 + 0],
                            source8[i * 8 + 1],
                            source8[i * 8 + 2],
                            source8[i * 8 + 3],
                            source8[i * 8 + 4],
                            source8[i * 8 + 5],
                            source8[i * 8 + 6],
                            source8[i * 8 + 7]
                        )

                        /// Convert Int8 to Int16 and shift
                        let monoVector16: SIMD8<Int16> = SIMD8<Int16>(
                            Int16(monoVector[0]) << 8,
                            Int16(monoVector[1]) << 8,
                            Int16(monoVector[2]) << 8,
                            Int16(monoVector[3]) << 8,
                            Int16(monoVector[4]) << 8,
                            Int16(monoVector[5]) << 8,
                            Int16(monoVector[6]) << 8,
                            Int16(monoVector[7]) << 8
                        )

                        /// Interleave mono samples to stereo
                        for j in 0..<8 {
                            let outputIndex: Int = (i * 16) + (j * 2)
                            outputData[outputIndex] = monoVector16[j]     /// Left
                            outputData[outputIndex + 1] = monoVector16[j] /// Right
                        }
                    }

                    /// Handle remaining samples
                    let remaining: Int = samplesRead % 8
                    if remaining > 0 {
                        let startIdx: Int = simdCount * 8
                        for i in 0..<remaining {
                            let sample: Int16 = Int16(source8[startIdx + i]) << 8
                            let outputIndex: Int = (simdCount * 16) + (i * 2)
                            outputData[outputIndex] = sample     /// Left
                            outputData[outputIndex + 1] = sample /// Right
                        }
                    }

                    pcmBuffer.frameLength = AVAudioFrameCount(samplesRead)
                } else {
                    /// Process 16 samples at a time for stereo
                    let simdCount: Int = (samplesRead / 16) * 2  /// Process pairs for stereo
                    for i in 0..<simdCount {
                        let stereoVector: SIMD8<Int8> = SIMD8<Int8>(
                            source8[i * 8 + 0],
                            source8[i * 8 + 1],
                            source8[i * 8 + 2],
                            source8[i * 8 + 3],
                            source8[i * 8 + 4],
                            source8[i * 8 + 5],
                            source8[i * 8 + 6],
                            source8[i * 8 + 7]
                        )

                        let stereoVector16: SIMD8<Int16> = SIMD8<Int16>(
                            Int16(stereoVector[0]) << 8,
                            Int16(stereoVector[1]) << 8,
                            Int16(stereoVector[2]) << 8,
                            Int16(stereoVector[3]) << 8,
                            Int16(stereoVector[4]) << 8,
                            Int16(stereoVector[5]) << 8,
                            Int16(stereoVector[6]) << 8,
                            Int16(stereoVector[7]) << 8
                        )

                        /// Store converted stereo samples
                        for j in 0..<8 {
                            outputData[i * 8 + j] = stereoVector16[j]
                        }
                    }

                    /// Handle remaining samples
                    let remaining: Int = (samplesRead % 16) / 2
                    if remaining > 0 {
                        let startIdx: Int = simdCount * 8
                        for i in 0..<remaining {
                            outputData[startIdx + i] = Int16(source8[startIdx * 2 + i * 2]) << 8
                            outputData[startIdx + i + 1] = Int16(source8[startIdx * 2 + i * 2 + 1]) << 8
                        }
                    }

                    pcmBuffer.frameLength = AVAudioFrameCount(samplesRead / 2)
                }

                return bytesRead

            } else {
                /// Handle 16-bit source
                guard var source16: [Int16] = sourceBuffer16 else { return 0 }

                let bytesRead: Int = buffer.read(
                    UnsafeMutableRawPointer(&source16),
                    preferredSize: bytesToRead
                )
                let samplesRead: Int = bytesRead / 2

                if sourceChannels == 1 {
                    /// Process 8 samples at a time
                    let simdCount: Int = samplesRead / 8
                    for i in 0..<simdCount {
                        let monoVector: SIMD8<Int16> = SIMD8<Int16>(
                            source16[i * 8 + 0],
                            source16[i * 8 + 1],
                            source16[i * 8 + 2],
                            source16[i * 8 + 3],
                            source16[i * 8 + 4],
                            source16[i * 8 + 5],
                            source16[i * 8 + 6],
                            source16[i * 8 + 7]
                        )

                        /// Interleave mono samples to stereo
                        for j in 0..<8 {
                            let outputIndex: Int = (i * 16) + (j * 2)
                            outputData[outputIndex] = monoVector[j]     /// Left
                            outputData[outputIndex + 1] = monoVector[j] /// Right
                        }
                    }

                    /// Handle remaining samples
                    let remaining: Int = samplesRead % 8
                    if remaining > 0 {
                        let startIdx: Int = simdCount * 8
                        for i in 0..<remaining {
                            let sample: Int16 = source16[startIdx + i]
                            let outputIndex: Int = (simdCount * 16) + (i * 2)
                            outputData[outputIndex] = sample     /// Left
                            outputData[outputIndex + 1] = sample /// Right
                        }
                    }

                    pcmBuffer.frameLength = AVAudioFrameCount(samplesRead)
                } else {
                    /// Already stereo, just copy
                    memcpy(outputData, source16, bytesRead)
                    pcmBuffer.frameLength = AVAudioFrameCount(samplesRead / 2)
                }

                return bytesRead
            }
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        /// Create format using standard device format
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2  /// Standard stereo output
        ) else {
            ELOG("Failed to create format")
            return
        }

        DLOG("Using standard device format: \(format.description)")

        /// Pre-allocate output buffer
        outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrameCapacity)

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)

        let renderBlock: AVAudioSourceNodeRenderBlock = { [weak self] isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            if frameCount == 0 || frameCount > self.maxFrameCapacity {
                ELOG("Invalid frame count requested: \(frameCount)")
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                return noErr
            }

            guard let pcmBuffer = self.outputBuffer else {
                ELOG("Output buffer not allocated")
                isSilence.pointee = true
                return noErr
            }

            pcmBuffer.frameLength = frameCount
            let bytesCopied = read(pcmBuffer)

            if bytesCopied == 0 {
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                return noErr
            }

            /// Copy interleaved data directly
            if let source = pcmBuffer.int16ChannelData?[0],
               let dest = ablPointer[0].mData?.assumingMemoryBound(to: Int16.self) {
                let count = Int(pcmBuffer.frameLength) * 2  /// 2 channels
                memcpy(dest, source, count * 2)  /// 2 bytes per sample
                ablPointer[0].mDataByteSize = UInt32(count * 2)
            }

            isSilence.pointee = false
            return noErr
        }

        src = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        guard let src else {
            ELOG("Failed to create audio source node")
            return
        }

        /// Setup audio chain with varispeed
        engine.attach(src)
        engine.attach(varispeedNode)

        engine.connect(src, to: varispeedNode, format: format)
        engine.connect(varispeedNode, to: engine.mainMixerNode, format: format)

        /// Set varispeed rate based on source rate
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let targetRate = AVAudioSession.sharedInstance().sampleRate
        let rateRatio = sourceRate / targetRate

        varispeedNode.rate = Float(rateRatio)

        DLOG("Audio setup - Source rate: \(sourceRate)Hz, Target rate: \(targetRate)Hz, Rate ratio: \(rateRatio)")

        engine.mainMixerNode.outputVolume = volume
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
        outputBuffer = nil  /// Clean up buffer
        isRunning = false
    }

    public func pauseAudio() {
        guard isRunning else { return }
        engine.pause()
        isRunning = false
    }

    private func configureAudioSession() {
#if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient,
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
}
