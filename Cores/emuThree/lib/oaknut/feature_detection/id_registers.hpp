// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>

namespace oaknut::id {

namespace detail {

template<std::size_t lsb>
constexpr unsigned extract_bit(std::uint64_t value)
{
    return (value >> lsb) & 1;
}

template<std::size_t lsb>
constexpr unsigned extract_field(std::uint64_t value)
{
    return (value >> lsb) & 0xf;
}

template<std::size_t lsb>
constexpr signed extract_signed_field(std::uint64_t value)
{
    return static_cast<signed>(static_cast<std::int64_t>(value << (60 - lsb)) >> 60);
}

}  // namespace detail

struct Pfr0Register {
    std::uint64_t value;

    constexpr signed FP() const { return detail::extract_signed_field<16>(value); }
    constexpr signed AdvSIMD() const { return detail::extract_signed_field<20>(value); }
    constexpr unsigned GIC() const { return detail::extract_field<24>(value); }
    constexpr unsigned RAS() const { return detail::extract_field<28>(value); }
    constexpr unsigned SVE() const { return detail::extract_field<32>(value); }
    constexpr unsigned SEL2() const { return detail::extract_field<36>(value); }
    constexpr unsigned MPAM() const { return detail::extract_field<40>(value); }
    constexpr unsigned AMU() const { return detail::extract_field<44>(value); }
    constexpr unsigned DIT() const { return detail::extract_field<48>(value); }
    constexpr unsigned RME() const { return detail::extract_field<52>(value); }
    constexpr unsigned CSV2() const { return detail::extract_field<56>(value); }
    constexpr unsigned CSV3() const { return detail::extract_field<60>(value); }
};

struct Pfr1Register {
    std::uint64_t value;

    constexpr unsigned BT() const { return detail::extract_field<0>(value); }
    constexpr unsigned SSBS() const { return detail::extract_field<4>(value); }
    constexpr unsigned MTE() const { return detail::extract_field<8>(value); }
    constexpr unsigned RAS_frac() const { return detail::extract_field<12>(value); }
    constexpr unsigned MPAM_frac() const { return detail::extract_field<16>(value); }
    // [20:23] - reserved
    constexpr unsigned SME() const { return detail::extract_field<24>(value); }
    constexpr unsigned RNDR_trap() const { return detail::extract_field<28>(value); }
    constexpr unsigned CSV2_frac() const { return detail::extract_field<32>(value); }
    constexpr unsigned NMI() const { return detail::extract_field<36>(value); }
    constexpr unsigned MTE_frac() const { return detail::extract_field<40>(value); }
    constexpr unsigned GCS() const { return detail::extract_field<44>(value); }
    constexpr unsigned THE() const { return detail::extract_field<48>(value); }
    constexpr unsigned MTEX() const { return detail::extract_field<52>(value); }
    constexpr unsigned DF2() const { return detail::extract_field<56>(value); }
    constexpr unsigned PFAR() const { return detail::extract_field<60>(value); }
};

struct Pfr2Register {
    std::uint64_t value;

    constexpr unsigned MTEPERM() const { return detail::extract_field<0>(value); }
    constexpr unsigned MTESTOREONLY() const { return detail::extract_field<4>(value); }
    constexpr unsigned MTEFAR() const { return detail::extract_field<8>(value); }
    // [12:31] reserved
    constexpr unsigned FPMR() const { return detail::extract_field<32>(value); }
    // [36:63] reserved
};

struct Zfr0Register {
    std::uint64_t value;

    constexpr unsigned SVEver() const { return detail::extract_field<0>(value); }
    constexpr unsigned AES() const { return detail::extract_field<4>(value); }
    // [8:15] reserved
    constexpr unsigned BitPerm() const { return detail::extract_field<16>(value); }
    constexpr unsigned BF16() const { return detail::extract_field<20>(value); }
    constexpr unsigned B16B16() const { return detail::extract_field<24>(value); }
    // [28:31] reserved
    constexpr unsigned SHA3() const { return detail::extract_field<32>(value); }
    // [36:39] reserved
    constexpr unsigned SM4() const { return detail::extract_field<40>(value); }
    constexpr unsigned I8MM() const { return detail::extract_field<44>(value); }
    // [48:51] reserved
    constexpr unsigned F32MM() const { return detail::extract_field<52>(value); }
    constexpr unsigned F64MM() const { return detail::extract_field<56>(value); }
    // [60:63] reserved
};

struct Smfr0Register {
    std::uint64_t value;

