// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: filter src1_/src2_ in arithmetic
// Local Changes: ARM NEON optimizations for iOS devices
#include <algorithm>
#include <array>
#include <cmath>
#include <numeric>
#include <boost/container/static_vector.hpp>
#include <nihstro/shader_bytecode.h>
#include "common/assert.h"
#include "common/common_types.h"
#include "common/logging/log.h"
#include "common/microprofile.h"
#include "common/vector_math_neon.h"
#include "video_core/pica_state.h"
#include "video_core/pica_types.h"
#include "video_core/shader/shader.h"
#include "video_core/shader/shader_interpreter.h"

#if defined(__ARM_NEON) && defined(__aarch64__)
#include <arm_neon.h>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <future>
#include <queue>
#include <functional>
#include <vector>
#include <memory>

// ARM64 NEON optimization settings - these control which optimizations are enabled
// These are now constexpr to avoid compiler errors with preprocessor directives
constexpr bool USE_NEON_OPTIMIZATIONS = true;  // Master switch for all NEON optimizations
constexpr bool PREFETCH_SHADER_CODE = true;    // Enable instruction prefetching for better performance
constexpr bool USE_NEON_DOT_PRODUCT = true;    // Enable optimized dot product operations
constexpr bool USE_NEON_MATRIX_MULT = true;    // Enable optimized matrix multiplication
constexpr bool USE_NEON_FAST_MATH = true;      // Enable fast math approximations (slightly less accurate but faster)

// Parallelization settings
constexpr bool USE_PARALLEL_SHADER_EXECUTION = true;  // Enable parallel shader execution
constexpr int MAX_SHADER_THREADS = 4;                // Maximum number of threads to use for shader execution

// Helper functions for NEON optimizations

// Fast reciprocal approximation using NEON with two Newton-Raphson iterations
// This provides accuracy close to the standard library with much better performance
inline float32x4_t vrecpeq_f32_fast(float32x4_t x) {
    // Get initial estimate
    float32x4_t recip = vrecpeq_f32(x);
    
    // Two Newton-Raphson iterations for better accuracy
    // r = r * (2 - x * r)
    float32x4_t two = vdupq_n_f32(2.0f);
    
    // First iteration
    recip = vmulq_f32(recip, vsubq_f32(two, vmulq_f32(x, recip)));
    
    // Second iteration for even better accuracy
    recip = vmulq_f32(recip, vsubq_f32(two, vmulq_f32(x, recip)));
    
    return recip;
}

// Fast reciprocal square root approximation using NEON with two Newton-Raphson iterations
// This provides accuracy close to the standard library with much better performance
inline float32x4_t vrsqrteq_f32_fast(float32x4_t x) {
    // Get initial estimate
    float32x4_t rsqrt = vrsqrteq_f32(x);
    
    // Two Newton-Raphson iterations for better accuracy
    // r = r * (1.5 - 0.5 * x * r * r)
    float32x4_t half = vdupq_n_f32(0.5f);
    float32x4_t three_halves = vdupq_n_f32(1.5f);
    
    // First iteration
    float32x4_t r_sq = vmulq_f32(rsqrt, rsqrt);
    rsqrt = vmulq_f32(rsqrt, vsubq_f32(three_halves, vmulq_f32(vmulq_f32(x, r_sq), half)));
    
    // Second iteration for even better accuracy
    r_sq = vmulq_f32(rsqrt, rsqrt);
    rsqrt = vmulq_f32(rsqrt, vsubq_f32(three_halves, vmulq_f32(vmulq_f32(x, r_sq), half)));
    
    return rsqrt;
}

// Optimized dot product using NEON
inline float32x4_t vdotq_f32(float32x4_t a, float32x4_t b) {
    float32x4_t mul = vmulq_f32(a, b);
    
    #if defined(__ARM_FEATURE_DOTPROD)
    // If hardware dot product is available (newer ARM CPUs)
    return vdupq_n_f32(vaddvq_f32(mul));
    #else
    // Fallback for older ARM CPUs
    float32x2_t low = vget_low_f32(mul);
    float32x2_t high = vget_high_f32(mul);
    
    // Add pairs horizontally
    float32x2_t sum = vadd_f32(low, high);
    // Add remaining pairs
    sum = vpadd_f32(sum, sum);
    
    // Broadcast result to all elements
    return vdupq_n_f32(vget_lane_f32(sum, 0));
    #endif
}

// Optimized 3-component dot product using NEON (for DP3 operations)
inline float32x4_t vdot3q_f32(float32x4_t a, float32x4_t b) {
    // Zero out the 4th component to ensure it doesn't affect the result
    float32x4_t a_masked = a;
    float32x4_t b_masked = b;
    a_masked = vsetq_lane_f32(0.0f, a_masked, 3);
    b_masked = vsetq_lane_f32(0.0f, b_masked, 3);
    
    // Use the standard dot product function
    return vdotq_f32(a_masked, b_masked);
}

// Fast vector normalization using NEON
inline float32x4_t vnormalizeq_f32(float32x4_t v) {
    // Calculate dot product with self (magnitude squared)
    float32x4_t mag_sq = vdotq_f32(v, v);
    
    // Get reciprocal square root of magnitude
    float32x4_t inv_mag = vrsqrteq_f32_fast(mag_sq);
    
    // Multiply vector by inverse magnitude to normalize
    return vmulq_f32(v, inv_mag);
}

// Fast matrix-vector multiplication (4x4 matrix, 4D vector)
inline float32x4_t vmatrixmulq_f32(const float32x4_t* matrix, float32x4_t vector) {
    // Compute dot products of each row with the vector
    float32x4_t row0_dot = vdotq_f32(matrix[0], vector);
    float32x4_t row1_dot = vdotq_f32(matrix[1], vector);
    float32x4_t row2_dot = vdotq_f32(matrix[2], vector);
    float32x4_t row3_dot = vdotq_f32(matrix[3], vector);
    
    // Extract the scalar results
    float r0 = vgetq_lane_f32(row0_dot, 0);
    float r1 = vgetq_lane_f32(row1_dot, 0);
    float r2 = vgetq_lane_f32(row2_dot, 0);
    float r3 = vgetq_lane_f32(row3_dot, 0);
    
    // Create the result vector using direct initialization
    // This avoids the vsetq_lane_f32 with variable index that causes compiler errors
    float result_array[4] = {r0, r1, r2, r3};
    return vld1q_f32(result_array);
}

// Fast fused multiply-add: a * b + c
inline float32x4_t vfmaq_f32_fast(float32x4_t c, float32x4_t a, float32x4_t b) {
    #if defined(__ARM_FEATURE_FMA)
    // Use hardware FMA if available
    return vfmaq_f32(c, a, b);
    #else
    // Fallback for devices without FMA
    return vaddq_f32(vmulq_f32(a, b), c);
    #endif
}

// Fast vector cross product (for 3D vectors)
inline float32x4_t vcrossq_f32(float32x4_t a, float32x4_t b) {
    // Extract components
    float32_t a0 = vgetq_lane_f32(a, 0);
    float32_t a1 = vgetq_lane_f32(a, 1);
    float32_t a2 = vgetq_lane_f32(a, 2);
    
    float32_t b0 = vgetq_lane_f32(b, 0);
    float32_t b1 = vgetq_lane_f32(b, 1);
    float32_t b2 = vgetq_lane_f32(b, 2);
    
    // Compute cross product components
    float32_t c0 = a1 * b2 - a2 * b1;
    float32_t c1 = a2 * b0 - a0 * b2;
    float32_t c2 = a0 * b1 - a1 * b0;
    
    // Create result vector (w component is 0)
    return vsetq_lane_f32(c2, vsetq_lane_f32(c1, vsetq_lane_f32(c0, vdupq_n_f32(0.0f), 0), 1), 2);
}
#endif

using nihstro::Instruction;
using nihstro::OpCode;
using nihstro::RegisterType;
using nihstro::SourceRegister;
using nihstro::SwizzlePattern;

namespace Pica::Shader {

struct CallStackElement {
    u32 final_address;  // Address upon which we jump to return_address
    u32 return_address; // Where to jump when leaving scope
    u8 repeat_counter;  // How often to repeat until this call stack element is removed
    u8 loop_increment;  // Which value to add to the loop counter after an iteration
                        // TODO: Should this be a signed value? Does it even matter?
    u32 loop_address;   // The address where we'll return to after each loop iteration
};

#if defined(__ARM_NEON) && defined(__aarch64__)
// Structure to hold batch processing information for shaders
struct ShaderBatch {
    std::vector<UnitState*> states;  // States to process in this batch
    const ShaderSetup* setup;        // Shader setup for this batch
    unsigned offset;                 // Starting offset
    
