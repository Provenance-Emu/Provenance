// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

template<std::uint32_t mask_>
static constexpr std::uint32_t pdep(std::uint32_t val)
{
    std::uint32_t mask = mask_;
    std::uint32_t res = 0;
    for (std::uint32_t bb = 1; mask; bb += bb) {
        if (val & bb)
            res |= mask & (~mask + 1);
        mask &= mask - 1;
    }
    return res;
}

#define OAKNUT_STD_ENCODE(TYPE, ACCESS, SIZE)                   \
    template<std::uint32_t splat>                               \
    std::uint32_t encode(TYPE v)                                \
    {                                                           \
        static_assert(std::popcount(splat) == SIZE);            \
        return pdep<splat>(static_cast<std::uint32_t>(ACCESS)); \
    }

OAKNUT_STD_ENCODE(RReg, v.index() & 31, 5)
OAKNUT_STD_ENCODE(VReg, v.index() & 31, 5)
OAKNUT_STD_ENCODE(VRegArranged, v.index() & 31, 5)

OAKNUT_STD_ENCODE(AddSubImm, v.m_encoded, 13)
OAKNUT_STD_ENCODE(BitImm32, v.m_encoded, 12)
OAKNUT_STD_ENCODE(BitImm64, v.m_encoded, 13)
OAKNUT_STD_ENCODE(LslShift<32>, v.m_encoded, 12)
OAKNUT_STD_ENCODE(LslShift<64>, v.m_encoded, 12)
OAKNUT_STD_ENCODE(FImm8, v.m_encoded, 8)
OAKNUT_STD_ENCODE(RepImm, v.m_encoded, 8)

OAKNUT_STD_ENCODE(Cond, v, 4)
OAKNUT_STD_ENCODE(AddSubExt, v, 3)
OAKNUT_STD_ENCODE(IndexExt, v, 3)
OAKNUT_STD_ENCODE(AddSubShift, v, 2)
OAKNUT_STD_ENCODE(LogShift, v, 2)
OAKNUT_STD_ENCODE(PstateField, v, 6)
OAKNUT_STD_ENCODE(SystemReg, v, 15)
OAKNUT_STD_ENCODE(AtOp, v, 7)
OAKNUT_STD_ENCODE(BarrierOp, v, 4)
OAKNUT_STD_ENCODE(DcOp, v, 10)
OAKNUT_STD_ENCODE(IcOp, v, 10)
OAKNUT_STD_ENCODE(PrfOp, v, 5)
OAKNUT_STD_ENCODE(TlbiOp, v, 10)

template<std::uint32_t splat>
std::uint32_t encode(MovImm16 v)
{
    static_assert(std::popcount(splat) == 17 || std::popcount(splat) == 18);
    if constexpr (std::popcount(splat) == 17) {
        constexpr std::uint32_t mask = (1 << std::popcount(splat)) - 1;
        if ((v.m_encoded & mask) != v.m_encoded)
            throw OaknutException{ExceptionType::InvalidMovImm16};
    }
    return pdep<splat>(v.m_encoded);
}

template<std::uint32_t splat, std::size_t imm_size>
std::uint32_t encode(Imm<imm_size> v)
{
    static_assert(std::popcount(splat) >= imm_size);
    return pdep<splat>(v.value());
}

template<std::uint32_t splat, int A, int B>
std::uint32_t encode(ImmChoice<A, B> v)
{
    static_assert(std::popcount(splat) == 1);
    return pdep<splat>(v.m_encoded);
}

template<std::uint32_t splat, int A, int B, int C, int D>
std::uint32_t encode(ImmChoice<A, B, C, D> v)
{
    static_assert(std::popcount(splat) == 2);
    return pdep<splat>(v.m_encoded);
}

template<std::uint32_t splat, std::size_t size, std::size_t align>
std::uint32_t encode(SOffset<size, align> v)
{
    static_assert(std::popcount(splat) == size - align);
    return pdep<splat>(v.m_encoded);
}

template<std::uint32_t splat, std::size_t size, std::size_t align>
std::uint32_t encode(POffset<size, align> v)
{
    static_assert(std::popcount(splat) == size - align);
    return pdep<splat>(v.m_encoded);
}

template<std::uint32_t splat>
std::uint32_t encode(std::uint32_t v)
{
    return pdep<splat>(v);
}

