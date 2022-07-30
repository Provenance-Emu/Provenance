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

#include "EventHandler.hxx"
#include "KeyboardWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyboardWidget::KeyboardWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, Controller& controller)
  : ControllerWidget(boss, font, x, y, controller)
{
  const bool leftport = isLeftPort();
  const string& label = leftport ? "Left (Keyboard)" : "Right (Keyboard)";

  const int fontHeight = font.getFontHeight();
  int xpos = x, ypos = y, lwidth = font.getStringWidth("Right (Keyboard)");
  const StaticTextWidget* t = new StaticTextWidget(boss, font, xpos, ypos+2, lwidth,
                                      fontHeight, label, TextAlign::Left);

  xpos += 30;  ypos += t->getHeight() + 20;

  for(int i = 0; i < 12; ++i)
  {
    myBox[i] = new CheckboxWidget(boss, font, xpos, ypos, "",
                                  CheckboxWidget::kCheckActionCmd);
    myBox[i]->setID(i);
    myBox[i]->setTarget(this);
    xpos += myBox[i]->getWidth() + 5;
    if((i+1) % 3 == 0)
    {
      xpos = x + 30;
      ypos += myBox[i]->getHeight() + 5;
    }
    addFocusWidget(myBox[i]);
  }
  myEvent = leftport ? ourLeftEvents.data() : ourRightEvents.data();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KeyboardWidget::loadConfig()
{
  const Event& event = instance().eventHandler().event();
  for(int i = 0; i < 12; ++i)
    myBox[i]->setState(event.get(myEvent[i]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KeyboardWidget::handleCommand(
    CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == CheckboxWidget::kCheckActionCmd)
    instance().eventHandler().handleEvent(myEvent[id], myBox[id]->getState());
}
