// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <algorithm>
#include <cstddef>

namespace oaknut {

template<size_t N>
struct StringLiteral {
    constexpr StringLiteral(const char (&str)[N])
    {
        std::copy_n(str, N, value);
    }

    static constexpr std::size_t strlen = N - 1;
    static constexpr std::size_t size = N;

    char value[N];
};

namespace detail {

template<StringLiteral<33> haystack, StringLiteral needles>
consteval std::uint32_t find()
{
    std::uint32_t result = 0;
    for (std::size_t i = 0; i < 32; i++) {
        for (std::size_t a = 0; a < needles.strlen; a++) {
            if (haystack.value[i] == needles.value[a]) {
                result |= 1 << (31 - i);
            }
        }
    }
    return result;
}

}  // namespace detail

}  // namespace oaknut
