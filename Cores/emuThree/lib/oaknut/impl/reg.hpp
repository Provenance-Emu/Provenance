// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cassert>
#include <cstddef>
#include <cstdint>

#include "oaknut/oaknut_exception.hpp"

namespace oaknut {

struct Reg;

struct RReg;
struct ZrReg;
struct WzrReg;
struct XReg;
struct WReg;
struct SpReg;
struct WspReg;
struct XRegSp;
struct XRegWsp;

struct VReg;
struct VRegArranged;
struct BReg;
struct HReg;
struct SReg;
struct DReg;
struct QReg;
struct VReg_2H;
struct VReg_8B;
struct VReg_4H;
struct VReg_2S;
struct VReg_1D;
struct VReg_16B;
struct VReg_8H;
struct VReg_4S;
struct VReg_2D;
struct VReg_1Q;

struct VRegSelector;

template<typename Elem>
struct ElemSelector;
struct BElem;
struct HElem;
struct SElem;
struct DElem;

struct Reg {
    constexpr explicit Reg(bool is_vector_, unsigned bitsize_, int index_)
        : m_index(static_cast<std::int8_t>(index_))
        , m_bitsize(static_cast<std::uint8_t>(bitsize_))
        , m_is_vector(is_vector_)
    {
        assert(index_ >= -1 && index_ <= 31);
        assert(bitsize_ != 0 && (bitsize_ & (bitsize_ - 1)) == 0 && "Bitsize must be a power of two");
    }

    constexpr int index() const { return m_index; }
    constexpr unsigned bitsize() const { return m_bitsize; }
    constexpr bool is_vector() const { return m_is_vector; }

private:
    std::int8_t m_index;
    std::uint8_t m_bitsize;
    bool m_is_vector;
};

struct RReg : public Reg {
    constexpr explicit RReg(unsigned bitsize_, int index_)
        : Reg(false, bitsize_, index_)
    {
        assert(bitsize_ == 32 || bitsize_ == 64);
    }

    XReg toX() const;
    WReg toW() const;

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct ZrReg : public RReg {
    constexpr explicit ZrReg()
        : RReg(64, 31) {}
};

struct WzrReg : public RReg {
    constexpr explicit WzrReg()
        : RReg(32, 31) {}
};

struct XReg : public RReg {
    constexpr explicit XReg(int index_)
        : RReg(64, index_) {}

