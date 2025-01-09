//
//  AudioUnitGameAudioEngine.swift
//
//  Created by Joseph Mattiello on 11/9/24.
//

import Foundation
import AudioToolbox
import AudioUnit
import CoreGraphics
import AVFoundation
import CoreAudio
import PVAudio
import PVLogging

#if SWIFT_PACKAGE
import PVCoreBridge
#endif

public typealias AudioDeviceID = UInt32

/// Audio context manages the buffer and format conversion for a single audio stream
final class OEGameAudioContext {
    /// Core audio properties
    let buffer: RingBufferProtocol?
    let channelCount: Int32
    let bytesPerSample: Int32
    let sourceFormat: AVAudioFormat
    let outputFormat: AVAudioFormat
    let converter: AVAudioConverter?
    let sourceBuffer: AVAudioPCMBuffer?

    /// Buffer management
    var bufferUnderrunCount: Int = 0
    var currentBufferFrames: UInt32 = 4096

    /// Reference to audio engine for adjusting converter
    weak var audioEngine: AudioUnitGameAudioEngine?

    /// Performance tracking
    private var performanceHistory: [Double] = []
    private let maxHistorySize = 10

    init(buffer: RingBufferProtocol?,
         channelCount: Int32,
         bytesPerSample: Int32,
         sampleRate: Double,
         audioEngine: AudioUnitGameAudioEngine) {
        self.buffer = buffer
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
        self.audioEngine = audioEngine

        /// Setup source format based on input parameters
        sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: true
        )!

        /// Setup output format (44.1kHz stereo)
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100.0,
            channels: 2,
            interleaved: true
        )!

        converter = AVAudioConverter(from: sourceFormat, to: outputFormat)
        sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 4096)
    }

    /// Adjust buffer size based on performance
    func adjustBufferSize(forFrames frames: UInt32) {
        guard let audioEngine = audioEngine,
              let converterUnit = audioEngine.auMetaData.mConverterUnit else { return }

        if bufferUnderrunCount > 5 {
            let optimalFrames = min(currentBufferFrames * 2, 8192)
            if optimalFrames != currentBufferFrames {
                var maxFrames = optimalFrames
                let err = AudioUnitSetProperty(
                    converterUnit,
                    kAudioUnitProperty_MaximumFramesPerSlice,
                    kAudioUnitScope_Global,
                    0,
                    &maxFrames,
                    UInt32(MemoryLayout<UInt32>.size)
                )
                if err == noErr {
                    currentBufferFrames = optimalFrames
                    DLOG("Adjusted buffer size to \(optimalFrames) frames")
                }
            }
            bufferUnderrunCount = 0
        }
    }

    /// Update buffer size based on performance history
    func updateBufferSize() {
        guard let audioEngine = audioEngine,
              let converterUnit = audioEngine.auMetaData.mConverterUnit else { return }

        let performanceRatio = Double(bufferUnderrunCount) / 100.0
        performanceHistory.append(performanceRatio)
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }

        let avgPerformance = performanceHistory.reduce(0.0, +) / Double(performanceHistory.count)

        let idealFrameSize: UInt32
        switch avgPerformance {
        case 0...0.1:  /// Excellent performance
            idealFrameSize = 1024
        case 0.1...0.3:  /// Good performance
            idealFrameSize = 2048
        case 0.3...0.5:  /// Fair performance
            idealFrameSize = 4096
        default:  /// Poor performance
            idealFrameSize = 8192
        }

        if idealFrameSize != currentBufferFrames {
            adjustBufferSize(forFrames: idealFrameSize)
        }
    }
}

