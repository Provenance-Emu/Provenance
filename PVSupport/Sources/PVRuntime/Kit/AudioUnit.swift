// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import AudioToolbox
import AVFoundation
@_implementationOnly import os.log

@objc(OEAudioUnit) final public class AudioUnit: AUAudioUnit {
    // swiftlint:disable identifier_name
    @objc public static var kAudioUnitSubType_Emulator     = OSType(bitPattern: 0x65_6d_75_21) // emu!
    @objc public static let kAudioUnitManufacturer_OpenEmu = OSType(bitPattern: 0x6f_65_6d_75) // oemu
    
    private static var isRegistered: Bool = {
        let desc = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                             componentSubType: kAudioUnitSubType_Emulator,
                                             componentManufacturer: kAudioUnitManufacturer_OpenEmu,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
        
        AUAudioUnit.registerSubclass(AudioUnit.self,
                                     as: desc,
                                     name: "OEAudioUnit",
                                     version: .max)
        return true
    }()
    
    @objc public static func register() {
        _ = isRegistered
    }
    
    private var _outputProvider: AURenderPullInputBlock?
    
    @objc public override var outputProvider: AURenderPullInputBlock? {
        get { _outputProvider }
        set { _outputProvider = newValue }
    }
    
    private let _inputBus: CustomBus
    private var _inputBusArray: AUAudioUnitBusArray!
    private let _outputBus: CustomBus
    private var _outputBusArray: AUAudioUnitBusArray!
    
    @frozen @usableFromInline struct Converter {
        let conv: AudioConverterRef?
        let buffer: UnsafeMutablePointer<UInt8>?
        let inputFrameCount: UInt32
        let inputBytePerFrame: UInt32
    }

    private var converter: UnsafeMutablePointer<Converter> = .allocate(capacity: 1)
    
    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        
        _inputBus   = try CustomBus(format: defaultFormat)
        _outputBus  = try CustomBus(format: defaultFormat)
        
        try super.init(componentDescription: componentDescription, options: options)
        
        _inputBusArray  = .init(audioUnit: self, busType: .input, busses: [_inputBus])
        _outputBusArray = .init(audioUnit: self, busType: .output, busses: [_outputBus])
        
