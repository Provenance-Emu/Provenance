// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <optional>

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

inline CpuFeatures detect_features()
{
    return CpuFeatures{CpuFeature::FP, CpuFeature::ASIMD};
}

inline std::optional<id::IdRegisters> read_id_registers()
{
    return std::nullopt;
}

}  // namespace oaknut
