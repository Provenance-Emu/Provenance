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
    let buffer: RingBufferProtocol
    let channelCount: Int32
    let bytesPerSample: Int32

    init(buffer: RingBufferProtocol, channelCount: Int32, bytesPerSample: Int32) {
        self.buffer = buffer
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
    }
}

func RenderCallback(inRefCon : UnsafeMutableRawPointer,
     ioActionFlags : UnsafeMutablePointer<AudioUnitRenderActionFlags>,
     inTimeStamp : UnsafePointer<AudioTimeStamp>,
     inBusNumber : UInt32,
     inNumberFrames : UInt32,
     ioData : UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    let context: OEGameAudioContext = inRefCon.assumingMemoryBound(to: OEGameAudioContext.self).pointee

    let availableBytes: Int = context.buffer.availableBytesForWriting

    let bytesRequested: Int = Int(Int32(inNumberFrames) * context.bytesPerSample * context.channelCount)

    let bytesToWrite: Int = min(availableBytes, bytesRequested)

    guard let outBuffer = ioData?.pointee.mBuffers.mData else {
        ELOG("outBuffer pointer was nil")
        return noErr
    }

    if bytesToWrite > 0 {
        let readBytes = context.buffer.read(outBuffer, preferredSize: bytesToWrite)
    } else {
        memset(outBuffer, 0, Int(bytesRequested))
    }

    return noErr
}

@MainActor var recordingFile: ExtAudioFileRef?

import AudioToolbox

@objc(OEGameAudioEngine)
public final class OEGameAudioEngine: NSObject, AudioEngineProtocol {

    
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