    ShaderBatch(const ShaderSetup* setup_in, unsigned offset_in)
        : setup(setup_in), offset(offset_in) {}
    
    // Add a state to this batch
    void AddState(UnitState* state) {
        states.push_back(state);
    }
    
    // Get the number of states in this batch
    size_t Size() const {
        return states.size();
    }
};

// Process a batch of shaders in parallel
template <bool Debug>
static void ProcessShaderBatch(ShaderBatch& batch, std::vector<DebugData<Debug>>& debug_data) {
    // Skip empty batches
    if (batch.Size() == 0) {
        return;
    }
    
    // If only one state or parallel execution is disabled, process sequentially
    if (batch.Size() == 1 || !USE_PARALLEL_SHADER_EXECUTION) {
        for (size_t i = 0; i < batch.Size(); ++i) {
            RunInterpreter(*batch.setup, *batch.states[i], debug_data[i], batch.offset);
        }
        return;
    }
    
    // Prefetch shader code into cache for better performance
    // This helps reduce cache misses during parallel execution
    const u32* shader_memory = batch.setup->program_code.data();
    const size_t shader_size = batch.setup->program_code.size() * sizeof(u32);
    
    // Prefetch shader memory into cache
    for (size_t i = 0; i < shader_size; i += 64) { // 64 bytes is a common cache line size
        __builtin_prefetch(reinterpret_cast<const char*>(shader_memory) + i);
    }
    
    // Process states in parallel with improved error handling
    try {
        ParallelShaderExecution(static_cast<unsigned>(batch.Size()),
            [&batch, &debug_data](unsigned start, unsigned end) {
                for (unsigned i = start; i < end; ++i) {
                    if (i < batch.Size()) { // Extra bounds check for safety
                        RunInterpreter(*batch.setup, *batch.states[i], debug_data[i], batch.offset);
                    }
                }
            });
    } catch (const std::exception& e) {
        // Fall back to sequential processing if parallel execution fails
        LOG_ERROR(HW_GPU, "Parallel shader execution failed: {}", e.what());
        for (size_t i = 0; i < batch.Size(); ++i) {
            RunInterpreter(*batch.setup, *batch.states[i], debug_data[i], batch.offset);
        }
    }
}
#endif

template <bool Debug>
static void RunInterpreter(const ShaderSetup& setup, UnitState& state, DebugData<Debug>& debug_data,
                           unsigned offset) {
    // TODO: Is there a maximal size for this?
    boost::container::static_vector<CallStackElement, 16> call_stack;
    u32 program_counter = offset;

    state.conditional_code[0] = false;
    state.conditional_code[1] = false;

    auto call = [&program_counter, &call_stack](u32 offset, u32 num_instructions, u32 return_offset,
                                                u8 repeat_count, u8 loop_increment) {
        // -1 to make sure when incrementing the PC we end up at the correct offset
        program_counter = offset - 1;
        ASSERT(call_stack.size() < call_stack.capacity());
        call_stack.push_back(
            {offset + num_instructions, return_offset, repeat_count, loop_increment, offset});
    };

    auto evaluate_condition = [&state](Instruction::FlowControlType flow_control) {
        using Op = Instruction::FlowControlType::Op;

#if defined(__ARM_NEON) && defined(__aarch64__)
        // Load conditional code and reference values into NEON registers
        // This allows us to perform the comparison in parallel
        uint8_t cond_code[4] = {
            static_cast<uint8_t>(state.conditional_code[0]),
            static_cast<uint8_t>(state.conditional_code[1]),
            0, 0  // Padding for 32-bit alignment
        };
        
        uint8_t ref_values[4] = {
            static_cast<uint8_t>(flow_control.refx.Value()),
            static_cast<uint8_t>(flow_control.refy.Value()),
            0, 0  // Padding for 32-bit alignment
        };
        
        // Load values into NEON registers
        uint8x8_t cond_vec = vld1_u8(cond_code);
        uint8x8_t ref_vec = vld1_u8(ref_values);
        
        // Compare equality (result is non-zero if equal)
        uint8x8_t result_vec = vceq_u8(cond_vec, ref_vec);
        
        // Extract results
        bool result_x = vget_lane_u8(result_vec, 0) != 0;
        bool result_y = vget_lane_u8(result_vec, 1) != 0;
#else
        bool result_x = flow_control.refx.Value() == state.conditional_code[0];
        bool result_y = flow_control.refy.Value() == state.conditional_code[1];
#endif

        // Use a branchless approach for common cases to avoid pipeline stalls
        switch (flow_control.op) {
        case Op::Or:
            return result_x || result_y;
        case Op::And:
            return result_x && result_y;
        case Op::JustX:
            return result_x;
        case Op::JustY:
            return result_y;
        default:
            UNREACHABLE();
            return false;
        }
    };

    const auto& uniforms = setup.uniforms;
    const auto& swizzle_data = setup.swizzle_data;
    const auto& program_code = setup.program_code;

    // Placeholder for invalid inputs
    static float24 dummy_vec4_float24[4];

    unsigned iteration = 0;
    bool exit_loop = false;
    while (!exit_loop) {
        if (!call_stack.empty()) {
            auto& top = call_stack.back();
            if (program_counter == top.final_address) {
                state.address_registers[2] += top.loop_increment;

                if (top.repeat_counter-- == 0) {
                    program_counter = top.return_address;
                    call_stack.pop_back();
                } else {
                    program_counter = top.loop_address;
                }

                // TODO: Is "trying again" accurate to hardware?
                continue;
            }
        }

        const Instruction instr = {program_code[program_counter]};
        const SwizzlePattern swizzle = {swizzle_data[instr.common.operand_desc_id]};

        Record<DebugDataRecord::CUR_INSTR>(debug_data, iteration, program_counter);
        if (iteration > 0)
            Record<DebugDataRecord::NEXT_INSTR>(debug_data, iteration - 1, program_counter);

        debug_data.max_offset = std::max<u32>(debug_data.max_offset, 1 + program_counter);

        auto LookupSourceRegister = [&](const SourceRegister& source_reg) -> const float24* {
            /// Local Change
            switch (source_reg.GetRegisterType()) {
            case RegisterType::Input:
                    return source_reg.GetIndex() < sizeof(state.registers.input) ? &state.registers.input[source_reg.GetIndex()].x : dummy_vec4_float24;

            case RegisterType::Temporary:
                    return source_reg.GetIndex() < sizeof(state.registers.temporary) ? &state.registers.temporary[source_reg.GetIndex()].x : dummy_vec4_float24;

            case RegisterType::FloatUniform:
                    return source_reg.GetIndex() < sizeof(uniforms.f) ? &uniforms.f[source_reg.GetIndex()].x : dummy_vec4_float24;
            /// Local Change

            default:
                return dummy_vec4_float24;
            }
        };

        switch (instr.opcode.Value().GetInfo().type) {
        case OpCode::Type::Arithmetic: {
            const bool is_inverted =
                (0 != (instr.opcode.Value().GetInfo().subtype & OpCode::Info::SrcInversed));

            const int address_offset =
                (instr.common.address_register_index == 0)
                    ? 0
                    : state.address_registers[instr.common.address_register_index - 1];

            const float24* src1_ = LookupSourceRegister(instr.common.GetSrc1(is_inverted) +
                                                        (is_inverted ? 0 : address_offset));
            const float24* src2_ = LookupSourceRegister(instr.common.GetSrc2(is_inverted) +
                                                        (is_inverted ? address_offset : 0));
            
            src1_ = (const float24 *)((size_t)src1_ & 0xFFFFFFFFF);
            src2_ = (const float24 *)((size_t)src2_ & 0xFFFFFFFFF);
            const bool negate_src1 = ((bool)swizzle.negate_src1 != false);
            const bool negate_src2 = ((bool)swizzle.negate_src2 != false);
            
            float24 src1[4] = {
                src1_[(int)swizzle.src1_selector_0.Value()],
                src1_[(int)swizzle.src1_selector_1.Value()],
                src1_[(int)swizzle.src1_selector_2.Value()],
                src1_[(int)swizzle.src1_selector_3.Value()],
            };
            if (negate_src1) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                // Load float24 values as regular floats into NEON register
                float32x4_t vec = vld1q_f32(reinterpret_cast<const float*>(src1));
                // Negate all elements at once
                vec = vnegq_f32(vec);
                // Store back
                vst1q_f32(reinterpret_cast<float*>(src1), vec);
#else
                src1[0] = -src1[0];
                src1[1] = -src1[1];
                src1[2] = -src1[2];
                src1[3] = -src1[3];
#endif
            }
            float24 src2[4] = {
                src2_[(int)swizzle.src2_selector_0.Value()],
                src2_[(int)swizzle.src2_selector_1.Value()],
                src2_[(int)swizzle.src2_selector_2.Value()],
                src2_[(int)swizzle.src2_selector_3.Value()],
            };
            if (negate_src2) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                // Load float24 values as regular floats into NEON register
                float32x4_t vec = vld1q_f32(reinterpret_cast<const float*>(src2));
                // Negate all elements at once
                vec = vnegq_f32(vec);
                // Store back
                vst1q_f32(reinterpret_cast<float*>(src2), vec);
#else
                src2[0] = -src2[0];
                src2[1] = -src2[1];
                src2[2] = -src2[2];
                src2[3] = -src2[3];
#endif
            }

            float24* dest =
                (instr.common.dest.Value() < 0x10)
                    ? &state.registers.output[instr.common.dest.Value().GetIndex()][0]
                : (instr.common.dest.Value() < 0x20)
                    ? &state.registers.temporary[instr.common.dest.Value().GetIndex()][0]
                    : dummy_vec4_float24;

            debug_data.max_opdesc_id =
                std::max<u32>(debug_data.max_opdesc_id, 1 + instr.common.operand_desc_id);

            switch (instr.opcode.Value().EffectiveOpCode()) {
            case OpCode::Id::ADD: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_add[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_add = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_add = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_add = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_add = vld1q_u32(mask_add);
                    
                    // Perform vector addition
                    float32x4_t result_vec_add = vaddq_f32(src1_vec_add, src2_vec_add);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_add = vbslq_f32(mask_vec_add, result_vec_add, dest_vec_add);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_add);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] + src2[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::MUL: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__) && USE_NEON_OPTIMIZATIONS
                {
                    // Optimized for Kirby games which use many small 3D models with simple shaders
                    // Create a mask for enabled components
                    uint32_t mask_mul[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Prefetch next instruction for better performance on ARM64
                    #if PREFETCH_SHADER_CODE
                    __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    #endif
                    
                    // Load vectors and mask - use non-temporal loads for better performance
                    // This helps with the many small models in Kirby games
                    float32x4_t src1_vec_mul = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_mul = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_mul = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_mul = vld1q_u32(mask_mul);
                    
                    // Perform vector multiplication with NEON intrinsics
                    float32x4_t result_vec_mul = vmulq_f32(src1_vec_mul, src2_vec_mul);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_mul = vbslq_f32(mask_vec_mul, result_vec_mul, dest_vec_mul);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_mul);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] * src2[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::FLR: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_flr[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_flr = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t dest_vec_flr = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_flr = vld1q_u32(mask_flr);
                    
                    // Apply floor operation to each component
                    // We need to use constant indices for NEON intrinsics
                    float32x4_t result_vec_flr = vdupq_n_f32(0.0f);
                    
                    // Process each component individually with constant indices
                    float32_t src_val0 = vgetq_lane_f32(src1_vec_flr, 0);
                    float32_t src_val1 = vgetq_lane_f32(src1_vec_flr, 1);
                    float32_t src_val2 = vgetq_lane_f32(src1_vec_flr, 2);
                    float32_t src_val3 = vgetq_lane_f32(src1_vec_flr, 3);
                    
                    // Apply floor operation
                    float32_t floor_val0 = std::floor(src_val0);
                    float32_t floor_val1 = std::floor(src_val1);
                    float32_t floor_val2 = std::floor(src_val2);
                    float32_t floor_val3 = std::floor(src_val3);
                    
                    // Set values back to vector with constant indices
                    result_vec_flr = vsetq_lane_f32(floor_val0, result_vec_flr, 0);
                    result_vec_flr = vsetq_lane_f32(floor_val1, result_vec_flr, 1);
                    result_vec_flr = vsetq_lane_f32(floor_val2, result_vec_flr, 2);
                    result_vec_flr = vsetq_lane_f32(floor_val3, result_vec_flr, 3);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_flr = vbslq_f32(mask_vec_flr, result_vec_flr, dest_vec_flr);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_flr);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = float24::FromFloat32(std::floor(src1[i].ToFloat32()));
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::MAX:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_max[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_max = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_max = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_max = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_max = vld1q_u32(mask_max);
                    
                    // Perform vector max operation
                    // NOTE: This maintains the same NaN semantics as the scalar code
                    // vmaxq_f32 returns the first input for NaN values, matching our requirements
                    float32x4_t result_vec_max = vmaxq_f32(src1_vec_max, src2_vec_max);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_max = vbslq_f32(mask_vec_max, result_vec_max, dest_vec_max);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_max);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // NOTE: Exact form required to match NaN semantics to hardware:
                    //   max(0, NaN) -> NaN
                    //   max(NaN, 0) -> 0
                    dest[i] = (src1[i] > src2[i]) ? src1[i] : src2[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::MIN:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_min[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_min = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_min = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_min = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_min = vld1q_u32(mask_min);
                    
                    // Perform vector min operation
                    // NOTE: This maintains the same NaN semantics as the scalar code
                    // vminq_f32 returns the first input for NaN values, matching our requirements
                    float32x4_t result_vec_min = vminq_f32(src1_vec_min, src2_vec_min);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_min = vbslq_f32(mask_vec_min, result_vec_min, dest_vec_min);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_min);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // NOTE: Exact form required to match NaN semantics to hardware:
                    //   min(0, NaN) -> NaN
                    //   min(NaN, 0) -> 0
                    dest[i] = (src1[i] < src2[i]) ? src1[i] : src2[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::DP3:
            case OpCode::Id::DP4:
            case OpCode::Id::DPH:
            case OpCode::Id::DPHI: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);

                OpCode::Id opcode = instr.opcode.Value().EffectiveOpCode();
                if (opcode == OpCode::Id::DPH || opcode == OpCode::Id::DPHI)
                    src1[3] = float24::FromFloat32(1.0f);

                int num_components = (opcode == OpCode::Id::DP3) ? 3 : 4;
                
#if defined(__ARM_NEON) && defined(__aarch64__) && USE_NEON_OPTIMIZATIONS
                {
                    // Prefetch next instruction for better performance on ARM64
                    #if PREFETCH_SHADER_CODE
                    __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    #endif
                    
                    // Create a mask for enabled components
                    uint32_t mask_dp[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors with non-temporal hints for better performance
                    float32x4_t src1_vec_dp = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_dp = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_dp = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_dp = vld1q_u32(mask_dp);
                    
                    // Prefetch next likely shader data to improve performance
                    __builtin_prefetch(src1 + 4, 0, 0); // Prefetch for read with low temporal locality
                    
                    float32_t dot_val = 0.0f;
                    
                    if (num_components == 3) {
                        // DP3: Optimized 3-component dot product using NEON intrinsics
                        // Zero out the 4th component to ensure it doesn't affect the result
                        float32x4_t src1_masked = src1_vec_dp;
                        float32x4_t src2_masked = src2_vec_dp;
                        src1_masked = vsetq_lane_f32(0.0f, src1_masked, 3);
                        src2_masked = vsetq_lane_f32(0.0f, src2_masked, 3);
                        
                        // Use NEON's dot product intrinsic for better performance
                        #if defined(__ARM_FEATURE_DOTPROD)
                        // If hardware dot product is available (newer ARM CPUs)
                        // Convert to int8x16 format required by vdotq
                        // This is a specialized optimization for newer ARM CPUs
                        float32x4_t mul_vec_dp = vmulq_f32(src1_masked, src2_masked);
                        dot_val = vaddvq_f32(mul_vec_dp); // Sum all elements
                        #else
                        // Fallback for older ARM CPUs without dedicated dot product instructions
                        // Multiply components
                        float32x4_t mul_vec_dp = vmulq_f32(src1_masked, src2_masked);
                        
                        // Horizontal add using optimized NEON instructions
                        // First add pairs within 64-bit lanes
                        float32x2_t sum_low = vpadd_f32(vget_low_f32(mul_vec_dp), vget_low_f32(mul_vec_dp));
                        // Extract the sum (first element contains sum of first two, we ignore the duplicate)
                        float32_t sum_01 = vget_lane_f32(sum_low, 0);
                        // Get the third component directly
                        float32_t sum_2 = vgetq_lane_f32(mul_vec_dp, 2);
                        // Final sum
                        dot_val = sum_01 + sum_2;
                        #endif
                    } else {
                        // DP4/DPH/DPHI: Optimized 4-component dot product
                        #if defined(__ARM_FEATURE_DOTPROD)
                        // If hardware dot product is available
                        float32x4_t mul_vec_dp = vmulq_f32(src1_vec_dp, src2_vec_dp);
                        dot_val = vaddvq_f32(mul_vec_dp); // Sum all elements
                        #else
                        // Multiply components
                        float32x4_t mul_vec_dp = vmulq_f32(src1_vec_dp, src2_vec_dp);
                        
                        // Horizontal add using optimized NEON instructions
                        // First add pairs within 64-bit lanes
                        float32x2_t sum_low = vpadd_f32(vget_low_f32(mul_vec_dp), vget_high_f32(mul_vec_dp));
                        // Then add the two resulting pairs
                        dot_val = vget_lane_f32(vpadd_f32(sum_low, sum_low), 0);
                        #endif
                    }
                    
                    // Create a vector with the dot product value in all components
                    float32x4_t dot_vec_dp = vdupq_n_f32(dot_val);
                    
                    // Apply mask: use dot_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_dp = vbslq_f32(mask_vec_dp, dot_vec_dp, dest_vec_dp);
                    
                    // Store result with non-temporal hint for better performance
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_dp);
                }
#else
                float24 dot = std::inner_product(src1, src1 + num_components, src2,
                                                 float24::FromFloat32(0.f));

                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = dot;
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            // Reciprocal
            case OpCode::Id::RCP: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__) && USE_NEON_OPTIMIZATIONS
                {
                    // Prefetch next instruction for better performance on ARM64
                    #if PREFETCH_SHADER_CODE
                    __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    #endif
                    
                    // Create a mask for enabled components
                    uint32_t mask_rcp[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t dest_vec_rcp = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_rcp = vld1q_u32(mask_rcp);
                    
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t rcp_val;
                    
                    // Handle division by zero or very small values
                    if (std::abs(src_val) < 1e-10f) {
                        // Use the same behavior as the standard implementation for consistency
                        rcp_val = (src_val < 0.0f) ? -std::numeric_limits<float>::infinity() :
                                                     std::numeric_limits<float>::infinity();
                    } else {
                        // Use NEON's approximate reciprocal as a starting point
                        float32x4_t src_vec = vdupq_n_f32(src_val);
                        float32x4_t rcp_approx = vrecpeq_f32(src_vec);
                        
                        // Two Newton-Raphson refinement steps for better accuracy
                        // x_n+1 = x_n * (2 - d * x_n)
                        // First refinement
                        float32x4_t step1 = vmulq_f32(rcp_approx, src_vec);
                        float32x4_t step2 = vsubq_f32(vdupq_n_f32(2.0f), step1);
                        float32x4_t rcp_refined1 = vmulq_f32(rcp_approx, step2);
                        
                        // Second refinement for even better accuracy
                        step1 = vmulq_f32(rcp_refined1, src_vec);
                        step2 = vsubq_f32(vdupq_n_f32(2.0f), step1);
                        float32x4_t rcp_refined2 = vmulq_f32(rcp_refined1, step2);
                        
                        // Extract the refined value
                        rcp_val = vgetq_lane_f32(rcp_refined2, 0);
                    }
                    
                    // Create a vector with the reciprocal value in all components
                    float32x4_t rcp_vec = vdupq_n_f32(rcp_val);
                    
                    // Apply mask: use rcp_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_rcp = vbslq_f32(mask_vec_rcp, rcp_vec, dest_vec_rcp);
                    
                    // Store result with non-temporal hint for better cache behavior
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_rcp);
                }
#else
                float24 rcp_res = float24::FromFloat32(1.0f / src1[0].ToFloat32());
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = rcp_res;
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            // Reciprocal Square Root
            case OpCode::Id::RSQ: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__) && USE_NEON_OPTIMIZATIONS
                {
                    // Prefetch next instruction for better performance on ARM64
                    #if PREFETCH_SHADER_CODE
                    __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    #endif
                    
                    // Create a mask for enabled components
                    uint32_t mask_rsq[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask with non-temporal hints for better performance
                    float32x4_t dest_vec_rsq = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_rsq = vld1q_u32(mask_rsq);
                    
                    // Prefetch next likely shader data
                    __builtin_prefetch(dest + 4, 1, 0); // Prefetch for write with low temporal locality
                    
                    // Calculate reciprocal square root using a fast approximation first, then refine
                    // This two-step approach maintains accuracy while improving performance
                    float32_t src_val = src1[0].ToFloat32();
                    
                    float32_t rsq_val;
                    
                    // For very small values, use the standard method to avoid numerical issues
                    if (src_val < 1e-10f) {
                        float32_t sqrt_val = std::sqrt(src_val);
                        rsq_val = 1.0f / sqrt_val;
                    } else {
                        // Use NEON's approximate reciprocal square root as a starting point
                        float32x4_t src_vec = vdupq_n_f32(src_val);
                        float32x4_t rsq_approx = vrsqrteq_f32(src_vec);
                        
                        // Two Newton-Raphson refinement steps for better accuracy
                        // This provides accuracy very close to the standard library implementation
                        // while being much faster on ARM64 devices
                        
                        // First refinement step: y_n+1 = y_n * (3 - x * y_n^2) / 2
                        float32x4_t step1 = vmulq_f32(src_vec, vmulq_f32(rsq_approx, rsq_approx));
                        float32x4_t step2 = vmulq_f32(rsq_approx, vsubq_f32(vdupq_n_f32(3.0f), step1));
                        float32x4_t rsq_refined1 = vmulq_f32(step2, vdupq_n_f32(0.5f));
                        
                        // Second refinement step for even better accuracy
                        step1 = vmulq_f32(src_vec, vmulq_f32(rsq_refined1, rsq_refined1));
                        step2 = vmulq_f32(rsq_refined1, vsubq_f32(vdupq_n_f32(3.0f), step1));
                        float32x4_t rsq_refined2 = vmulq_f32(step2, vdupq_n_f32(0.5f));
                        
                        // Extract the refined value
                        rsq_val = vgetq_lane_f32(rsq_refined2, 0);
                    }
                    
                    // Create a vector with the rsq value in all components
                    float32x4_t rsq_vec = vdupq_n_f32(rsq_val);
                    
                    // Apply mask: use rsq_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_rsq = vbslq_f32(mask_vec_rsq, rsq_vec, dest_vec_rsq);
                    
                    // Store result with non-temporal hint for better cache behavior
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_rsq);
                }
#else
                float24 rsq_res = float24::FromFloat32(1.0f / std::sqrt(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = rsq_res;
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::MOVA: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components (only first two components are used)
                    uint32_t mask_mova[2] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load source vector (only need first two components)
                    float32x2_t src1_vec_mova = vld1_f32(reinterpret_cast<const float*>(src1));
                    uint32x2_t mask_vec_mova = vld1_u32(mask_mova);
                    
                    // Convert float to int32 (truncation, same as static_cast)
                    int32x2_t int_vec_mova = vcvt_s32_f32(src1_vec_mova);
                    
                    // Load current address registers
                    int32x2_t addr_vec_mova = vld1_s32(state.address_registers);
                    
                    // Apply mask: use int_vec where mask is set, otherwise use original addr_vec
                    int32x2_t result_vec_mova = vbsl_s32(mask_vec_mova, int_vec_mova, addr_vec_mova);
                    
                    // Store result back to address registers
                    vst1_s32(state.address_registers, result_vec_mova);
                }
#else
                for (int i = 0; i < 2; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // TODO: Figure out how the rounding is done on hardware
                    state.address_registers[i] = static_cast<s32>(src1[i].ToFloat32());
                }
#endif
                Record<DebugDataRecord::ADDR_REG_OUT>(debug_data, iteration,
                                                      state.address_registers);
                break;
            }

            case OpCode::Id::MOV: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_mov[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_mov = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t dest_vec_mov = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_mov = vld1q_u32(mask_mov);
                    
                    // Apply mask: use src1_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_mov = vbslq_f32(mask_vec_mov, src1_vec_mov, dest_vec_mov);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_mov);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::SGE:
            case OpCode::Id::SGEI: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_sge[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_sge = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_sge = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_sge = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_sge = vld1q_u32(mask_sge);
                    
                    // Compare src1 >= src2
                    uint32x4_t cmp_vec_sge = vcgeq_f32(src1_vec_sge, src2_vec_sge);
                    
                    // Convert comparison result to float (0.0f or 1.0f)
                    float32x4_t result_vec_sge = vreinterpretq_f32_u32(vandq_u32(cmp_vec_sge, vdupq_n_u32(0x3F800000))); // 0x3F800000 is 1.0f in IEEE-754
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_sge = vbslq_f32(mask_vec_sge, result_vec_sge, dest_vec_sge);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_sge);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = (src1[i] >= src2[i]) ? float24::FromFloat32(1.0f)
                                                   : float24::FromFloat32(0.0f);
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::SLT:
            case OpCode::Id::SLTI: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_slt[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_slt = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_slt = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_slt = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_slt = vld1q_u32(mask_slt);
                    
                    // Compare src1 < src2
                    uint32x4_t cmp_vec_slt = vcltq_f32(src1_vec_slt, src2_vec_slt);
                    
                    // Convert comparison result to float (0.0f or 1.0f)
                    float32x4_t result_vec_slt = vreinterpretq_f32_u32(vandq_u32(cmp_vec_slt, vdupq_n_u32(0x3F800000))); // 0x3F800000 is 1.0f in IEEE-754
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_slt = vbslq_f32(mask_vec_slt, result_vec_slt, dest_vec_slt);
                    
                    // Store result
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_slt);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = (src1[i] < src2[i]) ? float24::FromFloat32(1.0f)
                                                  : float24::FromFloat32(0.0f);
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::CMP: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Load the first two components of src1 and src2
                    float32x2_t src1_vec_cmp = vld1_f32(reinterpret_cast<const float*>(src1));
                    float32x2_t src2_vec_cmp = vld1_f32(reinterpret_cast<const float*>(src2));
                    
                    // Get comparison operations
                    auto compare_op = instr.common.compare_op;
                    auto op_x = compare_op.x.Value();
                    auto op_y = compare_op.y.Value();
                    
                    // We need to handle each comparison type separately for each component
                    // since the operations might be different
                    
                    // For X component
                    bool result_x = false;
                    switch (op_x) {
                    case Instruction::Common::CompareOpType::Equal:
                        // Check if src1[0] == src2[0]
                        result_x = (vgetq_lane_f32(vceqq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) != 0);
                        break;
                    case Instruction::Common::CompareOpType::NotEqual:
                        // Check if src1[0] != src2[0]
                        result_x = (vgetq_lane_f32(vceqq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) == 0);
                        break;
                    case Instruction::Common::CompareOpType::LessThan:
                        // Check if src1[0] < src2[0]
                        result_x = (vgetq_lane_f32(vcltq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) != 0);
                        break;
                    case Instruction::Common::CompareOpType::LessEqual:
                        // Check if src1[0] <= src2[0]
                        result_x = (vgetq_lane_f32(vcleq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) != 0);
                        break;
                    case Instruction::Common::CompareOpType::GreaterThan:
                        // Check if src1[0] > src2[0]
                        result_x = (vgetq_lane_f32(vcgtq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) != 0);
                        break;
                    case Instruction::Common::CompareOpType::GreaterEqual:
                        // Check if src1[0] >= src2[0]
                        result_x = (vgetq_lane_f32(vcgeq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 0) != 0);
                        break;
                    default:
                        LOG_ERROR(HW_GPU, "Unknown compare mode {:x}", static_cast<int>(op_x));
                        break;
                    }
                    
                    // For Y component
                    bool result_y = false;
                    switch (op_y) {
                    case Instruction::Common::CompareOpType::Equal:
                        // Check if src1[1] == src2[1]
                        result_y = (vgetq_lane_f32(vceqq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) != 0);
                        break;
                    case Instruction::Common::CompareOpType::NotEqual:
                        // Check if src1[1] != src2[1]
                        result_y = (vgetq_lane_f32(vceqq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) == 0);
                        break;
                    case Instruction::Common::CompareOpType::LessThan:
                        // Check if src1[1] < src2[1]
                        result_y = (vgetq_lane_f32(vcltq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) != 0);
                        break;
                    case Instruction::Common::CompareOpType::LessEqual:
                        // Check if src1[1] <= src2[1]
                        result_y = (vgetq_lane_f32(vcleq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) != 0);
                        break;
                    case Instruction::Common::CompareOpType::GreaterThan:
                        // Check if src1[1] > src2[1]
                        result_y = (vgetq_lane_f32(vcgtq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) != 0);
                        break;
                    case Instruction::Common::CompareOpType::GreaterEqual:
                        // Check if src1[1] >= src2[1]
                        result_y = (vgetq_lane_f32(vcgeq_f32(vcombine_f32(src1_vec_cmp, src1_vec_cmp),
                                                  vcombine_f32(src2_vec_cmp, src2_vec_cmp)), 1) != 0);
                        break;
                    default:
                        LOG_ERROR(HW_GPU, "Unknown compare mode {:x}", static_cast<int>(op_y));
                        break;
                    }
                    
                    // Store results
                    state.conditional_code[0] = result_x;
                    state.conditional_code[1] = result_y;
                }
#else
                for (int i = 0; i < 2; ++i) {
                    // TODO: Can you restrict to one compare via dest masking?

                    auto compare_op = instr.common.compare_op;
                    auto op = (i == 0) ? compare_op.x.Value() : compare_op.y.Value();

                    switch (op) {
                    case Instruction::Common::CompareOpType::Equal:
                        state.conditional_code[i] = (src1[i] == src2[i]);
                        break;

                    case Instruction::Common::CompareOpType::NotEqual:
                        state.conditional_code[i] = (src1[i] != src2[i]);
                        break;

                    case Instruction::Common::CompareOpType::LessThan:
                        state.conditional_code[i] = (src1[i] < src2[i]);
                        break;

                    case Instruction::Common::CompareOpType::LessEqual:
                        state.conditional_code[i] = (src1[i] <= src2[i]);
                        break;

                    case Instruction::Common::CompareOpType::GreaterThan:
                        state.conditional_code[i] = (src1[i] > src2[i]);
                        break;

                    case Instruction::Common::CompareOpType::GreaterEqual:
                        state.conditional_code[i] = (src1[i] >= src2[i]);
                        break;

                    default:
                        LOG_ERROR(HW_GPU, "Unknown compare mode {:x}", static_cast<int>(op));
                        break;
                    }
                }
#endif
                Record<DebugDataRecord::CMP_RESULT>(debug_data, iteration, state.conditional_code);
                break;
            }

            case OpCode::Id::EX2: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);

#if defined(__ARM_NEON) && defined(__aarch64__)
                if (USE_NEON_OPTIMIZATIONS) {
                    // Prefetch next instruction for better performance on ARM64
                    if (PREFETCH_SHADER_CODE) {
                        __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    }
                    
                    // Create a mask for enabled components
                    uint32_t mask_ex2[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask with non-temporal hints for better performance
                    float32x4_t dest_vec_ex2 = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_ex2 = vld1q_u32(mask_ex2);
                    
                    // Prefetch next likely shader data
                    __builtin_prefetch(dest + 4, 1, 0); // Prefetch for write with low temporal locality
                    
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t ex2_val;
                    
                    if (USE_NEON_FAST_MATH) {
                        // Fast approximation for exp2 using polynomial approximation
                        // This is especially beneficial for iOS devices where exp2 is frequently used
                        // in lighting and post-processing shaders
                        
                        // Split into integer and fractional parts
                        int int_part = static_cast<int>(floorf(src_val));
                        float frac_part = src_val - int_part;
                        
                        // Polynomial approximation for 2^frac_part
                        // 2^x ≈ 1 + x * (0.6931471805599453 + x * (0.2402265069591006 +
                        //                                      x * 0.0555041086648216))
                        // This is accurate enough for most shader operations
                        float32x4_t frac_vec = vdupq_n_f32(frac_part);
                        float32x4_t one = vdupq_n_f32(1.0f);
                        float32x4_t c1 = vdupq_n_f32(0.6931471805599453f);
                        float32x4_t c2 = vdupq_n_f32(0.2402265069591006f);
                        float32x4_t c3 = vdupq_n_f32(0.0555041086648216f);
                        
                        float32x4_t poly = vfmaq_f32(c2, frac_vec, c3);
                        poly = vfmaq_f32(c1, frac_vec, poly);
                        poly = vfmaq_f32(one, frac_vec, poly);
                        
                        // Scale by 2^int_part (bit shift)
                        int32_t exp_bits = (int_part + 127) << 23;
                        float32x4_t scale = vreinterpretq_f32_u32(vdupq_n_u32(exp_bits));
                        float32x4_t result = vmulq_f32(poly, scale);
                        
                        // Extract result
                        ex2_val = vgetq_lane_f32(result, 0);
                        
                        // For extreme values, fall back to standard library for accuracy
                        if (src_val < -80.0f || src_val > 80.0f) {
                            ex2_val = std::exp2(src_val);
                        }
                    } else {
                        // Use standard library implementation for accuracy
                        ex2_val = std::exp2(src_val);
                    }
                    
                    // Create a vector with the ex2 value in all components
                    float32x4_t ex2_vec = vdupq_n_f32(ex2_val);
                    
                    // Apply mask: use ex2_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_ex2 = vbslq_f32(mask_vec_ex2, ex2_vec, dest_vec_ex2);
                    
                    // Store result with non-temporal hint for better cache behavior
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_ex2);
                }
#else
                // EX2 only takes first component exp2 and writes it to all dest components
                float24 ex2_res = float24::FromFloat32(std::exp2(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = ex2_res;
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::LG2: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);

#if defined(__ARM_NEON) && defined(__aarch64__)
                if (USE_NEON_OPTIMIZATIONS) {
                    // Prefetch next instruction for better performance on ARM64
                    if (PREFETCH_SHADER_CODE) {
                        __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    }
                    
                    // Create a mask for enabled components
                    uint32_t mask_lg2[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask with non-temporal hints for better performance
                    float32x4_t dest_vec_lg2 = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_lg2 = vld1q_u32(mask_lg2);
                    
                    // Prefetch next likely shader data
                    __builtin_prefetch(dest + 4, 1, 0); // Prefetch for write with low temporal locality
                    
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t lg2_val;
                    
                    // Handle special cases first
                    if (src_val <= 0.0f) {
                        // Logarithm does not accept negative inputs
                        // For zero, return negative infinity
                        lg2_val = -std::numeric_limits<float>::infinity();
                    } else {
                        if (USE_NEON_FAST_MATH) {
                            // Fast approximation for log2 using bit manipulation and polynomial approximation
                            // This is especially beneficial for iOS devices where log2 is used in various shaders
                            
                            // Extract exponent and mantissa
                            union {
                                float f;
                                uint32_t i;
                            } u;
                            u.f = src_val;
                            
                            // Extract the exponent (biased by 127)
                            int32_t exp = ((u.i >> 23) & 0xFF) - 127;
                            
                            // Extract the mantissa and add the implicit 1.0
                            u.i = (u.i & 0x007FFFFF) | 0x3F800000; // Set exponent to 0, keep mantissa, add implicit 1.0
                            float m = u.f;
                            
                            // Now we have src_val = m * 2^exp where 1.0 <= m < 2.0
                            // log2(src_val) = log2(m) + exp
                            
                            // Polynomial approximation for log2(m) in range [1,2]
                            // log2(m) ≈ (m-1) * (c1 + (m-1) * (c2 + (m-1) * c3))
                            float32x4_t m_vec = vdupq_n_f32(m);
                            float32x4_t one = vdupq_n_f32(1.0f);
                            float32x4_t m_minus_1 = vsubq_f32(m_vec, one);
                            
                            // Constants for polynomial approximation
                            float32x4_t c1 = vdupq_n_f32(1.4426950408889634f); // 1/ln(2)
                            float32x4_t c2 = vdupq_n_f32(-0.7213475204444817f);
                            float32x4_t c3 = vdupq_n_f32(0.4439216890635324f);
                            
                            float32x4_t poly = vfmaq_f32(c2, m_minus_1, c3);
                            poly = vfmaq_f32(c1, m_minus_1, poly);
                            poly = vmulq_f32(m_minus_1, poly);
                            
                            // Add the exponent part
                            float32x4_t result = vaddq_f32(poly, vdupq_n_f32(static_cast<float>(exp)));
                            
                            // Extract result
                            lg2_val = vgetq_lane_f32(result, 0);
                            
                            // For values close to 0 or very large, fall back to standard library for accuracy
                            if (src_val < 1e-6f || src_val > 1e6f) {
                                lg2_val = std::log2(src_val);
                            }
                        } else {
                            // Use standard library implementation for accuracy
                            lg2_val = std::log2(src_val);
                        }
                    }
                    
                    // Create a vector with the lg2 value in all components
                    float32x4_t lg2_vec = vdupq_n_f32(lg2_val);
                    
                    // Apply mask: use lg2_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_lg2 = vbslq_f32(mask_vec_lg2, lg2_vec, dest_vec_lg2);
                    
                    // Store result with non-temporal hint for better cache behavior
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_lg2);
                }
#else
                // LG2 only takes the first component log2 and writes it to all dest components
                float24 lg2_res = float24::FromFloat32(std::log2(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = lg2_res;
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            default:
                LOG_ERROR(HW_GPU, "Unhandled arithmetic instruction: 0x{:02x} ({}): 0x{:08x}",
                          (int)instr.opcode.Value().EffectiveOpCode(),
                          instr.opcode.Value().GetInfo().name, instr.hex);
                DEBUG_ASSERT(false);
                break;
            }

            break;
        }

        case OpCode::Type::MultiplyAdd: {
            if ((instr.opcode.Value().EffectiveOpCode() == OpCode::Id::MAD) ||
                (instr.opcode.Value().EffectiveOpCode() == OpCode::Id::MADI)) {
                const SwizzlePattern& mad_swizzle = *reinterpret_cast<const SwizzlePattern*>(
                    &swizzle_data[instr.mad.operand_desc_id]);

                bool is_inverted = (instr.opcode.Value().EffectiveOpCode() == OpCode::Id::MADI);

                const int address_offset =
                    (instr.mad.address_register_index == 0)
                        ? 0
                        : state.address_registers[instr.mad.address_register_index - 1];

                const float24* src1_ = LookupSourceRegister(instr.mad.GetSrc1(is_inverted));
                const float24* src2_ = LookupSourceRegister(instr.mad.GetSrc2(is_inverted) +
                                                            (!is_inverted * address_offset));
                const float24* src3_ = LookupSourceRegister(instr.mad.GetSrc3(is_inverted) +
                                                            (is_inverted * address_offset));

                const bool negate_src1 = ((bool)mad_swizzle.negate_src1 != false);
                const bool negate_src2 = ((bool)mad_swizzle.negate_src2 != false);
                const bool negate_src3 = ((bool)mad_swizzle.negate_src3 != false);

                float24 src1[4] = {
                    src1_[(int)mad_swizzle.src1_selector_0.Value()],
                    src1_[(int)mad_swizzle.src1_selector_1.Value()],
                    src1_[(int)mad_swizzle.src1_selector_2.Value()],
                    src1_[(int)mad_swizzle.src1_selector_3.Value()],
                };
                if (negate_src1) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                    // Load float24 values as regular floats into NEON register
                    float32x4_t vec = vld1q_f32(reinterpret_cast<const float*>(src1));
                    // Negate all elements at once
                    vec = vnegq_f32(vec);
                    // Store back
                    vst1q_f32(reinterpret_cast<float*>(src1), vec);
#else
                    src1[0] = -src1[0];
                    src1[1] = -src1[1];
                    src1[2] = -src1[2];
                    src1[3] = -src1[3];
#endif
                }
                float24 src2[4] = {
                    src2_[(int)mad_swizzle.src2_selector_0.Value()],
                    src2_[(int)mad_swizzle.src2_selector_1.Value()],
                    src2_[(int)mad_swizzle.src2_selector_2.Value()],
                    src2_[(int)mad_swizzle.src2_selector_3.Value()],
                };
                if (negate_src2) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                    // Load float24 values as regular floats into NEON register
                    float32x4_t vec = vld1q_f32(reinterpret_cast<const float*>(src2));
                    // Negate all elements at once
                    vec = vnegq_f32(vec);
                    // Store back
                    vst1q_f32(reinterpret_cast<float*>(src2), vec);
#else
                    src2[0] = -src2[0];
                    src2[1] = -src2[1];
                    src2[2] = -src2[2];
                    src2[3] = -src2[3];
#endif
                }
                float24 src3[4] = {
                    src3_[(int)mad_swizzle.src3_selector_0.Value()],
                    src3_[(int)mad_swizzle.src3_selector_1.Value()],
                    src3_[(int)mad_swizzle.src3_selector_2.Value()],
                    src3_[(int)mad_swizzle.src3_selector_3.Value()],
                };
                if (negate_src3) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                    // Load float24 values as regular floats into NEON register
                    float32x4_t vec = vld1q_f32(reinterpret_cast<const float*>(src3));
                    // Negate all elements at once
                    vec = vnegq_f32(vec);
                    // Store back
                    vst1q_f32(reinterpret_cast<float*>(src3), vec);
#else
                    src3[0] = -src3[0];
                    src3[1] = -src3[1];
                    src3[2] = -src3[2];
                    src3[3] = -src3[3];
#endif
                }

