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

// MARK: - Bessel function (used for Kaiser window design)

/// Modified Bessel function of the first kind, order 0.
/// Used to compute the Kaiser window for FIR filter design.
private func modifiedBessel0(_ x: Double) -> Double {
    var sum = 1.0
    var term = 1.0
    for k in 1...25 {
        let xk = x / 2.0
        term *= (xk * xk) / (Double(k) * Double(k))
        sum += term
        if term < 1e-15 { break }
    }
    return sum
}

// MARK: - Scratch buffers

private final class DSPInterpolationScratch {
    var leftChannel  = [Float]()
    var rightChannel = [Float]()
    var filteredLeft = [Float]()
    var filteredRight = [Float]()
    var indexBuffer  = [Float]()
    /// Pre-allocated raw byte buffer — avoids malloc on the audio render thread.
    /// 32 KB covers up to 4096 source frames at 4 bytes/frame with headroom.
    var rawBuffer    = [UInt8](repeating: 0, count: 32_768)

    func ensureCapacity(_ count: Int) {
        if leftChannel.count  < count { leftChannel  = [Float](repeating: 0, count: count) }
        if rightChannel.count < count { rightChannel = [Float](repeating: 0, count: count) }
        if filteredLeft.count < count { filteredLeft = [Float](repeating: 0, count: count) }
        if filteredRight.count < count { filteredRight = [Float](repeating: 0, count: count) }
        if indexBuffer.count  < count { indexBuffer  = [Float](repeating: 0, count: count) }
    }

    /// Grows rawBuffer only if needed; on the happy path (rawBuffer large enough) this is a no-op.
    func ensureRawCapacity(_ byteCount: Int) {
        if rawBuffer.count < byteCount {
            rawBuffer = [UInt8](repeating: 0, count: byteCount)
        }
    }
}

// MARK: - DSP render block

