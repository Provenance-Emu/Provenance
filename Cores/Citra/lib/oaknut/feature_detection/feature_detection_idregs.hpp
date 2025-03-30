// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include "oaknut/feature_detection/cpu_feature.hpp"
#include "oaknut/feature_detection/id_registers.hpp"

namespace oaknut {

CpuFeatures detect_features_via_id_registers(id::IdRegisters regs)
{
    CpuFeatures result;

    if (regs.pfr0.FP() >= 0)
        result |= CpuFeatures{CpuFeature::FP};
    if (regs.pfr0.AdvSIMD() >= 0)
        result |= CpuFeatures{CpuFeature::ASIMD};
    if (regs.isar0.AES() >= 1)
        result |= CpuFeatures{CpuFeature::AES};
    if (regs.isar0.AES() >= 2)
        result |= CpuFeatures{CpuFeature::PMULL};
    if (regs.isar0.SHA1() >= 1)
        result |= CpuFeatures{CpuFeature::SHA1};
    if (regs.isar0.SHA2() >= 1)
        result |= CpuFeatures{CpuFeature::SHA256};
    if (regs.isar0.CRC32() >= 1)
        result |= CpuFeatures{CpuFeature::CRC32};
    if (regs.isar0.Atomic() >= 2)
        result |= CpuFeatures{CpuFeature::LSE};
    if (regs.pfr0.FP() >= 1 && regs.pfr0.AdvSIMD() >= 1)
        result |= CpuFeatures{CpuFeature::FP16Conv, CpuFeature::FP16};
    if (regs.isar0.RDM() >= 1)
        result |= CpuFeatures{CpuFeature::RDM};
    if (regs.isar1.JSCVT() >= 1)
        result |= CpuFeatures{CpuFeature::JSCVT};
    if (regs.isar1.FCMA() >= 1)
        result |= CpuFeatures{CpuFeature::FCMA};
    if (regs.isar1.LRCPC() >= 1)
        result |= CpuFeatures{CpuFeature::LRCPC};
    if (regs.isar1.DPB() >= 1)
        result |= CpuFeatures{CpuFeature::DPB};
    if (regs.isar0.SHA3() >= 1)
        result |= CpuFeatures{CpuFeature::SHA3};
    if (regs.isar0.SM3() >= 1)
        result |= CpuFeatures{CpuFeature::SM3};
    if (regs.isar0.SM4() >= 1)
        result |= CpuFeatures{CpuFeature::SM4};
    if (regs.isar0.DP() >= 1)
        result |= CpuFeatures{CpuFeature::DotProd};
    if (regs.isar0.SHA2() >= 2)
        result |= CpuFeatures{CpuFeature::SHA512};
    if (regs.pfr0.SVE() >= 1)
        result |= CpuFeatures{CpuFeature::SVE};
    if (regs.isar0.FHM() >= 1)
        result |= CpuFeatures{CpuFeature::FHM};
    if (regs.pfr0.DIT() >= 1)
        result |= CpuFeatures{CpuFeature::DIT};
    if (regs.mmfr2.AT() >= 1)
        result |= CpuFeatures{CpuFeature::LSE2};
    if (regs.isar1.LRCPC() >= 2)
        result |= CpuFeatures{CpuFeature::LRCPC2};
    if (regs.isar0.TS() >= 1)
        result |= CpuFeatures{CpuFeature::FlagM};
    if (regs.pfr1.SSBS() >= 2)
        result |= CpuFeatures{CpuFeature::SSBS};
    if (regs.isar1.SB() >= 1)
        result |= CpuFeatures{CpuFeature::SB};
    if (regs.isar1.APA() >= 1 || regs.isar1.API() >= 1)
        result |= CpuFeatures{CpuFeature::PACA};
    if (regs.isar1.GPA() >= 1 || regs.isar1.GPI() >= 1)
        result |= CpuFeatures{CpuFeature::PACG};
    if (regs.isar1.DPB() >= 2)
        result |= CpuFeatures{CpuFeature::DPB2};
    if (regs.zfr0.SVEver() >= 1)
        result |= CpuFeatures{CpuFeature::SVE2};
    if (regs.zfr0.AES() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_AES};
    if (regs.zfr0.AES() >= 2)
        result |= CpuFeatures{CpuFeature::SVE_PMULL128};
    if (regs.zfr0.BitPerm() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_BITPERM};
    if (regs.zfr0.SHA3() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_SHA3};
    if (regs.zfr0.SM4() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_SM4};
    if (regs.isar0.TS() >= 2)
        result |= CpuFeatures{CpuFeature::FlagM2};
    if (regs.isar1.FRINTTS() >= 1)
        result |= CpuFeatures{CpuFeature::FRINTTS};
    if (regs.zfr0.I8MM() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_I8MM};
    if (regs.zfr0.F32MM() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_F32MM};
    if (regs.zfr0.F64MM() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_F64MM};
    if (regs.zfr0.BF16() >= 1)
        result |= CpuFeatures{CpuFeature::SVE_BF16};
    if (regs.isar1.I8MM() >= 1)
        result |= CpuFeatures{CpuFeature::I8MM};
    if (regs.isar1.BF16() >= 1)
        result |= CpuFeatures{CpuFeature::BF16};
    if (regs.isar1.DGH() >= 1)
        result |= CpuFeatures{CpuFeature::DGH};
    if (regs.isar0.RNDR() >= 1)
        result |= CpuFeatures{CpuFeature::RNG};
    if (regs.pfr1.BT() >= 1)
        result |= CpuFeatures{CpuFeature::BTI};
    if (regs.pfr1.MTE() >= 2)
        result |= CpuFeatures{CpuFeature::MTE};
    if (regs.mmfr0.ECV() >= 1)
        result |= CpuFeatures{CpuFeature::ECV};
    if (regs.mmfr1.AFP() >= 1)
        result |= CpuFeatures{CpuFeature::AFP};
    if (regs.isar2.RPRES() >= 1)
        result |= CpuFeatures{CpuFeature::RPRES};
    if (regs.pfr1.MTE() >= 3)
        result |= CpuFeatures{CpuFeature::MTE3};
    if (regs.pfr1.SME() >= 1)
        result |= CpuFeatures{CpuFeature::SME};
    if (regs.smfr0.I16I64() == 0b1111)
        result |= CpuFeatures{CpuFeature::SME_I16I64};
    if (regs.smfr0.F64F64() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_F64F64};
    if (regs.smfr0.I8I32() == 0b1111)
        result |= CpuFeatures{CpuFeature::SME_I8I32};
    if (regs.smfr0.F16F32() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_F16F32};
    if (regs.smfr0.B16F32() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_B16F32};
    if (regs.smfr0.F32F32() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_F32F32};
    if (regs.smfr0.FA64() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_FA64};
    if (regs.isar2.WFxT() >= 2)
        result |= CpuFeatures{CpuFeature::WFxT};
    if (regs.isar1.BF16() >= 2)
        result |= CpuFeatures{CpuFeature::EBF16};
    if (regs.zfr0.BF16() >= 2)
        result |= CpuFeatures{CpuFeature::SVE_EBF16};
    if (regs.isar2.CSSC() >= 1)
        result |= CpuFeatures{CpuFeature::CSSC};
    if (regs.isar2.RPRFM() >= 1)
        result |= CpuFeatures{CpuFeature::RPRFM};
    if (regs.zfr0.SVEver() >= 2)
        result |= CpuFeatures{CpuFeature::SVE2p1};
    if (regs.smfr0.SMEver() >= 1)
        result |= CpuFeatures{CpuFeature::SME2};
    if (regs.smfr0.SMEver() >= 2)
        result |= CpuFeatures{CpuFeature::SME2p1};
    if (regs.smfr0.I16I32() == 0b0101)
        result |= CpuFeatures{CpuFeature::SME_I16I32};
    if (regs.smfr0.BI32I32() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_BI32I32};
    if (regs.smfr0.B16B16() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_B16B16};
    if (regs.smfr0.F16F16() == 0b1)
        result |= CpuFeatures{CpuFeature::SME_F16F16};
    if (regs.isar2.MOPS() >= 1)
        result |= CpuFeatures{CpuFeature::MOPS};
    if (regs.isar2.BC() >= 1)
        result |= CpuFeatures{CpuFeature::HBC};

    return result;
}

}  // namespace oaknut
