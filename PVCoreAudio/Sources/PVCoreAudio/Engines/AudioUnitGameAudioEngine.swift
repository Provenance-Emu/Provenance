//
//  PVCoreAudio.swift
//
//
//  Created by Joseph Mattiello on 5/19/24.
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

final class OEGameAudioContext {
    let buffer: RingBufferProtocol?
    let channelCount: Int32
    let bytesPerSample: Int32
    let sourceFormat: AVAudioFormat
    let outputFormat: AVAudioFormat
    let converter: AVAudioConverter?
    let sourceBuffer: AVAudioPCMBuffer?

    /// Add these properties to track buffer status
    var bufferUnderrunCount: Int = 0
    var currentBufferFrames: UInt32 = 4096

    /// Add reference to audio engine for adjusting converter
    weak var audioEngine: AudioUnitGameAudioEngine?

    /// Add performance tracking
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

        /// Create source format
        sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: true
        )!

        /// Create output format (44.1kHz stereo)
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100.0,
            channels: 2,
            interleaved: true
        )!

        /// Create converter
        converter = AVAudioConverter(from: sourceFormat, to: outputFormat)

        /// Pre-allocate source buffer
        sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: 4096
        )
    }

    /// Move adjustBufferSize into context
    func adjustBufferSize(forFrames frames: UInt32) {
        guard let audioEngine = audioEngine,
              let converterUnit = audioEngine.auMetaData.mConverterUnit else { return }

        /// Only adjust if we have persistent underruns
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

    func updateBufferSize() {
        guard let audioEngine = audioEngine,
              let converterUnit = audioEngine.auMetaData.mConverterUnit else { return }

        /// Track performance ratio
        let performanceRatio = Double(bufferUnderrunCount) / 100.0
        performanceHistory.append(performanceRatio)
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }

        /// Calculate average performance
        let avgPerformance = performanceHistory.reduce(0.0, +) / Double(performanceHistory.count)

        /// Determine ideal frame size based on performance
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

        /// Calculate actual frames read
        let framesRead = bytesRead / bytesPerFrame

        /// Update buffer size
        ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesRead)

        /// Handle underrun
        if bytesRead < bytesNeeded {
            DLOG("Buffer underrun: got \(bytesRead) of \(bytesNeeded) bytes needed")
            context.bufferUnderrunCount += 1

            /// Fill remaining space with silence
            let remainingBytes = bytesNeeded - bytesRead
            memset(outputData + bytesRead, 0, remainingBytes)
            ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesNeeded)
        } else {
            context.bufferUnderrunCount = max(0, context.bufferUnderrunCount - 1)
        }

        /// Use new dynamic buffer sizing
        context.updateBufferSize()
    } else {
        /// No data available, output silence
        memset(outputData, 0, bytesNeeded)
        ioData?.pointee.mBuffers.mDataByteSize = UInt32(bytesNeeded)
        context.bufferUnderrunCount += 1
    }

    return noErr
}

@objc(OEGameAudioEngine)
public final class AudioUnitGameAudioEngine: NSObject, AudioEngineProtocol {

    private var _contexts: [OEGameAudioContext] = [OEGameAudioContext]()
    private var _outputDeviceID: UInt32 = 0
    @objc public var running: Bool = false

    internal final class AUMetaData {
        var mGraph: AUGraph? = nil
        var mOutputNode: AUNode = 0
        var mOutputUnit: AudioUnit? = nil
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

    public override init() {
        auMetaData = .init()

        super.init()

        _outputDeviceID = 0
        volume = 1
        setupAudioRouteChangeMonitoring()
    }

    internal var auMetaData: AUMetaData

    @objc public var volume: Float = 1.0 {
        didSet {
            volumeUpdated()
        }
    }

    deinit {
        let auMetaData = self.auMetaData
        Task{ @MainActor in
            if let mGraph = auMetaData.mGraph {
                AUGraphUninitialize(mGraph)
                DisposeAUGraph(mGraph)
            }
        }
    }

    @objc public func pauseAudio() {
        stopAudio()
        running = false
    }

    @objc public func startAudio() throws {
        var err: OSStatus

        if let mgraph = auMetaData.mGraph {
            err = AUGraphStart(auMetaData.mGraph!)
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

    private func setupAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.ambient) //, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay])
        try AVAudioSession.sharedInstance().setActive(true)
        ILOG("Successfully set audio session to .ambient")
    }

    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
        #if !os(macOS)
        do {
            try setupAudioSession()
        } catch {
            ELOG("Audio Error: \(error.localizedDescription)")
            throw error
        }
        #endif

        var err: OSStatus
        auMetaData.uninitialize()

        /// 1. Create a new AUGraph
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

        /// 2. Setup and add nodes
        /// Setup output node
        #if os(iOS)
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