    // [0:27] reserved
    constexpr unsigned SF8DP2() const { return detail::extract_bit<28>(value); }
    constexpr unsigned SF8DP4() const { return detail::extract_bit<29>(value); }
    constexpr unsigned SF8FMA() const { return detail::extract_bit<30>(value); }
    // [31] reserved
    constexpr unsigned F32F32() const { return detail::extract_bit<32>(value); }
    constexpr unsigned BI32I32() const { return detail::extract_bit<33>(value); }
    constexpr unsigned B16F32() const { return detail::extract_bit<34>(value); }
    constexpr unsigned F16F32() const { return detail::extract_bit<35>(value); }
    constexpr unsigned I8I32() const { return detail::extract_field<36>(value); }
    constexpr unsigned F8F32() const { return detail::extract_bit<40>(value); }
    constexpr unsigned F8F16() const { return detail::extract_bit<41>(value); }
    constexpr unsigned F16F16() const { return detail::extract_bit<42>(value); }
    constexpr unsigned B16B16() const { return detail::extract_bit<43>(value); }
    constexpr unsigned I16I32() const { return detail::extract_field<44>(value); }
    constexpr unsigned F64F64() const { return detail::extract_bit<48>(value); }
    // [49:51] reserved
    constexpr unsigned I16I64() const { return detail::extract_field<52>(value); }
    constexpr unsigned SMEver() const { return detail::extract_field<56>(value); }
    constexpr unsigned LUTv2() const { return detail::extract_bit<60>(value); }
    // [61:62] reserved
    constexpr unsigned FA64() const { return detail::extract_bit<63>(value); }
};

struct Isar0Register {
    std::uint64_t value;

    // [0:3] reserved
    constexpr unsigned AES() const { return detail::extract_field<4>(value); }
    constexpr unsigned SHA1() const { return detail::extract_field<8>(value); }
    constexpr unsigned SHA2() const { return detail::extract_field<12>(value); }
    constexpr unsigned CRC32() const { return detail::extract_field<16>(value); }
    constexpr unsigned Atomic() const { return detail::extract_field<20>(value); }
    constexpr unsigned TME() const { return detail::extract_field<24>(value); }
    constexpr unsigned RDM() const { return detail::extract_field<28>(value); }
    constexpr unsigned SHA3() const { return detail::extract_field<32>(value); }
    constexpr unsigned SM3() const { return detail::extract_field<36>(value); }
    constexpr unsigned SM4() const { return detail::extract_field<40>(value); }
    constexpr unsigned DP() const { return detail::extract_field<44>(value); }
    constexpr unsigned FHM() const { return detail::extract_field<48>(value); }
    constexpr unsigned TS() const { return detail::extract_field<52>(value); }
    constexpr unsigned TLB() const { return detail::extract_field<56>(value); }
    constexpr unsigned RNDR() const { return detail::extract_field<60>(value); }
};

struct Isar1Register {
    std::uint64_t value;

    constexpr unsigned DPB() const { return detail::extract_field<0>(value); }
    constexpr unsigned APA() const { return detail::extract_field<4>(value); }
    constexpr unsigned API() const { return detail::extract_field<8>(value); }
    constexpr unsigned JSCVT() const { return detail::extract_field<12>(value); }
    constexpr unsigned FCMA() const { return detail::extract_field<16>(value); }
    constexpr unsigned LRCPC() const { return detail::extract_field<20>(value); }
    constexpr unsigned GPA() const { return detail::extract_field<24>(value); }
    constexpr unsigned GPI() const { return detail::extract_field<28>(value); }
    constexpr unsigned FRINTTS() const { return detail::extract_field<32>(value); }
    constexpr unsigned SB() const { return detail::extract_field<36>(value); }
    constexpr unsigned SPECRES() const { return detail::extract_field<40>(value); }
    constexpr unsigned BF16() const { return detail::extract_field<44>(value); }
    constexpr unsigned DGH() const { return detail::extract_field<48>(value); }
    constexpr unsigned I8MM() const { return detail::extract_field<52>(value); }
    constexpr unsigned XS() const { return detail::extract_field<56>(value); }
    constexpr unsigned LS64() const { return detail::extract_field<60>(value); }
};

struct Isar2Register {
    std::uint64_t value;

