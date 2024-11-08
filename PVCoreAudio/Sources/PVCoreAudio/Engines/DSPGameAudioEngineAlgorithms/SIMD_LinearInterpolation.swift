//
//  DSP+SIMD.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/7/24.
//

import Foundation
import Accelerate
import AVFoundation
import PVAudio

extension DSPGameAudioEngine {
    /// Linear Interpolation with SIMD
    internal func readBlockForBuffer_SIMD_LinearInterpolation
    (_ buffer: RingBufferProtocol) -> DSPAudioEngineRenderBlock {
        /// Cache format information
        let sourceChannels = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth = gameCore.audioBitDepth
        let sourceRate = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame = sourceChannels * (Int(sourceBitDepth) / 8)
        let targetRate = AVAudioSession.sharedInstance().sampleRate
        let rateRatio = Double(sourceRate) / targetRate
        
        /// Setup low-pass filter
        let filterSize = 4
        var filterCoeff = [Float](repeating: 0, count: filterSize)
        vDSP_hamm_window(&filterCoeff, vDSP_Length(filterSize), 0)
        var sum: Float = 0
        vDSP_sve(filterCoeff, 1, &sum, vDSP_Length(filterSize))
        vDSP_vsdiv(filterCoeff, 1, &sum, &filterCoeff, 1, vDSP_Length(filterSize))
        
        return { pcmBuffer in
            let targetFrameCount = Int(pcmBuffer.frameCapacity)
            
            /// Check available bytes in ring buffer
            let availableBytes = buffer.availableBytes
            let availableFrames = availableBytes / sourceBytesPerFrame
            
            /// Calculate needed frames including extra for interpolation and filtering
            let neededFrames = Int(ceil(Double(targetFrameCount) * rateRatio)) + filterSize
            
            /// Use the minimum of what we need and what's available
            let framesToRead = min(neededFrames, availableFrames)
            let bytesToRead = framesToRead * sourceBytesPerFrame
            
            /// Early exit if we don't have enough data
            if framesToRead < 2 {  /// Need at least 2 frames for interpolation
                pcmBuffer.frameLength = 0
                return 0
            }
            
            /// Read source data
            let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesToRead)
            defer { sourceBuffer.deallocate() }
            
            let bytesRead = buffer.read(sourceBuffer, preferredSize: bytesToRead)
            
            if bytesRead == 0 {
                pcmBuffer.frameLength = 0
                return 0
            }
            
            /// Calculate actual frames available from bytes read
            let sourceFrames = bytesRead / sourceBytesPerFrame
            
            /// Adjust output frames based on what we actually got
            let outputFrames = min(
                targetFrameCount,
                Int(Double(sourceFrames - 1) / rateRatio)  /// -1 for interpolation safety
            )
            
            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    let sourceFrames = bytesRead / (2 * sourceChannels)  /// Account for mono/stereo
                    
                    /// Create temporary buffers
                    var leftChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var rightChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredLeft = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredRight = [Float](repeating: 0, count: sourceFrames + filterSize)
                    
                    /// Convert to float with headroom
                    var scale = Float(0.9 / 32768.0)
                    
                    if sourceChannels == 2 {
                        /// Stereo source
                        vDSP_vflt16(input, 2, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_vflt16(input.advanced(by: 1), 2, &rightChannel, 1, vDSP_Length(sourceFrames))
                    } else {
                        /// Mono source - convert once and copy to both channels
                        vDSP_vflt16(input, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_mmov(&leftChannel, &rightChannel, vDSP_Length(sourceFrames), 1, 1, 1)
                    }
                    
                    /// Apply scaling
                    vDSP_vsmul(leftChannel, 1, &scale, &leftChannel, 1, vDSP_Length(sourceFrames))
                    vDSP_vsmul(rightChannel, 1, &scale, &rightChannel, 1, vDSP_Length(sourceFrames))
                    
                    /// Apply low-pass filter
                    vDSP_conv(leftChannel, 1, filterCoeff, 1, &filteredLeft, 1,
                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    vDSP_conv(rightChannel, 1, filterCoeff, 1, &filteredRight, 1,
                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    
                    /// Get output buffer pointers
                    let outLeft = pcmBuffer.floatChannelData?[0]
                    let outRight = pcmBuffer.floatChannelData?[1]
                    
                    /// Perform SIMD linear interpolation
                    let outputFrames = min(targetFrameCount, sourceFrames - 1)
                    let simdCount = outputFrames & ~7  /// Round down to multiple of 8
                    
                    /// Process 8 samples at a time using SIMD
                    for i in stride(from: 0, to: simdCount, by: 8) {
                        /// Calculate source positions for 8 samples
                        let baseIndex = Double(i) * rateRatio
                        let indices = SIMD8<Double>(
                            baseIndex,
                            baseIndex + rateRatio,
                            baseIndex + rateRatio * 2,
                            baseIndex + rateRatio * 3,
                            baseIndex + rateRatio * 4,
                            baseIndex + rateRatio * 5,
                            baseIndex + rateRatio * 6,
                            baseIndex + rateRatio * 7
                        )
                        
                        /// Get integer indices and fractions
                        var sourceIndices = SIMD8<Int>()
                        var fractions = SIMD8<Float>()
                        
                        for j in 0..<8 {
                            let index = floor(indices[j])
                            sourceIndices[j] = Int(index)
                            fractions[j] = Float(indices[j] - index)
                        }
                        
                        /// Load source samples
                        var leftLow = SIMD8<Float>()
                        var leftHigh = SIMD8<Float>()
                        var rightLow = SIMD8<Float>()
                        var rightHigh = SIMD8<Float>()
                        
                        for j in 0..<8 {
                            leftLow[j] = filteredLeft[sourceIndices[j]]
                            leftHigh[j] = filteredLeft[sourceIndices[j] + 1]
                            rightLow[j] = filteredRight[sourceIndices[j]]
                            rightHigh[j] = filteredRight[sourceIndices[j] + 1]
                        }
                        
                        /// Perform linear interpolation
                        let oneMinusFraction = 1.0 - fractions
                        let leftResult = leftLow * oneMinusFraction + leftHigh * fractions
                        let rightResult = rightLow * oneMinusFraction + rightHigh * fractions
                        
                        /// Store results
                        for j in 0..<8 {
                            outLeft?[i + j] = leftResult[j]
                            outRight?[i + j] = rightResult[j]
                        }
                    }
                    
                    /// Handle remaining samples
                    for i in simdCount..<outputFrames {
                        let sourcePos = Double(i) * rateRatio
                        let sourceIndex = Int(floor(sourcePos))
                        let fraction = Float(sourcePos - Double(sourceIndex))
                        
                        if sourceIndex + 1 < sourceFrames {
                            let leftSample = filteredLeft[sourceIndex] * (1.0 - fraction) +
                            filteredLeft[sourceIndex + 1] * fraction
                            let rightSample = filteredRight[sourceIndex] * (1.0 - fraction) +
                            filteredRight[sourceIndex + 1] * fraction
                            
                            outLeft?[i] = leftSample
                            outRight?[i] = rightSample
                        } else {
                            outLeft?[i] = filteredLeft[sourceIndex]
                            outRight?[i] = filteredRight[sourceIndex]
                        }
                    }
                    
                    pcmBuffer.frameLength = AVAudioFrameCount(targetFrameCount)
                }
            } else if sourceBitDepth == 8 {
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    let sourceFrames = bytesRead / sourceChannels
                    
                    /// Create temporary buffers
                    var leftChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var rightChannel = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredLeft = [Float](repeating: 0, count: sourceFrames + filterSize)
                    var filteredRight = [Float](repeating: 0, count: sourceFrames + filterSize)
                    
                    /// Convert to float with headroom (8-bit range is -128 to 127)
                    var scale = Float(0.9 / 128.0)
                    
                    if sourceChannels == 2 {
                        /// Stereo source
                        var tempLeft = [Int8](repeating: 0, count: sourceFrames)
                        var tempRight = [Int8](repeating: 0, count: sourceFrames)
                        
                        /// Deinterleave channels
                        for i in 0..<sourceFrames {
                            tempLeft[i] = input[i * 2]
                            tempRight[i] = input[i * 2 + 1]
                        }
                        
                        /// Convert to float
                        vDSP_vflt8(tempLeft, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_vflt8(tempRight, 1, &rightChannel, 1, vDSP_Length(sourceFrames))
                    } else {
                        /// Mono source - convert once and copy to both channels
                        vDSP_vflt8(input, 1, &leftChannel, 1, vDSP_Length(sourceFrames))
                        vDSP_mmov(&leftChannel, &rightChannel, vDSP_Length(sourceFrames), 1, 1, 1)
                    }
                    
                    /// Apply scaling
                    vDSP_vsmul(leftChannel, 1, &scale, &leftChannel, 1, vDSP_Length(sourceFrames))
                    vDSP_vsmul(rightChannel, 1, &scale, &rightChannel, 1, vDSP_Length(sourceFrames))
                    
                    /// Apply low-pass filter
                    vDSP_conv(leftChannel, 1, filterCoeff, 1, &filteredLeft, 1,
                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    vDSP_conv(rightChannel, 1, filterCoeff, 1, &filteredRight, 1,
                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                    
                    /// Get output buffer pointers
                    let outLeft = pcmBuffer.floatChannelData?[0]
                    let outRight = pcmBuffer.floatChannelData?[1]
                    
                    /// Perform SIMD linear interpolation
                    let outputFrames = min(targetFrameCount, sourceFrames - 1)
                    let simdCount = outputFrames & ~7  /// Round down to multiple of 8
                    
                    /// Process 8 samples at a time using SIMD
                    for i in stride(from: 0, to: simdCount, by: 8) {
                        let baseIndex = Double(i) * rateRatio
                        let indices = SIMD8<Double>(
                            baseIndex,
                            baseIndex + rateRatio,
                            baseIndex + rateRatio * 2,
                            baseIndex + rateRatio * 3,
                            baseIndex + rateRatio * 4,
                            baseIndex + rateRatio * 5,
                            baseIndex + rateRatio * 6,
                            baseIndex + rateRatio * 7
                        )
                        
                        var sourceIndices = SIMD8<Int>()
                        var fractions = SIMD8<Float>()
                        
                        for j in 0..<8 {
                            let index = floor(indices[j])
                            sourceIndices[j] = Int(index)
                            fractions[j] = Float(indices[j] - index)
                        }
                        
                        var leftLow = SIMD8<Float>()
                        var leftHigh = SIMD8<Float>()
                        var rightLow = SIMD8<Float>()
                        var rightHigh = SIMD8<Float>()
                        
                        for j in 0..<8 {
                            leftLow[j] = filteredLeft[sourceIndices[j]]
                            leftHigh[j] = filteredLeft[sourceIndices[j] + 1]
                            rightLow[j] = filteredRight[sourceIndices[j]]
                            rightHigh[j] = filteredRight[sourceIndices[j] + 1]
                        }
                        
                        let oneMinusFraction = 1.0 - fractions
                        let leftResult = leftLow * oneMinusFraction + leftHigh * fractions
                        let rightResult = rightLow * oneMinusFraction + rightHigh * fractions
                        
                        for j in 0..<8 {
                            outLeft?[i + j] = leftResult[j]
                            outRight?[i + j] = rightResult[j]
                        }
                    }
                    
                    /// Handle remaining samples
                    for i in simdCount..<outputFrames {
                        let sourcePos = Double(i) * rateRatio
                        let sourceIndex = Int(floor(sourcePos))
                        let fraction = Float(sourcePos - Double(sourceIndex))
                        
                        if sourceIndex + 1 < sourceFrames {
                            let leftSample = filteredLeft[sourceIndex] * (1.0 - fraction) +
                            filteredLeft[sourceIndex + 1] * fraction
                            let rightSample = filteredRight[sourceIndex] * (1.0 - fraction) +
                            filteredRight[sourceIndex + 1] * fraction
                            
                            outLeft?[i] = leftSample
                            outRight?[i] = rightSample
                        } else {
                            outLeft?[i] = filteredLeft[sourceIndex]
                            outRight?[i] = filteredRight[sourceIndex]
                        }
                    }
                    
                    pcmBuffer.frameLength = AVAudioFrameCount(targetFrameCount)
                }
            }
            
            /// Set actual frame length
            pcmBuffer.frameLength = AVAudioFrameCount(outputFrames)
            
            return bytesRead
        }
    }
}
