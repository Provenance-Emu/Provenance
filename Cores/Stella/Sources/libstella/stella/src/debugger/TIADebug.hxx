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

#ifndef TIA_DEBUG_HXX
#define TIA_DEBUG_HXX

class Debugger;
class TIA;
class DelayQueueIterator;

// Function type for TIADebug instance methods
class TIADebug;
using TiaMethod = int (TIADebug::*)() const;

#include "DebuggerSystem.hxx"
#include "bspf.hxx"

class TiaState : public DebuggerState
{
  public:
    IntArray coluRegs;
    IntArray fixedCols;
    BoolArray cx;
    IntArray gr;
    BoolArray ref;
    BoolArray vdel;
    BoolArray resm;
    IntArray pos;
    IntArray hm;
    IntArray pf;
    IntArray size;
    IntArray aud;
    IntArray info;
    BoolArray vsb;

    // Indices for various IntArray above
    enum { P0, P1, M0, M1, BL };
};

class TIADebug : public DebuggerSystem
{
  public:
    TIADebug(Debugger& dbg, Console& console);
    TIA& tia() const { return myTIA; }

    const DebuggerState& getState() override;
    const DebuggerState& getOldState() override { return myOldState; }

    void saveOldState() override;
    string toString() override;
    string debugColors() const;
    static string palette();

    // TIA byte (or part of a byte) registers
    uInt8 nusiz0(int newVal = -1);
    uInt8 nusiz1(int newVal = -1);
    uInt8 nusizP0(int newVal = -1);
    uInt8 nusizP1(int newVal = -1);
    uInt8 nusizM0(int newVal = -1);
    uInt8 nusizM1(int newVal = -1);
    const string& nusizP0String() { return nusizStrings[nusizP0()]; }
    const string& nusizP1String() { return nusizStrings[nusizP1()]; }

    uInt8 coluP0(int newVal = -1);
    uInt8 coluP1(int newVal = -1);
    uInt8 coluPF(int newVal = -1);
    uInt8 coluBK(int newVal = -1);

    uInt8 sizeBL(int newVal = -1);
    uInt8 ctrlPF(int newVal = -1);

    uInt8 pf0(int newVal = -1);
    uInt8 pf1(int newVal = -1);
    uInt8 pf2(int newVal = -1);

    uInt8 grP0(int newVal = -1);
    uInt8 grP1(int newVal = -1);
    uInt8 posP0(int newVal = -1);
    uInt8 posP1(int newVal = -1);
    uInt8 posM0(int newVal = -1);
    uInt8 posM1(int newVal = -1);
    uInt8 posBL(int newVal = -1);
    uInt8 hmP0(int newVal = -1);
    uInt8 hmP1(int newVal = -1);
    uInt8 hmM0(int newVal = -1);
    uInt8 hmM1(int newVal = -1);
    uInt8 hmBL(int newVal = -1);

    uInt8 audC0(int newVal = -1);
    uInt8 audC1(int newVal = -1);
    uInt8 audF0(int newVal = -1);
    uInt8 audF1(int newVal = -1);
    uInt8 audV0(int newVal = -1);
    uInt8 audV1(int newVal = -1);
    string audFreq0();
    string audFreq1();

    void setGRP0Old(uInt8 b);
    void setGRP1Old(uInt8 b);
    void setENABLOld(bool b);

    // TIA bool registers
    bool refP0(int newVal = -1);
    bool refP1(int newVal = -1);
    bool enaM0(int newVal = -1);
    bool enaM1(int newVal = -1);
    bool enaBL(int newVal = -1);

    bool vdelP0(int newVal = -1);
    bool vdelP1(int newVal = -1);
    bool vdelBL(int newVal = -1);

    bool resMP0(int newVal = -1);
    bool resMP1(int newVal = -1);

    bool refPF(int newVal = -1);
    bool scorePF(int newVal = -1);
    bool priorityPF(int newVal = -1);

    bool vsync(int newVal = -1);
    bool vblank(int newVal = -1);

    /** Get specific bits in the collision register (used by collXX_XX) */
    bool collision(CollisionBit id, bool toggle = false) const;

    // Collision registers
    bool collM0_P1() const { return collision(CollisionBit::M0P1); }
    bool collM0_P0() const { return collision(CollisionBit::M0P0); }
    bool collM1_P0() const { return collision(CollisionBit::M1P0); }
    bool collM1_P1() const { return collision(CollisionBit::M1P1); }
    bool collP0_PF() const { return collision(CollisionBit::P0PF); }
    bool collP0_BL() const { return collision(CollisionBit::P0BL); }
    bool collP1_PF() const { return collision(CollisionBit::P1PF); }
    bool collP1_BL() const { return collision(CollisionBit::P1BL); }
    bool collM0_PF() const { return collision(CollisionBit::M0PF); }
    bool collM0_BL() const { return collision(CollisionBit::M0BL); }
    bool collM1_PF() const { return collision(CollisionBit::M1PF); }
    bool collM1_BL() const { return collision(CollisionBit::M1BL); }
    bool collBL_PF() const { return collision(CollisionBit::BLPF); }
    bool collP0_P1() const { return collision(CollisionBit::P0P1); }
    bool collM0_M1() const { return collision(CollisionBit::M0M1); }

    // TIA strobe registers
    void strobeWsync();
    void strobeRsync();
    void strobeResP0();
    void strobeResP1();
    void strobeResM0();
    void strobeResM1();
    void strobeResBL();
    void strobeHmove();
    void strobeHmclr();
    void strobeCxclr();

    // Read-only internal TIA state
    int scanlines() const;
    int scanlinesLastFrame() const;
    int frameCount() const;
    int frameCycles() const;
    int frameWsyncCycles() const;
    int cyclesLo() const;
    int cyclesHi() const;
    int clocksThisLine() const;
    int cyclesThisLine() const;
    bool vsync() const;
    bool vblank() const;
    int vsyncAsInt() const  { return static_cast<int>(vsync());  } // so we can use _vsync pseudo-register
    int vblankAsInt() const { return static_cast<int>(vblank()); } // so we can use _vblank pseudo-register

    shared_ptr<DelayQueueIterator> delayQueueIterator() const;

  private:
    /** Display a color patch for color at given index in the palette */
    static string colorSwatch(uInt8 c);

    string audFreq(uInt8 dist, uInt8 div) const;
    static string stringOnly(string_view value, bool changed = false);
    static string decWithLabel(string_view label, uInt16 value,
                               bool changed = false, uInt16 width = 3);
    static string hexWithLabel(string_view label, uInt16 value,
                               bool changed = false, uInt16 width = 2);
    static string binWithLabel(string_view label, uInt16 value,
                               bool changed = false);
    static string boolWithLabel(string_view label, bool value,
                                bool changed = false);

  private:
    TiaState myState;
    TiaState myOldState;

    TIA& myTIA;

    static const std::array<string, 8> nusizStrings;

  private:
    // Following constructors and assignment operators not supported
    TIADebug() = delete;
    TIADebug(const TIADebug&) = delete;
    TIADebug(TIADebug&&) = delete;
    TIADebug& operator=(const TIADebug&) = delete;
    TIADebug& operator=(TIADebug&&) = delete;
};

#endif
