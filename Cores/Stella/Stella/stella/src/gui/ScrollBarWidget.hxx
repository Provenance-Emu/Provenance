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

#ifndef SCROLL_BAR_WIDGET_HXX
#define SCROLL_BAR_WIDGET_HXX

class GuiObject;

#include "Widget.hxx"
#include "Command.hxx"
#include "bspf.hxx"

class ScrollBarWidget : public Widget, public CommandSender
{
  public:
    ScrollBarWidget(GuiObject* boss, const GUI::Font& font,
                    int x, int y, int w, int h);
    ~ScrollBarWidget() override = default;

    void recalc();
    void handleMouseWheel(int x, int y, int direction) override;

    static void setWheelLines(int lines) { _WHEEL_LINES = lines; }
    static int  getWheelLines()          { return _WHEEL_LINES;  }
    static int scrollBarWidth(const GUI::Font& font)
    {
      return font.getFontHeight() < 24 ? 15 : 23;
    }

  private:
    void drawWidget(bool hilite) override;
    void checkBounds(int old_pos);

    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseMoved(int x, int y) override;
    bool handleMouseClicks(int x, int y, MouseButton b) override;
    void handleMouseLeft() override;
    void setArrows();

  public:
    int _numEntries{0};
    int _entriesPerPage{0};
    int _currentPos{0};
    int _wheel_lines{0};

  private:
    enum class Part { None, UpArrow, DownArrow, Slider, PageUp, PageDown };

    Part _part{Part::None};
    Part _draggingPart{Part::None};
    int _sliderHeight{0};
    int _sliderPos{0};
    int _sliderDeltaMouseDownPos{0};
    int _upDownWidth{0};
    int _upDownHeight{0};
    int _upDownBoxHeight{0};
    int _scrollBarWidth{0};
    const uInt32* _upImg{nullptr};
    const uInt32* _downImg{nullptr};

    static int _WHEEL_LINES;

  private:
    // Following constructors and assignment operators not supported
    ScrollBarWidget() = delete;
    ScrollBarWidget(const ScrollBarWidget&) = delete;
    ScrollBarWidget(ScrollBarWidget&&) = delete;
    ScrollBarWidget& operator=(const ScrollBarWidget&) = delete;
    ScrollBarWidget& operator=(ScrollBarWidget&&) = delete;
};

#endif