        maximumFramesToRender = 512
    }
    
    deinit {
        converter.deallocate()
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        _inputBusArray
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        _outputBusArray
    }
    
    final var requiresConversion: Bool {
        _inputBus.format != _outputBus.format
    }
    
    @objc public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        
        guard requiresConversion else { return }
        
        let srcDesc = _inputBus.format.streamDescription
        let dstDesc = _outputBus.format.streamDescription
        
        var conv: AudioConverterRef?
        let status = AudioConverterNew(srcDesc, dstDesc, &conv)
        if status != noErr {
            os_log(.error, log: .audio, "Unable to create audio converter: %d", status)
            return
        }
        
        /* 64 bytes of padding above self.maximumFramesToRender because
         * CoreAudio is stupid and likes to request more bytes than the maximum
         * even though IT TAKES CARE TO SET THE MAXIMUM VALUE ITSELF! */
        let inputFrameCount = maximumFramesToRender + 64
        let inputBytePerFrame = srcDesc.pointee.mBytesPerFrame
        let bufferSize = Int(inputFrameCount * inputBytePerFrame)
        
        converter.pointee = .init(conv: conv,
                                  buffer: .allocate(capacity: bufferSize),
                                  inputFrameCount: inputFrameCount,
                                  inputBytePerFrame: inputBytePerFrame)
        
        os_log(.info, log: .audio, "Audio converter buffer size = %u bytes", bufferSize)
    }
    
    @objc public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        freeResources()
    }
    
    private func freeResources() {
        if let buffer = converter.pointee.buffer {
            buffer.deallocate()
        }
        
        if let conv = converter.pointee.conv {
            AudioConverterDispose(conv)
        }
        
        converter.pointee = .init(conv: nil, buffer: nil, inputFrameCount: 0, inputBytePerFrame: 0)
    }
    
    // MARK: - AUAudioUnit (AUAudioUnitImplementation)
    
    @frozen @usableFromInline struct InputData {
        let pullInput: AURenderPullInputBlock?
        var timestamp: UnsafePointer<AudioTimeStamp>?
        let converter: UnsafePointer<Converter>
    }
    
    @objc public override var internalRenderBlock: AUInternalRenderBlock {
        let pullInput = outputProvider
        
        if requiresConversion {
            let inOutDataProc: AudioConverterComplexInputDataProc = { (_, ioNumberDataPackets, ioData, _, inUserData) -> OSStatus in
                let inp  = inUserData.unsafelyUnwrapped.assumingMemoryBound(to: InputData.self)
                let conv = inp.pointee.converter.pointee
                
                var pullFlags: AudioUnitRenderActionFlags = []
                ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(conv.buffer)
                ioData.pointee.mBuffers.mDataByteSize = conv.inputFrameCount * conv.inputBytePerFrame
                
                /* cap the bytes we return to the amount of bytes available to guard
                 * against core audio requesting more bytes that they fit in the buffer
                 * EVEN THOUGH THE BUFFER IS ALREADY LARGER THAN MAXIMUMFRAMESTORENDER */
                ioNumberDataPackets.pointee = min(conv.inputFrameCount, ioNumberDataPackets.pointee)
                
                return inp.pointee.pullInput.unsafelyUnwrapped(&pullFlags,
                                                               inp.pointee.timestamp.unsafelyUnwrapped,
                                                               ioNumberDataPackets.pointee,
                                                               0,
                                                               ioData)
            }
            
            let converter = converter
            
            var data = InputData(pullInput: pullInput,
                                 converter: converter)
            // swiftlint:disable closure_parameter_position
            return { (_ actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                      _ timestamp: UnsafePointer<AudioTimeStamp>,
                      _ frameCount: AUAudioFrameCount,
                      _ outputBusNumber: Int,
                      _ outputData: UnsafeMutablePointer<AudioBufferList>,
                      _ realtimeEvenListHead: UnsafePointer<AURenderEvent>?,
                      _ pullInputBlock: AURenderPullInputBlock?) -> AUAudioUnitStatus in
                guard pullInput != nil
                else { return kAudioUnitErr_NoConnection }
                
                data.timestamp = timestamp
                var packetSize: UInt32 = frameCount
                
                let res = AudioConverterFillComplexBuffer(converter.pointee.conv!, inOutDataProc, &data, &packetSize, outputData, nil)
                return res
            }
        }
        
        return { (_ actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                  _ timestamp: UnsafePointer<AudioTimeStamp>,
                  _ frameCount: AUAudioFrameCount,
                  _ outputBusNumber: Int,
                  _ outputData: UnsafeMutablePointer<AudioBufferList>,
                  _ realtimeEvenListHead: UnsafePointer<AURenderEvent>?,
                  _ pullInputBlock: AURenderPullInputBlock?) -> AUAudioUnitStatus in
            guard let pullInput = pullInput
            else { return kAudioUnitErr_NoConnection }
            
            var pullFlags: AudioUnitRenderActionFlags = []
            return pullInput(&pullFlags, timestamp, frameCount, 0, outputData)
        }
    }
    
    @objc class CustomBus: AUAudioUnitBus {
        var _format: AVAudioFormat
        
        override init(format: AVAudioFormat) throws {
            self._format = format
            try super.init(format: format)
        }
        
        @objc override func setFormat(_ format: AVAudioFormat) throws {
            if _format == format {
                return
            }
            
            willChangeValue(forKey: "format")
            _format = format
            didChangeValue(forKey: "format")
        }
        
        override var format: AVAudioFormat {
            _format
        }
    }
}
