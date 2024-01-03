// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: filter src1_/src2_ in arithmetic
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

        bool result_x = flow_control.refx.Value() == state.conditional_code[0];
        bool result_y = flow_control.refy.Value() == state.conditional_code[1];

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
                src1[0] = -src1[0];
                src1[1] = -src1[1];
                src1[2] = -src1[2];
                src1[3] = -src1[3];
            }
            float24 src2[4] = {
                src2_[(int)swizzle.src2_selector_0.Value()],
                src2_[(int)swizzle.src2_selector_1.Value()],
                src2_[(int)swizzle.src2_selector_2.Value()],
                src2_[(int)swizzle.src2_selector_3.Value()],
            };
            if (negate_src2) {
                src2[0] = -src2[0];
                src2[1] = -src2[1];
                src2[2] = -src2[2];
                src2[3] = -src2[3];
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
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] + src2[i];
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::MUL: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] * src2[i];
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::FLR:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = float24::FromFloat32(std::floor(src1[i].ToFloat32()));
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::MAX:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // NOTE: Exact form required to match NaN semantics to hardware:
                    //   max(0, NaN) -> NaN
                    //   max(NaN, 0) -> 0
                    dest[i] = (src1[i] > src2[i]) ? src1[i] : src2[i];
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::MIN:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // NOTE: Exact form required to match NaN semantics to hardware:
                    //   min(0, NaN) -> NaN
                    //   min(NaN, 0) -> 0
                    dest[i] = (src1[i] < src2[i]) ? src1[i] : src2[i];
                }
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
                float24 dot = std::inner_product(src1, src1 + num_components, src2,
                                                 float24::FromFloat32(0.f));

                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = dot;
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            // Reciprocal
            case OpCode::Id::RCP: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                float24 rcp_res = float24::FromFloat32(1.0f / src1[0].ToFloat32());
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = rcp_res;
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            // Reciprocal Square Root
            case OpCode::Id::RSQ: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                float24 rsq_res = float24::FromFloat32(1.0f / std::sqrt(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = rsq_res;
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::MOVA: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                for (int i = 0; i < 2; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    // TODO: Figure out how the rounding is done on hardware
                    state.address_registers[i] = static_cast<s32>(src1[i].ToFloat32());
                }
                Record<DebugDataRecord::ADDR_REG_OUT>(debug_data, iteration,
                                                      state.address_registers);
                break;
            }

            case OpCode::Id::MOV: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i];
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::SGE:
            case OpCode::Id::SGEI:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = (src1[i] >= src2[i]) ? float24::FromFloat32(1.0f)
                                                   : float24::FromFloat32(0.0f);
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::SLT:
            case OpCode::Id::SLTI:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = (src1[i] < src2[i]) ? float24::FromFloat32(1.0f)
                                                  : float24::FromFloat32(0.0f);
                }
                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;

            case OpCode::Id::CMP:
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::SRC2>(debug_data, iteration, src2);
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
                Record<DebugDataRecord::CMP_RESULT>(debug_data, iteration, state.conditional_code);
                break;

            case OpCode::Id::EX2: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);

                // EX2 only takes first component exp2 and writes it to all dest components
                float24 ex2_res = float24::FromFloat32(std::exp2(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = ex2_res;
                }

                Record<DebugDataRecord::DEST_OUT>(debug_data, iteration, dest);
                break;
            }

            case OpCode::Id::LG2: {
                Record<DebugDataRecord::SRC1>(debug_data, iteration, src1);
                Record<DebugDataRecord::DEST_IN>(debug_data, iteration, dest);

                // LG2 only takes the first component log2 and writes it to all dest components
                float24 lg2_res = float24::FromFloat32(std::log2(src1[0].ToFloat32()));
                for (int i = 0; i < 4; ++i) {
                    if (!swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = lg2_res;
                }

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
                    src1[0] = -src1[0];
                    src1[1] = -src1[1];
                    src1[2] = -src1[2];
                    src1[3] = -src1[3];
                }
                float24 src2[4] = {
                    src2_[(int)mad_swizzle.src2_selector_0.Value()],
                    src2_[(int)mad_swizzle.src2_selector_1.Value()],
                    src2_[(int)mad_swizzle.src2_selector_2.Value()],
                    src2_[(int)mad_swizzle.src2_selector_3.Value()],
                };
                if (negate_src2) {
                    src2[0] = -src2[0];
                    src2[1] = -src2[1];
                    src2[2] = -src2[2];
                    src2[3] = -src2[3];
                }
                float24 src3[4] = {
                    src3_[(int)mad_swizzle.src3_selector_0.Value()],
                    src3_[(int)mad_swizzle.src3_selector_1.Value()],
                    src3_[(int)mad_swizzle.src3_selector_2.Value()],
                    src3_[(int)mad_swizzle.src3_selector_3.Value()],
                };
                if (negate_src3) {
                    src3[0] = -src3[0];
                    src3[1] = -src3[1];
                    src3[2] = -src3[2];
                    src3[3] = -src3[3];
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
                for (int i = 0; i < 4; ++i) {
                    if (!mad_swizzle.DestComponentEnabled(i))
                        continue;

                    dest[i] = src1[i] * src2[i] + src3[i];
                }
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
                call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                     program_counter + 1, 0, 0);
                break;

            case OpCode::Id::CALLU:
                Record<DebugDataRecord::COND_BOOL_IN>(
                    debug_data, iteration, uniforms.b[instr.flow_control.bool_uniform_id]);
                if (uniforms.b[instr.flow_control.bool_uniform_id]) {
                    call(instr.flow_control.dest_offset, instr.flow_control.num_instructions,
                         program_counter + 1, 0, 0);
                }
                break;

            case OpCode::Id::CALLC:
                Record<DebugDataRecord::COND_CMP_IN>(debug_data, iteration, state.conditional_code);
                if (evaluate_condition(instr.flow_control)) {
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
                state.address_registers[2] = loop_param.y;

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
