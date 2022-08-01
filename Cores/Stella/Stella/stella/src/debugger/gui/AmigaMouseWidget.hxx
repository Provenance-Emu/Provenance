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

#ifndef AMIGAMOUSE_WIDGET_HXX
#define AMIGAMOUSE_WIDGET_HXX

class Controller;

#include "PointingDeviceWidget.hxx"

class AmigaMouseWidget : public PointingDeviceWidget
{
  public:
    AmigaMouseWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                     Controller& controller);

    ~AmigaMouseWidget() override = default;

  private:
    const std::array<uInt8, 4> myGrayCodeTable = { 0b00, 0b10, 0b11, 0b01 };

    uInt8 getGrayCodeTable(const int index, const int direction) const override;

    // Following constructors and assignment operators not supported
    AmigaMouseWidget() = delete;
    AmigaMouseWidget(const AmigaMouseWidget&) = delete;
    AmigaMouseWidget(AmigaMouseWidget&&) = delete;
    AmigaMouseWidget& operator=(const AmigaMouseWidget&) = delete;
    AmigaMouseWidget& operator=(AmigaMouseWidget&&) = delete;
};

#endif
