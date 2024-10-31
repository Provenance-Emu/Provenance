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

#include "bspf.hxx"
#include "Dialog.hxx"
#include "Font.hxx"
#include "FBSurface.hxx"
#include "GuiObject.hxx"

#include "TimeLineWidget.hxx"

static constexpr int HANDLE_W = 3;
static constexpr int HANDLE_H = 3; // size above/below the slider

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimeLineWidget::TimeLineWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int w, int h,
                               string_view label, uInt32 labelWidth, int cmd)
  : ButtonWidget(boss, font, x, y, w, h, label, cmd),
    _labelWidth{labelWidth}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_TRACK_MOUSE
    | Widget::FLAG_CLEARBG | Widget::FLAG_NOBG;

  _bgcolor = kDlgColor;
  _bgcolorhi = kDlgColor;

  if(!_label.empty() && _labelWidth == 0)
    _labelWidth = _font.getStringWidth(_label);

  _w = w + _labelWidth;

  _stepValue.reserve(100);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::setValue(int value)
{
  const uInt32 v = BSPF::clamp(static_cast<uInt32>(value), _valueMin, _valueMax);

  if(v != _value)
  {
    _value = v;
    setDirty();
    sendCommand(_cmd, _value, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::setMinValue(uInt32 value)
{
  _valueMin = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::setMaxValue(uInt32 value)
{
  _valueMax = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::setStepValues(const IntArray& steps)
{
  _stepValue.clear();

  // If no steps are defined, just use the maximum value
  if(!steps.empty())
  {
    // Try to allocate as infrequently as possible
    if(steps.size() > _stepValue.capacity())
      _stepValue.reserve(2 * steps.size());

    const double scale = (_w - _labelWidth - 2 - HANDLE_W) / static_cast<double>(steps.back());

    // Skip the very last value; we take care of it outside the end of the loop
    for(uInt32 i = 0; i < steps.size() - 1; ++i)
      _stepValue.push_back(static_cast<int>(steps[i] * scale));

    // Due to integer <-> double conversion, the last value is sometimes
    // slightly less than the maximum value; we assign it manually to fix this
    _stepValue.push_back(_w - _labelWidth - 2 - HANDLE_W);
  }
  else
    _stepValue.push_back(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::handleMouseMoved(int x, int y)
{
  if(isEnabled() && _isDragging && x >= static_cast<int>(_labelWidth))
    setValue(posToValue(x - _labelWidth));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && b == MouseButton::LEFT)
  {
    _isDragging = true;
    handleMouseMoved(x, y);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && _isDragging)
    sendCommand(_cmd, _value, _id);

  _isDragging = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::handleMouseWheel(int x, int y, int direction)
{
  if(isEnabled())
  {
    if(direction < 0 && _value < _valueMax)
      setValue(_value + 1);
    else if(direction > 0 && _value > _valueMin)
      setValue(_value - 1);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeLineWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();

  // Draw the label, if any
  if(_labelWidth > 0)
    s.drawString(_font, _label, _x, _y + 2, _labelWidth,
                 isEnabled() ? kTextColor : kColor, TextAlign::Left);

  // Frame the handle
  constexpr int HANDLE_W2 = (HANDLE_W + 1) / 2;
  const int p = valueToPos(_value),
            x = _x + _labelWidth + HANDLE_W2,
            w = _w - _labelWidth - HANDLE_W;
  s.hLine(x + p - HANDLE_W2, _y + 0, x + p - HANDLE_W2 + HANDLE_W, kColorInfo);
  s.vLine(x + p - HANDLE_W2, _y + 1, _y + _h - 2, kColorInfo);
  s.hLine(x + p - HANDLE_W2 + 1, _y + _h - 1, x + p - HANDLE_W2 + 1 + HANDLE_W, kBGColor);
  s.vLine(x + p - HANDLE_W2 + 1 + HANDLE_W, _y + 1, _y + _h - 2, kBGColor);
  // Frame the box
  s.hLine(x, _y + HANDLE_H, x + w - 2, kColorInfo);
  s.vLine(x, _y + HANDLE_H, _y + _h - 2 - HANDLE_H, kColorInfo);
  s.hLine(x + 1, _y + _h - 1 - HANDLE_H, x + w - 1, kBGColor);
  s.vLine(x + w - 1, _y + 1 + HANDLE_H, _y + _h - 2 - HANDLE_H, kBGColor);

  // Fill the box
  s.fillRect(x + 1, _y + 1 + HANDLE_H, w - 2, _h - 2 - HANDLE_H * 2,
             !isEnabled() ? kSliderBGColorLo : hilite ? kSliderBGColorHi : kSliderBGColor);
  // Draw the 'bar'
  s.fillRect(x + 1, _y + 1 + HANDLE_H, p, _h - 2 - HANDLE_H * 2,
             !isEnabled() ? kColor : hilite ? kSliderColorHi : kSliderColor);

  // Add 4 tickmarks for 5 intervals
  const int numTicks = std::min(5, static_cast<int>(_stepValue.size()));
  for(int i = 1; i < numTicks; ++i)
  {
    const int idx = static_cast<int>((_stepValue.size() * i + numTicks / 2) / numTicks);
    if(idx > 1)
    {
      const int xt = x + valueToPos(idx - 1);
      ColorId color = kNone;

      if(isEnabled())
      {
        if(xt > x + p)
          color = hilite ? kSliderColorHi : kSliderColor;
        else
          color = hilite ? kSliderBGColorHi : kSliderBGColor;
      }
      else
      {
        if(xt > x + p)
          color = kColor;
        else
          color = kSliderBGColorLo;
      }
      s.vLine(xt, _y + _h / 2, _y + _h - 2 - HANDLE_H, color);
    }
  }
  // Draw the handle
  s.fillRect(x + p + 1 - HANDLE_W2, _y + 1, HANDLE_W, _h - 2,
             !isEnabled() ? kColor : hilite ? kSliderColorHi : kSliderColor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 TimeLineWidget::valueToPos(uInt32 value) const
{
  return _stepValue[BSPF::clamp(value, _valueMin, _valueMax)];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 TimeLineWidget::posToValue(uInt32 pos) const
{
  // Find the interval in which 'pos' falls, and then the endpoint which
  // it is closest to
  for(uInt32 i = 0; i < _stepValue.size() - 1; ++i)
    if(pos >= _stepValue[i] && pos <= _stepValue[i+1])
      return (_stepValue[i+1] - pos) < (pos - _stepValue[i]) ? i+1 : i;

  return _valueMax;
}
