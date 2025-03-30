// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <bit>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <optional>

#include "oaknut/oaknut_exception.hpp"

namespace oaknut {

template<std::size_t bit_size_>
struct Imm {
public:
    static_assert(bit_size_ != 0 && bit_size_ <= 32, "Invalid bit_size");
    static constexpr std::size_t bit_size = bit_size_;
    static constexpr std::uint32_t mask = (1 << bit_size) - 1;

    constexpr /* implicit */ Imm(std::uint32_t value_)
        : m_value(value_)
    {
        if (!is_valid(value_))
            throw OaknutException{ExceptionType::ImmOutOfRange};
    }

    constexpr auto operator<=>(const Imm& other) const { return m_value <=> other.m_value; }
    constexpr auto operator<=>(std::uint32_t other) const { return operator<=>(Imm{other}); }

    constexpr std::uint32_t value() const { return m_value; }

    static bool is_valid(std::uint32_t value_)
    {
        return ((value_ & mask) == value_);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_value;
};

enum class AddSubImmShift {
    SHL_0,
    SHL_12,
};

struct AddSubImm {
public:
    constexpr AddSubImm(std::uint32_t value_, AddSubImmShift shift_)
        : m_encoded(value_ | ((shift_ == AddSubImmShift::SHL_12) ? 1 << 12 : 0))
    {
        if ((value_ & 0xFFF) != value_)
            throw OaknutException{ExceptionType::InvalidAddSubImm};
    }

    constexpr /* implicit */ AddSubImm(std::uint64_t value_)
    {
        if ((value_ & 0xFFF) == value_) {
            m_encoded = static_cast<std::uint32_t>(value_);
        } else if ((value_ & 0xFFF000) == value_) {
            m_encoded = static_cast<std::uint32_t>((value_ >> 12) | (1 << 12));
        } else {
            throw OaknutException{ExceptionType::InvalidAddSubImm};
        }
    }

