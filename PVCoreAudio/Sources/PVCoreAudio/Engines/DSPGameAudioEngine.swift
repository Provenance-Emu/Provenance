import Foundation
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

    public var volume: Float = 1.0 {
        didSet {
            updateOutputVolume()
        }
    }

    private lazy var varispeedNode: AVAudioUnitVarispeed = {
        let node = AVAudioUnitVarispeed()
        return node
    }()

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
            do {
                try configureAudioSession()
                try startAudio()
                updateOutputVolume() // Update volume based on new route
            } catch {
                handleAudioError(error)
            }
        default:
            break
        }
        #endif
    }

    private func handleAudioError(_ error: Error) {
        ELOG("Audio error occurred: \(error.localizedDescription)")

        do {
            stopAudio()
            Thread.sleep(forTimeInterval: 0.1)

            #if !os(macOS)
            try configureAudioSession()
            #endif

            try startAudio()
            DLOG("Successfully recovered from audio error")
        } catch {
            ELOG("Failed to recover from audio error: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioEngineErrorNotification"),
                object: self,
                userInfo: ["error": error]
            )
        }
    }
}
