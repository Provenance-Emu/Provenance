// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void BCAX(VReg_16B rd, VReg_16B rn, VReg_16B rm, VReg_16B ra)
{
    emit<"11001110001mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void EOR3(VReg_16B rd, VReg_16B rn, VReg_16B rm, VReg_16B ra)
{
    emit<"11001110000mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FABD(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110110mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110110mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110110mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FABS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FACGE(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110010mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110110mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110110mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110110mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADDP(HReg rd, VReg_2H rn)
{
    emit<"0101111000110000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FADDP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADDP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(HReg rd, HReg rn, ImmConstFZero)
{
    emit<"0101111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(VReg_4H rd, VReg_4H rn, ImmConstFZero)
{
    emit<"0000111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(VReg_8H rd, VReg_8H rn, ImmConstFZero)
{
    emit<"0100111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(HReg rd, HReg rn, ImmConstFZero)
{
    emit<"0111111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(VReg_4H rd, VReg_4H rn, ImmConstFZero)
{
    emit<"0010111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(VReg_8H rd, VReg_8H rn, ImmConstFZero)
{
    emit<"0110111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110110mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110110mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110110mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(HReg rd, HReg rn, ImmConstFZero)
{
    emit<"0101111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(VReg_4H rd, VReg_4H rn, ImmConstFZero)
{
    emit<"0000111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(VReg_8H rd, VReg_8H rn, ImmConstFZero)
{
    emit<"0100111011111000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(HReg rd, HReg rn, ImmConstFZero)
{
    emit<"0111111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(VReg_4H rd, VReg_4H rn, ImmConstFZero)
{
    emit<"0010111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(VReg_8H rd, VReg_8H rn, ImmConstFZero)
{
    emit<"0110111011111000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(HReg rd, HReg rn, ImmConstFZero)
{
    emit<"0101111011111000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(VReg_4H rd, VReg_4H rn, ImmConstFZero)
{
    emit<"0000111011111000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(VReg_8H rd, VReg_8H rn, ImmConstFZero)
{
    emit<"0100111011111000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(HReg rd, HReg rn)
{
    emit<"0101111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(HReg rd, HReg rn)
{
    emit<"0111111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(HReg rd, HReg rn)
{
    emit<"0101111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(HReg rd, HReg rn)
{
    emit<"0111111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(HReg rd, HReg rn)
{
    emit<"0101111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(HReg rd, HReg rn)
{
    emit<"0111111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(HReg rd, HReg rn)
{
    emit<"0101111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(HReg rd, HReg rn)
{
    emit<"0111111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(HReg rd, HReg rn)
{
    emit<"0101111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(HReg rd, HReg rn)
{
    emit<"0111111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FDIV(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FDIV(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMP(HReg rd, VReg_2H rn)
{
    emit<"0101111000110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXNMP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMV(HReg rd, VReg_4H rn)
{
    emit<"0000111000110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXNMV(HReg rd, VReg_8H rn)
{
    emit<"0100111000110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXP(HReg rd, VReg_2H rn)
{
    emit<"0101111000110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXV(HReg rd, VReg_4H rn)
{
    emit<"0000111000110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXV(HReg rd, VReg_8H rn)
{
    emit<"0100111000110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMIN(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110110mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMIN(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110110mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110110mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110110mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMP(HReg rd, VReg_2H rn)
{
    emit<"0101111010110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINNMP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110110mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110110mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMV(HReg rd, VReg_4H rn)
{
    emit<"0000111010110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINNMV(HReg rd, VReg_8H rn)
{
    emit<"0100111010110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINP(HReg rd, VReg_2H rn)
{
    emit<"0101111010110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMINP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110110mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110110mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINV(HReg rd, VReg_4H rn)
{
    emit<"0000111010110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMINV(HReg rd, VReg_8H rn)
{
    emit<"0100111010110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMLA(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111100LMmmmm0001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLA(VReg_8B rd, VReg_8B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111100LMmmmm0001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLA(VReg_16B rd, VReg_16B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111100LMmmmm0001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLA(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLA(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLAL(VReg_2S rd, VReg_2H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111110LMmmmm0000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLAL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111110LMmmmm0000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLAL2(VReg_2S rd, VReg_2H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111110LMmmmm1000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLAL2(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111110LMmmmm1000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLAL(VReg_2S rd, VReg_2H rn, VReg_2H rm)
{
    emit<"00001110001mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"01001110001mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLAL2(VReg_2S rd, VReg_2H rn, VReg_2H rm)
{
    emit<"00101110001mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLAL2(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"01101110001mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLS(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111100LMmmmm0101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLS(VReg_8B rd, VReg_8B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111100LMmmmm0101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLS(VReg_16B rd, VReg_16B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111100LMmmmm0101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLS(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110110mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLS(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110110mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLSL(VReg_2S rd, VReg_2H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111110LMmmmm0100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLSL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111110LMmmmm0100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLSL2(VReg_2S rd, VReg_2H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111110LMmmmm1100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLSL2(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111110LMmmmm1100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMLSL(VReg_2S rd, VReg_2H rn, VReg_2H rm)
{
    emit<"00001110101mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLSL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"01001110101mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLSL2(VReg_2S rd, VReg_2H rn, VReg_2H rm)
{
    emit<"00101110101mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLSL2(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"01101110101mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMOV(VReg_4H rd, FImm8 imm)
{
    emit<"0000111100000vvv111111vvvvvddddd", "d", "v">(rd, imm);
}
void FMOV(VReg_8H rd, FImm8 imm)
{
    emit<"0100111100000vvv111111vvvvvddddd", "d", "v">(rd, imm);
}
void FMUL(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMUL(VReg_8B rd, VReg_8B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMUL(VReg_16B rd, VReg_16B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMUL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110010mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMUL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110010mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110010mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0111111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMULX(VReg_8B rd, VReg_8B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FMULX(VReg_16B rd, VReg_16B rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111100LMmmmm1001H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void FNEG(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FNEG(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(HReg rd, HReg rn)
{
    emit<"0101111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPS(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110010mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPX(HReg rd, HReg rn)
{
    emit<"0101111011111001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111011111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111011111001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(HReg rd, HReg rn)
{
    emit<"0111111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTS(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110110mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110110mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110110mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSQRT(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111011111001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FSQRT(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111011111001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FSUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110110mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110110mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RAX1(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"11001110011mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SCVTF(HReg rd, HReg rn)
{
    emit<"0101111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SDOT(VReg_2S rd, VReg_8B rn, SElem em)
{
    emit<"0000111110LMmmmm1110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SDOT(VReg_4S rd, VReg_16B rn, SElem em)
{
    emit<"0100111110LMmmmm1110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SDOT(VReg_2S rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110100mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SDOT(VReg_4S rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110100mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA512H(QReg rd, QReg rn, VReg_2D rm)
{
    emit<"11001110011mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA512H2(QReg rd, QReg rn, VReg_2D rm)
{
    emit<"11001110011mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA512SU0(VReg_2D rd, VReg_2D rn)
{
    emit<"1100111011000000100000nnnnnddddd", "d", "n">(rd, rn);
}
void SHA512SU1(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"11001110011mmmmm100010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SM3PARTW1(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"11001110011mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SM3PARTW2(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"11001110011mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SM3SS1(VReg_4S rd, VReg_4S rn, VReg_4S rm, VReg_4S ra)
{
    emit<"11001110010mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void SM3TT1A(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"11001110010mmmmm10ii00nnnnnddddd", "d", "n", "m", "i">(rd, rn, em.reg_index(), em.elem_index());
}
void SM3TT1B(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"11001110010mmmmm10ii01nnnnnddddd", "d", "n", "m", "i">(rd, rn, em.reg_index(), em.elem_index());
}
void SM3TT2A(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"11001110010mmmmm10ii10nnnnnddddd", "d", "n", "m", "i">(rd, rn, em.reg_index(), em.elem_index());
}
void SM3TT2B(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"11001110010mmmmm10ii11nnnnnddddd", "d", "n", "m", "i">(rd, rn, em.reg_index(), em.elem_index());
}
void SM4E(VReg_4S rd, VReg_4S rn)
{
    emit<"1100111011000000100001nnnnnddddd", "d", "n">(rd, rn);
}
void SM4EKEY(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"11001110011mmmmm110010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UCVTF(HReg rd, HReg rn)
{
    emit<"0111111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001111001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UDOT(VReg_2S rd, VReg_8B rn, SElem em)
{
    emit<"0010111110LMmmmm1110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UDOT(VReg_4S rd, VReg_16B rn, SElem em)
{
    emit<"0110111110LMmmmm1110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UDOT(VReg_2S rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110100mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UDOT(VReg_4S rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110100mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void XAR(VReg_2D rd, VReg_2D rn, VReg_2D rm, Imm<6> rotate_amount)
{
    emit<"11001110100mmmmmiiiiiinnnnnddddd", "d", "n", "m", "i">(rd, rn, rm, rotate_amount);
}
