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
        /// Cache format information
        let sourceChannels = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth = gameCore.audioBitDepth
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerSample = Int(sourceBitDepth / 8)

        /// Get target format (audio session)
        let targetRate: Double = AVAudioSession.sharedInstance().sampleRate // Or get from audio session
        let resampleRatio = targetRate / sourceRate

        return { outputBuffer, maxBytes -> Int in
            /// Calculate frame counts
            let targetFrameCount = maxBytes / 4 /// 2 channels * 2 bytes (16-bit)
            let sourceFrameCount = Int(Double(targetFrameCount) / resampleRatio)
            let sourceBytesToRead = sourceFrameCount * sourceChannels * sourceBytesPerSample

            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceBytesToRead)
            defer { sourceBuffer.deallocate() }

            let bytesRead = buffer.read(sourceBuffer, preferredSize: sourceBytesToRead)
            if bytesRead == 0 {
                memset(outputBuffer, 0, maxBytes)
                return maxBytes
            }

            /// Setup output buffer
            let output = outputBuffer.assumingMemoryBound(to: Int16.self)
            var outputIndex = 0

            /// Handle different source formats
            if sourceBitDepth == 8 {
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    for targetFrame in 0..<targetFrameCount {
                        /// Calculate source position with interpolation
                        let sourcePos = Double(targetFrame) / resampleRatio
                        let sourceFrame = Int(sourcePos)
                        let fraction = sourcePos - Double(sourceFrame)

                        /// Ensure we have enough frames for interpolation
                        guard sourceFrame < (bytesRead / sourceChannels) - 1 else { break }

                        if sourceChannels == 1 {
                            /// Mono to stereo conversion with interpolation
                            let sample1 = Int16(input[sourceFrame]) << 8
                            let sample2 = Int16(input[sourceFrame + 1]) << 8
                            let interpolated = Int16(
                                Double(sample1) * (1.0 - fraction) +
                                Double(sample2) * fraction
                            )

                            /// Duplicate to both channels
                            output[outputIndex] = interpolated     /// Left
                            output[outputIndex + 1] = interpolated /// Right
                            outputIndex += 2
                        } else {
                            /// Stereo with interpolation
                            for channel in 0..<2 {
                                let sample1 = Int16(input[sourceFrame * 2 + channel]) << 8
                                let sample2 = Int16(input[(sourceFrame + 1) * 2 + channel]) << 8
                                output[outputIndex + channel] = Int16(
                                    Double(sample1) * (1.0 - fraction) +
                                    Double(sample2) * fraction
                                )
                            }
                            outputIndex += 2
                        }
                    }
                }
            } else {
                /// Handle 16-bit input
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    for targetFrame in 0..<targetFrameCount {
                        let sourcePos = Double(targetFrame) / resampleRatio
                        let sourceFrame = Int(sourcePos)
                        let fraction = sourcePos - Double(sourceFrame)

                        guard sourceFrame < (bytesRead / (sourceChannels * 2)) - 1 else { break }

                        if sourceChannels == 1 {
                            /// Mono to stereo with interpolation
                            let sample1 = input[sourceFrame]
                            let sample2 = input[sourceFrame + 1]
                            let interpolated = Int16(
                                Double(sample1) * (1.0 - fraction) +
                                Double(sample2) * fraction
                            )

                            output[outputIndex] = interpolated
                            output[outputIndex + 1] = interpolated
                            outputIndex += 2
                        } else {
                            /// Stereo with interpolation
                            for channel in 0..<2 {
                                let sample1 = input[sourceFrame * 2 + channel]
                                let sample2 = input[(sourceFrame + 1) * 2 + channel]
                                output[outputIndex + channel] = Int16(
                                    Double(sample1) * (1.0 - fraction) +
                                    Double(sample2) * fraction
                                )
                            }
                            outputIndex += 2
                        }
                    }
                }
            }

            /// Fill any remaining buffer space with silence
            if outputIndex * 2 < maxBytes {
                memset(outputBuffer.advanced(by: outputIndex * 2), 0, maxBytes - (outputIndex * 2))
            }

            return maxBytes
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

    private func configureAudioSession() {
        #if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient,
                                  mode: .default,
                                  options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }
}
