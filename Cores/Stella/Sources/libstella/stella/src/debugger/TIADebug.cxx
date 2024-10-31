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

#include "Base.hxx"
#include "System.hxx"
#include "Debugger.hxx"
#include "TIA.hxx"
#include "DelayQueueIterator.hxx"
#include "RiotDebug.hxx"

#include "TIADebug.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TIADebug::TIADebug(Debugger& dbg, Console& console)
  : DebuggerSystem(dbg, console),
    myTIA{console.tia()}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const DebuggerState& TIADebug::getState()
{
  // Color registers
  myState.coluRegs.clear();
  myState.coluRegs.push_back(coluP0());
  myState.coluRegs.push_back(coluP1());
  myState.coluRegs.push_back(coluPF());
  myState.coluRegs.push_back(coluBK());

  // Debug Colors
  const int timing = myConsole.timing() == ConsoleTiming::ntsc ? 0
    : myConsole.timing() == ConsoleTiming::pal ? 1 : 2;

  myState.fixedCols.clear();
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::P0]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::P1]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::PF]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::BK]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::M0]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::M1]);
  myState.fixedCols.push_back(myTIA.myFixedColorPalette[timing][TIA::BL]);
  myState.fixedCols.push_back(TIA::FixedColor::HBLANK_WHITE);

  // Collisions
  myState.cx.clear();
  myState.cx.push_back(collP0_PF());
  myState.cx.push_back(collP0_BL());
  myState.cx.push_back(collM1_P0());
  myState.cx.push_back(collM0_P0());
  myState.cx.push_back(collP0_P1());
  myState.cx.push_back(collP1_PF());
  myState.cx.push_back(collP1_BL());
  myState.cx.push_back(collM1_P1());
  myState.cx.push_back(collM0_P1());
  myState.cx.push_back(collM0_PF());
  myState.cx.push_back(collM0_BL());
  myState.cx.push_back(collM0_M1());
  myState.cx.push_back(collM1_PF());
  myState.cx.push_back(collM1_BL());
  myState.cx.push_back(collBL_PF());

  // Player 0 & 1 and Ball graphics registers
  myState.gr.clear();
  myState.gr.push_back(myTIA.myPlayer0.getGRPNew());
  myState.gr.push_back(myTIA.myPlayer1.getGRPNew());
  myState.gr.push_back(myTIA.myPlayer0.getGRPOld());
  myState.gr.push_back(myTIA.myPlayer1.getGRPOld());
  myState.gr.push_back(myTIA.myBall.getENABLNew());
  myState.gr.push_back(myTIA.myBall.getENABLOld());
  myState.gr.push_back(enaM0());
  myState.gr.push_back(enaM1());

  // Player 0 & 1, Missile 0 & 1 and Ball graphics status registers
  myState.ref.clear();
  myState.ref.push_back(refP0());
  myState.ref.push_back(refP1());
  myState.vdel.clear();
  myState.vdel.push_back(vdelP0());
  myState.vdel.push_back(vdelP1());
  myState.vdel.push_back(vdelBL());
  myState.resm.clear();
  myState.resm.push_back(resMP0());
  myState.resm.push_back(resMP1());

  // Position registers
  myState.pos.clear();
  myState.pos.push_back(posP0());
  myState.pos.push_back(posP1());
  myState.pos.push_back(posM0());
  myState.pos.push_back(posM1());
  myState.pos.push_back(posBL());

  // Horizontal move registers
  myState.hm.clear();
  myState.hm.push_back(hmP0());
  myState.hm.push_back(hmP1());
  myState.hm.push_back(hmM0());
  myState.hm.push_back(hmM1());
  myState.hm.push_back(hmBL());

  // Playfield registers
  myState.pf.clear();
  myState.pf.push_back(pf0());
  myState.pf.push_back(pf1());
  myState.pf.push_back(pf2());
  myState.pf.push_back(refPF());
  myState.pf.push_back(scorePF());
  myState.pf.push_back(priorityPF());

  // Size registers
  myState.size.clear();
  myState.size.push_back(nusizP0());
  myState.size.push_back(nusizP1());
  myState.size.push_back(nusizM0());
  myState.size.push_back(nusizM1());
  myState.size.push_back(sizeBL());

  // VSync/VBlank registers
  myState.vsb.clear();
  myState.vsb.push_back(vsync());
  myState.vsb.push_back(vblank());

  // Audio registers
  myState.aud.clear();
  myState.aud.push_back(audF0());
  myState.aud.push_back(audF1());
  myState.aud.push_back(audC0());
  myState.aud.push_back(audC1());
  myState.aud.push_back(audV0());
  myState.aud.push_back(audV1());

  // internal TIA state
  myState.info.clear();
  myState.info.push_back(frameCount());
  myState.info.push_back(frameCycles());
  myState.info.push_back(cyclesLo());
  myState.info.push_back(cyclesHi());
  myState.info.push_back(scanlines());
  myState.info.push_back(scanlinesLastFrame());
  myState.info.push_back(clocksThisLine());
  myState.info.push_back(frameWsyncCycles());

  return myState;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::saveOldState()
{
  // Color registers
  myOldState.coluRegs.clear();
  myOldState.coluRegs.push_back(coluP0());
  myOldState.coluRegs.push_back(coluP1());
  myOldState.coluRegs.push_back(coluPF());
  myOldState.coluRegs.push_back(coluBK());

  // Collisions
  myOldState.cx.clear();
  myOldState.cx.push_back(collP0_PF());
  myOldState.cx.push_back(collP0_BL());
  myOldState.cx.push_back(collM1_P0());
  myOldState.cx.push_back(collM0_P0());
  myOldState.cx.push_back(collP0_P1());
  myOldState.cx.push_back(collP1_PF());
  myOldState.cx.push_back(collP1_BL());
  myOldState.cx.push_back(collM1_P1());
  myOldState.cx.push_back(collM0_P1());
  myOldState.cx.push_back(collM0_PF());
  myOldState.cx.push_back(collM0_BL());
  myOldState.cx.push_back(collM0_M1());
  myOldState.cx.push_back(collM1_PF());
  myOldState.cx.push_back(collM1_BL());
  myOldState.cx.push_back(collBL_PF());

  // Player 0 & 1 graphics registers
  myOldState.gr.clear();
  myOldState.gr.push_back(myTIA.myPlayer0.getGRPNew());
  myOldState.gr.push_back(myTIA.myPlayer1.getGRPNew());
  myOldState.gr.push_back(myTIA.myPlayer0.getGRPOld());
  myOldState.gr.push_back(myTIA.myPlayer1.getGRPOld());
  myOldState.gr.push_back(myTIA.myBall.getENABLNew());
  myOldState.gr.push_back(myTIA.myBall.getENABLOld());
  myOldState.gr.push_back(enaM0());
  myOldState.gr.push_back(enaM1());

  // Player 0 & 1, Missile 0 & 1 and Ball graphics status registers
  myOldState.ref.clear();
  myOldState.ref.push_back(refP0());
  myOldState.ref.push_back(refP1());
  myOldState.vdel.clear();
  myOldState.vdel.push_back(vdelP0());
  myOldState.vdel.push_back(vdelP1());
  myOldState.vdel.push_back(vdelBL());
  myOldState.resm.clear();
  myOldState.resm.push_back(resMP0());
  myOldState.resm.push_back(resMP1());

  // Position registers
  myOldState.pos.clear();
  myOldState.pos.push_back(posP0());
  myOldState.pos.push_back(posP1());
  myOldState.pos.push_back(posM0());
  myOldState.pos.push_back(posM1());
  myOldState.pos.push_back(posBL());

  // Horizontal move registers
  myOldState.hm.clear();
  myOldState.hm.push_back(hmP0());
  myOldState.hm.push_back(hmP1());
  myOldState.hm.push_back(hmM0());
  myOldState.hm.push_back(hmM1());
  myOldState.hm.push_back(hmBL());

  // Playfield registers
  myOldState.pf.clear();
  myOldState.pf.push_back(pf0());
  myOldState.pf.push_back(pf1());
  myOldState.pf.push_back(pf2());
  myOldState.pf.push_back(refPF());
  myOldState.pf.push_back(scorePF());
  myOldState.pf.push_back(priorityPF());

  // Size registers
  myOldState.size.clear();
  myOldState.size.push_back(nusizP0());
  myOldState.size.push_back(nusizP1());
  myOldState.size.push_back(nusizM0());
  myOldState.size.push_back(nusizM1());
  myOldState.size.push_back(sizeBL());

  // VSync/VBlank registers
  myOldState.vsb.clear();
  myOldState.vsb.push_back(vsync());
  myOldState.vsb.push_back(vblank());

  // Audio registers
  myOldState.aud.clear();
  myOldState.aud.push_back(audF0());
  myOldState.aud.push_back(audF1());
  myOldState.aud.push_back(audC0());
  myOldState.aud.push_back(audC1());
  myOldState.aud.push_back(audV0());
  myOldState.aud.push_back(audV1());

  // internal TIA state
  myOldState.info.clear();
  myOldState.info.push_back(frameCount());
  myOldState.info.push_back(frameCycles());
  myOldState.info.push_back(cyclesLo());
  myOldState.info.push_back(cyclesHi());
  myOldState.info.push_back(scanlines());
  myOldState.info.push_back(scanlinesLastFrame());
  myOldState.info.push_back(clocksThisLine());
  myOldState.info.push_back(frameWsyncCycles());
}

