// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <optional>

#include <sys/sysctl.h>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

// Ref: https://developer.apple.com/documentation/kernel/1387446-sysctlbyname/determining_instruction_set_characteristics

namespace detail {

inline bool detect_feature(const char* const sysctl_name)
{
    int result = 0;
    std::size_t result_size = sizeof(result);
    if (::sysctlbyname(sysctl_name, &result, &result_size, nullptr, 0) == 0) {
        return result != 0;
    }
    return false;
}

}  // namespace detail

inline CpuFeatures detect_features_via_sysctlbyname()
{
    CpuFeatures result;

    if (detail::detect_feature("hw.optional.AdvSIMD") || detail::detect_feature("hw.optional.neon"))
        result |= CpuFeatures{CpuFeature::ASIMD};
    if (detail::detect_feature("hw.optional.floatingpoint"))
        result |= CpuFeatures{CpuFeature::FP};
    if (detail::detect_feature("hw.optional.AdvSIMD_HPFPCvt") || detail::detect_feature("hw.optional.neon_hpfp"))
        result |= CpuFeatures{CpuFeature::FP16Conv};
    if (detail::detect_feature("hw.optional.arm.FEAT_BF16"))
        result |= CpuFeatures{CpuFeature::BF16};
    if (detail::detect_feature("hw.optional.arm.FEAT_DotProd"))
        result |= CpuFeatures{CpuFeature::DotProd};
    if (detail::detect_feature("hw.optional.arm.FEAT_FCMA") || detail::detect_feature("hw.optional.armv8_3_compnum"))
        result |= CpuFeatures{CpuFeature::FCMA};
    if (detail::detect_feature("hw.optional.arm.FEAT_FHM") || detail::detect_feature("hw.optional.armv8_2_fhm"))
        result |= CpuFeatures{CpuFeature::FHM};
    if (detail::detect_feature("hw.optional.arm.FEAT_FP16") || detail::detect_feature("hw.optional.neon_fp16"))
        result |= CpuFeatures{CpuFeature::FP16};
    if (detail::detect_feature("hw.optional.arm.FEAT_FRINTTS"))
        result |= CpuFeatures{CpuFeature::FRINTTS};
    if (detail::detect_feature("hw.optional.arm.FEAT_I8MM"))
        result |= CpuFeatures{CpuFeature::I8MM};
    if (detail::detect_feature("hw.optional.arm.FEAT_JSCVT"))
        result |= CpuFeatures{CpuFeature::JSCVT};
    if (detail::detect_feature("hw.optional.arm.FEAT_RDM"))
        result |= CpuFeatures{CpuFeature::RDM};
    if (detail::detect_feature("hw.optional.arm.FEAT_FlagM"))
        result |= CpuFeatures{CpuFeature::FlagM};
    if (detail::detect_feature("hw.optional.arm.FEAT_FlagM2"))
        result |= CpuFeatures{CpuFeature::FlagM2};
    if (detail::detect_feature("hw.optional.armv8_crc32"))
        result |= CpuFeatures{CpuFeature::CRC32};
    if (detail::detect_feature("hw.optional.arm.FEAT_LRCPC"))
        result |= CpuFeatures{CpuFeature::LRCPC};
    if (detail::detect_feature("hw.optional.arm.FEAT_LRCPC2"))
        result |= CpuFeatures{CpuFeature::LRCPC2};
    if (detail::detect_feature("hw.optional.arm.FEAT_LSE") || detail::detect_feature("hw.optional.armv8_1_atomics"))
        result |= CpuFeatures{CpuFeature::LSE};
    if (detail::detect_feature("hw.optional.arm.FEAT_LSE2"))
        result |= CpuFeatures{CpuFeature::LSE2};
    if (detail::detect_feature("hw.optional.arm.FEAT_AES"))
        result |= CpuFeatures{CpuFeature::AES};
    if (detail::detect_feature("hw.optional.arm.FEAT_PMULL"))
        result |= CpuFeatures{CpuFeature::PMULL};
    if (detail::detect_feature("hw.optional.arm.FEAT_SHA1"))
        result |= CpuFeatures{CpuFeature::SHA1};
    if (detail::detect_feature("hw.optional.arm.FEAT_SHA256"))
        result |= CpuFeatures{CpuFeature::SHA256};
    if (detail::detect_feature("hw.optional.arm.FEAT_SHA512") || detail::detect_feature("hw.optional.armv8_2_sha512"))
        result |= CpuFeatures{CpuFeature::SHA512};
    if (detail::detect_feature("hw.optional.arm.FEAT_SHA3") || detail::detect_feature("hw.optional.armv8_2_sha3"))
        result |= CpuFeatures{CpuFeature::SHA3};
    if (detail::detect_feature("hw.optional.arm.FEAT_BTI"))
        result |= CpuFeatures{CpuFeature::BTI};
    if (detail::detect_feature("hw.optional.arm.FEAT_DPB"))
        result |= CpuFeatures{CpuFeature::DPB};
    if (detail::detect_feature("hw.optional.arm.FEAT_DPB2"))
        result |= CpuFeatures{CpuFeature::DPB2};
    if (detail::detect_feature("hw.optional.arm.FEAT_ECV"))
        result |= CpuFeatures{CpuFeature::ECV};
    if (detail::detect_feature("hw.optional.arm.FEAT_SB"))
        result |= CpuFeatures{CpuFeature::SB};
    if (detail::detect_feature("hw.optional.arm.FEAT_SSBS"))
        result |= CpuFeatures{CpuFeature::SSBS};

    return result;
}

inline CpuFeatures detect_features()
{
    return detect_features_via_sysctlbyname();
}

inline std::optional<id::IdRegisters> read_id_registers()
{
    return std::nullopt;
}

}  // namespace oaknut
