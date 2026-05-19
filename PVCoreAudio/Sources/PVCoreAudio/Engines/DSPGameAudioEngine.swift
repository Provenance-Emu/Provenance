import Foundation
import os
import AVFoundation
import PVLogging
import PVAudio
import PVCoreBridge
import AudioToolbox
import CoreAudio
import PVSettings
import Accelerate

#if !os(macOS)
import MediaPlayer
#endif

@available(macOS 11.0, iOS 14.0, *)
final public class DSPGameAudioEngine: AudioEngineProtocol {

    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    private var src: AVAudioSourceNode?
    internal weak var gameCore: EmulatorCoreAudioDataSource!
    private var isRunning = false
    private let muteSwitchMonitor = PVMuteSwitchMonitor()
    private var reusablePCMBuffer: AVAudioPCMBuffer?

    /// Audio buffer for waveform visualization
    private var audioBufferForVisualization = [Float](repeating: 0, count: 4096)
    private let audioBufferLock = OSAllocatedUnfairLock<Void>(initialState: ())

    public var volume: Float = 1.0 {
        didSet {
            updateOutputVolume()
        }
    }

    private lazy var audioFormat: AVAudioFormat? = {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AVAudioSession.sharedInstance().sampleRate,
            channels: 2,
            interleaved: false
        )
    }()

    public init() {
        muteSwitchMonitor.startMonitoring { [weak self] isMuted in
            self?.updateOutputVolume()
        }
        configureAudioSession()

        // Observe changes to respectMuteSwitch setting
        Task {
            for await newValue in Defaults.updates(Defaults.Keys.respectMuteSwitch) {
                await MainActor.run { [weak self] in
                    self?.configureAudioSession()
                    self?.updateOutputVolume()
                }
            }
        }

        #if !os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }

    deinit {
        muteSwitchMonitor.stopMonitoring()
        stopAudio()
        #if !os(macOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        self.gameCore = gameCore
    }

    /// Type alias for the read block
    typealias OEAudioBufferReadBlock = (UnsafeMutableRawPointer, Int) -> Int

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

        let dspOption = Defaults[.audioEngineDSPAlgorithm]
        let read: DSPAudioEngineRenderBlock

        switch dspOption {
            case .SIMD_LinearInterpolation:
                read = readBlockForBuffer_SIMD_LinearInterpolation(gameCore.ringBuffer(atIndex: 0)!)
        }

        /// Create source node
        let renderBlock: AVAudioSourceNodeRenderBlock = { isSilence, timestamp, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let requestedFrames = Int(frameCount)
            let outBytesPerChannel = requestedFrames * MemoryLayout<Float>.size

            guard let pcmBuffer = self.obtainPCMBuffer(format: format, frameCapacity: frameCount) else {
                // Zero-fill the requested buffer rather than reporting a short fill,
                // which AVAudioSourceNode interprets as an explicit silent block.
                for i in 0..<min(ablPointer.count, 2) {
                    if let dest = ablPointer[i].mData {
                        memset(dest, 0, outBytesPerChannel)
                    }
                    ablPointer[i].mDataByteSize = UInt32(outBytesPerChannel)
                }
                isSilence.pointee = true
                return noErr
            }

            let bytesCopied = read(pcmBuffer)
            let framesProduced = Int(pcmBuffer.frameLength)

            if bytesCopied == 0 || framesProduced == 0 {
                // Full silence — zero-fill the entire output buffer to avoid clicks.
                for i in 0..<min(ablPointer.count, 2) {
                    if let dest = ablPointer[i].mData {
                        memset(dest, 0, outBytesPerChannel)
                    }
                    ablPointer[i].mDataByteSize = UInt32(outBytesPerChannel)
                }
                isSilence.pointee = true
                return noErr
            }

            /// Copy valid frames to output buffers and pad any tail with silence so the
            /// AU always receives exactly `frameCount` frames. Returning short here would
            /// produce audible clicks at the tail of partial-fill blocks.
            for i in 0..<min(ablPointer.count, 2) {
                guard let source = pcmBuffer.floatChannelData?[i],
                      let dest = ablPointer[i].mData?.assumingMemoryBound(to: Float.self) else { continue }
                let count = framesProduced

                vDSP_mmov(source, dest, vDSP_Length(count), 1, 1, 1)
                if count < requestedFrames {
                    // Pad tail with zeros — avoids garbage samples being played.
                    memset(dest.advanced(by: count), 0, (requestedFrames - count) * MemoryLayout<Float>.size)
                }
                ablPointer[i].mDataByteSize = UInt32(outBytesPerChannel)
            }

            // TODO(audio-glitch-audit-r2): The visualization lock is acquired on the real-time
            // audio thread and shared with the UI thread in `getWaveformData`. If the UI
            // happens to hold this lock when the render block runs, the audio thread will
            // BLOCK on a non-RT-safe primitive → buffer underrun click. `OSAllocatedUnfairLock`
            // is fast in the uncontended case but is NOT real-time safe under contention.
            //
            // A safer pattern is a lock-free double/triple buffer or a per-frame "latest"
            // snapshot updated by the audio thread and copied by the UI thread without
            // mutual exclusion. For now we attempt the lock and SKIP visualization if
            // contended, rather than blocking the audio thread.
            //
            // Verify: profile with Instruments "Audio" → "Real-time Thread" template while
            // the in-game visualizer is on screen. If render-block stalls correlate with
            // UI updates of the waveform, this is the cause.
            if let leftChannel = pcmBuffer.floatChannelData?[0], let rightChannel = pcmBuffer.floatChannelData?[1] {
                _ = self.audioBufferLock.withLockIfAvailable { _ in
                    let count = min(Int(pcmBuffer.frameLength), self.audioBufferForVisualization.count)
                    var half: Float = 0.5
                    vDSP_vadd(leftChannel, 1, rightChannel, 1, &self.audioBufferForVisualization, 1, vDSP_Length(count))
                    vDSP_vsmul(self.audioBufferForVisualization, 1, &half, &self.audioBufferForVisualization, 1, vDSP_Length(count))
                }
            }

            isSilence.pointee = false
            return noErr
        }

        src = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        guard let src else {
            ELOG("Failed to create audio source node")
            return
        }

        /// Setup audio chain without additional resampling
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)

        DLOG("Audio setup - DSP source rate: \(gameCore.audioSampleRate(forBuffer: 0))Hz, Target rate: \(AVAudioSession.sharedInstance().sampleRate)Hz (DSP handles resample)")

        updateOutputVolume()
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
        // Drain stale audio data after stopping the consumer (#3183).
        // Use clear() instead of reset() to avoid deallocating/reinitialising
        // the backing buffer while the emulator core may still be writing.
        gameCore?.ringBuffer(atIndex: 0)?.clear()
    }

    private func configureAudioSession() {
        #if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback category when ignoring mute switch, .ambient otherwise
            let category: AVAudioSession.Category = Defaults[.respectMuteSwitch] ? .ambient : .playback
            try session.setCategory(category,
                                  mode: .default,
                                  options: [.mixWithOthers])
            let bufferDuration = Defaults[.audioLatency] / 1000.0
            try session.setPreferredIOBufferDuration(bufferDuration)
            try session.setActive(true)
            ILOG("Audio session configured to \(category.rawValue)")
        } catch {
            ELOG("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func obtainPCMBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        if let existing = reusablePCMBuffer, existing.frameCapacity >= frameCapacity {
            existing.frameLength = 0
            return existing
        }

        reusablePCMBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        reusablePCMBuffer?.frameLength = 0
        return reusablePCMBuffer
    }

    private func updateOutputVolume() {
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        if !isRunning {
            engine.mainMixerNode.outputVolume = 0.0
        } else if Defaults[.respectMuteSwitch] {
            // Only mute if using internal speaker and mute switch is on
            if muteSwitchMonitor.isMuted && !currentRoute.isOutputtingToExternalDevice {
                engine.mainMixerNode.outputVolume = 0.0
            } else {
                engine.mainMixerNode.outputVolume = volume
            }
        } else {
            // Ignore mute switch
            engine.mainMixerNode.outputVolume = volume
        }
        #else
        engine.mainMixerNode.outputVolume = volume
        #endif
    }

    @objc private func handleAudioRouteChange(notification: Notification) {
        #if !os(macOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Note: `configureAudioSession()` and `startAudio()` swallow errors internally
            // (neither is `throws`). The previous do/try/catch was dead code.
            //
            // TODO(audio-glitch-audit): On route change we currently call startAudio()
            // again without first stopping/pausing the running engine. AVAudioEngine
            // tolerates this but it has been observed to emit a brief click when
            // hot-swapping between speaker and headphones. If runtime profiling
            // confirms a click here, gate this on `isRunning` and call `stopAudio()`
            // before re-configuring.
            configureAudioSession()
            startAudio()
            updateOutputVolume() // Update volume based on new route
        default:
            break
        }
        #endif
    }

    private func handleAudioError(_ error: Error) {
        ELOG("Audio error occurred: \(error.localizedDescription)")

        stopAudio()
        Thread.sleep(forTimeInterval: 0.1)

        #if !os(macOS)
        configureAudioSession()
        #endif

        startAudio()
        DLOG("Audio error recovery path executed")
    }

    /// Captures audio data for visualization
    private func captureAudioDataForVisualization(_ buffer: UnsafeMutableRawPointer, _ byteCount: Int, _ channels: Int32) {
        // Only process if we have enough data
        guard byteCount > 0 else { return }

        audioBufferLock.withLock {
            // Process 16-bit PCM audio data
            let samples = buffer.bindMemory(to: Int16.self, capacity: byteCount / 2)
            let sampleCount = min(byteCount / 2, audioBufferForVisualization.count)

            // For stereo, average the channels
            if channels == 2 {
                for i in 0..<(sampleCount / 2) {
                    let leftSample = Float(samples[i * 2]) / Float(Int16.max)
                    let rightSample = Float(samples[i * 2 + 1]) / Float(Int16.max)
                    audioBufferForVisualization[i] = (leftSample + rightSample) / 2.0
                }
            } else {
                // For mono, just convert to float
                for i in 0..<sampleCount {
                    audioBufferForVisualization[i] = Float(samples[i]) / Float(Int16.max)
                }
            }
        }
    }

    /// Get waveform data for visualization
    public func getWaveformData(numberOfPoints: Int) -> WaveformData {
        audioBufferLock.withLock {
            // Create a result array of the requested size
            var result = [Float](repeating: 0, count: numberOfPoints)

            // If we don't have enough data or engine isn't running, return zeros
            guard isRunning, !audioBufferForVisualization.isEmpty else {
                return WaveformData(amplitudes: result)
            }

            // Use Accelerate framework to downsample the audio buffer to the requested number of points
            let inputLength = vDSP_Length(audioBufferForVisualization.count)
            let stride = max(1, Int(inputLength) / numberOfPoints)

            for i in 0..<numberOfPoints {
                let startIdx = i * stride
                let endIdx = min(startIdx + stride, audioBufferForVisualization.count)

                if startIdx < endIdx {
                    // Take absolute values for visualization
                    var absValues = [Float](repeating: 0, count: endIdx - startIdx)
                    vDSP_vabs(Array(audioBufferForVisualization[startIdx..<endIdx]), 1, &absValues, 1, vDSP_Length(endIdx - startIdx))

                    // Find the maximum value in this segment
                    var maxValue: Float = 0
                    vDSP_maxv(absValues, 1, &maxValue, vDSP_Length(absValues.count))

                    result[i] = maxValue
                }
            }

            return WaveformData(amplitudes: result)
        }
    }
}
