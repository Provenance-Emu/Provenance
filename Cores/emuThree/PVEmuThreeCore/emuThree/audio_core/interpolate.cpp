// Copyright 2016 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <algorithm>
#include <cmath>
#include "audio_core/interpolate.h"
#include "common/assert.h"

// Use ARM NEON intrinsics for ARM64 platforms
#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#endif

namespace AudioCore::AudioInterp {

// Calculations are done in fixed point with 24 fractional bits.
// (This is not verified. This was chosen for minimal error.)
constexpr u64 scale_factor = 1 << 24;
constexpr u64 scale_mask = scale_factor - 1;

/// Here we step over the input in steps of rate, until we consume all of the input.
/// Three adjacent samples are passed to fn each step.
template <typename Function>
static void StepOverSamples(State& state, StereoBuffer16& input, float rate, StereoFrame16& output,
                            std::size_t& outputi, Function fn) {
    ASSERT(rate > 0);

    if (input.empty())
        return;

    input.insert(input.begin(), {state.xn2, state.xn1});

#if defined(__ARM_NEON) && defined(__aarch64__)
    // Precompute step size and use NEON for position calculations when possible
    const u64 step_size = static_cast<u64>(rate * scale_factor);
    u64 fposition = state.fposition;
    std::size_t inputi = 0;
    
    // Process in batches when possible for better cache usage
    const size_t remaining_output = output.size() - outputi;
    
    while (outputi < output.size()) {
        // Calculate input index from position
        inputi = static_cast<std::size_t>(fposition / scale_factor);

        if (inputi + 2 >= input.size()) {
            inputi = input.size() - 2;
            break;
        }

        // Extract fraction part for interpolation
        u64 fraction = fposition & scale_mask;
        
        // Call interpolation function
        output[outputi++] = fn(fraction, input[inputi], input[inputi + 1], input[inputi + 2]);

        // Update position
        fposition += step_size;
    }
#else
    const u64 step_size = static_cast<u64>(rate * scale_factor);
    u64 fposition = state.fposition;
    std::size_t inputi = 0;

    while (outputi < output.size()) {
        inputi = static_cast<std::size_t>(fposition / scale_factor);

        if (inputi + 2 >= input.size()) {
            inputi = input.size() - 2;
            break;
        }

        u64 fraction = fposition & scale_mask;
        output[outputi++] = fn(fraction, input[inputi], input[inputi + 1], input[inputi + 2]);

        fposition += step_size;
    }
#endif

    state.xn2 = input[inputi];
    state.xn1 = input[inputi + 1];
    state.fposition = fposition - inputi * scale_factor;

    input.erase(input.begin(), std::next(input.begin(), inputi + 2));
}

void None(State& state, StereoBuffer16& input, float rate, StereoFrame16& output,
          std::size_t& outputi) {
    StepOverSamples(
        state, input, rate, output, outputi,
        [](u64 fraction, const auto& x0, const auto& x1, const auto& x2) {
#if defined(__ARM_NEON) && defined(__aarch64__)
            // No interpolation needed for None, just return x0 directly
            // But we can use NEON for efficient memory operations
            int16x4_t x0_vec = vld1_s16(x0.data()); // Load as int16x4_t
            std::array<s16, 2> result;
            vst1_s16(result.data(), x0_vec); // Store directly
            return result;
#else
            return x0;
#endif
        });
}

void Linear(State& state, StereoBuffer16& input, float rate, StereoFrame16& output,
            std::size_t& outputi) {
    // Note on accuracy: Some values that this produces are +/- 1 from the actual firmware.
    StepOverSamples(state, input, rate, output, outputi,
                    [](u64 fraction, const auto& x0, const auto& x1, const auto& x2) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                        // Load stereo samples into NEON registers
                        int16x4_t x0_vec = vld1_s16(x0.data()); // Load as int16x4_t
                        int16x4_t x1_vec = vld1_s16(x1.data()); // Load as int16x4_t
                        
                        // Convert to 32-bit for more precision in calculations
                        int32x4_t x0_vec32 = vmovl_s16(x0_vec);
                        int32x4_t x1_vec32 = vmovl_s16(x1_vec);
                        
                        // Calculate delta with saturation
                        int32x4_t delta = vqsubq_s32(x1_vec32, x0_vec32);
                        
                        // Convert fraction to 32-bit and duplicate to all lanes
                        int32x4_t frac_vec = vdupq_n_s32(static_cast<int32_t>(fraction));
                        
                        // Multiply delta by fraction
                        int32x4_t mul_result = vmulq_s32(delta, frac_vec);
                        
                        // Divide by scale_factor (shift right by 24 bits)
                        int32x4_t scaled_delta = vshrq_n_s32(mul_result, 24);
                        
                        // Add to original samples
                        int32x4_t result32 = vaddq_s32(x0_vec32, scaled_delta);
                        
                        // Convert back to 16-bit with saturation
                        int16x4_t result = vqmovn_s32(result32);
                        
                        // Store result in array
                        std::array<s16, 2> result_array;
                        vst1_s16(result_array.data(), result);
                        return result_array;
#else
                        // This is a saturated subtraction. (Verified by black-box fuzzing.)
                        s64 delta0 = std::clamp<s64>(x1[0] - x0[0], -32768, 32767);
                        s64 delta1 = std::clamp<s64>(x1[1] - x0[1], -32768, 32767);

                        return std::array<s16, 2>{
                            static_cast<s16>(x0[0] + fraction * delta0 / scale_factor),
                            static_cast<s16>(x0[1] + fraction * delta1 / scale_factor),
                        };
#endif
                    });
}

