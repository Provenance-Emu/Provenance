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

#include "OSystem.hxx"
#include "Console.hxx"
#include "TIA.hxx"
#include "QuadTari.hxx"
#include "AtariVoxWidget.hxx"
#include "DrivingWidget.hxx"
#include "JoystickWidget.hxx"
#include "NullControlWidget.hxx"
#include "PaddleWidget.hxx"
#include "SaveKeyWidget.hxx"

#include "QuadTariWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
QuadTariWidget::QuadTariWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, Controller& controller)
  : ControllerWidget(boss, font, x, y, controller)
{
  const string label = (isLeftPort() ? "Left" : "Right") + string(" (QuadTari)");
  const StaticTextWidget* t = new StaticTextWidget(boss, font, x, y + 2, label);
  const QuadTari& qt = static_cast<QuadTari&>(controller);

  y = t->getBottom() + _lineHeight;
  addController(boss, x, y, *qt.myFirstController, false);
  addController(boss, x, y, *qt.mySecondController, true);

  myPointer = new StaticTextWidget(boss, font,
                                   t->getLeft() + _fontWidth * 7, y, "  ");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariWidget::addController(GuiObject* boss, int x, int y,
                                   Controller& controller, bool second)
{
  ControllerWidget* widget = nullptr;

  x += second ? _fontWidth * 10 : 0;
  switch(controller.type())
  {
    case Controller::Type::Joystick:
      x += _fontWidth * 2;
      widget = new JoystickWidget(boss, _font, x, y, controller, true);
      break;

    case Controller::Type::Driving:
      widget = new DrivingWidget(boss, _font, x, y, controller, true);
      break;

    case Controller::Type::Paddles:
      widget = new PaddleWidget(boss, _font, x, y, controller, true, second);
      break;

    case Controller::Type::AtariVox:
      widget = new AtariVoxWidget(boss, _font, x, y, controller, true);
      break;

    case Controller::Type::SaveKey:
      widget = new SaveKeyWidget(boss, _font, x, y, controller, true);
      break;

    default:
      widget = new NullControlWidget(boss, _font, x, y, controller, true);
      break;
  }
  const WidgetArray focusList = widget->getFocusList();
  if(!focusList.empty())
    addToFocusList(focusList);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariWidget::loadConfig()
{
  const bool first = !(instance().console().tia().registerValue(VBLANK) & 0x80);

  myPointer->setLabel(first ? "<-" : "->");
}
