// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <cstdint>
#include <variant>

#include "oaknut/oaknut_exception.hpp"

namespace oaknut {

struct Label;

namespace detail {

constexpr std::uint64_t inverse_mask_from_size(std::size_t size)
{
    return (~std::uint64_t{0}) << size;
}

constexpr std::uint64_t mask_from_size(std::size_t size)
{
    return (~std::uint64_t{0}) >> (64 - size);
}

template<std::size_t bit_count>
constexpr std::uint64_t sign_extend(std::uint64_t value)
{
    static_assert(bit_count != 0, "cannot sign-extend zero-sized value");
    constexpr size_t shift_amount = 64 - bit_count;
    return static_cast<std::uint64_t>(static_cast<std::int64_t>(value << shift_amount) >> shift_amount);
}

}  // namespace detail

template<std::size_t bitsize, std::size_t alignment>
struct AddrOffset {
    AddrOffset(std::ptrdiff_t diff)
        : m_payload(encode(diff))
    {}

    AddrOffset(Label& label)
        : m_payload(&label)
    {}

    AddrOffset(const void* ptr)
        : m_payload(ptr)
    {}

    static std::uint32_t encode(std::ptrdiff_t diff)
    {
        const std::uint64_t diff_u64 = static_cast<std::uint64_t>(diff);
        if (detail::sign_extend<bitsize>(diff_u64) != diff_u64)
            throw OaknutException{ExceptionType::OffsetOutOfRange};
        if (diff_u64 != (diff_u64 & detail::inverse_mask_from_size(alignment)))
            throw OaknutException{ExceptionType::OffsetMisaligned};

        return static_cast<std::uint32_t>((diff_u64 & detail::mask_from_size(bitsize)) >> alignment);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::variant<std::uint32_t, Label*, const void*> m_payload;
};

template<std::size_t bitsize, std::size_t shift_amount>
struct PageOffset {
    PageOffset(const void* ptr)
        : m_payload(ptr)
    {}

    PageOffset(Label& label)
        : m_payload(&label)
    {}

    static std::uint32_t encode(std::uintptr_t current_addr, std::uintptr_t target)
    {
        std::uint64_t diff = static_cast<std::uint64_t>((static_cast<std::int64_t>(target) >> shift_amount) - (static_cast<std::int64_t>(current_addr) >> shift_amount));
        if (detail::sign_extend<bitsize>(diff) != diff)
            throw OaknutException{ExceptionType::OffsetOutOfRange};
        diff &= detail::mask_from_size(bitsize);
        return static_cast<std::uint32_t>(((diff & 3) << (bitsize - 2)) | (diff >> 2));
    }

    static bool valid(std::uintptr_t current_addr, std::uintptr_t target)
    {
        std::uint64_t diff = static_cast<std::uint64_t>((static_cast<std::int64_t>(target) >> shift_amount) - (static_cast<std::int64_t>(current_addr) >> shift_amount));
        return detail::sign_extend<bitsize>(diff) == diff;
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::variant<Label*, const void*> m_payload;
};

template<std::size_t bitsize, std::size_t alignment>
struct SOffset {
    SOffset(std::int64_t offset)
    {
        const std::uint64_t diff_u64 = static_cast<std::uint64_t>(offset);
        if (detail::sign_extend<bitsize>(diff_u64) != diff_u64)
            throw OaknutException{ExceptionType::OffsetOutOfRange};
        if (diff_u64 != (diff_u64 & detail::inverse_mask_from_size(alignment)))
            throw OaknutException{ExceptionType::OffsetMisaligned};

        m_encoded = static_cast<std::uint32_t>((diff_u64 & detail::mask_from_size(bitsize)) >> alignment);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

template<std::size_t bitsize, std::size_t alignment>
struct POffset {
    POffset(std::int64_t offset)
    {
        const std::uint64_t diff_u64 = static_cast<std::uint64_t>(offset);
        if (diff_u64 > detail::mask_from_size(bitsize))
            throw OaknutException{ExceptionType::OffsetOutOfRange};
        if (diff_u64 != (diff_u64 & detail::inverse_mask_from_size(alignment)))
            throw OaknutException{ExceptionType::OffsetMisaligned};

        m_encoded = static_cast<std::uint32_t>((diff_u64 & detail::mask_from_size(bitsize)) >> alignment);
    }

private:
    template<typename Policy>
    friend class BasicCodeGenerator;
    std::uint32_t m_encoded;
};

}  // namespace oaknut
