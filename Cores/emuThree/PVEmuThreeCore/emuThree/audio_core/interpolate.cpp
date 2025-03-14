// Copyright 2016 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <algorithm>
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
#if defined(__ARM_NEON) || defined(__aarch64__)
            // No interpolation needed for None, just return x0 directly
            // But we can still use NEON to potentially optimize memory operations
            return x0;
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
#if defined(__ARM_NEON) || defined(__aarch64__)
                        // Load stereo samples into NEON registers
                        int16x2_t v_x0 = vld1_s16(reinterpret_cast<const int16_t*>(&x0[0]));
                        int16x2_t v_x1 = vld1_s16(reinterpret_cast<const int16_t*>(&x1[0]));
                        
                        // Calculate delta with saturation (x1 - x0)
                        int16x2_t v_delta = vqsub_s16(v_x1, v_x0);
                        
                        // Convert to 32-bit for multiplication
                        int32x2_t v_delta_32 = vmovl_s16(v_delta);
                        int32x2_t v_x0_32 = vmovl_s16(v_x0);
                        
                        // Calculate fraction * delta
                        // First convert fraction to 32-bit fixed-point value for each channel
                        int32x2_t v_fraction = vdup_n_s32(static_cast<int32_t>(fraction));
                        int32x2_t v_product = vmul_s32(v_delta_32, v_fraction);
                        
                        // Divide by scale_factor (shift right by 24)
                        int32x2_t v_scaled = vshr_n_s32(v_product, 24);
                        
                        // Add to original sample
                        int32x2_t v_result_32 = vadd_s32(v_x0_32, v_scaled);
                        
                        // Convert back to 16-bit with saturation
                        int16x2_t v_result = vqmovn_s32(vcombine_s32(v_result_32, v_result_32));
                        
                        // Store result
                        std::array<s16, 2> result;
                        vst1_s16(reinterpret_cast<int16_t*>(&result[0]), v_result);
                        return result;
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
#if defined(__ARM_NEON) || defined(__aarch64__)
                        // Load all three stereo samples into NEON registers
                        int16x2_t v_x0 = vld1_s16(reinterpret_cast<const int16_t*>(&x0[0]));
                        int16x2_t v_x1 = vld1_s16(reinterpret_cast<const int16_t*>(&x1[0]));
                        int16x2_t v_x2 = vld1_s16(reinterpret_cast<const int16_t*>(&x2[0]));
                        
                        // Convert to 32-bit for calculations
                        int32x2_t v_x0_32 = vmovl_s16(v_x0);
                        int32x2_t v_x1_32 = vmovl_s16(v_x1);
                        int32x2_t v_x2_32 = vmovl_s16(v_x2);
                        
                        // Calculate cubic coefficients
                        // a = 0.5 * (x2 - 2*x1 + x0)
                        // b = 0.5 * (x1 - x0) + (x2 - x1)
                        // c = 0.5 * (x1 - x0)
                        // d = x0
                        
                        // Calculate 2*x1
                        int32x2_t v_2x1 = vshl_n_s32(v_x1_32, 1); // 2*x1
                        
                        // a = 0.5 * (x2 - 2*x1 + x0)
                        int32x2_t v_a = vsub_s32(v_x2_32, v_2x1);
                        v_a = vadd_s32(v_a, v_x0_32);
                        v_a = vshr_n_s32(v_a, 1); // Multiply by 0.5 (shift right by 1)
                        
                        // x1 - x0
                        int32x2_t v_x1_x0 = vsub_s32(v_x1_32, v_x0_32);
                        
                        // c = 0.5 * (x1 - x0)
                        int32x2_t v_c = vshr_n_s32(v_x1_x0, 1); // Multiply by 0.5
                        
                        // x2 - x1
                        int32x2_t v_x2_x1 = vsub_s32(v_x2_32, v_x1_32);
                        
                        // b = c + (x2 - x1)
                        int32x2_t v_b = vadd_s32(v_c, v_x2_x1);
                        
                        // d = x0
                        int32x2_t v_d = v_x0_32;
                        
                        // Convert fraction to float for cubic calculation
                        float frac = static_cast<float>(fraction) / static_cast<float>(scale_factor);
                        float32x2_t v_frac = vdup_n_f32(frac);
                        float32x2_t v_frac2 = vmul_f32(v_frac, v_frac); // frac²
                        float32x2_t v_frac3 = vmul_f32(v_frac2, v_frac); // frac³
                        
                        // Convert coefficients to float
                        float32x2_t v_a_f = vcvt_f32_s32(v_a);
                        float32x2_t v_b_f = vcvt_f32_s32(v_b);
                        float32x2_t v_c_f = vcvt_f32_s32(v_c);
                        float32x2_t v_d_f = vcvt_f32_s32(v_d);
                        
                        // Calculate result: a*frac³ + b*frac² + c*frac + d
                        float32x2_t v_result_f = vmul_f32(v_a_f, v_frac3);
                        v_result_f = vmla_f32(v_result_f, v_b_f, v_frac2);
                        v_result_f = vmla_f32(v_result_f, v_c_f, v_frac);
                        v_result_f = vadd_f32(v_result_f, v_d_f);
                        
                        // Convert back to int32
                        int32x2_t v_result_32 = vcvt_s32_f32(v_result_f);
                        
                        // Convert to 16-bit with saturation
                        int16x2_t v_result = vqmovn_s32(vcombine_s32(v_result_32, v_result_32));
                        
                        // Store result
                        std::array<s16, 2> result;
                        vst1_s16(reinterpret_cast<int16_t*>(&result[0]), v_result);
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
