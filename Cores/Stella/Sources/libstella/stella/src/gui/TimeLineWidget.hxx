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

#ifndef TIMELINE_WIDGET_HXX
#define TIMELINE_WIDGET_HXX

#include "Widget.hxx"

class TimeLineWidget : public ButtonWidget
{
  public:
    TimeLineWidget(GuiObject* boss, const GUI::Font& font,
                   int x, int y, int w, int h, string_view label = "",
                   uInt32 labelWidth = 0, int cmd = 0);

    void setValue(int value) override;
    uInt32 getValue() const { return _value; }

    void setMinValue(uInt32 value);
    void setMaxValue(uInt32 value);
    uInt32 getMinValue() const { return _valueMin; }
    uInt32 getMaxValue() const { return _valueMax; }

    /**
      Steps are not necessarily linear in a timeline, so we need info
      on each interval instead.
    */
    void setStepValues(const IntArray& steps);

  protected:
    void handleMouseMoved(int x, int y) override;
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseWheel(int x, int y, int direction) override;

    void drawWidget(bool hilite) override;

    uInt32 valueToPos(uInt32 value) const;
    uInt32 posToValue(uInt32 pos) const;

  protected:
    uInt32  _value{0};
    uInt32  _valueMin{0}, _valueMax{0};
    bool    _isDragging{false};
    uInt32  _labelWidth{0};

    uIntArray _stepValue;

  private:
    // Following constructors and assignment operators not supported
    TimeLineWidget() = delete;
    TimeLineWidget(const TimeLineWidget&) = delete;
    TimeLineWidget(TimeLineWidget&&) = delete;
    TimeLineWidget& operator=(const TimeLineWidget&) = delete;
    TimeLineWidget& operator=(TimeLineWidget&&) = delete;
};

#endif
