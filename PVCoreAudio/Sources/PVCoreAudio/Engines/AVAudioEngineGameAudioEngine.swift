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

    private let engine = AVAudioEngine()
    private var src: AVAudioSourceNode?
    internal weak var gameCore: EmulatorCoreAudioDataSource!
    private var isRunning = false

    public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    private let varispeedNode = AVAudioUnitVarispeed()
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?

    /// Pre-allocated buffers
    private var sourceBuffer: AVAudioPCMBuffer?
    private var outputBuffer: AVAudioPCMBuffer?
    private let maxFrameCapacity: AVAudioFrameCount = 2048

    public init() {
        configureAudioSession()
    }

    private func setupAudioFormats() -> Bool {
        /// Create input format based on game core
        inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: gameCore.audioSampleRate(forBuffer: 0),
            channels: AVAudioChannelCount(gameCore.channelCount(forBuffer: 0)),
            interleaved: true)

        /// Create output format matching device
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2,
            interleaved: false)

        guard let inputFormat = inputFormat,
              let outputFormat = outputFormat else {
            ELOG("Failed to create audio formats")
            return false
        }

        /// Create converter between formats
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        /// Pre-allocate buffers
        sourceBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                      frameCapacity: maxFrameCapacity)
        outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                      frameCapacity: maxFrameCapacity)

        return true
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        guard setupAudioFormats(),
              let outputFormat = outputFormat,
              let converter = converter else {
            return
        }

        let renderBlock: AVAudioSourceNodeRenderBlock = { [weak self] isSilence,
            timestamp, frameCount, audioBufferList -> OSStatus in
            guard let self = self,
                  let sourceBuffer = self.sourceBuffer,
                  let outputBuffer = self.outputBuffer else {
                isSilence.pointee = true
                return noErr
            }

            /// Read from ring buffer
            let ringBuffer = self.gameCore.ringBuffer(atIndex: 0)!
            let bytesPerFrame = Int(self.gameCore.channelCount(forBuffer: 0)) *
            (Int(self.gameCore.audioBitDepth) / 8)
            let bytesToRead = Int(frameCount) * bytesPerFrame

            sourceBuffer.frameLength = frameCount
            let bytesRead = ringBuffer.read(sourceBuffer.int16ChannelData![0],
                                         preferredSize: bytesToRead)

            if bytesRead == 0 {
                isSilence.pointee = true
                return noErr
            }

            /// Convert format
            outputBuffer.frameLength = frameCount
            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }

            /// Copy to output
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for i in 0..<Int(outputFormat.channelCount) {
                if let source = outputBuffer.floatChannelData?[i],
                   let dest = ablPointer[i].mData?.assumingMemoryBound(to: Float.self) {
                    memcpy(dest, source, Int(frameCount) * 4)
                    ablPointer[i].mDataByteSize = UInt32(frameCount * 4)
                }
            }

            isSilence.pointee = false
            return noErr
        }

        src = AVAudioSourceNode(format: outputFormat, renderBlock: renderBlock)

        guard let src else { return }

        /// Setup audio chain
        engine.attach(src)
        engine.attach(varispeedNode)

        engine.connect(src, to: varispeedNode, format: outputFormat)
        engine.connect(varispeedNode, to: engine.mainMixerNode, format: outputFormat)

        engine.mainMixerNode.outputVolume = volume
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        self.gameCore = gameCore
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
