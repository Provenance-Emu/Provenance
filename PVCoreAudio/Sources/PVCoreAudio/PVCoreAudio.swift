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

final class OEGameAudioContext: Sendable {
    let buffer: RingBuffer
    let channelCount: Int32
    let bytesPerSample: Int32

    init(buffer: RingBuffer, channelCount: Int32, bytesPerSample: Int32) {
        self.buffer = buffer
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
    }
}

@MainActor var recordingFile: ExtAudioFileRef?

import AudioToolbox

@objc(OEGameAudio)
public final class OEGameAudio: NSObject, Sendable{
    @MainActor
    private var _contexts: [OEGameAudioContext] = [OEGameAudioContext]()
    @MainActor
    private var _outputDeviceID: NSNumber?
    @MainActor
    @objc public var running: Bool = false

    @MainActor
    @objc public var gameCore: EmulatorCoreAudioDataSource?

    @MainActor
    internal struct AUMetaData: Sendable {
        var mGraph: AUGraph? = nil
        var mOutputNode: AUNode = 0
        var mOutputUnit: AudioUnit? = nil
        var mMixerNode: AUNode = 0
        var mMixerUnit: AudioUnit? = nil
        var mConverterNode: AUNode = 0
        var mConverterUnit: AudioUnit? = nil
        
        mutating func uninitialize() {
            if let mGraph = mGraph  {
                AUGraphStop(mGraph)
                AUGraphClose(mGraph)
                AUGraphUninitialize(mGraph)
            }
            self.mGraph = nil
        }
    }

    @MainActor
    internal var auMetaData: AUMetaData = .init()

    @MainActor
    @objc public var volume: Float = 1.0 {
        didSet {
            volumeUpdated()
        }
    }

    // No default version for this class
    @MainActor
    override private init() {
        super.init()
    }

    // Designated Initializer
    @MainActor
    @objc public init(core: EmulatorCoreAudioDataSource) {
        super.init()

#if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            ILOG("Successfully set audio session to ambient")
        } catch {
            ELOG("Audio Error: \(error.localizedDescription)")
        }
#endif

        _outputDeviceID = 0
        volume = 1

        gameCore = core
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

    @MainActor @objc public func pauseAudio() {
        stopAudio()
        running = false
    }

    @MainActor
    @objc public func startAudio() {
        createGraph()
        running = true
    }

