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
    var buffer: RingBuffer
    var channelCount: Int32
    var bytesPerSample: Int32

    init(buffer: RingBuffer, channelCount: Int32, bytesPerSample: Int32) {
        self.buffer = buffer
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
    }
}

var recordingFile: ExtAudioFileRef?

import AudioToolbox

@objc(OEGameAudio)
public class OEGameAudio: NSObject {
    private var _contexts: [OEGameAudioContext] = [OEGameAudioContext]()
    private var _outputDeviceID: NSNumber?
    @objc public var running: Bool = false

    @objc public var gameCore: EmulatorCoreAudioDataSource?
    private var mGraph: AUGraph!
    private var mOutputNode: AUNode = 0
    private var mOutputUnit: AudioUnit?
    private var mMixerNode: AUNode = 0
    private var mMixerUnit: AudioUnit?
    private var mConverterNode: AUNode = 0
    private var mConverterUnit: AudioUnit?

    @objc public var volume: Float = 1.0 {
        didSet {
            volumeUpdated()
        }
    }

    // No default version for this class
    override private init() {
        super.init()
    }

    // Designated Initializer
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
        AUGraphUninitialize(mGraph)
        DisposeAUGraph(mGraph)
    }

    @objc public func pauseAudio() {
        stopAudio()
        running = false
    }

    @objc public func startAudio() {
        createGraph()
        running = true
    }

    @objc public func stopAudio() {
        if let recordingFile = recordingFile {
            ExtAudioFileDispose(recordingFile)
        }
        AUGraphStop(mGraph)
        AUGraphClose(mGraph)
        AUGraphUninitialize(mGraph)
        running = false
    }

    private func createGraph() {
        var err: OSStatus

        AUGraphStop(mGraph)
        AUGraphClose(mGraph)
        AUGraphUninitialize(mGraph)

        // Create the graph
        err = NewAUGraph(&mGraph)
        if err != 0 {
            ELOG("NewAUGraph failed")
        }

        // Open the graph
        err = AUGraphOpen(mGraph)
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
        err = AUGraphAddNode(mGraph, &desc, &mOutputNode)
        if err != 0 {
            ELOG("couldn't create node for output unit")
        }

        err = AUGraphNodeInfo(mGraph, mOutputNode, nil, &mOutputUnit)
        if err != 0 {
            ELOG("couldn't get output from node")
        }

        desc.componentType = kAudioUnitType_Mixer
        desc.componentSubType = kAudioUnitSubType_MultiChannelMixer
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        // Create the mixer node
        err = AUGraphAddNode(mGraph, &desc, &mMixerNode)
        if err != 0 {
            ELOG("couldn't create node for file player")
        }

        err = AUGraphNodeInfo(mGraph, mMixerNode, nil, &mMixerUnit)
        if err != 0 {
            ELOG("couldn't get player unit from node")
        }

        desc.componentType = kAudioUnitType_FormatConverter
        desc.componentSubType = kAudioUnitSubType_AUConverter
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        let bufferCount: Int = Int(gameCore?.audioBufferCount ?? 0)

        for i in 0..<bufferCount {
            if let ringBuffer = gameCore?.ringBuffer(atIndex: UInt(i)) {
                ringBuffer.reset()
                _contexts[i] = OEGameAudioContext(buffer: ringBuffer,
                                                  channelCount: Int32(gameCore?.channelCount(forBuffer: UInt(i)) ?? 0),
                                                  bytesPerSample: Int32(gameCore?.audioBitDepth ?? 0 / 8))
            }

            // Create the converter node
            err = AUGraphAddNode(mGraph, &desc, &mConverterNode)
            if err != 0 {
                ELOG("couldn't create node for converter")
            }

            err = AUGraphNodeInfo(mGraph, mConverterNode, nil, &mConverterUnit)
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


            err = AudioUnitSetProperty(mConverterUnit!, kAudioUnitProperty_SetRenderCallback,
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

            err = AudioUnitSetProperty(mConverterUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            if err != 0 {
                ELOG("couldn't set player's input stream format")
            } else {
                DLOG("Set the player's input stream format")
            }

            err = AUGraphConnectNodeInput(mGraph, mConverterNode, 0, mMixerNode, UInt32(i))
            if err != 0 {
                ELOG("Couldn't connect the converter to the mixer")
            } else {
                ELOG("Connected the converter to the mixer")
            }
        }

        // Connect the player to the output unit (stream format will propagate)
        err = AUGraphConnectNodeInput(mGraph, mMixerNode, 0, mOutputNode, 0)
        if err != 0 {
            ELOG("Could not connect the input of the output")
        } else {
            DLOG("Connected input of the output")
        }

        AudioUnitSetParameter(mOutputUnit!, AudioUnitParameterUnit.linearGain.rawValue, kAudioUnitScope_Global, 0, 1.0, 0)

        var outputDeviceID = _outputDeviceID?.uint32Value ?? 0
        err = AudioUnitSetProperty(mOutputUnit!, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
        if err != 0 {
            ELOG("couldn't set device properties")
        }

        err = AUGraphInitialize(mGraph)
        if err != 0 {
            ELOG("couldn't initialize graph")
        } else {
            DLOG("Initialized the graph")
        }

        err = AUGraphStart(mGraph)
        if err != 0 {
            ELOG("couldn't start graph")
        } else {
            DLOG("Started the graph")
        }

        volumeUpdated()
    }

    @objc public lazy var outputDeviceID: AudioDeviceID = _outputDeviceID?.uint32Value ?? 0 {
        didSet {
            _setOutputDeviceID(outputDeviceID)
        }
    }

    func _setOutputDeviceID(_ outputDeviceID: AudioDeviceID) {
        var outputDeviceID = outputDeviceID
        let currentID = self.outputDeviceID
        if outputDeviceID != currentID {
            _outputDeviceID = (outputDeviceID == 0 ? nil : NSNumber(value: outputDeviceID))

            if let mOutputUnit = mOutputUnit {
                AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
            }
        }
    }

    private func volumeUpdated() {
        if let mMixerUnit = mMixerUnit {
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
}