    constexpr unsigned WFxT() const { return detail::extract_field<0>(value); }
    constexpr unsigned RPRES() const { return detail::extract_field<4>(value); }
    constexpr unsigned GPA3() const { return detail::extract_field<8>(value); }
    constexpr unsigned APA3() const { return detail::extract_field<12>(value); }
    constexpr unsigned MOPS() const { return detail::extract_field<16>(value); }
    constexpr unsigned BC() const { return detail::extract_field<20>(value); }
    constexpr unsigned PAC_frac() const { return detail::extract_field<24>(value); }
    constexpr unsigned CLRBHB() const { return detail::extract_field<28>(value); }
    constexpr unsigned SYSREG_128() const { return detail::extract_field<32>(value); }
    constexpr unsigned SYSINSTR_128() const { return detail::extract_field<36>(value); }
    constexpr unsigned PRFMSLC() const { return detail::extract_field<40>(value); }
    // [44:47] reserved
    constexpr unsigned RPRFM() const { return detail::extract_field<48>(value); }
    constexpr unsigned CSSC() const { return detail::extract_field<52>(value); }
    constexpr unsigned LUT() const { return detail::extract_field<56>(value); }
    constexpr unsigned ATS1A() const { return detail::extract_field<60>(value); }
};

struct Isar3Register {
    std::uint64_t value;

    constexpr unsigned CPA() const { return detail::extract_field<0>(value); }
    constexpr unsigned FAMINMAX() const { return detail::extract_field<4>(value); }
    constexpr unsigned TLBIW() const { return detail::extract_field<8>(value); }
    // [12:63] reserved
};

struct Mmfr0Register {
    std::uint64_t value;

    constexpr unsigned PARange() const { return detail::extract_field<0>(value); }
    constexpr unsigned ASIDBits() const { return detail::extract_field<4>(value); }
    constexpr unsigned BigEnd() const { return detail::extract_field<8>(value); }
    constexpr unsigned SNSMem() const { return detail::extract_field<12>(value); }
    constexpr unsigned BigEndEL0() const { return detail::extract_field<16>(value); }
    constexpr unsigned TGran16() const { return detail::extract_field<20>(value); }
    constexpr unsigned TGran64() const { return detail::extract_field<24>(value); }
    constexpr unsigned TGran4() const { return detail::extract_field<28>(value); }
    constexpr unsigned TGran16_2() const { return detail::extract_field<32>(value); }
    constexpr unsigned TGran64_2() const { return detail::extract_field<36>(value); }
    constexpr unsigned TGran4_2() const { return detail::extract_field<40>(value); }
    constexpr unsigned ExS() const { return detail::extract_field<44>(value); }
    // [48:55] reserved
    constexpr unsigned FGT() const { return detail::extract_field<56>(value); }
    constexpr unsigned ECV() const { return detail::extract_field<60>(value); }
};

struct Mmfr1Register {
    std::uint64_t value;

    constexpr unsigned HAFDBS() const { return detail::extract_field<0>(value); }
    constexpr unsigned VMIDBits() const { return detail::extract_field<4>(value); }
    constexpr unsigned VH() const { return detail::extract_field<8>(value); }
    constexpr unsigned HPDS() const { return detail::extract_field<12>(value); }
    constexpr unsigned LO() const { return detail::extract_field<16>(value); }
    constexpr unsigned PAN() const { return detail::extract_field<20>(value); }
    constexpr unsigned SpecSEI() const { return detail::extract_field<24>(value); }
    constexpr unsigned XNX() const { return detail::extract_field<28>(value); }
    constexpr unsigned TWED() const { return detail::extract_field<32>(value); }
    constexpr unsigned ETS() const { return detail::extract_field<36>(value); }
    constexpr unsigned HCX() const { return detail::extract_field<40>(value); }
    constexpr unsigned AFP() const { return detail::extract_field<44>(value); }
    constexpr unsigned nTLBPA() const { return detail::extract_field<48>(value); }
    constexpr unsigned TIDCP1() const { return detail::extract_field<52>(value); }
    constexpr unsigned CMOW() const { return detail::extract_field<56>(value); }
    constexpr unsigned ECBHB() const { return detail::extract_field<60>(value); }
};

struct Mmfr2Register {
    std::uint64_t value;