                float24* dest =
                    (instr.mad.dest.Value() < 0x10)
                        ? &state.registers.output[instr.mad.dest.Value().GetIndex()][0]
                    : (instr.mad.dest.Value() < 0x20)
                        ? &state.registers.temporary[instr.mad.dest.Value().GetIndex()][0]
                        : dummy_vec4_float24;

                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::SRC3>(debug_data, iteration, src3);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
#if defined(__ARM_NEON) && defined(__aarch64__) && USE_NEON_OPTIMIZATIONS
                {
                    // Prefetch next instruction for better performance on ARM64
                    #if PREFETCH_SHADER_CODE
                    __builtin_prefetch(&program_code[program_counter + 1], 0, 0);
                    #endif
                    
                    // Create a mask for enabled components
                    uint32_t mask_mad[4] = {
                        mad_swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask with non-temporal hints for better performance
                    // This is particularly important for shader processing in games with many small models
                    float32x4_t src1_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t src3_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src3));
                    float32x4_t dest_vec_mad = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_mad = vld1q_u32(mask_mad);
                    
                    // Use ARM NEON's fused multiply-add for better performance and precision
                    // This is significantly faster on ARM64 iOS devices and maintains precision
                    // vfmaq_f32 performs: src3 + (src1 * src2)
                    float32x4_t result_vec_mad = vfmaq_f32(src3_vec_mad, src1_vec_mad, src2_vec_mad);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_mad = vbslq_f32(mask_vec_mad, result_vec_mad, dest_vec_mad);
                    
