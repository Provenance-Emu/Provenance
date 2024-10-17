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

#include "ColorWidget.hxx"
#include "DataGridWidget.hxx"
#include "EditTextWidget.hxx"
#include "FrameBuffer.hxx"
#include "Font.hxx"
#include "GuiObject.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "TIA.hxx"
#include "TIADebug.hxx"
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
            buttonW = 7 * fontWidth,
            buttonH = lineHeight,
            hGap = fontWidth,
            vGap = fontHeight / 2,
            hBorder = 10,
            vBorder = 10;
  int xpos = hBorder, ypos = vBorder;
  StaticTextWidget* t = nullptr;
  ButtonWidget* b = nullptr;


  ////////////////////////////
  // VSync/VBlank
  ////////////////////////////
  int buttonX = xpos, buttonY = ypos;
  myVSync = new CheckboxWidget(boss, lfont, buttonX, buttonY, "VSync", kVSyncCmd);
  myVSync->setTarget(this);
  addFocusWidget(myVSync);

  buttonX += myVSync->getRight() + hGap * 2;
  myVBlank = new CheckboxWidget(boss, lfont, buttonX, buttonY, "VBlank", kVBlankCmd);
  myVBlank->setTarget(this);
  addFocusWidget(myVBlank);

  // Color registers
  ypos = vBorder + lineHeight * 2 + vGap / 2;
  static constexpr std::array<string_view, 4> regNames = {
    "COLUP0", "COLUP1", "COLUPF", "COLUBK"
  };
  for(int row = 0; row < 4; ++row)
    new StaticTextWidget(boss, lfont, xpos, ypos + row * lineHeight + 2,
                         regNames[row]);
  xpos += 6 * fontWidth + hGap;
  myColorRegs = new DataGridWidget(boss, nfont, xpos, ypos,
                                   1, 4, 2, 8, Common::Base::Fmt::_16);
  myColorRegs->setTarget(this);
  myColorRegs->setID(kColorRegsID);
  addFocusWidget(myColorRegs);

  xpos += myColorRegs->colWidth() + hGap / 2;
  myCOLUP0Color = new ColorWidget(boss, nfont, xpos, ypos + 2,
                                  static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
  myCOLUP0Color->setTarget(this);

  ypos += lineHeight;
  myCOLUP1Color = new ColorWidget(boss, nfont, xpos, ypos + 2,
                                  static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
  myCOLUP1Color->setTarget(this);

  ypos += lineHeight;
  myCOLUPFColor = new ColorWidget(boss, nfont, xpos, ypos + 2,
                                  static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
  myCOLUPFColor->setTarget(this);

  ypos += lineHeight;
  myCOLUBKColor = new ColorWidget(boss, nfont, xpos, ypos + 2,
                                  static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
  myCOLUBKColor->setTarget(this);

  // Fixed debug colors
  xpos = myCOLUP0Color->getRight() + hGap * 4;  ypos = vBorder + lineHeight + vGap / 2;
  myFixedEnabled = new CheckboxWidget(boss, lfont, xpos, ypos, "Debug Colors", kDbgClCmd);
  myFixedEnabled->setToolTip("Enable fixed debug colors", Event::ToggleFixedColors);
  myFixedEnabled->setTarget(this);
  addFocusWidget(myFixedEnabled);

  static constexpr std::array<string_view, 8> dbgLabels = {
    "P0", "P1", "PF", "BK", "M0", "M1", "BL", "HM"
  };
  for(uInt32 row = 0; row <= 3; ++row)
  {
    ypos += lineHeight;
    t = new StaticTextWidget(boss, lfont, xpos, ypos + 2, dbgLabels[row]);
    myFixedColors[row] = new ColorWidget(boss, nfont, t->getRight() + hGap,
                                         ypos + 2, static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
    myFixedColors[row]->setTarget(this);
  }
  xpos = myFixedColors[0]->getRight() + hGap * 2;
  ypos = vBorder + lineHeight + vGap / 2;
  for(uInt32 row = 4; row <= 7; ++row)
  {
    ypos += lineHeight;
    t = new StaticTextWidget(boss, lfont, xpos, ypos + 2, dbgLabels[row]);
    myFixedColors[row] = new ColorWidget(boss, nfont, t->getRight() + hGap,
                                         ypos + 2, static_cast<uInt32>(1.5 * lineHeight), lineHeight - 4);
    myFixedColors[row]->setTarget(this);
  }

  ////////////////////////////
  // Collision register bits
  ////////////////////////////
  xpos = myFixedColors[4]->getRight() + 6 * hGap;  ypos = vBorder + lineHeight;

  // Add all 15 collision bits (with labels)
  static constexpr std::array<string_view, 5> rowLabel = { "P0", "P1", "M0", "M1", "BL" };
  static constexpr std::array<string_view, 5> colLabel = { "PF", "BL", "M1", "M0", "P1" };
  int idx = 0;
  for(uInt32 row = 0; row < 5; ++row)
  {
    // Add vertical label
    t = new StaticTextWidget(boss, lfont, xpos, ypos, rowLabel[row]);
    int collX = t->getRight() + hGap;

    for(uInt32 col = 0; col < 5 - row; ++col, ++idx)
    {
      myCollision[idx] = new CheckboxWidget(boss, lfont, collX, ypos, "", CheckboxWidget::kCheckActionCmd);
      myCollision[idx]->setTarget(this);
      myCollision[idx]->setID(idx);

      if(row == 0)
      {
        // Add centered horizontal label
        const int labelx = collX - (2 * fontWidth - myCollision[idx]->getWidth()) / 2;
        new StaticTextWidget(boss, lfont, labelx, ypos - lineHeight, colLabel[col]);
      }
      collX += fontWidth * 2 + hGap;
    }
    ypos += lineHeight + 3; // constant gap for all font sizes because checkboxes have the same size too
  }

  // Clear all collision bits
  buttonX = myCollision[kP0_P1ID]->getRight() - buttonW;
  buttonY = myCollision[kBL_PFID]->getBottom() - buttonH;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, buttonH,
                       "CXCLR", kCxclrCmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // P0 register info
  ////////////////////////////
  // grP0 (new)
  ypos = std::max(myFixedColors[3]->getBottom(), b->getBottom()) + vGap * 1.5;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "P0");
  myGRP0 = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 8, 1);
  myGRP0->setTarget(this);
  myGRP0->setID(kGRP0ID);
  myGRP0->clearBackgroundColor();
  addFocusWidget(myGRP0);

  // posP0
  t = new StaticTextWidget(boss, lfont, myGRP0->getRight() + hGap * 1.5, ypos + 2, "Pos#");
  myPosP0 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosP0->setTarget(this);
  myPosP0->setID(kPosP0ID);
  myPosP0->setRange(0, 160);
  addFocusWidget(myPosP0);

  // hmP0
  t = new StaticTextWidget(boss, lfont, myPosP0->getRight() + hGap * 3, ypos + 2, "HM");
  myHMP0 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMP0->setTarget(this);
  myHMP0->setID(kHMP0ID);
  addFocusWidget(myHMP0);

  // P0 reflect
  myRefP0 = new CheckboxWidget(boss, lfont, myHMP0->getRight() + hGap * 2, ypos + 1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefP0->setTarget(this);
  myRefP0->setID(kRefP0ID);
  addFocusWidget(myRefP0);

  // P0 reset
  buttonX = myRefP0->getRight() + hGap * 2;
  b = new ButtonWidget(boss, lfont, buttonX, ypos, buttonW, buttonH,
                       "RESP0", kResP0Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  // grP0 (old)
  ypos += myGRP0->getHeight() + vGap / 2;
  myGRP0Old = new TogglePixelWidget(boss, nfont, myGRP0->getLeft(), ypos + 1, 8, 1);
  myGRP0Old->setTarget(this);
  myGRP0Old->setID(kGRP0OldID);
  myGRP0Old->clearBackgroundColor();
  addFocusWidget(myGRP0Old);

  // P0 delay
  myDelP0 = new CheckboxWidget(boss, lfont, myGRP0Old->getRight() + hGap * 1.5, ypos + 2,
                               "VDel", CheckboxWidget::kCheckActionCmd);
  myDelP0->setTarget(this);
  myDelP0->setID(kDelP0ID);
  addFocusWidget(myDelP0);

  // NUSIZ0 (player portion)
  new StaticTextWidget(boss, lfont, myHMP0->getLeft() - fontWidth * 5 - hGap / 2, ypos + 2, "NuSiz");
  myNusizP0 = new DataGridWidget(boss, nfont, myHMP0->getLeft(), ypos,
                                 1, 1, 1, 3, Common::Base::Fmt::_16_1);
  myNusizP0->setTarget(this);
  myNusizP0->setID(kNusizP0ID);
  addFocusWidget(myNusizP0);

  myNusizP0Text = new EditTextWidget(boss, nfont, myNusizP0->getRight() + hGap / 2, ypos,
                                     21 * fontWidth, lineHeight);
  myNusizP0Text->setEditable(false, true);

  ////////////////////////////
  // P1 register info
  ////////////////////////////
  // grP1 (new)
  ypos += lineHeight + vGap * 1.5;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "P1");
  myGRP1 = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 8, 1);
  myGRP1->setTarget(this);
  myGRP1->setID(kGRP1ID);
  myGRP1->clearBackgroundColor();
  addFocusWidget(myGRP1);

  // posP1
  t = new StaticTextWidget(boss, lfont, myGRP1->getRight() + hGap * 1.5, ypos + 2, "Pos#");
  myPosP1 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosP1->setTarget(this);
  myPosP1->setID(kPosP1ID);
  myPosP1->setRange(0, 160);
  addFocusWidget(myPosP1);

  // hmP1
  t = new StaticTextWidget(boss, lfont, myPosP1->getRight() + hGap * 3, ypos + 2, "HM");
  myHMP1 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMP1->setTarget(this);
  myHMP1->setID(kHMP1ID);
  addFocusWidget(myHMP1);

  // P1 reflect
  myRefP1 = new CheckboxWidget(boss, lfont, myHMP1->getRight() + hGap * 2, ypos + 1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefP1->setTarget(this);
  myRefP1->setID(kRefP1ID);
  addFocusWidget(myRefP1);

  // P1 reset
  b = new ButtonWidget(boss, lfont, myRefP1->getRight() + hGap * 2, ypos,
                       buttonW, buttonH, "RESP1", kResP1Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  // grP1 (old)
  ypos += myGRP1->getHeight() + vGap / 2;
  myGRP1Old = new TogglePixelWidget(boss, nfont, myGRP1->getLeft(), ypos + 1, 8, 1);
  myGRP1Old->setTarget(this);
  myGRP1Old->setID(kGRP1OldID);
  myGRP1Old->clearBackgroundColor();
  addFocusWidget(myGRP1Old);

  // P1 delay
  myDelP1 = new CheckboxWidget(boss, lfont, myGRP1Old->getRight() + hGap * 1.5, ypos + 2,
                               "VDel", CheckboxWidget::kCheckActionCmd);
  myDelP1->setTarget(this);
  myDelP1->setID(kDelP1ID);
  addFocusWidget(myDelP1);

  // NUSIZ1 (player portion)
  new StaticTextWidget(boss, lfont, myHMP1->getLeft() - fontWidth * 5 - hGap / 2, ypos + 2, "NuSiz");
  myNusizP1 = new DataGridWidget(boss, nfont, myHMP1->getLeft(), ypos,
                                 1, 1, 1, 3, Common::Base::Fmt::_16_1);
  myNusizP1->setTarget(this);
  myNusizP1->setID(kNusizP1ID);
  addFocusWidget(myNusizP1);

  myNusizP1Text = new EditTextWidget(boss, nfont, myNusizP1->getRight() + hGap / 2, ypos,
                                     21 * fontWidth, lineHeight);
  myNusizP1Text->setEditable(false, true);

  ////////////////////////////
  // M0 register info
  ////////////////////////////
  // enaM0
  ypos += lineHeight + vGap * 1.5;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "M0");
  myEnaM0 = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 1, 1);
  myEnaM0->setTarget(this);
  myEnaM0->setID(kEnaM0ID);
  myEnaM0->clearBackgroundColor();
  addFocusWidget(myEnaM0);

  // posM0
  t = new StaticTextWidget(boss, lfont, myEnaM0->getRight() + hGap * 1.5, ypos + 2, "Pos#");
  myPosM0 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosM0->setTarget(this);
  myPosM0->setID(kPosM0ID);
  myPosM0->setRange(0, 160);
  addFocusWidget(myPosM0);

  // hmM0
  t = new StaticTextWidget(boss, lfont, myPosM0->getRight() + hGap * 1.5, ypos + 2, "HM");
  myHMM0 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMM0->setTarget(this);
  myHMM0->setID(kHMM0ID);
  addFocusWidget(myHMM0);

  // NUSIZ0 (missile portion)
  t = new StaticTextWidget(boss, lfont, myHMM0->getRight() + hGap * 1.5, ypos + 2, "Size");
  myNusizM0 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                                 1, 1, 1, 2, Common::Base::Fmt::_16_1);
  myNusizM0->setTarget(this);
  myNusizM0->setID(kNusizM0ID);
  addFocusWidget(myNusizM0);

  // M0 reset to player 0
  myResMP0 = new CheckboxWidget(boss, lfont, myNusizM0->getRight() + hGap * 2, ypos + 1,
                                "Reset to P0", CheckboxWidget::kCheckActionCmd);
  myResMP0->setTarget(this);
  myResMP0->setID(kResMP0ID);
  addFocusWidget(myResMP0);

  // M0 reset
  b = new ButtonWidget(boss, lfont, buttonX, ypos, buttonW, buttonH,
                       "RESM0", kResM0Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // M1 register info
  ////////////////////////////
  // enaM1
  ypos += lineHeight + vGap / 2;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "M1");
  myEnaM1 = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 1, 1);
  myEnaM1->setTarget(this);
  myEnaM1->setID(kEnaM1ID);
  myEnaM1->clearBackgroundColor();
  addFocusWidget(myEnaM1);

  // posM0
  t = new StaticTextWidget(boss, lfont, myEnaM1->getRight() + hGap * 1.5, ypos + 2, "Pos#");
  myPosM1 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosM1->setTarget(this);
  myPosM1->setID(kPosM1ID);
  myPosM1->setRange(0, 160);
  addFocusWidget(myPosM1);

  // hmM0
  t = new StaticTextWidget(boss, lfont, myPosM1->getRight() + hGap * 1.5, ypos + 2, "HM");
  myHMM1 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMM1->setTarget(this);
  myHMM1->setID(kHMM1ID);
  addFocusWidget(myHMM1);

  // NUSIZ1 (missile portion)
  t = new StaticTextWidget(boss, lfont, myHMM1->getRight() + hGap * 1.5, ypos + 2, "Size");
  myNusizM1 = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                                 1, 1, 1, 2, Common::Base::Fmt::_16_1);
  myNusizM1->setTarget(this);
  myNusizM1->setID(kNusizM1ID);
  addFocusWidget(myNusizM1);

  // M1 reset to player 0
  myResMP1 = new CheckboxWidget(boss, lfont, myNusizM1->getRight() + hGap * 2, ypos + 1,
                                "Reset to P1", CheckboxWidget::kCheckActionCmd);
  myResMP1->setTarget(this);
  myResMP1->setID(kResMP1ID);
  addFocusWidget(myResMP1);

  // M1 reset
  b = new ButtonWidget(boss, lfont, buttonX, ypos, buttonW, buttonH,
                       "RESM1", kResM1Cmd);
  b->setTarget(this);
  addFocusWidget(b);

  ////////////////////////////
  // BL register info
  ////////////////////////////
  // enaBL
  ypos += lineHeight + vGap / 2;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "BL");
  myEnaBL = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 1, 1);
  myEnaBL->setTarget(this);
  myEnaBL->setID(kEnaBLID);
  myEnaBL->clearBackgroundColor();
  addFocusWidget(myEnaBL);

  // posBL
  t = new StaticTextWidget(boss, lfont, myEnaBL->getRight() + hGap * 1.5, ypos + 2, "Pos#");
  myPosBL = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                               1, 1, 3, 8, Common::Base::Fmt::_10);
  myPosBL->setTarget(this);
  myPosBL->setID(kPosBLID);
  myPosBL->setRange(0, 160);
  addFocusWidget(myPosBL);

  // hmBL
  t = new StaticTextWidget(boss, lfont, myPosBL->getRight() + hGap * 1.5, ypos + 2, "HM");
  myHMBL = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                              1, 1, 1, 4, Common::Base::Fmt::_16_1);
  myHMBL->setTarget(this);
  myHMBL->setID(kHMBLID);
  addFocusWidget(myHMBL);

  // CTRLPF (size portion)
  t = new StaticTextWidget(boss, lfont, myHMBL->getRight() + hGap * 1.5, ypos + 2, "Size");
  mySizeBL = new DataGridWidget(boss, nfont, t->getRight() + hGap / 2, ypos,
                                1, 1, 1, 2, Common::Base::Fmt::_16_1);
  mySizeBL->setTarget(this);
  mySizeBL->setID(kSizeBLID);
  addFocusWidget(mySizeBL);

  // Reset ball
  b = new ButtonWidget(boss, lfont, buttonX, ypos, buttonW, buttonH,
                       "RESBL", kResBLCmd);
  b->setTarget(this);
  addFocusWidget(b);

  // Ball (old)
  ypos += lineHeight + hGap / 2;
  myEnaBLOld = new TogglePixelWidget(boss, nfont, myEnaBL->getLeft(), ypos + 1, 1, 1);
  myEnaBLOld->setTarget(this);
  myEnaBLOld->setID(kEnaBLOldID);
  myEnaBLOld->clearBackgroundColor();
  addFocusWidget(myEnaBLOld);

  // Ball delay
  myDelBL = new CheckboxWidget(boss, lfont, myEnaBLOld->getRight() + hGap * 1.5, ypos + 2,
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
  static constexpr std::array<string_view, 8> bitNames = {
    "0", "1", "2", "3", "4", "5", "6", "7"
  };

  // PF0
  ypos += lineHeight + sfHeight + vGap * 1.5;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 2, "PF");
  myPF[0] = new TogglePixelWidget(boss, nfont, t->getRight() + hGap, ypos + 1, 4, 1, 4);
  myPF[0]->setTarget(this);
  myPF[0]->setID(kPF0ID);
  addFocusWidget(myPF[0]);

  // PF1
  myPF[1] = new TogglePixelWidget(boss, nfont, myPF[0]->getRight() + hGap / 2, ypos + 1, 8, 1);
  myPF[1]->setTarget(this);
  myPF[1]->setID(kPF1ID);
  addFocusWidget(myPF[1]);

  // PF2
  myPF[2] = new TogglePixelWidget(boss, nfont, myPF[1]->getRight() + hGap / 2, ypos + 1, 8, 1);
  myPF[2]->setTarget(this);
  myPF[2]->setID(kPF2ID);
  addFocusWidget(myPF[2]);

  // PFx bit labels
  const auto start = [&](int sw) { return (sw - sfWidth + 2) / 2; };
  const int colw = myPF[0]->getWidth() / 4;
  xpos = myPF[0]->getLeft() + start(colw);
  const int _ypos = ypos - sfHeight;
  for(int i = 4; i <= 7; ++i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, bitNames[i]);
    xpos += colw;
  }
  xpos = myPF[1]->getLeft() + start(colw);
  for(int i = 7; i >= 0; --i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, bitNames[i]);
    xpos += colw;
  }
  xpos = myPF[2]->getLeft() + start(colw);
  for(int i = 0; i <= 7; ++i)
  {
    new StaticTextWidget(boss, sf, xpos, _ypos, bitNames[i]);
    xpos += colw;
  }

  // PF reflect, score, priority
  ypos = myPF[0]->getBottom() + vGap / 2;
  myRefPF = new CheckboxWidget(boss, lfont, myPF[0]->getLeft(), ypos + 1,
                               "Reflect", CheckboxWidget::kCheckActionCmd);
  myRefPF->setTarget(this);
  myRefPF->setID(kRefPFID);
  addFocusWidget(myRefPF);

  myScorePF = new CheckboxWidget(boss, lfont, myRefPF->getRight() + hGap * 2, ypos + 1,
                                 "Score", CheckboxWidget::kCheckActionCmd);
  myScorePF->setTarget(this);
  myScorePF->setID(kScorePFID);
  addFocusWidget(myScorePF);

  myPriorityPF = new CheckboxWidget(boss, lfont, myScorePF->getRight() + hGap * 2, ypos + 1,
                                    "Priority", CheckboxWidget::kCheckActionCmd);
  myPriorityPF->setTarget(this);
  myPriorityPF->setID(kPriorityPFID);
  addFocusWidget(myPriorityPF);

  ypos += lineHeight + vGap * 1.5;
  t = new StaticTextWidget(boss, lfont, hBorder, ypos + 1, "Queued Writes");
  myDelayQueueWidget = new DelayQueueWidget(boss, lfont, t->getRight() + hGap, ypos);

  ////////////////////////////
  // Strobe buttons
  ////////////////////////////
  buttonX = myDelayQueueWidget->getRight() + hGap * 2;
  buttonY = ypos;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, buttonH,
                       "WSYNC", kWsyncCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonY += lineHeight + vGap;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, buttonH,
                       "RSYNC", kRsyncCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonX = b->getRight() + hGap * 2;
  buttonY = ypos;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, buttonH,
                       "HMOVE", kHmoveCmd);
  b->setTarget(this);
  addFocusWidget(b);

  buttonY += lineHeight + vGap;
  b = new ButtonWidget(boss, lfont, buttonX, buttonY, buttonW, buttonH,
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
  const auto& state    = static_cast<const TiaState&>(tia.getState());
  const auto& oldstate = static_cast<const TiaState&>(tia.getOldState());

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
  myGRP0Old->setIntState(state.gr[TiaState::P0 + 2], state.ref[TiaState::P0]);

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
  myGRP1Old->setIntState(state.gr[TiaState::P1 + 2], state.ref[TiaState::P1]);

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
  myEnaM0->setColor(tia.resMP0() ? kBGColorLo : state.coluRegs[0]);
  myEnaM0->setCrossed(tia.resMP0());
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
  myEnaM1->setColor(tia.resMP1() ? kBGColorLo : state.coluRegs[1]);
  myEnaM1->setCrossed(tia.resMP1());
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