    static constexpr bool is_valid(std::uint64_t value_)
    {
        return ((value_ & 0xFFF) == value_) || ((value_ & 0xFFF000) == value_);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

enum class MovImm16Shift {
    SHL_0,
    SHL_16,
    SHL_32,
    SHL_48,
};

struct MovImm16 {
public:
    MovImm16(std::uint16_t value_, MovImm16Shift shift_)
        : m_encoded(static_cast<std::uint32_t>(value_) | (static_cast<std::uint32_t>(shift_) << 16))
    {}

    constexpr /* implict */ MovImm16(std::uint64_t value_)
    {
        std::uint32_t shift = 0;
        while (value_ != 0) {
            const std::uint32_t lsw = static_cast<std::uint16_t>(value_ & 0xFFFF);
            if (value_ == lsw) {
                m_encoded = lsw | (shift << 16);
                return;
            } else if (lsw != 0) {
                throw OaknutException{ExceptionType::InvalidMovImm16};
            }
            value_ >>= 16;
            shift++;
        }
    }

    static constexpr bool is_valid(std::uint64_t value_)
    {
        return ((value_ & 0xFFFF) == value_) || ((value_ & 0xFFFF0000) == value_) || ((value_ & 0xFFFF00000000) == value_) || ((value_ & 0xFFFF000000000000) == value_);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded = 0;
};

namespace detail {

constexpr std::optional<std::uint32_t> encode_bit_imm(std::uint64_t value)
{
    if (value == 0 || (~value) == 0)
        return std::nullopt;

    const int rotation = std::countr_zero(value & (value + 1));
    const std::uint64_t rot_value = std::rotr(value, rotation);

    const int esize = std::countr_zero(rot_value & (rot_value + 1));
    const int ones = std::countr_one(rot_value);

    if (std::rotr(value, esize) != value)
        return std::nullopt;

    const int S = ((-esize) << 1) | (ones - 1);
    const int R = (esize - rotation) & (esize - 1);
    const int N = (~S >> 6) & 1;

    return static_cast<std::uint32_t>((S & 0b111111) | (R << 6) | (N << 12));
}

constexpr std::optional<std::uint32_t> encode_bit_imm(std::uint32_t value)
{
    const std::uint64_t value_u64 = (static_cast<std::uint64_t>(value) << 32) | static_cast<std::uint64_t>(value);
    const auto result = encode_bit_imm(value_u64);
    if (result && (*result & 0b0'111111'111111) != *result)
        return std::nullopt;
    return result;
}

}  // namespace detail

struct BitImm32 {
public:
    constexpr BitImm32(Imm<6> imms, Imm<6> immr)
        : m_encoded((imms.value() << 6) | immr.value())
    {}

    constexpr /* implicit */ BitImm32(std::uint32_t value)
    {
        const auto encoded = detail::encode_bit_imm(value);
        if (!encoded || (*encoded & 0x1000) != 0)
            throw OaknutException{ExceptionType::InvalidBitImm32};
        m_encoded = *encoded;
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

struct BitImm64 {
public:
    constexpr BitImm64(bool N, Imm<6> imms, Imm<6> immr)
        : m_encoded((N ? 1 << 12 : 0) | (imms.value() << 6) | immr.value())
    {}

    constexpr /* implicit */ BitImm64(std::uint64_t value)
    {
        const auto encoded = detail::encode_bit_imm(value);
        if (!encoded)
            throw OaknutException{ExceptionType::InvalidBitImm64};
        m_encoded = *encoded;
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

struct FImm8 {
public:
    constexpr explicit FImm8(std::uint8_t encoded)
        : m_encoded(encoded)
    {}

    constexpr FImm8(bool sign, Imm<3> exp, Imm<4> mantissa)
        : m_encoded((sign ? 1 << 7 : 0) | (exp.value() << 4) | (mantissa.value()))
    {}

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

struct RepImm {
public:
    constexpr explicit RepImm(std::uint8_t encoded)
        : m_encoded(encoded)
    {}

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

template<int A>
struct ImmConst {
    constexpr /* implicit */ ImmConst(int value)
    {
        if (value != A) {
            throw OaknutException{ExceptionType::InvalidImmConst};
        }
    }
};

struct ImmConstFZero {
    constexpr /* implicit */ ImmConstFZero(double value)
    {
        if (value != 0) {
            throw OaknutException{ExceptionType::InvalidImmConstFZero};
        }
    }
};

template<int...>
struct ImmChoice;

template<int A, int B>
struct ImmChoice<A, B> {
    constexpr /* implicit */ ImmChoice(int value)
    {
        if (value == A) {
            m_encoded = 0;
        } else if (value == B) {
            m_encoded = 1;
        } else {
            throw OaknutException{ExceptionType::InvalidImmChoice};
        }
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

template<int A, int B, int C, int D>
struct ImmChoice<A, B, C, D> {
    constexpr /* implicit */ ImmChoice(int value)
    {
        if (value == A) {
            m_encoded = 0;
        } else if (value == B) {
            m_encoded = 1;
        } else if (value == C) {
            m_encoded = 2;
        } else if (value == D) {
            m_encoded = 3;
        } else {
            throw OaknutException{ExceptionType::InvalidImmChoice};
        }
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

template<unsigned Start, unsigned End>
struct ImmRange {
    constexpr /* implicit */ ImmRange(unsigned value_)
        : m_value(value_)
    {
        if (value_ < Start || value_ > End) {
            throw OaknutException{ExceptionType::InvalidImmRange};
        }
    }

    constexpr unsigned value() const { return m_value; }

private:
    unsigned m_value;
};

template<std::size_t max_value>
struct LslShift {
    constexpr /* implicit */ LslShift(std::size_t amount)
        : m_encoded((((-amount) & (max_value - 1)) << 6) | (max_value - amount - 1))
    {
        if (amount >= max_value)
            throw OaknutException{ExceptionType::LslShiftOutOfRange};
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

}  // namespace oaknut