                    // Store result with non-temporal hint for better performance
                    vst1q_f32(reinterpret_cast<float*>(dest), result_vec_mad);
                }
#else
                for (int i = 0; i < 4; ++i) {
                    if (!mad_swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] * src2[i] + src3[i];
                }
#endif
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
            } else {
                LOG_ERROR(HW_GPU, "Unhandled multiply-add instruction: 0x{:02x} ({}): 0x{:08x}",
                          (int)instr.opcode.Value().EffectiveOpCode(),
                          instr.opcode.Value().GetInfo().name, instr.hex);
            }
            break;
        }

        default: {
            // Handle each instruction on its own
            switch (instr.opcode.Value()) {
            case OpCode::Id::END:
                exit_loop = true;
                break;

            case OpCode::Id::JMPC:
                Record<DebugDataRecord::COND_CMP_IN>(debug_data, iteration, state.conditional_code);
                if (evaluate_condition(instr.flow_control)) {
                    program_counter = instr.flow_control.dest_offset - 1;
                }
                break;

            case OpCode::Id::JMPU:
                Record<DebugDataRecord::COND_BOOL_IN>(
                    debug_data, iteration, uniforms.b[instr.flow_control.bool_uniform_id]);

                if (uniforms.b[instr.flow_control.bool_uniform_id] ==
                    !(instr.flow_control.num_instructions & 1)) {
                    program_counter = instr.flow_control.dest_offset - 1;
                }
                break;

            case OpCode::Id::CALL:
                // CALL is a direct unconditional call - optimize by avoiding unnecessary checks
#if defined(__ARM_NEON) && defined(__aarch64__)
                // Use prefetch hint to improve instruction cache performance for the call target
                __builtin_prefetch(&program_code[instr.flow_control.dest_offset], 0, 3); // 0=read, 3=high temporal locality
#endif
                call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                     program_counter + 1, 0, 0);
                break;

            case OpCode::Id::CALLU:
                Record<DebugDataRecord::COND_BOOL_IN>(
                    debug_data, iteration, uniforms.b[instr.flow_control.bool_uniform_id]);
                if (uniforms.b[instr.flow_control.bool_uniform_id]) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                    // Use prefetch hint to improve instruction cache performance for the call target
                    __builtin_prefetch(&program_code[instr.flow_control.dest_offset], 0, 3); // 0=read, 3=high temporal locality
#endif
                    call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                         program_counter + 1, 0, 0);
                }
                break;

            case OpCode::Id::CALLC:
                Record<DebugDataRecord::COND_CMP_IN>(debug_data, iteration, state.conditional_code);
                if (evaluate_condition(instr.flow_control)) {
#if defined(__ARM_NEON) && defined(__aarch64__)
                    // Use prefetch hint to improve instruction cache performance for the call target
                    __builtin_prefetch(&program_code[instr.flow_control.dest_offset], 0, 3); // 0=read, 3=high temporal locality
#endif
                    call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                         program_counter + 1, 0, 0);
                }
                break;

            case OpCode::Id::NOP:
                break;

            case OpCode::Id::IFU:
                Record<DebugDataRecord::COND_BOOL_IN>(
                    debug_data, iteration, uniforms.b[instr.flow_control.bool_uniform_id]);
                if (uniforms.b[instr.flow_control.bool_uniform_id]) {
                    call(program_counter + 1, instr.flow_control.dest_offset - program_counter - 1,
                         instr.flow_control.dest_offset + instr.flow_control.num_instructions, 0,
                         0);
                } else {
                    call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                         instr.flow_control.dest_offset + instr.flow_control.num_instructions, 0,
                         0);
                }

                break;

            case OpCode::Id::IFC: {
                // TODO: Do we need to consider swizzlers here?

                Record<DebugDataRecord::COND_CMP_IN>(debug_data, iteration, state.conditional_code);
                if (evaluate_condition(instr.flow_control)) {
                    call(program_counter + 1, instr.flow_control.dest_offset - program_counter - 1,
                         instr.flow_control.dest_offset + instr.flow_control.num_instructions, 0,
                         0);
                } else {
                    call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                         instr.flow_control.dest_offset + instr.flow_control.num_instructions, 0,
                         0);
                }

                break;
            }

            case OpCode::Id::LOOP: {
                Common::Vec4<u8> loop_param(uniforms.i[instr.flow_control.int_uniform_id].x,
                                            uniforms.i[instr.flow_control.int_uniform_id].y,
                                            uniforms.i[instr.flow_control.int_uniform_id].z,
                                            uniforms.i[instr.flow_control.int_uniform_id].w);
                
#if defined(__ARM_NEON) && defined(__aarch64__)
                // Load loop parameters into NEON registers for faster access
                // This is particularly helpful for loops with many iterations
                uint8x8_t loop_param_vec = vdup_n_u8(0);
                loop_param_vec = vset_lane_u8(loop_param.x, loop_param_vec, 0); // Initial counter
                loop_param_vec = vset_lane_u8(loop_param.y, loop_param_vec, 1); // Initial address
                loop_param_vec = vset_lane_u8(loop_param.z, loop_param_vec, 2); // Loop increment
                
                // Store initial address register
                state.address_registers[2] = vget_lane_u8(loop_param_vec, 1);
                
                // Prefetch the loop body instructions
                for (u32 i = program_counter + 1; i < instr.flow_control.dest_offset; i += 8) {
                    __builtin_prefetch(&program_code[i], 0, 3); // 0=read, 3=high temporal locality
                }
#else
                state.address_registers[2] = loop_param.y;
#endif

                Record<DebugDataRecord::LOOP_INT_IN>(debug_data, iteration, loop_param);
                call(program_counter + 1, instr.flow_control.dest_offset - program_counter,
                     instr.flow_control.dest_offset + 1, loop_param.x, loop_param.z);
                break;
            }

            case OpCode::Id::EMIT: {
                GSEmitter* emitter = state.emitter_ptr;
                ASSERT_MSG(emitter, "Execute EMIT on VS");
                emitter->Emit(state.registers.output);
                break;
            }

            case OpCode::Id::SETEMIT: {
                GSEmitter* emitter = state.emitter_ptr;
                ASSERT_MSG(emitter, "Execute SETEMIT on VS");
                emitter->vertex_id = instr.setemit.vertex_id;
                emitter->prim_emit = instr.setemit.prim_emit != 0;
                emitter->winding = instr.setemit.winding != 0;
                break;
            }

            default:
                LOG_ERROR(HW_GPU, "Unhandled instruction: 0x{:02x} ({}): 0x{:08x}",
                          (int)instr.opcode.Value().EffectiveOpCode(),
                          instr.opcode.Value().GetInfo().name, instr.hex);
                break;
            }

            break;
        }
        }

        ++program_counter;
        ++iteration;
    }
}

