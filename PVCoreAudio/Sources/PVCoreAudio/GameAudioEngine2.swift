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

    typealias OEAudioBufferReadBlock = (UnsafeMutableRawPointer, Int) -> Int
    private func readBlockForBuffer(_ buffer: RingBufferProtocol) -> OEAudioBufferReadBlock {
        /// Cache format information
        let sourceChannels = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth = gameCore.audioBitDepth
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame = sourceChannels * (Int(sourceBitDepth) / 8)

        /// Setup conversion parameters
        let targetRate: Double = 48000.0
        let resampleRatio = targetRate / sourceRate

        DLOG("Audio setup - Source rate: \(sourceRate)Hz, Target rate: \(targetRate)Hz, Ratio: \(resampleRatio)")

        return { outputBuffer, maxBytes -> Int in
            let targetFrameCount = maxBytes / 4  /// 2 bytes per Int16 * 2 channels
            let sourceFrameCount = Int(ceil(Double(targetFrameCount) / resampleRatio)) + 2
            let sourceBytesToRead = sourceFrameCount * sourceBytesPerFrame

            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceBytesToRead)
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: sourceBytesToRead)
            let output = outputBuffer.assumingMemoryBound(to: Int16.self)

            if bytesRead == 0 {
                memset(output, 0, maxBytes)
                return maxBytes
            }

            if sourceBitDepth == 16 {
                /// Direct copy for 16-bit
                memcpy(output, sourceBuffer, min(bytesRead, maxBytes))
                return min(bytesRead, maxBytes)
            } else if sourceBitDepth == 8 {
                /// Convert 8-bit to 16-bit
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    for i in 0..<(bytesRead) {
                        /// Convert 8-bit to 16-bit by shifting left by 8
                        output[i] = Int16(input[i]) << 8
                    }
                }
                return bytesRead * 2  /// Double size for 8-bit to 16-bit conversion
            }

            return 0
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        /// Create format for non-interleaved integer stereo
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 48000.0,
            channels: 2
        ) else {
            ELOG("Failed to create format")
            return
        }

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)

        /// Create source node with rendering block
        let renderBlock: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            /// Get buffer pointers for both channels
            guard let leftData = ablPointer[0].mData?.assumingMemoryBound(to: Int16.self),
                  let rightData = ablPointer[1].mData?.assumingMemoryBound(to: Int16.self) else {
                isSilence.pointee = true
                return noErr
            }

            /// Calculate bytes per channel
            let bytesPerChannel = Int(frameCount) * MemoryLayout<Int16>.stride

            /// Read into left channel buffer
            let bytesCopied = read(leftData, bytesPerChannel * 2)  /// Still read both channels

            if bytesCopied == 0 {
                isSilence.pointee = true
                ablPointer[0].mDataByteSize = 0
                ablPointer[1].mDataByteSize = 0
                ablPointer[0].mNumberChannels = 1
                ablPointer[1].mNumberChannels = 1
                return noErr
            }

            isSilence.pointee = false

            /// Set proper buffer sizes for each channel
            let bytesPerBuffer = bytesCopied / 2
            ablPointer[0].mDataByteSize = UInt32(bytesPerBuffer)
            ablPointer[1].mDataByteSize = UInt32(bytesPerBuffer)
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