extension DSPGameAudioEngine {
    /// Linear resampling via vDSP_vlint with a 64-tap Kaiser-windowed sinc anti-alias filter.
    ///
    /// Design choices:
    /// - **64-tap Kaiser window (β = 8)** → ~80 dB stop-band attenuation, far superior to the
    ///   previous 4-tap Hamming moving-average which provided essentially zero aliasing rejection.
    /// - **Cutoff** set to `min(targetNyquist, sourceNyquist)` expressed as a normalised
    ///   frequency relative to the source rate: `fc = 0.5 / max(rateRatio, 1)`.
    ///   - Downsampling (rateRatio > 1): attenuates above the target Nyquist to prevent aliasing.
    ///   - Upsampling  (rateRatio < 1): uses 0.45 to remove reconstruction images while
    ///     preserving the full source bandwidth.
    /// - **vDSP_vlint** replaces the previous hand-written gather loop (which was scalar despite
    ///   using SIMD8<Float> for the arithmetic portion).
    /// - **rawBuffer pre-allocation** on the scratch object eliminates the per-frame malloc/free
    ///   that previously ran on the real-time audio render thread.
    internal func readBlockForBuffer_SIMD_LinearInterpolation
    (_ buffer: RingBufferProtocol) -> DSPAudioEngineRenderBlock {
        let scratch = DSPInterpolationScratch()

        // Cache format information
        let sourceChannels       = Int(gameCore.channelCount(forBuffer: 0))
        let sourceBitDepth       = gameCore.audioBitDepth
        let sourceRate           = gameCore.audioSampleRate(forBuffer: 0)
        let sourceBytesPerFrame  = sourceChannels * (Int(sourceBitDepth) / 8)
        let targetRate           = AVAudioSession.sharedInstance().sampleRate
        let rateRatio            = sourceRate / targetRate   // > 1 = downsample, < 1 = upsample

        // ── Filter design (computed once at engine start, not on the audio thread) ────────────
        //
        // 64-tap Kaiser-windowed sinc low-pass filter.
        // Kaiser β = 8.0 gives ~80 dB stop-band attenuation with a smooth transition.
        let filterSize = 64
        let fc: Double = rateRatio > 1.0 ? 0.5 / rateRatio : 0.45   // normalised cutoff [0, 0.5]
        let kaiserBeta = 8.0
        let iZero0     = modifiedBessel0(kaiserBeta)
        let M          = Double(filterSize - 1)

        var filterCoeff = [Float](repeating: 0, count: filterSize)
        for i in 0..<filterSize {
            let n = Double(i) - M / 2.0
            // Sinc kernel (L'Hôpital at n == 0)
            let sincVal: Double = abs(n) < 1e-10 ? 2.0 * fc
                                                  : sin(2.0 * .pi * fc * n) / (.pi * n)
            // Kaiser window
            let arg = 2.0 * Double(i) / M - 1.0
            let x   = kaiserBeta * sqrt(max(0.0, 1.0 - arg * arg))
            let win = modifiedBessel0(x) / iZero0
            filterCoeff[i] = Float(sincVal * win)
        }
        // Normalise to unity gain at DC
        var filterSum: Float = 0
        vDSP_sve(filterCoeff, 1, &filterSum, vDSP_Length(filterSize))
        vDSP_vsdiv(filterCoeff, 1, &filterSum, &filterCoeff, 1, vDSP_Length(filterSize))

        // ── Render block (called on real-time audio thread) ──────────────────────────────────
        return { pcmBuffer in
            let targetFrameCount = Int(pcmBuffer.frameCapacity)

            // How many source frames do we need?
            //   • extra `filterSize` frames ensure the convolution has a full valid tail
            let availableBytes   = buffer.availableBytes
            let availableFrames  = availableBytes / sourceBytesPerFrame
            let neededFrames     = Int(ceil(Double(targetFrameCount) * rateRatio)) + filterSize
            let framesToRead     = min(neededFrames, availableFrames)
            let bytesToRead      = framesToRead * sourceBytesPerFrame

            guard framesToRead >= 2 else {      // need at least 2 frames for interpolation
                pcmBuffer.frameLength = 0
                return 0
            }

            // Read source data into pre-allocated scratch buffer (no malloc on audio thread)
            scratch.ensureRawCapacity(bytesToRead)
            let bytesRead = scratch.rawBuffer.withUnsafeMutableBytes { ptr in
                buffer.read(ptr.baseAddress!, preferredSize: min(bytesToRead, ptr.count))
            }

            guard bytesRead > 0 else {
                pcmBuffer.frameLength = 0
                return 0
            }

            let sourceFrames = bytesRead / sourceBytesPerFrame
            let outputFrames = min(
                targetFrameCount,
                Int(Double(sourceFrames - 1) / rateRatio)   // -1 for interpolation boundary safety
            )

            guard outputFrames > 0 else {
                pcmBuffer.frameLength = 0
                return 0
            }

            let capacity = max(sourceFrames + filterSize, outputFrames)
            scratch.ensureCapacity(capacity)

            // ── 16-bit path ───────────────────────────────────────────────────────────────────
            if sourceBitDepth == 16 {
                scratch.rawBuffer.withUnsafeMutableBytes { rawPtr in
                    rawPtr.baseAddress!.withMemoryRebound(to: Int16.self, capacity: bytesRead / 2) { input in
                        let sourceFrames16 = bytesRead / (2 * sourceChannels)
                        scratch.leftChannel.withUnsafeMutableBufferPointer  { leftPtr in
                        scratch.rightChannel.withUnsafeMutableBufferPointer { rightPtr in
                        scratch.filteredLeft.withUnsafeMutableBufferPointer  { filteredLeftPtr in
                        scratch.filteredRight.withUnsafeMutableBufferPointer { filteredRightPtr in
                            guard let leftBase         = leftPtr.baseAddress,
                                  let rightBase        = rightPtr.baseAddress,
                                  let filteredLeftBase  = filteredLeftPtr.baseAddress,
                                  let filteredRightBase = filteredRightPtr.baseAddress
                            else { return }

                            // Convert Int16 → Float, deinterleaving channels via stride
                            var scale = Float(0.9 / 32768.0)
                            if sourceChannels == 2 {
                                vDSP_vflt16(input,                  2, leftBase,  1, vDSP_Length(sourceFrames16))
                                vDSP_vflt16(input.advanced(by: 1),  2, rightBase, 1, vDSP_Length(sourceFrames16))
                            } else {
                                vDSP_vflt16(input, 1, leftBase, 1, vDSP_Length(sourceFrames16))
                                vDSP_mmov(leftBase, rightBase, vDSP_Length(sourceFrames16), 1, 1, 1)
                            }
                            vDSP_vsmul(leftBase,  1, &scale, leftBase,  1, vDSP_Length(sourceFrames16))
                            vDSP_vsmul(rightBase, 1, &scale, rightBase, 1, vDSP_Length(sourceFrames16))

                            // Anti-alias filter: 64-tap Kaiser-windowed sinc convolution
                            vDSP_conv(leftBase,  1, filterCoeff, 1, filteredLeftBase,  1,
                                      vDSP_Length(sourceFrames16), vDSP_Length(filterSize))
                            vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                      vDSP_Length(sourceFrames16), vDSP_Length(filterSize))

                            // Resample: build fractional index ramp, then gather+interpolate
                            guard let outLeft  = pcmBuffer.floatChannelData?[0],
                                  let outRight = pcmBuffer.floatChannelData?[1] else { return }
                            scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                guard let idxBase = idxPtr.baseAddress else { return }
                                var start = Float(0);  var step = Float(rateRatio)
                                vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                vDSP_vlint(filteredLeftBase,  idxBase, 1, outLeft,  1,
                                           vDSP_Length(outputFrames), vDSP_Length(sourceFrames16))
                                vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                           vDSP_Length(outputFrames), vDSP_Length(sourceFrames16))
                            }
                        }}}}
                    }
                }

