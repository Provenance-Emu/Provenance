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

#ifndef TOGGLE_PIXEL_WIDGET_HXX
#define TOGGLE_PIXEL_WIDGET_HXX

#include "ToggleWidget.hxx"

/* TogglePixelWidget */
class TogglePixelWidget : public ToggleWidget
{
  public:
    TogglePixelWidget(GuiObject* boss, const GUI::Font& font,
                      int x, int y, int cols = 1, int rows = 1,
                      int shiftBits = 0);
    ~TogglePixelWidget() override = default;

    void setColor(ColorId color) { _pixelColor = color; }
    void clearColor() { _pixelColor = kDlgColor; }
    void setBackgroundColor(ColorId color) { _backgroundColor = color; }
    void clearBackgroundColor() { _backgroundColor = kDlgColor; }

    void setState(const BoolArray& state);

    void setIntState(int value, bool swap = false);
    int  getIntState();

    void setCrossed(bool enable);

  private:
    ColorId _pixelColor{kNone}, _backgroundColor{kDlgColor};
    bool _crossBits{false};

  private:
    void drawWidget(bool hilite) override;

    // Following constructors and assignment operators not supported
    TogglePixelWidget() = delete;
    TogglePixelWidget(const TogglePixelWidget&) = delete;
    TogglePixelWidget(TogglePixelWidget&&) = delete;
    TogglePixelWidget& operator=(const TogglePixelWidget&) = delete;
    TogglePixelWidget& operator=(TogglePixelWidget&&) = delete;
};

#endif
