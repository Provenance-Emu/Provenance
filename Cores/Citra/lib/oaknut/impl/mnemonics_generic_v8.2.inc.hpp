// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void BFC(WReg wd, Imm<5> lsb, Imm<5> width)
{
    if (width.value() == 0 || width.value() > (32 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"0011001100rrrrrrssssss11111ddddd", "d", "r", "s">(wd, (~lsb.value() + 1) & 31, width.value() - 1);
}
void BFC(XReg xd, Imm<6> lsb, Imm<6> width)
{
    if (width.value() == 0 || width.value() > (64 - lsb.value()))
        throw OaknutException{ExceptionType::InvalidBitWidth};
    emit<"1011001101rrrrrrssssss11111ddddd", "d", "r", "s">(xd, (~lsb.value() + 1) & 63, width.value() - 1);
}
void ESB()
{
    emit<"11010101000000110010001000011111">();
}
void PSB()
{
    emit<"11010101000000110010001000111111">();
}