            // ── 8-bit path ────────────────────────────────────────────────────────────────────
            } else if sourceBitDepth == 8 {
                scratch.rawBuffer.withUnsafeMutableBytes { rawPtr in
                    rawPtr.baseAddress!.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                        let sourceFrames8 = bytesRead / sourceChannels
                        let cap8 = max(sourceFrames8 + filterSize, outputFrames)
                        scratch.ensureCapacity(cap8)

                        scratch.leftChannel.withUnsafeMutableBufferPointer  { leftPtr in
                        scratch.rightChannel.withUnsafeMutableBufferPointer { rightPtr in
                        scratch.filteredLeft.withUnsafeMutableBufferPointer  { filteredLeftPtr in
                        scratch.filteredRight.withUnsafeMutableBufferPointer { filteredRightPtr in
                            guard let leftBase         = leftPtr.baseAddress,
                                  let rightBase        = rightPtr.baseAddress,
                                  let filteredLeftBase  = filteredLeftPtr.baseAddress,
                                  let filteredRightBase = filteredRightPtr.baseAddress
                            else { return }

                            // Convert Int8 → Float, deinterleaving via stride (matches 16-bit pattern)
                            var scale = Float(0.9 / 128.0)
                            if sourceChannels == 2 {
                                vDSP_vflt8(input,                 2, leftBase,  1, vDSP_Length(sourceFrames8))
                                vDSP_vflt8(input.advanced(by: 1), 2, rightBase, 1, vDSP_Length(sourceFrames8))
                            } else {
                                vDSP_vflt8(input, 1, leftBase, 1, vDSP_Length(sourceFrames8))
                                vDSP_mmov(leftBase, rightBase, vDSP_Length(sourceFrames8), 1, 1, 1)
                            }
                            vDSP_vsmul(leftBase,  1, &scale, leftBase,  1, vDSP_Length(sourceFrames8))
                            vDSP_vsmul(rightBase, 1, &scale, rightBase, 1, vDSP_Length(sourceFrames8))

                            // Anti-alias filter
                            vDSP_conv(leftBase,  1, filterCoeff, 1, filteredLeftBase,  1,
                                      vDSP_Length(sourceFrames8), vDSP_Length(filterSize))
                            vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                      vDSP_Length(sourceFrames8), vDSP_Length(filterSize))

                            // Resample
                            guard let outLeft  = pcmBuffer.floatChannelData?[0],
                                  let outRight = pcmBuffer.floatChannelData?[1] else { return }
                            scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                guard let idxBase = idxPtr.baseAddress else { return }
                                var start = Float(0);  var step = Float(rateRatio)
                                vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                vDSP_vlint(filteredLeftBase,  idxBase, 1, outLeft,  1,
                                           vDSP_Length(outputFrames), vDSP_Length(sourceFrames8))
                                vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                           vDSP_Length(outputFrames), vDSP_Length(sourceFrames8))
                            }
                        }}}}
                    }
                }
            }

            pcmBuffer.frameLength = AVAudioFrameCount(outputFrames)
            return bytesRead
        }
    }
}