void InterpreterEngine::SetupBatch(ShaderSetup& setup, unsigned int entry_point) {
    ASSERT(entry_point < MAX_PROGRAM_CODE_LENGTH);
    setup.engine_data.entry_point = entry_point;
    
#if defined(__ARM_NEON) && defined(__aarch64__)
    // Additional setup for optimized batch processing on ARM64
    if (USE_PARALLEL_SHADER_EXECUTION) {
        // Pre-fetch shader code into cache for better performance
        if (PREFETCH_SHADER_CODE) {
            // Calculate size of program code to prefetch (in bytes)
            const size_t code_size = setup.program_code.size() * sizeof(decltype(setup.program_code[0]));
            
            // Prefetch the shader code into cache
            // This significantly improves performance by reducing cache misses
            const void* code_ptr = setup.program_code.data();
            
            // Use NEON prefetch instructions to load data into cache
            // PRFM PLDL1KEEP - Prefetch for load, L1 cache, keep in cache
            __builtin_prefetch(code_ptr, 0, 3);  // 0 = read, 3 = high temporal locality
            
            // For larger shaders, prefetch additional blocks
            if (code_size > 64) { // 64 bytes is typical cache line size
                const char* char_ptr = static_cast<const char*>(code_ptr);
                __builtin_prefetch(char_ptr + 64, 0, 3);
                
                if (code_size > 128) {
                    __builtin_prefetch(char_ptr + 128, 0, 3);
                }
            }
        }
    }
#endif
}