        /// 3. Open the graph to get audio units
        err = AUGraphOpen(mGraph)
        if err != noErr {
            ELOG("Error opening graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// 4. Get audio units
        err = AUGraphNodeInfo(mGraph, auMetaData.mConverterNode, nil, &auMetaData.mConverterUnit)
        if err != noErr {
            ELOG("Error getting converter unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(mGraph, auMetaData.mOutputNode, nil, &auMetaData.mOutputUnit)
        if err != noErr {
            ELOG("Error getting output unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(mGraph, auMetaData.mFilterNode, nil, &auMetaData.mFilterUnit)
        if err != noErr {
            ELOG("Error getting filter unit: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// 5. Setup formats
        guard let converterUnit = auMetaData.mConverterUnit else {
            ELOG("Converter unit is nil")
            throw AudioEngineError.failedToCreateAudioEngine(-1)
        }

        /// Create source format
        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: gameCore.audioSampleRate(forBuffer: 0),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(gameCore.channelCount(forBuffer: 0) * (gameCore.audioBitDepth / 8)),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(gameCore.channelCount(forBuffer: 0) * (gameCore.audioBitDepth / 8)),
            mChannelsPerFrame: UInt32(gameCore.channelCount(forBuffer: 0)),
            mBitsPerChannel: UInt32(gameCore.audioBitDepth),
            mReserved: 0
        )

        /// Create output format (44.1kHz stereo)
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

        /// 6. Create and setup audio context
        let context = OEGameAudioContext(
            buffer: gameCore.ringBuffer(atIndex: 0),
            channelCount: Int32(gameCore.channelCount(forBuffer: 0)),
            bytesPerSample: Int32(gameCore.audioBitDepth) / 8,
            sampleRate: gameCore.audioSampleRate(forBuffer: 0),
            audioEngine: self
        )
        _contexts.append(context)

        /// 7. Setup render callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: RenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(context).toOpaque()
        )

        err = AudioUnitSetProperty(
            converterUnit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        if err != noErr {
            ELOG("Error setting render callback: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// 8. Connect nodes
        err = AUGraphConnectNodeInput(mGraph,
                                   auMetaData.mConverterNode, 0,
                                   auMetaData.mFilterNode, 0)
        if err != noErr {
            ELOG("Error connecting converter to filter: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphConnectNodeInput(mGraph,
                                   auMetaData.mFilterNode, 0,
                                   auMetaData.mOutputNode, 0)
        if err != noErr {
            ELOG("Error connecting filter to output: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// 9. Initialize graph
        err = AUGraphInitialize(mGraph)
        if err != noErr {
            ELOG("Error initializing graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// 10. Set initial volume
        volumeUpdated()
    }

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
                let err = AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))

                if err != 0 {
                    ELOG("couldn't set current output device ID")
                    throw AudioEngineError.failedToCreateAudioEngine(err)
                } else {
                    DLOG("Set current output device ID to \(outputDeviceID)")
                }
            }
        }
    }

    private func volumeUpdated() {
        if let outputUnit = auMetaData.mOutputUnit {
            #if os(macOS)
            /// For macOS
            AudioUnitSetParameter(
                outputUnit,
                kHALOutputParam_Volume,
                kAudioUnitScope_Global,
                0,
                volume,
                0
            )
            #else
            /// For iOS RemoteIO unit
            AudioUnitSetParameter(
                outputUnit,
                kHALOutputParam_Volume,
                kAudioUnitScope_Output,
                0,
                volume,
                0
            )
            #endif
        }
    }

    @objc public func volumeUp() {
        var newVolume = volume + 0.1
        if newVolume > 1.0 {
            newVolume = 1.0
        }
        self.volume = newVolume
    }

    @objc public func volumeDown() {
        var newVolume = volume - 0.1
        if newVolume < 0.0 {
            newVolume = 0.0
        }
        self.volume = newVolume
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
    }

    public func setFilterEnabled(_ enabled: Bool) {
        guard let filterUnit = auMetaData.mFilterUnit else { return }

        var bypass: UInt32 = enabled ? 0 : 1
        AudioUnitSetProperty(filterUnit,
                           kAudioUnitProperty_BypassEffect,
                           kAudioUnitScope_Global,
                           0,
                           &bypass,
                           UInt32(MemoryLayout<UInt32>.size))
    }
}

extension AudioUnitGameAudioEngine {
    @discardableResult
    func _setAudioOutputDevice(for audioUnit: AudioUnit, deviceID: AudioDeviceID) throws -> OSStatus {
        var deviceIDCopy = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            propertySize
        )

        if status != noErr {
            throw AudioEngineError.failedToCreateAudioEngine(status)
        }

        return status
    }

    private func handleAudioError(_ error: Error) {
        ELOG("Audio error occurred: \(error.localizedDescription)")

        /// Try to recover
        do {
            stopAudio()

            /// Wait briefly before restart
            Thread.sleep(forTimeInterval: 0.1)

            /// Reinitialize audio session if needed
            #if !os(macOS)
            try setupAudioSession()
            #endif

            /// Try to restart
            try startAudio()
            DLOG("Successfully recovered from audio error")
        } catch {
            ELOG("Failed to recover from audio error: \(error.localizedDescription)")
            /// Post notification about unrecoverable error
            NotificationCenter.default.post(
                name: NSNotification.Name("AudioEngineErrorNotification"),
                object: self,
                userInfo: ["error": error]
            )
        }
    }

    /// Add monitoring for audio route changes
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
