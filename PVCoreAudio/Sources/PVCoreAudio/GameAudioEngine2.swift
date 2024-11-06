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
    private func readBlockForBuffer(_ buffer: RingBufferProtocol) -> OEAudioBufferReadBlock {
        /// Cache format information
        let sourceChannels = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth = gameCore.audioBitDepth
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame = sourceChannels * (Int(sourceBitDepth) / 8)

        /// Calculate scale factor based on bit depth
        let scale = Float(1.0 / Float(1 << (sourceBitDepth - 1)))

        /// Setup conversion parameters
        let targetRate: Double = 48000.0
        let resampleRatio = targetRate / sourceRate

        /// Keep track of last samples for smooth transitions
        var lastSamples = [Float](repeating: 0.0, count: 2)

        DLOG("Audio setup - Source rate: \(sourceRate)Hz, Target rate: \(targetRate)Hz, Ratio: \(resampleRatio)")

        return { outputBuffer, maxBytes -> Int in
            let targetFrameCount = maxBytes / 8  /// 2 channels * 4 bytes (Float32)
            let sourceFrameCount = Int(ceil(Double(targetFrameCount) / resampleRatio)) + 2
            let sourceBytesToRead = sourceFrameCount * sourceBytesPerFrame

            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceBytesToRead)
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: sourceBytesToRead)
            let output = outputBuffer.assumingMemoryBound(to: Float.self)

            if bytesRead == 0 {
                /// Handle silence with fade out using vDSP
                let fadeLength = min(32, targetFrameCount * 2)
                var fadeWindow = [Float](repeating: 0.0, count: fadeLength)
                vDSP_vgen(
                    [1.0], [0.0],
                    &fadeWindow, 1,
                    vDSP_Length(fadeLength)
                )

                /// Create arrays for left and right channel fades
                let leftFade = [Float](repeating: lastSamples[0], count: fadeLength)
                let rightFade = [Float](repeating: lastSamples[1], count: fadeLength)

                /// Apply fade to left channel
                vDSP_vmul(
                    fadeWindow,                /// Input array A
                    1,                        /// Stride for A
                    leftFade,                 /// Input array B
                    1,                        /// Stride for B
                    output,                   /// Output array C
                    2,                        /// Stride for C (interleaved)
                    vDSP_Length(fadeLength/2) /// Number of points
                )

                /// Apply fade to right channel
                vDSP_vmul(
                    fadeWindow,                    /// Input array A
                    1,                            /// Stride for A
                    rightFade,                    /// Input array B
                    1,                            /// Stride for B
                    output.advanced(by: 1),       /// Output array C (offset for right channel)
                    2,                            /// Stride for C (interleaved)
                    vDSP_Length(fadeLength/2)     /// Number of points
                )

                /// Clear remaining buffer
                if fadeLength < targetFrameCount * 2 {
                    memset(
                        output.advanced(by: fadeLength),
                        0,
                        maxBytes - (fadeLength * 4)
                    )
                }

                lastSamples = [0.0, 0.0]
                return maxBytes
            }

            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    if sourceChannels == 2 {
                        let framesAvailable = bytesRead / 4  /// 2 channels * 2 bytes
                        var leftChannel = [Float](repeating: 0.0, count: framesAvailable)
                        var rightChannel = [Float](repeating: 0.0, count: framesAvailable)

                        /// Convert to float
                        vDSP_vflt16(input, 2, &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vflt16(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(framesAvailable))

                        /// Scale to -1.0 to 1.0
                        let scale: Float = 1.0 / 32768.0
                        vDSP_vsmul(leftChannel, 1, [scale], &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vsmul(rightChannel, 1, [scale], &rightChannel, 1, vDSP_Length(framesAvailable))

                        /// Setup resampling
                        let outputLength = vDSP_Length(targetFrameCount)
                        let inputLength = vDSP_Length(framesAvailable)

                        var resampledLeft = [Float](repeating: 0.0, count: targetFrameCount)
                        var resampledRight = [Float](repeating: 0.0, count: targetFrameCount)

                        /// Simple 2-point filter for resampling
                        var filter = [Float](repeating: 1.0, count: 2)

                        vDSP_desamp(
                            leftChannel,
                            vDSP_Stride(resampleRatio),
                            filter,
                            &resampledLeft,
                            vDSP_Length(targetFrameCount),
                            vDSP_Length(2)
                        )

                        vDSP_desamp(
                            rightChannel,
                            vDSP_Stride(resampleRatio),
                            filter,
                            &resampledRight,
                            vDSP_Length(targetFrameCount),
                            vDSP_Length(2)
                        )

                        /// Copy to output buffer (non-interleaved)
                        memcpy(output, resampledLeft, targetFrameCount * 4)
                        memcpy(output.advanced(by: targetFrameCount), resampledRight, targetFrameCount * 4)

                        /// Store last samples for fade out
                        lastSamples = [resampledLeft.last ?? 0.0, resampledRight.last ?? 0.0]

                        DLOG("Bytes read: \(bytesRead), Frames available: \(framesAvailable)")

                        /// Create array from UnsafePointer for debug
                        let inputArray = Array(UnsafeBufferPointer(start: input, count: min(4, framesAvailable * 2)))
                        DLOG("First few input samples: \(inputArray)")

                        DLOG("First few left samples after conversion: \(Array(leftChannel[0..<4]))")
                        DLOG("First few right samples after conversion: \(Array(rightChannel[0..<4]))")
                        DLOG("First few resampled left: \(Array(resampledLeft[0..<4]))")
                        DLOG("First few resampled right: \(Array(resampledRight[0..<4]))")

                    } else if sourceChannels == 1 {
                        let framesAvailable = bytesRead / 2  /// 1 channel * 2 bytes

                        /// Convert mono int16 to float
                        var monoChannel = [Float](repeating: 0.0, count: framesAvailable)

                        vDSP_vflt16(
                            input, 1,                    /// Stride is 1 for mono
                            &monoChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Scale to -1.0 to 1.0 range
                        vDSP_vsmul(
                            monoChannel, 1,
                            [scale], &monoChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Resample mono channel
                        var resampledMono = [Float](repeating: 0.0, count: targetFrameCount)

                        let inputLength = vDSP_Length(framesAvailable)
                        let outputLength = vDSP_Length(targetFrameCount)

                        vDSP_vqint(
                            monoChannel,                   /// Input signal
                            [Float(resampleRatio)],        /// Stride factor
                            0,                             /// Input stride
                            &resampledMono,                /// Output signal
                            1,                             /// Output stride
                            outputLength,                  /// Number of output points
                            inputLength                    /// Number of input points
                        )

                        /// Duplicate mono to both channels
                        for i in 0..<targetFrameCount {
                            let sample = resampledMono[i]
                            output[i * 2] = sample     /// Left
                            output[i * 2 + 1] = sample /// Right
                        }

                        /// Store last sample for fade out
                        lastSamples = [resampledMono.last ?? 0.0, resampledMono.last ?? 0.0]
                    }
                }
            }  else if sourceBitDepth == 8 {
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    if sourceChannels == 2 {
                        let framesAvailable = bytesRead / 2  /// 2 channels * 1 byte

                        /// Convert int8 to float and deinterleave
                        var leftChannel = [Float](repeating: 0.0, count: framesAvailable)
                        var rightChannel = [Float](repeating: 0.0, count: framesAvailable)

                        /// Convert left channel (stride of 2 for stereo)
                        vDSP_vflt8(
                            input, 2,
                            &leftChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Convert right channel (stride of 2, offset by 1)
                        vDSP_vflt8(
                            input.advanced(by: 1), 2,
                            &rightChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Scale to -1.0 to 1.0 range
                        vDSP_vsmul(
                            leftChannel, 1,
                            [scale], &leftChannel, 1,
                            vDSP_Length(framesAvailable)
                        )
                        vDSP_vsmul(
                            rightChannel, 1,
                            [scale], &rightChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Resample each channel
                        var resampledLeft = [Float](repeating: 0.0, count: targetFrameCount)
                        var resampledRight = [Float](repeating: 0.0, count: targetFrameCount)

                        let inputLength = vDSP_Length(framesAvailable)
                        let outputLength = vDSP_Length(targetFrameCount)

                        vDSP_vqint(
                            leftChannel,                    /// Input signal
                            [Float(resampleRatio)],        /// Stride factor
                            0,                             /// Input stride
                            &resampledLeft,                /// Output signal
                            1,                             /// Output stride
                            outputLength,                  /// Number of output points
                            inputLength                    /// Number of input points
                        )

                        vDSP_vqint(
                            rightChannel,                  /// Input signal
                            [Float(resampleRatio)],        /// Stride factor
                            0,                            /// Input stride
                            &resampledRight,              /// Output signal
                            1,                            /// Output stride
                            outputLength,                 /// Number of output points
                            inputLength                   /// Number of input points
                        )

                        /// Interleave channels back together
                        for i in 0..<targetFrameCount {
                            output[i * 2] = resampledLeft[i]
                            output[i * 2 + 1] = resampledRight[i]
                        }

                        /// Store last samples for fade out
                        lastSamples = [resampledLeft.last ?? 0.0, resampledRight.last ?? 0.0]

                    } else if sourceChannels == 1 {
                        let framesAvailable = bytesRead  /// 1 channel * 1 byte

                        /// Convert mono int8 to float
                        var monoChannel = [Float](repeating: 0.0, count: framesAvailable)

                        vDSP_vflt8(
                            input, 1,                    /// Stride is 1 for mono
                            &monoChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Scale to -1.0 to 1.0 range
                        vDSP_vsmul(
                            monoChannel, 1,
                            [scale], &monoChannel, 1,
                            vDSP_Length(framesAvailable)
                        )

                        /// Resample mono channel
                        var resampledMono = [Float](repeating: 0.0, count: targetFrameCount)

                        let inputLength = vDSP_Length(framesAvailable)
                        let outputLength = vDSP_Length(targetFrameCount)

                        vDSP_vqint(
                            monoChannel,                   /// Input signal
                            [Float(resampleRatio)],        /// Stride factor
                            0,                             /// Input stride
                            &resampledMono,                /// Output signal
                            1,                             /// Output stride
                            outputLength,                  /// Number of output points
                            inputLength                    /// Number of input points
                        )

                        /// Duplicate mono to both channels
                        for i in 0..<targetFrameCount {
                            let sample = resampledMono[i]
                            output[i * 2] = sample     /// Left
                            output[i * 2 + 1] = sample /// Right
                        }

                        /// Store last sample for fade out
                        lastSamples = [resampledMono.last ?? 0.0, resampledMono.last ?? 0.0]
                    }
                }
            }

            return maxBytes
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

        /// Create source node with rendering block
        let renderBlock: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            /// Get separate buffer pointers for left and right channels
            guard let leftData = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightData = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
                isSilence.pointee = true
                return noErr
            }

            /// Create temporary interleaved buffer
            let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: Int(frameCount) * 2)
            defer { tempBuffer.deallocate() }

            /// Read into temporary buffer
            let bytesRequested = Int(frameCount) * MemoryLayout<Float32>.stride * 2
            let bytesCopied = read(tempBuffer, bytesRequested)

            if bytesCopied == 0 {
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                ablPointer[1].mDataByteSize = 0
                ablPointer[0].mNumberChannels = 1
                ablPointer[1].mNumberChannels = 1
                return noErr
            }

            /// Debug the actual audio values being sent to the engine
            let firstFewSamples = Array(UnsafeBufferPointer(start: tempBuffer, count: min(8, Int(frameCount) * 2)))
            DLOG("Audio output samples: \(firstFewSamples)")

            /// Copy directly to output buffers
            for i in 0..<Int(frameCount) {
                leftData[i] = tempBuffer[i * 2]
                rightData[i] = tempBuffer[i * 2 + 1]
            }

            isSilence.pointee = false
            ablPointer[0].mDataByteSize = UInt32(frameCount * 4)
            ablPointer[1].mDataByteSize = UInt32(frameCount * 4)
            ablPointer[0].mNumberChannels = 1
            ablPointer[1].mNumberChannels = 1

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
            try session.setPreferredIOBufferDuration(0.010)
            try session.setActive(true)
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
#endif
    }
}