    @MainActor @objc public func stopAudio() {
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

    @MainActor
    private func createGraph() {
        var err: OSStatus

        auMetaData.uninitialize()

        // Create the graph
        err = NewAUGraph(&auMetaData.mGraph)
        if err != 0 {
            ELOG("NewAUGraph failed")
        }

        // Open the graph
        err = AUGraphOpen(auMetaData.mGraph!)
        if err != 0 {
            ELOG("couldn't open graph")
        }

        var desc = AudioComponentDescription()

        desc.componentType = kAudioUnitType_Output
#if !os(macOS)
        desc.componentSubType = kAudioUnitSubType_RemoteIO
#else
        desc.componentSubType = kAudioUnitSubType_DefaultOutput
#endif
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        desc.componentFlagsMask = 0
        desc.componentFlags = 0

        // Create the output node
        err = AUGraphAddNode(auMetaData.mGraph!, &desc, &auMetaData.mOutputNode)
        if err != 0 {
            ELOG("couldn't create node for output unit")
        }

        err = AUGraphNodeInfo(auMetaData.mGraph!, auMetaData.mOutputNode, nil, &auMetaData.mOutputUnit)
        if err != 0 {
            ELOG("couldn't get output from node")
        }

        desc.componentType = kAudioUnitType_Mixer
        desc.componentSubType = kAudioUnitSubType_MultiChannelMixer
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        // Create the mixer node
        err = AUGraphAddNode(auMetaData.mGraph!, &desc, &auMetaData.mMixerNode)
        if err != 0 {
            ELOG("couldn't create node for file player")
        }

        err = AUGraphNodeInfo(auMetaData.mGraph!, auMetaData.mMixerNode, nil, &auMetaData.mMixerUnit)
        if err != 0 {
            ELOG("couldn't get player unit from node")
        }

        desc.componentType = kAudioUnitType_FormatConverter
        desc.componentSubType = kAudioUnitSubType_AUConverter
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        let bufferCount: Int = Int(gameCore?.audioBufferCount ?? 0)
        
        _contexts.removeAll(keepingCapacity: true)
        
        for i in 0..<bufferCount {
            if let ringBuffer = gameCore?.ringBuffer(atIndex: UInt(i)) {
                ringBuffer.reset()
                let newContext = OEGameAudioContext(buffer: ringBuffer,
                                                  channelCount: Int32(gameCore?.channelCount(forBuffer: UInt(i)) ?? 0),
                                                  bytesPerSample: Int32(gameCore?.audioBitDepth ?? 0 / 8))
                _contexts.append(newContext)
            }

            // Create the converter node
            err = AUGraphAddNode(auMetaData.mGraph!, &desc, &auMetaData.mConverterNode)
            if err != 0 {
                ELOG("couldn't create node for converter")
            }

            err = AUGraphNodeInfo(auMetaData.mGraph!, auMetaData.mConverterNode, nil, &auMetaData.mConverterUnit)
            if err != 0 {
                ELOG("couldn't get player unit from converter")
            }

            var renderCallbackStruct = AURenderCallbackStruct()

            // create our C closure
            renderCallbackStruct.inputProc = {
                (inRefCon : UnsafeMutableRawPointer,
                 ioActionFlags : UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                 inTimeStamp : UnsafePointer<AudioTimeStamp>,
                 inBusNumber : UInt32,
                 inNumberFrames : UInt32,
                 ioData : UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
                
                let context:OEGameAudioContext = inRefCon.assumingMemoryBound(to: OEGameAudioContext.self).pointee

                let availableBytes:Int = context.buffer.availableBytesForWriting

                let bytesRequested:Int = Int(Int32(inNumberFrames) * context.bytesPerSample * context.channelCount)

                let bytesToWrite = min(availableBytes, bytesRequested)

                guard let outBuffer = ioData?.pointee.mBuffers.mData else {
                    ELOG("outBuffer pointer was nil")
                    return noErr
                }

                if bytesToWrite > 0 {
                    context.buffer.write(outBuffer, size: bytesToWrite)
                } else {
                    memset(outBuffer, 0, Int(bytesRequested))
                }

                return noErr
            }

            // set inRefCon to reference to `OEGameAudioContext` by casting to pointer
            renderCallbackStruct.inputProcRefCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(_contexts[i]).toOpaque())


            err = AudioUnitSetProperty(auMetaData.mConverterUnit!, kAudioUnitProperty_SetRenderCallback,
                                       kAudioUnitScope_Input, 0, &renderCallbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
            if err != 0 {
                ELOG("Couldn't set the render callback")
            } else {
                DLOG("Set the render callback")
            }

            var mDataFormat = AudioStreamBasicDescription()
            let channelCount = UInt32(_contexts[i].channelCount)
            let bytesPerSample = UInt32(_contexts[i].bytesPerSample)
            let formatFlag: AudioFormatFlags = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger
            mDataFormat.mSampleRate = gameCore?.audioSampleRate(forBuffer: UInt(i)) ?? 0
            mDataFormat.mFormatID = kAudioFormatLinearPCM
            mDataFormat.mFormatFlags = formatFlag | kAudioFormatFlagsNativeEndian
            mDataFormat.mBytesPerPacket = bytesPerSample * channelCount
            mDataFormat.mFramesPerPacket = 1
            mDataFormat.mBytesPerFrame = bytesPerSample * channelCount
            mDataFormat.mChannelsPerFrame = channelCount
            mDataFormat.mBitsPerChannel = 8 * bytesPerSample

            err = AudioUnitSetProperty(auMetaData.mConverterUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            if err != 0 {
                ELOG("couldn't set player's input stream format")
            } else {
                DLOG("Set the player's input stream format")
            }

            err = AUGraphConnectNodeInput(auMetaData.mGraph!, auMetaData.mConverterNode, 0, auMetaData.mMixerNode, UInt32(i))
            if err != 0 {
                ELOG("Couldn't connect the converter to the mixer")
            } else {
                ELOG("Connected the converter to the mixer")
            }
        }

        // Connect the player to the output unit (stream format will propagate)
        err = AUGraphConnectNodeInput(auMetaData.mGraph!, auMetaData.mMixerNode, 0, auMetaData.mOutputNode, 0)
        if err != 0 {
            ELOG("Could not connect the input of the output")
        } else {
            DLOG("Connected input of the output")
        }

        AudioUnitSetParameter(auMetaData.mOutputUnit!, AudioUnitParameterUnit.linearGain.rawValue, kAudioUnitScope_Global, 0, 1.0, 0)

        var outputDeviceID = _outputDeviceID?.uint32Value ?? 0
        err = AudioUnitSetProperty(auMetaData.mOutputUnit!, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
        if err != 0 {
            ELOG("couldn't set device properties")
        }

        err = AUGraphInitialize(auMetaData.mGraph!)
        if err != 0 {
            ELOG("couldn't initialize graph")
        } else {
            DLOG("Initialized the graph")
        }

        err = AUGraphStart(auMetaData.mGraph!)
        if err != 0 {
            ELOG("couldn't start graph")
        } else {
            DLOG("Started the graph")
        }

        volumeUpdated()
    }

    @MainActor
    @objc public var outputDeviceID: AudioDeviceID = 0 {
        didSet {
            _setOutputDeviceID(outputDeviceID)
        }
    }

    @MainActor
    func _setOutputDeviceID(_ outputDeviceID: AudioDeviceID) {
        var outputDeviceID = outputDeviceID
        let currentID = self.outputDeviceID
        if outputDeviceID != currentID {
            _outputDeviceID = (outputDeviceID == 0 ? nil : NSNumber(value: outputDeviceID))

            if let mOutputUnit = auMetaData.mOutputUnit {
                AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
            }
        }
    }

    @MainActor private func volumeUpdated() {
        if let mMixerUnit = auMetaData.mMixerUnit {
            AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0)
        }
    }

    @MainActor @objc public func volumeUp() {
        var newVolume = volume + 0.1
        if newVolume > 1.0 {
            newVolume = 1.0
        }

        self.volume = newVolume
    }

    @MainActor @objc public func volumeDown() {
        var newVolume = volume - 0.1
        if newVolume < 0.0 {
            newVolume = 0.0
        }

        self.volume = newVolume
    }
}
