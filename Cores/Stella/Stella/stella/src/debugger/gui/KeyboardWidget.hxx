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

#ifndef KEYBOARD_WIDGET_HXX
#define KEYBOARD_WIDGET_HXX

#include "Event.hxx"
#include "ControllerWidget.hxx"

class KeyboardWidget : public ControllerWidget
{
  public:
    KeyboardWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                   Controller& controller);
    ~KeyboardWidget() override = default;

  private:
    std::array<CheckboxWidget*, 12> myBox{nullptr};
    const Event::Type* myEvent{nullptr};

    static constexpr std::array<Event::Type, 12> ourLeftEvents = {{
      Event::LeftKeyboard1,    Event::LeftKeyboard2,  Event::LeftKeyboard3,
      Event::LeftKeyboard4,    Event::LeftKeyboard5,  Event::LeftKeyboard6,
      Event::LeftKeyboard7,    Event::LeftKeyboard8,  Event::LeftKeyboard9,
      Event::LeftKeyboardStar, Event::LeftKeyboard0,  Event::LeftKeyboardPound
    }};
    static constexpr std::array<Event::Type, 12> ourRightEvents = {{
      Event::RightKeyboard1,    Event::RightKeyboard2,  Event::RightKeyboard3,
      Event::RightKeyboard4,    Event::RightKeyboard5,  Event::RightKeyboard6,
      Event::RightKeyboard7,    Event::RightKeyboard8,  Event::RightKeyboard9,
      Event::RightKeyboardStar, Event::RightKeyboard0,  Event::RightKeyboardPound
    }};

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    // Following constructors and assignment operators not supported
    KeyboardWidget() = delete;
    KeyboardWidget(const KeyboardWidget&) = delete;
    KeyboardWidget(KeyboardWidget&&) = delete;
    KeyboardWidget& operator=(const KeyboardWidget&) = delete;
    KeyboardWidget& operator=(KeyboardWidget&&) = delete;
};

#endif
