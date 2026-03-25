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

private final class DSPInterpolationScratch {
    var leftChannel = [Float]()
    var rightChannel = [Float]()
    var filteredLeft = [Float]()
    var filteredRight = [Float]()
    var indexBuffer = [Float]()

    func ensureCapacity(_ count: Int) {
        if leftChannel.count < count { leftChannel = [Float](repeating: 0, count: count) }
        if rightChannel.count < count { rightChannel = [Float](repeating: 0, count: count) }
        if filteredLeft.count < count { filteredLeft = [Float](repeating: 0, count: count) }
        if filteredRight.count < count { filteredRight = [Float](repeating: 0, count: count) }
        if indexBuffer.count < count { indexBuffer = [Float](repeating: 0, count: count) }
    }
}

extension DSPGameAudioEngine {
    /// Linear Interpolation with SIMD
    internal func readBlockForBuffer_SIMD_LinearInterpolation
    (_ buffer: RingBufferProtocol) -> DSPAudioEngineRenderBlock {
        let scratch = DSPInterpolationScratch()
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

            /// If we cannot produce any frames, exit early
            if outputFrames <= 0 {
                pcmBuffer.frameLength = 0
                return 0
            }

            if sourceBitDepth == 16 {
                sourceBuffer.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                    let sourceFrames = bytesRead / (2 * sourceChannels)  /// Account for mono/stereo

                    let capacity = max(sourceFrames + filterSize, outputFrames)
                    scratch.ensureCapacity(capacity)

                    scratch.leftChannel.withUnsafeMutableBufferPointer { leftPtr in
                        scratch.rightChannel.withUnsafeMutableBufferPointer { rightPtr in
                            scratch.filteredLeft.withUnsafeMutableBufferPointer { filteredLeftPtr in
                                scratch.filteredRight.withUnsafeMutableBufferPointer { filteredRightPtr in
                                    guard let leftBase = leftPtr.baseAddress,
                                          let rightBase = rightPtr.baseAddress,
                                          let filteredLeftBase = filteredLeftPtr.baseAddress,
                                          let filteredRightBase = filteredRightPtr.baseAddress
                                    else { return }

                                    /// Convert to float with headroom
                                    var scale = Float(0.9 / 32768.0)

                                    if sourceChannels == 2 {
                                        /// Stereo source
                                        vDSP_vflt16(input, 2, leftBase, 1, vDSP_Length(sourceFrames))
                                        vDSP_vflt16(input.advanced(by: 1), 2, rightBase, 1, vDSP_Length(sourceFrames))
                                    } else {
                                        /// Mono source - convert once and copy to both channels
                                        vDSP_vflt16(input, 1, leftBase, 1, vDSP_Length(sourceFrames))
                                        vDSP_mmov(leftBase, rightBase, vDSP_Length(sourceFrames), 1, 1, 1)
                                    }

                                    /// Apply scaling
                                    vDSP_vsmul(leftBase, 1, &scale, leftBase, 1, vDSP_Length(sourceFrames))
                                    vDSP_vsmul(rightBase, 1, &scale, rightBase, 1, vDSP_Length(sourceFrames))

                                    /// Apply low-pass filter
                                    vDSP_conv(leftBase, 1, filterCoeff, 1, filteredLeftBase, 1,
                                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                                    vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))

                                    /// Resample via vDSP_vlint: build a float index ramp then
                                    /// let vDSP gather + linearly interpolate both channels in one pass.
                                    guard let outLeft = pcmBuffer.floatChannelData?[0],
                                          let outRight = pcmBuffer.floatChannelData?[1] else { return }
                                    scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                        guard let idxBase = idxPtr.baseAddress else { return }
                                        var start = Float(0)
                                        var step = Float(rateRatio)
                                        vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                        vDSP_vlint(filteredLeftBase, idxBase, 1, outLeft, 1,
                                                   vDSP_Length(outputFrames), vDSP_Length(sourceFrames))
                                        vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                                   vDSP_Length(outputFrames), vDSP_Length(sourceFrames))
                                    }
                                }
                            }
                        }
                    }
                }
            } else if sourceBitDepth == 8 {
                sourceBuffer.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                    let sourceFrames = bytesRead / sourceChannels

                    let capacity = max(sourceFrames + filterSize, outputFrames)
                    scratch.ensureCapacity(capacity)

                    scratch.leftChannel.withUnsafeMutableBufferPointer { leftPtr in
                        scratch.rightChannel.withUnsafeMutableBufferPointer { rightPtr in
                            scratch.filteredLeft.withUnsafeMutableBufferPointer { filteredLeftPtr in
                                scratch.filteredRight.withUnsafeMutableBufferPointer { filteredRightPtr in
                                    guard let leftBase = leftPtr.baseAddress,
                                          let rightBase = rightPtr.baseAddress,
                                          let filteredLeftBase = filteredLeftPtr.baseAddress,
                                          let filteredRightBase = filteredRightPtr.baseAddress
                                    else { return }

                                    /// Convert to float with headroom (8-bit range is -128 to 127)
                                    var scale = Float(0.9 / 128.0)

                                    if sourceChannels == 2 {
                                        /// Stereo: deinterleave and convert to float in one vDSP pass
                                        vDSP_vflt8(input, 2, leftBase, 1, vDSP_Length(sourceFrames))
                                        vDSP_vflt8(input.advanced(by: 1), 2, rightBase, 1, vDSP_Length(sourceFrames))
                                    } else {
                                        /// Mono source - convert once and copy to both channels
                                        vDSP_vflt8(input, 1, leftBase, 1, vDSP_Length(sourceFrames))
                                        vDSP_mmov(leftBase, rightBase, vDSP_Length(sourceFrames), 1, 1, 1)
                                    }

                                    /// Apply scaling
                                    vDSP_vsmul(leftBase, 1, &scale, leftBase, 1, vDSP_Length(sourceFrames))
                                    vDSP_vsmul(rightBase, 1, &scale, rightBase, 1, vDSP_Length(sourceFrames))

                                    /// Apply low-pass filter
                                    vDSP_conv(leftBase, 1, filterCoeff, 1, filteredLeftBase, 1,
                                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))
                                    vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                              vDSP_Length(sourceFrames), vDSP_Length(filterSize))

                                    /// Resample via vDSP_vlint: build a float index ramp then
                                    /// let vDSP gather + linearly interpolate both channels in one pass.
                                    guard let outLeft = pcmBuffer.floatChannelData?[0],
                                          let outRight = pcmBuffer.floatChannelData?[1] else { return }
                                    scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                        guard let idxBase = idxPtr.baseAddress else { return }
                                        var start = Float(0)
                                        var step = Float(rateRatio)
                                        vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                        vDSP_vlint(filteredLeftBase, idxBase, 1, outLeft, 1,
                                                   vDSP_Length(outputFrames), vDSP_Length(sourceFrames))
                                        vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                                   vDSP_Length(outputFrames), vDSP_Length(sourceFrames))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            /// Set actual frame length
            pcmBuffer.frameLength = AVAudioFrameCount(outputFrames)

            return bytesRead
        }
    }
}
