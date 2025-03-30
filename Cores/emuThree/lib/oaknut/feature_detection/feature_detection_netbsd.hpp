// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>

#include <aarch64/armreg.h>
#include <sys/param.h>
#include <sys/sysctl.h>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/feature_detection_hwcaps.hpp"
#include "oaknut/feature_detection/feature_detection_idregs.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

inline std::optional<id::IdRegisters> read_id_registers(std::size_t core_index)
{
    const std::string path = "machdep.cpu" + std::to_string(core_index) + ".cpu_id";

    aarch64_sysctl_cpu_id id;
    std::size_t id_len = sizeof id;

    if (sysctlbyname(path.c_str(), &id, &id_len, nullptr, 0) < 0)
        return std::nullopt;

    return id::IdRegisters{
        id.ac_midr,
        id::Pfr0Register{id.ac_aa64pfr0},
        id::Pfr1Register{id.ac_aa64pfr1},
        id::Pfr2Register{0},
        id::Zfr0Register{id.ac_aa64zfr0},
        id::Smfr0Register{0},
        id::Isar0Register{id.ac_aa64isar0},
        id::Isar1Register{id.ac_aa64isar1},
        id::Isar2Register{0},
        id::Isar3Register{0},
        id::Mmfr0Register{id.ac_aa64mmfr0},
        id::Mmfr1Register{id.ac_aa64mmfr1},
        id::Mmfr2Register{id.ac_aa64mmfr2},
        id::Mmfr3Register{0},
        id::Mmfr4Register{0},
    };
}

inline std::size_t get_core_count()
{
    int result = 0;
    size_t result_size = sizeof(result);
    const std::array<int, 2> mib{CTL_HW, HW_NCPU};
    if (sysctl(mib.data(), mib.size(), &result, &result_size, nullptr, 0) < 0)
        return 0;
    return result;
}

inline CpuFeatures detect_features()
{
    std::optional<CpuFeatures> result;

    const std::size_t core_count = get_core_count();
    for (std::size_t core_index = 0; core_index < core_count; core_index++) {
        if (const std::optional<id::IdRegisters> id_regs = read_id_registers(core_index)) {
            const CpuFeatures current_features = detect_features_via_id_registers(*id_regs);
            if (result) {
                result = *result & current_features;
            } else {
                result = current_features;
            }
        }
    }

    return result.value_or(CpuFeatures{});
}

}  // namespace oaknut