        // Create the graph
        err = NewAUGraph(&auMetaData.mGraph)
        if err != 0 {
            ELOG("NewAUGraph failed")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        // Open the graph
        err = AUGraphOpen(auMetaData.mGraph!)
        if err != 0 {
            ELOG("couldn't open graph")
            throw AudioEngineError.failedToCreateAudioEngine(err)
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

        /// Create the output node
        err = AUGraphAddNode(auMetaData.mGraph!, &desc, &auMetaData.mOutputNode)
        if err != 0 {
            ELOG("couldn't create node for output unit")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(auMetaData.mGraph!, auMetaData.mOutputNode, nil, &auMetaData.mOutputUnit)
        if err != 0 {
            ELOG("couldn't get output from node")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        desc.componentType = kAudioUnitType_Mixer
        desc.componentSubType = kAudioUnitSubType_MultiChannelMixer
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        // Create the mixer node
        err = AUGraphAddNode(auMetaData.mGraph!, &desc, &auMetaData.mMixerNode)
        if err != 0 {
            ELOG("couldn't create node for file player")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        err = AUGraphNodeInfo(auMetaData.mGraph!, auMetaData.mMixerNode, nil, &auMetaData.mMixerUnit)
        if err != 0 {
            ELOG("couldn't get player unit from node")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        desc.componentType = kAudioUnitType_FormatConverter
        desc.componentSubType = kAudioUnitSubType_AUConverter
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        let bufferCount: Int = Int(gameCore.audioBufferCount)
        
        _contexts.removeAll(keepingCapacity: true)
        
        for i in 0..<bufferCount {
            let coreAudioBitDepth: UInt = gameCore.audioBitDepth
            let coreChannelCount = gameCore.channelCount(forBuffer: UInt(i))
            if let ringBuffer = gameCore.ringBuffer(atIndex: UInt(i)) {
                ringBuffer.reset()
                let newContext = OEGameAudioContext(buffer: ringBuffer,
                                                  channelCount: Int32(coreChannelCount),
                                                  bytesPerSample: Int32( coreAudioBitDepth / 8))
                _contexts.append(newContext)
            } else {
                assertionFailure("Ring buffer at index: \(i) was nil")
                ELOG("Ring buffer at index: \(i) was nil")
            }

            // Create the converter node
            err = AUGraphAddNode(auMetaData.mGraph!,
                                 &desc,
                                 &auMetaData.mConverterNode)
            if err != 0 {
                ELOG("couldn't create node for converter")
                throw AudioEngineError.failedToCreateAudioEngine(err)
            }

            err = AUGraphNodeInfo(auMetaData.mGraph!,
                                  auMetaData.mConverterNode,
                                  nil,
                                  &auMetaData.mConverterUnit)
            if err != 0 {
                ELOG("couldn't get player unit from converter")
                throw AudioEngineError.failedToCreateAudioEngine(err)
            }

            var renderCallbackStruct = AURenderCallbackStruct()

            // create our C closure
            renderCallbackStruct.inputProc = RenderCallback

            // set inRefCon to reference to `OEGameAudioContext` by casting to pointer
            renderCallbackStruct.inputProcRefCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(_contexts[i]).toOpaque())


            err = AudioUnitSetProperty(auMetaData.mConverterUnit!, kAudioUnitProperty_SetRenderCallback,
                                       kAudioUnitScope_Input, 0, &renderCallbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
            if err != 0 {
                ELOG("Couldn't set the render callback")
                throw AudioEngineError.failedToCreateAudioEngine(err)
            } else {
                DLOG("Set the render callback")
            }

            let channelCount = UInt32(_contexts[i].channelCount)
            let bytesPerSample = UInt32(_contexts[i].bytesPerSample)
            let formatFlag: AudioFormatFlags = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger
            let mSampleRate: Float64 = gameCore.audioSampleRate(forBuffer: UInt(i))
            let mFormatFags: AudioFormatFlags = formatFlag | kAudioFormatFlagsNativeEndian
            let mBytesPerPacket = bytesPerSample * channelCount
            let mFramesPerPacket: UInt32 = 1 // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
            let mBytesPerFrame = bytesPerSample * channelCount
            let mChannelsPerFrame = channelCount
            let mBitsPerChannel = 8 * bytesPerSample
            
            VLOG("mSampleRate: \(mSampleRate), mFormatFags: \(mFormatFags), mBytesPerPacket: \(mBytesPerPacket), mFramesPerPacket: \(mFramesPerPacket), mBytesPerFrame: \(mBytesPerFrame), mChannelsPerFrame: \(mChannelsPerFrame), mBitsPerChannel: \(mBitsPerChannel)")
            
            var mDataFormat = AudioStreamBasicDescription(
                mSampleRate: mSampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: mFormatFags,
                mBytesPerPacket: mBytesPerPacket,
                mFramesPerPacket: mFramesPerPacket,
                mBytesPerFrame: mBytesPerFrame,
                mChannelsPerFrame: mChannelsPerFrame,
                mBitsPerChannel: mBitsPerChannel,
                mReserved: 0)

            err = AudioUnitSetProperty(auMetaData.mConverterUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            if err != 0 {
                ELOG("couldn't set player's input stream format: \(err)")
                throw AudioEngineError.failedToCreateAudioEngine(err)
            } else {
                DLOG("Set the player's input stream format")
            }

            err = AUGraphConnectNodeInput(auMetaData.mGraph!, auMetaData.mConverterNode, 0, auMetaData.mMixerNode, UInt32(i))
            if err != 0 {
                ELOG("Couldn't connect the converter to the mixer: \(err)")
                throw AudioEngineError.failedToCreateAudioEngine(err)
            } else {
                ELOG("Connected the converter to the mixer")
            }
        }

        // Connect the player to the output unit (stream format will propagate)
        err = AUGraphConnectNodeInput(auMetaData.mGraph!, auMetaData.mMixerNode, 0, auMetaData.mOutputNode, 0)
        if err != 0 {
            ELOG("Could not connect the input of the output: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        } else {
            DLOG("Connected input of the output")
        }

        err = AudioUnitSetParameter(auMetaData.mOutputUnit!, AudioUnitParameterUnit.linearGain.rawValue, kAudioUnitScope_Global, 0, 1.0, 0)
        if err != 0 {
            ELOG("couldn't set device AudioUnitSetParameter: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        }

        try _setAudioOutputDevice(for:auMetaData.mOutputUnit!, deviceID: _outputDeviceID)

        err = AUGraphInitialize(auMetaData.mGraph!)
        if err != 0 {
            ELOG("couldn't initialize graph: \(err)")
            throw AudioEngineError.failedToCreateAudioEngine(err)
        } else {
            DLOG("Initialized the graph")
        }
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

extension OEGameAudioEngine {
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
