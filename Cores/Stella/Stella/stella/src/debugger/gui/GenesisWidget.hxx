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

#ifndef GENESIS_WIDGET_HXX
#define GENESIS_WIDGET_HXX

#include "Control.hxx"
#include "ControllerWidget.hxx"

class GenesisWidget : public ControllerWidget
{
  public:
    GenesisWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                  Controller& controller);
    ~GenesisWidget() override = default;

  private:
    enum { kJUp = 0, kJDown, kJLeft, kJRight, kJBbtn, kJCbtn };

    std::array<CheckboxWidget*, 6> myPins{nullptr};
    static constexpr std::array<Controller::DigitalPin, 5> ourPinNo = {{
      Controller::DigitalPin::One, Controller::DigitalPin::Two,
      Controller::DigitalPin::Three, Controller::DigitalPin::Four,
      Controller::DigitalPin::Six
    }};

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    // Following constructors and assignment operators not supported
    GenesisWidget() = delete;
    GenesisWidget(const GenesisWidget&) = delete;
    GenesisWidget(GenesisWidget&&) = delete;
    GenesisWidget& operator=(const GenesisWidget&) = delete;
    GenesisWidget& operator=(GenesisWidget&&) = delete;
};

#endif
