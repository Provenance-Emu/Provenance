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
    private var audioConverter: AVAudioConverter?

    private lazy var mixerNode: AVAudioMixerNode = {
        let mixer = AVAudioMixerNode()
        return mixer
    }()

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
        let bufferSize = gameCore.audioBufferSize(forBuffer: 0)
        let bytesPerSample = bitDepth / 8

        DLOG("Core audio properties - Channels: \(channelCount), Rate: \(sampleRate), Bits: \(bitDepth)")
        DLOG("Buffer size: \(bufferSize), Bytes per sample: \(bytesPerSample)")

        /// For 8-bit audio, we'll use 16-bit internally
        if bitDepth == 8 {
            return AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 2 * channelCount,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2 * channelCount,
                mChannelsPerFrame: channelCount,
                mBitsPerChannel: 16,
                mReserved: 0)
        }

        /// Check for interleaved format
        let isInterleaved = channelCount == 1 &&
                           bitDepth == 16 &&
                           bufferSize % (bytesPerSample * 2) == 0

        if isInterleaved {
            DLOG("Using interleaved stereo format")
            return AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 2,
                mBitsPerChannel: 16,
                mReserved: 0)
        }

        let formatFlags: AudioFormatFlags = bitDepth == 32
            ? kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
            : kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked

        return AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: formatFlags,
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
        var originalSD = streamDescription
        let channelCount = originalSD.mChannelsPerFrame
        let is8Bit = gameCore.audioBitDepth == 8

        /// Create source format from stream description
        guard let sourceFormat = AVAudioFormat(streamDescription: &originalSD) else {
            ELOG("Failed to create source format")
            return
        }

        DLOG("Source rate: \(sourceFormat.sampleRate), Session rate: \(AVAudioSession.sharedInstance().sampleRate)")

        src = AVAudioSourceNode(format: sourceFormat) { [weak self] _, _, frameCount, inputData in
            guard let self = self else { return noErr }

            let bytesPerFrame = is8Bit ? 1 : originalSD.mBytesPerFrame
            let bytesRequested = Int(frameCount * bytesPerFrame)

            let tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesRequested)
            defer { tempBuffer.deallocate() }

            let bytesCopied = read(tempBuffer, bytesRequested)

            if is8Bit {
                /// Convert 8-bit to 16-bit
                let outputBuffer = inputData.pointee.mBuffers.mData!.assumingMemoryBound(to: Int16.self)
                for i in 0..<bytesCopied {
                    outputBuffer[i] = Int16(tempBuffer[i]) << 8
                }
                inputData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied * 2)
            } else {
                /// Copy directly for other formats
                memcpy(inputData.pointee.mBuffers.mData!, tempBuffer, bytesCopied)
                inputData.pointee.mBuffers.mDataByteSize = UInt32(bytesCopied)
            }

            inputData.pointee.mBuffers.mNumberChannels = channelCount

            return noErr
        }

        if let src {
            engine.attach(src)
            engine.attach(mixerNode)

            /// Connect through mixer for sample rate conversion
            engine.connect(src, to: mixerNode, format: sourceFormat)
            engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)

            mixerNode.outputVolume = 1.0
            DLOG("Connected through mixer node for sample rate conversion")
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
