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
        let targetRate = 48000.0
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
            /// Request extra frames for interpolation and filtering
            let adjustedFrameCount = min(
                Int(ceil(Double(targetFrameCount) * rateRatio)) + filterSize,
                Int(pcmBuffer.frameCapacity)
            )
            let sourceBytesToRead = adjustedFrameCount * sourceBytesPerFrame

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
                        let sourceFrames = bytesRead / 4

                        /// Create temporary buffers
                        var leftChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                        var rightChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                        var filteredLeft = [Float](repeating: 0, count: sourceFrames + filterSize)
                        var filteredRight = [Float](repeating: 0, count: sourceFrames + filterSize)

                        /// Convert to float
                        var scale = Float(1.0 / 32768.0)
                        vDSP_vflt16(input, 2, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_vflt16(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(sourceFrames))
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

                        /// Use Accelerate's built-in interpolation
                        var slope = Float(1.0 / rateRatio)
                        vDSP_vqint(filteredLeft, &slope,
                                  1,
                                  outLeft!, 1,
                                  vDSP_Length(targetFrameCount),
                                  vDSP_Length(sourceFrames))

                        vDSP_vqint(filteredRight, &slope,
                                  1,
                                  outRight!, 1,
                                  vDSP_Length(targetFrameCount),
                                  vDSP_Length(sourceFrames))

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
        let targetRate = 48000.0
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
