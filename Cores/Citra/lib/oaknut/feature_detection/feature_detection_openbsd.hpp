// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>

#include <sys/sysctl.h>
#include <sys/types.h>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/feature_detection_hwcaps.hpp"
#include "oaknut/feature_detection/feature_detection_idregs.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

namespace detail {

inline std::uint64_t read_id_register(int index)
{
    uint64_t result = 0;
    size_t result_size = sizeof(result);
    std::array<int, 2> mib{CTL_MACHDEP, index};
    if (sysctl(mib.data(), mib.size(), &result, &result_size, nullptr, 0) < 0)
        return 0;
    return result;
}

}  // namespace detail

inline std::optional<id::IdRegisters> read_id_registers()
{
    // See OpenBSD source: sys/arch/arm64/include/cpu.h

    return id::IdRegisters{
        std::nullopt,                                   // No easy way of getting MIDR_EL1 other than reading /proc/cpu
        id::Pfr0Register{detail::read_id_register(8)},  // CPU_ID_AA64PFR0
        id::Pfr1Register{detail::read_id_register(9)},  // CPU_ID_AA64PFR1
        id::Pfr2Register{0},
        id::Zfr0Register{detail::read_id_register(11)},   // CPU_ID_AA64ZFR0
        id::Smfr0Register{detail::read_id_register(10)},  // CPU_ID_AA64SMFR0
        id::Isar0Register{detail::read_id_register(2)},   // CPU_ID_AA64ISAR0
        id::Isar1Register{detail::read_id_register(3)},   // CPU_ID_AA64ISAR1
        id::Isar2Register{detail::read_id_register(4)},   // CPU_ID_AA64ISAR2
        id::Isar3Register{0},
        id::Mmfr0Register{detail::read_id_register(5)},  // CPU_ID_AA64MMFR0
        id::Mmfr1Register{detail::read_id_register(6)},  // CPU_ID_AA64MMFR1
        id::Mmfr2Register{detail::read_id_register(7)},  // CPU_ID_AA64MMFR2
        id::Mmfr3Register{0},
        id::Mmfr4Register{0},
    };
}

inline CpuFeatures detect_features()
{
    return detect_features_via_id_registers(*read_id_registers());
}

}  // namespace oaknut
