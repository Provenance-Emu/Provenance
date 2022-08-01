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

#include "JoystickWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
JoystickWidget::JoystickWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, Controller& controller,
                               bool embedded)
  : ControllerWidget(boss, font, x, y, controller)
{
  const int fontHeight = font.getFontHeight();
  int xpos = x, ypos = y;

  if(!embedded)
  {
    const string& label = getHeader();
    const int lwidth = font.getStringWidth("Right (Joystick)");
    const StaticTextWidget* t = new StaticTextWidget(boss, font, xpos, ypos + 2, lwidth,
                                        _lineHeight, label, TextAlign::Left);
    xpos += t->getWidth() / 2 - 5;  ypos = t->getBottom() + fontHeight;
  }
  myPins[kJUp] = new CheckboxWidget(boss, font, xpos, ypos, "",
                                    CheckboxWidget::kCheckActionCmd);
  myPins[kJUp]->setID(kJUp);
  myPins[kJUp]->setTarget(this);

  ypos += myPins[kJUp]->getHeight() * 2 + 10;
  myPins[kJDown] = new CheckboxWidget(boss, font, xpos, ypos, "",
                                      CheckboxWidget::kCheckActionCmd);
  myPins[kJDown]->setID(kJDown);
  myPins[kJDown]->setTarget(this);

  xpos -= myPins[kJUp]->getWidth() + 5;
  ypos -= myPins[kJUp]->getHeight() + 5;
  myPins[kJLeft] = new CheckboxWidget(boss, font, xpos, ypos, "",
                                      CheckboxWidget::kCheckActionCmd);
  myPins[kJLeft]->setID(kJLeft);
  myPins[kJLeft]->setTarget(this);

  xpos += (myPins[kJUp]->getWidth() + 5) * 2;
  myPins[kJRight] = new CheckboxWidget(boss, font, xpos, ypos, "",
                                       CheckboxWidget::kCheckActionCmd);
  myPins[kJRight]->setID(kJRight);
  myPins[kJRight]->setTarget(this);

  xpos -= (myPins[kJUp]->getWidth() + 5) * 2;
  ypos = myPins[kJDown]->getBottom() + fontHeight * 0.75;
  myPins[kJFire] = new CheckboxWidget(boss, font, xpos, ypos, "Fire",
                                      CheckboxWidget::kCheckActionCmd);
  myPins[kJFire]->setID(kJFire);
  myPins[kJFire]->setTarget(this);

  addFocusWidget(myPins[kJUp]);
  addFocusWidget(myPins[kJLeft]);
  addFocusWidget(myPins[kJRight]);
  addFocusWidget(myPins[kJDown]);
  addFocusWidget(myPins[kJFire]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoystickWidget::loadConfig()
{
  myPins[kJUp]->setState(!getPin(ourPinNo[kJUp]));
  myPins[kJDown]->setState(!getPin(ourPinNo[kJDown]));
  myPins[kJLeft]->setState(!getPin(ourPinNo[kJLeft]));
  myPins[kJRight]->setState(!getPin(ourPinNo[kJRight]));
  myPins[kJFire]->setState(!getPin(ourPinNo[kJFire]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoystickWidget::handleCommand(
    CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == CheckboxWidget::kCheckActionCmd)
    setPin(ourPinNo[id], !myPins[id]->getState());
}
