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

        /// Create source format (input format)
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sourceRate),
            channels: AVAudioChannelCount(sourceChannels),
            interleaved: true) else {
            ELOG("Failed to create source format")
            return { _ in 0 }
        }

        /// Create destination format (output format)
        guard let destinationFormat = AVAudioFormat(
            standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2
        ) else {
            ELOG("Failed to create destination format")
            return { _ in 0 }
        }

        /// Create converter if needed
        if audioConverter == nil {
            audioConverter = AVAudioConverter(from: sourceFormat, to: destinationFormat)
        }

        return { pcmBuffer in
            /// Check available bytes in ring buffer
            let availableBytes = buffer.availableBytes
            if availableBytes == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            /// Calculate frames we can read
            let availableFrames = availableBytes / sourceBytesPerFrame
            let bytesToRead = availableFrames * sourceBytesPerFrame

            /// Create/reuse input buffer
            if self.inputBuffer == nil || self.inputBuffer?.format != sourceFormat {
                self.inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat,
                                                  frameCapacity: AVAudioFrameCount(availableFrames))
            }

            guard let inputBuffer = self.inputBuffer,
                  let audioConverter = self.audioConverter else {
                return 0
            }

            /// Read directly into input buffer's raw memory
            if let inputData = inputBuffer.int16ChannelData?[0] {
                let bytesRead = buffer.read(
                    UnsafeMutableRawPointer(inputData),
                    preferredSize: bytesToRead
                )
                inputBuffer.frameLength = AVAudioFrameCount(bytesRead / sourceBytesPerFrame)
            }

            /// Convert to output format
            var error: NSError?
            let status = audioConverter.convert(to: pcmBuffer, error: &error) { packetCount, status in
                status.pointee = .haveData
                return inputBuffer
            }

            if status == .error {
                ELOG("Conversion error: \(error?.localizedDescription ?? "unknown")")
                return 0
            }

            return Int(pcmBuffer.frameLength)
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        /// Create output format
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
