// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void SQRDMLAH(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0111111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLAH(SReg rd, SReg rn, SElem em)
{
    emit<"0111111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLAH(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLAH(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLAH(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLAH(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLAH(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110010mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLAH(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110100mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLAH(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLAH(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLAH(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110100mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLAH(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110100mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0111111101LMmmmm1111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLSH(SReg rd, SReg rn, SElem em)
{
    emit<"0111111110LMmmmm1111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLSH(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm1111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLSH(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm1111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMLSH(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm1111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLSH(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm1111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMLSH(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110010mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110100mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110100mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMLSH(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110100mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
