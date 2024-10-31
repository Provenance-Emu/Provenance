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
#include "Font.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "RiotDebug.hxx"
#include "TIADebug.hxx"
#include "Widget.hxx"
#include "EditTextWidget.hxx"
#include "GuiObject.hxx"

#include "TiaInfoWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TiaInfoWidget::TiaInfoWidget(GuiObject* boss, const GUI::Font& lfont,
                             const GUI::Font& nfont,
                             int x, int y, int max_w)
  : Widget(boss, lfont, x, y, 16, 16),
    CommandSender(boss)
{
  const int VGAP = lfont.getLineHeight() / 4;
  constexpr int VBORDER = 5 + 1;
  const int COLUMN_GAP = _fontWidth * 1.25;
  const bool longstr = lfont.getStringWidth("Frame Cycls12345") + _fontWidth * 0.5
    + COLUMN_GAP + lfont.getStringWidth("Scanline262262")
    + EditTextWidget::calcWidth(lfont) * 3 <= max_w;
  const int lineHeight = lfont.getLineHeight();
  int lwidth = lfont.getStringWidth(longstr ? "Frame Cycls" : "F. Cycls");
  int lwidth8 = lwidth - lfont.getMaxCharWidth() * 3;
  int lwidthR = lfont.getStringWidth(longstr ? "Frame Cnt." : "Frame   ");
  int fwidth = EditTextWidget::calcWidth(lfont, 5);
  const int twidth = EditTextWidget::calcWidth(lfont, 8);
  const int LGAP = (max_w - lwidth - EditTextWidget::calcWidth(lfont, 5)
    - lwidthR - EditTextWidget::calcWidth(lfont, 5)) / 4;

  lwidth += LGAP;
  lwidth8 += LGAP;
  lwidthR += LGAP;

  // Left column
  // Left: Frame Cycle
  int xpos = x, ypos = y + VBORDER;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Frame Cycls" : "F. Cycls");
  myFrameCycles = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myFrameCycles->setToolTip("CPU cycles executed this frame.");
  myFrameCycles->setEditable(false, true);

  // Left: WSync Cycles
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "WSync Cycls" : "WSync C.");
  myWSyncCylces = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myWSyncCylces->setToolTip("CPU cycles used for WSYNC this frame.");
  myWSyncCylces->setEditable(false, true);

  // Left: Timer Cycles
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Timer Cycls" : "Timer C.");
  myTimerCylces = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myTimerCylces->setToolTip("CPU cycles roughly used for INTIM reads this frame.");
  myTimerCylces->setEditable(false, true);

  // Left: Total Cycles
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, "Total");
  myTotalCycles = new EditTextWidget(boss, nfont, xpos + lwidth8, ypos - 1, twidth, lineHeight);
  myTotalCycles->setEditable(false, true);

  // Left: Delta Cycles
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, "Delta");
  myDeltaCycles = new EditTextWidget(boss, nfont, xpos + lwidth8, ypos - 1, twidth, lineHeight);
  myDeltaCycles->setToolTip("CPU cycles executed since last debug break.");
  myDeltaCycles->setEditable(false, true);

  // Right column
  xpos = x + max_w - lwidthR - EditTextWidget::calcWidth(lfont, 5); ypos = y + VBORDER;
  //xpos = myDeltaCycles->getRight() + LGAP * 2; ypos = y + VBORDER;

  // Right: Frame Count
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Frame Cnt." : "Frame");
  myFrameCount = new EditTextWidget(boss, nfont, xpos + lwidthR, ypos - 1, fwidth, lineHeight);
  myFrameCount->setToolTip("Total number of frames executed this session.");
  myFrameCount->setEditable(false, true);

  lwidth = lfont.getStringWidth(longstr ? "Color Clock " : "Pixel Pos ") + LGAP;
  fwidth = EditTextWidget::calcWidth(lfont, 3);

  // Right: Scanline
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Scanline" : "Scn Ln");
  myScanlineCountLast = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myScanlineCountLast->setToolTip("Number of scanlines of last frame.");
  myScanlineCountLast->setEditable(false, true);
  myScanlineCount = new EditTextWidget(boss, nfont,
                                       xpos + lwidth - myScanlineCountLast->getWidth() - 2, ypos - 1,
                                       fwidth, lineHeight);
  myScanlineCount->setToolTip("Current scanline of this frame.");
  myScanlineCount->setEditable(false, true);

  // Right: Scan Cycle
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Scan Cycle" : "Scn Cycle");
  myScanlineCycles = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myScanlineCycles->setToolTip("CPU cycles in current scanline.");
  myScanlineCycles->setEditable(false, true);

  // Right: Pixel Pos
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, "Pixel Pos");
  myPixelPosition = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myPixelPosition->setToolTip("Pixel position in current scanline.");
  myPixelPosition->setEditable(false, true);

  // Right: Color Clock
  ypos += lineHeight + VGAP;
  new StaticTextWidget(boss, lfont, xpos, ypos + 1, longstr ? "Color Clock" : "Color Clk");
  myColorClocks = new EditTextWidget(boss, nfont, xpos + lwidth, ypos - 1, fwidth, lineHeight);
  myColorClocks->setToolTip("Color clocks in current scanline.");
  myColorClocks->setEditable(false, true);

  // Calculate actual dimensions
  _w = myColorClocks->getRight() - x;
  _h = myColorClocks->getBottom();

  //setHelpAnchor("TIAInfo", true); // TODO: does not work due to missing focus
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaInfoWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
//cerr << "TiaInfoWidget button press: x = " << x << ", y = " << y << '\n';
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaInfoWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaInfoWidget::loadConfig()
{
  const Debugger& dbg = instance().debugger();
  TIADebug& tia = dbg.tiaDebug();
  const auto& oldTia = static_cast<const TiaState&>(tia.getOldState());
  RiotDebug& riot = dbg.riotDebug();
  const auto& oldRiot = static_cast<const RiotState&>(riot.getOldState());

  myFrameCount->setText(Common::Base::toString(tia.frameCount(), Common::Base::Fmt::_10_5),
                        tia.frameCount() != oldTia.info[0]);
  myFrameCycles->setText(Common::Base::toString(tia.frameCycles(), Common::Base::Fmt::_10_5),
                         tia.frameCycles() != oldTia.info[1]);

  const uInt64 total = tia.cyclesLo() + (static_cast<uInt64>(tia.cyclesHi()) << 32);
  const uInt64 totalOld = oldTia.info[2] + (static_cast<uInt64>(oldTia.info[3]) << 32);
  myTotalCycles->setText(Common::Base::toString(static_cast<uInt32>(total) / 1000000,
                         Common::Base::Fmt::_10_6) + "e6",
                         total / 1000000 != totalOld / 1000000);
  myTotalCycles->setToolTip("Total CPU cycles (E notation) executed for this session ("
                            + std::to_string(total) + ").");

  const uInt64 delta = total - totalOld;
  myDeltaCycles->setText(Common::Base::toString(static_cast<uInt32>(delta),
                         Common::Base::Fmt::_10_8)); // no coloring

  const int clk = tia.clocksThisLine();
  myScanlineCount->setText(Common::Base::toString(tia.scanlines(), Common::Base::Fmt::_10_3),
                           tia.scanlines() != oldTia.info[4]);
  myScanlineCountLast->setText(
    Common::Base::toString(tia.scanlinesLastFrame(), Common::Base::Fmt::_10_3),
    tia.scanlinesLastFrame() != oldTia.info[5]);
  myScanlineCycles->setText(Common::Base::toString(clk/3, Common::Base::Fmt::_10),
                            clk != oldTia.info[6]);
  myPixelPosition->setText(Common::Base::toString(clk-68, Common::Base::Fmt::_10),
                           clk != oldTia.info[6]);
  myColorClocks->setText(Common::Base::toString(clk, Common::Base::Fmt::_10),
                         clk != oldTia.info[6]);

  myWSyncCylces->setText(Common::Base::toString(tia.frameWsyncCycles(), Common::Base::Fmt::_10_5),
                         tia.frameWsyncCycles() != oldTia.info[7]);

  myTimerCylces->setText(Common::Base::toString(riot.timReadCycles(), Common::Base::Fmt::_10_5),
                         riot.timReadCycles() != oldRiot.timReadCycles);
}
