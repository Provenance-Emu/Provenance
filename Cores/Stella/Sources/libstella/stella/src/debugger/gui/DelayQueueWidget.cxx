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

#include "DelayQueueWidget.hxx"
#include "DelayQueueIterator.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "TIADebug.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "Base.hxx"
#include "TIA.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DelayQueueWidget::DelayQueueWidget(
    GuiObject* boss,
    const GUI::Font& font,
    int x, int y
  ) : Widget(boss, font, x, y, 0, 0)
{
  _textcolor = kTextColor;

  _w = 20 * font.getMaxCharWidth() + 6;
  _h = static_cast<int>(myLines.size() * font.getLineHeight() + 6);

  for (auto&& line : myLines)
    line = "";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DelayQueueWidget::loadConfig() {
  const shared_ptr<DelayQueueIterator> delayQueueIterator =
      instance().debugger().tiaDebug().delayQueueIterator();

  using Common::Base;
  for (auto&& line : myLines) {
    if (!delayQueueIterator->isValid()) {
      if(!line.empty())
      {
        setDirty();
        line = "";
      }
      continue;
    }

    stringstream ss;
    const auto address = delayQueueIterator->address();
    const int delay = delayQueueIterator->delay();

    switch (address) {
      case TIA::DummyRegisters::shuffleP0:
        ss << delay << " clk, shuffle GRP0";
        break;

      case TIA::DummyRegisters::shuffleP1:
        ss << delay << " clk, shuffle GRP1";
        break;

      case TIA::DummyRegisters::shuffleBL:
        ss << delay << " clk, shuffle ENABL";
        break;

      default:
        if (address < 64) ss
          << delay
          << " clk, $"
          << Base::toString(delayQueueIterator->value(), Base::Fmt::_16_2)
          << " -> "
          << instance().debugger().cartDebug().getLabel(address, false);
        break;
    }

    if(line != ss.str())
    {
      setDirty();
      line = ss.str();
    }
    delayQueueIterator->next();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DelayQueueWidget::drawWidget(bool hilite)
{
  FBSurface& surface = _boss->dialog().surface();

  int y = _y,
      x = _x,
      w = _w;
  const int lineHeight = _font.getLineHeight();

  surface.frameRect(x, y, w, _h, kColor);

  y += 1;
  x += 1;
  w -= 1;
  surface.fillRect(x, y, w - 1, _h - 2, kDlgColor);

  y += 2;
  x += 2;
  w -= 3;

  for (const auto& line : myLines) {
    surface.drawString(_font, line, x, y, w, _textcolor);
    y += lineHeight;
  }
}
