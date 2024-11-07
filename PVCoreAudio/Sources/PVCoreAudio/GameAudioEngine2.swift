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

    private lazy var varispeedNode: AVAudioUnitVarispeed = {
        let node = AVAudioUnitVarispeed()
        return node
    }()

    private lazy var audioFormat: AVAudioFormat? = {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AVAudioSession.sharedInstance().sampleRate,
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
        let targetRate = AVAudioSession.sharedInstance().sampleRate
        let rateRatio = Double(sourceRate) / targetRate

        /// Setup low-pass filter
        let filterSize = 4
        var filterCoeff = [Float](repeating: 0, count: filterSize)
        vDSP_hamm_window(&filterCoeff, vDSP_Length(filterSize), 0)
        var sum: Float = 0
        vDSP_sve(filterCoeff, 1, &sum, vDSP_Length(filterSize))
        vDSP_vsdiv(filterCoeff, 1, &sum, &filterCoeff, 1, vDSP_Length(filterSize))

        return { pcmBuffer in
            let targetFrameCount = Int(pcmBuffer.frameCapacity)

            /// Check available bytes in ring buffer
            let availableBytes = buffer.availableBytes
            let availableFrames = availableBytes / sourceBytesPerFrame

            /// Calculate needed frames including extra for interpolation and filtering
            let neededFrames = Int(ceil(Double(targetFrameCount) * rateRatio)) + filterSize

            /// Use the minimum of what we need and what's available
            let framesToRead = min(neededFrames, availableFrames)
            let bytesToRead = framesToRead * sourceBytesPerFrame

            /// Early exit if we don't have enough data
            if framesToRead < 2 {  /// Need at least 2 frames for interpolation
                pcmBuffer.frameLength = 0
                return 0
            }

            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesToRead)
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: bytesToRead)

            if bytesRead == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            /// Calculate actual frames available from bytes read
            let sourceFrames = bytesRead / sourceBytesPerFrame

            /// Adjust output frames based on what we actually got
            let outputFrames = min(
                targetFrameCount,
                Int(Double(sourceFrames - 1) / rateRatio)  /// -1 for interpolation safety
            )

            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    let sourceFrames = bytesRead / (2 * sourceChannels)  /// Account for mono/stereo

                    /// Create temporary buffers
                    var leftChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var rightChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredLeft = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredRight = [Float](repeating: 0, count: sourceFrames + filterSize)

                    /// Convert to float with headroom
                    var scale = Float(0.9 / 32768.0)

                    if sourceChannels == 2 {
                        /// Stereo source
                        vDSP_vflt16(input, 2, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_vflt16(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(sourceFrames))
                    } else {
                        /// Mono source - convert once and copy to both channels
                        vDSP_vflt16(input, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_mmov(&leftChannel, &rightChannel, vDSP_Length(sourceFrames), 1, 1, 1)
                    }

                    /// Apply scaling
                    vDSP_vsmul(leftChannel, 1, &scale, &leftChannel, 1, vDSP_Length(sourceFrames))
                    vDSP_vsmul(rightChannel, 1, &scale, &rightChannel, 1, vDSP_Length(sourceFrames))

                    /// Apply low-pass filter
                    vDSP_conv(leftChannel, 1, filterCoeff, 1, &filteredLeft, 1,
                            vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    vDSP_conv(rightChannel, 1, filterCoeff, 1, &filteredRight, 1,
                            vDSP_Length(sourceFrames), vDSP_Length(filterSize))

                    /// Get output buffer pointers
                    let outLeft = pcmBuffer.floatChannelData?[0]
                    let outRight = pcmBuffer.floatChannelData?[1]

                    /// Perform SIMD linear interpolation
                    let outputFrames = min(targetFrameCount, sourceFrames - 1)
                    let simdCount = outputFrames & ~7  /// Round down to multiple of 8

                    /// Process 8 samples at a time using SIMD
                    for i in stride(from: 0, to: simdCount, by: 8) {
                        /// Calculate source positions for 8 samples
                        let baseIndex = Double(i) * rateRatio
                        let indices = SIMD8<Double>(
                            baseIndex,
                            baseIndex + rateRatio,
                            baseIndex + rateRatio * 2,
                            baseIndex + rateRatio * 3,
                            baseIndex + rateRatio * 4,
                            baseIndex + rateRatio * 5,
                            baseIndex + rateRatio * 6,
                            baseIndex + rateRatio * 7
                        )

                        /// Get integer indices and fractions
                        var sourceIndices = SIMD8<Int>()
                        var fractions = SIMD8<Float>()

                        for j in 0..<8 {
                            let index = floor(indices[j])
                            sourceIndices[j] = Int(index)
                            fractions[j] = Float(indices[j] - index)
                        }

                        /// Load source samples
                        var leftLow = SIMD8<Float>()
                        var leftHigh = SIMD8<Float>()
                        var rightLow = SIMD8<Float>()
                        var rightHigh = SIMD8<Float>()

                        for j in 0..<8 {
                            leftLow[j] = filteredLeft[sourceIndices[j]]
                            leftHigh[j] = filteredLeft[sourceIndices[j] + 1]
                            rightLow[j] = filteredRight[sourceIndices[j]]
                            rightHigh[j] = filteredRight[sourceIndices[j] + 1]
                        }

                        /// Perform linear interpolation
                        let oneMinusFraction = 1.0 - fractions
                        let leftResult = leftLow * oneMinusFraction + leftHigh * fractions
                        let rightResult = rightLow * oneMinusFraction + rightHigh * fractions

                        /// Store results
                        for j in 0..<8 {
                            outLeft?[i + j] = leftResult[j]
                            outRight?[i + j] = rightResult[j]
                        }
                    }

                    /// Handle remaining samples
                    for i in simdCount..<outputFrames {
                        let sourcePos = Double(i) * rateRatio
                        let sourceIndex = Int(floor(sourcePos))
                        let fraction = Float(sourcePos - Double(sourceIndex))

                        if sourceIndex + 1 < sourceFrames {
                            let leftSample = filteredLeft[sourceIndex] * (1.0 - fraction) +
                                           filteredLeft[sourceIndex + 1] * fraction
                            let rightSample = filteredRight[sourceIndex] * (1.0 - fraction) +
                                            filteredRight[sourceIndex + 1] * fraction

                            outLeft?[i] = leftSample
                            outRight?[i] = rightSample
                        } else {
                            outLeft?[i] = filteredLeft[sourceIndex]
                            outRight?[i] = filteredRight[sourceIndex]
                        }
                    }

                    pcmBuffer.frameLength = AVAudioFrameCount(targetFrameCount)
                }
            } else if sourceBitDepth == 8 {
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    let sourceFrames = bytesRead / sourceChannels

                    /// Create temporary buffers
                    var leftChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var rightChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredLeft = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredRight = [Float](repeating: 0, count: sourceFrames + filterSize)

                    /// Convert to float with headroom (8-bit range is -128 to 127)
                    var scale = Float(0.9 / 128.0)

                    if sourceChannels == 2 {
                        /// Stereo source
                        var tempLeft = [Int8](repeating: 0, count: sourceFrames)
                        var tempRight = [Int8](repeating: 0, count: sourceFrames)

                        /// Deinterleave channels
                        for i in 0..<sourceFrames {
                            tempLeft[i] = input[i * 2]
                            tempRight[i] = input[i * 2 + 1]
                        }

                        /// Convert to float
                        vDSP_vflt8(tempLeft, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_vflt8(tempRight, 1, &rightChannel, 1, vDSP_Length(sourceFrames))
                    } else {
                        /// Mono source - convert once and copy to both channels
                        vDSP_vflt8(input, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_mmov(&leftChannel, &rightChannel, vDSP_Length(sourceFrames), 1, 1, 1)
                    }

                    /// Apply scaling
                    vDSP_vsmul(leftChannel, 1, &scale, &leftChannel, 1, vDSP_Length(sourceFrames))
                    vDSP_vsmul(rightChannel, 1, &scale, &rightChannel, 1, vDSP_Length(sourceFrames))

                    /// Apply low-pass filter
                    vDSP_conv(leftChannel, 1, filterCoeff, 1, &filteredLeft, 1,
                            vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    vDSP_conv(rightChannel, 1, filterCoeff, 1, &filteredRight, 1,
                            vDSP_Length(sourceFrames), vDSP_Length(filterSize))

                    /// Get output buffer pointers
                    let outLeft = pcmBuffer.floatChannelData?[0]
                    let outRight = pcmBuffer.floatChannelData?[1]

                    /// Perform SIMD linear interpolation
                    let outputFrames = min(targetFrameCount, sourceFrames - 1)
                    let simdCount = outputFrames & ~7  /// Round down to multiple of 8

                    /// Process 8 samples at a time using SIMD
                    for i in stride(from: 0, to: simdCount, by: 8) {
                        let baseIndex = Double(i) * rateRatio
                        let indices = SIMD8<Double>(
                            baseIndex,
                            baseIndex + rateRatio,
                            baseIndex + rateRatio * 2,
                            baseIndex + rateRatio * 3,
                            baseIndex + rateRatio * 4,
                            baseIndex + rateRatio * 5,
                            baseIndex + rateRatio * 6,
                            baseIndex + rateRatio * 7
                        )

                        var sourceIndices = SIMD8<Int>()
                        var fractions = SIMD8<Float>()

                        for j in 0..<8 {
                            let index = floor(indices[j])
                            sourceIndices[j] = Int(index)
                            fractions[j] = Float(indices[j] - index)
                        }

                        var leftLow = SIMD8<Float>()
                        var leftHigh = SIMD8<Float>()
                        var rightLow = SIMD8<Float>()
                        var rightHigh = SIMD8<Float>()

                        for j in 0..<8 {
                            leftLow[j] = filteredLeft[sourceIndices[j]]
                            leftHigh[j] = filteredLeft[sourceIndices[j] + 1]
                            rightLow[j] = filteredRight[sourceIndices[j]]
                            rightHigh[j] = filteredRight[sourceIndices[j] + 1]
                        }

                        let oneMinusFraction = 1.0 - fractions
                        let leftResult = leftLow * oneMinusFraction + leftHigh * fractions
                        let rightResult = rightLow * oneMinusFraction + rightHigh * fractions

                        for j in 0..<8 {
                            outLeft?[i + j] = leftResult[j]
                            outRight?[i + j] = rightResult[j]
                        }
                    }

                    /// Handle remaining samples
                    for i in simdCount..<outputFrames {
                        let sourcePos = Double(i) * rateRatio
                        let sourceIndex = Int(floor(sourcePos))
                        let fraction = Float(sourcePos - Double(sourceIndex))

                        if sourceIndex + 1 < sourceFrames {
                            let leftSample = filteredLeft[sourceIndex] * (1.0 - fraction) +
                                           filteredLeft[sourceIndex + 1] * fraction
                            let rightSample = filteredRight[sourceIndex] * (1.0 - fraction) +
                                            filteredRight[sourceIndex + 1] * fraction

                            outLeft?[i] = leftSample
                            outRight?[i] = rightSample
                        } else {
                            outLeft?[i] = filteredLeft[sourceIndex]
                            outRight?[i] = filteredRight[sourceIndex]
                        }
                    }

                    pcmBuffer.frameLength = AVAudioFrameCount(targetFrameCount)
                }
            }

            /// Set actual frame length
            pcmBuffer.frameLength = AVAudioFrameCount(outputFrames)

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
            sampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2,
            interleaved: false
        ) else {
            ELOG("Failed to create format")
            return
        }

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)

        /// Create source node
        let renderBlock: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                isSilence.pointee = true
                return noErr
            }

            let bytesCopied = read(pcmBuffer)

            if bytesCopied == 0 {
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                ablPointer[1].mDataByteSize = 0
                return noErr
            }

            /// Copy only the valid frames to output buffers
            for i in 0..<2 {
                let source = pcmBuffer.floatChannelData?[i]
                let dest = ablPointer[i].mData?.assumingMemoryBound(to: Float.self)
                let count = Int(pcmBuffer.frameLength)

                vDSP_mmov(source!, dest!, vDSP_Length(count), 1, 1, 1)
                ablPointer[i].mDataByteSize = UInt32(count * 4)
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

        /// Adjust varispeed rate since we're also interpolating
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
