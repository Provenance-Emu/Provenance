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

#include "DataGridWidget.hxx"
#include "DrivingWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DrivingWidget::DrivingWidget(GuiObject* boss, const GUI::Font& font,
                             int x, int y, Controller& controller, bool embedded)
  : ControllerWidget(boss, font, x, y, controller)
{
  const string& label = getHeader();

  const int lineHeight = font.getLineHeight(),
            bHeight = font.getLineHeight() * 1.25;
  int xpos = x, ypos = y;

  if(embedded)
  {
    const int bWidth = font.getStringWidth("GC+ ");

    ypos += _lineHeight * 0.334;
    myGrayUp = new ButtonWidget(boss, font, xpos, ypos, bWidth, bHeight,
                                "GC+", kGrayUpCmd);

    ypos += myGrayUp->getHeight() + bHeight * 0.3;
    myGrayDown = new ButtonWidget(boss, font, xpos, ypos, bWidth, bHeight,
                                  "GC-", kGrayDownCmd);
    xpos += myGrayDown->getWidth() + _fontWidth * 0.75;
  }
  else
  {
    const int lwidth = font.getStringWidth("Right (Driving)"),
      bWidth = font.getStringWidth("Gray code +") + _fontWidth * 1.25;

    const StaticTextWidget* t = new StaticTextWidget(boss, font, xpos, ypos + 2, lwidth,
                                                     lineHeight, label, TextAlign::Left);

    ypos = t->getBottom() + _lineHeight * 1.334;
    myGrayUp = new ButtonWidget(boss, font, xpos, ypos, bWidth, bHeight,
                                "Gray code +", kGrayUpCmd);

    ypos += myGrayUp->getHeight() + bHeight * 0.3;
    myGrayDown = new ButtonWidget(boss, font, xpos, ypos, bWidth, bHeight,
                                  "Gray code -", kGrayDownCmd);
    xpos += myGrayDown->getWidth() + _fontWidth;
  }
  ypos -= bHeight * 0.6;
  myGrayValue = new DataGridWidget(boss, font, xpos, ypos,
                                   1, 1, 2, 8, Common::Base::Fmt::_16);

  xpos = x + myGrayDown->getWidth() * 0.25; ypos = myGrayDown->getBottom() + _lineHeight;
  myFire = new CheckboxWidget(boss, font, xpos, ypos, "Fire", kFireCmd);

  myGrayUp->setTarget(this);
  myGrayDown->setTarget(this);
  myGrayValue->setTarget(this);
  myGrayValue->setEditable(false);
  myFire->setTarget(this);

  addFocusWidget(myGrayUp);
  addFocusWidget(myGrayDown);
  addFocusWidget(myFire);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DrivingWidget::loadConfig()
{
  uInt8 gray = 0;
  if(getPin(Controller::DigitalPin::One)) gray += 1;
  if(getPin(Controller::DigitalPin::Two)) gray += 2;

  for(myGrayIndex = 0; myGrayIndex < 4; ++myGrayIndex)
  {
    if(ourGrayTable[myGrayIndex] == gray)
    {
      setValue(myGrayIndex);
      break;
    }
  }

  myFire->setState(!getPin(Controller::DigitalPin::Six));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DrivingWidget::handleCommand(
    CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case kGrayUpCmd:
      myGrayIndex = (myGrayIndex + 1) % 4;
      setPin(Controller::DigitalPin::One, (ourGrayTable[myGrayIndex] & 0x1) != 0);
      setPin(Controller::DigitalPin::Two, (ourGrayTable[myGrayIndex] & 0x2) != 0);
      setValue(myGrayIndex);
      break;
    case kGrayDownCmd:
      myGrayIndex = myGrayIndex == 0 ? 3 : myGrayIndex - 1;
      setPin(Controller::DigitalPin::One, (ourGrayTable[myGrayIndex] & 0x1) != 0);
      setPin(Controller::DigitalPin::Two, (ourGrayTable[myGrayIndex] & 0x2) != 0);
      setValue(myGrayIndex);
      break;
    case kFireCmd:
      setPin(Controller::DigitalPin::Six, !myFire->getState());
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DrivingWidget::setValue(int idx)
{
  const int grayCode = ourGrayTable[idx];
  // FIXME  * 8 = a nasty hack, because the DataGridWidget does not support 2 digit binary output
  myGrayValue->setList(0, (grayCode & 0b01) + (grayCode & 0b10) * 8);
}
