// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void ABS(DReg rd, DReg rn)
{
    emit<"0101111011100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ABS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADD(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADD(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN(VReg_8B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"00001110001mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN2(VReg_16B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110001mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN(VReg_4H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"00001110011mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN2(VReg_8H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110011mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN(VReg_2S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"00001110101mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDHN2(VReg_4S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110101mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(DReg rd, VReg_2D rn)
{
    emit<"0101111011110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADDP(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm101111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ADDV(BReg rd, VReg_8B rn)
{
    emit<"0000111000110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADDV(BReg rd, VReg_16B rn)
{
    emit<"0100111000110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADDV(HReg rd, VReg_4H rn)
{
    emit<"0000111001110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADDV(HReg rd, VReg_8H rn)
{
    emit<"0100111001110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void ADDV(SReg rd, VReg_4S rn)
{
    emit<"0100111010110001101110nnnnnddddd", "d", "n">(rd, rn);
}
void AESD(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000101000010110nnnnnddddd", "d", "n">(rd, rn);
}
void AESE(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000101000010010nnnnnddddd", "d", "n">(rd, rn);
}
void AESIMC(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000101000011110nnnnnddddd", "d", "n">(rd, rn);
}
void AESMC(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000101000011010nnnnnddddd", "d", "n">(rd, rn);
}
void AND(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void AND(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIC(VReg_4H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0010111100000vvv10c101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void BIC(VReg_8H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0110111100000vvv10c101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void BIC(VReg_2S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0010111100000vvv0cc101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void BIC(VReg_4S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0110111100000vvv0cc101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void BIC(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110011mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIC(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110011mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIF(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110111mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIF(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110111mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIT(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BIT(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BSL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110011mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void BSL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110011mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CLS(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLS(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CLZ(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100000010010nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMEQ(DReg rd, DReg rn, ImmConst<0>)
{
    emit<"0101111011100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_8B rd, VReg_8B rn, ImmConst<0>)
{
    emit<"0000111000100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_16B rd, VReg_16B rn, ImmConst<0>)
{
    emit<"0100111000100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_4H rd, VReg_4H rn, ImmConst<0>)
{
    emit<"0000111001100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_8H rd, VReg_8H rn, ImmConst<0>)
{
    emit<"0100111001100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_2S rd, VReg_2S rn, ImmConst<0>)
{
    emit<"0000111010100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_4S rd, VReg_4S rn, ImmConst<0>)
{
    emit<"0100111010100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMEQ(VReg_2D rd, VReg_2D rn, ImmConst<0>)
{
    emit<"0100111011100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGE(DReg rd, DReg rn, ImmConst<0>)
{
    emit<"0111111011100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_8B rd, VReg_8B rn, ImmConst<0>)
{
    emit<"0010111000100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_16B rd, VReg_16B rn, ImmConst<0>)
{
    emit<"0110111000100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_4H rd, VReg_4H rn, ImmConst<0>)
{
    emit<"0010111001100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_8H rd, VReg_8H rn, ImmConst<0>)
{
    emit<"0110111001100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_2S rd, VReg_2S rn, ImmConst<0>)
{
    emit<"0010111010100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_4S rd, VReg_4S rn, ImmConst<0>)
{
    emit<"0110111010100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGE(VReg_2D rd, VReg_2D rn, ImmConst<0>)
{
    emit<"0110111011100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMGT(DReg rd, DReg rn, ImmConst<0>)
{
    emit<"0101111011100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_8B rd, VReg_8B rn, ImmConst<0>)
{
    emit<"0000111000100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_16B rd, VReg_16B rn, ImmConst<0>)
{
    emit<"0100111000100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_4H rd, VReg_4H rn, ImmConst<0>)
{
    emit<"0000111001100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_8H rd, VReg_8H rn, ImmConst<0>)
{
    emit<"0100111001100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_2S rd, VReg_2S rn, ImmConst<0>)
{
    emit<"0000111010100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_4S rd, VReg_4S rn, ImmConst<0>)
{
    emit<"0100111010100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMGT(VReg_2D rd, VReg_2D rn, ImmConst<0>)
{
    emit<"0100111011100000100010nnnnnddddd", "d", "n">(rd, rn);
}
void CMHI(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHI(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm001101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMHS(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm001111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMLE(DReg rd, DReg rn, ImmConst<0>)
{
    emit<"0111111011100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_8B rd, VReg_8B rn, ImmConst<0>)
{
    emit<"0010111000100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_16B rd, VReg_16B rn, ImmConst<0>)
{
    emit<"0110111000100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_4H rd, VReg_4H rn, ImmConst<0>)
{
    emit<"0010111001100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_8H rd, VReg_8H rn, ImmConst<0>)
{
    emit<"0110111001100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_2S rd, VReg_2S rn, ImmConst<0>)
{
    emit<"0010111010100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_4S rd, VReg_4S rn, ImmConst<0>)
{
    emit<"0110111010100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLE(VReg_2D rd, VReg_2D rn, ImmConst<0>)
{
    emit<"0110111011100000100110nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(DReg rd, DReg rn, ImmConst<0>)
{
    emit<"0101111011100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_8B rd, VReg_8B rn, ImmConst<0>)
{
    emit<"0000111000100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_16B rd, VReg_16B rn, ImmConst<0>)
{
    emit<"0100111000100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_4H rd, VReg_4H rn, ImmConst<0>)
{
    emit<"0000111001100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_8H rd, VReg_8H rn, ImmConst<0>)
{
    emit<"0100111001100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_2S rd, VReg_2S rn, ImmConst<0>)
{
    emit<"0000111010100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_4S rd, VReg_4S rn, ImmConst<0>)
{
    emit<"0100111010100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMLT(VReg_2D rd, VReg_2D rn, ImmConst<0>)
{
    emit<"0100111011100000101010nnnnnddddd", "d", "n">(rd, rn);
}
void CMTST(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CMTST(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm100011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void CNT(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void CNT(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(BReg rd, BElem en)
{
    emit<"01011110000xxxx1000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(HReg rd, HElem en)
{
    emit<"01011110000xxx10000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(SReg rd, SElem en)
{
    emit<"01011110000xx100000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(DReg rd, DElem en)
{
    emit<"01011110000x1000000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_8B rd, BElem en)
{
    emit<"00001110000xxxx1000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_16B rd, BElem en)
{
    emit<"01001110000xxxx1000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_4H rd, HElem en)
{
    emit<"00001110000xxx10000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_8H rd, HElem en)
{
    emit<"01001110000xxx10000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_2S rd, SElem en)
{
    emit<"00001110000xx100000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_4S rd, SElem en)
{
    emit<"01001110000xx100000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_2D rd, DElem en)
{
    emit<"01001110000x1000000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void DUP(VReg_8B rd, WReg rn)
{
    emit<"00001110000xxxx1000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_16B rd, WReg rn)
{
    emit<"01001110000xxxx1000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_4H rd, WReg rn)
{
    emit<"00001110000xxx10000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_8H rd, WReg rn)
{
    emit<"01001110000xxx10000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_2S rd, WReg rn)
{
    emit<"00001110000xx100000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_4S rd, WReg rn)
{
    emit<"01001110000xx100000011nnnnnddddd", "d", "n">(rd, rn);
}
void DUP(VReg_2D rd, XReg rn)
{
    emit<"01001110000x1000000011nnnnnddddd", "d", "n">(rd, rn);
}
void EOR(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void EOR(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void EXT(VReg_8B rd, VReg_8B rn, VReg_8B rm, Imm<3> index)
{
    emit<"00101110000mmmmm0jjjj0nnnnnddddd", "d", "n", "m", "j">(rd, rn, rm, index);
}
void EXT(VReg_16B rd, VReg_16B rn, VReg_16B rm, Imm<4> index)
{
    emit<"01101110000mmmmm0jjjj0nnnnnddddd", "d", "n", "m", "j">(rd, rn, rm, index);
}
void FABD(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABD(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FABS(SReg rd, SReg rn)
{
    emit<"0001111000100000110000nnnnnddddd", "d", "n">(rd, rn);
}
void FABS(DReg rd, DReg rn)
{
    emit<"0001111001100000110000nnnnnddddd", "d", "n">(rd, rn);
}
void FABS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FABS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FABS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FACGE(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110001mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110011mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGE(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FACGT(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm111011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADD(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADDP(SReg rd, VReg_2S rn)
{
    emit<"0111111000110000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FADDP(DReg rd, VReg_2D rn)
{
    emit<"0111111001110000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FADDP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADDP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FADDP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCCMP(SReg rn, SReg rm, Imm<4> nzcv, Cond cond)
{
    emit<"00011110001mmmmmcccc01nnnnn0ffff", "n", "m", "f", "c">(rn, rm, nzcv, cond);
}
void FCCMP(DReg rn, DReg rm, Imm<4> nzcv, Cond cond)
{
    emit<"00011110011mmmmmcccc01nnnnn0ffff", "n", "m", "f", "c">(rn, rm, nzcv, cond);
}
void FCCMPE(SReg rn, SReg rm, Imm<4> nzcv, Cond cond)
{
    emit<"00011110001mmmmmcccc01nnnnn1ffff", "n", "m", "f", "c">(rn, rm, nzcv, cond);
}
void FCCMPE(DReg rn, DReg rm, Imm<4> nzcv, Cond cond)
{
    emit<"00011110011mmmmmcccc01nnnnn1ffff", "n", "m", "f", "c">(rn, rm, nzcv, cond);
}
void FCMEQ(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110011mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMEQ(SReg rd, SReg rn, ImmConstFZero)
{
    emit<"0101111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(DReg rd, DReg rn, ImmConstFZero)
{
    emit<"0101111011100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(VReg_2S rd, VReg_2S rn, ImmConstFZero)
{
    emit<"0000111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(VReg_4S rd, VReg_4S rn, ImmConstFZero)
{
    emit<"0100111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMEQ(VReg_2D rd, VReg_2D rn, ImmConstFZero)
{
    emit<"0100111011100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110011mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGE(SReg rd, SReg rn, ImmConstFZero)
{
    emit<"0111111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(DReg rd, DReg rn, ImmConstFZero)
{
    emit<"0111111011100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(VReg_2S rd, VReg_2S rn, ImmConstFZero)
{
    emit<"0010111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(VReg_4S rd, VReg_4S rn, ImmConstFZero)
{
    emit<"0110111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGE(VReg_2D rd, VReg_2D rn, ImmConstFZero)
{
    emit<"0110111011100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm111001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FCMGT(SReg rd, SReg rn, ImmConstFZero)
{
    emit<"0101111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(DReg rd, DReg rn, ImmConstFZero)
{
    emit<"0101111011100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(VReg_2S rd, VReg_2S rn, ImmConstFZero)
{
    emit<"0000111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(VReg_4S rd, VReg_4S rn, ImmConstFZero)
{
    emit<"0100111010100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMGT(VReg_2D rd, VReg_2D rn, ImmConstFZero)
{
    emit<"0100111011100000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(SReg rd, SReg rn, ImmConstFZero)
{
    emit<"0111111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(DReg rd, DReg rn, ImmConstFZero)
{
    emit<"0111111011100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(VReg_2S rd, VReg_2S rn, ImmConstFZero)
{
    emit<"0010111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(VReg_4S rd, VReg_4S rn, ImmConstFZero)
{
    emit<"0110111010100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLE(VReg_2D rd, VReg_2D rn, ImmConstFZero)
{
    emit<"0110111011100000110110nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(SReg rd, SReg rn, ImmConstFZero)
{
    emit<"0101111010100000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(DReg rd, DReg rn, ImmConstFZero)
{
    emit<"0101111011100000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(VReg_2S rd, VReg_2S rn, ImmConstFZero)
{
    emit<"0000111010100000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(VReg_4S rd, VReg_4S rn, ImmConstFZero)
{
    emit<"0100111010100000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMLT(VReg_2D rd, VReg_2D rn, ImmConstFZero)
{
    emit<"0100111011100000111010nnnnnddddd", "d", "n">(rd, rn);
}
void FCMP(SReg rn, SReg rm)
{
    emit<"00011110001mmmmm001000nnnnn00000", "n", "m">(rn, rm);
}
void FCMP(SReg rn, ImmConstFZero)
{
    emit<"0001111000100000001000nnnnn01000", "n">(rn);
}
void FCMP(DReg rn, DReg rm)
{
    emit<"00011110011mmmmm001000nnnnn00000", "n", "m">(rn, rm);
}
void FCMP(DReg rn, ImmConstFZero)
{
    emit<"0001111001100000001000nnnnn01000", "n">(rn);
}
void FCMPE(SReg rn, SReg rm)
{
    emit<"00011110001mmmmm001000nnnnn10000", "n", "m">(rn, rm);
}
void FCMPE(SReg rn, ImmConstFZero)
{
    emit<"0001111000100000001000nnnnn11000", "n">(rn);
}
void FCMPE(DReg rn, DReg rm)
{
    emit<"00011110011mmmmm001000nnnnn10000", "n", "m">(rn, rm);
}
void FCMPE(DReg rn, ImmConstFZero)
{
    emit<"0001111001100000001000nnnnn11000", "n">(rn);
}
void FCSEL(SReg rd, SReg rn, SReg rm, Cond cond)
{
    emit<"00011110001mmmmmcccc11nnnnnddddd", "d", "n", "m", "c">(rd, rn, rm, cond);
}
void FCSEL(DReg rd, DReg rn, DReg rm, Cond cond)
{
    emit<"00011110011mmmmmcccc11nnnnnddddd", "d", "n", "m", "c">(rd, rn, rm, cond);
}
void FCVT(SReg rd, HReg rn)
{
    emit<"0001111011100010010000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVT(DReg rd, HReg rn)
{
    emit<"0001111011100010110000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVT(HReg rd, SReg rn)
{
    emit<"0001111000100011110000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVT(DReg rd, SReg rn)
{
    emit<"0001111000100010110000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVT(HReg rd, DReg rn)
{
    emit<"0001111001100011110000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVT(SReg rd, DReg rn)
{
    emit<"0001111001100010010000nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(WReg wd, SReg rn)
{
    emit<"0001111000100100000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTAS(XReg xd, SReg rn)
{
    emit<"1001111000100100000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTAS(WReg wd, DReg rn)
{
    emit<"0001111001100100000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTAS(XReg xd, DReg rn)
{
    emit<"1001111001100100000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTAS(SReg rd, SReg rn)
{
    emit<"0101111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(DReg rd, DReg rn)
{
    emit<"0101111001100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(WReg wd, SReg rn)
{
    emit<"0001111000100101000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTAU(XReg xd, SReg rn)
{
    emit<"1001111000100101000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTAU(WReg wd, DReg rn)
{
    emit<"0001111001100101000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTAU(XReg xd, DReg rn)
{
    emit<"1001111001100101000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTAU(SReg rd, SReg rn)
{
    emit<"0111111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(DReg rd, DReg rn)
{
    emit<"0111111001100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTAU(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTL(VReg_4S rd, VReg_4H rn)
{
    emit<"0000111000100001011110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTL2(VReg_4S rd, VReg_8H rn)
{
    emit<"0100111000100001011110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTL(VReg_2D rd, VReg_2S rn)
{
    emit<"0000111001100001011110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTL2(VReg_2D rd, VReg_4S rn)
{
    emit<"0100111001100001011110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(WReg wd, SReg rn)
{
    emit<"0001111000110000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTMS(XReg xd, SReg rn)
{
    emit<"1001111000110000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTMS(WReg wd, DReg rn)
{
    emit<"0001111001110000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTMS(XReg xd, DReg rn)
{
    emit<"1001111001110000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTMS(SReg rd, SReg rn)
{
    emit<"0101111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(DReg rd, DReg rn)
{
    emit<"0101111001100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(WReg wd, SReg rn)
{
    emit<"0001111000110001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTMU(XReg xd, SReg rn)
{
    emit<"1001111000110001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTMU(WReg wd, DReg rn)
{
    emit<"0001111001110001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTMU(XReg xd, DReg rn)
{
    emit<"1001111001110001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTMU(SReg rd, SReg rn)
{
    emit<"0111111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(DReg rd, DReg rn)
{
    emit<"0111111001100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTMU(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTN(VReg_4H rd, VReg_4S rn)
{
    emit<"0000111000100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTN2(VReg_8H rd, VReg_4S rn)
{
    emit<"0100111000100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTN(VReg_2S rd, VReg_2D rn)
{
    emit<"0000111001100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0100111001100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(WReg wd, SReg rn)
{
    emit<"0001111000100000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTNS(XReg xd, SReg rn)
{
    emit<"1001111000100000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTNS(WReg wd, DReg rn)
{
    emit<"0001111001100000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTNS(XReg xd, DReg rn)
{
    emit<"1001111001100000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTNS(SReg rd, SReg rn)
{
    emit<"0101111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(DReg rd, DReg rn)
{
    emit<"0101111001100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(WReg wd, SReg rn)
{
    emit<"0001111000100001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTNU(XReg xd, SReg rn)
{
    emit<"1001111000100001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTNU(WReg wd, DReg rn)
{
    emit<"0001111001100001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTNU(XReg xd, DReg rn)
{
    emit<"1001111001100001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTNU(SReg rd, SReg rn)
{
    emit<"0111111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(DReg rd, DReg rn)
{
    emit<"0111111001100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTNU(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(WReg wd, SReg rn)
{
    emit<"0001111000101000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTPS(XReg xd, SReg rn)
{
    emit<"1001111000101000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTPS(WReg wd, DReg rn)
{
    emit<"0001111001101000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTPS(XReg xd, DReg rn)
{
    emit<"1001111001101000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTPS(SReg rd, SReg rn)
{
    emit<"0101111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(DReg rd, DReg rn)
{
    emit<"0101111011100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(WReg wd, SReg rn)
{
    emit<"0001111000101001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTPU(XReg xd, SReg rn)
{
    emit<"1001111000101001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTPU(WReg wd, DReg rn)
{
    emit<"0001111001101001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTPU(XReg xd, DReg rn)
{
    emit<"1001111001101001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTPU(SReg rd, SReg rn)
{
    emit<"0111111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(DReg rd, DReg rn)
{
    emit<"0111111011100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTPU(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100001101010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTXN(SReg rd, DReg rn)
{
    emit<"0111111001100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTXN(VReg_2S rd, VReg_2D rn)
{
    emit<"0010111001100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTXN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0110111001100001011010nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(WReg wd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"0001111000011000SSSSSSnnnnnddddd", "d", "n", "S">(wd, rn, 64 - fbits.value());
}
void FCVTZS(XReg xd, SReg rn, ImmRange<1, 64> fbits)
{
    emit<"1001111000011000SSSSSSnnnnnddddd", "d", "n", "S">(xd, rn, 64 - fbits.value());
}
void FCVTZS(WReg wd, DReg rn, ImmRange<1, 32> fbits)
{
    emit<"0001111001011000SSSSSSnnnnnddddd", "d", "n", "S">(wd, rn, 64 - fbits.value());
}
void FCVTZS(XReg xd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"1001111001011000SSSSSSnnnnnddddd", "d", "n", "S">(xd, rn, 64 - fbits.value());
}
void FCVTZS(WReg wd, SReg rn)
{
    emit<"0001111000111000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTZS(XReg xd, SReg rn)
{
    emit<"1001111000111000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTZS(WReg wd, DReg rn)
{
    emit<"0001111001111000000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTZS(XReg xd, DReg rn)
{
    emit<"1001111001111000000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTZS(HReg rd, HReg rn, ImmRange<1, 16> fbits)
{
    emit<"010111110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZS(SReg rd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"01011111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZS(DReg rd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"0101111101hhhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void FCVTZS(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> fbits)
{
    emit<"000011110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZS(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> fbits)
{
    emit<"010011110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZS(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> fbits)
{
    emit<"00001111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZS(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> fbits)
{
    emit<"01001111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZS(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> fbits)
{
    emit<"0100111101hhhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void FCVTZS(SReg rd, SReg rn)
{
    emit<"0101111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(DReg rd, DReg rn)
{
    emit<"0101111011100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(WReg wd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"0001111000011001SSSSSSnnnnnddddd", "d", "n", "S">(wd, rn, 64 - fbits.value());
}
void FCVTZU(XReg xd, SReg rn, ImmRange<1, 64> fbits)
{
    emit<"1001111000011001SSSSSSnnnnnddddd", "d", "n", "S">(xd, rn, 64 - fbits.value());
}
void FCVTZU(WReg wd, DReg rn, ImmRange<1, 32> fbits)
{
    emit<"0001111001011001SSSSSSnnnnnddddd", "d", "n", "S">(wd, rn, 64 - fbits.value());
}
void FCVTZU(XReg xd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"1001111001011001SSSSSSnnnnnddddd", "d", "n", "S">(xd, rn, 64 - fbits.value());
}
void FCVTZU(WReg wd, SReg rn)
{
    emit<"0001111000111001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTZU(XReg xd, SReg rn)
{
    emit<"1001111000111001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTZU(WReg wd, DReg rn)
{
    emit<"0001111001111001000000nnnnnddddd", "d", "n">(wd, rn);
}
void FCVTZU(XReg xd, DReg rn)
{
    emit<"1001111001111001000000nnnnnddddd", "d", "n">(xd, rn);
}
void FCVTZU(HReg rd, HReg rn, ImmRange<1, 16> fbits)
{
    emit<"011111110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZU(SReg rd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"01111111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZU(DReg rd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"0111111101hhhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void FCVTZU(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> fbits)
{
    emit<"001011110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZU(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> fbits)
{
    emit<"011011110001hbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void FCVTZU(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> fbits)
{
    emit<"00101111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZU(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> fbits)
{
    emit<"01101111001hhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void FCVTZU(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> fbits)
{
    emit<"0110111101hhhbbb111111nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void FCVTZU(SReg rd, SReg rn)
{
    emit<"0111111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(DReg rd, DReg rn)
{
    emit<"0111111011100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FCVTZU(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100001101110nnnnnddddd", "d", "n">(rd, rn);
}
void FDIV(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FDIV(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FDIV(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FDIV(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FDIV(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMADD(SReg rd, SReg rn, SReg rm, SReg ra)
{
    emit<"00011111000mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FMADD(DReg rd, DReg rn, DReg rm, DReg ra)
{
    emit<"00011111010mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FMAX(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm010010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm010010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAX(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNM(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMP(SReg rd, VReg_2S rn)
{
    emit<"0111111000110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXNMP(DReg rd, VReg_2D rn)
{
    emit<"0111111001110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXNMP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXNMV(SReg rd, VReg_4S rn)
{
    emit<"0110111000110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXP(SReg rd, VReg_2S rn)
{
    emit<"0111111000110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXP(DReg rd, VReg_2D rn)
{
    emit<"0111111001110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMAXP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMAXV(SReg rd, VReg_4S rn)
{
    emit<"0110111000110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMIN(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMIN(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMIN(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMIN(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMIN(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNM(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMP(SReg rd, VReg_2S rn)
{
    emit<"0111111010110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINNMP(DReg rd, VReg_2D rn)
{
    emit<"0111111011110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINNMP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm110001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINNMV(SReg rd, VReg_4S rn)
{
    emit<"0110111010110000110010nnnnnddddd", "d", "n">(rd, rn);
}
void FMINP(SReg rd, VReg_2S rn)
{
    emit<"0111111010110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMINP(DReg rd, VReg_2D rn)
{
    emit<"0111111011110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMINP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINP(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm111101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMINV(SReg rd, VReg_4S rn)
{
    emit<"0110111010110000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FMLA(SReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm0001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLA(DReg rd, DReg rn, DElem em)
{
    emit<"0101111111LMmmmm0001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMLA(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLA(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLA(VReg_2D rd, VReg_2D rn, DElem em)
{
    emit<"0100111111LMmmmm0001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMLA(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLA(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLA(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLS(SReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm0101H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLS(DReg rd, DReg rn, DElem em)
{
    emit<"0101111111LMmmmm0101H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMLS(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0101H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLS(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0101H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMLS(VReg_2D rd, VReg_2D rn, DElem em)
{
    emit<"0100111111LMmmmm0101H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMLS(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLS(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMLS(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm110011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMOV(SReg rd, WReg wn)
{
    emit<"0001111000100111000000nnnnnddddd", "d", "n">(rd, wn);
}
void FMOV(WReg wd, SReg rn)
{
    emit<"0001111000100110000000nnnnnddddd", "d", "n">(wd, rn);
}
void FMOV(DReg rd, XReg xn)
{
    emit<"1001111001100111000000nnnnnddddd", "d", "n">(rd, xn);
}
void FMOV(DElem_1 ed, XReg xn)
{
    emit<"1001111010101111000000nnnnnddddd", "d", "n">(ed.reg_index(), xn);
}
void FMOV(XReg xd, DReg rn)
{
    emit<"1001111001100110000000nnnnnddddd", "d", "n">(xd, rn);
}
void FMOV(XReg xd, DElem_1 en)
{
    emit<"1001111010101110000000nnnnnddddd", "d", "n">(xd, en.reg_index());
}
void FMOV(SReg rd, SReg rn)
{
    emit<"0001111000100000010000nnnnnddddd", "d", "n">(rd, rn);
}
void FMOV(DReg rd, DReg rn)
{
    emit<"0001111001100000010000nnnnnddddd", "d", "n">(rd, rn);
}
void FMOV(SReg rd, FImm8 imm)
{
    emit<"00011110001iiiiiiii10000000ddddd", "d", "i">(rd, imm);
}
void FMOV(DReg rd, FImm8 imm)
{
    emit<"00011110011iiiiiiii10000000ddddd", "d", "i">(rd, imm);
}
void FMOV(VReg_2S rd, FImm8 imm)
{
    emit<"0000111100000vvv111101vvvvvddddd", "d", "v">(rd, imm);
}
void FMOV(VReg_4S rd, FImm8 imm)
{
    emit<"0100111100000vvv111101vvvvvddddd", "d", "v">(rd, imm);
}
void FMOV(VReg_2D rd, FImm8 imm)
{
    emit<"0110111100000vvv111101vvvvvddddd", "d", "v">(rd, imm);
}
void FMSUB(SReg rd, SReg rn, SReg rm, SReg ra)
{
    emit<"00011111000mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FMSUB(DReg rd, DReg rn, DReg rm, DReg ra)
{
    emit<"00011111010mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FMUL(SReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMUL(DReg rd, DReg rn, DElem em)
{
    emit<"0101111111LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMUL(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMUL(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMUL(VReg_2D rd, VReg_2D rn, DElem em)
{
    emit<"0100111111LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMUL(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm000010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMUL(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm000010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMUL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110001mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMUL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110001mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMUL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110011mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110001mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110011mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm110111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FMULX(SReg rd, SReg rn, SElem em)
{
    emit<"0111111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMULX(DReg rd, DReg rn, DElem em)
{
    emit<"0111111111LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FMULX(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMULX(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), em.elem_index() & 1, em.elem_index() >> 1);
}
void FMULX(VReg_2D rd, VReg_2D rn, DElem em)
{
    emit<"0110111111LMmmmm1001H0nnnnnddddd", "d", "n", "Mm", "L", "H">(rd, rn, em.reg_index(), 0, em.elem_index());
}
void FNEG(SReg rd, SReg rn)
{
    emit<"0001111000100001010000nnnnnddddd", "d", "n">(rd, rn);
}
void FNEG(DReg rd, DReg rn)
{
    emit<"0001111001100001010000nnnnnddddd", "d", "n">(rd, rn);
}
void FNEG(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FNEG(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FNEG(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100000111110nnnnnddddd", "d", "n">(rd, rn);
}
void FNMADD(SReg rd, SReg rn, SReg rm, SReg ra)
{
    emit<"00011111001mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FNMADD(DReg rd, DReg rn, DReg rm, DReg ra)
{
    emit<"00011111011mmmmm0aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FNMSUB(SReg rd, SReg rn, SReg rm, SReg ra)
{
    emit<"00011111001mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FNMSUB(DReg rd, DReg rn, DReg rm, DReg ra)
{
    emit<"00011111011mmmmm1aaaaannnnnddddd", "d", "n", "m", "a">(rd, rn, rm, ra);
}
void FNMUL(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm100010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FNMUL(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm100010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPE(SReg rd, SReg rn)
{
    emit<"0101111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(DReg rd, DReg rn)
{
    emit<"0101111011100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPE(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPS(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110001mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110011mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110001mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110001mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPS(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110011mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRECPX(SReg rd, SReg rn)
{
    emit<"0101111010100001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FRECPX(DReg rd, DReg rn)
{
    emit<"0101111011100001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(SReg rd, SReg rn)
{
    emit<"0001111000100110010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(DReg rd, DReg rn)
{
    emit<"0001111001100110010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTA(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(SReg rd, SReg rn)
{
    emit<"0001111000100111110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(DReg rd, DReg rn)
{
    emit<"0001111001100111110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTI(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(SReg rd, SReg rn)
{
    emit<"0001111000100101010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(DReg rd, DReg rn)
{
    emit<"0001111001100101010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTM(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(SReg rd, SReg rn)
{
    emit<"0001111000100100010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(DReg rd, DReg rn)
{
    emit<"0001111001100100010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTN(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(SReg rd, SReg rn)
{
    emit<"0001111000100100110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(DReg rd, DReg rn)
{
    emit<"0001111001100100110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTP(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100001100010nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(SReg rd, SReg rn)
{
    emit<"0001111000100111010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(DReg rd, DReg rn)
{
    emit<"0001111001100111010000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTX(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(SReg rd, SReg rn)
{
    emit<"0001111000100101110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(DReg rd, DReg rn)
{
    emit<"0001111001100101110000nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRINTZ(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100001100110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(SReg rd, SReg rn)
{
    emit<"0111111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(DReg rd, DReg rn)
{
    emit<"0111111011100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTE(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void FRSQRTS(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FRSQRTS(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm111111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSQRT(SReg rd, SReg rn)
{
    emit<"0001111000100001110000nnnnnddddd", "d", "n">(rd, rn);
}
void FSQRT(DReg rd, DReg rn)
{
    emit<"0001111001100001110000nnnnnddddd", "d", "n">(rd, rn);
}
void FSQRT(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FSQRT(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FSQRT(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100001111110nnnnnddddd", "d", "n">(rd, rn);
}
void FSUB(SReg rd, SReg rn, SReg rm)
{
    emit<"00011110001mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSUB(DReg rd, DReg rn, DReg rm)
{
    emit<"00011110011mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void FSUB(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm110101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void INS(BElem ed, BElem en)
{
    emit<"01101110000xxxx10yyyy1nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void INS(HElem ed, HElem en)
{
    emit<"01101110000xxx100yyy01nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void INS(SElem ed, SElem en)
{
    emit<"01101110000xx1000yy001nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void INS(DElem ed, DElem en)
{
    emit<"01101110000x10000y0001nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void INS(BElem ed, WReg rn)
{
    emit<"01001110000xxxx1000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void INS(HElem ed, WReg rn)
{
    emit<"01001110000xxx10000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void INS(SElem ed, WReg rn)
{
    emit<"01001110000xx100000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void INS(DElem ed, XReg rn)
{
    emit<"01001110000x1000000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void LD1(List<VReg_8B, 1> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 1> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 1> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 1> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 1> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 1> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 1> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 1> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110011011111011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110011011111011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110011011111011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110011011111011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110011011111011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110011011111011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110011011111011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110011011111011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011100nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011100nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011101nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011101nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011110nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011110nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011111nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011111nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm101000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm101000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm101001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm101001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm101010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm101010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm101011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm101011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm011011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm011011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm001000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm001000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm001001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm001001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm001010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm001010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm001011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm001011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1(List<BElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<HElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<SElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<DElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<BElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<1>)
{
    emit<"0Q00110111011111000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<BElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm000Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD1(List<HElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0Q00110111011111010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<HElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm010Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD1(List<SElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110111011111100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<SElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm100S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD1(List<DElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110111011111100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD1(List<DElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm100001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD1R(List<VReg_8B, 1> tlist, XRegSp addr_n)
{
    emit<"0000110101000000110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_16B, 1> tlist, XRegSp addr_n)
{
    emit<"0100110101000000110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_4H, 1> tlist, XRegSp addr_n)
{
    emit<"0000110101000000110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_8H, 1> tlist, XRegSp addr_n)
{
    emit<"0100110101000000110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_2S, 1> tlist, XRegSp addr_n)
{
    emit<"0000110101000000110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_4S, 1> tlist, XRegSp addr_n)
{
    emit<"0100110101000000110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_1D, 1> tlist, XRegSp addr_n)
{
    emit<"0000110101000000110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_2D, 1> tlist, XRegSp addr_n)
{
    emit<"0100110101000000110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<1>)
{
    emit<"0000110111011111110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<1>)
{
    emit<"0100110111011111110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0000110111011111110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0100110111011111110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0000110111011111110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0100110111011111110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110111011111110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0100110111011111110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD1R(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm110000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm110000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm110001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm110001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm110010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm110010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm110011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD1R(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm110011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_8B, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_16B, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_4H, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_8H, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_2S, 2> tlist, XRegSp addr_n)
{
    emit<"0000110001000000100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_4S, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_2D, 2> tlist, XRegSp addr_n)
{
    emit<"0100110001000000100011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110011011111100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110011011111100011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm100000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm100000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm100001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm100001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm100010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm100010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm100011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2(List<BElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<HElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<SElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<DElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<BElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0Q00110111111111000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<BElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm000Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD2(List<HElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110111111111010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<HElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm010Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD2(List<SElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110111111111100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<SElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm100S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD2(List<DElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0Q00110111111111100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD2(List<DElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm100001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD2R(List<VReg_8B, 2> tlist, XRegSp addr_n)
{
    emit<"0000110101100000110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_16B, 2> tlist, XRegSp addr_n)
{
    emit<"0100110101100000110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_4H, 2> tlist, XRegSp addr_n)
{
    emit<"0000110101100000110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_8H, 2> tlist, XRegSp addr_n)
{
    emit<"0100110101100000110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_2S, 2> tlist, XRegSp addr_n)
{
    emit<"0000110101100000110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_4S, 2> tlist, XRegSp addr_n)
{
    emit<"0100110101100000110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_1D, 2> tlist, XRegSp addr_n)
{
    emit<"0000110101100000110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_2D, 2> tlist, XRegSp addr_n)
{
    emit<"0100110101100000110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0000110111111111110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0100110111111111110000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0000110111111111110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0100110111111111110001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110111111111110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0100110111111111110010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110111111111110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110111111111110011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD2R(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm110000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm110000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm110001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm110001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm110010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm110010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm110011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD2R(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm110011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_8B, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_16B, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_4H, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_8H, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_2S, 3> tlist, XRegSp addr_n)
{
    emit<"0000110001000000010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_4S, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_2D, 3> tlist, XRegSp addr_n)
{
    emit<"0100110001000000010011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110011011111010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110011011111010011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm010000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm010000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm010001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm010001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm010010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm010010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm010011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3(List<BElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<HElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<SElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<DElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110101000000101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<BElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<3>)
{
    emit<"0Q00110111011111001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<BElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm001Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD3(List<HElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<6>)
{
    emit<"0Q00110111011111011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<HElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm011Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD3(List<SElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<12>)
{
    emit<"0Q00110111011111101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<SElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm101S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD3(List<DElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0Q00110111011111101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD3(List<DElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101110mmmmm101001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD3R(List<VReg_8B, 3> tlist, XRegSp addr_n)
{
    emit<"0000110101000000111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_16B, 3> tlist, XRegSp addr_n)
{
    emit<"0100110101000000111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_4H, 3> tlist, XRegSp addr_n)
{
    emit<"0000110101000000111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_8H, 3> tlist, XRegSp addr_n)
{
    emit<"0100110101000000111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_2S, 3> tlist, XRegSp addr_n)
{
    emit<"0000110101000000111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_4S, 3> tlist, XRegSp addr_n)
{
    emit<"0100110101000000111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_1D, 3> tlist, XRegSp addr_n)
{
    emit<"0000110101000000111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_2D, 3> tlist, XRegSp addr_n)
{
    emit<"0100110101000000111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<3>)
{
    emit<"0000110111011111111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<3>)
{
    emit<"0100110111011111111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<6>)
{
    emit<"0000110111011111111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<6>)
{
    emit<"0100110111011111111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<12>)
{
    emit<"0000110111011111111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<12>)
{
    emit<"0100110111011111111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110111011111111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0100110111011111111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD3R(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm111000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm111000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm111001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm111001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm111010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm111010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101110mmmmm111011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD3R(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101110mmmmm111011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_8B, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_16B, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_4H, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_8H, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_2S, 4> tlist, XRegSp addr_n)
{
    emit<"0000110001000000000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_4S, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_2D, 4> tlist, XRegSp addr_n)
{
    emit<"0100110001000000000011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110011011111000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110011011111000011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm000000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm000000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm000001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm000001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100110mmmmm000010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm000010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100110mmmmm000011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4(List<BElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<HElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<SElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<DElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110101100000101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<BElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110111111111001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<BElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm001Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD4(List<HElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110111111111011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<HElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm011Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD4(List<SElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0Q00110111111111101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<SElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm101S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD4(List<DElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0Q00110111111111101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void LD4(List<DElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101111mmmmm101001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void LD4R(List<VReg_8B, 4> tlist, XRegSp addr_n)
{
    emit<"0000110101100000111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_16B, 4> tlist, XRegSp addr_n)
{
    emit<"0100110101100000111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_4H, 4> tlist, XRegSp addr_n)
{
    emit<"0000110101100000111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_8H, 4> tlist, XRegSp addr_n)
{
    emit<"0100110101100000111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_2S, 4> tlist, XRegSp addr_n)
{
    emit<"0000110101100000111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_4S, 4> tlist, XRegSp addr_n)
{
    emit<"0100110101100000111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_1D, 4> tlist, XRegSp addr_n)
{
    emit<"0000110101100000111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_2D, 4> tlist, XRegSp addr_n)
{
    emit<"0100110101100000111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0000110111111111111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0100110111111111111000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110111111111111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0100110111111111111001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110111111111111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110111111111111010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110111111111111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110111111111111011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void LD4R(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm111000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm111000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm111001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm111001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm111010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm111010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001101111mmmmm111011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LD4R(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001101111mmmmm111011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void LDNP(SReg rt1, SReg rt2, XRegSp addr_n, SOffset<9, 2> offset = 0)
{
    emit<"0010110001iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDNP(DReg rt1, DReg rt2, XRegSp addr_n, SOffset<10, 3> offset = 0)
{
    emit<"0110110001iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDNP(QReg rt1, QReg rt2, XRegSp addr_n, SOffset<11, 4> offset = 0)
{
    emit<"1010110001iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(SReg rt1, SReg rt2, XRegSp addr_n, PostIndexed, SOffset<9, 2> offset)
{
    emit<"0010110011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(DReg rt1, DReg rt2, XRegSp addr_n, PostIndexed, SOffset<10, 3> offset)
{
    emit<"0110110011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(QReg rt1, QReg rt2, XRegSp addr_n, PostIndexed, SOffset<11, 4> offset)
{
    emit<"1010110011iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(SReg rt1, SReg rt2, XRegSp addr_n, PreIndexed, SOffset<9, 2> offset)
{
    emit<"0010110111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(DReg rt1, DReg rt2, XRegSp addr_n, PreIndexed, SOffset<10, 3> offset)
{
    emit<"0110110111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(QReg rt1, QReg rt2, XRegSp addr_n, PreIndexed, SOffset<11, 4> offset)
{
    emit<"1010110111iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(SReg rt1, SReg rt2, XRegSp addr_n, SOffset<9, 2> offset = 0)
{
    emit<"0010110101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(DReg rt1, DReg rt2, XRegSp addr_n, SOffset<10, 3> offset = 0)
{
    emit<"0110110101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDP(QReg rt1, QReg rt2, XRegSp addr_n, SOffset<11, 4> offset = 0)
{
    emit<"1010110101iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void LDR(BReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"00111100010iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(HReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"01111100010iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(SReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"10111100010iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(DReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"11111100010iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(QReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"00111100110iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(BReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"00111100010iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(HReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"01111100010iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(SReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"10111100010iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(DReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"11111100010iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(QReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"00111100110iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(BReg rt, XRegSp addr_n, POffset<12, 0> offset = 0)
{
    emit<"0011110101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(HReg rt, XRegSp addr_n, POffset<13, 1> offset = 0)
{
    emit<"0111110101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(SReg rt, XRegSp addr_n, POffset<14, 2> offset = 0)
{
    emit<"1011110101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(DReg rt, XRegSp addr_n, POffset<15, 3> offset = 0)
{
    emit<"1111110101iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(QReg rt, XRegSp addr_n, POffset<16, 4> offset = 0)
{
    emit<"0011110111iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDR(SReg rt, AddrOffset<21, 2> offset)
{
    emit<"00011100iiiiiiiiiiiiiiiiiiittttt", "t", "i">(rt, offset);
}
void LDR(DReg rt, AddrOffset<21, 2> offset)
{
    emit<"01011100iiiiiiiiiiiiiiiiiiittttt", "t", "i">(rt, offset);
}
void LDR(QReg rt, AddrOffset<21, 2> offset)
{
    emit<"10011100iiiiiiiiiiiiiiiiiiittttt", "t", "i">(rt, offset);
}
void LDR(BReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111100011mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void LDR(HReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111100011mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void LDR(SReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 2> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"10111100011mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void LDR(DReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 3> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"11111100011mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void LDR(QReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 4> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111100111mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void LDUR(BReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"00111100010iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDUR(HReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"01111100010iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDUR(SReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"10111100010iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDUR(DReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"11111100010iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void LDUR(QReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"00111100110iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void MLA(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm0000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MLA(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm0000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MLA(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm0000H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MLA(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm0000H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MLA(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLA(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLA(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLA(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLA(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLA(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm0100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MLS(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm0100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MLS(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm0100H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MLS(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm0100H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MLS(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MLS(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm100101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MOV(BElem ed, BElem en)
{
    emit<"01101110000xxxx10yyyy1nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void MOV(HElem ed, HElem en)
{
    emit<"01101110000xxx100yyy01nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void MOV(SElem ed, SElem en)
{
    emit<"01101110000xx1000yy001nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void MOV(DElem ed, DElem en)
{
    emit<"01101110000x10000y0001nnnnnddddd", "d", "x", "n", "y">(ed.reg_index(), ed.elem_index(), en.reg_index(), en.elem_index());
}
void MOV(BElem ed, WReg rn)
{
    emit<"01001110000xxxx1000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void MOV(HElem ed, WReg rn)
{
    emit<"01001110000xxx10000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void MOV(SElem ed, WReg rn)
{
    emit<"01001110000xx100000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void MOV(DElem ed, XReg rn)
{
    emit<"01001110000x1000000111nnnnnddddd", "d", "x", "n">(ed.reg_index(), ed.elem_index(), rn);
}
void MOV(BReg rd, BElem en)
{
    emit<"01011110000xxxx1000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void MOV(HReg rd, HElem en)
{
    emit<"01011110000xxx10000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void MOV(SReg rd, SElem en)
{
    emit<"01011110000xx100000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void MOV(DReg rd, DElem en)
{
    emit<"01011110000x1000000001nnnnnddddd", "d", "n", "x">(rd, en.reg_index(), en.elem_index());
}
void MOV(WReg wd, SElem en)
{
    emit<"00001110000xx100001111nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void MOV(XReg xd, DElem en)
{
    emit<"01001110000x1000001111nnnnnddddd", "d", "n", "x">(xd, en.reg_index(), en.elem_index());
}
void MOV(VReg_8B rd, VReg_8B rn)
{
    emit<"00001110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rn);
}
void MOV(VReg_16B rd, VReg_16B rn)
{
    emit<"01001110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rn);
}
void MOVI(VReg_8B rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmConst<0> = 0)
{
    emit<"0000111100000vvv111001vvvvvddddd", "d", "v">(rd, imm);
}
void MOVI(VReg_16B rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmConst<0> = 0)
{
    emit<"0100111100000vvv111001vvvvvddddd", "d", "v">(rd, imm);
}
void MOVI(VReg_4H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0000111100000vvv10c001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(VReg_8H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0100111100000vvv10c001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(VReg_2S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0000111100000vvv0cc001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(VReg_4S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0100111100000vvv0cc001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(VReg_2S rd, Imm<8> imm, MslSymbol, ImmChoice<8, 16> amount)
{
    emit<"0000111100000vvv110c01vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(VReg_4S rd, Imm<8> imm, MslSymbol, ImmChoice<8, 16> amount)
{
    emit<"0100111100000vvv110c01vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MOVI(DReg rd, RepImm imm)
{
    emit<"0010111100000vvv111001vvvvvddddd", "d", "v">(rd, imm);
}
void MOVI(VReg_2D rd, RepImm imm)
{
    emit<"0110111100000vvv111001vvvvvddddd", "d", "v">(rd, imm);
}
void MUL(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm1000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MUL(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm1000H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void MUL(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1000H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MUL(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1000H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void MUL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MUL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MUL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MUL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MUL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MUL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void MVN(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void MVN(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void MVNI(VReg_4H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0010111100000vvv10c001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MVNI(VReg_8H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0110111100000vvv10c001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MVNI(VReg_2S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0010111100000vvv0cc001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MVNI(VReg_4S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0110111100000vvv0cc001vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MVNI(VReg_2S rd, Imm<8> imm, MslSymbol, ImmChoice<8, 16> amount)
{
    emit<"0010111100000vvv110c01vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void MVNI(VReg_4S rd, Imm<8> imm, MslSymbol, ImmChoice<8, 16> amount)
{
    emit<"0110111100000vvv110c01vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void NEG(DReg rd, DReg rn)
{
    emit<"0111111011100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NEG(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100000101110nnnnnddddd", "d", "n">(rd, rn);
}
void NOT(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void NOT(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void ORN(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110111mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ORN(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110111mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ORR(VReg_4H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0000111100000vvv10c101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void ORR(VReg_8H rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8> amount = 0)
{
    emit<"0100111100000vvv10c101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void ORR(VReg_2S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0000111100000vvv0cc101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void ORR(VReg_4S rd, Imm<8> imm, LslSymbol = LslSymbol::LSL, ImmChoice<0, 8, 16, 24> amount = 0)
{
    emit<"0100111100000vvv0cc101vvvvvddddd", "d", "v", "c">(rd, imm, amount);
}
void ORR(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ORR(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110101mmmmm000111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMUL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMUL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm100111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMULL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm111000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMULL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm111000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMULL(VReg_1Q rd, VReg_1D rn, VReg_1D rm)
{
    emit<"00001110111mmmmm111000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void PMULL2(VReg_1Q rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm111000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN(VReg_8B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"00101110001mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN2(VReg_16B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110001mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN(VReg_4H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"00101110011mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN2(VReg_8H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110011mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN(VReg_2S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"00101110101mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RADDHN2(VReg_4S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110101mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RBIT(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111001100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void RBIT(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111001100000010110nnnnnddddd", "d", "n">(rd, rn);
}
void REV16(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000000110nnnnnddddd", "d", "n">(rd, rn);
}
void REV16(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000000110nnnnnddddd", "d", "n">(rd, rn);
}
void REV32(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV32(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV32(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV32(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void REV64(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000000010nnnnnddddd", "d", "n">(rd, rn);
}
void RSHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void RSHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void RSHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void RSHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void RSHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void RSHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void RSUBHN(VReg_8B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"00101110001mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RSUBHN2(VReg_16B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110001mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RSUBHN(VReg_4H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"00101110011mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RSUBHN2(VReg_8H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110011mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RSUBHN(VReg_2S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"00101110101mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void RSUBHN2(VReg_4S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110101mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABA(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABAL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SABDL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADALP(VReg_4H rd, VReg_8B rn)
{
    emit<"0000111000100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADALP(VReg_8H rd, VReg_16B rn)
{
    emit<"0100111000100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADALP(VReg_2S rd, VReg_4H rn)
{
    emit<"0000111001100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADALP(VReg_4S rd, VReg_8H rn)
{
    emit<"0100111001100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADALP(VReg_1D rd, VReg_2S rn)
{
    emit<"0000111010100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADALP(VReg_2D rd, VReg_4S rn)
{
    emit<"0100111010100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDLP(VReg_4H rd, VReg_8B rn)
{
    emit<"0000111000100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLP(VReg_8H rd, VReg_16B rn)
{
    emit<"0100111000100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLP(VReg_2S rd, VReg_4H rn)
{
    emit<"0000111001100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLP(VReg_4S rd, VReg_8H rn)
{
    emit<"0100111001100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLP(VReg_1D rd, VReg_2S rn)
{
    emit<"0000111010100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLP(VReg_2D rd, VReg_4S rn)
{
    emit<"0100111010100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLV(HReg rd, VReg_8B rn)
{
    emit<"0000111000110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLV(HReg rd, VReg_16B rn)
{
    emit<"0100111000110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLV(SReg rd, VReg_4H rn)
{
    emit<"0000111001110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLV(SReg rd, VReg_8H rn)
{
    emit<"0100111001110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SADDLV(DReg rd, VReg_4S rn)
{
    emit<"0100111010110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SADDW(VReg_8H rd, VReg_8H rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDW2(VReg_8H rd, VReg_8H rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDW(VReg_4S rd, VReg_4S rn, VReg_4H rm)
{
    emit<"00001110011mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDW2(VReg_4S rd, VReg_4S rn, VReg_8H rm)
{
    emit<"01001110011mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDW(VReg_2D rd, VReg_2D rn, VReg_2S rm)
{
    emit<"00001110101mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SADDW2(VReg_2D rd, VReg_2D rn, VReg_4S rm)
{
    emit<"01001110101mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SCVTF(SReg rd, WReg wn, ImmRange<1, 32> fbits)
{
    emit<"0001111000000010SSSSSSnnnnnddddd", "d", "n", "S">(rd, wn, 64 - fbits.value());
}
void SCVTF(DReg rd, WReg wn, ImmRange<1, 32> fbits)
{
    emit<"0001111001000010SSSSSSnnnnnddddd", "d", "n", "S">(rd, wn, 64 - fbits.value());
}
void SCVTF(SReg rd, XReg xn, ImmRange<1, 64> fbits)
{
    emit<"1001111000000010SSSSSSnnnnnddddd", "d", "n", "S">(rd, xn, 64 - fbits.value());
}
void SCVTF(DReg rd, XReg xn, ImmRange<1, 64> fbits)
{
    emit<"1001111001000010SSSSSSnnnnnddddd", "d", "n", "S">(rd, xn, 64 - fbits.value());
}
void SCVTF(SReg rd, WReg wn)
{
    emit<"0001111000100010000000nnnnnddddd", "d", "n">(rd, wn);
}
void SCVTF(DReg rd, WReg wn)
{
    emit<"0001111001100010000000nnnnnddddd", "d", "n">(rd, wn);
}
void SCVTF(SReg rd, XReg xn)
{
    emit<"1001111000100010000000nnnnnddddd", "d", "n">(rd, xn);
}
void SCVTF(DReg rd, XReg xn)
{
    emit<"1001111001100010000000nnnnnddddd", "d", "n">(rd, xn);
}
void SCVTF(HReg rd, HReg rn, ImmRange<1, 16> fbits)
{
    emit<"010111110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void SCVTF(SReg rd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"01011111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void SCVTF(DReg rd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"0101111101hhhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void SCVTF(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> fbits)
{
    emit<"000011110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void SCVTF(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> fbits)
{
    emit<"010011110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void SCVTF(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> fbits)
{
    emit<"00001111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void SCVTF(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> fbits)
{
    emit<"01001111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void SCVTF(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> fbits)
{
    emit<"0100111101hhhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void SCVTF(SReg rd, SReg rn)
{
    emit<"0101111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(DReg rd, DReg rn)
{
    emit<"0101111001100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SCVTF(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111001100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void SHA1C(QReg rd, SReg rn, VReg_4S rm)
{
    emit<"01011110000mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA1H(SReg rd, SReg rn)
{
    emit<"0101111000101000000010nnnnnddddd", "d", "n">(rd, rn);
}
void SHA1M(QReg rd, SReg rn, VReg_4S rm)
{
    emit<"01011110000mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA1P(QReg rd, SReg rn, VReg_4S rm)
{
    emit<"01011110000mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA1SU0(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01011110000mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA1SU1(VReg_4S rd, VReg_4S rn)
{
    emit<"0101111000101000000110nnnnnddddd", "d", "n">(rd, rn);
}
void SHA256H(QReg rd, QReg rn, VReg_4S rm)
{
    emit<"01011110000mmmmm010000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA256H2(QReg rd, QReg rn, VReg_4S rm)
{
    emit<"01011110000mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHA256SU0(VReg_4S rd, VReg_4S rn)
{
    emit<"0101111000101000001010nnnnnddddd", "d", "n">(rd, rn);
}
void SHA256SU1(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01011110000mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHL(DReg rd, DReg rn, ImmRange<0, 63> shift)
{
    emit<"0101111101hhhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_8B rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0000111100001bbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_16B rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0100111100001bbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_4H rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"000011110001hbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_8H rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"010011110001hbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_2S rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00001111001hhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_4S rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01001111001hhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHL(VReg_2D rd, VReg_2D rn, ImmRange<0, 63> shift)
{
    emit<"0100111101hhhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SHLL(VReg_8H rd, VReg_8B rn, ImmConst<8>)
{
    emit<"0010111000100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHLL2(VReg_8H rd, VReg_16B rn, ImmConst<8>)
{
    emit<"0110111000100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHLL(VReg_4S rd, VReg_4H rn, ImmConst<16>)
{
    emit<"0010111001100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHLL2(VReg_4S rd, VReg_8H rn, ImmConst<16>)
{
    emit<"0110111001100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHLL(VReg_2D rd, VReg_2S rn, ImmConst<32>)
{
    emit<"0010111010100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHLL2(VReg_2D rd, VReg_4S rn, ImmConst<32>)
{
    emit<"0110111010100001001110nnnnnddddd", "d", "n">(rd, rn);
}
void SHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SHSUB(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHSUB(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHSUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHSUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHSUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SHSUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SLI(DReg rd, DReg rn, ImmRange<0, 63> shift)
{
    emit<"0111111101hhhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_8B rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0010111100001bbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_16B rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0110111100001bbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_4H rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"001011110001hbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_8H rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"011011110001hbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_2S rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00101111001hhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_4S rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01101111001hhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SLI(VReg_2D rd, VReg_2D rn, ImmRange<0, 63> shift)
{
    emit<"0110111101hhhbbb010101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SMAX(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAX(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAX(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAX(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAX(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAX(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMAXV(BReg rd, VReg_8B rn)
{
    emit<"0000111000110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMAXV(BReg rd, VReg_16B rn)
{
    emit<"0100111000110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMAXV(HReg rd, VReg_4H rn)
{
    emit<"0000111001110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMAXV(HReg rd, VReg_8H rn)
{
    emit<"0100111001110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMAXV(SReg rd, VReg_4S rn)
{
    emit<"0100111010110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMIN(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMIN(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMIN(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMIN(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMIN(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMIN(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMINV(BReg rd, VReg_8B rn)
{
    emit<"0000111000110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMINV(BReg rd, VReg_16B rn)
{
    emit<"0100111000110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMINV(HReg rd, VReg_4H rn)
{
    emit<"0000111001110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMINV(HReg rd, VReg_8H rn)
{
    emit<"0100111001110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMINV(SReg rd, VReg_4S rn)
{
    emit<"0100111010110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void SMLAL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm0010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMLAL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm0010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMLAL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMLAL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMLAL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLAL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLAL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLAL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLAL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm0110H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMLSL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm0110H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMLSL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMLSL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMLSL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMLSL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMOV(WReg wd, BElem en)
{
    emit<"00001110000xxxx1001011nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void SMOV(WReg wd, HElem en)
{
    emit<"00001110000xxx10001011nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void SMOV(XReg xd, BElem en)
{
    emit<"01001110000xxxx1001011nnnnnddddd", "d", "n", "x">(xd, en.reg_index(), en.elem_index());
}
void SMOV(XReg xd, HElem en)
{
    emit<"01001110000xxx10001011nnnnnddddd", "d", "n", "x">(xd, en.reg_index(), en.elem_index());
}
void SMOV(XReg xd, SElem en)
{
    emit<"01001110000xx100001011nnnnnddddd", "d", "n", "x">(xd, en.reg_index(), en.elem_index());
}
void SMULL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm1010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMULL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm1010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SMULL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMULL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SMULL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMULL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMULL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMULL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMULL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SMULL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQABS(BReg rd, BReg rn)
{
    emit<"0101111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(HReg rd, HReg rn)
{
    emit<"0101111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(SReg rd, SReg rn)
{
    emit<"0101111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(DReg rd, DReg rn)
{
    emit<"0101111011100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQABS(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQADD(BReg rd, BReg rn, BReg rm)
{
    emit<"01011110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQADD(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL(SReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111101LMmmmm0011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLAL(DReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm0011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLAL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm0011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLAL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm0011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLAL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLAL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLAL(SReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL(DReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLAL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm100100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL(SReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111101LMmmmm0111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLSL(DReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm0111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLSL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm0111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLSL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm0111H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMLSL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm0111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLSL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm0111H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMLSL(SReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL(DReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMLSL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111101LMmmmm1100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULH(SReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm1100H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULH(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm1100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULH(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm1100H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULH(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1100H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULH(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1100H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULH(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULH(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL(SReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111101LMmmmm1011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULL(DReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm1011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm1011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm1011H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQDMULL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1011H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQDMULL(SReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL(DReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQDMULL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm110100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQNEG(BReg rd, BReg rn)
{
    emit<"0111111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(HReg rd, HReg rn)
{
    emit<"0111111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(SReg rd, SReg rn)
{
    emit<"0111111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(DReg rd, DReg rn)
{
    emit<"0111111011100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQNEG(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100000011110nnnnnddddd", "d", "n">(rd, rn);
}
void SQRDMULH(HReg rd, HReg rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0101111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMULH(SReg rd, SReg rn, SElem em)
{
    emit<"0101111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMULH(VReg_4H rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0000111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMULH(VReg_8H rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0100111101LMmmmm1101H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void SQRDMULH(VReg_2S rd, VReg_2S rn, SElem em)
{
    emit<"0000111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMULH(VReg_4S rd, VReg_4S rn, SElem em)
{
    emit<"0100111110LMmmmm1101H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void SQRDMULH(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMULH(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMULH(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMULH(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMULH(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRDMULH(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm101101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(BReg rd, BReg rn, BReg rm)
{
    emit<"01011110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQRSHRN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0101111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"010111110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01011111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQRSHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQRSHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQRSHRUN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0111111100001bbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRUN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"011111110001hbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRUN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01111111001hhbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQRSHRUN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRUN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQRSHRUN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRUN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQRSHRUN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQRSHRUN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb100011nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHL(BReg rd, BReg rn, ImmRange<0, 7> shift)
{
    emit<"0101111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(HReg rd, HReg rn, ImmRange<0, 15> shift)
{
    emit<"010111110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(SReg rd, SReg rn, ImmRange<0, 31> shift)
{
    emit<"01011111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(DReg rd, DReg rn, ImmRange<0, 63> shift)
{
    emit<"0101111101hhhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_8B rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0000111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_16B rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0100111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_4H rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"000011110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_8H rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"010011110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_2S rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00001111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_4S rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01001111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(VReg_2D rd, VReg_2D rn, ImmRange<0, 63> shift)
{
    emit<"0100111101hhhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHL(BReg rd, BReg rn, BReg rm)
{
    emit<"01011110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSHLU(BReg rd, BReg rn, ImmRange<0, 7> shift)
{
    emit<"0111111100001bbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(HReg rd, HReg rn, ImmRange<0, 15> shift)
{
    emit<"011111110001hbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(SReg rd, SReg rn, ImmRange<0, 31> shift)
{
    emit<"01111111001hhbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(DReg rd, DReg rn, ImmRange<0, 63> shift)
{
    emit<"0111111101hhhbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_8B rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0010111100001bbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_16B rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0110111100001bbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_4H rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"001011110001hbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_8H rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"011011110001hbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_2S rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00101111001hhbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_4S rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01101111001hhbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHLU(VReg_2D rd, VReg_2D rn, ImmRange<0, 63> shift)
{
    emit<"0110111101hhhbbb011001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SQSHRN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0101111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"010111110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01011111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHRUN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0111111100001bbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRUN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"011111110001hbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRUN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01111111001hhbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHRUN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRUN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SQSHRUN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRUN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SQSHRUN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSHRUN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb100001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SQSUB(BReg rd, BReg rn, BReg rm)
{
    emit<"01011110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(HReg rd, HReg rn, HReg rm)
{
    emit<"01011110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(SReg rd, SReg rn, SReg rm)
{
    emit<"01011110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQSUB(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SQXTN(BReg rd, HReg rn)
{
    emit<"0101111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN(HReg rd, SReg rn)
{
    emit<"0101111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN(SReg rd, DReg rn)
{
    emit<"0101111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN(VReg_8B rd, VReg_8H rn)
{
    emit<"0000111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN2(VReg_16B rd, VReg_8H rn)
{
    emit<"0100111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN(VReg_4H rd, VReg_4S rn)
{
    emit<"0000111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN2(VReg_8H rd, VReg_4S rn)
{
    emit<"0100111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN(VReg_2S rd, VReg_2D rn)
{
    emit<"0000111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0100111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(BReg rd, HReg rn)
{
    emit<"0111111000100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(HReg rd, SReg rn)
{
    emit<"0111111001100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(SReg rd, DReg rn)
{
    emit<"0111111010100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(VReg_8B rd, VReg_8H rn)
{
    emit<"0010111000100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN2(VReg_16B rd, VReg_8H rn)
{
    emit<"0110111000100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(VReg_4H rd, VReg_4S rn)
{
    emit<"0010111001100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN2(VReg_8H rd, VReg_4S rn)
{
    emit<"0110111001100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN(VReg_2S rd, VReg_2D rn)
{
    emit<"0010111010100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SQXTUN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0110111010100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void SRHADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRHADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRHADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRHADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRHADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRHADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRI(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0111111101hhhbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SRI(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRI(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRI(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRI(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRI(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRI(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRI(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0110111101hhhbbb010001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SRSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SRSHR(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0101111101hhhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SRSHR(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRSHR(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRSHR(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRSHR(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRSHR(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRSHR(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRSHR(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0100111101hhhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SRSRA(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0101111101hhhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SRSRA(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRSRA(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SRSRA(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRSRA(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SRSRA(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRSRA(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SRSRA(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0100111101hhhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01011110111mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110111mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSHLL(VReg_8H rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0000111100001bbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHLL2(VReg_8H rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0100111100001bbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHLL(VReg_4S rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"000011110001hbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHLL2(VReg_4S rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"010011110001hbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHLL(VReg_2D rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00001111001hhbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHLL2(VReg_2D rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01001111001hhbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void SSHR(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0101111101hhhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SSHR(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SSHR(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SSHR(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SSHR(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SSHR(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SSHR(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SSHR(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0100111101hhhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SSRA(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0101111101hhhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SSRA(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0000111100001bbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SSRA(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0100111100001bbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void SSRA(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"000011110001hbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SSRA(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"010011110001hbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void SSRA(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00001111001hhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SSRA(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01001111001hhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void SSRA(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0100111101hhhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void SSUBL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW(VReg_8H rd, VReg_8H rn, VReg_8B rm)
{
    emit<"00001110001mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW2(VReg_8H rd, VReg_8H rn, VReg_16B rm)
{
    emit<"01001110001mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW(VReg_4S rd, VReg_4S rn, VReg_4H rm)
{
    emit<"00001110011mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW2(VReg_4S rd, VReg_4S rn, VReg_8H rm)
{
    emit<"01001110011mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW(VReg_2D rd, VReg_2D rn, VReg_2S rm)
{
    emit<"00001110101mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SSUBW2(VReg_2D rd, VReg_2D rn, VReg_4S rm)
{
    emit<"01001110101mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ST1(List<VReg_8B, 1> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 1> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 1> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 1> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 1> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 1> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 1> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 1> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110010011111011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110010011111011100nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110010011111011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110010011111011101nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110010011111011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110010011111011110nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0000110010011111011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0100110010011111011111nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011100nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_16B, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011100nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011101nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8H, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011101nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011110nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4S, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011110nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_1D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011111nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2D, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011111nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111101000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111101001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111101010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111101011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm101000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm101000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm101001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm101001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm101010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm101010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_1D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm101011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm101011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111011000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111011001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111011010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111011011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_1D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm011011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm011011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111001000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111001001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111001010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111001011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST1(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm001000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm001000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm001001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm001001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm001010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm001010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_1D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm001011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm001011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST1(List<BElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<HElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<SElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<DElem, 1> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<BElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<1>)
{
    emit<"0Q00110110011111000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<BElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm000Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST1(List<HElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0Q00110110011111010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<HElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm010Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST1(List<SElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110110011111100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<SElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm100S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST1(List<DElem, 1> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110110011111100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST1(List<DElem, 1> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm100001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST2(List<VReg_8B, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_16B, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_4H, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_8H, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_2S, 2> tlist, XRegSp addr_n)
{
    emit<"0000110000000000100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_4S, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_2D, 2> tlist, XRegSp addr_n)
{
    emit<"0100110000000000100011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111100000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111100001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0000110010011111100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111100010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0100110010011111100011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST2(List<VReg_8B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm100000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_16B, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm100000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_4H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm100001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_8H, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm100001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_2S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm100010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_4S, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm100010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<VReg_2D, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm100011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST2(List<BElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<HElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<SElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<DElem, 2> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<BElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<2>)
{
    emit<"0Q00110110111111000Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<BElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm000Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST2(List<HElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110110111111010Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<HElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm010Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST2(List<SElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110110111111100S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<SElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm100S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST2(List<DElem, 2> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0Q00110110111111100001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST2(List<DElem, 2> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm100001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST3(List<VReg_8B, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_16B, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_4H, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_8H, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_2S, 3> tlist, XRegSp addr_n)
{
    emit<"0000110000000000010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_4S, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_2D, 3> tlist, XRegSp addr_n)
{
    emit<"0100110000000000010011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111010000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111010001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0000110010011111010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111010010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<48>)
{
    emit<"0100110010011111010011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST3(List<VReg_8B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm010000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_16B, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm010000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_4H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm010001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_8H, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm010001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_2S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm010010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_4S, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm010010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<VReg_2D, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm010011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST3(List<BElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<HElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<SElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<DElem, 3> tlist, XRegSp addr_n)
{
    emit<"0Q00110100000000101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<BElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<3>)
{
    emit<"0Q00110110011111001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<BElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm001Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST3(List<HElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<6>)
{
    emit<"0Q00110110011111011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<HElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm011Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST3(List<SElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<12>)
{
    emit<"0Q00110110011111101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<SElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm101S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST3(List<DElem, 3> tlist, XRegSp addr_n, PostIndexed, ImmConst<24>)
{
    emit<"0Q00110110011111101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST3(List<DElem, 3> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101100mmmmm101001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST4(List<VReg_8B, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_16B, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_4H, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_8H, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_2S, 4> tlist, XRegSp addr_n)
{
    emit<"0000110000000000000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_4S, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_2D, 4> tlist, XRegSp addr_n)
{
    emit<"0100110000000000000011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111000000nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111000001nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0000110010011111000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111000010nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<64>)
{
    emit<"0100110010011111000011nnnnnttttt", "t", "n">(tlist, addr_n);
}
void ST4(List<VReg_8B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm000000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_16B, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm000000nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_4H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm000001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_8H, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm000001nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_2S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"00001100100mmmmm000010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_4S, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm000010nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<VReg_2D, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"01001100100mmmmm000011nnnnnttttt", "t", "n", "m">(tlist, addr_n, xm);
}
void ST4(List<BElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<HElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<SElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<DElem, 4> tlist, XRegSp addr_n)
{
    emit<"0Q00110100100000101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<BElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<4>)
{
    emit<"0Q00110110111111001Szznnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<BElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm001Szznnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST4(List<HElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<8>)
{
    emit<"0Q00110110111111011Sz0nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<HElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm011Sz0nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST4(List<SElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<16>)
{
    emit<"0Q00110110111111101S00nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<SElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm101S00nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void ST4(List<DElem, 4> tlist, XRegSp addr_n, PostIndexed, ImmConst<32>)
{
    emit<"0Q00110110111111101001nnnnnttttt", "t", "QSz", "n">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n);
}
void ST4(List<DElem, 4> tlist, XRegSp addr_n, PostIndexed, XReg xm)
{
    if (xm.index() == 31)
        throw OaknutException{ExceptionType::InvalidOperandXZR};
    emit<"0Q001101101mmmmm101001nnnnnttttt", "t", "QSz", "n", "m">(tlist.m_base.reg_index(), tlist.m_base.elem_index(), addr_n, xm);
}
void STNP(SReg rt1, SReg rt2, XRegSp addr_n, SOffset<9, 2> offset = 0)
{
    emit<"0010110000iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STNP(DReg rt1, DReg rt2, XRegSp addr_n, SOffset<10, 3> offset = 0)
{
    emit<"0110110000iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STNP(QReg rt1, QReg rt2, XRegSp addr_n, SOffset<11, 4> offset = 0)
{
    emit<"1010110000iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(SReg rt1, SReg rt2, XRegSp addr_n, PostIndexed, SOffset<9, 2> offset)
{
    emit<"0010110010iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(DReg rt1, DReg rt2, XRegSp addr_n, PostIndexed, SOffset<10, 3> offset)
{
    emit<"0110110010iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(QReg rt1, QReg rt2, XRegSp addr_n, PostIndexed, SOffset<11, 4> offset)
{
    emit<"1010110010iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(SReg rt1, SReg rt2, XRegSp addr_n, PreIndexed, SOffset<9, 2> offset)
{
    emit<"0010110110iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(DReg rt1, DReg rt2, XRegSp addr_n, PreIndexed, SOffset<10, 3> offset)
{
    emit<"0110110110iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(QReg rt1, QReg rt2, XRegSp addr_n, PreIndexed, SOffset<11, 4> offset)
{
    emit<"1010110110iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(SReg rt1, SReg rt2, XRegSp addr_n, SOffset<9, 2> offset = 0)
{
    emit<"0010110100iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(DReg rt1, DReg rt2, XRegSp addr_n, SOffset<10, 3> offset = 0)
{
    emit<"0110110100iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STP(QReg rt1, QReg rt2, XRegSp addr_n, SOffset<11, 4> offset = 0)
{
    emit<"1010110100iiiiiiiuuuuunnnnnttttt", "t", "u", "n", "i">(rt1, rt2, addr_n, offset);
}
void STR(BReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"00111100000iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(HReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"01111100000iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(SReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"10111100000iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(DReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"11111100000iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(QReg rt, XRegSp addr_n, PostIndexed, SOffset<9, 0> offset)
{
    emit<"00111100100iiiiiiiii01nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(BReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"00111100000iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(HReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"01111100000iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(SReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"10111100000iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(DReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"11111100000iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(QReg rt, XRegSp addr_n, PreIndexed, SOffset<9, 0> offset)
{
    emit<"00111100100iiiiiiiii11nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(BReg rt, XRegSp addr_n, POffset<12, 0> offset = 0)
{
    emit<"0011110100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(HReg rt, XRegSp addr_n, POffset<13, 1> offset = 0)
{
    emit<"0111110100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(SReg rt, XRegSp addr_n, POffset<14, 2> offset = 0)
{
    emit<"1011110100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(DReg rt, XRegSp addr_n, POffset<15, 3> offset = 0)
{
    emit<"1111110100iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(QReg rt, XRegSp addr_n, POffset<16, 4> offset = 0)
{
    emit<"0011110110iiiiiiiiiiiinnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STR(BReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 0> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111100001mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void STR(HReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 1> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"01111100001mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void STR(SReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 2> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"10111100001mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void STR(DReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 3> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"11111100001mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void STR(QReg rt, XRegSp xn, RReg rm, IndexExt ext = IndexExt::LSL, ImmChoice<0, 4> amount = 0)
{
    indexext_verify_reg_size(ext, rm);
    emit<"00111100101mmmmmpppS10nnnnnttttt", "t", "n", "m", "p", "S">(rt, xn, rm, ext, amount);
}
void STUR(BReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"00111100000iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STUR(HReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"01111100000iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STUR(SReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"10111100000iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STUR(DReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"11111100000iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void STUR(QReg rt, XRegSp addr_n, SOffset<9, 0> offset = 0)
{
    emit<"00111100100iiiiiiiii00nnnnnttttt", "t", "n", "i">(rt, addr_n, offset);
}
void SUB(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUB(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm100001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN(VReg_8B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"00001110001mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN2(VReg_16B rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110001mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN(VReg_4H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"00001110011mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN2(VReg_8H rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110011mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN(VReg_2S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"00001110101mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUBHN2(VReg_4S rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110101mmmmm011000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void SUQADD(BReg rd, BReg rn)
{
    emit<"0101111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(HReg rd, HReg rn)
{
    emit<"0101111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(SReg rd, SReg rn)
{
    emit<"0101111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(DReg rd, DReg rn)
{
    emit<"0101111011100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_8B rd, VReg_8B rn)
{
    emit<"0000111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_16B rd, VReg_16B rn)
{
    emit<"0100111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_4H rd, VReg_4H rn)
{
    emit<"0000111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_8H rd, VReg_8H rn)
{
    emit<"0100111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SUQADD(VReg_2D rd, VReg_2D rn)
{
    emit<"0100111011100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL(VReg_8H rd, VReg_8B rn)
{
    emit<"0000111100001000101001nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL2(VReg_8H rd, VReg_16B rn)
{
    emit<"0100111100001000101001nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL(VReg_4S rd, VReg_4H rn)
{
    emit<"000011110001h000101001nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL2(VReg_4S rd, VReg_8H rn)
{
    emit<"010011110001h000101001nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL(VReg_2D rd, VReg_2S rn)
{
    emit<"00001111001hh000101001nnnnnddddd", "d", "n">(rd, rn);
}
void SXTL2(VReg_2D rd, VReg_4S rn)
{
    emit<"01001111001hh000101001nnnnnddddd", "d", "n">(rd, rn);
}
void TBL(VReg_8B rd, List<VReg_16B, 2> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm001000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_16B rd, List<VReg_16B, 2> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm001000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_8B rd, List<VReg_16B, 3> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm010000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_16B rd, List<VReg_16B, 3> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm010000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_8B rd, List<VReg_16B, 4> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm011000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_16B rd, List<VReg_16B, 4> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm011000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_8B rd, List<VReg_16B, 1> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm000000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBL(VReg_16B rd, List<VReg_16B, 1> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm000000nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_8B rd, List<VReg_16B, 2> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm001100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_16B rd, List<VReg_16B, 2> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm001100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_8B rd, List<VReg_16B, 3> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm010100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_16B rd, List<VReg_16B, 3> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm010100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_8B rd, List<VReg_16B, 4> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm011100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_16B rd, List<VReg_16B, 4> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm011100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_8B rd, List<VReg_16B, 1> nlist, VReg_8B rm)
{
    emit<"00001110000mmmmm000100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TBX(VReg_16B rd, List<VReg_16B, 1> nlist, VReg_16B rm)
{
    emit<"01001110000mmmmm000100nnnnnddddd", "d", "n", "m">(rd, nlist, rm);
}
void TRN1(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN1(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm001010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void TRN2(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm011010nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABA(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm011111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABAL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm010100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm011101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UABDL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm011100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADALP(VReg_4H rd, VReg_8B rn)
{
    emit<"0010111000100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADALP(VReg_8H rd, VReg_16B rn)
{
    emit<"0110111000100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADALP(VReg_2S rd, VReg_4H rn)
{
    emit<"0010111001100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADALP(VReg_4S rd, VReg_8H rn)
{
    emit<"0110111001100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADALP(VReg_1D rd, VReg_2S rn)
{
    emit<"0010111010100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADALP(VReg_2D rd, VReg_4S rn)
{
    emit<"0110111010100000011010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm000000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDLP(VReg_4H rd, VReg_8B rn)
{
    emit<"0010111000100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLP(VReg_8H rd, VReg_16B rn)
{
    emit<"0110111000100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLP(VReg_2S rd, VReg_4H rn)
{
    emit<"0010111001100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLP(VReg_4S rd, VReg_8H rn)
{
    emit<"0110111001100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLP(VReg_1D rd, VReg_2S rn)
{
    emit<"0010111010100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLP(VReg_2D rd, VReg_4S rn)
{
    emit<"0110111010100000001010nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLV(HReg rd, VReg_8B rn)
{
    emit<"0010111000110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLV(HReg rd, VReg_16B rn)
{
    emit<"0110111000110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLV(SReg rd, VReg_4H rn)
{
    emit<"0010111001110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLV(SReg rd, VReg_8H rn)
{
    emit<"0110111001110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void UADDLV(DReg rd, VReg_4S rn)
{
    emit<"0110111010110000001110nnnnnddddd", "d", "n">(rd, rn);
}
void UADDW(VReg_8H rd, VReg_8H rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDW2(VReg_8H rd, VReg_8H rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDW(VReg_4S rd, VReg_4S rn, VReg_4H rm)
{
    emit<"00101110011mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDW2(VReg_4S rd, VReg_4S rn, VReg_8H rm)
{
    emit<"01101110011mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDW(VReg_2D rd, VReg_2D rn, VReg_2S rm)
{
    emit<"00101110101mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UADDW2(VReg_2D rd, VReg_2D rn, VReg_4S rm)
{
    emit<"01101110101mmmmm000100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UCVTF(SReg rd, WReg wn, ImmRange<1, 32> fbits)
{
    emit<"0001111000000011SSSSSSnnnnnddddd", "d", "n", "S">(rd, wn, 64 - fbits.value());
}
void UCVTF(DReg rd, WReg wn, ImmRange<1, 32> fbits)
{
    emit<"0001111001000011SSSSSSnnnnnddddd", "d", "n", "S">(rd, wn, 64 - fbits.value());
}
void UCVTF(SReg rd, XReg xn, ImmRange<1, 64> fbits)
{
    emit<"1001111000000011SSSSSSnnnnnddddd", "d", "n", "S">(rd, xn, 64 - fbits.value());
}
void UCVTF(DReg rd, XReg xn, ImmRange<1, 64> fbits)
{
    emit<"1001111001000011SSSSSSnnnnnddddd", "d", "n", "S">(rd, xn, 64 - fbits.value());
}
void UCVTF(SReg rd, WReg wn)
{
    emit<"0001111000100011000000nnnnnddddd", "d", "n">(rd, wn);
}
void UCVTF(DReg rd, WReg wn)
{
    emit<"0001111001100011000000nnnnnddddd", "d", "n">(rd, wn);
}
void UCVTF(SReg rd, XReg xn)
{
    emit<"1001111000100011000000nnnnnddddd", "d", "n">(rd, xn);
}
void UCVTF(DReg rd, XReg xn)
{
    emit<"1001111001100011000000nnnnnddddd", "d", "n">(rd, xn);
}
void UCVTF(HReg rd, HReg rn, ImmRange<1, 16> fbits)
{
    emit<"011111110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void UCVTF(SReg rd, SReg rn, ImmRange<1, 32> fbits)
{
    emit<"01111111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void UCVTF(DReg rd, DReg rn, ImmRange<1, 64> fbits)
{
    emit<"0111111101hhhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void UCVTF(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> fbits)
{
    emit<"001011110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void UCVTF(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> fbits)
{
    emit<"011011110001hbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - fbits.value());
}
void UCVTF(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> fbits)
{
    emit<"00101111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void UCVTF(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> fbits)
{
    emit<"01101111001hhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - fbits.value());
}
void UCVTF(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> fbits)
{
    emit<"0110111101hhhbbb111001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - fbits.value());
}
void UCVTF(SReg rd, SReg rn)
{
    emit<"0111111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(DReg rd, DReg rn)
{
    emit<"0111111001100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111000100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UCVTF(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111001100001110110nnnnnddddd", "d", "n">(rd, rn);
}
void UHADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm000001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UHSUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAX(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm011001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm101001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMAXV(BReg rd, VReg_8B rn)
{
    emit<"0010111000110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMAXV(BReg rd, VReg_16B rn)
{
    emit<"0110111000110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMAXV(HReg rd, VReg_4H rn)
{
    emit<"0010111001110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMAXV(HReg rd, VReg_8H rn)
{
    emit<"0110111001110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMAXV(SReg rd, VReg_4S rn)
{
    emit<"0110111010110000101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMIN(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMIN(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMIN(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMIN(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMIN(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMIN(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm011011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINP(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm101011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMINV(BReg rd, VReg_8B rn)
{
    emit<"0010111000110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMINV(BReg rd, VReg_16B rn)
{
    emit<"0110111000110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMINV(HReg rd, VReg_4H rn)
{
    emit<"0010111001110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMINV(HReg rd, VReg_8H rn)
{
    emit<"0110111001110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMINV(SReg rd, VReg_4S rn)
{
    emit<"0110111010110001101010nnnnnddddd", "d", "n">(rd, rn);
}
void UMLAL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm0010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMLAL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm0010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMLAL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm0010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMLAL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm0010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMLAL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLAL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLAL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLAL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLAL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLAL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm100000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm0110H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMLSL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm0110H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMLSL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm0110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMLSL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm0110H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMLSL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMLSL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm101000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMOV(WReg wd, BElem en)
{
    emit<"00001110000xxxx1001111nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void UMOV(WReg wd, HElem en)
{
    emit<"00001110000xxx10001111nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void UMOV(WReg wd, SElem en)
{
    emit<"00001110000xx100001111nnnnnddddd", "d", "n", "x">(wd, en.reg_index(), en.elem_index());
}
void UMOV(XReg xd, DElem en)
{
    emit<"01001110000x1000001111nnnnnddddd", "d", "n", "x">(xd, en.reg_index(), en.elem_index());
}
void UMULL(VReg_4S rd, VReg_4H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0010111101LMmmmm1010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMULL2(VReg_4S rd, VReg_8H rn, HElem em)
{
    if (em.reg_index() >= 16)
        throw OaknutException{ExceptionType::InvalidCombination};
    emit<"0110111101LMmmmm1010H0nnnnnddddd", "d", "n", "m", "H", "L", "M">(rd, rn, em.reg_index(), em.elem_index() >> 2, (em.elem_index() >> 1) & 1, em.elem_index() & 1);
}
void UMULL(VReg_2D rd, VReg_2S rn, SElem em)
{
    emit<"0010111110LMmmmm1010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMULL2(VReg_2D rd, VReg_4S rn, SElem em)
{
    emit<"0110111110LMmmmm1010H0nnnnnddddd", "d", "n", "Mm", "H", "L">(rd, rn, em.reg_index(), em.elem_index() >> 1, em.elem_index() & 1);
}
void UMULL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMULL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMULL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMULL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMULL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UMULL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm110000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(BReg rd, BReg rn, BReg rm)
{
    emit<"01111110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQADD(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm000011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(BReg rd, BReg rn, BReg rm)
{
    emit<"01111110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm010111nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQRSHRN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0111111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQRSHRN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"011111110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQRSHRN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01111111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQRSHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQRSHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQRSHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQRSHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQRSHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQRSHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb100111nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQSHL(BReg rd, BReg rn, ImmRange<0, 7> shift)
{
    emit<"0111111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(HReg rd, HReg rn, ImmRange<0, 15> shift)
{
    emit<"011111110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(SReg rd, SReg rn, ImmRange<0, 31> shift)
{
    emit<"01111111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(DReg rd, DReg rn, ImmRange<0, 63> shift)
{
    emit<"0111111101hhhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_8B rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0010111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_16B rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0110111100001bbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_4H rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"001011110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_8H rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"011011110001hbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_2S rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00101111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_4S rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01101111001hhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(VReg_2D rd, VReg_2D rn, ImmRange<0, 63> shift)
{
    emit<"0110111101hhhbbb011101nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void UQSHL(BReg rd, BReg rn, BReg rm)
{
    emit<"01111110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm010011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSHRN(BReg rd, HReg rn, ImmRange<1, 8> shift)
{
    emit<"0111111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQSHRN(HReg rd, SReg rn, ImmRange<1, 16> shift)
{
    emit<"011111110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQSHRN(SReg rd, DReg rn, ImmRange<1, 32> shift)
{
    emit<"01111111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQSHRN(VReg_8B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQSHRN2(VReg_16B rd, VReg_8H rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void UQSHRN(VReg_4H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQSHRN2(VReg_8H rd, VReg_4S rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void UQSHRN(VReg_2S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQSHRN2(VReg_4S rd, VReg_2D rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb100101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void UQSUB(BReg rd, BReg rn, BReg rm)
{
    emit<"01111110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(HReg rd, HReg rn, HReg rm)
{
    emit<"01111110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(SReg rd, SReg rn, SReg rm)
{
    emit<"01111110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQSUB(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm001011nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UQXTN(BReg rd, HReg rn)
{
    emit<"0111111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN(HReg rd, SReg rn)
{
    emit<"0111111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN(SReg rd, DReg rn)
{
    emit<"0111111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN(VReg_8B rd, VReg_8H rn)
{
    emit<"0010111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN2(VReg_16B rd, VReg_8H rn)
{
    emit<"0110111000100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN(VReg_4H rd, VReg_4S rn)
{
    emit<"0010111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN2(VReg_8H rd, VReg_4S rn)
{
    emit<"0110111001100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN(VReg_2S rd, VReg_2D rn)
{
    emit<"0010111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void UQXTN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0110111010100001010010nnnnnddddd", "d", "n">(rd, rn);
}
void URECPE(VReg_2S rd, VReg_2S rn)
{
    emit<"0000111010100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void URECPE(VReg_4S rd, VReg_4S rn)
{
    emit<"0100111010100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void URHADD(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URHADD(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URHADD(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URHADD(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URHADD(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URHADD(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm000101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm010101nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void URSHR(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0111111101hhhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void URSHR(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void URSHR(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void URSHR(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void URSHR(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void URSHR(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void URSHR(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void URSHR(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0110111101hhhbbb001001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void URSQRTE(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void URSQRTE(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100001110010nnnnnddddd", "d", "n">(rd, rn);
}
void URSRA(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0111111101hhhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void URSRA(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void URSRA(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void URSRA(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void URSRA(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void URSRA(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void URSRA(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void URSRA(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0110111101hhhbbb001101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void USHL(DReg rd, DReg rn, DReg rm)
{
    emit<"01111110111mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHL(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01101110111mmmmm010001nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USHLL(VReg_8H rd, VReg_8B rn, ImmRange<0, 7> shift)
{
    emit<"0010111100001bbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHLL2(VReg_8H rd, VReg_16B rn, ImmRange<0, 7> shift)
{
    emit<"0110111100001bbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHLL(VReg_4S rd, VReg_4H rn, ImmRange<0, 15> shift)
{
    emit<"001011110001hbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHLL2(VReg_4S rd, VReg_8H rn, ImmRange<0, 15> shift)
{
    emit<"011011110001hbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHLL(VReg_2D rd, VReg_2S rn, ImmRange<0, 31> shift)
{
    emit<"00101111001hhbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHLL2(VReg_2D rd, VReg_4S rn, ImmRange<0, 31> shift)
{
    emit<"01101111001hhbbb101001nnnnnddddd", "d", "n", "hb">(rd, rn, shift.value());
}
void USHR(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0111111101hhhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void USHR(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void USHR(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void USHR(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void USHR(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void USHR(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void USHR(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void USHR(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0110111101hhhbbb000001nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void USQADD(BReg rd, BReg rn)
{
    emit<"0111111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(HReg rd, HReg rn)
{
    emit<"0111111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(SReg rd, SReg rn)
{
    emit<"0111111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(DReg rd, DReg rn)
{
    emit<"0111111011100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_8B rd, VReg_8B rn)
{
    emit<"0010111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_16B rd, VReg_16B rn)
{
    emit<"0110111000100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_4H rd, VReg_4H rn)
{
    emit<"0010111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_8H rd, VReg_8H rn)
{
    emit<"0110111001100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_2S rd, VReg_2S rn)
{
    emit<"0010111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_4S rd, VReg_4S rn)
{
    emit<"0110111010100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USQADD(VReg_2D rd, VReg_2D rn)
{
    emit<"0110111011100000001110nnnnnddddd", "d", "n">(rd, rn);
}
void USRA(DReg rd, DReg rn, ImmRange<1, 64> shift)
{
    emit<"0111111101hhhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void USRA(VReg_8B rd, VReg_8B rn, ImmRange<1, 8> shift)
{
    emit<"0010111100001bbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void USRA(VReg_16B rd, VReg_16B rn, ImmRange<1, 8> shift)
{
    emit<"0110111100001bbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 16 - shift.value());
}
void USRA(VReg_4H rd, VReg_4H rn, ImmRange<1, 16> shift)
{
    emit<"001011110001hbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void USRA(VReg_8H rd, VReg_8H rn, ImmRange<1, 16> shift)
{
    emit<"011011110001hbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 32 - shift.value());
}
void USRA(VReg_2S rd, VReg_2S rn, ImmRange<1, 32> shift)
{
    emit<"00101111001hhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void USRA(VReg_4S rd, VReg_4S rn, ImmRange<1, 32> shift)
{
    emit<"01101111001hhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 64 - shift.value());
}
void USRA(VReg_2D rd, VReg_2D rn, ImmRange<1, 64> shift)
{
    emit<"0110111101hhhbbb000101nnnnnddddd", "d", "n", "hb">(rd, rn, 128 - shift.value());
}
void USUBL(VReg_8H rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBL2(VReg_8H rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBL(VReg_4S rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBL2(VReg_4S rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBL(VReg_2D rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBL2(VReg_2D rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001000nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW(VReg_8H rd, VReg_8H rn, VReg_8B rm)
{
    emit<"00101110001mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW2(VReg_8H rd, VReg_8H rn, VReg_16B rm)
{
    emit<"01101110001mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW(VReg_4S rd, VReg_4S rn, VReg_4H rm)
{
    emit<"00101110011mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW2(VReg_4S rd, VReg_4S rn, VReg_8H rm)
{
    emit<"01101110011mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW(VReg_2D rd, VReg_2D rn, VReg_2S rm)
{
    emit<"00101110101mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void USUBW2(VReg_2D rd, VReg_2D rn, VReg_4S rm)
{
    emit<"01101110101mmmmm001100nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UXTL(VReg_8H rd, VReg_8B rn)
{
    emit<"0010111100001000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UXTL2(VReg_8H rd, VReg_16B rn)
{
    emit<"0110111100001000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UXTL(VReg_4S rd, VReg_4H rn)
{
    emit<"001011110001h000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UXTL2(VReg_4S rd, VReg_8H rn)
{
    emit<"011011110001h000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UXTL(VReg_2D rd, VReg_2S rn)
{
    emit<"00101111001hh000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UXTL2(VReg_2D rd, VReg_4S rn)
{
    emit<"01101111001hh000101001nnnnnddddd", "d", "n">(rd, rn);
}
void UZP1(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP1(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm000110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void UZP2(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm010110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void XTN(VReg_8B rd, VReg_8H rn)
{
    emit<"0000111000100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void XTN2(VReg_16B rd, VReg_8H rn)
{
    emit<"0100111000100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void XTN(VReg_4H rd, VReg_4S rn)
{
    emit<"0000111001100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void XTN2(VReg_8H rd, VReg_4S rn)
{
    emit<"0100111001100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void XTN(VReg_2S rd, VReg_2D rn)
{
    emit<"0000111010100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void XTN2(VReg_4S rd, VReg_2D rn)
{
    emit<"0100111010100001001010nnnnnddddd", "d", "n">(rd, rn);
}
void ZIP1(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP1(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm001110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_8B rd, VReg_8B rn, VReg_8B rm)
{
    emit<"00001110000mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_16B rd, VReg_16B rn, VReg_16B rm)
{
    emit<"01001110000mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_4H rd, VReg_4H rn, VReg_4H rm)
{
    emit<"00001110010mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_8H rd, VReg_8H rn, VReg_8H rm)
{
    emit<"01001110010mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_2S rd, VReg_2S rn, VReg_2S rm)
{
    emit<"00001110100mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_4S rd, VReg_4S rn, VReg_4S rm)
{
    emit<"01001110100mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
void ZIP2(VReg_2D rd, VReg_2D rn, VReg_2D rm)
{
    emit<"01001110110mmmmm011110nnnnnddddd", "d", "n", "m">(rd, rn, rm);
}
