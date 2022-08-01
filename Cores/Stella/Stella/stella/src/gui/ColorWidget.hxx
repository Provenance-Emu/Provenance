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

#ifndef COLOR_WIDGET_HXX
#define COLOR_WIDGET_HXX

class ColorDialog;
class GuiObject;

#include "Widget.hxx"
#include "Command.hxx"

/**
  Displays a color from the TIA palette.  This class will eventually
  be expanded with a TIA palette table, to set the color visually.

  @author  Stephen Anthony
*/
class ColorWidget : public Widget, public CommandSender
{
  friend class ColorDialog;

  public:
    ColorWidget(GuiObject* boss, const GUI::Font& font,
                int x, int y, int w, int h, int cmd = 0, bool framed = true);
    ~ColorWidget() override = default;

    void setColor(ColorId color);
    ColorId getColor() const { return _color;  }

    void setCrossed(bool enable);

  protected:
    void handleMouseEntered() override { }
    void handleMouseLeft() override { }
    void drawWidget(bool hilite) override;

  protected:
    ColorId _color{kNone};
    bool _framed{true};
    int	_cmd{0};

    bool _crossGrid{false};

  private:
    // Following constructors and assignment operators not supported
    ColorWidget() = delete;
    ColorWidget(const ColorWidget&) = delete;
    ColorWidget(ColorWidget&&) = delete;
    ColorWidget& operator=(const ColorWidget&) = delete;
    ColorWidget& operator=(ColorWidget&&) = delete;
};

#endif