/// Render callback function for processing audio data
func RenderCallback(inRefCon: UnsafeMutableRawPointer,
                   ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                   inTimeStamp: UnsafePointer<AudioTimeStamp>,
                   inBusNumber: UInt32,
                   inNumberFrames: UInt32,
                   ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {

    let context = Unmanaged<OEGameAudioContext>.fromOpaque(inRefCon).takeUnretainedValue()

    guard let buffer = context.buffer,
          let outputData = ioData?.pointee.mBuffers.mData else {
        return noErr
    }

    /// Calculate frames based on sample rates
    let ratio = context.sourceFormat.sampleRate / context.outputFormat.sampleRate
    let sourceFramesNeeded = UInt32(Double(inNumberFrames) * ratio)

    /// Calculate bytes needed based on source format
    let bytesPerFrame = Int(context.bytesPerSample * context.channelCount)
    let bytesNeeded = Int(sourceFramesNeeded) * bytesPerFrame

    /// Read from ring buffer
    let availableBytes = buffer.availableBytesForReading
    let bytesToRead = min(availableBytes, bytesNeeded)

    if bytesToRead > 0 {
        /// Read data
        let bytesRead = buffer.read(outputData, preferredSize: bytesToRead)

        /// Update buffer size
        ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesRead)

        /// Handle underrun
        if bytesRead < bytesNeeded {
            DLOG("""
                Buffer underrun:
                - Bytes read: \(bytesRead)
                - Bytes needed: \(bytesNeeded)
                - Available bytes: \(availableBytes)
                - Frames requested: \(inNumberFrames)
                - Source frames needed: \(sourceFramesNeeded)
                """)
            context.bufferUnderrunCount += 1

            /// Fill remaining space with silence
            let remainingBytes = bytesNeeded - bytesRead
            memset(outputData + bytesRead, 0, remainingBytes)
            ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesNeeded)
        } else {
            context.bufferUnderrunCount = max(0, context.bufferUnderrunCount - 1)
        }

        context.updateBufferSize()
    } else {
        /// No data available, output silence
        memset(outputData, 0, bytesNeeded)
        ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesNeeded)
    }

    return noErr
}

@objc(OEGameAudioEngine)
public final class AudioUnitGameAudioEngine: NSObject, AudioEngineProtocol {

    /// Metadata for Audio Units and Graph
    internal final class AUMetaData {
        var mGraph: AUGraph? = nil
        var mOutputNode: AUNode = 0
        var mOutputUnit: AudioUnit? = nil
        var mMixerNode: AUNode = 0
        var mMixerUnit: AudioUnit? = nil
        var mConverterNode: AUNode = 0
        var mConverterUnit: AudioUnit? = nil
        var mFilterNode: AUNode = 0
        var mFilterUnit: AudioUnit? = nil

        func uninitialize() {
            if let mGraph = mGraph  {
                AUGraphStop(mGraph)
                AUGraphClose(mGraph)
                AUGraphUninitialize(mGraph)
            }
            self.mGraph = nil
        }
    }

    /// Audio engine properties
    private var _contexts: [OEGameAudioContext] = [OEGameAudioContext]()
    private var _outputDeviceID: UInt32 = 0
    @objc public var running: Bool = false
    internal var auMetaData: AUMetaData

    /// Volume control
    @objc public var volume: Float = 1.0 {
        didSet {
            volumeUpdated()
        }
    }

    /// Initialize audio engine
    public override init() {
        auMetaData = .init()
        super.init()
        _outputDeviceID = 0
        volume = 1
        setupAudioRouteChangeMonitoring()
    }

    /// Cleanup resources
    deinit {
        let auMetaData = self.auMetaData
        Task { @MainActor in
            if let mGraph = auMetaData.mGraph {
                AUGraphUninitialize(mGraph)
                DisposeAUGraph(mGraph)
            }
        }
    }

    /// Audio control methods
    @objc public func pauseAudio() {
        stopAudio()
        running = false
    }

    @objc public func startAudio() throws {
        var err: OSStatus

        if let mgraph = auMetaData.mGraph {
            err = AUGraphStart(mgraph)
            if err != 0 {
                ELOG("couldn't start graph")
                running = false
                throw AudioEngineError.failedToCreateAudioEngine(err)
            } else {
                running = true
                volumeUpdated()
                DLOG("Started the graph")
            }
        } else {
            WLOG("Graph not created yet. Forget to call `setupAudioGraph()`?")
            running = false
        }
    }

    @objc public func stopAudio() {
        if let mGraph = auMetaData.mGraph {
            AUGraphStop(mGraph)
            AUGraphClose(mGraph)
            AUGraphUninitialize(mGraph)
        }
        running = false
    }

