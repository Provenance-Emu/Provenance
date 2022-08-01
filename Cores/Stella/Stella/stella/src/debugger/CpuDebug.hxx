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

#ifndef CPU_DEBUG_HXX
#define CPU_DEBUG_HXX

class M6502;
class System;

// Function type for CpuDebug instance methods
class CpuDebug;
using CpuMethod = int (CpuDebug::*)() const;

#include "DebuggerSystem.hxx"

class CpuState : public DebuggerState
{
  public:
    int PC{0}, SP{0}, PS{0}, A{0}, X{0}, Y{0};
    int srcS{0}, srcA{0}, srcX{0}, srcY{0}, dest{0};
    BoolArray PSbits;
};

class CpuDebug : public DebuggerSystem
{
  public:
    CpuDebug(Debugger& dbg, Console& console);

    const DebuggerState& getState() override;
    const DebuggerState& getOldState() override { return myOldState; }

    void saveOldState() override;
    string toString() override { return EmptyString; } // Not needed, since CPU stuff is always visible

    int pc() const;
    int sp() const;
    int a()  const;
    int x()  const;
    int y()  const;

    // These return int, not boolean!
    int n() const;
    int v() const;
    int b() const;
    int d() const;
    int i() const;
    int z() const;
    int c() const;

    int icycles() const;

    void setPC(int pc);
    void setSP(int sp);
    void setPS(int ps);
    void setA(int a);
    void setX(int x);
    void setY(int y);

    void setN(bool on);
    void setV(bool on);
    void setB(bool on);
    void setD(bool on);
    void setI(bool on);
    void setZ(bool on);
    void setC(bool on);

    void setCycles(int cycles);

    void toggleN();
    void toggleV();
    void toggleB();
    void toggleD();
    void toggleI();
    void toggleZ();
    void toggleC();

  private:
    M6502& my6502;

    CpuState myState;
    CpuState myOldState;

  private:
    // Following constructors and assignment operators not supported
    CpuDebug() = delete;
    CpuDebug(const CpuDebug&) = delete;
    CpuDebug(CpuDebug&&) = delete;
    CpuDebug& operator=(const CpuDebug&) = delete;
    CpuDebug& operator=(CpuDebug&&) = delete;
};

#endif
