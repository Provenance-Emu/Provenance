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

#include "Paddles.hxx"
#include "PaddleWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PaddleWidget::PaddleWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                           Controller& controller, bool embedded, bool second)
  : ControllerWidget(boss, font, x, y, controller)
{
  const bool leftport = isLeftPort();
  const string& label = getHeader();
  const int fontHeight = font.getFontHeight();

  int xpos = x, ypos = y,
    lwidth = font.getStringWidth("Right (Paddles)");

  if(!embedded)
  {
    new StaticTextWidget(boss, font, xpos, ypos + 2, lwidth,
                         _lineHeight, label);
    ypos += _lineHeight + fontHeight + 2;

    const string& p0string = leftport ? "P1 pot " : "P3 pot ";
    const string& p1string = leftport ? "P2 pot " : "P4 pot ";
    myP0Resistance =
      new SliderWidget(boss, font, xpos, ypos,
                       p0string, 0, kP0Changed);

    xpos += 20;  ypos += myP0Resistance->getHeight() * 1.33;
    myP0Fire = new CheckboxWidget(boss, font, xpos, ypos,
                                  "Fire", kP0Fire);

    xpos = x;  ypos += _lineHeight * 2.25;
    myP1Resistance =
      new SliderWidget(boss, font, xpos, ypos,
                       p1string, 0, kP1Changed);

    xpos += 20;  ypos += myP1Resistance->getHeight() * 1.33;
    myP1Fire = new CheckboxWidget(boss, font, xpos, ypos,
                                  "Fire", kP1Fire);
  }
  else
  {
    const string& p0string = leftport ? second ? "P1b" : "P1a"
                                      : second ? "P3b" : "P3a";
    const string& p1string = leftport ? second ? "P2b" : "P2a"
                                      : second ? "P4b" : "P4a";

    new StaticTextWidget(boss, font, xpos, ypos + 2, p0string);

    //ypos += lineHeight;
    myP0Resistance = new SliderWidget(boss, font, xpos, ypos);
    myP0Resistance->setEnabled(false);
    myP0Resistance->setFlags(Widget::FLAG_INVISIBLE);

    ypos += _lineHeight * 1.33;
    myP0Fire = new CheckboxWidget(boss, font, xpos, ypos,
                                  "Fire", kP0Fire);

    xpos = x;  ypos += _lineHeight * 2.25;
    new StaticTextWidget(boss, font, xpos, ypos + 2, p1string);

    //ypos += lineHeight;
    myP1Resistance = new SliderWidget(boss, font, xpos, ypos);
    myP1Resistance->setEnabled(false);
    myP1Resistance->setFlags(Widget::FLAG_INVISIBLE);

    ypos += _lineHeight * 1.33;
    myP1Fire = new CheckboxWidget(boss, font, xpos, ypos,
                                  "Fire", kP1Fire);
  }
  myP0Resistance->setMinValue(0);
  myP0Resistance->setMaxValue(uInt32{Paddles::MAX_RESISTANCE});
  myP0Resistance->setStepValue(uInt32{Paddles::MAX_RESISTANCE / 100});
  myP0Resistance->setTarget(this);

  myP0Fire->setTarget(this);

  myP1Resistance->setMinValue(0);
  myP1Resistance->setMaxValue(uInt32{Paddles::MAX_RESISTANCE});
  myP1Resistance->setStepValue(uInt32{Paddles::MAX_RESISTANCE / 100});
  myP1Resistance->setTarget(this);

  myP1Fire->setTarget(this);

  addFocusWidget(myP0Resistance);
  addFocusWidget(myP0Fire);
  addFocusWidget(myP1Resistance);
  addFocusWidget(myP1Fire);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaddleWidget::loadConfig()
{
  myP0Resistance->setValue(static_cast<Int32>(Paddles::MAX_RESISTANCE -
      getPin(Controller::AnalogPin::Nine).resistance));
  myP1Resistance->setValue(static_cast<Int32>(Paddles::MAX_RESISTANCE -
      getPin(Controller::AnalogPin::Five).resistance));
  myP0Fire->setState(!getPin(Controller::DigitalPin::Four));
  myP1Fire->setState(!getPin(Controller::DigitalPin::Three));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PaddleWidget::handleCommand(
    CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case kP0Changed:
      setPin(Controller::AnalogPin::Nine,
             AnalogReadout::connectToVcc(Paddles::MAX_RESISTANCE - myP0Resistance->getValue()));
      break;
    case kP1Changed:
      setPin(Controller::AnalogPin::Five,
             AnalogReadout::connectToVcc(Paddles::MAX_RESISTANCE - myP1Resistance->getValue()));
      break;
    case kP0Fire:
      setPin(Controller::DigitalPin::Four, !myP0Fire->getState());
      break;
    case kP1Fire:
      setPin(Controller::DigitalPin::Three, !myP1Fire->getState());
      break;
    default:
      break;
  }
}
