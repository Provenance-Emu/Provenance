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

        /// Pre-calculate filter coefficients for a simple low-pass filter
        let filterSize = 3
        var filterCoeff = [Double](repeating: 1.0 / Double(filterSize), count: filterSize)

        DLOG("Audio setup - Source rate: \(sourceRate)Hz, Target rate: \(targetRate)Hz, Ratio: \(resampleRatio)")

        return { pcmBuffer in
            let targetFrameCount = Int(pcmBuffer.frameCapacity)
            let sourceFrameCount = Int(ceil(Double(targetFrameCount) * resampleRatio)) + 2
            let sourceBytesToRead = sourceFrameCount * sourceBytesPerFrame

            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceBytesToRead)
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: sourceBytesToRead)

            if bytesRead == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    if sourceChannels == 2 {
                        let framesAvailable = bytesRead / 4  /// 2 channels * 2 bytes
                        var leftChannel = [Double](repeating: 0.0, count: framesAvailable)
                        var rightChannel = [Double](repeating: 0.0, count: framesAvailable)

                        /// Convert to double and scale in one step
                        let scale = 1.0 / 32768.0
                        vDSP_vflt16D(input, 2, &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vflt16D(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vsmulD(leftChannel, 1, [scale], &leftChannel, 1, vDSP_Length(framesAvailable))
                        vDSP_vsmulD(rightChannel, 1, [scale], &rightChannel, 1, vDSP_Length(framesAvailable))

                        /// Apply simple low-pass filter
                        var filteredLeft = [Double](repeating: 0.0, count: framesAvailable)
                        var filteredRight = [Double](repeating: 0.0, count: framesAvailable)

                        vDSP_convD(leftChannel, 1, filterCoeff, 1, &filteredLeft, 1,
                                 vDSP_Length(framesAvailable - filterSize + 1), vDSP_Length(filterSize))
                        vDSP_convD(rightChannel, 1, filterCoeff, 1, &filteredRight, 1,
                                 vDSP_Length(framesAvailable - filterSize + 1), vDSP_Length(filterSize))

                        /// Get pointers to PCM buffer channels
                        let resampledLeft = UnsafeMutablePointer<Float>(pcmBuffer.floatChannelData![0])
                        let resampledRight = UnsafeMutablePointer<Float>(pcmBuffer.floatChannelData![1])

                        /// Linear interpolation with filtered data
                        for i in 0..<targetFrameCount {
                            let sourceIndex = Double(i) * resampleRatio
                            let index = Int(sourceIndex)
                            let fraction = sourceIndex - floor(sourceIndex)

                            if index + 1 < framesAvailable - filterSize + 1 {
                                let leftSample = filteredLeft[index] * (1.0 - fraction) +
                                               filteredLeft[index + 1] * fraction
                                let rightSample = filteredRight[index] * (1.0 - fraction) +
                                                filteredRight[index + 1] * fraction

                                resampledLeft[i] = Float(max(-1.0, min(1.0, leftSample)))
                                resampledRight[i] = Float(max(-1.0, min(1.0, rightSample)))
                            } else {
                                resampledLeft[i] = Float(max(-1.0, min(1.0, filteredLeft[min(index, framesAvailable - filterSize)])))
                                resampledRight[i] = Float(max(-1.0, min(1.0, filteredRight[min(index, framesAvailable - filterSize)])))
                            }
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

        /// Create source node with rendering block
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

            /// Copy PCM buffer data to the audio buffer list
            for i in 0..<Int(frameCount) {
                ablPointer[0].mData?.assumingMemoryBound(to: Float.self)[i] = pcmBuffer.floatChannelData?.pointee[i] ?? 0
                ablPointer[1].mData?.assumingMemoryBound(to: Float.self)[i] = pcmBuffer.floatChannelData?.advanced(by: 1).pointee[i] ?? 0
            }

            isSilence.pointee = false
            ablPointer[0].mDataByteSize = UInt32(frameCount * UInt32(MemoryLayout<Float>.size))
            ablPointer[1].mDataByteSize = UInt32(frameCount * UInt32(MemoryLayout<Float>.size))

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