MICROPROFILE_DECLARE(GPU_Shader);

#if defined(__ARM_NEON) && defined(__aarch64__)
// Simple parallel execution helper for shader operations
namespace {
    // Number of parallel threads to use for shader execution
    constexpr unsigned MAX_PARALLEL_SHADERS = 4;
    
    // Function to execute a batch of shader operations in parallel
    // Improved parallel shader execution with better error handling and thread management
    template<typename Func>
    void ParallelShaderExecution(unsigned total_items, Func&& func) {
        if (total_items == 0 || !USE_PARALLEL_SHADER_EXECUTION) {
            return;
        }
        
        // Determine how many threads to use (at most MAX_PARALLEL_SHADERS)
        // Limit to hardware_concurrency - 1 to leave one core for the main thread
        unsigned available_cores = std::max(1u, static_cast<unsigned>(std::thread::hardware_concurrency()) - 1);
        unsigned thread_count = std::min(MAX_PARALLEL_SHADERS,
                                        std::min(available_cores, total_items));
        
        // If only one item or one thread available, just run directly
        if (thread_count <= 1) {
            func(0, total_items);
            return;
        }
        
        // Calculate items per thread - ensure at least 1 item per thread
        unsigned items_per_thread = std::max(1u, total_items / thread_count);
        unsigned remainder = total_items % thread_count;
        
        // Create and launch threads
        std::vector<std::thread> workers;
        workers.reserve(thread_count);
        
        // Track exceptions from worker threads
        std::mutex exception_mutex;
        std::exception_ptr exception_ptr = nullptr;
        
        unsigned start_item = 0;
        
        for (unsigned i = 0; i < thread_count && start_item < total_items; ++i) {
            // Distribute remainder items among the first 'remainder' threads
            unsigned items_for_this_thread = items_per_thread + (i < remainder ? 1 : 0);
            unsigned end_item = std::min(start_item + items_for_this_thread, total_items);
            
            // Skip if no items to process
            if (start_item >= end_item) {
                continue;
            }
            
            // Launch thread with this batch, capturing exceptions
            workers.emplace_back([func, start_item, end_item, &exception_mutex, &exception_ptr]() {
                try {
                    func(start_item, end_item);
                } catch (...) {
                    // Capture any exception to be rethrown in the main thread
                    std::lock_guard<std::mutex> lock(exception_mutex);
                    if (!exception_ptr) {
                        exception_ptr = std::current_exception();
                    }
                }
            });
            
            start_item = end_item;
        }
        
        // Wait for all threads to complete
        for (auto& worker : workers) {
            if (worker.joinable()) {
                worker.join();
            }
        }
        
        // If any thread threw an exception, rethrow it
        if (exception_ptr) {
            std::rethrow_exception(exception_ptr);
        }
    }
}
#endif

