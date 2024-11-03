//
//  GameAudioEngine.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 9/10/24.
//


import AVFoundation
import Foundation
import AudioToolbox
import AudioUnit
import CoreGraphics
import AVFoundation
import CoreAudio

import PVAudio
import PVLogging
import PVCoreBridge


/// Second version of the game audio engine
/// This one based on `AVAudioEngine`
public class GameAudioEngine: AudioEngineProtocol {
    
    public var volume: Float {
        didSet {
            mixerNode.volume = max(0, min(volume, 1))
        }
    }
    
    /// Format of ... audio
    private var audioFormat: AVAudioFormat?

    private lazy var engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()
    
    /// Final output mixer node
    private lazy var mixerNode: AVAudioMixerNode = {
        let node = AVAudioMixerNode()
        engine.attach(node)
        return node
    }()
    private lazy var monoMixerNode: AVAudioMixerNode = {
        let node = AVAudioMixerNode()
        return node
    }()
    private var playerNodes: [AVAudioPlayerNode]
    private var converterNodes: [AVAudioUnit]
    private var contexts: [OEGameAudioContext]
    private var isPlaying: Bool = false
    
    private(set) var isMonoOutput = false {
        didSet {
            reconfigureAudioEngine()
        }
    }

    public init() {
        playerNodes = []
        converterNodes = []
        contexts = []
        self.volume = 1
        engine.attach(mixerNode)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
    }
    
    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {
//        guard let gameCore = gameCore else {
//            print("Error: gameCore is nil")
//            return
//        }
        
        // Clear existing nodes
        for node in playerNodes + converterNodes {
            engine.detach(node)
        }
        playerNodes.removeAll()
        converterNodes.removeAll()
        contexts.removeAll()
        
        let bufferCount = Int(gameCore.audioBufferCount)
        
        for i in 0..<bufferCount {
            guard let ringBuffer = gameCore.ringBuffer(atIndex: UInt(i)) else {
                ELOG("Error: Ring buffer at index \(i) was nil")
                continue
            }
            
            let coreChannelCount = gameCore.channelCount(forBuffer: UInt(i))
            let coreSampleRate = gameCore.audioSampleRate(forBuffer: UInt(i))
            let coreAudioBitDepth = gameCore.audioBitDepth
            let bytesPerSample = Int32(coreAudioBitDepth / 8)
            ringBuffer.reset()
            
            let newContext = OEGameAudioContext(buffer: ringBuffer,
                                                channelCount: Int32(coreChannelCount),
                                                bytesPerSample: bytesPerSample)
            contexts.append(newContext)
            
            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            playerNodes.append(playerNode)
            
            let converterNode = AVAudioUnitVarispeed()
            engine.attach(converterNode)
            converterNodes.append(converterNode)
            
            let commonFormat: AVAudioCommonFormat
            if bytesPerSample == 2 {
                commonFormat = .pcmFormatInt16
            } else if bytesPerSample == 4 {
                commonFormat = .pcmFormatFloat32
            } else if bytesPerSample == 8 {
                commonFormat = .pcmFormatFloat64
            } else {
                fatalError("Invalid bytes per audio sample: \(bytesPerSample)")
            }

            
            guard let format = AVAudioFormat(commonFormat: commonFormat,
                                             sampleRate: Double(coreSampleRate),
                                             channels: AVAudioChannelCount(coreChannelCount),
                                             interleaved: true) else {
                ELOG("Format for buffer \(i) could not be created")
                engine.stop()
                return
            }
            
            audioFormat = format
            
            engine.connect(playerNode, to: converterNode, format: nil)
            engine.connect(converterNode, to: mixerNode, format: nil)
            
            engine.attach(monoMixerNode)
            engine.connect(monoMixerNode, to: engine.mainMixerNode, format: nil)

            scheduleBuffer(for: playerNode, with: newContext, format: format)
        }
        
        do {
            try engine.start()
        } catch {
            ELOG("Error starting AVAudioEngine: \(error)")
            throw error
        }
    }
    
