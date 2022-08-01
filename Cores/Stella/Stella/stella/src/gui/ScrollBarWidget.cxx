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

#include "OSystem.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "ScrollBarWidget.hxx"
#include "bspf.hxx"

/*
 * TODO:
 * - Allow for a horizontal scrollbar, too?
 * - If there are less items than fit on one pages, no scrolling can be done
 *   and we thus should not highlight the arrows/slider.
 */

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ScrollBarWidget::ScrollBarWidget(GuiObject* boss, const GUI::Font& font,
                                 int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h), CommandSender(boss)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_TRACK_MOUSE | Widget::FLAG_CLEARBG;
  _bgcolor = kWidColor;
  _bgcolorhi = kWidColor;

  _scrollBarWidth = scrollBarWidth(font);

  setArrows();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::setArrows()
{
  // Small up arrow
  static constexpr std::array<uInt32, 6> up_arrow = {
    0b0001000,
    0b0011100,
    0b0111110,
    0b1110111,
    0b1100011,
    0b1000001,
  };
  // Small down arrow
  static constexpr std::array<uInt32, 6> down_arrow = {
    0b1000001,
    0b1100011,
    0b1110111,
    0b0111110,
    0b0011100,
    0b0001000
  };

  // Large up arrow
  static constexpr std::array<uInt32, 9> up_arrow_large = {
    0b00000100000,
    0b00001110000,
    0b00011111000,
    0b00111111100,
    0b01111011110,
    0b11110001111,
    0b11100000111,
    0b11000000011,
    0b10000000001,
  };
  // Large down arrow
  static constexpr std::array<uInt32, 9> down_arrow_large = {
    0b10000000001,
    0b11000000011,
    0b11100000111,
    0b11110001111,
    0b01111011110,
    0b00111111100,
    0b00011111000,
    0b00001110000,
    0b00000100000
  };


  if(_font.getFontHeight() < 24)
  {
    _upDownWidth = 7;
    _upDownHeight = 6;
    _upDownBoxHeight = 18;
    _upImg = up_arrow.data();
    _downImg = down_arrow.data();
  }
  else
  {
    _upDownWidth = 11;
    _upDownHeight = 9;
    _upDownBoxHeight = 27;
    _upImg = up_arrow_large.data();
    _downImg = down_arrow_large.data();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::handleMouseDown(int x, int y, MouseButton b,
                                      int clickCount)
{
  // Ignore subsequent mouse clicks when the slider is being moved
  if(_draggingPart == Part::Slider)
    return;

  const int old_pos = _currentPos;

  // Do nothing if there are less items than fit on one page
  if(_numEntries <= _entriesPerPage)
    return;

  if (y <= _upDownBoxHeight)
  {
    // Up arrow
    _currentPos--;
    _draggingPart = Part::UpArrow;
  }
  else if(y >= _h - _upDownBoxHeight)
  {
    // Down arrow
    _currentPos++;
    _draggingPart = Part::DownArrow;
  }
  else if(y < _sliderPos)
  {
    _currentPos -= _entriesPerPage - 1;
  }
  else if(y >= _sliderPos + _sliderHeight)
  {
    _currentPos += _entriesPerPage - 1;
  }
  else
  {
    _draggingPart = Part::Slider;
    _sliderDeltaMouseDownPos = y - _sliderPos;
  }

  // Make sure that _currentPos is still inside the bounds
  checkBounds(old_pos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::handleMouseUp(int x, int y, MouseButton b,
                                    int clickCount)
{
  _draggingPart = Part::None;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::handleMouseWheel(int x, int y, int direction)
{
  const int old_pos = _currentPos;

  if(_numEntries < _entriesPerPage)
    return;

  if(direction < 0)
    _currentPos -= _wheel_lines ? _wheel_lines : _WHEEL_LINES;
  else
    _currentPos += _wheel_lines ? _wheel_lines : _WHEEL_LINES;

  // Make sure that _currentPos is still inside the bounds
  checkBounds(old_pos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::handleMouseMoved(int x, int y)
{
  // Do nothing if there are less items than fit on one page
  if(_numEntries <= _entriesPerPage)
    return;

  if(_draggingPart == Part::Slider)
  {
    const int old_pos = _currentPos;
    _sliderPos = y - _sliderDeltaMouseDownPos;

    if(_sliderPos < _upDownBoxHeight)
      _sliderPos = _upDownBoxHeight;

    if(_sliderPos > _h - _upDownBoxHeight - _sliderHeight)
      _sliderPos = _h - _upDownBoxHeight - _sliderHeight;

    _currentPos = (_sliderPos - _upDownBoxHeight) * (_numEntries - _entriesPerPage) /
                  (_h - 2 * _upDownBoxHeight - _sliderHeight);
    checkBounds(old_pos);
  }
  else
  {
    const Part old_part = _part;

    if(y <= _upDownBoxHeight)   // Up arrow
      _part = Part::UpArrow;
    else if(y >= _h - _upDownBoxHeight)	// Down arrow
      _part = Part::DownArrow;
    else if(y < _sliderPos)
      _part = Part::PageUp;
    else if(y >= _sliderPos + _sliderHeight)
      _part = Part::PageDown;
    else
      _part = Part::Slider;

    if (old_part != _part)
      setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ScrollBarWidget::handleMouseClicks(int x, int y, MouseButton b)
{
  // Let continuous mouse clicks come through, as the scroll buttons need them
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::checkBounds(int old_pos)
{
  if(_numEntries <= _entriesPerPage || _currentPos < 0)
    _currentPos = 0;
  else if(_currentPos > _numEntries - _entriesPerPage)
    _currentPos = _numEntries - _entriesPerPage;

  if (old_pos != _currentPos)
  {
    recalc();
    setDirty();
    sendCommand(GuiObject::kSetPositionCmd, _currentPos, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::handleMouseLeft()
{
  _part = Part::None;
  Widget::handleMouseLeft();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::recalc()
{
//cerr << "ScrollBarWidget::recalc()\n";
  const int oldSliderHeight = _sliderHeight,
            oldSliderPos = _sliderPos;

  if(_numEntries > _entriesPerPage)
  {
    _sliderHeight = (_h - 2 * _upDownBoxHeight) * _entriesPerPage / _numEntries;
    if(_sliderHeight < _upDownBoxHeight)
      _sliderHeight = _upDownBoxHeight;

    _sliderPos = _upDownBoxHeight + (_h - 2 * _upDownBoxHeight - _sliderHeight) *
                 _currentPos / (_numEntries - _entriesPerPage);
    if(_sliderPos < 0)
      _sliderPos = 0;
  }
  else
  {
    _sliderHeight = _h - 2 * _upDownBoxHeight;
    _sliderPos = _upDownBoxHeight;
  }

  if(oldSliderHeight != _sliderHeight || oldSliderPos != _sliderPos)
    setDirty(); // only set dirty when something changed
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ScrollBarWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();
  const int bottomY = _y + _h;
  const bool isSinglePage = (_numEntries <= _entriesPerPage);

  s.frameRect(_x, _y, _w, _h, hilite ? kWidColorHi : kColor);

  if(_draggingPart != Part::None)
    _part = _draggingPart;

  // Up arrow
  if(hilite && _part == Part::UpArrow)
    s.fillRect(_x + 1, _y + 1, _w - 2, _upDownBoxHeight - 2, kScrollColor);
  s.drawBitmap(_upImg, _x + (_scrollBarWidth - _upDownWidth) / 2,
               _y + (_upDownBoxHeight - _upDownHeight) / 2,
               isSinglePage ? kColor
                            : (hilite && _part == Part::UpArrow) ? kWidColor : kTextColor,
               _upDownWidth, _upDownHeight);

  // Down arrow
  if(hilite && _part == Part::DownArrow)
    s.fillRect(_x + 1, bottomY - _upDownBoxHeight + 1, _w - 2, _upDownBoxHeight - 2, kScrollColor);
  s.drawBitmap(_downImg, _x + (_scrollBarWidth - _upDownWidth) / 2,
               bottomY - _upDownBoxHeight + (_upDownBoxHeight - _upDownHeight) / 2,
               isSinglePage ? kColor
                            : (hilite && _part == Part::DownArrow) ? kWidColor : kTextColor,
               _upDownWidth, _upDownHeight);

  // Slider
  if(!isSinglePage)
  {
    // align slider to scroll intervals
    int alignedPos = _upDownBoxHeight + (_h - 2 * _upDownBoxHeight - _sliderHeight) *
      _currentPos / (_numEntries - _entriesPerPage);
    if(alignedPos < 0)
      alignedPos = 0;

    s.fillRect(_x + 1, _y + alignedPos - 1, _w - 2, _sliderHeight + 2,
              (hilite && _part == Part::Slider) ? kScrollColorHi : kScrollColor);
  }
  clearDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int ScrollBarWidget::_WHEEL_LINES = 4;