    constexpr unsigned CnP() const { return detail::extract_field<0>(value); }
    constexpr unsigned UAO() const { return detail::extract_field<4>(value); }
    constexpr unsigned LSM() const { return detail::extract_field<8>(value); }
    constexpr unsigned IESB() const { return detail::extract_field<12>(value); }
    constexpr unsigned VARange() const { return detail::extract_field<16>(value); }
    constexpr unsigned CCIDX() const { return detail::extract_field<20>(value); }
    constexpr unsigned NV() const { return detail::extract_field<24>(value); }
    constexpr unsigned ST() const { return detail::extract_field<28>(value); }
    constexpr unsigned AT() const { return detail::extract_field<32>(value); }
    constexpr unsigned IDS() const { return detail::extract_field<36>(value); }
    constexpr unsigned FWB() const { return detail::extract_field<40>(value); }
    // [44:47] reserved
    constexpr unsigned TTL() const { return detail::extract_field<48>(value); }
    constexpr unsigned BBM() const { return detail::extract_field<52>(value); }
    constexpr unsigned EVT() const { return detail::extract_field<56>(value); }
    constexpr unsigned E0PD() const { return detail::extract_field<60>(value); }
};

struct Mmfr3Register {
    std::uint64_t value;

    constexpr unsigned TCRX() const { return detail::extract_field<0>(value); }
    constexpr unsigned SCTLRX() const { return detail::extract_field<4>(value); }
    constexpr unsigned S1PIE() const { return detail::extract_field<8>(value); }
    constexpr unsigned S2PIE() const { return detail::extract_field<12>(value); }
    constexpr unsigned S1POE() const { return detail::extract_field<16>(value); }
    constexpr unsigned S2POE() const { return detail::extract_field<20>(value); }
    constexpr unsigned AIE() const { return detail::extract_field<24>(value); }
    constexpr unsigned MEC() const { return detail::extract_field<28>(value); }
    constexpr unsigned D128() const { return detail::extract_field<32>(value); }
    constexpr unsigned D128_2() const { return detail::extract_field<36>(value); }
    constexpr unsigned SNERR() const { return detail::extract_field<40>(value); }
    constexpr unsigned ANERR() const { return detail::extract_field<44>(value); }
    // [48:51] reserved
    constexpr unsigned SDERR() const { return detail::extract_field<52>(value); }
    constexpr unsigned ADERR() const { return detail::extract_field<56>(value); }
    constexpr unsigned Spec_FPACC() const { return detail::extract_field<60>(value); }
};

struct Mmfr4Register {
    std::uint64_t value;

    // [0:3] reserved
    constexpr unsigned EIESB() const { return detail::extract_field<4>(value); }
    constexpr unsigned ASID2() const { return detail::extract_field<8>(value); }
    constexpr unsigned HACDBS() const { return detail::extract_field<12>(value); }
    constexpr unsigned FGWTE3() const { return detail::extract_field<16>(value); }
    constexpr unsigned NV_frac() const { return detail::extract_field<20>(value); }
    constexpr unsigned E2H0() const { return detail::extract_field<24>(value); }
    // [28:35] reserved
    constexpr unsigned E3DSE() const { return detail::extract_field<36>(value); }
    // [40:63] reserved
};

struct IdRegisters {
    std::optional<std::uint64_t> midr;
    Pfr0Register pfr0;
    Pfr1Register pfr1;
    Pfr2Register pfr2;
    Zfr0Register zfr0;
    Smfr0Register smfr0;
    Isar0Register isar0;
    Isar1Register isar1;
    Isar2Register isar2;
    Isar3Register isar3;
    Mmfr0Register mmfr0;
    Mmfr1Register mmfr1;
    Mmfr2Register mmfr2;
    Mmfr3Register mmfr3;
    Mmfr4Register mmfr4;
};

}  // namespace oaknut::id
