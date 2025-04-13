// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

void CAS(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000101sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000111sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000111sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10001000101sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CAS(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11001000101sssss011111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11001000111sssss011111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11001000111sssss111111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11001000101sssss111111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000111sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000111sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000101sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00001000101sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000111sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000111sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000101sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01001000101sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASP(WReg ws, WReg ws2, WReg wt, WReg wt2, XRegSp xn)
{
    if (wt.index() + 1 != wt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (wt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (ws.index() + 1 != ws2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (ws.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"00001000001sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASPA(WReg ws, WReg ws2, WReg wt, WReg wt2, XRegSp xn)
{
    if (wt.index() + 1 != wt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (wt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (ws.index() + 1 != ws2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (ws.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"00001000011sssss011111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASPAL(WReg ws, WReg ws2, WReg wt, WReg wt2, XRegSp xn)
{
    if (wt.index() + 1 != wt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (wt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (ws.index() + 1 != ws2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (ws.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"00001000011sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASPL(WReg ws, WReg ws2, WReg wt, WReg wt2, XRegSp xn)
{
    if (wt.index() + 1 != wt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (wt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (ws.index() + 1 != ws2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (ws.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"00001000001sssss111111nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void CASP(XReg xs, XReg xs2, XReg xt, XReg xt2, XRegSp xn)
{
    if (xt.index() + 1 != xt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (xs.index() + 1 != xs2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xs.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"01001000001sssss011111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASPA(XReg xs, XReg xs2, XReg xt, XReg xt2, XRegSp xn)
{
    if (xt.index() + 1 != xt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (xs.index() + 1 != xs2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xs.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"01001000011sssss011111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASPAL(XReg xs, XReg xs2, XReg xt, XReg xt2, XRegSp xn)
{
    if (xt.index() + 1 != xt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (xs.index() + 1 != xs2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xs.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"01001000011sssss111111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void CASPL(XReg xs, XReg xs2, XReg xt, XReg xt2, XRegSp xn)
{
    if (xt.index() + 1 != xt2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xt.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    if (xs.index() + 1 != xs2.index())
        throw OaknutException{ExceptionType::InvalidPairSecond};
    if (xs.index() & 1)
        throw OaknutException{ExceptionType::InvalidPairFirst};
    emit<"01001000001sssss111111nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDADD(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADD(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss000000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDADDA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss000000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDADDAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss000000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDADDL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss000000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDADDAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDADDLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss000000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLR(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLR(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss000100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDCLRA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss000100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDCLRAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss000100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDCLRL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss000100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDCLRAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDCLRLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss000100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEOR(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEOR(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss001000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDEORA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss001000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDEORAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss001000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDEORL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss001000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDEORAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDEORLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss001000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDLAR(WReg wt, XRegSp xn)
{
    emit<"1000100011011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LDLAR(XReg xt, XRegSp xn)
{
    emit<"1100100011011111011111nnnnnttttt", "t", "n">(xt, xn);
}
void LDLARB(WReg wt, XRegSp xn)
{
    emit<"0000100011011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LDLARH(WReg wt, XRegSp xn)
{
    emit<"0100100011011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void LDSET(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSET(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss001100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSETA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss001100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSETAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss001100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSETL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss001100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSETAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSETLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss001100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAX(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAX(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss010000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMAXA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss010000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMAXAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss010000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMAXL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss010000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMAXAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMAXLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss010000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMIN(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMIN(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss010100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMINA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss010100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMINAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss010100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMINL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss010100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDSMINAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDSMINLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss010100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAX(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAX(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss011000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMAXA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss011000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMAXAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss011000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMAXL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss011000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMAXAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMAXLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss011000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMIN(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMIN(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss011100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMINA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss011100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMINAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss011100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMINL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss011100nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void LDUMINAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void LDUMINLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss011100nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void STADD(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STADDL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STADD(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss000000nnnnn11111", "s", "n">(xs, xn);
}
void STADDL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss000000nnnnn11111", "s", "n">(xs, xn);
}
void STADDB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STADDLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STADDH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STADDLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss000000nnnnn11111", "s", "n">(ws, xn);
}
void STCLR(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STCLRL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STCLR(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss000100nnnnn11111", "s", "n">(xs, xn);
}
void STCLRL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss000100nnnnn11111", "s", "n">(xs, xn);
}
void STCLRB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STCLRLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STCLRH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STCLRLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss000100nnnnn11111", "s", "n">(ws, xn);
}
void STEOR(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STEORL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STEOR(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss001000nnnnn11111", "s", "n">(xs, xn);
}
void STEORL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss001000nnnnn11111", "s", "n">(xs, xn);
}
void STEORB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STEORLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STEORH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STEORLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss001000nnnnn11111", "s", "n">(ws, xn);
}
void STLLR(WReg wt, XRegSp xn)
{
    emit<"1000100010011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void STLLR(XReg xt, XRegSp xn)
{
    emit<"1100100010011111011111nnnnnttttt", "t", "n">(xt, xn);
}
void STLLRB(WReg wt, XRegSp xn)
{
    emit<"0000100010011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void STLLRH(WReg wt, XRegSp xn)
{
    emit<"0100100010011111011111nnnnnttttt", "t", "n">(wt, xn);
}
void STSET(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSETL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSET(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss001100nnnnn11111", "s", "n">(xs, xn);
}
void STSETL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss001100nnnnn11111", "s", "n">(xs, xn);
}
void STSETB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSETLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSETH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSETLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss001100nnnnn11111", "s", "n">(ws, xn);
}
void STSMAX(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMAXL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMAX(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss010000nnnnn11111", "s", "n">(xs, xn);
}
void STSMAXL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss010000nnnnn11111", "s", "n">(xs, xn);
}
void STSMAXB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMAXLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMAXH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMAXLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss010000nnnnn11111", "s", "n">(ws, xn);
}
void STSMIN(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STSMINL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STSMIN(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss010100nnnnn11111", "s", "n">(xs, xn);
}
void STSMINL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss010100nnnnn11111", "s", "n">(xs, xn);
}
void STSMINB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STSMINLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STSMINH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STSMINLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss010100nnnnn11111", "s", "n">(ws, xn);
}
void STUMAX(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMAXL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMAX(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss011000nnnnn11111", "s", "n">(xs, xn);
}
void STUMAXL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss011000nnnnn11111", "s", "n">(xs, xn);
}
void STUMAXB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMAXLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMAXH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMAXLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss011000nnnnn11111", "s", "n">(ws, xn);
}
void STUMIN(WReg ws, XRegSp xn)
{
    emit<"10111000001sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void STUMINL(WReg ws, XRegSp xn)
{
    emit<"10111000011sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void STUMIN(XReg xs, XRegSp xn)
{
    emit<"11111000001sssss011100nnnnn11111", "s", "n">(xs, xn);
}
void STUMINL(XReg xs, XRegSp xn)
{
    emit<"11111000011sssss011100nnnnn11111", "s", "n">(xs, xn);
}
void STUMINB(WReg ws, XRegSp xn)
{
    emit<"00111000001sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void STUMINLB(WReg ws, XRegSp xn)
{
    emit<"00111000011sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void STUMINH(WReg ws, XRegSp xn)
{
    emit<"01111000001sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void STUMINLH(WReg ws, XRegSp xn)
{
    emit<"01111000011sssss011100nnnnn11111", "s", "n">(ws, xn);
}
void SWP(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000001sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPA(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000101sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPAL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000111sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPL(WReg ws, WReg wt, XRegSp xn)
{
    emit<"10111000011sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWP(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000001sssss100000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void SWPA(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000101sssss100000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void SWPAL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000111sssss100000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void SWPL(XReg xs, XReg xt, XRegSp xn)
{
    emit<"11111000011sssss100000nnnnnttttt", "s", "t", "n">(xs, xt, xn);
}
void SWPAB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000101sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPALB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000111sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000001sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPLB(WReg ws, WReg wt, XRegSp xn)
{
    emit<"00111000011sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPAH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000101sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPALH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000111sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000001sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
void SWPLH(WReg ws, WReg wt, XRegSp xn)
{
    emit<"01111000011sssss100000nnnnnttttt", "s", "t", "n">(ws, wt, xn);
}