    private func scheduleBuffer(for playerNode: AVAudioPlayerNode, with context: OEGameAudioContext, format: AVAudioFormat) {
        let frameCapacity = AVAudioFrameCount(2048)  // Adjust this value as needed
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            fatalError("Unable to create AVAudioPCMBuffer")
        }
        
        buffer.frameLength = frameCapacity
        
        let channelCount = Int(context.channelCount)
        let bytesPerSample = Int(context.bytesPerSample)
        
        playerNode.scheduleBuffer(buffer) {
            self.fillBuffer(buffer, with: context)
            self.scheduleBuffer(for: playerNode, with: context, format: format)
        }
        
        playerNode.play()
    }
    
    private func fillBuffer(_ buffer: AVAudioPCMBuffer, with context: OEGameAudioContext) {
        let channelCount = Int(context.channelCount)
        let bytesPerSample = Int(context.bytesPerSample)
        let bytesRequested = Int(buffer.frameLength) * channelCount * bytesPerSample
        
        let availableBytes = context.buffer?.availableBytesForWriting ?? 0
        let bytesToWrite = min(availableBytes, bytesRequested)
        
        if bytesToWrite > 0 {
            let tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesToWrite)
            defer { tempBuffer.deallocate() }
            
            context.buffer?.read(tempBuffer, preferredSize: bytesToWrite)
            
            for channel in 0..<channelCount {
                guard let channelData = buffer.floatChannelData?[channel] else { continue }
                
                for frame in 0..<Int(buffer.frameLength) {
                    let byteOffset = (frame * channelCount + channel) * bytesPerSample
                    if byteOffset < bytesToWrite {
                        let value: Float
                        switch bytesPerSample {
                        case 1:
                            value = Float(tempBuffer[byteOffset]) / Float(Int8.max)
                        case 2:
                            value = Float(Int16(bigEndian: tempBuffer.withMemoryRebound(to: Int16.self, capacity: 1) { $0.pointee })) / Float(Int16.max)
                        case 4:
                            value = tempBuffer.withMemoryRebound(to: Float.self, capacity: 1) { $0.pointee }
                        default:
                            value = 0
                        }
                        channelData[frame] = value
                    } else {
                        channelData[frame] = 0
                    }
                }
            }
        } else {
            for channel in 0..<channelCount {
                if let channelData = buffer.floatChannelData?[channel] {
                    memset(channelData, 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
                }
            }
        }
    }
}

extension GameAudioEngine {
    private func performResumeAudio() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 0.020) {
                self.resumeAudio()
            }
    }
    
    public func resumeAudio() {
        isPlaying = true
        do {
            try engine.start()
        } catch {
            ELOG("Unable to start AVAudioEngine: \(error.localizedDescription)")
        }
    }
}


// MARK: - Volume
public extension GameAudioEngine {
    
    func setVolume(_ volume: Float) {
        self.volume = volume
    }
    
    func increaseVolume() {
        let newVolume = mixerNode.volume + 0.1
        setVolume(newVolume)
    }
    
    func decreaseVolume() {
        let newVolume = mixerNode.volume - 0.1
        setVolume(newVolume)
    }
    
    func getVolume() -> Float {
        return mixerNode.volume
    }
}

// MARK: - Runloop
public extension GameAudioEngine {
    
    func startAudio() throws {
         guard !isPlaying else { return }
         
         do {
             try engine.start()
         } catch {
             ELOG("Error starting audio engine: \(error)")
             throw error
         }
        for playerNode in playerNodes {
            updateMonoSetting()
            playerNode.play()
        }
        isPlaying = true
     }
     
    func pauseAudio() {
         guard isPlaying else { return }
         
         for playerNode in playerNodes {
             playerNode.pause()
         }
         isPlaying = false
     }
     
    func stopAudio() {
         for playerNode in playerNodes {
             playerNode.stop()
         }
         engine.stop()
         isPlaying = false
     }
     
