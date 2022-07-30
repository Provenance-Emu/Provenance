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

#include "ColorWidget.hxx"
#include "DataGridWidget.hxx"
#include "EditTextWidget.hxx"
#include "FrameBuffer.hxx"
#include "Font.hxx"
#include "GuiObject.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "TIA.hxx"
#include "TIADebug.hxx"
#include "ToggleBitWidget.hxx"
#include "TogglePixelWidget.hxx"
#include "Widget.hxx"
#include "DelayQueueWidget.hxx"
#include "TiaWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TiaWidget::TiaWidget(GuiObject* boss, const GUI::Font& lfont,
                     const GUI::Font& nfont,
                     int x, int y, int w, int h)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss)
{
  const int fontWidth  = lfont.getMaxCharWidth(),
            fontHeight = lfont.getFontHeight(),
            lineHeight = lfont.getLineHeight(),
            buttonW = 7 * fontWidth;
  int xpos = 10, ypos = 10, buttonX = 0, buttonY = 0;
  StaticTextWidget* t = nullptr;
  ButtonWidget* b = nullptr;


  ////////////////////////////
  // VSync/VBlank
  ////////////////////////////
  buttonX = xpos;  buttonY = ypos;
  myVSync = new CheckboxWidget(boss, lfont, buttonX, buttonY, "VSync", kVSyncCmd);
  myVSync->setTarget(this);
  addFocusWidget(myVSync);

  buttonX += myVSync->getRight() + 15;
  myVBlank = new CheckboxWidget(boss, lfont, buttonX, buttonY, "VBlank", kVBlankCmd);
  myVBlank->setTarget(this);
  addFocusWidget(myVBlank);

  ypos += lineHeight * 2 + 6;

  // Color registers
  static constexpr std::array<const char*, 4> regNames = {
    "COLUP0", "COLUP1", "COLUPF", "COLUBK"
  };
  for(int row = 0; row < 4; ++row)
  {
    new StaticTextWidget(boss, lfont, xpos, ypos + row*lineHeight + 2,
                         6*fontWidth, fontHeight, regNames[row], TextAlign::Left);
  }
  xpos += 6*fontWidth + 8;
  myColorRegs = new DataGridWidget(boss, nfont, xpos, ypos,
                                   1, 4, 2, 8, Common::Base::Fmt::_16);
  myColorRegs->setTarget(this);
  myColorRegs->setID(kColorRegsID);
  addFocusWidget(myColorRegs);

  xpos += myColorRegs->colWidth() + 5;
  myCOLUP0Color = new ColorWidget(boss, nfont, xpos, ypos+2,
    static_cast<uInt32>(1.5*lineHeight), lineHeight - 4);
  myCOLUP0Color->setTarget(this);

  ypos += lineHeight;
  myCOLUP1Color = new ColorWidget(boss, nfont, xpos, ypos+2,
    static_cast<uInt32>(1.5*lineHeight), lineHeight - 4);
  myCOLUP1Color->setTarget(this);

  ypos += lineHeight;
  myCOLUPFColor = new ColorWidget(boss, nfont, xpos, ypos+2,
    static_cast<uInt32>(1.5*lineHeight), lineHeight - 4);
  myCOLUPFColor->setTarget(this);

  ypos += lineHeight;
  myCOLUBKColor = new ColorWidget(boss, nfont, xpos, ypos+2,
    static_cast<uInt32>(1.5*lineHeight), lineHeight - 4);
  myCOLUBKColor->setTarget(this);

  // Fixed debug colors
  xpos += myCOLUP0Color->getWidth() + 30;  ypos = 10 + lineHeight + 6;
  myFixedEnabled = new CheckboxWidget(boss, lfont, xpos, ypos, "Debug Colors", kDbgClCmd);
  myFixedEnabled->setToolTip("Enable fixed debug colors", Event::ToggleFixedColors);
  myFixedEnabled->setTarget(this);
  addFocusWidget(myFixedEnabled);

  static constexpr std::array<const char*, 8> dbgLabels = {
    "P0", "P1", "PF", "BK", "M0", "M1", "BL", "HM"
  };
  for(uInt32 row = 0; row <= 3; ++row)
  {
    ypos += lineHeight;
    t = new StaticTextWidget(boss, lfont, xpos, ypos + 2, 2*fontWidth, fontHeight,
                             dbgLabels[row], TextAlign::Left);
    myFixedColors[row] = new ColorWidget(boss, nfont, xpos + 2 + t->getWidth() + 4,
                               ypos + 2, uInt32(1.5*lineHeight), lineHeight - 4);
    myFixedColors[row]->setTarget(this);
  }
  xpos += t->getWidth() + myFixedColors[0]->getWidth() + 24;
  ypos = 10 + lineHeight + 6;
  for(uInt32 row = 4; row <= 7; ++row)
  {
    ypos += lineHeight;
    t = new StaticTextWidget(boss, lfont, xpos, ypos + 2, 2*fontWidth, fontHeight,
                             dbgLabels[row], TextAlign::Left);
    myFixedColors[row] = new ColorWidget(boss, nfont, xpos + 2 + t->getWidth() + 4,
                               ypos + 2, uInt32(1.5*lineHeight), lineHeight - 4);
    myFixedColors[row]->setTarget(this);
  }

  ////////////////////////////
  // Collision register bits
  ////////////////////////////
  xpos += myFixedColors[0]->getWidth() + 2*fontWidth + 60;  ypos = 10;

  // Add all 15 collision bits (with labels)
  uInt32 cxclrY = 0;
  xpos -= 2*fontWidth + 5;  ypos += lineHeight;
  static constexpr std::array<const char*, 5> rowLabel = { "P0", "P1", "M0", "M1", "BL" };
  static constexpr std::array<const char*, 5> colLabel = { "PF", "BL", "M1", "M0", "P1" };
  const uInt32 lwidth = 2 * fontWidth;
  int collX = xpos + lwidth + 5, collY = ypos, idx = 0;
  for(uInt32 row = 0; row < 5; ++row)
  {
    // Add vertical label
    new StaticTextWidget(boss, lfont, xpos, ypos + row*(lineHeight+3),
                         2*fontWidth, fontHeight,
                         rowLabel[row], TextAlign::Left);

    for(uInt32 col = 0; col < 5 - row; ++col, ++idx)
    {
      myCollision[idx] = new CheckboxWidget(boss, lfont, collX, collY, "", CheckboxWidget::kCheckActionCmd);
      myCollision[idx]->setTarget(this);
      myCollision[idx]->setID(idx);

      // We need to know where the PF_BL register is, to properly position
      // the CXCLR button
      if(idx == kBL_PFID)
        cxclrY = collY;

      // Add horizontal label
      uInt32 labelx = collX;
      if(lwidth > static_cast<uInt32>(myCollision[idx]->getWidth()))
        labelx -= (lwidth - myCollision[idx]->getWidth()) / 2;
      else
        labelx += (myCollision[idx]->getWidth() - lwidth) / 2;

      new StaticTextWidget(boss, lfont, labelx, ypos-lineHeight, lwidth, fontHeight,
                           colLabel[col], TextAlign::Left);

      collX += myCollision[idx]->getWidth() + 10;
    }
    collX = xpos + lwidth + 5;
    collY += lineHeight+3;
  }

  // Clear all collision bits
  buttonX = collX + 5*(myCollision[0]->getWidth() + 10) - buttonW - 10;
  buttonY = lineHeight == 15 ? cxclrY : cxclrY - 4;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, lineHeight,
                       "CXCLR", kCxclrCmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // P0 register info
  ////////////////////////////
  // grP0 (new)
  xpos = 10;  ypos = collY + 4;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "P0", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myGRP0 = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myGRP0->setTarget(this);
  myGRP0->setID(kGRP0ID);
  myGRP0->clearBackgroundColor();
  addFocusWidget(myGRP0);

  // posP0
  xpos += myGRP0->getWidth() + 12;
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                           "Pos#", TextAlign::Left);
  xpos += t->getWidth() + 2;
  myPosP0 = new DataGridWidget(boss, nfont, xpos, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosP0->setTarget(this);
  myPosP0->setID(kPosP0ID);
  myPosP0->setRange(0, 160);
  addFocusWidget(myPosP0);

  // hmP0
  xpos += myPosP0->getWidth() + fontWidth + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "HM", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myHMP0 = new DataGridWidget(boss, nfont, xpos, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMP0->setTarget(this);
  myHMP0->setID(kHMP0ID);
  addFocusWidget(myHMP0);

  // P0 reflect
  xpos += myHMP0->getWidth() + 15;
  myRefP0 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefP0->setTarget(this);
  myRefP0->setID(kRefP0ID);
  addFocusWidget(myRefP0);

  // P0 reset
  xpos += myRefP0->getWidth() + 12;
  buttonX = xpos;
  b = new ButtonWidget(boss, lfont, xpos, ypos, buttonW, lineHeight,
                       "RESP0", kResP0Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  // grP0 (old)
  xpos = 10 + 2*fontWidth + 5;  ypos += myGRP0->getHeight() + 5;
  myGRP0Old = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myGRP0Old->setTarget(this);
  myGRP0Old->setID(kGRP0OldID);
  myGRP0Old->clearBackgroundColor();
  addFocusWidget(myGRP0Old);

  // P0 delay
  xpos += myGRP0Old->getWidth() + 12;
  myDelP0 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "VDel", CheckboxWidget::kCheckActionCmd);
  myDelP0->setTarget(this);
  myDelP0->setID(kDelP0ID);
  addFocusWidget(myDelP0);

  // NUSIZ0 (player portion)
  xpos += myDelP0->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 5*fontWidth, fontHeight,
                       "NuSiz", TextAlign::Left);
  xpos += 5*fontWidth + 5;
  myNusizP0 = new DataGridWidget(boss, nfont, xpos, ypos,
                                 1, 1, 1, 3, Common::Base::Fmt::_16_1);
  myNusizP0->setTarget(this);
  myNusizP0->setID(kNusizP0ID);
  addFocusWidget(myNusizP0);

  xpos += myNusizP0->getWidth() + 5;
  myNusizP0Text = new EditTextWidget(boss, nfont, xpos, ypos, 21*fontWidth,
                                     lineHeight, "");
  myNusizP0Text->setEditable(false, true);

  ////////////////////////////
  // P1 register info
  ////////////////////////////
  // grP1 (new)
  xpos = 10;  ypos += lineHeight + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "P1", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myGRP1 = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myGRP1->setTarget(this);
  myGRP1->setID(kGRP1ID);
  myGRP1->clearBackgroundColor();
  addFocusWidget(myGRP1);

  // posP1
  xpos += myGRP1->getWidth() + 12;
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                           "Pos#", TextAlign::Left);
  xpos += t->getWidth() + 2;
  myPosP1 = new DataGridWidget(boss, nfont, xpos, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosP1->setTarget(this);
  myPosP1->setID(kPosP1ID);
  myPosP1->setRange(0, 160);
  addFocusWidget(myPosP1);

  // hmP1
  xpos += myPosP1->getWidth() + fontWidth + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "HM", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myHMP1 = new DataGridWidget(boss, nfont, xpos, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMP1->setTarget(this);
  myHMP1->setID(kHMP1ID);
  addFocusWidget(myHMP1);

  // P1 reflect
  xpos += myHMP1->getWidth() + 15;
  myRefP1 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefP1->setTarget(this);
  myRefP1->setID(kRefP1ID);
  addFocusWidget(myRefP1);

  // P1 reset
  xpos += myRefP1->getWidth() + 12;
  b = new ButtonWidget(boss, lfont, xpos, ypos, buttonW, lineHeight,
                       "RESP1", kResP1Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  // grP1 (old)
  xpos = 10 + 2*fontWidth + 5;  ypos += myGRP1->getHeight() + 5;
  myGRP1Old = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myGRP1Old->setTarget(this);
  myGRP1Old->setID(kGRP1OldID);
  myGRP1Old->clearBackgroundColor();
  addFocusWidget(myGRP1Old);

  // P1 delay
  xpos += myGRP1Old->getWidth() + 12;
  myDelP1 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "VDel", CheckboxWidget::kCheckActionCmd);
  myDelP1->setTarget(this);
  myDelP1->setID(kDelP1ID);
  addFocusWidget(myDelP1);

  // NUSIZ1 (player portion)
  xpos += myDelP1->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 5*fontWidth, fontHeight,
                       "NuSiz", TextAlign::Left);
  xpos += 5*fontWidth + 5;
  myNusizP1 = new DataGridWidget(boss, nfont, xpos, ypos,
                                 1, 1, 1, 3, Common::Base::Fmt::_16_1);
  myNusizP1->setTarget(this);
  myNusizP1->setID(kNusizP1ID);
  addFocusWidget(myNusizP1);

  xpos += myNusizP1->getWidth() + 5;
  myNusizP1Text = new EditTextWidget(boss, nfont, xpos, ypos, 21*fontWidth,
                                     lineHeight, "");
  myNusizP1Text->setEditable(false, true);

  ////////////////////////////
  // M0 register info
  ////////////////////////////
  // enaM0
  xpos = 10;  ypos += lineHeight + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "M0", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myEnaM0 = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 1, 1);
  myEnaM0->setTarget(this);
  myEnaM0->setID(kEnaM0ID);
  myEnaM0->clearBackgroundColor();
  addFocusWidget(myEnaM0);

  // posM0
  xpos += myEnaM0->getWidth() + 12;
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                           "Pos#", TextAlign::Left);
  xpos += t->getWidth() + 2;
  myPosM0 = new DataGridWidget(boss, nfont, xpos, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosM0->setTarget(this);
  myPosM0->setID(kPosM0ID);
  myPosM0->setRange(0, 160);
  addFocusWidget(myPosM0);

  // hmM0
  xpos += myPosM0->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "HM", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myHMM0 = new DataGridWidget(boss, nfont, xpos, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMM0->setTarget(this);
  myHMM0->setID(kHMM0ID);
  addFocusWidget(myHMM0);

  // NUSIZ0 (missile portion)
  xpos += myHMM0->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                       "Size", TextAlign::Left);
  xpos += 4*fontWidth + 5;
  myNusizM0 = new DataGridWidget(boss, nfont, xpos, ypos,
                                 1, 1, 1, 2, Common::Base::Fmt::_16_1);
  myNusizM0->setTarget(this);
  myNusizM0->setID(kNusizM0ID);
  addFocusWidget(myNusizM0);

  // M0 reset to player 0
  xpos += myNusizM0->getWidth() + 15;
  myResMP0 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                                "Reset to P0", CheckboxWidget::kCheckActionCmd);
  myResMP0->setTarget(this);
  myResMP0->setID(kResMP0ID);
  addFocusWidget(myResMP0);

  // M0 reset
  xpos = buttonX;
  b = new ButtonWidget(boss, lfont, xpos, ypos, buttonW, lineHeight,
                       "RESM0", kResM0Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // M1 register info
  ////////////////////////////
  // enaM1
  xpos = 10;  ypos += lineHeight + 4;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "M1", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myEnaM1 = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 1, 1);
  myEnaM1->setTarget(this);
  myEnaM1->setID(kEnaM1ID);
  myEnaM1->clearBackgroundColor();
  addFocusWidget(myEnaM1);

  // posM0
  xpos += myEnaM1->getWidth() + 12;
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                           "Pos#", TextAlign::Left);
  xpos += t->getWidth() + 2;
  myPosM1 = new DataGridWidget(boss, nfont, xpos, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosM1->setTarget(this);
  myPosM1->setID(kPosM1ID);
  myPosM1->setRange(0, 160);
  addFocusWidget(myPosM1);

  // hmM0
  xpos += myPosM1->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "HM", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myHMM1 = new DataGridWidget(boss, nfont, xpos, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMM1->setTarget(this);
  myHMM1->setID(kHMM1ID);
  addFocusWidget(myHMM1);

  // NUSIZ1 (missile portion)
  xpos += myHMM1->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                       "Size", TextAlign::Left);
  xpos += 4*fontWidth + 5;
  myNusizM1 = new DataGridWidget(boss, nfont, xpos, ypos,
                                 1, 1, 1, 2, Common::Base::Fmt::_16_1);
  myNusizM1->setTarget(this);
  myNusizM1->setID(kNusizM1ID);
  addFocusWidget(myNusizM1);

  // M1 reset to player 0
  xpos += myNusizM1->getWidth() + 15;
  myResMP1 = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                                "Reset to P1", CheckboxWidget::kCheckActionCmd);
  myResMP1->setTarget(this);
  myResMP1->setID(kResMP1ID);
  addFocusWidget(myResMP1);

  // M1 reset
  xpos = buttonX;
  b = new ButtonWidget(boss, lfont, xpos, ypos, buttonW, lineHeight,
                       "RESM1", kResM1Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // BL register info
  ////////////////////////////
  // enaBL
  xpos = 10;  ypos += lineHeight + 4;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "BL", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myEnaBL = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 1, 1);
  myEnaBL->setTarget(this);
  myEnaBL->setID(kEnaBLID);
  myEnaBL->clearBackgroundColor();
  addFocusWidget(myEnaBL);

  // posBL
  xpos += myEnaBL->getWidth() + 12;
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                           "Pos#", TextAlign::Left);
  xpos += t->getWidth() + 2;
  myPosBL = new DataGridWidget(boss, nfont, xpos, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosBL->setTarget(this);
  myPosBL->setID(kPosBLID);
  myPosBL->setRange(0, 160);
  addFocusWidget(myPosBL);

  // hmBL
  xpos += myPosBL->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "HM", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myHMBL = new DataGridWidget(boss, nfont, xpos, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMBL->setTarget(this);
  myHMBL->setID(kHMBLID);
  addFocusWidget(myHMBL);

  // CTRLPF (size portion)
  xpos += myHMBL->getWidth() + 12;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 4*fontWidth, fontHeight,
                       "Size", TextAlign::Left);
  xpos += 4*fontWidth + 5;
  mySizeBL = new DataGridWidget(boss, nfont, xpos, ypos,
                                1, 1, 1, 2, Common::Base::Fmt::_16_1);
  mySizeBL->setTarget(this);
  mySizeBL->setID(kSizeBLID);
  addFocusWidget(mySizeBL);

  // Reset ball
  xpos = buttonX;
  b = new ButtonWidget(boss, lfont, xpos, ypos, buttonW, lineHeight,
                       "RESBL", kResBLCmd);
  b->setTarget(this);
  addFocusWidget(b);

  // Ball (old)
  xpos = 10 + 2*fontWidth + 5;  ypos += myEnaBL->getHeight() + 5;
  myEnaBLOld = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 1, 1);
  myEnaBLOld->setTarget(this);
  myEnaBLOld->setID(kEnaBLOldID);
  myEnaBLOld->clearBackgroundColor();
  addFocusWidget(myEnaBLOld);

  // Ball delay
  xpos += myEnaBLOld->getWidth() + 12;
  myDelBL = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "VDel", CheckboxWidget::kCheckActionCmd);
  myDelBL->setTarget(this);
  myDelBL->setID(kDelBLID);
  addFocusWidget(myDelBL);

  ////////////////////////////
  // PF 0/1/2 registers
  ////////////////////////////
  const GUI::Font& sf = instance().frameBuffer().smallFont();
  const int sfWidth = sf.getMaxCharWidth(),
            sfHeight = sf.getFontHeight();
  static constexpr std::array<const char*, 8> bitNames = {
    "0", "1", "2", "3", "4", "5", "6", "7"
  };

  // PF0
  xpos = 10;  ypos += lineHeight + sfHeight + 6;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, 2*fontWidth, fontHeight,
                       "PF", TextAlign::Left);
  xpos += 2*fontWidth + 5;
  myPF[0] = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 4, 1, 4);
  myPF[0]->setTarget(this);
  myPF[0]->setID(kPF0ID);
  addFocusWidget(myPF[0]);

  // PF1
  xpos += myPF[0]->getWidth() + 2;
  myPF[1] = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myPF[1]->setTarget(this);
  myPF[1]->setID(kPF1ID);
  addFocusWidget(myPF[1]);

  // PF2
  xpos += myPF[1]->getWidth() + 2;
  myPF[2] = new TogglePixelWidget(boss, nfont, xpos, ypos+1, 8, 1);
  myPF[2]->setTarget(this);
  myPF[2]->setID(kPF2ID);
  addFocusWidget(myPF[2]);

  // PFx bit labels
  const auto start = [&](int sw) { return (sw - sfWidth) / 2; };
  const int colw = myPF[0]->getWidth() / 4;
  xpos = 10 + 2*fontWidth + 5 + start(colw);
  const int _ypos = ypos - sfHeight;
  for(int i = 4; i <= 7; ++i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, sfWidth, sfHeight,
                         bitNames[i], TextAlign::Left);
    xpos += colw;
  }
  xpos = 10 + 2*fontWidth + 5 + myPF[0]->getWidth() + 2 + start(colw);
  for(int i = 7; i >= 0; --i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, sfWidth, sfHeight,
                         bitNames[i], TextAlign::Left);
    xpos += colw;
  }
  xpos = 10 + 2*fontWidth + 5 + myPF[0]->getWidth() + 2 +
         myPF[1]->getWidth() + 2 + start(colw);
  for(int i = 0; i <= 7; ++i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, sfWidth, sfHeight,
                         bitNames[i], TextAlign::Left);
    xpos += colw;
  }

  // PF reflect, score, priority
  xpos = 10 + 4*fontWidth;  ypos += lineHeight + 6;
  myRefPF = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefPF->setTarget(this);
  myRefPF->setID(kRefPFID);
  addFocusWidget(myRefPF);

  xpos += myRefPF->getWidth() + 15;
  myScorePF = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                                 "Score", CheckboxWidget::kCheckActionCmd);
  myScorePF->setTarget(this);
  myScorePF->setID(kScorePFID);
  addFocusWidget(myScorePF);

  xpos += myScorePF->getWidth() + 15;
  myPriorityPF = new CheckboxWidget(boss, lfont, xpos, ypos+1,
                                    "Priority", CheckboxWidget::kCheckActionCmd);
  myPriorityPF->setTarget(this);
  myPriorityPF->setID(kPriorityPFID);
  addFocusWidget(myPriorityPF);

  xpos = 10;
  ypos += lineHeight + 10;
  t = new StaticTextWidget(boss, lfont, xpos, ypos, 13*fontWidth, fontHeight,
    "Queued Writes", TextAlign::Left);

  xpos += t->getWidth() + 10;
  myDelayQueueWidget = new DelayQueueWidget(boss, lfont, xpos, ypos);

  ////////////////////////////
  // Strobe buttons
  ////////////////////////////
  buttonX = xpos + myDelayQueueWidget->getWidth() + 20;
  buttonY = ypos;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, lineHeight,
                       "WSYNC", kWsyncCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonY += lineHeight + 3;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, lineHeight,
                       "RSYNC", kRsyncCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonX = b->getRight() + 20;
  buttonY = ypos;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, lineHeight,
                       "HMOVE", kHmoveCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonY += lineHeight + 3;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, lineHeight,
                       "HMCLR", kHmclrCmd);
  b->setTarget(this);
  addFocusWidget(b);

  setHelpAnchor("TIATab", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  TIADebug& tia = instance().debugger().tiaDebug();

  switch(cmd)
  {
    case kWsyncCmd:
      tia.strobeWsync();
      break;

    case kRsyncCmd:
      tia.strobeRsync();
      break;

    case kResP0Cmd:
      tia.strobeResP0();
      break;

    case kResP1Cmd:
      tia.strobeResP1();
      break;

    case kResM0Cmd:
      tia.strobeResM0();
      break;

    case kResM1Cmd:
      tia.strobeResM1();
      break;

    case kResBLCmd:
      tia.strobeResBL();
      break;

    case kHmoveCmd:
      tia.strobeHmove();
      break;

    case kHmclrCmd:
      tia.strobeHmclr();
      break;

    case kCxclrCmd:
      tia.strobeCxclr();
      break;

    case kDbgClCmd:
      myFixedEnabled->setState(tia.tia().toggleFixedColors());
      break;

    case kVSyncCmd:
      tia.vsync((tia.vsyncAsInt() & ~0x02) | (myVSync->getState() ? 0x02 : 0x00));
      break;

    case kVBlankCmd:
      tia.vblank((tia.vblankAsInt() & ~0x02) | (myVBlank->getState() ? 0x02 : 0x00));
      break;

    case DataGridWidget::kItemDataChangedCmd:
      switch(id)
      {
        case kColorRegsID:
          changeColorRegs();
          break;

        case kPosP0ID:
          tia.posP0(myPosP0->getSelectedValue());
          break;

        case kPosP1ID:
          tia.posP1(myPosP1->getSelectedValue());
          break;

        case kPosM0ID:
          tia.posM0(myPosM0->getSelectedValue());
          break;

        case kPosM1ID:
          tia.posM1(myPosM1->getSelectedValue());
          break;

        case kPosBLID:
          tia.posBL(myPosBL->getSelectedValue());
          break;

        case kHMP0ID:
          tia.hmP0(myHMP0->getSelectedValue());
          break;

        case kHMP1ID:
          tia.hmP1(myHMP1->getSelectedValue());
          break;

        case kHMM0ID:
          tia.hmM0(myHMM0->getSelectedValue());
          break;

        case kHMM1ID:
          tia.hmM1(myHMM1->getSelectedValue());
          break;

        case kHMBLID:
          tia.hmBL(myHMBL->getSelectedValue());
          break;

        case kNusizP0ID:
          tia.nusizP0(myNusizP0->getSelectedValue());
          myNusizP0Text->setText(tia.nusizP0String());
          break;

        case kNusizP1ID:
          tia.nusizP1(myNusizP1->getSelectedValue());
          myNusizP1Text->setText(tia.nusizP1String());
          break;

        case kNusizM0ID:
          tia.nusizM0(myNusizM0->getSelectedValue());
          break;

        case kNusizM1ID:
          tia.nusizM1(myNusizM1->getSelectedValue());
          break;

        case kSizeBLID:
          tia.sizeBL(mySizeBL->getSelectedValue());
          break;

        default:
          cerr << "TiaWidget DG changed\n";
          break;
      }
      break;

    case ToggleWidget::kItemDataChangedCmd:
      switch(id)
      {
        case kGRP0ID:
          tia.grP0(myGRP0->getIntState());
          break;

        case kGRP0OldID:
          tia.setGRP0Old(myGRP0Old->getIntState());
          break;

        case kGRP1ID:
          tia.grP1(myGRP1->getIntState());
          break;

        case kGRP1OldID:
          tia.setGRP1Old(myGRP1Old->getIntState());
          break;

        case kEnaM0ID:
          tia.enaM0(myEnaM0->getIntState());
          break;

        case kEnaM1ID:
          tia.enaM1(myEnaM1->getIntState());
          break;

        case kEnaBLID:
          tia.enaBL(myEnaBL->getIntState());
          break;

        case kEnaBLOldID:
          tia.setENABLOld(myEnaBLOld->getIntState() != 0);
          break;

        case kPF0ID:
          tia.pf0(myPF[0]->getIntState());
          break;

        case kPF1ID:
          tia.pf1(myPF[1]->getIntState());
          break;

        case kPF2ID:
          tia.pf2(myPF[2]->getIntState());
          break;

        default:
          break;
      }
      break;

    case CheckboxWidget::kCheckActionCmd:
      switch(id)
      {
        case kP0_PFID:
          tia.collision(CollisionBit::P0PF, true);
          break;

        case kP0_BLID:
          tia.collision(CollisionBit::P0BL, true);
          break;

        case kP0_M1ID:
          tia.collision(CollisionBit::M1P0, true);
          break;

        case kP0_M0ID:
          tia.collision(CollisionBit::M0P0, true);
          break;

        case kP0_P1ID:
          tia.collision(CollisionBit::P0P1, true);
          break;

        case kP1_PFID:
          tia.collision(CollisionBit::P1PF, true);
          break;
        case kP1_BLID:
          tia.collision(CollisionBit::P1BL, true);
          break;

        case kP1_M1ID:
          tia.collision(CollisionBit::M1P1, true);
          break;
        case kP1_M0ID:
          tia.collision(CollisionBit::M0P1, true);
          break;

        case kM0_PFID:
          tia.collision(CollisionBit::M0PF, true);
          break;

        case kM0_BLID:
          tia.collision(CollisionBit::M0BL, true);
          break;

        case kM0_M1ID:
          tia.collision(CollisionBit::M0M1, true);
          break;

        case kM1_PFID:
          tia.collision(CollisionBit::M1PF, true);
          break;

        case kM1_BLID:
          tia.collision(CollisionBit::M1BL, true);
          break;

        case kBL_PFID:
          tia.collision(CollisionBit::BLPF, true);
          break;

        case kRefP0ID:
          tia.refP0(myRefP0->getState() ? 1 : 0);
          break;

        case kRefP1ID:
          tia.refP1(myRefP1->getState() ? 1 : 0);
          break;

        case kDelP0ID:
          tia.vdelP0(myDelP0->getState() ? 1 : 0);
          break;

        case kDelP1ID:
          tia.vdelP1(myDelP1->getState() ? 1 : 0);
          break;

        case kDelBLID:
          tia.vdelBL(myDelBL->getState() ? 1 : 0);
          break;

        case kResMP0ID:
          tia.resMP0(myResMP0->getState() ? 1 : 0);
          break;

        case kResMP1ID:
          tia.resMP1(myResMP1->getState() ? 1 : 0);
          break;

        case kRefPFID:
          tia.refPF(myRefPF->getState() ? 1 : 0);
          break;

        case kScorePFID:
          tia.scorePF(myScorePF->getState() ? 1 : 0);
          break;

        case kPriorityPFID:
          tia.priorityPF(myPriorityPF->getState() ? 1 : 0);
          break;

        default:
          break;
      }
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaWidget::loadConfig()
{
  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  TIADebug& tia = instance().debugger().tiaDebug();
  const TiaState& state    = static_cast<const TiaState&>(tia.getState());
  const TiaState& oldstate = static_cast<const TiaState&>(tia.getOldState());

  // Color registers
  alist.clear();  vlist.clear();  changed.clear();
  for(uInt32 i = 0; i < 4; ++i)
  {
    alist.push_back(i);
    vlist.push_back(state.coluRegs[i]);
    changed.push_back(state.coluRegs[i] != oldstate.coluRegs[i]);
  }
  myColorRegs->setList(alist, vlist, changed);

  const bool fixed = tia.tia().usingFixedColors();

  myCOLUP0Color->setColor(state.coluRegs[0]);
  myCOLUP1Color->setColor(state.coluRegs[1]);
  myCOLUPFColor->setColor(state.coluRegs[2]);
  myCOLUBKColor->setColor(state.coluRegs[3]);
  myCOLUP0Color->setCrossed(fixed);
  myCOLUP1Color->setCrossed(fixed);
  myCOLUPFColor->setCrossed(fixed);
  myCOLUBKColor->setCrossed(fixed);

  // Fixed debug colors
  myFixedEnabled->setState(fixed);
  for(uInt32 c = 0; c < 8; ++c)
  {
    myFixedColors[c]->setColor(state.fixedCols[c]);
    myFixedColors[c]->setCrossed(!fixed);
  }

  ////////////////////////////
  // Collision register bits
  ////////////////////////////
  myCollision[kP0_PFID]->setState(tia.collP0_PF(), state.cx[0] != oldstate.cx[0]);
  myCollision[kP0_BLID]->setState(tia.collP0_BL(), state.cx[1] != oldstate.cx[1]);
  myCollision[kP0_M1ID]->setState(tia.collM1_P0(), state.cx[2] != oldstate.cx[2]);
  myCollision[kP0_M0ID]->setState(tia.collM0_P0(), state.cx[3] != oldstate.cx[3]);
  myCollision[kP0_P1ID]->setState(tia.collP0_P1(), state.cx[4] != oldstate.cx[4]);
  myCollision[kP1_PFID]->setState(tia.collP1_PF(), state.cx[5] != oldstate.cx[5]);
  myCollision[kP1_BLID]->setState(tia.collP1_BL(), state.cx[6] != oldstate.cx[6]);
  myCollision[kP1_M1ID]->setState(tia.collM1_P1(), state.cx[7] != oldstate.cx[7]);
  myCollision[kP1_M0ID]->setState(tia.collM0_P1(), state.cx[8] != oldstate.cx[8]);
  myCollision[kM0_PFID]->setState(tia.collM0_PF(), state.cx[9] != oldstate.cx[9]);
  myCollision[kM0_BLID]->setState(tia.collM0_BL(), state.cx[10] != oldstate.cx[10]);
  myCollision[kM0_M1ID]->setState(tia.collM0_M1(), state.cx[11] != oldstate.cx[11]);
  myCollision[kM1_PFID]->setState(tia.collM1_PF(), state.cx[12] != oldstate.cx[12]);
  myCollision[kM1_BLID]->setState(tia.collM1_BL(), state.cx[13] != oldstate.cx[13]);
  myCollision[kBL_PFID]->setState(tia.collBL_PF(), state.cx[14] != oldstate.cx[14]);

  ////////////////////////////
  // P0 register info
  ////////////////////////////
  // grP0 (new and old)
  if(tia.vdelP0())
  {
    myGRP0->setColor(kBGColorLo);
    myGRP0Old->setColor(state.coluRegs[0]);
    myGRP0Old->setCrossed(false);
  }
  else
  {
    myGRP0->setColor(state.coluRegs[0]);
    myGRP0Old->setColor(kBGColorLo);
    myGRP0Old->setCrossed(true);
  }
  myGRP0->setIntState(state.gr[TiaState::P0], state.ref[TiaState::P0]);
  myGRP0Old->setIntState(state.gr[TiaState::P0+2], state.ref[TiaState::P0]);

  // posP0
  myPosP0->setList(0, state.pos[TiaState::P0],
      state.pos[TiaState::P0] != oldstate.pos[TiaState::P0]);

  // hmP0
  myHMP0->setList(0, state.hm[TiaState::P0],
      state.hm[TiaState::P0] != oldstate.hm[TiaState::P0]);

  // refP0 & vdelP0
  myRefP0->setState(tia.refP0(), state.ref[TiaState::P0] != oldstate.ref[TiaState::P0]);
  myDelP0->setState(tia.vdelP0(), state.vdel[TiaState::P0] != oldstate.vdel[TiaState::P0]);

  // NUSIZ0 (player portion)
  const bool nusiz0changed = state.size[TiaState::P0] != oldstate.size[TiaState::P0];
  myNusizP0->setList(0, state.size[TiaState::P0], nusiz0changed);
  myNusizP0Text->setText(tia.nusizP0String(), nusiz0changed);

  ////////////////////////////
  // P1 register info
  ////////////////////////////
  // grP1 (new and old)
  if(tia.vdelP1())
  {
    myGRP1->setColor(kBGColorLo);
    myGRP1Old->setColor(state.coluRegs[1]);
    myGRP1Old->setCrossed(false);
  }
  else
  {
    myGRP1->setColor(state.coluRegs[1]);
    myGRP1Old->setColor(kBGColorLo);
    myGRP1Old->setCrossed(true);
  }
  myGRP1->setIntState(state.gr[TiaState::P1], state.ref[TiaState::P1]);
  myGRP1Old->setIntState(state.gr[TiaState::P1+2], state.ref[TiaState::P1]);

  // posP1
  myPosP1->setList(0, state.pos[TiaState::P1],
      state.pos[TiaState::P1] != oldstate.pos[TiaState::P1]);

  // hmP1
  myHMP1->setList(0, state.hm[TiaState::P1],
      state.hm[TiaState::P1] != oldstate.hm[TiaState::P1]);

  // refP1 & vdelP1
  myRefP1->setState(tia.refP1(), state.ref[TiaState::P1] != oldstate.ref[TiaState::P1]);
  myDelP1->setState(tia.vdelP1(), state.vdel[TiaState::P1] != oldstate.vdel[TiaState::P1]);

  // NUSIZ1 (player portion)
  const bool nusiz1changed = state.size[TiaState::P1] != oldstate.size[TiaState::P1];
  myNusizP1->setList(0, state.size[TiaState::P1], nusiz1changed);
  myNusizP1Text->setText(tia.nusizP1String(), nusiz1changed);

  ////////////////////////////
  // M0 register info
  ////////////////////////////
  // enaM0
  myEnaM0->setColor(state.coluRegs[0]);
  myEnaM0->setIntState(tia.enaM0() ? 1 : 0, false);

  // posM0
  myPosM0->setList(0, state.pos[TiaState::M0],
      state.pos[TiaState::M0] != oldstate.pos[TiaState::M0]);

  // hmM0
  myHMM0->setList(0, state.hm[TiaState::M0],
      state.hm[TiaState::M0] != oldstate.hm[TiaState::M0]);

  // NUSIZ0 (missile portion)
  myNusizM0->setList(0, state.size[TiaState::M0],
      state.size[TiaState::M0] != oldstate.size[TiaState::M0]);

  // resMP0
  myResMP0->setState(tia.resMP0(), state.resm[TiaState::P0] != oldstate.resm[TiaState::P0]);

  ////////////////////////////
  // M1 register info
  ////////////////////////////
  // enaM1
  myEnaM1->setColor(state.coluRegs[1]);
  myEnaM1->setIntState(tia.enaM1() ? 1 : 0, false);

  // posM1
  myPosM1->setList(0, state.pos[TiaState::M1],
      state.pos[TiaState::M1] != oldstate.pos[TiaState::M1]);

  // hmM1
  myHMM1->setList(0, state.hm[TiaState::M1],
      state.hm[TiaState::M1] != oldstate.hm[TiaState::M1]);

  // NUSIZ1 (missile portion)
  myNusizM1->setList(0, state.size[TiaState::M1],
      state.size[TiaState::M1] != oldstate.size[TiaState::M1]);

  // resMP1
  myResMP1->setState(tia.resMP1(),state.resm[TiaState::P1] != oldstate.resm[TiaState::P1]);

  ////////////////////////////
  // BL register info
  ////////////////////////////
  // enaBL (new and old)
  if(tia.vdelBL())
  {
    myEnaBL->setColor(kBGColorLo);
    myEnaBLOld->setColor(state.coluRegs[2]);
    myEnaBLOld->setCrossed(false);
  }
  else
  {
    myEnaBL->setColor(state.coluRegs[2]);
    myEnaBLOld->setColor(kBGColorLo);
    myEnaBLOld->setCrossed(true);
  }
  myEnaBL->setIntState(state.gr[4], false);
  myEnaBLOld->setIntState(state.gr[5], false);

  // posBL
  myPosBL->setList(0, state.pos[TiaState::BL],
      state.pos[TiaState::BL] != oldstate.pos[TiaState::BL]);

  // hmBL
  myHMBL->setList(0, state.hm[TiaState::BL],
      state.hm[TiaState::BL] != oldstate.hm[TiaState::BL]);

  // CTRLPF (size portion)
  mySizeBL->setList(0, state.size[TiaState::BL],
      state.size[TiaState::BL] != oldstate.size[TiaState::BL]);

  // vdelBL
  myDelBL->setState(tia.vdelBL(), state.vdel[2] != oldstate.vdel[2]);

  ////////////////////////////
  // PF register info
  ////////////////////////////
  // PF0
  myPF[0]->setColor(state.coluRegs[2]);
  myPF[0]->setIntState(state.pf[0], true);  // reverse bit order

  // PF1
  myPF[1]->setColor(state.coluRegs[2]);
  myPF[1]->setIntState(state.pf[1], false);

  // PF2
  myPF[2]->setColor(state.coluRegs[2]);
  myPF[2]->setIntState(state.pf[2], true);  // reverse bit order

  // Reflect
  myRefPF->setState(tia.refPF(), state.pf[3] != oldstate.pf[3]);

  // Score
  myScorePF->setState(tia.scorePF(), state.pf[4] != oldstate.pf[4]);

  // Priority
  myPriorityPF->setState(tia.priorityPF(), state.pf[5] != oldstate.pf[5]);

  myDelayQueueWidget->loadConfig();

  myVSync->setState(tia.vsync(), tia.vsync() != oldstate.vsb[0]);
  myVBlank->setState(tia.vblank(), tia.vblank() != oldstate.vsb[1]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaWidget::changeColorRegs()
{
  const int addr  = myColorRegs->getSelectedAddr();
  const int value = myColorRegs->getSelectedValue();

  switch(addr)
  {
    case kCOLUP0Addr:
      instance().debugger().tiaDebug().coluP0(value);
      myCOLUP0Color->setColor(value);
      break;

    case kCOLUP1Addr:
      instance().debugger().tiaDebug().coluP1(value);
      myCOLUP1Color->setColor(value);
      break;

    case kCOLUPFAddr:
      instance().debugger().tiaDebug().coluPF(value);
      myCOLUPFColor->setColor(value);
      break;

    case kCOLUBKAddr:
      instance().debugger().tiaDebug().coluBK(value);
      myCOLUBKColor->setColor(value);
      break;

    default:
      break;
  }
}
