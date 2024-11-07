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
final public class GameAudioEngine2: AudioEngineProtocol {

    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    private var src: AVAudioSourceNode?
    private weak var gameCore: EmulatorCoreAudioDataSource!
    private var isRunning = false

    public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    private lazy var audioFormat: AVAudioFormat? = {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 2,
            interleaved: false
        )
    }()

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
        let sourceChannels = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth = gameCore.audioBitDepth
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame = sourceChannels * (Int(sourceBitDepth) / 8)

        /// Setup conversion parameters
        let targetRate: Double = 48000.0
        let resampleRatio = Double(sourceRate) / targetRate

        /// Adjust playback position to maintain correct timing
        var playbackPosition: Double = 0.0
        let playbackIncrement = resampleRatio  /// This maintains original timing

        /// 4-point interpolation
        let filterLength = 4
        var coefficients = [Float](repeating: 0, count: filterLength)

        return { pcmBuffer in
            let targetFrameCount = Int(pcmBuffer.frameCapacity)
            let sourceFrameCount = Int(ceil(Double(targetFrameCount) * resampleRatio)) + filterLength
            let sourceBytesToRead = sourceFrameCount * sourceBytesPerFrame

            /// Read source data using SIMD-aligned buffer
            let alignment = MemoryLayout<SIMD8<Float>>.alignment
            let sourceBuffer = UnsafeMutableRawPointer.allocate(
                byteCount: sourceBytesToRead,
                alignment: alignment
            )
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: sourceBytesToRead)

            if bytesRead == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    if sourceChannels == 2 {
                        let framesAvailable = bytesRead / 4

                        /// Convert to float and scale
                        var leftChannel = [Float](repeating: 0, count: framesAvailable + filterLength)
                        var rightChannel = [Float](repeating: 0, count: framesAvailable + filterLength)

                        vDSP_vflt16(input, 2, &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vflt16(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(framesAvailable))

                        var scale = Float(1.0 / 32768.0)
                        vDSP_vsmul(leftChannel, 1, &scale, &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vsmul(rightChannel, 1, &scale, &rightChannel, 1, vDSP_Length(framesAvailable))

                        let resampledLeft = UnsafeMutablePointer<Float>(pcmBuffer.floatChannelData![0])
                        let resampledRight = UnsafeMutablePointer<Float>(pcmBuffer.floatChannelData![1])

                        /// Process in SIMD-friendly chunks
                        let chunkSize = 8 * 16  // Process 128 samples at a time

                        leftChannel.withUnsafeBufferPointer { leftPtr in
                            rightChannel.withUnsafeBufferPointer { rightPtr in
                                for i in 0..<targetFrameCount {
                                    let sourceIndex = Float(playbackPosition)
                                    let index = Int(floor(Double(sourceIndex)))
                                    let fraction = sourceIndex - Float(index)

                                    /// Calculate cubic interpolation coefficients
                                    coefficients[0] = (1.0 - fraction) * (1.0 - fraction) * (1.0 - fraction)
                                    coefficients[1] = 3.0 * fraction * (1.0 - fraction) * (1.0 - fraction)
                                    coefficients[2] = 3.0 * fraction * fraction * (1.0 - fraction)
                                    coefficients[3] = fraction * fraction * fraction

                                    if index + filterLength <= framesAvailable {
                                        vDSP_dotpr(coefficients, 1,
                                                 leftPtr.baseAddress!.advanced(by: index), 1,
                                                 resampledLeft.advanced(by: i),
                                                 vDSP_Length(1))

                                        vDSP_dotpr(coefficients, 1,
                                                 rightPtr.baseAddress!.advanced(by: index), 1,
                                                 resampledRight.advanced(by: i),
                                                 vDSP_Length(1))
                                    } else {
                                        /// Handle edge case
                                        let lastValidIndex = framesAvailable - 1
                                        resampledLeft[i] = leftChannel[lastValidIndex]
                                        resampledRight[i] = rightChannel[lastValidIndex]
                                    }

                                    /// Increment playback position to maintain timing
                                    playbackPosition += playbackIncrement
                                }
                            }
                        }

                        /// Reset playback position if needed
                        if playbackPosition >= Double(framesAvailable) {
                            playbackPosition -= Double(framesAvailable)
                        }

                        pcmBuffer.frameLength = AVAudioFrameCount(targetFrameCount)
                    }
                }
            }

            return bytesRead
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        /// Create format for non-interleaved float stereo
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 2,
            interleaved: false    /// Non-interleaved for mixer compatibility
        ) else {
            ELOG("Failed to create format")
            return
        }

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)

        /// Create source node with SIMD-optimized rendering block
        let renderBlock: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            /// Create a PCM buffer to hold the audio data
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                isSilence.pointee = true
                return noErr
            }

            /// Read into PCM buffer
            let bytesCopied = read(pcmBuffer)

            if bytesCopied == 0 {
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                ablPointer[1].mDataByteSize = 0
                return noErr
            }

            /// Get pointers for SIMD operations
            let sourceLeft = pcmBuffer.floatChannelData?.pointee
            let sourceRight = pcmBuffer.floatChannelData?.advanced(by: 1).pointee
            let destLeft = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
            let destRight = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)

            guard let sourceLeft = sourceLeft,
                  let sourceRight = sourceRight,
                  let destLeft = destLeft,
                  let destRight = destRight else {
                isSilence.pointee = true
                return noErr
            }

            /// Process in chunks of 8 samples using SIMD
            let simdCount = Int(frameCount) / 8
            for i in 0..<simdCount {
                let leftChunk = SIMD8<Float>(
                    sourceLeft[i * 8 + 0],
                    sourceLeft[i * 8 + 1],
                    sourceLeft[i * 8 + 2],
                    sourceLeft[i * 8 + 3],
                    sourceLeft[i * 8 + 4],
                    sourceLeft[i * 8 + 5],
                    sourceLeft[i * 8 + 6],
                    sourceLeft[i * 8 + 7]
                )

                let rightChunk = SIMD8<Float>(
                    sourceRight[i * 8 + 0],
                    sourceRight[i * 8 + 1],
                    sourceRight[i * 8 + 2],
                    sourceRight[i * 8 + 3],
                    sourceRight[i * 8 + 4],
                    sourceRight[i * 8 + 5],
                    sourceRight[i * 8 + 6],
                    sourceRight[i * 8 + 7]
                )

                /// Store SIMD vectors directly
                withUnsafePointer(to: leftChunk) { ptr in
                    ptr.withMemoryRebound(to: Float.self, capacity: 8) { floatPtr in
                        (destLeft + (i * 8)).initialize(from: floatPtr, count: 8)
                    }
                }

                withUnsafePointer(to: rightChunk) { ptr in
                    ptr.withMemoryRebound(to: Float.self, capacity: 8) { floatPtr in
                        (destRight + (i * 8)).initialize(from: floatPtr, count: 8)
                    }
                }
            }

            /// Handle remaining samples
            let remainingSamples = Int(frameCount) % 8
            if remainingSamples > 0 {
                let startIdx = simdCount * 8
                for i in 0..<remainingSamples {
                    destLeft[startIdx + i] = sourceLeft[startIdx + i]
                    destRight[startIdx + i] = sourceRight[startIdx + i]
                }
            }

            isSilence.pointee = false
            ablPointer[0].mDataByteSize = UInt32(frameCount * 4)
            ablPointer[1].mDataByteSize = UInt32(frameCount * 4)

            return noErr
        }

        src = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        guard let src else {
            ELOG("Failed to create audio source node")
            return
        }

        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)
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
