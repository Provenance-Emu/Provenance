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

#include "Joy2BPlusWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Joy2BPlusWidget::Joy2BPlusWidget(GuiObject* boss, const GUI::Font& font,
  int x, int y, Controller& controller)
  : ControllerWidget(boss, font, x, y, controller)
{
  const string& label = isLeftPort() ? "Left (Joy 2B+)" : "Right (Joy 2B+)";

  const int fontHeight = font.getFontHeight();
  int xpos = x, ypos = y, lwidth = font.getStringWidth("Right (Joy 2B+)");
  auto* t = new StaticTextWidget(boss, font, xpos, ypos+2, lwidth,
                                 fontHeight, label, TextAlign::Left);
  xpos += t->getWidth()/2 - 5;  ypos += t->getHeight() + 10;
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
  ypos = 20 + (myPins[kJUp]->getHeight() + 10) * 3;
  myPins[kJButtonB] = new CheckboxWidget(boss, font, xpos, ypos, "Button B",
    CheckboxWidget::kCheckActionCmd);
  myPins[kJButtonB]->setID(kJButtonB);
  myPins[kJButtonB]->setTarget(this);

  ypos += myPins[kJButtonB]->getHeight() + 5;
  myPins[kJButtonC] = new CheckboxWidget(boss, font, xpos, ypos, "Button C",
    CheckboxWidget::kCheckActionCmd);
  myPins[kJButtonC]->setID(kJButtonC);
  myPins[kJButtonC]->setTarget(this);

  ypos += myPins[kJButtonC]->getHeight() + 5;
  myPins[kJButton3] = new CheckboxWidget(boss, font, xpos, ypos, "Button 3",
    CheckboxWidget::kCheckActionCmd);
  myPins[kJButton3]->setID(kJButton3);
  myPins[kJButton3]->setTarget(this);

  addFocusWidget(myPins[kJUp]);
  addFocusWidget(myPins[kJLeft]);
  addFocusWidget(myPins[kJRight]);
  addFocusWidget(myPins[kJDown]);
  addFocusWidget(myPins[kJButtonB]);
  addFocusWidget(myPins[kJButtonC]);
  addFocusWidget(myPins[kJButton3]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joy2BPlusWidget::loadConfig()
{
  myPins[kJUp]->setState(!getPin(ourPinNo[kJUp]));
  myPins[kJDown]->setState(!getPin(ourPinNo[kJDown]));
  myPins[kJLeft]->setState(!getPin(ourPinNo[kJLeft]));
  myPins[kJRight]->setState(!getPin(ourPinNo[kJRight]));
  myPins[kJButtonB]->setState(!getPin(ourPinNo[kJButtonB]));

  myPins[kJButton3]->setState(
    getPin(Controller::AnalogPin::Five) == AnalogReadout::connectToGround());
  myPins[kJButtonC]->setState(
    getPin(Controller::AnalogPin::Nine) == AnalogReadout::connectToGround());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joy2BPlusWidget::handleCommand(
    CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == CheckboxWidget::kCheckActionCmd)
  {
    switch(id)
    {
      case kJUp:
      case kJDown:
      case kJLeft:
      case kJRight:
      case kJButtonB:
        setPin(ourPinNo[id], !myPins[id]->getState());
        break;
      case kJButtonC:
        setPin(Controller::AnalogPin::Nine,
          myPins[id]->getState() ? AnalogReadout::connectToGround()
                                 : AnalogReadout::connectToVcc());
        break;
      case kJButton3:
        setPin(Controller::AnalogPin::Five,
          myPins[id]->getState() ? AnalogReadout::connectToGround()
                                 : AnalogReadout::connectToVcc());
        break;
      default:
        break;
    }
  }
}
