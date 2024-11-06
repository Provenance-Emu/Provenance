import Foundation
import AVFoundation
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio
import PVSettings

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
            let bytesToRead = min(bytesAvailable, max)

            if bytesToRead == 0 {
                memset(buf, 0, max)
                return max
            }

            let bytesRead = buffer.read(buf, preferredSize: bytesToRead)

            if bytesRead < max {
                memset(buf.advanced(by: bytesRead), 0, max - bytesRead)
            }

            return max
        }
    }

    private func updateSourceNode() {
        if let src {
            engine.detach(src)
            self.src = nil
        }

        let read = readBlockForBuffer(gameCore.ringBuffer(atIndex: 0)!)
        var sd = streamDescription
        let bytesPerFrame = sd.mBytesPerFrame

        guard let format = AVAudioFormat(streamDescription: &sd) else {
            ELOG("Failed to create AVAudioFormat")
            return
        }

        src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, inputData in
            guard let self = self else { return noErr }

            let bytesRequested = Int(frameCount * bytesPerFrame)
            let bytesCopied = read(inputData.pointee.mBuffers.mData!, bytesRequested)

            inputData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied)
            inputData.pointee.mBuffers.mNumberChannels = sd.mChannelsPerFrame

            return noErr
        }

        if let src {
            engine.attach(src)
            engine.connect(src, to: engine.mainMixerNode, format: format)
        }
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
    
    var preferredAudioLatency: TimeInterval {
        Defaults[.audioLatency]
    }

    private func configureAudioSession() {
        #if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient,
                                  mode: .default,
                                  options: [.mixWithOthers])
            let preferredLatency = (self.preferredAudioLatency / 1000.0)
            DLOG("Setting preferred IO buffer duration: \(preferredLatency)")
            try session.setPreferredIOBufferDuration(preferredLatency)
            try session.setActive(true)
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }
}
