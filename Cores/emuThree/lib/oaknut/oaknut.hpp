// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <bit>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <tuple>
#include <type_traits>
#include <variant>
#include <vector>

#include "oaknut/impl/enum.hpp"
#include "oaknut/impl/imm.hpp"
#include "oaknut/impl/list.hpp"
#include "oaknut/impl/multi_typed_name.hpp"
#include "oaknut/impl/offset.hpp"
#include "oaknut/impl/overloaded.hpp"
#include "oaknut/impl/reg.hpp"
#include "oaknut/impl/string_literal.hpp"
#include "oaknut/oaknut_exception.hpp"

namespace oaknut {

struct Label {
public:
    Label() = default;

    bool is_bound() const
    {
        return m_offset.has_value();
    }

    std::ptrdiff_t offset() const
    {
        return m_offset.value();
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;

    explicit Label(std::ptrdiff_t offset)
        : m_offset(offset)
    {}

    using EmitFunctionType = std::uint32_t (*)(std::ptrdiff_t wb_offset, std::ptrdiff_t resolved_offset);

    struct Writeback {
        std::ptrdiff_t m_wb_offset;
        std::uint32_t m_mask;
        EmitFunctionType m_fn;
    };

    std::optional<std::ptrdiff_t> m_offset;
    std::vector<Writeback> m_wbs;
};

template<typename Policy>
class BasicCodeGenerator : public Policy {
public:
    BasicCodeGenerator(typename Policy::constructor_argument_type arg, std::uint32_t* xmem)
        : Policy(arg, xmem)
    {}

    Label l() const
    {
        return Label{Policy::offset()};
    }

    void l(Label& label) const
    {
        if (label.is_bound())
            throw OaknutException{ExceptionType::LabelRedefinition};

        const auto target_offset = Policy::offset();
        label.m_offset = target_offset;
        for (auto& wb : label.m_wbs) {
            const std::uint32_t value = wb.m_fn(wb.m_wb_offset, target_offset);
            Policy::set_at_offset(wb.m_wb_offset, value, wb.m_mask);
        }
        label.m_wbs.clear();
    }

#include "oaknut/impl/mnemonics_fpsimd_v8.0.inc.hpp"
#include "oaknut/impl/mnemonics_fpsimd_v8.1.inc.hpp"
#include "oaknut/impl/mnemonics_fpsimd_v8.2.inc.hpp"
#include "oaknut/impl/mnemonics_generic_v8.0.inc.hpp"
#include "oaknut/impl/mnemonics_generic_v8.1.inc.hpp"
#include "oaknut/impl/mnemonics_generic_v8.2.inc.hpp"

    void RET()
    {
        return RET(XReg{30});
    }

    void ADRL(XReg xd, const void* addr)
    {
        ADRP(xd, addr);
        ADD(xd, xd, reinterpret_cast<uint64_t>(addr) & 0xFFF);
    }

    void MOV(WReg wd, uint32_t imm)
    {
        if (wd.index() == 31)
            return;
        if (MovImm16::is_valid(imm))
            return MOVZ(wd, imm);
        if (MovImm16::is_valid(static_cast<std::uint32_t>(~imm)))
            return MOVN(wd, static_cast<std::uint32_t>(~imm));
        if (detail::encode_bit_imm(imm))
            return ORR(wd, WzrReg{}, imm);

        MOVZ(wd, {static_cast<std::uint16_t>(imm >> 0), MovImm16Shift::SHL_0});
        MOVK(wd, {static_cast<std::uint16_t>(imm >> 16), MovImm16Shift::SHL_16});
    }

    void MOV(XReg xd, uint64_t imm)
    {
        if (xd.index() == 31)
            return;
        if (imm >> 32 == 0)
            return MOV(xd.toW(), static_cast<std::uint32_t>(imm));
        if (MovImm16::is_valid(imm))
            return MOVZ(xd, imm);
        if (MovImm16::is_valid(~imm))
            return MOVN(xd, ~imm);
        if (detail::encode_bit_imm(imm))
            return ORR(xd, ZrReg{}, imm);

        bool movz_done = false;
        int shift_count = 0;

        if (detail::encode_bit_imm(static_cast<std::uint32_t>(imm))) {
            ORR(xd.toW(), WzrReg{}, static_cast<std::uint32_t>(imm));
            imm >>= 32;
            movz_done = true;
            shift_count = 2;
        }

        while (imm != 0) {
            const uint16_t hw = static_cast<uint16_t>(imm);
            if (hw != 0) {
                if (movz_done) {
                    MOVK(xd, {hw, static_cast<MovImm16Shift>(shift_count)});
                } else {
                    MOVZ(xd, {hw, static_cast<MovImm16Shift>(shift_count)});
                    movz_done = true;
                }
            }
            imm >>= 16;
            shift_count++;
        }
    }

