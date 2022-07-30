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

#ifndef TOGGLE_BIT_WIDGET_HXX
#define TOGGLE_BIT_WIDGET_HXX

#include "ToggleWidget.hxx"

/* ToggleBitWidget */
class ToggleBitWidget : public ToggleWidget
{
  public:
    ToggleBitWidget(GuiObject* boss, const GUI::Font& font,
                    int x, int y, int cols, int rows, int colchars = 1);
    ToggleBitWidget(GuiObject* boss, const GUI::Font& font,
                    int x, int y, int cols, int rows, int colchars,
                    const StringList& labels);
    ~ToggleBitWidget() override = default;

    void setList(const StringList& off, const StringList& on);
    void setState(const BoolArray& state, const BoolArray& changed);

    string getToolTip(const Common::Point& pos) const override;

  protected:
    void drawWidget(bool hilite) override;

  protected:
    StringList _offList;
    StringList _onList;
    StringList _labelList;

  private:
    // Following constructors and assignment operators not supported
    ToggleBitWidget() = delete;
    ToggleBitWidget(const ToggleBitWidget&) = delete;
    ToggleBitWidget(ToggleBitWidget&&) = delete;
    ToggleBitWidget& operator=(const ToggleBitWidget&) = delete;
    ToggleBitWidget& operator=(ToggleBitWidget&&) = delete;
};

#endif