/* the set methods now use mySystem.poke(). This will save us the
   trouble of masking the values here, since TIA::poke() will do it
   for us.

   This means that the GUI should *never* just display the value the
   user entered: it should always read the return value of the set
   method and display that.

   An Example:

   User enters "ff" in the AUDV0 field. GUI calls value = tiaDebug->audV0(0xff).
   The AUDV0 register is only 4 bits wide, so "value" is 0x0f. That's what
   should be displayed.

   In a perfect world, the GUI would only allow one hex digit to be entered...
   but we allow decimal or binary input in the GUI (with # or \ prefix). The
   only way to make that work would be to validate the data entry after every
   keystroke... which would be a pain for both us and the user. Using poke()
   here is a compromise that allows the TIA to do the range-checking for us,
   so the GUI and/or TIADebug don't have to duplicate logic from TIA::poke().
*/

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vdelP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(VDELP0, static_cast<bool>(newVal));

  return myTIA.registerValue(VDELP0) & 0x01;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vdelP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(VDELP1, static_cast<bool>(newVal));

  return myTIA.registerValue(VDELP1) & 0x01;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vdelBL(int newVal)
{
  if(newVal > -1)
    mySystem.poke(VDELBL, static_cast<bool>(newVal));

  return myTIA.registerValue(VDELBL) & 0x01;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::enaM0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(ENAM0, static_cast<bool>(newVal) << 1);

  return myTIA.registerValue(ENAM0) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::enaM1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(ENAM1, static_cast<bool>(newVal) << 1);

  return myTIA.registerValue(ENAM1) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::enaBL(int newVal)
{
  if(newVal > -1)
    mySystem.poke(ENABL, static_cast<bool>(newVal) << 1);

  return myTIA.registerValue(ENABL) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::resMP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(RESMP0, static_cast<bool>(newVal) << 1);

  return myTIA.registerValue(RESMP0) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::resMP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(RESMP1, static_cast<bool>(newVal) << 1);

  return myTIA.registerValue(RESMP1) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::refP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(REFP0, static_cast<bool>(newVal) << 3);

  return myTIA.registerValue(REFP0) & 0x08;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::refP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(REFP1, static_cast<bool>(newVal) << 3);

  return myTIA.registerValue(REFP1) & 0x08;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::refPF(int newVal)
{
  if(newVal > -1)
  {
    int tmp = myTIA.registerValue(CTRLPF);
    if(newVal)
      tmp |= 0x01;
    else
      tmp &= ~0x01;
    mySystem.poke(CTRLPF, tmp);
  }

  return myTIA.registerValue(CTRLPF) & 0x01;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::scorePF(int newVal)
{
  if(newVal > -1)
  {
    int tmp = myTIA.registerValue(CTRLPF);
    if(newVal)
      tmp |= 0x02;
    else
      tmp &= ~0x02;
    mySystem.poke(CTRLPF, tmp);
  }

  return myTIA.registerValue(CTRLPF) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::priorityPF(int newVal)
{
  if(newVal > -1)
  {
    int tmp = myTIA.registerValue(CTRLPF);
    if(newVal)
      tmp |= 0x04;
    else
      tmp &= ~0x04;
    mySystem.poke(CTRLPF, tmp);
  }

  return myTIA.registerValue(CTRLPF) & 0x04;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::collision(CollisionBit id, bool toggle) const
{
  switch(id)
  {
    case CollisionBit::M0P1:
      if(toggle)
        myTIA.toggleCollP1M0();
      return myTIA.collCXM0P()  & 0x80;

    case CollisionBit::M0P0:
      if(toggle)
        myTIA.toggleCollP0M0();
      return myTIA.collCXM0P()  & 0x40;

    case CollisionBit::M1P0:
      if(toggle)
        myTIA.toggleCollP0M1();
      return myTIA.collCXM1P()  & 0x80;

    case CollisionBit::M1P1:
      if(toggle)
        myTIA.toggleCollP1M1();
      return myTIA.collCXM1P()  & 0x40;

    case CollisionBit::P0PF:
      if(toggle)
        myTIA.toggleCollP0PF();
      return myTIA.collCXP0FB() & 0x80;
    case CollisionBit::P0BL:
      if(toggle)
        myTIA.toggleCollP0BL();
      return myTIA.collCXP0FB() & 0x40;

    case CollisionBit::P1PF:
      if(toggle)
        myTIA.toggleCollP1PF();
      return myTIA.collCXP1FB() & 0x80;

    case CollisionBit::P1BL:
      if(toggle)
        myTIA.toggleCollP1BL();
      return myTIA.collCXP1FB() & 0x40;

    case CollisionBit::M0PF:
      if(toggle)
        myTIA.toggleCollM0PF();
      return myTIA.collCXM0FB() & 0x80;

    case CollisionBit::M0BL:
      if(toggle)
        myTIA.toggleCollM0BL();
      return myTIA.collCXM0FB() & 0x40;

    case CollisionBit::M1PF:
      if(toggle)
        myTIA.toggleCollM1PF();
      return myTIA.collCXM1FB() & 0x80;

    case CollisionBit::M1BL:
      if(toggle)
        myTIA.toggleCollM1BL();
      return myTIA.collCXM1FB() & 0x40;

    case CollisionBit::BLPF:
      if(toggle)
        myTIA.toggleCollBLPF();
      return myTIA.collCXBLPF() & 0x80;

    case CollisionBit::P0P1:
      if(toggle)
        myTIA.toggleCollP0P1();
      return myTIA.collCXPPMM() & 0x80;

    case CollisionBit::M0M1:
      if(toggle)
        myTIA.toggleCollM0M1();
      return myTIA.collCXPPMM() & 0x40;
  }
  return false;  // make compiler happy
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audC0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDC0, newVal);

  return myTIA.registerValue(AUDC0) & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audC1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDC1, newVal);

  return myTIA.registerValue(AUDC1) & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audV0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDV0, newVal);

  return myTIA.registerValue(AUDV0) & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audV1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDV1, newVal);

  return myTIA.registerValue(AUDV1) & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audF0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDF0, newVal);

  return myTIA.registerValue(AUDF0) & 0x1f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::audF1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(AUDF1, newVal);

  return myTIA.registerValue(AUDF1) & 0x1f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::pf0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(PF0, newVal << 4);

  return myTIA.registerValue(PF0) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::pf1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(PF1, newVal);

  return myTIA.registerValue(PF1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::pf2(int newVal)
{
  if(newVal > -1)
    mySystem.poke(PF2, newVal);

  return myTIA.registerValue(PF2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::coluP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(COLUP0, newVal);

  return myTIA.registerValue(COLUP0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::coluP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(COLUP1, newVal);

  return myTIA.registerValue(COLUP1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::coluPF(int newVal)
{
  if(newVal > -1)
    mySystem.poke(COLUPF, newVal);

  return myTIA.registerValue(COLUPF);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::coluBK(int newVal)
{
  if(newVal > -1)
    mySystem.poke(COLUBK, newVal);

  return myTIA.registerValue(COLUBK);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusiz0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(NUSIZ0, newVal);

  return myTIA.registerValue(NUSIZ0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusiz1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(NUSIZ1, newVal);

  return myTIA.registerValue(NUSIZ1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusizP0(int newVal)
{
  if(newVal > -1)
  {
    uInt8 tmp = myTIA.registerValue(NUSIZ0) & ~0x07;
    tmp |= (newVal & 0x07);
    mySystem.poke(NUSIZ0, tmp);
  }

  return myTIA.registerValue(NUSIZ0) & 0x07;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusizP1(int newVal)
{
  if(newVal > -1)
  {
    uInt8 tmp = myTIA.registerValue(NUSIZ1) & ~0x07;
    tmp |= newVal & 0x07;
    mySystem.poke(NUSIZ1, tmp);
  }

  return myTIA.registerValue(NUSIZ1) & 0x07;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusizM0(int newVal)
{
  if(newVal > -1)
  {
    uInt8 tmp = myTIA.registerValue(NUSIZ0) & ~0x30;
    tmp |= (newVal & 0x04) << 4;
    mySystem.poke(NUSIZ0, tmp);
  }

  return (myTIA.registerValue(NUSIZ0) & 0x30) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::nusizM1(int newVal)
{
  if(newVal > -1)
  {
    uInt8 tmp = myTIA.registerValue(NUSIZ1) & ~0x30;
    tmp |= (newVal & 0x04) << 4;
    mySystem.poke(NUSIZ1, tmp);
  }

  return (myTIA.registerValue(NUSIZ1) & 0x30) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::grP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(GRP0, newVal);

  return myTIA.registerValue(GRP0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::grP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(GRP1, newVal);

  return myTIA.registerValue(GRP1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::posP0(int newVal)
{
  if(newVal > -1)
    myTIA.myPlayer0.setPosition(newVal);

  return myTIA.myPlayer0.getPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::posP1(int newVal)
{
  if(newVal > -1)
    myTIA.myPlayer1.setPosition(newVal);

  return myTIA.myPlayer1.getPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::posM0(int newVal)
{
  if(newVal > -1)
    myTIA.myMissile0.setPosition(newVal);

  return myTIA.myMissile0.getPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::posM1(int newVal)
{
  if(newVal > -1)
    myTIA.myMissile1.setPosition(newVal);

  return myTIA.myMissile1.getPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::posBL(int newVal)
{
  if(newVal > -1)
    myTIA.myBall.setPosition(newVal);

  return myTIA.myBall.getPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::ctrlPF(int newVal)
{
  if(newVal > -1)
    mySystem.poke(CTRLPF, newVal);

  return myTIA.registerValue(CTRLPF);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::sizeBL(int newVal)
{
  if(newVal > -1)
  {
    uInt8 tmp = myTIA.registerValue(CTRLPF) & ~0x30;
    tmp |= (newVal & 0x04) << 4;
    mySystem.poke(CTRLPF, tmp);
  }

  return (myTIA.registerValue(CTRLPF) & 0x30) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::hmP0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(HMP0, newVal << 4);

  return myTIA.registerValue(HMP0) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::hmP1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(HMP1, newVal << 4);

  return myTIA.registerValue(HMP1) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::hmM0(int newVal)
{
  if(newVal > -1)
    mySystem.poke(HMM0, newVal << 4);

  return myTIA.registerValue(HMM0) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::hmM1(int newVal)
{
  if(newVal > -1)
    mySystem.poke(HMM1, newVal << 4);

  return myTIA.registerValue(HMM1) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 TIADebug::hmBL(int newVal)
{
  if(newVal > -1)
    mySystem.poke(HMBL, newVal << 4);

  return myTIA.registerValue(HMBL) >> 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::setGRP0Old(uInt8 b)
{
  myTIA.myPlayer0.setGRPOld(b);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::setGRP1Old(uInt8 b)
{
  myTIA.myPlayer1.setGRPOld(b);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::setENABLOld(bool b)
{
  myTIA.myBall.setENABLOld(b);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeWsync()
{
  mySystem.poke(WSYNC, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeRsync()
{
  mySystem.poke(RSYNC, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeResP0()
{
  mySystem.poke(RESP0, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeResP1()
{
  mySystem.poke(RESP1, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeResM0()
{
  mySystem.poke(RESM0, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeResM1()
{
  mySystem.poke(RESM1, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeResBL()
{
  mySystem.poke(RESBL, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeHmove()
{
  mySystem.poke(HMOVE, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeHmclr()
{
  mySystem.poke(HMCLR, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TIADebug::strobeCxclr()
{
  mySystem.poke(CXCLR, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::frameCount() const
{
  return myTIA.frameCount();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::frameCycles() const
{
  return myTIA.frameCycles();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::frameWsyncCycles() const
{
  return myTIA.frameWSyncCycles();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::cyclesLo() const
{
  return static_cast<int>(myTIA.cycles());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::cyclesHi() const
{
  return static_cast<int>(myTIA.cycles() >> 32);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::scanlines() const
{
  return myTIA.scanlines();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::scanlinesLastFrame() const
{
  return myTIA.scanlinesLastFrame();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::clocksThisLine() const
{
  return myTIA.clocksThisLine();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TIADebug::cyclesThisLine() const
{
  return myTIA.clocksThisLine()/3;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vsync(int newVal)
{
  if (newVal > -1)
    mySystem.poke(VSYNC, newVal);

  return myTIA.registerValue(VSYNC) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vsync() const
{
  return myTIA.registerValue(VSYNC) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vblank(int newVal)
{
  if (newVal > -1)
    mySystem.poke(VBLANK, newVal);

  return myTIA.registerValue(VBLANK) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TIADebug::vblank() const
{
  return myTIA.registerValue(VBLANK) & 0x02;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<DelayQueueIterator> TIADebug::delayQueueIterator() const
{
  return myTIA.delayQueueIterator();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::colorSwatch(uInt8 c)
{
  string ret;

  ret += static_cast<char>((c >> 1) | 0x80);
  ret += "\177     ";
  ret += "\177\001 ";

  return ret;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::audFreq0()
{
  return audFreq(audC0(), audF0());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::audFreq1()
{
  return audFreq(audC1(), audF1());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::audFreq(uInt8 dist, uInt8 div) const
{
  static constexpr uInt16 dist_div[16] = {
      1, 15, 465, 465, 2, 2, 31, 31,
    511, 31,  31,   1, 6, 6, 93, 93
  };
  const double hz =
    (myConsole.timing() == ConsoleTiming::ntsc ? 31440.0 : 31200.0)
    / dist_div[dist] / (div + 1);
  ostringstream buf;

  buf.setf(std::ios_base::fixed, std::ios_base::floatfield);
  buf << std::setw(7) << std::setprecision(1) << hz << "Hz";

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::stringOnly(string_view value, bool changed)
{
  ostringstream buf;

  buf << value;

  if(changed)
    return static_cast<char>(kDbgColorRed & 0xff) + buf.str() +
           static_cast<char>(kTextColor & 0xff);
  else
    return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::decWithLabel(string_view label, uInt16 value,
                              bool changed, uInt16 width)
{
  ostringstream buf;

  buf << label;
  if(label != EmptyString)
    buf << "=";
  buf << "#" << std::setw(width) << std::dec << std::left << value;

  if(changed)
    return static_cast<char>(kDbgColorRed & 0xff) + buf.str() +
           static_cast<char>(kTextColor & 0xff);
  else
    return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::hexWithLabel(string_view label, uInt16 value,
                              bool changed, uInt16 width)
{
  ostringstream buf;

  buf << label;
  if(label != EmptyString)
    buf << "=";
  buf << "$" << (width == 1 ? Common::Base::HEX1 : Common::Base::HEX2) << value;

  if(changed)
    return static_cast<char>(kDbgColorRed & 0xff) + buf.str() +
           static_cast<char>(kTextColor & 0xff);
  else
    return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::binWithLabel(string_view label, uInt16 value, bool changed)
{
  ostringstream buf;

  buf << label;
  if(label != EmptyString)
    buf << "=";
  buf << "%" << Common::Base::toString(value, Common::Base::Fmt::_2_8);

  if(changed)
    return static_cast<char>(kDbgColorRed & 0xff) + buf.str() +
           static_cast<char>(kTextColor & 0xff);
  else
    return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::boolWithLabel(string_view label, bool value, bool changed)
{
  ostringstream buf;

  if(value)
  {
    string l{label};
    buf << "\177" << BSPF::toUpperCase(l) << "\177";
    //return "+" + BSPF::toUpperCase(label);
  }
  else
    buf << label;
    //return "-" + BSPF::toLowerCase(label);

  if(changed)
    return static_cast<char>(kDbgColorRed & 0xff) + buf.str() +
           static_cast<char>(kTextColor & 0xff);
  else
    return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::debugColors() const
{
  ostringstream buf;

  const int timing = myConsole.timing() == ConsoleTiming::ntsc ? 0
    : myConsole.timing() == ConsoleTiming::pal ? 1 : 2;

  buf << " " << myTIA.myFixedColorNames[TIA::P0] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::P0])
      << " Player 0\n"
      << " " << myTIA.myFixedColorNames[TIA::M0] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::M0])
      << " Missile 0\n"
      << " " << myTIA.myFixedColorNames[TIA::P1] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::P1])
      << " Player 1\n"
      << " " << myTIA.myFixedColorNames[TIA::M1] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::M1])
      << " Missile 1\n"
      << " " << myTIA.myFixedColorNames[TIA::PF] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::PF])
      << " Playfield\n"
      << " " << myTIA.myFixedColorNames[TIA::BL] << " " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::BL])
      << " Ball\n"
      << " Grey   " << colorSwatch(myTIA.myFixedColorPalette[timing][TIA::BK])
      << " Background\n"
      << " White  " << colorSwatch(TIA::FixedColor::HBLANK_WHITE)
      << " HMOVE\n";

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::palette()
{
  ostringstream buf;

  buf << "     0     2     4     6     8     A     C     E\n";
  uInt8 c = 0;
  for(uInt16 row = 0; row < 16; ++row)
  {
    buf << " " << Common::Base::HEX1 << row << " ";
    for(uInt16 col = 0; col < 8; ++col, c += 2)
      buf << colorSwatch(c);

    buf << '\n';
  }
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TIADebug::toString()
{
  ostringstream buf;

  // TODO: strobes? WSYNC RSYNC RESP0/1 RESM0/1 RESBL HMOVE HMCLR CXCLR

  RiotDebug& riot = myDebugger.riotDebug();
  const auto& riotState = static_cast<const RiotState&>(riot.getState());
  const auto& oldRiotState = static_cast<const RiotState&>(riot.getOldState());

  const auto& state = static_cast<const TiaState&>(getState());
  const auto& oldState = static_cast<const TiaState&>(getOldState());

  // build up output, then return it.
  buf << std::setfill(' ') << std::left
      << decWithLabel("scanline", myTIA.scanlines(),
                      static_cast<int>(myTIA.scanlines()) != oldState.info[4]) << " "
      << boolWithLabel("vsync",  vsync(),
                       state.vsb[0] != oldState.vsb[0]) << " "
      << boolWithLabel("vblank", vblank(),
                       state.vsb[1] != oldState.vsb[1])
      << '\n'
      << "Collisions: "
      << boolWithLabel("p0_pf", collP0_PF(), state.cx[0] != oldState.cx[0]) << " "
      << boolWithLabel("p0_bl", collP0_BL(), state.cx[1] != oldState.cx[1]) << " "
      << boolWithLabel("m1_p0", collM1_P0(), state.cx[2] != oldState.cx[2]) << " "
      << boolWithLabel("m0_p0", collM0_P0(), state.cx[3] != oldState.cx[3]) << " "
      << boolWithLabel("p0_p1", collP0_P1(), state.cx[4] != oldState.cx[4]) << " "
      << boolWithLabel("p1_pf", collP1_PF(), state.cx[5] != oldState.cx[5]) << " "
      << boolWithLabel("p1_bl", collP1_BL(), state.cx[6] != oldState.cx[6]) << " "
      << boolWithLabel("m1_p1", collM1_P1(), state.cx[7] != oldState.cx[7])
      << '\n' << "            "
      << boolWithLabel("m0_p1", collM0_P1(), state.cx[8] != oldState.cx[8]) << " "
      << boolWithLabel("m0_pf", collM0_PF(), state.cx[9] != oldState.cx[9]) << " "
      << boolWithLabel("m0_bl", collM0_BL(), state.cx[10] != oldState.cx[10]) << " "
      << boolWithLabel("m0_m1", collM0_M1(), state.cx[11] != oldState.cx[11]) << " "
      << boolWithLabel("m1_pf", collM1_PF(), state.cx[12] != oldState.cx[12]) << " "
      << boolWithLabel("m1_bl", collM1_BL(), state.cx[13] != oldState.cx[13]) << " "
      << boolWithLabel("bl_pf", collBL_PF(), state.cx[14] != oldState.cx[14])
      << '\n'
      << "COLUxx: "
      << hexWithLabel("P0", state.coluRegs[TiaState::P0],
                      state.coluRegs[TiaState::P0] != oldState.coluRegs[TiaState::P0]) << "/"
      << colorSwatch(state.coluRegs[TiaState::P0])
      << hexWithLabel("P1", state.coluRegs[TiaState::P1],
                      state.coluRegs[TiaState::P1] != oldState.coluRegs[TiaState::P1]) << "/"
      << colorSwatch(state.coluRegs[TiaState::P1])
      << hexWithLabel("PF", state.coluRegs[2],
                      state.coluRegs[2] != oldState.coluRegs[2]) << "/"
      << colorSwatch(state.coluRegs[2])
      << hexWithLabel("BK", state.coluRegs[3],
                      state.coluRegs[3] != oldState.coluRegs[3]) << "/"
      << colorSwatch(state.coluRegs[3])
      << '\n'
      << "P0: "
      << binWithLabel("GR", state.gr[TiaState::P0],
                      state.gr[TiaState::P0] != oldState.gr[TiaState::P0]) << " "
      << decWithLabel("pos", state.pos[TiaState::P0],
                      state.pos[TiaState::P0] != oldState.pos[TiaState::P0]) << " "
      << hexWithLabel("HM", state.hm[TiaState::P0],
                      state.hm[TiaState::P0] != oldState.hm[TiaState::P0], 1) << " "
      << stringOnly(nusizP0String(),
                    state.size[TiaState::P0] != oldState.size[TiaState::P0]) << " "
      << boolWithLabel("refl",  refP0(),
                       state.ref[TiaState::P0]  != oldState.ref[TiaState::P0]) << " "
      << boolWithLabel("delay", vdelP0(),
                       state.vdel[TiaState::P0] != oldState.vdel[TiaState::P0])
      << '\n'
      << "P1: "
      << binWithLabel("GR", state.gr[TiaState::P1],
                     state.gr[TiaState::P1] != oldState.gr[TiaState::P1]) << " "
      << decWithLabel("pos", state.pos[TiaState::P1],
                      state.pos[TiaState::P1] != oldState.pos[TiaState::P1]) << " "
      << hexWithLabel("HM", state.hm[TiaState::P1],
                      state.hm[TiaState::P1] != oldState.hm[TiaState::P1], 1) << " "
      << stringOnly(nusizP1String(),
                    state.size[TiaState::P1] != oldState.size[TiaState::P1]) << " "
      << boolWithLabel("refl", refP1(),
                       state.ref[TiaState::P1] != oldState.ref[TiaState::P1]) << " "
      << boolWithLabel("delay", vdelP1(),
                       state.vdel[TiaState::P1] != oldState.vdel[TiaState::P1])
      << '\n'
      << "M0: "
      << stringOnly(enaM0() ? "ENABLED " : "disabled",
                    state.gr[6] != oldState.gr[6]) << " "
      << decWithLabel("pos", state.pos[TiaState::M0],
                      state.pos[TiaState::M0] != oldState.pos[TiaState::M0]) << " "
      << hexWithLabel("HM", state.hm[TiaState::M0],
                      state.hm[TiaState::M0] != oldState.hm[TiaState::M0], 1) << " "
      << decWithLabel("size", state.size[TiaState::M0],
                      state.size[TiaState::M0] != oldState.size[TiaState::M0], 1) << " "
      << boolWithLabel("reset", resMP0(), state.resm[TiaState::P0] != oldState.resm[TiaState::P0])
      << '\n'
      << "M1: "
      << stringOnly(enaM1() ? "ENABLED " : "disabled",
                    state.gr[7] != oldState.gr[7]) << " "
      << decWithLabel("pos", state.pos[TiaState::M1],
                      state.pos[TiaState::M1] != oldState.pos[TiaState::M1]) << " "
      << hexWithLabel("HM", state.hm[TiaState::M1],
                      state.hm[TiaState::M1] != oldState.hm[TiaState::M1], 1) << " "
      << decWithLabel("size", state.size[TiaState::M1],
                      state.size[TiaState::M1] != oldState.size[TiaState::M1], 1) << " "
      << boolWithLabel("reset", resMP0(), state.resm[TiaState::P1] != oldState.resm[TiaState::P1])
      << '\n'
      << "BL: "
      << stringOnly(enaBL() ? "ENABLED " : "disabled",
                    state.gr[4] != oldState.gr[4]) << " "
      << decWithLabel("pos", state.pos[TiaState::BL],
                      state.pos[TiaState::BL] != oldState.pos[TiaState::BL]) << " "
      << hexWithLabel("HM", state.hm[TiaState::BL],
                      state.hm[TiaState::BL] != oldState.hm[TiaState::BL], 1) << " "
      << decWithLabel("size", state.size[TiaState::BL],
                      state.size[TiaState::BL] != oldState.size[TiaState::BL], 1) << " "
      << boolWithLabel("delay", vdelBL(), state.vdel[2] != oldState.vdel[2])
      << '\n'
      << "PF0: "
      << binWithLabel("", state.pf[0],
                      state.pf[0] != oldState.pf[0]) << "/"
      << hexWithLabel("", state.pf[0],
                      state.pf[0] != oldState.pf[0]) << " "
      << "PF1: "
      << binWithLabel("", state.pf[1],
                      state.pf[1] != oldState.pf[1]) << "/"
      << hexWithLabel("", state.pf[1],
                      state.pf[1] != oldState.pf[1]) << " "
      << "PF2: "
      << binWithLabel("", state.pf[2],
                      state.pf[2] != oldState.pf[2]) << "/"
      << hexWithLabel("", state.pf[2],
                      state.pf[2] != oldState.pf[2]) << " "
      << '\n' << "     "
      << boolWithLabel("reflect",  refPF(),      state.pf[3] != oldState.pf[3]) << " "
      << boolWithLabel("score",    scorePF(),    state.pf[4] != oldState.pf[4]) << " "
      << boolWithLabel("priority", priorityPF(), state.pf[5] != oldState.pf[5])
      << '\n'
      << boolWithLabel("inpt0", myTIA.peek(0x08) & 0x80,
                        (riotState.INPT0 & 0x80) != (oldRiotState.INPT0 & 0x80)) << " "
      << boolWithLabel("inpt1", myTIA.peek(0x09) & 0x80,
                        (riotState.INPT1 & 0x80) != (oldRiotState.INPT1 & 0x80)) << " "
      << boolWithLabel("inpt2", myTIA.peek(0x0a) & 0x80,
                        (riotState.INPT2 & 0x80) != (oldRiotState.INPT2 & 0x80)) << " "
      << boolWithLabel("inpt3", myTIA.peek(0x0b) & 0x80,
                        (riotState.INPT3 & 0x80) != (oldRiotState.INPT3 & 0x80)) << " "
      << boolWithLabel("inpt4", myTIA.peek(0x0c) & 0x80,
                        (riotState.INPT4 & 0x80) != (oldRiotState.INPT4 & 0x80)) << " "
      << boolWithLabel("inpt5", myTIA.peek(0x0d) & 0x80,
                        (riotState.INPT5 & 0x80) != (oldRiotState.INPT5 & 0x80)) << " "
      << boolWithLabel("dump_gnd_0123", myTIA.myAnalogReadouts[0].vblankDumped(),
                        riotState.INPTDump != oldRiotState.INPTDump)
      << '\n'
      << "AUDF0: "
      << hexWithLabel("", static_cast<int>(audF0()),
                      state.aud[0] != oldState.aud[0]) << "/"
      << std::setw(9) << std::right << stringOnly(audFreq0(),
                    state.aud[0] != oldState.aud[0]) << " "
      << "AUDC0: "
      << hexWithLabel("", static_cast<int>(audC0()),
                      state.aud[2] != oldState.aud[2], 1) << " "
      << "AUDV0: "
      << hexWithLabel("", static_cast<int>(audV0()),
                      state.aud[4] != oldState.aud[4], 1)
      << '\n'
      << "AUDF1: "
      << hexWithLabel("", static_cast<int>(audF1()),
                      state.aud[1] != oldState.aud[1]) << "/"
      << std::setw(9) << std::right << stringOnly(audFreq1(),
                    state.aud[1] != oldState.aud[1]) << " "
      << "AUDC1: "
      << hexWithLabel("", static_cast<int>(audC1()),
                      state.aud[3] != oldState.aud[3], 1) << " "
      << "AUDV1: "
      << hexWithLabel("", static_cast<int>(audV1()),
                      state.aud[5] != oldState.aud[5], 1);
  // note: last line should not contain \n, caller will add.
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<string, 8> TIADebug::nusizStrings = {
  "1 copy              ",
  "2 copies - close (8)",
  "2 copies - med (24) ",
  "3 copies - close (8)",
  "2 copies - wide (56)",
  "2x (16) sized player",
  "3 copies - med (24) ",
  "4x (32) sized player"
};