    // Convenience function for moving pointers to registers
    void MOVP2R(XReg xd, const void* addr)
    {
        const int64_t diff = reinterpret_cast<std::uint64_t>(addr) - Policy::template xptr<std::uintptr_t>();
        if (diff >= -0xF'FFFF && diff <= 0xF'FFFF) {
            ADR(xd, addr);
        } else if (PageOffset<21, 12>::valid(Policy::template xptr<std::uintptr_t>(), reinterpret_cast<std::uintptr_t>(addr))) {
            ADRL(xd, addr);
        } else {
            MOV(xd, reinterpret_cast<uint64_t>(addr));
        }
    }

    void align(std::size_t alignment)
    {
        if (alignment < 4 || (alignment & (alignment - 1)) != 0)
            throw OaknutException{ExceptionType::InvalidAlignment};

        while (Policy::offset() & (alignment - 1)) {
            NOP();
        }
    }

    void dw(std::uint32_t value)
    {
        Policy::append(value);
    }

    void dx(std::uint64_t value)
    {
        Policy::append(static_cast<std::uint32_t>(value));
        Policy::append(static_cast<std::uint32_t>(value >> 32));
    }

private:
#include "oaknut/impl/arm64_encode_helpers.inc.hpp"

    template<StringLiteral bs, StringLiteral... bargs, typename... Ts>
    void emit(Ts... args)
    {
        constexpr std::uint32_t base = detail::find<bs, "1">();
        std::uint32_t encoding = (base | ... | encode<detail::find<bs, bargs>()>(std::forward<Ts>(args)));
        Policy::append(encoding);
    }
};

struct PointerCodeGeneratorPolicy {
public:
    std::ptrdiff_t offset() const
    {
        return (m_ptr - m_wmem) * sizeof(std::uint32_t);
    }

    void set_offset(std::ptrdiff_t offset)
    {
        if ((offset % sizeof(std::uint32_t)) != 0)
            throw OaknutException{ExceptionType::InvalidAlignment};
        m_ptr = m_wmem + offset / sizeof(std::uint32_t);
    }

    template<typename T>
    T wptr() const
    {
        static_assert(std::is_pointer_v<T> || std::is_same_v<T, std::uintptr_t> || std::is_same_v<T, std::intptr_t>);
        return reinterpret_cast<T>(m_ptr);
    }

    template<typename T>
    T xptr() const
    {
        static_assert(std::is_pointer_v<T> || std::is_same_v<T, std::uintptr_t> || std::is_same_v<T, std::intptr_t>);
        return reinterpret_cast<T>(m_xmem + (m_ptr - m_wmem));
    }

    void set_wptr(std::uint32_t* p)
    {
        m_ptr = p;
    }

    void set_xptr(std::uint32_t* p)
    {
        m_ptr = m_wmem + (p - m_xmem);
    }

protected:
    using constructor_argument_type = std::uint32_t*;

    PointerCodeGeneratorPolicy(std::uint32_t* wmem, std::uint32_t* xmem)
        : m_ptr(wmem), m_wmem(wmem), m_xmem(xmem)
    {}

    void append(std::uint32_t instruction)
    {
        *m_ptr++ = instruction;
    }

    void set_at_offset(std::ptrdiff_t offset, std::uint32_t value, std::uint32_t mask) const
    {
        std::uint32_t* p = m_wmem + offset / sizeof(std::uint32_t);
        *p = (*p & mask) | value;
    }

private:
    std::uint32_t* m_ptr;
    std::uint32_t* const m_wmem;
    std::uint32_t* const m_xmem;
};

struct VectorCodeGeneratorPolicy {
public:
    std::ptrdiff_t offset() const
    {
        return m_vec.size() * sizeof(std::uint32_t);
    }

