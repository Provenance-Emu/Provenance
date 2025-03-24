// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <optional>

#include <processthreadsapi.h>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

namespace detail {

inline std::optional<std::uint64_t> read_registry_hklm(const std::string& subkey, const std::string& name)
{
    std::uint64_t value;
    DWORD value_len = sizeof(value);
    if (::RegGetValueA(HKEY_LOCAL_MACHINE, subkey.c_str(), name.c_str(), RRF_RT_REG_QWORD, nullptr, &value, &value_len) == ERROR_SUCCESS) {
        return value;
    }
    return std::nullopt;
}

inline std::uint64_t read_id_register(std::size_t core_index, const std::string& name)
{
    return read_registry_hklm("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\" + std::to_string(core_index), "CP " + name).value_or(0);
}

}  // namespace detail

// Ref: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-isprocessorfeaturepresent

inline CpuFeatures detect_features_via_IsProcessorFeaturePresent()
{
    CpuFeatures result;

    if (::IsProcessorFeaturePresent(30))  // PF_ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::AES, CpuFeature::PMULL, CpuFeature::SHA1, CpuFeature::SHA256};
    if (::IsProcessorFeaturePresent(31))  // PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::CRC32};
    if (::IsProcessorFeaturePresent(34))  // PF_ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::LSE};
    if (::IsProcessorFeaturePresent(43))  // PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::DotProd};
    if (::IsProcessorFeaturePresent(44))  // PF_ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::JSCVT};
    if (::IsProcessorFeaturePresent(45))  // PF_ARM_V83_LRCPC_INSTRUCTIONS_AVAILABLE
        result |= CpuFeatures{CpuFeature::LRCPC};

    return result;
}

inline CpuFeatures detect_features()
{
    CpuFeatures result{CpuFeature::FP, CpuFeature::ASIMD};
    result |= detect_features_via_IsProcessorFeaturePresent();
    return result;
}

inline std::size_t get_core_count()
{
    ::SYSTEM_INFO sys_info;
    ::GetSystemInfo(&sys_info);
    return sys_info.dwNumberOfProcessors;
}

inline std::optional<id::IdRegisters> read_id_registers(std::size_t core_index)
{
    return id::IdRegisters{
        detail::read_id_register(core_index, "4000"),
        id::Pfr0Register{detail::read_id_register(core_index, "4020")},
        id::Pfr1Register{detail::read_id_register(core_index, "4021")},
        id::Pfr2Register{detail::read_id_register(core_index, "4022")},
        id::Zfr0Register{detail::read_id_register(core_index, "4024")},
        id::Smfr0Register{detail::read_id_register(core_index, "4025")},
        id::Isar0Register{detail::read_id_register(core_index, "4030")},
        id::Isar1Register{detail::read_id_register(core_index, "4031")},
        id::Isar2Register{detail::read_id_register(core_index, "4032")},
        id::Isar3Register{detail::read_id_register(core_index, "4033")},
        id::Mmfr0Register{detail::read_id_register(core_index, "4038")},
        id::Mmfr1Register{detail::read_id_register(core_index, "4039")},
        id::Mmfr2Register{detail::read_id_register(core_index, "403A")},
        id::Mmfr3Register{detail::read_id_register(core_index, "403B")},
        id::Mmfr4Register{detail::read_id_register(core_index, "403C")},
    };
}

}  // namespace oaknut
