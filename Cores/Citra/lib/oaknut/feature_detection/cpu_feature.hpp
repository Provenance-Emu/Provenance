// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <bitset>
#include <cstddef>
#include <initializer_list>

#if defined(__cpp_lib_constexpr_bitset) && __cpp_lib_constexpr_bitset >= 202207L
#    define OAKNUT_CPU_FEATURES_CONSTEXPR constexpr
#else
#    define OAKNUT_CPU_FEATURES_CONSTEXPR
#endif

namespace oaknut {

// NOTE: This file contains code that can be compiled on non-arm64 systems.
//       For run-time CPU feature detection, include feature_detection.hpp

enum class CpuFeature {
#define OAKNUT_CPU_FEATURE(name) name,
#include "oaknut/impl/cpu_feature.inc.hpp"
#undef OAKNUT_CPU_FEATURE
};

constexpr std::size_t cpu_feature_count = 0
#define OAKNUT_CPU_FEATURE(name) +1
#include "oaknut/impl/cpu_feature.inc.hpp"
#undef OAKNUT_CPU_FEATURE
    ;

class CpuFeatures final {
public:
    constexpr CpuFeatures() = default;

    OAKNUT_CPU_FEATURES_CONSTEXPR explicit CpuFeatures(std::initializer_list<CpuFeature> features)
    {
        for (CpuFeature f : features) {
            m_bitset.set(static_cast<std::size_t>(f));
        }
    }

    constexpr bool has(CpuFeature feature) const
    {
        if (static_cast<std::size_t>(feature) >= cpu_feature_count)
            return false;
        return m_bitset[static_cast<std::size_t>(feature)];
    }

    OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures& operator&=(const CpuFeatures& other) noexcept
    {
        m_bitset &= other.m_bitset;
        return *this;
    }

    OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures& operator|=(const CpuFeatures& other) noexcept
    {
        m_bitset |= other.m_bitset;
        return *this;
    }

    OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures& operator^=(const CpuFeatures& other) noexcept
    {
        m_bitset ^= other.m_bitset;
        return *this;
    }

    OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator~() const noexcept
    {
        CpuFeatures result;
        result.m_bitset = ~m_bitset;
        return result;
    }

private:
    using bitset = std::bitset<cpu_feature_count>;

    friend OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator&(const CpuFeatures& a, const CpuFeatures& b) noexcept;
    friend OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator|(const CpuFeatures& a, const CpuFeatures& b) noexcept;
    friend OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator^(const CpuFeatures& a, const CpuFeatures& b) noexcept;

    bitset m_bitset;
};

OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator&(const CpuFeatures& a, const CpuFeatures& b) noexcept
{
    CpuFeatures result;
    result.m_bitset = a.m_bitset & b.m_bitset;
    return result;
}

OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator|(const CpuFeatures& a, const CpuFeatures& b) noexcept
{
    CpuFeatures result;
    result.m_bitset = a.m_bitset | b.m_bitset;
    return result;
}

OAKNUT_CPU_FEATURES_CONSTEXPR CpuFeatures operator^(const CpuFeatures& a, const CpuFeatures& b) noexcept
{
    CpuFeatures result;
    result.m_bitset = a.m_bitset ^ b.m_bitset;
    return result;
}

}  // namespace oaknut
