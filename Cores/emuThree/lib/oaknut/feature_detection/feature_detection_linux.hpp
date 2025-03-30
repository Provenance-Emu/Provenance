// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <optional>

#include <sys/auxv.h>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/feature_detection_hwcaps.hpp"
#include "oaknut/feature_detection/id_registers.hpp"
#include "oaknut/feature_detection/read_id_registers_directly.hpp"

#ifndef AT_HWCAP
#    define AT_HWCAP 16
#endif
#ifndef AT_HWCAP2
#    define AT_HWCAP2 26
#endif

namespace oaknut {

inline CpuFeatures detect_features_via_hwcap()
{
    const unsigned long hwcap = ::getauxval(AT_HWCAP);
    const unsigned long hwcap2 = ::getauxval(AT_HWCAP2);
    return detect_features_via_hwcap(hwcap, hwcap2);
}

inline CpuFeatures detect_features()
{
    return detect_features_via_hwcap();
}

inline std::optional<id::IdRegisters> read_id_registers()
{
    constexpr unsigned long hwcap_cpuid = (1 << 11);
    if (::getauxval(AT_HWCAP) & hwcap_cpuid) {
        return id::read_id_registers_directly();
    }
    return std::nullopt;
}

}  // namespace oaknut
