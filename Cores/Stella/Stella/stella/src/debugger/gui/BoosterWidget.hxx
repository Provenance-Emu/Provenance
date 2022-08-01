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

#ifndef BOOSTER_WIDGET_HXX
#define BOOSTER_WIDGET_HXX

#include "Control.hxx"
#include "ControllerWidget.hxx"

class BoosterWidget : public ControllerWidget
{
  public:
    BoosterWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                   Controller& controller);
    ~BoosterWidget() override = default;

  private:
    enum { kJUp = 0, kJDown, kJLeft, kJRight, kJFire, kJBooster, kJTrigger };

    std::array<CheckboxWidget*, 7> myPins{nullptr};
    static constexpr std::array<Controller::DigitalPin, 5> ourPinNo = {{
      Controller::DigitalPin::One, Controller::DigitalPin::Two,
      Controller::DigitalPin::Three, Controller::DigitalPin::Four,
      Controller::DigitalPin::Six
    }};

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    // Following constructors and assignment operators not supported
    BoosterWidget() = delete;
    BoosterWidget(const BoosterWidget&) = delete;
    BoosterWidget(BoosterWidget&&) = delete;
    BoosterWidget& operator=(const BoosterWidget&) = delete;
    BoosterWidget& operator=(BoosterWidget&&) = delete;
};

#endif
