// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstdint>
#include <optional>

#include <sys/auxv.h>
#include <sys/param.h>

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

#if __FreeBSD_version < 1300114
#    error "Incompatible ABI change (incorrect HWCAP definitions on earlier FreeBSD versions)"
#endif

namespace oaknut {

namespace detail {

inline unsigned long getauxval(int aux)
{
    unsigned long result = 0;
    if (::elf_aux_info(aux, &result, static_cast<int>(sizeof result)) == 0) {
        return result;
    }
    return 0;
}

}  // namespace detail

inline CpuFeatures detect_features_via_hwcap()
{
    const unsigned long hwcap = detail::getauxval(AT_HWCAP);
    const unsigned long hwcap2 = detail::getauxval(AT_HWCAP2);
    return detect_features_via_hwcap(hwcap, hwcap2);
}

inline std::optional<id::IdRegisters> read_id_registers()
{
    // HWCAP_CPUID is falsely not set on many FreeBSD kernel versions,
    // so we don't bother checking it.
    return id::read_id_registers_directly();
}

inline CpuFeatures detect_features()
{
    return detect_features_via_hwcap();
}

}  // namespace oaknut
