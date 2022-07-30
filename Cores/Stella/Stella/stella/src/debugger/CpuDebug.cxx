//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include <sstream>

#include "M6502.hxx"
#include "System.hxx"
#include "Debugger.hxx"
#include "TIADebug.hxx"

#include "CpuDebug.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CpuDebug::CpuDebug(Debugger& dbg, Console& console)
  : DebuggerSystem(dbg, console),
    my6502{mySystem.m6502()}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const DebuggerState& CpuDebug::getState()
{
  myState.PC = my6502.PC;
  myState.SP = my6502.SP;
  myState.PS = my6502.PS();
  myState.A  = my6502.A;
  myState.X  = my6502.X;
  myState.Y  = my6502.Y;

  myState.srcS = my6502.lastSrcAddressS();
  myState.srcA = my6502.lastSrcAddressA();
  myState.srcX = my6502.lastSrcAddressX();
  myState.srcY = my6502.lastSrcAddressY();
  myState.dest = my6502.lastWriteAddress();

  Debugger::set_bits(myState.PS, myState.PSbits);

  return myState;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::saveOldState()
{
  myOldState.PC = my6502.PC;
  myOldState.SP = my6502.SP;
  myOldState.PS = my6502.PS();
  myOldState.A  = my6502.A;
  myOldState.X  = my6502.X;
  myOldState.Y  = my6502.Y;

  myOldState.srcS = my6502.lastSrcAddressS();
  myOldState.srcA = my6502.lastSrcAddressA();
  myOldState.srcX = my6502.lastSrcAddressX();
  myOldState.srcY = my6502.lastSrcAddressY();
  myOldState.dest = my6502.lastWriteAddress();

  Debugger::set_bits(myOldState.PS, myOldState.PSbits);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::pc() const
{
  return mySystem.m6502().PC;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::sp() const
{
  return mySystem.m6502().SP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::a() const
{
  return mySystem.m6502().A;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::x() const
{
  return mySystem.m6502().X;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::y() const
{
  return mySystem.m6502().Y;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::n() const
{
  return mySystem.m6502().N;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::v() const
{
  return mySystem.m6502().V;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::b() const
{
  return mySystem.m6502().B;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::d() const
{
  return mySystem.m6502().D;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::i() const
{
  return mySystem.m6502().I;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::z() const
{
  return !mySystem.m6502().notZ;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::c() const
{
  return mySystem.m6502().C;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CpuDebug::icycles() const
{
  return mySystem.m6502().icycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setPC(int pc)
{
  my6502.PC = static_cast<uInt16>(pc);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setSP(int sp)
{
  my6502.SP = static_cast<uInt8>(sp);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setPS(int ps)
{
  my6502.PS(ps);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setA(int a)
{
  my6502.A = static_cast<uInt8>(a);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setX(int x)
{
  my6502.X = static_cast<uInt8>(x);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setY(int y)
{
  my6502.Y = static_cast<uInt8>(y);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setN(bool on)
{
  my6502.N = on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setV(bool on)
{
  my6502.V = on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setB(bool)
{
  // nop - B is always true
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setD(bool on)
{
  my6502.D = on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setI(bool on)
{
  my6502.I = on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setZ(bool on)
{
  my6502.notZ = !on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setC(bool on)
{
  my6502.C = on;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::setCycles(int cycles)
{
  my6502.icycles = cycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleN()
{
  my6502.N = !my6502.N;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleV()
{
  my6502.V = !my6502.V;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleB()
{
  // nop - B is always true
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleD()
{
  my6502.D = !my6502.D;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleI()
{
  my6502.I = !my6502.I;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleZ()
{
  my6502.notZ = !my6502.notZ;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CpuDebug::toggleC()
{
  my6502.C = !my6502.C;
}
