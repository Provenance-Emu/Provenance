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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef RIOT_DEBUG_HXX
#define RIOT_DEBUG_HXX

class M6532;
class Debugger;
class RiotDebug;

// Function type for RiotDebug instance methods
class RiotDebug;
using RiotMethod = int (RiotDebug::*)() const;

#include "DebuggerSystem.hxx"

class RiotState : public DebuggerState
{
  public:
    uInt8 SWCHA_R{0}, SWCHA_W{0}, SWACNT{0}, SWCHB_R{0}, SWCHB_W{0}, SWBCNT{0};
    BoolArray swchaReadBits;
    BoolArray swchaWriteBits;
    BoolArray swacntBits;
    BoolArray swchbReadBits;
    BoolArray swchbWriteBits;
    BoolArray swbcntBits;

    uInt8 TIM1T{0}, TIM8T{0}, TIM64T{0}, T1024T{0}, INTIM{0}, TIMINT{0};
    Int32 TIMCLKS{0}, INTIMCLKS{0}, TIMDIV{0};
    uInt16 timReadCycles{0};

    // These are actually from the TIA, but are I/O related
    uInt8 INPT0{0}, INPT1{0}, INPT2{0}, INPT3{0}, INPT4{0}, INPT5{0};
    bool INPTLatch{false}, INPTDump{false};
};

class RiotDebug : public DebuggerSystem
{
  public:
    RiotDebug(Debugger& dbg, Console& console);

    const DebuggerState& getState() override;
    const DebuggerState& getOldState() override { return myOldState; }

    void saveOldState() override;
    string toString() override;

    /* Port A and B registers */
    uInt8 swcha(int newVal = -1);
    uInt8 swacnt(int newVal = -1);
    uInt8 swchb(int newVal = -1);
    uInt8 swbcnt(int newVal = -1);

    /* TIA INPTx and VBLANK registers
       Techically not part of the RIOT, but more appropriately placed here */
    uInt8 inpt(int x);
    bool vblank(int bit);

    /* Timer registers & associated clock */
    uInt8 tim1T(int newVal = -1);
    uInt8 tim8T(int newVal = -1);
    uInt8 tim64T(int newVal = -1);
    uInt8 tim1024T(int newVal = -1);
    uInt8 intim() const;
    uInt8 timint() const;
    Int32 timClocks() const;
    Int32 intimClocks() const;
    Int32 timDivider() const;
    /* Debugger pseudo-registers for timer accesses */
    int timWrappedOnRead() const;
    int timWrappedOnWrite() const;

    int timReadCycles() const;
    int timintAsInt() const { return static_cast<int>(timint()); } // so we can use _timInt pseudo-register
    int intimAsInt() const { return static_cast<int>(intim()); }   // so we can use _inTim pseudo-register

    /* Console switches */
    bool switches(int newVal = -1);
    bool diffP0(int newVal = -1);
    bool diffP1(int newVal = -1);
    bool tvType(int newVal = -1);
    bool select(int newVal = -1);
    bool reset(int newVal = -1);

    /* Port A description */
    string dirP0String();
    string dirP1String();

    /* Port B description */
    string diffP0String();
    string diffP1String();
    string tvTypeString();
    string switchesString();

  private:
    RiotState myState;
    RiotState myOldState;

  private:
    // Following constructors and assignment operators not supported
    RiotDebug() = delete;
    RiotDebug(const RiotDebug&) = delete;
    RiotDebug(RiotDebug&&) = delete;
    RiotDebug& operator=(const RiotDebug&) = delete;
    RiotDebug& operator=(RiotDebug&&) = delete;
};

#endif
