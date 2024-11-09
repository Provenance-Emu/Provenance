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

    init(buffer: RingBufferProtocol?, channelCount: Int32, bytesPerSample: Int32) {
        self.buffer = buffer
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
    }
}

func RenderCallback(inRefCon: UnsafeMutableRawPointer,
                   ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                   inTimeStamp: UnsafePointer<AudioTimeStamp>,
                   inBusNumber: UInt32,
                   inNumberFrames: UInt32,
                   ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {

    // Safely get context
    let context = Unmanaged<OEGameAudioContext>.fromOpaque(inRefCon).takeUnretainedValue()

    guard let buffer = context.buffer else {
        ELOG("Buffer is nil")
        return noErr
    }

    let availableBytes: Int = buffer.availableBytesForWriting
    let bytesRequested: Int = Int(Int32(inNumberFrames) * context.bytesPerSample * context.channelCount)
    let bytesToWrite: Int = min(availableBytes, bytesRequested)

    guard let ioPtr = ioData?.pointee.mBuffers.mData else {
        ELOG("Output buffer pointer was nil")
        return noErr
    }

    if bytesToWrite > 0 {
        let _ = buffer.read(ioPtr, preferredSize: bytesToWrite)
    } else {
        memset(ioPtr, 0, Int(bytesRequested))
    }

    return noErr
}

@MainActor var recordingFile: ExtAudioFileRef?

import AudioToolbox

@objc(OEGameAudioEngine)
public final class AudioUnitGameAudioEngine: NSObject, AudioEngineProtocol {


    private var _contexts: [OEGameAudioContext] = [OEGameAudioContext]()
    private var _outputDeviceID: UInt32 = 0
    @objc public var running: Bool = false

    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var mixer: AVAudioMixerNode = AVAudioMixerNode()

    internal final class AUMetaData {
        var mGraph: AUGraph? = nil
        var mOutputNode: AUNode = 0
        var mOutputUnit: AudioUnit? = nil
        var mMixerNode: AUNode = 0
        var mMixerUnit: AudioUnit? = nil
        var mConverterNode: AUNode = 0
        var mConverterUnit: AudioUnit? = nil

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
        Task { @MainActor in
            if let recordingFile = recordingFile {
                ExtAudioFileDispose(recordingFile)
            }
        }
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

        /// Create a new AUGraph
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

        /// Add output node to graph
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

        /// Add mixer node to graph
        err = AUGraphAddNode(mGraph, &mixercd, &auMetaData.mMixerNode)
        if err != noErr {
            ELOG("Error adding mixer node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup format converter node
        var convertercd = AudioComponentDescription(
            componentType: kAudioUnitType_FormatConverter,
            componentSubType: kAudioUnitSubType_AUConverter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        /// Add converter node to graph
        err = AUGraphAddNode(mGraph, &convertercd, &auMetaData.mConverterNode)
        if err != noErr {
            ELOG("Error adding converter node: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Open the graph
        err = AUGraphOpen(mGraph)
        if err != noErr {
            ELOG("Error opening graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Get audio units from nodes
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

        /// Configure audio format
        let channelCount = gameCore.channelCount(forBuffer: 0)
        let bytesPerSample = gameCore.audioBitDepth / 8

        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: gameCore.audioSampleRate(forBuffer: 0),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(bytesPerSample * channelCount),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSample * channelCount),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(gameCore.audioBitDepth),
            mReserved: 0
        )

        /// Set stream format for converter
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

        /// Get the output device's native format
        var outputFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        err = AudioUnitGetProperty(
            auMetaData.mOutputUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &outputFormat,
            &propertySize
        )
        if err != noErr {
            ELOG("Error getting output format: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// If we got an invalid format, create a reasonable default
        if outputFormat.mSampleRate == 0 {
            outputFormat = AudioStreamBasicDescription(
                mSampleRate: 44100.0,  /// Standard sample rate
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,    /// 2 channels * 2 bytes
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,     /// 2 channels * 2 bytes
                mChannelsPerFrame: 2,   /// Stereo
                mBitsPerChannel: 16,    /// 16-bit
                mReserved: 0
            )

            DLOG("Created default output format due to invalid device format")
        } else {
            /// Ensure output format is compatible
            outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
            outputFormat.mFramesPerPacket = 1
            outputFormat.mBytesPerFrame = 4     /// 2 channels * 2 bytes
            outputFormat.mBytesPerPacket = 4    /// Same as bytes per frame
            outputFormat.mBitsPerChannel = 16
        }

        DLOG("""
            Modified Output Format:
            - Sample Rate: \(outputFormat.mSampleRate)
            - Channels: \(outputFormat.mChannelsPerFrame)
            - Bits: \(outputFormat.mBitsPerChannel)
            - Format: \(outputFormat.mFormatID)
            - Bytes/Frame: \(outputFormat.mBytesPerFrame)
            """)

        /// Set converter's output format to match the output unit
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

        DLOG("Audio format conversion path: \(streamFormat.mSampleRate)Hz -> \(outputFormat.mSampleRate)Hz")

        /// Connect nodes
        err = AUGraphConnectNodeInput(mGraph,
                                    auMetaData.mConverterNode, 0,
                                    auMetaData.mMixerNode, 0)
        if err != noErr {
            ELOG("Error connecting converter to mixer: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphConnectNodeInput(mGraph,
                                    auMetaData.mMixerNode, 0,
                                    auMetaData.mOutputNode, 0)
        if err != noErr {
            ELOG("Error connecting mixer to output: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Initialize graph
        err = AUGraphInitialize(mGraph)
        if err != noErr {
            ELOG("Error initializing graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        /// Setup render callback
        var input = AURenderCallbackStruct(
            inputProc: RenderCallback,
            inputProcRefCon: Unmanaged.passRetained(
                OEGameAudioContext(
                    buffer: gameCore.ringBuffer(atIndex: 0),
                    channelCount: Int32(channelCount),
                    bytesPerSample: Int32(bytesPerSample)
                )
            ).toOpaque()
        )

        err = AUGraphSetNodeInputCallback(mGraph,
                                        auMetaData.mConverterNode,
                                        0,
                                        &input)
        if err != noErr {
            ELOG("Error setting input callback: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        ILOG("Audio graph setup complete")
    }

//    @MainActor
    @objc public var outputDeviceID: AudioDeviceID = 0 {
        didSet {
            try? setOutputDeviceID(outputDeviceID)
        }
    }

//    @MainActor
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
        if let mMixerUnit = auMetaData.mMixerUnit {
            AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0)
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
}