    func isAudioPlaying() -> Bool {
         return isPlaying
     }
}

// Mono Audio
extension GameAudioEngine: MonoAudioEngine {
    
    public func setMono(_ isMono: Bool) {
        self.isMonoOutput = isMono
    }
    
    public func toggleMonoOutput() {
        isMonoOutput.toggle()
    }
    
    private func reconfigureAudioEngine() {
        engine.pause()
        updateMonoSetting()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            ELOG("Error restarting audio engine after mono setting change: \(error)")
        }
    }
   
    private func updateMonoSetting() {
//        guard let format = audioFormat else { return }
//        
//        if isMonoOutput {
//            // Create mono format
//            guard let monoFormat = AVAudioFormat(commonFormat: format.commonFormat,
//                                                 sampleRate: format.sampleRate,
//                                                 channels: 1,
//                                                 interleaved: format.isInterleaved) else {
//                ELOG("Failed to create mono audio format")
//                return
//            }
//            
//            // Disconnect all player nodes from main mixer
//            playerNodes.forEach { playerNode in
//                engine.disconnectNodeOutput(playerNode)
//            }
//            
//            // Connect player nodes to mono mixer
//            playerNodes.forEach { playerNode in
//                engine.connect(playerNode, to: monoMixerNode, format: format)
//            }
//            
//            // Connect mono mixer to main mixer
//            engine.connect(monoMixerNode, to: engine.mainMixerNode, format: monoFormat)
//        } else {
//            // Disconnect mono mixer
//            engine.disconnectNodeInput(monoMixerNode)
//            engine.disconnectNodeOutput(monoMixerNode)
//            
//            // Connect player nodes directly to main mixer
//            playerNodes.forEach { playerNode in
//                engine.connect(playerNode, to: engine.mainMixerNode, format: format)
//            }
//        }
    }

//    private func updateMonoSetting() {
//           guard let format = audioFormat else { return }
//           
//           if isMonoOutput {
//               // Remove any existing connection to mainMixerNode
//               playerNodes.forEach { playerNode in
//                   engine.disconnectNodeOutput(playerNode)
//                   
//                   // Connect playerNode to monoMixerNode
//                   engine.connect(playerNode, to: monoMixerNode, format: format)
//               }
//               
//               // Create mono format
//               let monoFormat = AVAudioFormat(commonFormat: format.commonFormat,
//                                              sampleRate: format.sampleRate,
//                                              channels: 1,
//                                              interleaved: format.isInterleaved)
//               
//               // Install tap on monoMixerNode to convert to mono
//               monoMixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
//                   guard let self = self, let monoFormat = monoFormat else { return }
//                   
//                   let frameCount = buffer.frameLength
//                   let channelCount = buffer.format.channelCount
//                   
//                   // Create a new mono buffer
//                   guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: frameCount) else { return }
//                   monoBuffer.frameLength = frameCount
//                   
//                   // Get the audio buffers
//                   let inputBuffers = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(channelCount))
//                   let outputBuffers = UnsafeBufferPointer(start: monoBuffer.floatChannelData, count: 1)
//                   
//                   // Mix down to mono
//                   for frame in 0..<Int(frameCount) {
//                       var monoSample: Float = 0
//                       for channel in 0..<channelCount {
//                           monoSample += inputBuffers[Int(channel)][frame]
//                       }
//                       outputBuffers[0][frame] = monoSample / Float(channelCount)
//                   }
//                   
//                   // Output the mono buffer
//                   self.engine.mainMixerNode.scheduleBuffer(monoBuffer)
//               }
//           } else {
//               // Remove the tap and reconnect playerNode directly to mainMixerNode
//               monoMixerNode.removeTap(onBus: 0)
//               engine.disconnectNodeInput(monoMixerNode)
//               playerNodes.forEach { playerNode in
//                   engine.connect(playerNode, to: engine.mainMixerNode, format: format)
//               }
//           }
//       }
}
