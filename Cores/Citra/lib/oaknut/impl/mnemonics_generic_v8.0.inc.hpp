// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void ADC(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010000mmmmm000000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void ADC(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010000mmmmm000000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void ADCS(WReg wd, WReg wn, WReg wm)
{
    emit<"00111010000mmmmm000000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void ADCS(XReg xd, XReg xn, XReg xm)
{
    emit<"10111010000mmmmm000000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void ADD(WRegWsp wd, WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wd);
    emit<"00001011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(wd, wn, wm, ext, shift_amount);
}
void ADD(XRegSp xd, XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xd);
    addsubext_verify_reg_size(ext, rm);
    emit<"10001011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(xd, xn, rm, ext, shift_amount);
}
void ADD(WRegWsp wd, WRegWsp wn, AddSubImm imm)
{
    emit<"000100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(wd, wn, imm);
}
void ADD(WRegWsp wd, WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    ADD(wd, wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void ADD(XRegSp xd, XRegSp xn, AddSubImm imm)
{
    emit<"100100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(xd, xn, imm);
}
void ADD(XRegSp xd, XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    ADD(xd, xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void ADD(WReg wd, WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00001011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void ADD(XReg xd, XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10001011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ADDS(WReg wd, WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wd);
    emit<"00101011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(wd, wn, wm, ext, shift_amount);
}
void ADDS(XReg xd, XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xd);
    addsubext_verify_reg_size(ext, rm);
    emit<"10101011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(xd, xn, rm, ext, shift_amount);
}
void ADDS(WReg wd, WRegWsp wn, AddSubImm imm)
{
    emit<"001100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(wd, wn, imm);
}
void ADDS(WReg wd, WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    ADDS(wd, wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void ADDS(XReg xd, XRegSp xn, AddSubImm imm)
{
    emit<"101100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(xd, xn, imm);
}
void ADDS(XReg xd, XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    ADDS(xd, xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void ADDS(WReg wd, WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00101011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void ADDS(XReg xd, XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10101011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ADR(XReg xd, PageOffset<21, 0> label)
{
    emit<"0ii10000iiiiiiiiiiiiiiiiiiiddddd", "d", "i">(xd, label);
}
void ADRP(XReg xd, PageOffset<21, 12> label)
{
    emit<"1ii10000iiiiiiiiiiiiiiiiiiiddddd", "d", "i">(xd, label);
}
void AND(WRegWsp wd, WReg wn, BitImm32 imm)
{
    emit<"0001001000rrrrrrssssssnnnnnddddd", "d", "n", "rs">(wd, wn, imm);
}
void AND(XRegSp xd, XReg xn, BitImm64 imm)
{
    emit<"100100100Nrrrrrrssssssnnnnnddddd", "d", "n", "Nrs">(xd, xn, imm);
}
void AND(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00001010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void AND(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10001010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ANDS(WReg wd, WReg wn, BitImm32 imm)
{
    emit<"0111001000rrrrrrssssssnnnnnddddd", "d", "n", "rs">(wd, wn, imm);
}
void ANDS(XReg xd, XReg xn, BitImm64 imm)
{
    emit<"111100100Nrrrrrrssssssnnnnnddddd", "d", "n", "Nrs">(xd, xn, imm);
}
void ANDS(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void ANDS(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ASR(WReg wd, WReg wn, Imm<5> shift_amount)
{
    emit<"0001001100rrrrrr011111nnnnnddddd", "d", "n", "r">(wd, wn, shift_amount);
}
void ASR(XReg xd, XReg xn, Imm<6> shift_amount)
{
    emit<"1001001101rrrrrr111111nnnnnddddd", "d", "n", "r">(xd, xn, shift_amount);
}
void ASR(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001010nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void ASR(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001010nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void ASRV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001010nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void ASRV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001010nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void AT(AtOp op, XReg xt)
{
    emit<"1101010100001ooo0111100Mooottttt", "oMo", "t">(op, xt);
}
void B(AddrOffset<28, 2> label)
{
    emit<"000101iiiiiiiiiiiiiiiiiiiiiiiiii", "i">(label);
}
void B(Cond cond, AddrOffset<21, 2> label)
{
    emit<"01010100iiiiiiiiiiiiiiiiiii0cccc", "c", "i">(cond, label);
}
void BFI(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0011001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, (~lsb.value() + 1) & 31, width.value() - 1);
}
void BFI(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1011001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, (~lsb.value() + 1) & 63, width.value() - 1);
}
void BFM(WReg wd, WReg wn, Imm<5> immr, Imm<5> imms)
{
    emit<"0011001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, immr, imms);
}
void BFM(XReg xd, XReg xn, Imm<6> immr, Imm<6> imms)
{
    emit<"1011001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, immr, imms);
}
void BFXIL(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0011001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, lsb.value(), lsb.value() + width.value() - 1);
}
void BFXIL(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1011001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, lsb.value(), lsb.value() + width.value() - 1);
}
void BIC(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00001010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void BIC(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10001010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void BICS(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void BICS(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void BL(AddrOffset<28, 2> label)
{
    emit<"100101iiiiiiiiiiiiiiiiiiiiiiiiii", "i">(label);
}
void BLR(XReg xn)
{
    emit<"1101011000111111000000nnnnn00000", "n">(xn);
}
void BR(XReg xn)
{
    emit<"1101011000011111000000nnnnn00000", "n">(xn);
}
void BRK(Imm<16> imm)
{
    emit<"11010100001iiiiiiiiiiiiiiii00000", "i">(imm);
}
void CBNZ(WReg wt, AddrOffset<21, 2> label)
{
    emit<"00110101iiiiiiiiiiiiiiiiiiittttt", "t", "i">(wt, label);
}
void CBNZ(XReg xt, AddrOffset<21, 2> label)
{
    emit<"10110101iiiiiiiiiiiiiiiiiiittttt", "t", "i">(xt, label);
}
void CBZ(WReg wt, AddrOffset<21, 2> label)
{
    emit<"00110100iiiiiiiiiiiiiiiiiiittttt", "t", "i">(wt, label);
}
void CBZ(XReg xt, AddrOffset<21, 2> label)
{
    emit<"10110100iiiiiiiiiiiiiiiiiiittttt", "t", "i">(xt, label);
}
void CCMN(WReg wn, Imm<5> imm, Imm<4> nzcv, Cond cond)
{
    emit<"00111010010iiiiicccc10nnnnn0ffff", "n", "i", "f", "c">(wn, imm, nzcv, cond);
}
void CCMN(XReg xn, Imm<5> imm, Imm<4> nzcv, Cond cond)
{
    emit<"10111010010iiiiicccc10nnnnn0ffff", "n", "i", "f", "c">(xn, imm, nzcv, cond);
}
void CCMN(WReg wn, WReg wm, Imm<4> nzcv, Cond cond)
{
    emit<"00111010010mmmmmcccc00nnnnn0ffff", "n", "m", "f", "c">(wn, wm, nzcv, cond);
}
void CCMN(XReg xn, XReg xm, Imm<4> nzcv, Cond cond)
{
    emit<"10111010010mmmmmcccc00nnnnn0ffff", "n", "m", "f", "c">(xn, xm, nzcv, cond);
}
void CCMP(WReg wn, Imm<5> imm, Imm<4> nzcv, Cond cond)
{
    emit<"01111010010iiiiicccc10nnnnn0ffff", "n", "i", "f", "c">(wn, imm, nzcv, cond);
}
void CCMP(XReg xn, Imm<5> imm, Imm<4> nzcv, Cond cond)
{
    emit<"11111010010iiiiicccc10nnnnn0ffff", "n", "i", "f", "c">(xn, imm, nzcv, cond);
}
void CCMP(WReg wn, WReg wm, Imm<4> nzcv, Cond cond)
{
    emit<"01111010010mmmmmcccc00nnnnn0ffff", "n", "m", "f", "c">(wn, wm, nzcv, cond);
}
void CCMP(XReg xn, XReg xm, Imm<4> nzcv, Cond cond)
{
    emit<"11111010010mmmmmcccc00nnnnn0ffff", "n", "m", "f", "c">(xn, xm, nzcv, cond);
}
void CINC(WReg wd, WReg wn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"00011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(wd, wn, wn, invert(cond));
}
void CINC(XReg xd, XReg xn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"10011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(xd, xn, xn, invert(cond));
}
void CINV(WReg wd, WReg wn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"01011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(wd, wn, wn, invert(cond));
}
void CINV(XReg xd, XReg xn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"11011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(xd, xn, xn, invert(cond));
}
void CLREX(Imm<4> imm = 15)
{
    emit<"11010101000000110011MMMM01011111", "M">(imm);
}
void CLS(WReg wd, WReg wn)
{
    emit<"0101101011000000000101nnnnnddddd", "d", "n">(wd, wn);
}
void CLS(XReg xd, XReg xn)
{
    emit<"1101101011000000000101nnnnnddddd", "d", "n">(xd, xn);
}
void CLZ(WReg wd, WReg wn)
{
    emit<"0101101011000000000100nnnnnddddd", "d", "n">(wd, wn);
}
void CLZ(XReg xd, XReg xn)
{
    emit<"1101101011000000000100nnnnnddddd", "d", "n">(xd, xn);
}
void CMN(WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wn);
    emit<"00101011001mmmmmxxxiiinnnnn11111", "n", "m", "x", "i">(wn, wm, ext, shift_amount);
}
void CMN(XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xn);
    addsubext_verify_reg_size(ext, rm);
    emit<"10101011001mmmmmxxxiiinnnnn11111", "n", "m", "x", "i">(xn, rm, ext, shift_amount);
}
void CMN(WRegWsp wn, AddSubImm imm)
{
    emit<"001100010siiiiiiiiiiiinnnnn11111", "n", "si">(wn, imm);
}
void CMN(WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    CMN(wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void CMN(XRegSp xn, AddSubImm imm)
{
    emit<"101100010siiiiiiiiiiiinnnnn11111", "n", "si">(xn, imm);
}
void CMN(XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    CMN(xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void CMN(WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00101011ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(wn, wm, shift, shift_amount);
}
void CMN(XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10101011ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(xn, xm, shift, shift_amount);
}
void CMP(WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wn);
    emit<"01101011001mmmmmxxxiiinnnnn11111", "n", "m", "x", "i">(wn, wm, ext, shift_amount);
}
void CMP(XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xn);
    addsubext_verify_reg_size(ext, rm);
    emit<"11101011001mmmmmxxxiiinnnnn11111", "n", "m", "x", "i">(xn, rm, ext, shift_amount);
}
void CMP(WRegWsp wn, AddSubImm imm)
{
    emit<"011100010siiiiiiiiiiiinnnnn11111", "n", "si">(wn, imm);
}
void CMP(WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    CMP(wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void CMP(XRegSp xn, AddSubImm imm)
{
    emit<"111100010siiiiiiiiiiiinnnnn11111", "n", "si">(xn, imm);
}
void CMP(XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    CMP(xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void CMP(WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101011ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(wn, wm, shift, shift_amount);
}
void CMP(XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101011ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(xn, xm, shift, shift_amount);
}
void CNEG(WReg wd, WReg wn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"01011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(wd, wn, wn, invert(cond));
}
void CNEG(XReg xd, XReg xn, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"11011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(xd, xn, xn, invert(cond));
}
void CRC32B(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32H(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010001nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32W(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010010nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32X(WReg wd, WReg wn, XReg xm)
{
    emit<"10011010110mmmmm010011nnnnnddddd", "d", "n", "m">(wd, wn, xm);
}
void CRC32CB(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010100nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32CH(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010101nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32CW(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm010110nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void CRC32CX(WReg wd, WReg wn, XReg xm)
{
    emit<"10011010110mmmmm010111nnnnnddddd", "d", "n", "m">(wd, wn, xm);
}
void CSDB()
{
    emit<"11010101000000110010001010011111">();
}
void CSEL(WReg wd, WReg wn, WReg wm, Cond cond)
{
    emit<"00011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(wd, wn, wm, cond);
}
void CSEL(XReg xd, XReg xn, XReg xm, Cond cond)
{
    emit<"10011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(xd, xn, xm, cond);
}
void CSET(WReg wd, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"0001101010011111cccc0111111ddddd", "d", "c">(wd, invert(cond));
}
void CSET(XReg xd, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"1001101010011111cccc0111111ddddd", "d", "c">(xd, invert(cond));
}
void CSETM(WReg wd, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"0101101010011111cccc0011111ddddd", "d", "c">(wd, invert(cond));
}
void CSETM(XReg xd, Cond cond)
{
    if (cond == Cond::AL || cond == Cond::NV)
        throw OaknutException{ExceptionType::InvalidCond};
    emit<"1101101010011111cccc0011111ddddd", "d", "c">(xd, invert(cond));
}
void CSINC(WReg wd, WReg wn, WReg wm, Cond cond)
{
    emit<"00011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(wd, wn, wm, cond);
}
void CSINC(XReg xd, XReg xn, XReg xm, Cond cond)
{
    emit<"10011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(xd, xn, xm, cond);
}
void CSINV(WReg wd, WReg wn, WReg wm, Cond cond)
{
    emit<"01011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(wd, wn, wm, cond);
}
void CSINV(XReg xd, XReg xn, XReg xm, Cond cond)
{
    emit<"11011010100mmmmmcccc00nnnnnddddd", "d", "n", "m", "c">(xd, xn, xm, cond);
}
void CSNEG(WReg wd, WReg wn, WReg wm, Cond cond)
{
    emit<"01011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(wd, wn, wm, cond);
}
void CSNEG(XReg xd, XReg xn, XReg xm, Cond cond)
{
    emit<"11011010100mmmmmcccc01nnnnnddddd", "d", "n", "m", "c">(xd, xn, xm, cond);
}
void DC(DcOp op, XReg xt)
{
    emit<"1101010100001ooo0111MMMMooottttt", "oMo", "t">(op, xt);
}
void DCPS1(Imm<16> imm = 0)
{
    emit<"11010100101iiiiiiiiiiiiiiii00001", "i">(imm);
}
void DCPS2(Imm<16> imm = 0)
{
    emit<"11010100101iiiiiiiiiiiiiiii00010", "i">(imm);
}
void DMB(BarrierOp imm)
{
    emit<"11010101000000110011MMMM10111111", "M">(imm);
}
void DRPS()
{
    emit<"11010110101111110000001111100000">();
}
void DSB(BarrierOp imm)
{
    emit<"11010101000000110011MMMM10011111", "M">(imm);
}
void EON(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01001010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void EON(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11001010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void EOR(WRegWsp wd, WReg wn, BitImm32 imm)
{
    emit<"0101001000rrrrrrssssssnnnnnddddd", "d", "n", "rs">(wd, wn, imm);
}
void EOR(XRegSp xd, XReg xn, BitImm64 imm)
{
    emit<"110100100Nrrrrrrssssssnnnnnddddd", "d", "n", "Nrs">(xd, xn, imm);
}
void EOR(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01001010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void EOR(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11001010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ERET()
{
    emit<"11010110100111110000001111100000">();
}
void EXTR(WReg wd, WReg wn, WReg wm, Imm<5> imms)
{
    emit<"00010011100mmmmm0sssssnnnnnddddd", "d", "n", "m", "s">(wd, wn, wm, imms);
}
void EXTR(XReg xd, XReg xn, XReg xm, Imm<6> imms)
{
    emit<"10010011110mmmmmssssssnnnnnddddd", "d", "n", "m", "s">(xd, xn, xm, imms);
}
void HINT(Imm<7> imm)
{
    emit<"11010101000000110010MMMMooo11111", "Mo">(imm);
}
void HLT(Imm<16> imm)
{
    emit<"11010100010iiiiiiiiiiiiiiii00000", "i">(imm);
}
void HVC(Imm<16> imm)
{
    emit<"11010100000iiiiiiiiiiiiiiii00010", "i">(imm);
}
void IC(IcOp op, XReg xt)
{
    emit<"1101010100001ooo0111MMMMooottttt", "oMo", "t">(op, xt);
}
void ISB(BarrierOp imm = BarrierOp::SY)
{
    emit<"11010101000000110011MMMM11011111", "M">(imm);
}
void LDAR(WReg wt, XRegSp xn)
{
    emit<"1000100011011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDAR(XReg xt, XRegSp xn)
{
    emit<"1100100011011111111111nnnnnttttt", "t", "n">(xt, xn);
}
void LDARB(WReg wt, XRegSp xn)
{
    emit<"0000100011011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDARH(WReg wt, XRegSp xn)
{
    emit<"0100100011011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDAXP(WReg wt1, WReg wt2, XRegSp xn)
{
    emit<"10001000011111111uuuuunnnnnttttt", "t", "u", "n">(wt1, wt2, xn);
}
void LDAXP(XReg xt1, XReg xt2, XRegSp xn)
{
    emit<"11001000011111111uuuuunnnnnttttt", "t", "u", "n">(xt1, xt2, xn);
}
void LDAXR(WReg wt, XRegSp xn)
{
    emit<"1000100001011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDAXR(XReg xt, XRegSp xn)
{
    emit<"1100100001011111111111nnnnnttttt", "t", "n">(xt, xn);
}
void LDAXRB(WReg wt, XRegSp xn)
{
    emit<"0000100001011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDAXRH(WReg wt, XRegSp xn)
{
    emit<"0100100001011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void LDNP(WReg wt1, WReg wt2, XRegSp xn, SOffset<9, 2> imm = 0)
{
    emit<"0010100001iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void LDNP(XReg xt1, XReg xt2, XRegSp xn, SOffset<10, 3> imm = 0)
{
    emit<"1010100001iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDP(WReg wt1, WReg wt2, XRegSp xn, PostIndexed, SOffset<9, 2> imm)
{
    emit<"0010100011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void LDP(XReg xt1, XReg xt2, XRegSp xn, PostIndexed, SOffset<10, 3> imm)
{
    emit<"1010100011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDP(WReg wt1, WReg wt2, XRegSp xn, PreIndexed, SOffset<9, 2> imm)
{
    emit<"0010100111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void LDP(XReg xt1, XReg xt2, XRegSp xn, PreIndexed, SOffset<10, 3> imm)
{
    emit<"1010100111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDP(WReg wt1, WReg wt2, XRegSp xn, SOffset<9, 2> imm = 0)
{
    emit<"0010100101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void LDP(XReg xt1, XReg xt2, XRegSp xn, SOffset<10, 3> imm = 0)
{
    emit<"1010100101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDPSW(XReg xt1, XReg xt2, XRegSp xn, PostIndexed, SOffset<9, 2> imm)
{
    emit<"0110100011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDPSW(XReg xt1, XReg xt2, XRegSp xn, PreIndexed, SOffset<9, 2> imm)
{
    emit<"0110100111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDPSW(XReg xt1, XReg xt2, XRegSp xn, SOffset<9, 2> imm = 0)
{
    emit<"0110100101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void LDR(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"10111000010iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDR(XReg xt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"11111000010iiiiiiiii01nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDR(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"10111000010iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDR(XReg xt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"11111000010iiiiiiiii11nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDR(WReg wt, XRegSp xn, POffset<14, 2> pimm = 0)
{
    emit<"1011100101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void LDR(XReg xt, XRegSp xn, POffset<15, 3> pimm = 0)
{
    emit<"1111100101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(xt, xn, pimm);
}
void LDR(WReg wt, AddrOffset<21, 2> label)
{
    emit<"00011000iiiiiiiiiiiiiiiiiiittttt", "t", "i">(wt, label);
}
void LDR(XReg xt, AddrOffset<21, 2> label)
{
    emit<"01011000iiiiiiiiiiiiiiiiiiittttt", "t", "i">(xt, label);
}
void LDR(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 2> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"10111000011mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void LDR(XReg xt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 3> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"11111000011mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(xt, xn, rm, ext, amount);
}
void LDRB(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"00111000010iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRB(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"00111000010iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRB(WReg wt, XRegSp xn, POffset<12, 0> pimm = 0)
{
    emit<"0011100101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void LDRB(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111000011mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void LDRH(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"01111000010iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRH(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"01111000010iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRH(WReg wt, XRegSp xn, POffset<13, 1> pimm = 0)
{
    emit<"0111100101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void LDRH(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111000011mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void LDRSB(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"00111000110iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRSB(XReg xt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"00111000100iiiiiiiii01nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSB(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"00111000110iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRSB(XReg xt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"00111000100iiiiiiiii11nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSB(WReg wt, XRegSp xn, POffset<12, 0> pimm = 0)
{
    emit<"0011100111iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void LDRSB(XReg xt, XRegSp xn, POffset<12, 0> pimm = 0)
{
    emit<"0011100110iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(xt, xn, pimm);
}
void LDRSB(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111000111mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void LDRSB(WReg wt, XRegSp xn, XReg xm, ImmChoice<0, 0> amount = 0)
{
    emit<"00111000111mmmmm011S10nnnnnttttt", "t", "n", "m", "S">(wt, xn, xm, amount);
}
void LDRSB(XReg xt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111000101mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(xt, xn, rm, ext, amount);
}
void LDRSB(XReg xt, XRegSp xn, XReg xm, ImmChoice<0, 0> amount = 0)
{
    emit<"00111000101mmmmm011S10nnnnnttttt", "t", "n", "m", "S">(xt, xn, xm, amount);
}
void LDRSH(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"01111000110iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRSH(XReg xt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"01111000100iiiiiiiii01nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSH(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"01111000110iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDRSH(XReg xt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"01111000100iiiiiiiii11nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSH(WReg wt, XRegSp xn, POffset<13, 1> pimm = 0)
{
    emit<"0111100111iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void LDRSH(XReg xt, XRegSp xn, POffset<13, 1> pimm = 0)
{
    emit<"0111100110iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(xt, xn, pimm);
}
void LDRSH(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111000111mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void LDRSH(XReg xt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111000101mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(xt, xn, rm, ext, amount);
}
void LDRSW(XReg xt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"10111000100iiiiiiiii01nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSW(XReg xt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"10111000100iiiiiiiii11nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDRSW(XReg xt, XRegSp xn, POffset<14, 2> pimm = 0)
{
    emit<"1011100110iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(xt, xn, pimm);
}
void LDRSW(XReg xt, AddrOffset<21, 2> label)
{
    emit<"10011000iiiiiiiiiiiiiiiiiiittttt", "t", "i">(xt, label);
}
void LDRSW(XReg xt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 2> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"10111000101mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(xt, xn, rm, ext, amount);
}
void LDTR(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000010iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDTR(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"11111000010iiiiiiiii10nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDTRB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000010iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDTRH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000010iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDTRSB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000110iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDTRSB(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000100iiiiiiiii10nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDTRSH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000110iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDTRSH(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000100iiiiiiiii10nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDTRSW(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000100iiiiiiiii10nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDUR(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000010iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDUR(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"11111000010iiiiiiiii00nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDURB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000010iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDURH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000010iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDURSB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000110iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDURSB(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000100iiiiiiiii00nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDURSH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000110iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void LDURSH(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000100iiiiiiiii00nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDURSW(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000100iiiiiiiii00nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void LDXP(WReg wt1, WReg wt2, XRegSp xn)
{
    emit<"10001000011111110uuuuunnnnnttttt", "t", "u", "n">(wt1, wt2, xn);
}
void LDXP(XReg xt1, XReg xt2, XRegSp xn)
{
    emit<"11001000011111110uuuuunnnnnttttt", "t", "u", "n">(xt1, xt2, xn);
}
void LDXR(WReg wt, XRegSp xn)
{
    emit<"1000100001011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LDXR(XReg xt, XRegSp xn)
{
    emit<"1100100001011111011111nnnnnttttt", "t", "n">(xt, xn);
}
void LDXRB(WReg wt, XRegSp xn)
{
    emit<"0000100001011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LDXRH(WReg wt, XRegSp xn)
{
    emit<"0100100001011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LSL(WReg wd, WReg wn, LslShift<32> shift_amount)
{
    emit<"0101001100rrrrrrssssssnnnnnddddd", "d", "n", "rs">(wd, wn, shift_amount);
}
void LSL(XReg xd, XReg xn, LslShift<64> shift_amount)
{
    emit<"1101001101rrrrrrssssssnnnnnddddd", "d", "n", "rs">(xd, xn, shift_amount);
}
void LSL(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void LSL(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void LSLV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void LSLV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void LSR(WReg wd, WReg wn, Imm<5> shift_amount)
{
    emit<"0101001100rrrrrr011111nnnnnddddd", "d", "n", "r">(wd, wn, shift_amount);
}
void LSR(XReg xd, XReg xn, Imm<6> shift_amount)
{
    emit<"1101001101rrrrrr111111nnnnnddddd", "d", "n", "r">(xd, xn, shift_amount);
}
void LSR(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001001nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void LSR(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001001nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void LSRV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001001nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void LSRV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001001nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void MADD(WReg wd, WReg wn, WReg wm, WReg wa)
{
    emit<"00011011000mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(wd, wn, wm, wa);
}
void MADD(XReg xd, XReg xn, XReg xm, XReg xa)
{
    emit<"10011011000mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(xd, xn, xm, xa);
}
void MNEG(WReg wd, WReg wn, WReg wm)
{
    emit<"00011011000mmmmm111111nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void MNEG(XReg xd, XReg xn, XReg xm)
{
    emit<"10011011000mmmmm111111nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void MOV(WReg wd, WReg wm)
{
    emit<"00101010000mmmmm00000011111ddddd", "d", "m">(wd, wm);
}
void MOV(XReg xd, XReg xm)
{
    emit<"10101010000mmmmm00000011111ddddd", "d", "m">(xd, xm);
}
void MOV(WRegWsp wd, WRegWsp wn)
{
    emit<"0001000100000000000000nnnnnddddd", "d", "n">(wd, wn);
}
void MOV(XRegSp xd, XRegSp xn)
{
    emit<"1001000100000000000000nnnnnddddd", "d", "n">(xd, xn);
}
void MOVK(WReg wd, MovImm16 imm)
{
    emit<"0111001010hiiiiiiiiiiiiiiiiddddd", "d", "hi">(wd, imm);
}
void MOVK(XReg xd, MovImm16 imm)
{
    emit<"111100101hhiiiiiiiiiiiiiiiiddddd", "d", "hi">(xd, imm);
}
void MOVN(WReg wd, MovImm16 imm)
{
    emit<"0001001010hiiiiiiiiiiiiiiiiddddd", "d", "hi">(wd, imm);
}
void MOVN(XReg xd, MovImm16 imm)
{
    emit<"100100101hhiiiiiiiiiiiiiiiiddddd", "d", "hi">(xd, imm);
}
void MOVZ(WReg wd, MovImm16 imm)
{
    emit<"0101001010hiiiiiiiiiiiiiiiiddddd", "d", "hi">(wd, imm);
}
void MOVZ(XReg xd, MovImm16 imm)
{
    emit<"110100101hhiiiiiiiiiiiiiiiiddddd", "d", "hi">(xd, imm);
}
void MRS(XReg xt, SystemReg systemreg)
{
    emit<"110101010011ooooNNNNMMMMooottttt", "t", "oNMo">(xt, systemreg);
}
void MSR(PstateField pstatefield, Imm<4> imm)
{
    emit<"1101010100000ooo0100MMMMooo11111", "o", "M">(pstatefield, imm);
}
void MSR(SystemReg systemreg, XReg xt)
{
    emit<"110101010001ooooNNNNMMMMooottttt", "oNMo", "t">(systemreg, xt);
}
void MSUB(WReg wd, WReg wn, WReg wm, WReg wa)
{
    emit<"00011011000mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(wd, wn, wm, wa);
}
void MSUB(XReg xd, XReg xn, XReg xm, XReg xa)
{
    emit<"10011011000mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(xd, xn, xm, xa);
}
void MUL(WReg wd, WReg wn, WReg wm)
{
    emit<"00011011000mmmmm011111nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void MUL(XReg xd, XReg xn, XReg xm)
{
    emit<"10011011000mmmmm011111nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void MVN(WReg wd, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00101010ss1mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(wd, wm, shift, shift_amount);
}
void MVN(XReg xd, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10101010ss1mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(xd, xm, shift, shift_amount);
}
void NEG(WReg wd, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01001011ss0mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(wd, wm, shift, shift_amount);
}
void NEG(XReg xd, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11001011ss0mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(xd, xm, shift, shift_amount);
}
void NEGS(WReg wd, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101011ss0mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(wd, wm, shift, shift_amount);
}
void NEGS(XReg xd, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101011ss0mmmmmiiiiii11111ddddd", "d", "m", "s", "i">(xd, xm, shift, shift_amount);
}
void NGC(WReg wd, WReg wm)
{
    emit<"01011010000mmmmm00000011111ddddd", "d", "m">(wd, wm);
}
void NGC(XReg xd, XReg xm)
{
    emit<"11011010000mmmmm00000011111ddddd", "d", "m">(xd, xm);
}
void NGCS(WReg wd, WReg wm)
{
    emit<"01111010000mmmmm00000011111ddddd", "d", "m">(wd, wm);
}
void NGCS(XReg xd, XReg xm)
{
    emit<"11111010000mmmmm00000011111ddddd", "d", "m">(xd, xm);
}
void NOP()
{
    emit<"11010101000000110010000000011111">();
}
void ORN(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00101010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void ORN(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10101010ss1mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void ORR(WRegWsp wd, WReg wn, BitImm32 imm)
{
    emit<"0011001000rrrrrrssssssnnnnnddddd", "d", "n", "rs">(wd, wn, imm);
}
void ORR(XRegSp xd, XReg xn, BitImm64 imm)
{
    emit<"101100100Nrrrrrrssssssnnnnnddddd", "d", "n", "Nrs">(xd, xn, imm);
}
void ORR(WReg wd, WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"00101010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void ORR(XReg xd, XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"10101010ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void PRFM(PrfOp prfop, XRegSp xn, POffset<15, 3> pimm = 0)
{
    emit<"1111100110iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(prfop, xn, pimm);
}
void PRFM(PrfOp prfop, AddrOffset<21, 2> label)
{
    emit<"11011000iiiiiiiiiiiiiiiiiiittttt", "t", "i">(prfop, label);
}
void PRFM(PrfOp prfop, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 3> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"11111000101mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(prfop, xn, rm, ext, amount);
}
void PRFUM(PrfOp prfop, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"11111000100iiiiiiiii00nnnnnttttt", "t", "n", "i">(prfop, xn, simm);
}
void PSSBB()
{
    emit<"11010101000000110011010010011111">();
}
void RBIT(WReg wd, WReg wn)
{
    emit<"0101101011000000000000nnnnnddddd", "d", "n">(wd, wn);
}
void RBIT(XReg xd, XReg xn)
{
    emit<"1101101011000000000000nnnnnddddd", "d", "n">(xd, xn);
}
void RET(XReg xn)
{
    emit<"1101011001011111000000nnnnn00000", "n">(xn);
}
void REV(WReg wd, WReg wn)
{
    emit<"0101101011000000000010nnnnnddddd", "d", "n">(wd, wn);
}
void REV(XReg xd, XReg xn)
{
    emit<"1101101011000000000011nnnnnddddd", "d", "n">(xd, xn);
}
void REV16(WReg wd, WReg wn)
{
    emit<"0101101011000000000001nnnnnddddd", "d", "n">(wd, wn);
}
void REV16(XReg xd, XReg xn)
{
    emit<"1101101011000000000001nnnnnddddd", "d", "n">(xd, xn);
}
void REV32(XReg xd, XReg xn)
{
    emit<"1101101011000000000010nnnnnddddd", "d", "n">(xd, xn);
}
void REV64(XReg xd, XReg xn)
{
    emit<"1101101011000000000011nnnnnddddd", "d", "n">(xd, xn);
}
void ROR(WReg wd, WReg ws, Imm<5> shift_amount)
{
    emit<"00010011100mmmmm0sssssnnnnnddddd", "d", "n", "m", "s">(wd, ws, ws, shift_amount);
}
void ROR(XReg xd, XReg xs, Imm<6> shift_amount)
{
    emit<"10010011110mmmmmssssssnnnnnddddd", "d", "n", "m", "s">(xd, xs, xs, shift_amount);
}
void ROR(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001011nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void ROR(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001011nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void RORV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm001011nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void RORV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm001011nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void SB()
{
    emit<"11010101000000110011000011111111">();
}
void SBC(WReg wd, WReg wn, WReg wm)
{
    emit<"01011010000mmmmm000000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void SBC(XReg xd, XReg xn, XReg xm)
{
    emit<"11011010000mmmmm000000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void SBCS(WReg wd, WReg wn, WReg wm)
{
    emit<"01111010000mmmmm000000nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void SBCS(XReg xd, XReg xn, XReg xm)
{
    emit<"11111010000mmmmm000000nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void SBFIZ(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0001001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, (~lsb.value() + 1) & 31, width.value() - 1);
}
void SBFIZ(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1001001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, (~lsb.value() + 1) & 63, width.value() - 1);
}
void SBFM(WReg wd, WReg wn, Imm<5> immr, Imm<5> imms)
{
    emit<"0001001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, immr, imms);
}
void SBFM(XReg xd, XReg xn, Imm<6> immr, Imm<6> imms)
{
    emit<"1001001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, immr, imms);
}
void SBFX(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0001001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, lsb.value(), lsb.value() + width.value() - 1);
}
void SBFX(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1001001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, lsb.value(), lsb.value() + width.value() - 1);
}
void SDIV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm000011nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void SDIV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm000011nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void SEV()
{
    emit<"11010101000000110010000010011111">();
}
void SEVL()
{
    emit<"11010101000000110010000010111111">();
}
void SMADDL(XReg xd, WReg wn, WReg wm, XReg xa)
{
    emit<"10011011001mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(xd, wn, wm, xa);
}
void SMNEGL(XReg xd, WReg wn, WReg wm)
{
    emit<"10011011001mmmmm111111nnnnnddddd", "d", "n", "m">(xd, wn, wm);
}
void SMSUBL(XReg xd, WReg wn, WReg wm, XReg xa)
{
    emit<"10011011001mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(xd, wn, wm, xa);
}
void SMULH(XReg xd, XReg xn, XReg xm)
{
    emit<"10011011010mmmmm011111nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void SMULL(XReg xd, WReg wn, WReg wm)
{
    emit<"10011011001mmmmm011111nnnnnddddd", "d", "n", "m">(xd, wn, wm);
}
void SSBB()
{
    emit<"11010101000000110011000010011111">();
}
void STLR(WReg wt, XRegSp xn)
{
    emit<"1000100010011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void STLR(XReg xt, XRegSp xn)
{
    emit<"1100100010011111111111nnnnnttttt", "t", "n">(xt, xn);
}
void STLRB(WReg wt, XRegSp xn)
{
    emit<"0000100010011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void STLRH(WReg wt, XRegSp xn)
{
    emit<"0100100010011111111111nnnnnttttt", "t", "n">(wt, xn);
}
void STLXP(WReg ws, WReg wt1, WReg wt2, XRegSp xn)
{
    emit<"10001000001sssss1uuuuunnnnnttttt", "s", "t", "u", "n">(ws, wt1, wt2, xn);
}
void STLXP(WReg ws, XReg xt1, XReg xt2, XRegSp xn)
{
    emit<"11001000001sssss1uuuuunnnnnttttt", "s", "t", "u", "n">(ws, xt1, xt2, xn);
}
void STLXR(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000000sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STLXR(WReg ws, XReg xt, XRegSp xn)
{
    emit<"11001000000sssss111111nnnnnttttt", "s", "t", "n">(ws, xt, xn);
}
void STLXRB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000000sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STLXRH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000000sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STNP(WReg wt1, WReg wt2, XRegSp xn, SOffset<9, 2> imm = 0)
{
    emit<"0010100000iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void STNP(XReg xt1, XReg xt2, XRegSp xn, SOffset<10, 3> imm = 0)
{
    emit<"1010100000iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void STP(WReg wt1, WReg wt2, XRegSp xn, PostIndexed, SOffset<9, 2> imm)
{
    emit<"0010100010iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void STP(XReg xt1, XReg xt2, XRegSp xn, PostIndexed, SOffset<10, 3> imm)
{
    emit<"1010100010iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void STP(WReg wt1, WReg wt2, XRegSp xn, PreIndexed, SOffset<9, 2> imm)
{
    emit<"0010100110iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void STP(XReg xt1, XReg xt2, XRegSp xn, PreIndexed, SOffset<10, 3> imm)
{
    emit<"1010100110iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void STP(WReg wt1, WReg wt2, XRegSp xn, SOffset<9, 2> imm = 0)
{
    emit<"0010100100iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(wt1, wt2, xn, imm);
}
void STP(XReg xt1, XReg xt2, XRegSp xn, SOffset<10, 3> imm = 0)
{
    emit<"1010100100iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(xt1, xt2, xn, imm);
}
void STR(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"10111000000iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STR(XReg xt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"11111000000iiiiiiiii01nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void STR(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"10111000000iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STR(XReg xt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"11111000000iiiiiiiii11nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void STR(WReg wt, XRegSp xn, POffset<14, 2> pimm = 0)
{
    emit<"1011100100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void STR(XReg xt, XRegSp xn, POffset<15, 3> pimm = 0)
{
    emit<"1111100100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(xt, xn, pimm);
}
void STR(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 2> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"10111000001mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void STR(XReg xt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 3> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"11111000001mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(xt, xn, rm, ext, amount);
}
void STRB(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"00111000000iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STRB(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"00111000000iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STRB(WReg wt, XRegSp xn, POffset<12, 0> pimm = 0)
{
    emit<"0011100100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void STRB(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111000001mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void STRB(WReg wt, XRegSp xn, XReg xm, ImmChoice<0, 0> amount = 0)
{
    emit<"00111000001mmmmm011S10nnnnnttttt", "t", "n", "m", "S">(wt, xn, xm, amount);
}
void STRH(WReg wt, XRegSp xn, PostIndexed, SOffset<9, 0> simm)
{
    emit<"01111000000iiiiiiiii01nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STRH(WReg wt, XRegSp xn, PreIndexed, SOffset<9, 0> simm)
{
    emit<"01111000000iiiiiiiii11nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STRH(WReg wt, XRegSp xn, POffset<13, 1> pimm = 0)
{
    emit<"0111100100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(wt, xn, pimm);
}
void STRH(WReg wt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111000001mmmmmxxxS10nnnnnttttt", "t", "n", "m", "x", "S">(wt, xn, rm, ext, amount);
}
void STTR(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000000iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STTR(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"11111000000iiiiiiiii10nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void STTRB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000000iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STTRH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000000iiiiiiiii10nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STUR(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"10111000000iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STUR(XReg xt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"11111000000iiiiiiiii00nnnnnttttt", "t", "n", "i">(xt, xn, simm);
}
void STURB(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"00111000000iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STURH(WReg wt, XRegSp xn, SOffset<9, 0> simm = 0)
{
    emit<"01111000000iiiiiiiii00nnnnnttttt", "t", "n", "i">(wt, xn, simm);
}
void STXP(WReg ws, WReg wt1, WReg wt2, XRegSp xn)
{
    emit<"10001000001sssss0uuuuunnnnnttttt", "s", "t", "u", "n">(ws, wt1, wt2, xn);
}
void STXP(WReg ws, XReg xt1, XReg xt2, XRegSp xn)
{
    emit<"11001000001sssss0uuuuunnnnnttttt", "s", "t", "u", "n">(ws, xt1, xt2, xn);
}
void STXR(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000000sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STXR(WReg ws, XReg xt, XRegSp xn)
{
    emit<"11001000000sssss011111nnnnnttttt", "s", "t", "n">(ws, xt, xn);
}
void STXRB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000000sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STXRH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000000sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SUB(WRegWsp wd, WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wd);
    emit<"01001011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(wd, wn, wm, ext, shift_amount);
}
void SUB(XRegSp xd, XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xd);
    addsubext_verify_reg_size(ext, rm);
    emit<"11001011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(xd, xn, rm, ext, shift_amount);
}
void SUB(WRegWsp wd, WRegWsp wn, AddSubImm imm)
{
    emit<"010100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(wd, wn, imm);
}
void SUB(WRegWsp wd, WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    SUB(wd, wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void SUB(XRegSp xd, XRegSp xn, AddSubImm imm)
{
    emit<"110100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(xd, xn, imm);
}
void SUB(XRegSp xd, XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    SUB(xd, xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void SUB(WReg wd, WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01001011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void SUB(XReg xd, XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11001011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void SUBS(WReg wd, WRegWsp wn, WReg wm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, wd);
    emit<"01101011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(wd, wn, wm, ext, shift_amount);
}
void SUBS(XReg xd, XRegSp xn, RReg rm, AddSubExt ext = AddSubExt::LSL, Imm<3> shift_amount = 0)
{
    addsubext_lsl_correction(ext, xd);
    addsubext_verify_reg_size(ext, rm);
    emit<"11101011001mmmmmxxxiiinnnnnddddd", "d", "n", "m", "x", "i">(xd, xn, rm, ext, shift_amount);
}
void SUBS(WReg wd, WRegWsp wn, AddSubImm imm)
{
    emit<"011100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(wd, wn, imm);
}
void SUBS(WReg wd, WRegWsp wn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    SUBS(wd, wn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void SUBS(XReg xd, XRegSp xn, AddSubImm imm)
{
    emit<"111100010siiiiiiiiiiiinnnnnddddd", "d", "n", "si">(xd, xn, imm);
}
void SUBS(XReg xd, XRegSp xn, Imm<12> imm, LslSymbol, ImmChoice<0, 12> shift_amount)
{
    SUBS(xd, xn, AddSubImm{imm.value(), static_cast<AddSubImmShift>(shift_amount.m_encoded)});
}
void SUBS(WReg wd, WReg wn, WReg wm, AddSubShift shift = AddSubShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(wd, wn, wm, shift, shift_amount);
}
void SUBS(XReg xd, XReg xn, XReg xm, AddSubShift shift = AddSubShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101011ss0mmmmmiiiiiinnnnnddddd", "d", "n", "m", "s", "i">(xd, xn, xm, shift, shift_amount);
}
void SVC(Imm<16> imm)
{
    emit<"11010100000iiiiiiiiiiiiiiii00001", "i">(imm);
}
void SXTB(WReg wd, WReg wn)
{
    emit<"0001001100000000000111nnnnnddddd", "d", "n">(wd, wn);
}
void SXTB(XReg xd, WReg wn)
{
    emit<"1001001101000000000111nnnnnddddd", "d", "n">(xd, wn);
}
void SXTH(WReg wd, WReg wn)
{
    emit<"0001001100000000001111nnnnnddddd", "d", "n">(wd, wn);
}
void SXTH(XReg xd, WReg wn)
{
    emit<"1001001101000000001111nnnnnddddd", "d", "n">(xd, wn);
}
void SXTW(XReg xd, WReg wn)
{
    emit<"1001001101000000011111nnnnnddddd", "d", "n">(xd, wn);
}
void TBNZ(RReg rt, Imm<6> imm, AddrOffset<16, 2> label)
{
    tbz_verify_reg_size(rt, imm);
    emit<"b0110111bbbbbiiiiiiiiiiiiiittttt", "t", "b", "i">(rt, imm, label);
}
void TBZ(RReg rt, Imm<6> imm, AddrOffset<16, 2> label)
{
    tbz_verify_reg_size(rt, imm);
    emit<"b0110110bbbbbiiiiiiiiiiiiiittttt", "t", "b", "i">(rt, imm, label);
}
void TLBI(TlbiOp op, XReg xt)
{
    emit<"1101010100001ooo1000MMMMooottttt", "oMo", "t">(op, xt);
}
void TST(WReg wn, BitImm32 imm)
{
    emit<"0111001000rrrrrrssssssnnnnn11111", "n", "rs">(wn, imm);
}
void TST(XReg xn, BitImm64 imm)
{
    emit<"111100100Nrrrrrrssssssnnnnn11111", "n", "Nrs">(xn, imm);
}
void TST(WReg wn, WReg wm, LogShift shift = LogShift::LSL, Imm<5> shift_amount = 0)
{
    emit<"01101010ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(wn, wm, shift, shift_amount);
}
void TST(XReg xn, XReg xm, LogShift shift = LogShift::LSL, Imm<6> shift_amount = 0)
{
    emit<"11101010ss0mmmmmiiiiiinnnnn11111", "n", "m", "s", "i">(xn, xm, shift, shift_amount);
}
void UBFIZ(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0101001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, (~lsb.value() + 1) & 31, width.value() - 1);
}
void UBFIZ(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1101001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, (~lsb.value() + 1) & 63, width.value() - 1);
}
void UBFM(WReg wd, WReg wn, Imm<5> immr, Imm<5> imms)
{
    emit<"0101001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, immr, imms);
}
void UBFM(XReg xd, XReg xn, Imm<6> immr, Imm<6> imms)
{
    emit<"1101001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, immr, imms);
}
void UBFX(WReg wd, WReg wn, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0101001100rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(wd, wn, lsb.value(), lsb.value() + width.value() - 1);
}
void UBFX(XReg xd, XReg xn, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1101001101rrrrrrssssssnnnnnddddd", "d", "n", "r", "s">(xd, xn, lsb.value(), lsb.value() + width.value() - 1);
}
void UDF(Imm<16> imm)
{
    emit<"0000000000000000iiiiiiiiiiiiiiii", "i">(imm);
}
void UDIV(WReg wd, WReg wn, WReg wm)
{
    emit<"00011010110mmmmm000010nnnnnddddd", "d", "n", "m">(wd, wn, wm);
}
void UDIV(XReg xd, XReg xn, XReg xm)
{
    emit<"10011010110mmmmm000010nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void UMADDL(XReg xd, WReg wn, WReg wm, XReg xa)
{
    emit<"10011011101mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(xd, wn, wm, xa);
}
void UMNEGL(XReg xd, WReg wn, WReg wm)
{
    emit<"10011011101mmmmm111111nnnnnddddd", "d", "n", "m">(xd, wn, wm);
}
void UMSUBL(XReg xd, WReg wn, WReg wm, XReg xa)
{
    emit<"10011011101mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(xd, wn, wm, xa);
}
void UMULH(XReg xd, XReg xn, XReg xm)
{
    emit<"10011011110mmmmm011111nnnnnddddd", "d", "n", "m">(xd, xn, xm);
}
void UMULL(XReg xd, WReg wn, WReg wm)
{
    emit<"10011011101mmmmm011111nnnnnddddd", "d", "n", "m">(xd, wn, wm);
}
void UXTB(WReg wd, WReg wn)
{
    emit<"0101001100000000000111nnnnnddddd", "d", "n">(wd, wn);
}
void UXTH(WReg wd, WReg wn)
{
    emit<"0101001100000000001111nnnnnddddd", "d", "n">(wd, wn);
}
void WFE()
{
    emit<"11010101000000110010000001011111">();
}
void WFI()
{
    emit<"11010101000000110010000001111111">();
}
void YIELD()
{
    emit<"11010101000000110010000000111111">();
}
