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

#include "PointingDevice.hxx"
#include "DataGridWidget.hxx"
#include "PointingDeviceWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PointingDeviceWidget::PointingDeviceWidget(GuiObject* boss, const GUI::Font& font,
      int x, int y, Controller& controller)
  : ControllerWidget(boss, font, x, y, controller)
{
  int ypos = y;
  const int xLeft = x + 10,
            xMid = xLeft + 30,
            xRight = xLeft + 60,
            xValue = xLeft + 87;
  const StaticTextWidget* t = new StaticTextWidget(boss, font,
                                      x, y + 2, getHeader());
  ypos += t->getHeight() + 8;

  // add gray code and up widgets
  myGrayValueV = new DataGridWidget(boss, font, xMid, ypos,
                                    1, 1, 2, 8, Common::Base::Fmt::_16);
  myGrayValueV->setTarget(this);
  myGrayValueV->setEditable(false);

  ypos += myGrayValueV->getHeight() + 2;

  myGrayUp = new ButtonWidget(boss, font, xMid, ypos, 17, "+", kTBUp);
  myGrayUp->setTarget(this);

  ypos += myGrayUp->getHeight() + 5;

  // add horizontal direction and gray code widgets
  myGrayLeft = new ButtonWidget(boss, font, xLeft, ypos, 17, "-", kTBLeft);
  myGrayLeft->setTarget(this);

  myGrayRight = new ButtonWidget(boss, font, xRight, ypos, 17, "+", kTBRight);
  myGrayRight->setTarget(this);

  myGrayValueH = new DataGridWidget(boss, font, xValue, ypos + 2,
                                    1, 1, 2, 8, Common::Base::Fmt::_16);
  myGrayValueH->setTarget(this);
  myGrayValueH->setEditable(false);

  ypos += myGrayLeft->getHeight() + 5;

  // add down widget
  myGrayDown = new ButtonWidget(boss, font, xMid, ypos, 17, "-", kTBDown);
  myGrayDown->setTarget(this);

  ypos += myGrayDown->getHeight() + 8;

  myFire = new CheckboxWidget(boss, font, xLeft, ypos, "Fire", kTBFire);
  myFire->setTarget(this);

  addFocusWidget(myGrayUp);
  addFocusWidget(myGrayLeft);
  addFocusWidget(myGrayRight);
  addFocusWidget(myGrayDown);
  addFocusWidget(myFire);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PointingDeviceWidget::loadConfig()
{
  setGrayCodeH();
  setGrayCodeV();
  myFire->setState(!getPin(Controller::DigitalPin::Six));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PointingDeviceWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  // Since the PointingDevice uses its own, internal state (not reading the
  // controller), we have to communicate directly with it
  auto& pDev = static_cast<PointingDevice&>(controller());

  switch(cmd)
  {
    case kTBLeft:
      ++pDev.myCountH;
      pDev.myTrackBallLeft = false;
      setGrayCodeH();
      break;
    case kTBRight:
      --pDev.myCountH;
      pDev.myTrackBallLeft = true;
      setGrayCodeH();
      break;
    case kTBUp:
      ++pDev.myCountV;
      pDev.myTrackBallDown = true;
      setGrayCodeV();
      break;
    case kTBDown:
      --pDev.myCountV;
      pDev.myTrackBallDown = false;
      setGrayCodeV();
      break;
    case kTBFire:
      setPin(Controller::DigitalPin::Six, !myFire->getState());
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PointingDeviceWidget::setGrayCodeH()
{
  auto& pDev = static_cast<PointingDevice&>(controller());

  pDev.myCountH &= 0b11;
  setValue(myGrayValueH, pDev.myCountH, pDev.myTrackBallLeft);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PointingDeviceWidget::setGrayCodeV()
{
  auto& pDev = static_cast<PointingDevice&>(controller());

  pDev.myCountV &= 0b11;
  setValue(myGrayValueV, pDev.myCountV, !pDev.myTrackBallDown);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PointingDeviceWidget::setValue(DataGridWidget* grayValue,
                                    const int index, const int direction)
{
  const uInt8 grayCode = getGrayCodeTable(index, direction);

  // FIXME  * 8 = a nasty hack, because the DataGridWidget does not support 2 digit binary output
  grayValue->setList(0, (grayCode & 0b01) + (grayCode & 0b10) * 8);
}