    constexpr /* implicit */ XReg(ZrReg)
        : RReg(64, 31) {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct WReg : public RReg {
    constexpr explicit WReg(int index_)
        : RReg(32, index_) {}

    constexpr /* implicit */ WReg(WzrReg)
        : RReg(32, 31) {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

inline XReg RReg::toX() const
{
    if (index() == -1)
        throw OaknutException{ExceptionType::InvalidXSPConversion};
    return XReg{index()};
}

inline WReg RReg::toW() const
{
    if (index() == -1)
        throw OaknutException{ExceptionType::InvalidWSPConversion};
    return WReg{index()};
}

struct SpReg : public RReg {
    constexpr explicit SpReg()
        : RReg(64, -1) {}
};

struct WspReg : public RReg {
    constexpr explicit WspReg()
        : RReg(64, -1) {}
};

struct XRegSp : public RReg {
    constexpr /* implict */ XRegSp(SpReg)
        : RReg(64, -1) {}

    constexpr /* implict */ XRegSp(XReg xr)
        : RReg(64, xr.index())
    {
        if (xr.index() == 31)
            throw OaknutException{ExceptionType::InvalidXZRConversion};
    }

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct WRegWsp : public RReg {
    constexpr /* implict */ WRegWsp(WspReg)
        : RReg(32, -1) {}

    constexpr /* implict */ WRegWsp(WReg wr)
        : RReg(32, wr.index())
    {
        if (wr.index() == 31)
            throw OaknutException{ExceptionType::InvalidWZRConversion};
    }

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg : public Reg {
    constexpr explicit VReg(unsigned bitsize_, int index_)
        : Reg(true, bitsize_, index_)
    {
        assert(bitsize_ == 8 || bitsize_ == 16 || bitsize_ == 32 || bitsize_ == 64 || bitsize_ == 128);
    }

    constexpr BReg toB() const;
    constexpr HReg toH() const;
    constexpr SReg toS() const;
    constexpr DReg toD() const;
    constexpr QReg toQ() const;

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VRegArranged : public Reg {
protected:
    constexpr explicit VRegArranged(unsigned bitsize_, int index_, unsigned esize_)
        : Reg(true, bitsize_, index_), m_esize(static_cast<std::uint8_t>(esize_))
    {
        assert(esize_ != 0 && (esize_ & (esize_ - 1)) == 0 && "esize must be a power of two");
        assert(esize_ <= bitsize_);
    }

    template<typename Policy>
    friend class BasicCodeGenerator;

private:
    std::uint8_t m_esize;
};

struct VReg_2H : public VRegArranged {
    constexpr explicit VReg_2H(int reg_index_)
        : VRegArranged(32, reg_index_, 32 / 2)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_8B : public VRegArranged {
    constexpr explicit VReg_8B(int reg_index_)
        : VRegArranged(64, reg_index_, 64 / 8)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_4H : public VRegArranged {
    constexpr explicit VReg_4H(int reg_index_)
        : VRegArranged(64, reg_index_, 64 / 4)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_2S : public VRegArranged {
    constexpr explicit VReg_2S(int reg_index_)
        : VRegArranged(64, reg_index_, 64 / 2)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_1D : public VRegArranged {
    constexpr explicit VReg_1D(int reg_index_)
        : VRegArranged(64, reg_index_, 64 / 1)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_16B : public VRegArranged {
    constexpr explicit VReg_16B(int reg_index_)
        : VRegArranged(128, reg_index_, 128 / 16)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_8H : public VRegArranged {
    constexpr explicit VReg_8H(int reg_index_)
        : VRegArranged(128, reg_index_, 128 / 8)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_4S : public VRegArranged {
    constexpr explicit VReg_4S(int reg_index_)
        : VRegArranged(128, reg_index_, 128 / 4)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_2D : public VRegArranged {
    constexpr explicit VReg_2D(int reg_index_)
        : VRegArranged(128, reg_index_, 128 / 2)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct VReg_1Q : public VRegArranged {
    constexpr explicit VReg_1Q(int reg_index_)
        : VRegArranged(128, reg_index_, 128 / 1)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct Elem {
    constexpr explicit Elem(unsigned esize_, int reg_, unsigned elem_index_)
        : m_esize(esize_), m_reg(reg_), m_elem_index(elem_index_)
    {
        if (elem_index_ >= 128 / esize_)
            throw OaknutException{ExceptionType::InvalidElementIndex};
    }

    constexpr unsigned esize() const { return m_esize; }
    constexpr int reg_index() const { return m_reg; }
    constexpr unsigned elem_index() const { return m_elem_index; }

private:
    unsigned m_esize;
    int m_reg;
    unsigned m_elem_index;
};

struct BElem : public Elem {
    constexpr explicit BElem(int reg_, unsigned elem_index_)
        : Elem(2, reg_, elem_index_)
    {}
};

struct HElem : public Elem {
    constexpr explicit HElem(int reg_, unsigned elem_index_)
        : Elem(2, reg_, elem_index_)
    {}
};

struct SElem : public Elem {
    constexpr explicit SElem(int reg_, unsigned elem_index_)
        : Elem(4, reg_, elem_index_)
    {}
};

struct DElem : public Elem {
    constexpr explicit DElem(int reg_, unsigned elem_index_)
        : Elem(8, reg_, elem_index_)
    {}
};

struct DElem_1 : public DElem {
    constexpr /* implict */ DElem_1(DElem inner)
        : DElem(inner)
    {
        if (inner.elem_index() != 1)
            throw OaknutException{ExceptionType::InvalidDElem_1};
    }
};

template<typename E>
struct ElemSelector {
    constexpr explicit ElemSelector(int reg_index_)
        : m_reg_index(reg_index_)
    {}

    constexpr int reg_index() const { return m_reg_index; }

    constexpr E operator[](unsigned elem_index) const { return E{m_reg_index, elem_index}; }

private:
    int m_reg_index;
};

struct BReg : public VReg {
    constexpr explicit BReg(int index_)
        : VReg(8, index_)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct HReg : public VReg {
    constexpr explicit HReg(int index_)
        : VReg(16, index_)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct SReg : public VReg {
    constexpr explicit SReg(int index_)
        : VReg(32, index_)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;
};

struct DReg : public VReg {
    constexpr explicit DReg(int index_)
        : VReg(64, index_)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;

    constexpr ElemSelector<BElem> Belem() const { return ElemSelector<BElem>(index()); }
    constexpr ElemSelector<HElem> Helem() const { return ElemSelector<HElem>(index()); }
    constexpr ElemSelector<SElem> Selem() const { return ElemSelector<SElem>(index()); }
    constexpr ElemSelector<DElem> Delem() const { return ElemSelector<DElem>(index()); }

    constexpr VReg_8B B8() const { return VReg_8B{index()}; }
    constexpr VReg_4H H4() const { return VReg_4H{index()}; }
    constexpr VReg_2S S2() const { return VReg_2S{index()}; }
    constexpr VReg_1D D1() const { return VReg_1D{index()}; }
};

struct QReg : public VReg {
    constexpr explicit QReg(int index_)
        : VReg(128, index_)
    {}

    template<typename Policy>
    friend class BasicCodeGenerator;

    constexpr ElemSelector<BElem> Belem() const { return ElemSelector<BElem>(index()); }
    constexpr ElemSelector<HElem> Helem() const { return ElemSelector<HElem>(index()); }
    constexpr ElemSelector<SElem> Selem() const { return ElemSelector<SElem>(index()); }
    constexpr ElemSelector<DElem> Delem() const { return ElemSelector<DElem>(index()); }

    constexpr VReg_16B B16() const { return VReg_16B{index()}; }
    constexpr VReg_8H H8() const { return VReg_8H{index()}; }
    constexpr VReg_4S S4() const { return VReg_4S{index()}; }
    constexpr VReg_2D D2() const { return VReg_2D{index()}; }
    constexpr VReg_1Q Q1() const { return VReg_1Q{index()}; }
};

constexpr BReg VReg::toB() const
{
    return BReg{index()};
}
constexpr HReg VReg::toH() const
{
    return HReg{index()};
}
constexpr SReg VReg::toS() const
{
    return SReg{index()};
}
constexpr DReg VReg::toD() const
{
    return DReg{index()};
}
constexpr QReg VReg::toQ() const
{
    return QReg{index()};
}

struct VRegSelector {
    constexpr explicit VRegSelector(int reg_index)
        : m_reg_index(reg_index)
    {}

    constexpr int index() const { return m_reg_index; }

    constexpr ElemSelector<BElem> B() const { return ElemSelector<BElem>(index()); }
    constexpr ElemSelector<HElem> H() const { return ElemSelector<HElem>(index()); }
    constexpr ElemSelector<SElem> S() const { return ElemSelector<SElem>(index()); }
    constexpr ElemSelector<DElem> D() const { return ElemSelector<DElem>(index()); }

    constexpr VReg_2H H2() const { return VReg_2H{index()}; }
    constexpr VReg_8B B8() const { return VReg_8B{index()}; }
    constexpr VReg_4H H4() const { return VReg_4H{index()}; }
    constexpr VReg_2S S2() const { return VReg_2S{index()}; }
    constexpr VReg_1D D1() const { return VReg_1D{index()}; }
    constexpr VReg_16B B16() const { return VReg_16B{index()}; }
    constexpr VReg_8H H8() const { return VReg_8H{index()}; }
    constexpr VReg_4S S4() const { return VReg_4S{index()}; }
    constexpr VReg_2D D2() const { return VReg_2D{index()}; }
    constexpr VReg_1Q Q1() const { return VReg_1Q{index()}; }

private:
    int m_reg_index;
};

}  // namespace oaknut