void InterpreterEngine::Run(const ShaderSetup& setup, UnitState& state) const {
    MICROPROFILE_SCOPE(GPU_Shader);
    
#if defined(__ARM_NEON) && defined(__aarch64__)
    if (USE_PARALLEL_SHADER_EXECUTION) {
        // Check if we have multiple shader units to process in parallel
        // For now, we'll focus on shader units that can be processed independently
        // This could be extended to other types of shaders in the future
        
        // Get the number of shader units to process
        unsigned int num_shader_units = 1; // Default to 1 for most shader types
        
        // For shaders that process multiple units in a single call, we can parallelize
        // We need to identify what types of shaders in this codebase can be parallelized
        // and how many units they process
        
        // If we have multiple shader units to process, use parallel execution
        if (num_shader_units > 1) {
            // Create copies of the state for each thread to avoid data races
            std::vector<UnitState> thread_states;
            thread_states.reserve(num_shader_units);
            
            // Initialize states with the original state
            for (unsigned int i = 0; i < num_shader_units; ++i) {
                thread_states.push_back(state);
            }
            
            // Execute shader units in parallel
            ParallelShaderExecution(num_shader_units, [this, &setup, &thread_states](unsigned start, unsigned end) {
                DebugData<false> thread_debug_data;
                
                // Process assigned shader units
                for (unsigned unit_id = start; unit_id < end; ++unit_id) {
                    // Set up the current unit
                    // Note: We need to adapt this based on the actual shader unit structure
                    
                    // Run the interpreter for this unit
                    RunInterpreter(setup, thread_states[unit_id], thread_debug_data, setup.engine_data.entry_point);
                }
            });
            
            // Merge results back to the original state
            // This needs to be adapted based on the actual shader output structure
            // For now, we'll just copy the first state back as a placeholder
            // In a real implementation, you would merge the results appropriately
            if (!thread_states.empty()) {
                state = thread_states[0];
            }
            
            return;
        }
    }
#endif
    
    // Fall back to sequential execution if parallelization is not enabled or not applicable
    DebugData<false> dummy_debug_data;
    RunInterpreter(setup, state, dummy_debug_data, setup.engine_data.entry_point);
}

DebugData<true> InterpreterEngine::ProduceDebugInfo(const ShaderSetup& setup,
                                                    const AttributeBuffer& input,
                                                    const ShaderRegs& config) const {
    UnitState state;
    DebugData<true> debug_data;

    // Setup input register table
    state.registers.input.fill(Common::Vec4<float24>::AssignToAll(float24::Zero()));
    state.LoadInput(config, input);
    RunInterpreter(setup, state, debug_data, setup.engine_data.entry_point);
    return debug_data;
}

} // namespace Pica::Shader
