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
#include "common/vector_math.h"
#include "video_core/pica_state.h"
#include "video_core/pica_types.h"
#include "video_core/shader/shader.h"
#include "video_core/shader/shader_interpreter.h"

#if defined(__ARM_NEON) && defined(__aarch64__)
#include <arm_neon.h>
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
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_mul[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_mul = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_mul = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_mul = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_mul = vld1q_u32(mask_mul);
                    
                    // Perform vector multiplication
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
                
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_dp[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors
                    float32x4_t src1_vec_dp = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_dp = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t dest_vec_dp = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_dp = vld1q_u32(mask_dp);
                    
                    // Perform vector multiplication
                    float32x4_t mul_vec_dp = vmulq_f32(src1_vec_dp, src2_vec_dp);
                    
                    // Calculate dot product
                    float32_t dot_val = 0.0f;
                    if (num_components == 3) {
                        // DP3: Only use x, y, z components
                        float32x2_t sum_dp = vpadd_f32(vget_low_f32(mul_vec_dp), vget_low_f32(mul_vec_dp));
                        dot_val = vget_lane_f32(sum_dp, 0) + vget_lane_f32(vget_high_f32(mul_vec_dp), 0);
                    } else {
                        // DP4/DPH/DPHI: Use all four components
                        float32x2_t sum_dp = vpadd_f32(vget_low_f32(mul_vec_dp), vget_high_f32(mul_vec_dp));
                        dot_val = vget_lane_f32(vpadd_f32(sum_dp, sum_dp), 0);
                    }
                    
                    // Create a vector with the dot product value in all components
                    float32x4_t dot_vec_dp = vdupq_n_f32(dot_val);
                    
                    // Apply mask: use dot_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_dp = vbslq_f32(mask_vec_dp, dot_vec_dp, dest_vec_dp);
                    
                    // Store result
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
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
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
                    
                    // Calculate reciprocal using the exact same method as the non-NEON implementation
                    // This ensures numerical consistency between NEON and non-NEON code paths
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t rcp_val = 1.0f / src_val;
                    
                    // Create a vector with the reciprocal value in all components
                    float32x4_t rcp_vec = vdupq_n_f32(rcp_val);
                    
                    // Apply mask: use rcp_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_rcp = vbslq_f32(mask_vec_rcp, rcp_vec, dest_vec_rcp);
                    
                    // Store result
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
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_rsq[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t dest_vec_rsq = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_rsq = vld1q_u32(mask_rsq);
                    
                    // Calculate reciprocal square root using the exact same method as the non-NEON implementation
                    // ARM NEON provides vrsqrteq_f32 for approximate reciprocal square root
                    // but we need precise results matching the original implementation for numerical consistency
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t sqrt_val = std::sqrt(src_val);
                    float32_t rsq_val = 1.0f / sqrt_val;
                    
                    // Create a vector with the rsq value in all components
                    float32x4_t rsq_vec = vdupq_n_f32(rsq_val);
                    
                    // Apply mask: use rsq_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_rsq = vbslq_f32(mask_vec_rsq, rsq_vec, dest_vec_rsq);
                    
                    // Store result
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
                {
                    // Create a mask for enabled components
                    uint32_t mask_ex2[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t dest_vec_ex2 = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_ex2 = vld1q_u32(mask_ex2);
                    
                    // Calculate exp2 of the first component using the exact same method as the non-NEON implementation
                    // This ensures numerical consistency between NEON and non-NEON code paths
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t ex2_val = std::exp2(src_val);
                    
                    // Create a vector with the ex2 value in all components
                    float32x4_t ex2_vec = vdupq_n_f32(ex2_val);
                    
                    // Apply mask: use ex2_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_ex2 = vbslq_f32(mask_vec_ex2, ex2_vec, dest_vec_ex2);
                    
                    // Store result
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
                {
                    // Create a mask for enabled components
                    uint32_t mask_lg2[4] = {
                        swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t dest_vec_lg2 = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_lg2 = vld1q_u32(mask_lg2);
                    
                    // Calculate log2 of the first component using the exact same method as the non-NEON implementation
                    // This ensures numerical consistency between NEON and non-NEON code paths
                    float32_t src_val = src1[0].ToFloat32();
                    float32_t lg2_val = std::log2(src_val);
                    
                    // Create a vector with the lg2 value in all components
                    float32x4_t lg2_vec = vdupq_n_f32(lg2_val);
                    
                    // Apply mask: use lg2_vec where mask is set, otherwise use original dest_vec
                    float32x4_t result_vec_lg2 = vbslq_f32(mask_vec_lg2, lg2_vec, dest_vec_lg2);
                    
                    // Store result
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
#if defined(__ARM_NEON) && defined(__aarch64__)
                {
                    // Create a mask for enabled components
                    uint32_t mask_mad[4] = {
                        mad_swizzle.DestComponentEnabled(0) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(1) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(2) ? 0xFFFFFFFF : 0,
                        mad_swizzle.DestComponentEnabled(3) ? 0xFFFFFFFF : 0
                    };
                    
                    // Load vectors and mask
                    float32x4_t src1_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src1));
                    float32x4_t src2_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src2));
                    float32x4_t src3_vec_mad = vld1q_f32(reinterpret_cast<const float*>(src3));
                    float32x4_t dest_vec_mad = vld1q_f32(reinterpret_cast<const float*>(dest));
                    uint32x4_t mask_vec_mad = vld1q_u32(mask_mad);
                    
                    // Perform multiply and add operations separately to match the non-NEON implementation
                    // This avoids potential precision differences with fused multiply-add
                    float32x4_t mul_result = vmulq_f32(src1_vec_mad, src2_vec_mad);
                    float32x4_t result_vec_mad = vaddq_f32(mul_result, src3_vec_mad);
                    
                    // Apply mask: use result_vec where mask is set, otherwise use original dest_vec
                    result_vec_mad = vbslq_f32(mask_vec_mad, result_vec_mad, dest_vec_mad);
                    
                    // Store result
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
}

MICROPROFILE_DECLARE(GPU_Shader);

void InterpreterEngine::Run(const ShaderSetup& setup, UnitState& state) const {

    MICROPROFILE_SCOPE(GPU_Shader);

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