void Cubic(State& state, StereoBuffer16& input, float rate, StereoFrame16& output,
           std::size_t& outputi) {
    // Cubic interpolation provides better audio quality than linear
    StepOverSamples(state, input, rate, output, outputi,
                    [](u64 fraction, const auto& x0, const auto& x1, const auto& x2) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                        // Convert fraction to float for NEON vector operations
                        float frac = static_cast<float>(fraction) / static_cast<float>(scale_factor);
                        float32x4_t frac_vec = vdupq_n_f32(frac);
                        float32x4_t frac_squared = vmulq_f32(frac_vec, frac_vec);
                        float32x4_t frac_cubed = vmulq_f32(frac_squared, frac_vec);
                        
                        // Load all samples into NEON registers and convert to float
                        int16x4_t x0_s16 = vld1_s16(x0.data());
                        int16x4_t x1_s16 = vld1_s16(x1.data());
                        int16x4_t x2_s16 = vld1_s16(x2.data());
                        
                        // Convert to 32-bit signed integers
                        int32x4_t x0_s32 = vmovl_s16(x0_s16);
                        int32x4_t x1_s32 = vmovl_s16(x1_s16);
                        int32x4_t x2_s32 = vmovl_s16(x2_s16);
                        
                        // Convert to float
                        float32x4_t x0_f32 = vcvtq_f32_s32(x0_s32);
                        float32x4_t x1_f32 = vcvtq_f32_s32(x1_s32);
                        float32x4_t x2_f32 = vcvtq_f32_s32(x2_s32);
                        
                        // Calculate cubic coefficients for both channels in parallel
                        // a = 0.5 * (x2 - 2*x1 + x0)
                        float32x4_t two_x1 = vmulq_n_f32(x1_f32, 2.0f);
                        float32x4_t x2_minus_2x1 = vsubq_f32(x2_f32, two_x1);
                        float32x4_t x2_minus_2x1_plus_x0 = vaddq_f32(x2_minus_2x1, x0_f32);
                        float32x4_t a = vmulq_n_f32(x2_minus_2x1_plus_x0, 0.5f);
                        
                        // b = 0.5 * (x1 - x0) + (x2 - x1)
                        float32x4_t x1_minus_x0 = vsubq_f32(x1_f32, x0_f32);
                        float32x4_t half_x1_minus_x0 = vmulq_n_f32(x1_minus_x0, 0.5f);
                        float32x4_t x2_minus_x1 = vsubq_f32(x2_f32, x1_f32);
                        float32x4_t b = vaddq_f32(half_x1_minus_x0, x2_minus_x1);
                        
                        // c = 0.5 * (x1 - x0)
                        float32x4_t c = vmulq_n_f32(x1_minus_x0, 0.5f);
                        
                        // d = x0
                        float32x4_t d = x0_f32;
                        
                        // Calculate cubic: a*frac³ + b*frac² + c*frac + d
                        float32x4_t a_term = vmulq_f32(a, frac_cubed);
                        float32x4_t b_term = vmulq_f32(b, frac_squared);
                        float32x4_t c_term = vmulq_f32(c, frac_vec);
                        
                        float32x4_t result_f32 = vaddq_f32(vaddq_f32(vaddq_f32(a_term, b_term), c_term), d);
                        
                        // Convert back to s16 with saturation
                        int32x4_t result_s32 = vcvtq_s32_f32(result_f32);
                        int16x4_t result_s16 = vqmovn_s32(result_s32);
                        
                        // Store result
                        std::array<s16, 2> result;
                        vst1_s16(result.data(), result_s16);
                        return result;
#else
                        // Cubic interpolation coefficients
                        float frac = static_cast<float>(fraction) / static_cast<float>(scale_factor);

                        // Calculate cubic coefficients for each channel
                        std::array<s16, 2> result;
                        for (int i = 0; i < 2; i++) {
                            float a = 0.5f * (x2[i] - 2.0f * x1[i] + x0[i]);
                            float b = 0.5f * (x1[i] - x0[i]) + (x2[i] - x1[i]);
                            float c = 0.5f * (x1[i] - x0[i]);
                            float d = x0[i];

                            // Calculate cubic: a*frac³ + b*frac² + c*frac + d
                            float value = a * frac * frac * frac + b * frac * frac + c * frac + d;

                            // Clamp to s16 range and convert
                            result[i] = static_cast<s16>(std::clamp(value, -32768.0f, 32767.0f));
                        }
                        return result;
#endif
                    });
}

} // namespace AudioCore::AudioInterp