    /// iOS audio session setup
    private func setupAudioSession() throws {
        #if !os(macOS)
        try AVAudioSession.sharedInstance().setCategory(.ambient)
        try AVAudioSession.sharedInstance().setActive(true)
        ILOG("Successfully set audio session to .ambient")
        #endif
    }

    /// Setup the audio processing graph
    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        #if !os(macOS)
        try setupAudioSession()
        #endif

        var err: OSStatus
        auMetaData.uninitialize()

        /// Create new AUGraph
        var graph: AUGraph?
        err = NewAUGraph(&graph)
        if err != noErr {
            ELOG("Error creating AUGraph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }
        auMetaData.mGraph = graph

        guard let mGraph = auMetaData.mGraph else {
            ELOG("Failed to create AUGraph")
            throw AudioEngineError.failedToCreateAudioEngine(-1)
        }

        /// Setup output node
        #if os(iOS) || os(tvOS)
        let componentSubType = kAudioUnitSubType_RemoteIO
        #else
        let componentSubType = kAudioUnitSubType_DefaultOutput
        #endif

        var outputcd = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: componentSubType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        err = AUGraphAddNode(mGraph, &outputcd, &auMetaData.mOutputNode)
        if err != noErr {
            ELOG("Error adding output node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup mixer node
        var mixercd = AudioComponentDescription(
            componentType: kAudioUnitType_Mixer,
            componentSubType: kAudioUnitSubType_MultiChannelMixer,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        err = AUGraphAddNode(mGraph, &mixercd, &auMetaData.mMixerNode)
        if err != noErr {
            ELOG("Error adding mixer node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup converter node
        var convertercd = AudioComponentDescription(
            componentType: kAudioUnitType_FormatConverter,
            componentSubType: kAudioUnitSubType_AUConverter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        err = AUGraphAddNode(mGraph, &convertercd, &auMetaData.mConverterNode)
        if err != noErr {
            ELOG("Error adding converter node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup filter node
        var filtercd = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_LowPassFilter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        err = AUGraphAddNode(mGraph, &filtercd, &auMetaData.mFilterNode)
        if err != noErr {
            ELOG("Error adding filter node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Open graph to get audio units
        err = AUGraphOpen(mGraph)
        if err != noErr {
            ELOG("Error opening graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Get audio units
        err = AUGraphNodeInfo(mGraph, auMetaData.mOutputNode, nil, &auMetaData.mOutputUnit)
        if err != noErr {
            ELOG("Error getting output unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(mGraph, auMetaData.mMixerNode, nil, &auMetaData.mMixerUnit)
        if err != noErr {
            ELOG("Error getting mixer unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(mGraph, auMetaData.mConverterNode, nil, &auMetaData.mConverterUnit)
        if err != noErr {
            ELOG("Error getting converter unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(mGraph, auMetaData.mFilterNode, nil, &auMetaData.mFilterUnit)
        if err != noErr {
            ELOG("Error getting filter unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup formats
        let channelCount = gameCore.channelCount(forBuffer: 0)
        let bytesPerSample = gameCore.audioBitDepth / 8

        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: gameCore.audioSampleRate(forBuffer: 0),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channelCount * bytesPerSample),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(channelCount * bytesPerSample),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(gameCore.audioBitDepth),
            mReserved: 0
        )

        var outputFormat = AudioStreamBasicDescription(
            mSampleRate: 44100.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsCanonical,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        /// Log formats
        logAudioFormat(streamFormat, label: "Source Format")
        logAudioFormat(outputFormat, label: "Output Format")

        /// Set formats on converter
        err = AudioUnitSetProperty(
            auMetaData.mConverterUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if err != noErr {
            ELOG("Error setting converter input format: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AudioUnitSetProperty(
            auMetaData.mConverterUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &outputFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if err != noErr {
            ELOG("Error setting converter output format: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Connect nodes: Converter -> Mixer -> Filter -> Output
        err = AUGraphConnectNodeInput(mGraph,
                                    auMetaData.mConverterNode, 0,
                                    auMetaData.mMixerNode, 0)
        if err != noErr {
            ELOG("Error connecting converter to mixer: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphConnectNodeInput(mGraph,
                                    auMetaData.mMixerNode, 0,
                                    auMetaData.mFilterNode, 0)
        if err != noErr {
            ELOG("Error connecting mixer to filter: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphConnectNodeInput(mGraph,
                                    auMetaData.mFilterNode, 0,
                                    auMetaData.mOutputNode, 0)
        if err != noErr {
            ELOG("Error connecting filter to output: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Create and setup audio context
        let context = OEGameAudioContext(
            buffer: gameCore.ringBuffer(atIndex: 0),
            channelCount: Int32(channelCount),
            bytesPerSample: Int32(bytesPerSample),
            sampleRate: gameCore.audioSampleRate(forBuffer: 0),
            audioEngine: self
        )
        _contexts.append(context)

        /// Setup render callback
        var input = AURenderCallbackStruct(
            inputProc: RenderCallback,
            inputProcRefCon: Unmanaged.passRetained(context).toOpaque()
        )

        err = AUGraphSetNodeInputCallback(mGraph,
                                        auMetaData.mConverterNode,
                                        0,
                                        &input)
        if err != noErr {
            ELOG("Error setting input callback: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Initialize graph
        err = AUGraphInitialize(mGraph)
        if err != noErr {
            ELOG("Error initializing graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        ILOG("Audio graph setup complete")
    }

    /// Volume control methods
    private func volumeUpdated() {
        if let mMixerUnit = auMetaData.mMixerUnit {
            AudioUnitSetParameter(
                mMixerUnit,
                kMultiChannelMixerParam_Volume,
                kAudioUnitScope_Input,
                0,
                volume,
                0
            )
        }
    }

    @objc public func volumeUp() {
        volume = min(volume + 0.1, 1.0)
    }

    @objc public func volumeDown() {
        volume = max(volume - 0.1, 0.0)
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    /// Device management
    @objc public var outputDeviceID: AudioDeviceID = 0 {
        didSet {
            try? setOutputDeviceID(outputDeviceID)
        }
    }

    public func setOutputDeviceID(_ outputDeviceID: AudioDeviceID) throws {
        var outputDeviceID = outputDeviceID
        let currentID = self.outputDeviceID
        if outputDeviceID != currentID {
            _outputDeviceID = outputDeviceID

            if let mOutputUnit = auMetaData.mOutputUnit {
                let err = AudioUnitSetProperty(
                    mOutputUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &outputDeviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )

                if err != 0 {
                    ELOG("couldn't set current output device ID")
                    throw AudioEngineError.failedToCreateAudioEngine(err)
                } else {
                    DLOG("Set current output device ID to \(outputDeviceID)")
                }
            }
        }
    }

    /// Filter control
    public func setFilterEnabled(_ enabled: Bool) {
        guard let filterUnit = auMetaData.mFilterUnit else { return }

        var bypass: UInt32 = enabled ? 0 : 1
        AudioUnitSetProperty(
            filterUnit,
            kAudioUnitProperty_BypassEffect,
            kAudioUnitScope_Global,
            0,
            &bypass,
            UInt32(MemoryLayout<UInt32>.size)
        )
    }

    /// Format logging
    private func logAudioFormat(_ format: AudioStreamBasicDescription, label: String) {
        DLOG("\(label):")
        DLOG("- Sample Rate: \(format.mSampleRate)")
        DLOG("- Channels: \(format.mChannelsPerFrame)")
        DLOG("- Bits: \(format.mBitsPerChannel)")
        DLOG("- Bytes/Frame: \(format.mBytesPerFrame)")
        DLOG("- Bytes/Packet: \(format.mBytesPerPacket)")
        DLOG("- Frames/Packet: \(format.mFramesPerPacket)")
        DLOG("- Format ID: \(format.mFormatID)")
        DLOG("- Format Flags: \(format.mFormatFlags)")
    }

    /// Error handling
    private func handleAudioError(_ error: Error) {
        ELOG("Audio error occurred: \(error.localizedDescription)")

        do {
            stopAudio()
            Thread.sleep(forTimeInterval: 0.1)

            #if !os(macOS)
            try setupAudioSession()
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

    /// iOS route change handling
    private func setupAudioRouteChangeMonitoring() {
        #if !os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
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
                try setupAudioSession()
                try startAudio()
            } catch {
                handleAudioError(error)
            }
        default:
            break
        }
        #endif
    }
}