    template<typename T>
    T xptr() const
    {
        static_assert(std::is_pointer_v<T> || std::is_same_v<T, std::uintptr_t> || std::is_same_v<T, std::intptr_t>);
        return reinterpret_cast<T>(m_xmem + m_vec.size());
    }

protected:
    using constructor_argument_type = std::vector<std::uint32_t>&;

    VectorCodeGeneratorPolicy(std::vector<std::uint32_t>& vec, std::uint32_t* xmem)
        : m_vec(vec), m_xmem(xmem)
    {}

    void append(std::uint32_t instruction)
    {
        m_vec.push_back(instruction);
    }

    void set_at_offset(std::ptrdiff_t offset, std::uint32_t value, std::uint32_t mask) const
    {
        std::uint32_t& p = m_vec[offset / sizeof(std::uint32_t)];
        p = (p & mask) | value;
    }

private:
    std::vector<std::uint32_t>& m_vec;
    std::uint32_t* const m_xmem;
};

struct CodeGenerator : BasicCodeGenerator<PointerCodeGeneratorPolicy> {
public:
    CodeGenerator(std::uint32_t* mem)
        : BasicCodeGenerator<PointerCodeGeneratorPolicy>(mem, mem) {}
    CodeGenerator(std::uint32_t* wmem, std::uint32_t* xmem)
        : BasicCodeGenerator<PointerCodeGeneratorPolicy>(wmem, xmem) {}
};

struct VectorCodeGenerator : BasicCodeGenerator<VectorCodeGeneratorPolicy> {
public:
    VectorCodeGenerator(std::vector<std::uint32_t>& mem)
        : BasicCodeGenerator<VectorCodeGeneratorPolicy>(mem, nullptr) {}
    VectorCodeGenerator(std::vector<std::uint32_t>& wmem, std::uint32_t* xmem)
        : BasicCodeGenerator<VectorCodeGeneratorPolicy>(wmem, xmem) {}
};

namespace util {

inline constexpr WReg W0{0}, W1{1}, W2{2}, W3{3}, W4{4}, W5{5}, W6{6}, W7{7}, W8{8}, W9{9}, W10{10}, W11{11}, W12{12}, W13{13}, W14{14}, W15{15}, W16{16}, W17{17}, W18{18}, W19{19}, W20{20}, W21{21}, W22{22}, W23{23}, W24{24}, W25{25}, W26{26}, W27{27}, W28{28}, W29{29}, W30{30};
inline constexpr XReg X0{0}, X1{1}, X2{2}, X3{3}, X4{4}, X5{5}, X6{6}, X7{7}, X8{8}, X9{9}, X10{10}, X11{11}, X12{12}, X13{13}, X14{14}, X15{15}, X16{16}, X17{17}, X18{18}, X19{19}, X20{20}, X21{21}, X22{22}, X23{23}, X24{24}, X25{25}, X26{26}, X27{27}, X28{28}, X29{29}, X30{30};
inline constexpr ZrReg ZR{}, XZR{};
inline constexpr WzrReg WZR{};
inline constexpr SpReg SP{}, XSP{};
inline constexpr WspReg WSP{};

inline constexpr VRegSelector V0{0}, V1{1}, V2{2}, V3{3}, V4{4}, V5{5}, V6{6}, V7{7}, V8{8}, V9{9}, V10{10}, V11{11}, V12{12}, V13{13}, V14{14}, V15{15}, V16{16}, V17{17}, V18{18}, V19{19}, V20{20}, V21{21}, V22{22}, V23{23}, V24{24}, V25{25}, V26{26}, V27{27}, V28{28}, V29{29}, V30{30}, V31{31};
inline constexpr QReg Q0{0}, Q1{1}, Q2{2}, Q3{3}, Q4{4}, Q5{5}, Q6{6}, Q7{7}, Q8{8}, Q9{9}, Q10{10}, Q11{11}, Q12{12}, Q13{13}, Q14{14}, Q15{15}, Q16{16}, Q17{17}, Q18{18}, Q19{19}, Q20{20}, Q21{21}, Q22{22}, Q23{23}, Q24{24}, Q25{25}, Q26{26}, Q27{27}, Q28{28}, Q29{29}, Q30{30}, Q31{31};
inline constexpr DReg D0{0}, D1{1}, D2{2}, D3{3}, D4{4}, D5{5}, D6{6}, D7{7}, D8{8}, D9{9}, D10{10}, D11{11}, D12{12}, D13{13}, D14{14}, D15{15}, D16{16}, D17{17}, D18{18}, D19{19}, D20{20}, D21{21}, D22{22}, D23{23}, D24{24}, D25{25}, D26{26}, D27{27}, D28{28}, D29{29}, D30{30}, D31{31};
inline constexpr SReg S0{0}, S1{1}, S2{2}, S3{3}, S4{4}, S5{5}, S6{6}, S7{7}, S8{8}, S9{9}, S10{10}, S11{11}, S12{12}, S13{13}, S14{14}, S15{15}, S16{16}, S17{17}, S18{18}, S19{19}, S20{20}, S21{21}, S22{22}, S23{23}, S24{24}, S25{25}, S26{26}, S27{27}, S28{28}, S29{29}, S30{30}, S31{31};
inline constexpr HReg H0{0}, H1{1}, H2{2}, H3{3}, H4{4}, H5{5}, H6{6}, H7{7}, H8{8}, H9{9}, H10{10}, H11{11}, H12{12}, H13{13}, H14{14}, H15{15}, H16{16}, H17{17}, H18{18}, H19{19}, H20{20}, H21{21}, H22{22}, H23{23}, H24{24}, H25{25}, H26{26}, H27{27}, H28{28}, H29{29}, H30{30}, H31{31};
inline constexpr BReg B0{0}, B1{1}, B2{2}, B3{3}, B4{4}, B5{5}, B6{6}, B7{7}, B8{8}, B9{9}, B10{10}, B11{11}, B12{12}, B13{13}, B14{14}, B15{15}, B16{16}, B17{17}, B18{18}, B19{19}, B20{20}, B21{21}, B22{22}, B23{23}, B24{24}, B25{25}, B26{26}, B27{27}, B28{28}, B29{29}, B30{30}, B31{31};

inline constexpr Cond EQ{Cond::EQ}, NE{Cond::NE}, CS{Cond::CS}, CC{Cond::CC}, MI{Cond::MI}, PL{Cond::PL}, VS{Cond::VS}, VC{Cond::VC}, HI{Cond::HI}, LS{Cond::LS}, GE{Cond::GE}, LT{Cond::LT}, GT{Cond::GT}, LE{Cond::LE}, AL{Cond::AL}, NV{Cond::NV}, HS{Cond::HS}, LO{Cond::LO};

inline constexpr auto UXTB{MultiTypedName<AddSubExt::UXTB>{}};
inline constexpr auto UXTH{MultiTypedName<AddSubExt::UXTH>{}};
inline constexpr auto UXTW{MultiTypedName<AddSubExt::UXTW, IndexExt::UXTW>{}};
inline constexpr auto UXTX{MultiTypedName<AddSubExt::UXTX>{}};
inline constexpr auto SXTB{MultiTypedName<AddSubExt::SXTB>{}};
inline constexpr auto SXTH{MultiTypedName<AddSubExt::SXTH>{}};
inline constexpr auto SXTW{MultiTypedName<AddSubExt::SXTW, IndexExt::SXTW>{}};
inline constexpr auto SXTX{MultiTypedName<AddSubExt::SXTX, IndexExt::SXTX>{}};
inline constexpr auto LSL{MultiTypedName<AddSubExt::LSL, IndexExt::LSL, AddSubShift::LSL, LogShift::LSL, LslSymbol::LSL>{}};
inline constexpr auto LSR{MultiTypedName<AddSubShift::LSR, LogShift::LSR>{}};
inline constexpr auto ASR{MultiTypedName<AddSubShift::ASR, LogShift::ASR>{}};
inline constexpr auto ROR{MultiTypedName<LogShift::ROR>{}};

inline constexpr PostIndexed POST_INDEXED{};
inline constexpr PreIndexed PRE_INDEXED{};
inline constexpr MslSymbol MSL{MslSymbol::MSL};

}  // namespace util

}  // namespace oaknut
