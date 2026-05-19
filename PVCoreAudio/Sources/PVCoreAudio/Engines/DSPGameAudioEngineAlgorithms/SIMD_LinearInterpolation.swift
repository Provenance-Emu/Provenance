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

    /// Fractional sample position carried across render-block boundaries.
    /// Without this, the resampler restarts at index 0 every block, which produces a
    /// phase discontinuity (audible click) at every block boundary.
    var phase: Double = 0

    /// Source-sample tail carried across render-block boundaries so that the FIR
    /// anti-alias filter has valid history at the head of the next block.
    /// Stored as deinterleaved Float channels at the post-scale amplitude.
    var prevTailLeft:  [Float] = []
    var prevTailRight: [Float] = []

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
        //
        // TODO(audio-glitch-audit-r2): `sourceRate`, `targetRate`, `rateRatio`, and the
        // computed `filterCoeff` are captured by the closure at engine setup time and
        // never re-computed. If the emulator core changes its output rate mid-stream
        // (e.g. DS sample-rate switch, some Saturn modes) or the AVAudioSession output
        // rate changes (route change to AirPods Pro 48k → external DAC 44.1k), the
        // resampler runs with a stale ratio → cumulative phase drift and aliasing.
        // Verify: log `gameCore.audioSampleRate(forBuffer: 0)` and
        // `AVAudioSession.sharedInstance().sampleRate` inside the render block once per
        // ~1 s and compare to the cached values. If they ever diverge, this is a real
        // bug. Fix would be to recompute filter coefficients lazily when divergence is
        // detected (cannot allocate on the audio thread → pre-compute a small table or
        // post a notification to the engine to call `updateSourceNode()`).
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

        // History size we need to retain between blocks so the FIR has valid taps at the
        // head of the next block. We need (filterSize - 1) samples of source history.
        let historyFrames = filterSize - 1

        // Number of pad samples appended to the end of each block so vDSP_conv has a
        // full filter window without reading uninitialised scratch memory. The convolution
        // reads (N + filterSize - 1) samples to produce N outputs; we pad with zeros.
        let convPad = filterSize - 1

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

            // After prepending the per-channel history we have this many "usable" samples
            // for the resampler. We subtract `historyFrames` from the effective sample
            // count when computing the available output range because indices 0..<historyFrames
            // in the filtered buffer correspond to a transient where the FIR has not yet
            // seen all of its taps' worth of history (those samples were already emitted
            // from the previous block via the carried tail). The resampler index starts at
            // `historyFrames + scratch.phase` and walks by `rateRatio` per output sample.

            let totalSourceFrames = sourceFrames + historyFrames
            // Filtered output indices in [0, sourceFrames) are computed from a fully-populated
            // FIR window (carried history + real audio). Indices in [sourceFrames, totalSourceFrames)
            // are CONTAMINATED by the zero-pad tail — the filter window crosses the real/zero
            // boundary and produces a smeared, edge-ringing output. The NEXT block computes
            // the equivalent source positions from REAL continuation samples (the carried
            // history), so reading any contaminated index here produces a value that does NOT
            // match the next block's value at the same source position → boundary click.
            //
            // Constraint: vDSP_vlint reads filtered[floor(idx)] and filtered[floor(idx)+1].
            // Both must be uncontaminated, so floor(idx) + 1 <= sourceFrames - 1.
            // Resampler index for output i is `historyFrames + phase + i * rateRatio`.
            //   (outputFrames - 1) * rateRatio < (sourceFrames - 1) - historyFrames - phase
            let phase = scratch.phase
            // NOTE: This caps the max safe index at sourceFrames - 1 (not totalSourceFrames - 1)
            // to keep the linear-interp pair inside the uncontaminated filtered region.
            let usableSpan = Double(sourceFrames - 1) - (Double(historyFrames) + phase)
            let outputFrames = max(0, min(
                targetFrameCount,
                Int(floor(usableSpan / rateRatio))
            ))

            guard outputFrames > 0 else {
                pcmBuffer.frameLength = 0
                return 0
            }

            // Allocate channels large enough to hold history + new samples + zero pad for FIR.
            let capacity = max(totalSourceFrames + convPad, outputFrames)
            scratch.ensureCapacity(capacity)

            // Ensure the carried tail arrays exist with the right size.
            if scratch.prevTailLeft.count  != historyFrames { scratch.prevTailLeft  = [Float](repeating: 0, count: historyFrames) }
            if scratch.prevTailRight.count != historyFrames { scratch.prevTailRight = [Float](repeating: 0, count: historyFrames) }

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

                            // Prepend carried history so the FIR has valid taps at the head.
                            scratch.prevTailLeft.withUnsafeBufferPointer { tailL in
                                if let base = tailL.baseAddress {
                                    vDSP_mmov(base, leftBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }
                            scratch.prevTailRight.withUnsafeBufferPointer { tailR in
                                if let base = tailR.baseAddress {
                                    vDSP_mmov(base, rightBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }

                            // Convert Int16 → Float, deinterleaving channels via stride
                            var scale = Float(0.9 / 32768.0)
                            if sourceChannels == 2 {
                                vDSP_vflt16(input,                  2, leftBase  + historyFrames, 1, vDSP_Length(sourceFrames16))
                                vDSP_vflt16(input.advanced(by: 1),  2, rightBase + historyFrames, 1, vDSP_Length(sourceFrames16))
                            } else {
                                vDSP_vflt16(input, 1, leftBase + historyFrames, 1, vDSP_Length(sourceFrames16))
                                vDSP_mmov(leftBase + historyFrames, rightBase + historyFrames, vDSP_Length(sourceFrames16), 1, 1, 1)
                            }
                            vDSP_vsmul(leftBase  + historyFrames, 1, &scale, leftBase  + historyFrames, 1, vDSP_Length(sourceFrames16))
                            vDSP_vsmul(rightBase + historyFrames, 1, &scale, rightBase + historyFrames, 1, vDSP_Length(sourceFrames16))

                            // Zero-pad the convolution tail so vDSP_conv does not read
                            // stale samples past the end of the populated region.
                            let totalSF = sourceFrames16 + historyFrames
                            memset(leftBase  + totalSF, 0, convPad * MemoryLayout<Float>.size)
                            memset(rightBase + totalSF, 0, convPad * MemoryLayout<Float>.size)

                            // Anti-alias filter: 64-tap Kaiser-windowed sinc convolution.
                            // Produces totalSF outputs from totalSF + convPad inputs.
                            vDSP_conv(leftBase,  1, filterCoeff, 1, filteredLeftBase,  1,
                                      vDSP_Length(totalSF), vDSP_Length(filterSize))
                            vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                      vDSP_Length(totalSF), vDSP_Length(filterSize))

                            // Resample: build fractional index ramp, then gather+interpolate.
                            // Start at (historyFrames + scratch.phase) so we resume exactly
                            // where the last block stopped — no phase discontinuity.
                            guard let outLeft  = pcmBuffer.floatChannelData?[0],
                                  let outRight = pcmBuffer.floatChannelData?[1] else { return }
                            scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                guard let idxBase = idxPtr.baseAddress else { return }
                                var start = Float(Double(historyFrames) + phase)
                                var step  = Float(rateRatio)
                                vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                vDSP_vlint(filteredLeftBase,  idxBase, 1, outLeft,  1,
                                           vDSP_Length(outputFrames), vDSP_Length(totalSF))
                                vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                           vDSP_Length(outputFrames), vDSP_Length(totalSF))
                            }

                            // Carry tail (last `historyFrames` source samples) for next block.
                            let tailStart = totalSF - historyFrames
                            scratch.prevTailLeft.withUnsafeMutableBufferPointer { dst in
                                if let dstBase = dst.baseAddress {
                                    vDSP_mmov(leftBase + tailStart, dstBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }
                            scratch.prevTailRight.withUnsafeMutableBufferPointer { dst in
                                if let dstBase = dst.baseAddress {
                                    vDSP_mmov(rightBase + tailStart, dstBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }

                            // Update phase for the next block.
                            //
                            // Next block's [0, historyFrames) will be filled with this block's
                            // last `historyFrames` source samples (positions [tailStart, totalSF)
                            // == [sourceFrames16, sourceFrames16 + historyFrames) in this block's
                            // coordinate system). So the absolute position where the next block
                            // should resume is `historyFrames + phase + outputFrames * rateRatio`
                            // in this block, which in next block coordinates equals
                            // `historyFrames + (phase + outputFrames * rateRatio - sourceFrames16)`.
                            // NOTE: phase can legitimately go negative when the consumer (output)
                            // rate exceeds the producer's contribution this block — the next block
                            // is expected to re-read into the carried history region (which holds
                            // the last `historyFrames` source samples). Negative phase is valid
                            // down to `-historyFrames`; outside that window the historic carry
                            // is insufficient and we clamp (rare; only when output far exceeds
                            // available source — buffer underrun territory).
                            scratch.phase = phase + Double(outputFrames) * rateRatio - Double(sourceFrames16)
                            if scratch.phase < -Double(historyFrames) {
                                scratch.phase = -Double(historyFrames)
                            }
                        }}}}
                    }
                }

            // ── 8-bit path ────────────────────────────────────────────────────────────────────
            } else if sourceBitDepth == 8 {
                scratch.rawBuffer.withUnsafeMutableBytes { rawPtr in
                    rawPtr.baseAddress!.withMemoryRebound(to: Int8.self, capacity: bytesRead) { input in
                        let sourceFrames8 = bytesRead / sourceChannels
                        let cap8 = max(sourceFrames8 + historyFrames + convPad, outputFrames)
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

                            // Prepend carried history
                            scratch.prevTailLeft.withUnsafeBufferPointer { tailL in
                                if let base = tailL.baseAddress {
                                    vDSP_mmov(base, leftBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }
                            scratch.prevTailRight.withUnsafeBufferPointer { tailR in
                                if let base = tailR.baseAddress {
                                    vDSP_mmov(base, rightBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }

                            // Convert Int8 → Float, deinterleaving via stride (matches 16-bit pattern)
                            var scale = Float(0.9 / 128.0)
                            if sourceChannels == 2 {
                                vDSP_vflt8(input,                 2, leftBase  + historyFrames, 1, vDSP_Length(sourceFrames8))
                                vDSP_vflt8(input.advanced(by: 1), 2, rightBase + historyFrames, 1, vDSP_Length(sourceFrames8))
                            } else {
                                vDSP_vflt8(input, 1, leftBase + historyFrames, 1, vDSP_Length(sourceFrames8))
                                vDSP_mmov(leftBase + historyFrames, rightBase + historyFrames, vDSP_Length(sourceFrames8), 1, 1, 1)
                            }
                            vDSP_vsmul(leftBase  + historyFrames, 1, &scale, leftBase  + historyFrames, 1, vDSP_Length(sourceFrames8))
                            vDSP_vsmul(rightBase + historyFrames, 1, &scale, rightBase + historyFrames, 1, vDSP_Length(sourceFrames8))

                            // Zero-pad the convolution tail
                            let totalSF = sourceFrames8 + historyFrames
                            memset(leftBase  + totalSF, 0, convPad * MemoryLayout<Float>.size)
                            memset(rightBase + totalSF, 0, convPad * MemoryLayout<Float>.size)

                            // Anti-alias filter
                            vDSP_conv(leftBase,  1, filterCoeff, 1, filteredLeftBase,  1,
                                      vDSP_Length(totalSF), vDSP_Length(filterSize))
                            vDSP_conv(rightBase, 1, filterCoeff, 1, filteredRightBase, 1,
                                      vDSP_Length(totalSF), vDSP_Length(filterSize))

                            // Resample
                            guard let outLeft  = pcmBuffer.floatChannelData?[0],
                                  let outRight = pcmBuffer.floatChannelData?[1] else { return }
                            scratch.indexBuffer.withUnsafeMutableBufferPointer { idxPtr in
                                guard let idxBase = idxPtr.baseAddress else { return }
                                var start = Float(Double(historyFrames) + phase)
                                var step  = Float(rateRatio)
                                vDSP_vramp(&start, &step, idxBase, 1, vDSP_Length(outputFrames))
                                vDSP_vlint(filteredLeftBase,  idxBase, 1, outLeft,  1,
                                           vDSP_Length(outputFrames), vDSP_Length(totalSF))
                                vDSP_vlint(filteredRightBase, idxBase, 1, outRight, 1,
                                           vDSP_Length(outputFrames), vDSP_Length(totalSF))
                            }

                            // Carry tail
                            let tailStart = totalSF - historyFrames
                            scratch.prevTailLeft.withUnsafeMutableBufferPointer { dst in
                                if let dstBase = dst.baseAddress {
                                    vDSP_mmov(leftBase + tailStart, dstBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }
                            scratch.prevTailRight.withUnsafeMutableBufferPointer { dst in
                                if let dstBase = dst.baseAddress {
                                    vDSP_mmov(rightBase + tailStart, dstBase, vDSP_Length(historyFrames), 1, 1, 1)
                                }
                            }

                            // See 16-bit path for rationale: negative phase is legitimate down to
                            // -historyFrames (next block reads into carried history).
                            scratch.phase = phase + Double(outputFrames) * rateRatio - Double(sourceFrames8)
                            if scratch.phase < -Double(historyFrames) {
                                scratch.phase = -Double(historyFrames)
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
