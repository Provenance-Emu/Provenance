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

#include "GenesisWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GenesisWidget::GenesisWidget(GuiObject* boss, const GUI::Font& font,
                             int x, int y, Controller& controller)
  : ControllerWidget(boss, font, x, y, controller)
{
  const string& label = getHeader();

  const int fontHeight = font.getFontHeight();
  int xpos = x, ypos = y, lwidth = font.getStringWidth("Right (Genesis)");

  const StaticTextWidget* t = new StaticTextWidget(boss, font, xpos, ypos+2, lwidth,
                                      fontHeight, label, TextAlign::Left);
  xpos += t->getWidth()/2 - 5;  ypos += t->getHeight() + 20;
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
  ypos = 30 + (myPins[kJUp]->getHeight() + 10) * 3;
  myPins[kJBbtn] = new CheckboxWidget(boss, font, xpos, ypos, "B button",
                                      CheckboxWidget::kCheckActionCmd);
  myPins[kJBbtn]->setID(kJBbtn);
  myPins[kJBbtn]->setTarget(this);

  ypos += myPins[kJBbtn]->getHeight() + 5;
  myPins[kJCbtn] = new CheckboxWidget(boss, font, xpos, ypos, "C button",
                                      CheckboxWidget::kCheckActionCmd);
  myPins[kJCbtn]->setID(kJCbtn);
  myPins[kJCbtn]->setTarget(this);

  addFocusWidget(myPins[kJUp]);
  addFocusWidget(myPins[kJLeft]);
  addFocusWidget(myPins[kJRight]);
  addFocusWidget(myPins[kJDown]);
  addFocusWidget(myPins[kJBbtn]);
  addFocusWidget(myPins[kJCbtn]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void GenesisWidget::loadConfig()
{
  myPins[kJUp]->setState(!getPin(ourPinNo[kJUp]));
  myPins[kJDown]->setState(!getPin(ourPinNo[kJDown]));
  myPins[kJLeft]->setState(!getPin(ourPinNo[kJLeft]));
  myPins[kJRight]->setState(!getPin(ourPinNo[kJRight]));
  myPins[kJBbtn]->setState(!getPin(ourPinNo[kJBbtn]));

  myPins[kJCbtn]->setState(
    getPin(Controller::AnalogPin::Five) == AnalogReadout::connectToGround());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void GenesisWidget::handleCommand(
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
      case kJBbtn:
        setPin(ourPinNo[id], !myPins[id]->getState());
        break;
      case kJCbtn:
        setPin(Controller::AnalogPin::Five,
          myPins[id]->getState() ? AnalogReadout::connectToGround() :
                                   AnalogReadout::connectToVcc());
        break;
      default:
        break;
    }
  }
}