template<std::uint32_t splat, typename T, size_t N>
std::uint32_t encode(List<T, N> v)
{
    return encode<splat>(v.m_base);
}

template<std::uint32_t splat, std::size_t size, std::size_t align>
std::uint32_t encode(AddrOffset<size, align> v)
{
    static_assert(std::popcount(splat) == size - align);

    const auto encode_fn = [](std::ptrdiff_t current_offset, std::ptrdiff_t target_offset) {
        const std::ptrdiff_t diff = target_offset - current_offset;
        return pdep<splat>(AddrOffset<size, align>::encode(diff));
    };

    return std::visit(detail::overloaded{
                          [&](std::uint32_t encoding) -> std::uint32_t {
                              return pdep<splat>(encoding);
                          },
                          [&](Label* label) -> std::uint32_t {
                              if (label->m_offset) {
                                  return encode_fn(Policy::offset(), *label->m_offset);
                              }

                              label->m_wbs.emplace_back(Label::Writeback{Policy::offset(), ~splat, static_cast<Label::EmitFunctionType>(encode_fn)});
                              return 0u;
                          },
                          [&](const void* p) -> std::uint32_t {
                              const std::ptrdiff_t diff = reinterpret_cast<std::uintptr_t>(p) - Policy::template xptr<std::uintptr_t>();
                              return pdep<splat>(AddrOffset<size, align>::encode(diff));
                          },
                      },
                      v.m_payload);
}

template<std::uint32_t splat, std::size_t size, std::size_t shift_amount>
std::uint32_t encode(PageOffset<size, shift_amount> v)
{
    static_assert(std::popcount(splat) == size);

    const auto encode_fn = [](std::ptrdiff_t current_offset, std::ptrdiff_t target_offset) {
        return pdep<splat>(PageOffset<size, shift_amount>::encode(static_cast<std::uintptr_t>(current_offset), static_cast<std::uintptr_t>(target_offset)));
    };

    return std::visit(detail::overloaded{
                          [&](Label* label) -> std::uint32_t {
                              if (label->m_offset) {
                                  return encode_fn(Policy::offset(), *label->m_offset);
                              }

                              label->m_wbs.emplace_back(Label::Writeback{Policy::offset(), ~splat, static_cast<Label::EmitFunctionType>(encode_fn)});
                              return 0u;
                          },
                          [&](const void* p) -> std::uint32_t {
                              return pdep<splat>(PageOffset<size, shift_amount>::encode(Policy::template xptr<std::uintptr_t>(), reinterpret_cast<std::ptrdiff_t>(p)));
                          },
                      },
                      v.m_payload);
}

#undef OAKNUT_STD_ENCODE

void addsubext_lsl_correction(AddSubExt& ext, XRegSp)
{
    if (ext == AddSubExt::LSL)
        ext = AddSubExt::UXTX;
}
void addsubext_lsl_correction(AddSubExt& ext, WRegWsp)
{
    if (ext == AddSubExt::LSL)
        ext = AddSubExt::UXTW;
}
void addsubext_lsl_correction(AddSubExt& ext, XReg)
{
    if (ext == AddSubExt::LSL)
        ext = AddSubExt::UXTX;
}
void addsubext_lsl_correction(AddSubExt& ext, WReg)
{
    if (ext == AddSubExt::LSL)
        ext = AddSubExt::UXTW;
}

void addsubext_verify_reg_size(AddSubExt ext, RReg rm)
{
    if (rm.bitsize() == 32 && (static_cast<int>(ext) & 0b011) != 0b011)
        return;
    if (rm.bitsize() == 64 && (static_cast<int>(ext) & 0b011) == 0b011)
        return;
    throw OaknutException{ExceptionType::InvalidAddSubExt};
}

void indexext_verify_reg_size(IndexExt ext, RReg rm)
{
    if (rm.bitsize() == 32 && (static_cast<int>(ext) & 1) == 0)
        return;
    if (rm.bitsize() == 64 && (static_cast<int>(ext) & 1) == 1)
        return;
    throw OaknutException{ExceptionType::InvalidIndexExt};
}

void tbz_verify_reg_size(RReg rt, Imm<6> imm)
{
    if (rt.bitsize() == 32 && imm.value() >= 32)
        throw OaknutException{ExceptionType::BitPositionOutOfRange};
}
