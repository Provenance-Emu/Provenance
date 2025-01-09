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

#include "Widget.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "ToggleBitWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ToggleBitWidget::ToggleBitWidget(GuiObject* boss, const GUI::Font& font,
                                 int x, int y, int cols, int rows, int colchars,
                                 const StringList& labels)
  : ToggleWidget(boss, font, x, y, cols, rows),
    _labelList{labels}
{
  _rowHeight = font.getLineHeight();
  _colWidth  = colchars * font.getMaxCharWidth() + 8;
  _bgcolorlo = kDlgColor;

  // Make sure all lists contain some default values
  int size = _rows * _cols;
  while(size--)
  {
    _offList.emplace_back("0");
    _onList.emplace_back("1");
    _stateList.push_back(false);
    _changedList.push_back(false);
  }

  // Calculate real dimensions
  _w = _colWidth  * cols + 1;
  _h = _rowHeight * rows + 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ToggleBitWidget::ToggleBitWidget(GuiObject* boss, const GUI::Font& font,
                                 int x, int y, int cols, int rows, int colchars)
  : ToggleBitWidget(boss, font, x, y, cols, rows, colchars, StringList())
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToggleBitWidget::setList(const StringList& off, const StringList& on)
{
  _offList.clear();
  _offList = off;
  _onList.clear();
  _onList = on;

  assert(int(_offList.size()) == _rows * _cols);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToggleBitWidget::setState(const BoolArray& state, const BoolArray& changed)
{
  if(!std::equal(_changedList.begin(), _changedList.end(),
     changed.begin(), changed.end()))
    setDirty();

  _stateList.clear();
  _stateList = state;
  _changedList.clear();
  _changedList = changed;
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string ToggleBitWidget::getToolTip(const Common::Point& pos) const
{
  const Common::Point& idx = getToolTipIndex(pos);

  if(idx.y < 0)
    return EmptyString;

  string tip = ToggleWidget::getToolTip(pos);

  if(idx.x < static_cast<int>(_labelList.size()))
  {
    const string label = _labelList[idx.x];

    if(!label.empty())
      return tip + "\n" + label;
  }
  return tip;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToggleBitWidget::drawWidget(bool hilite)
{
//cerr << "ToggleBitWidget::drawWidget\n";
  FBSurface& s = dialog().surface();
  string buffer;

  s.frameRect(_x, _y, _w, _h, hilite && isEnabled() && isEditable() ? kWidColorHi : kColor);

  const int linewidth = _cols * _colWidth,
            lineheight = _rows * _rowHeight;

  // Draw the internal grid and labels
  for(int row = 1; row <= _rows - 1; row++)
    s.hLine(_x + 1, _y + (row * _rowHeight), _x + linewidth - 1, kBGColorLo);

  for(int col = 1; col <= _cols - 1; col++)
    s.vLine(_x + (col * _colWidth), _y + 1, _y + lineheight - 1, kBGColorLo);

  // Draw the list items
  for(int row = 0; row < _rows; row++)
  {
    for(int col = 0; col < _cols; col++)
    {
      ColorId textColor = kTextColor;
      const int x = _x + 4 + (col * _colWidth),
                y = _y + 2 + (row * _rowHeight),
                pos = row*_cols + col;

      // Draw the selected item inverted, on a highlighted background.
      if(_currentRow == row && _currentCol == col && _hasFocus)
      {
        s.fillRect(x - 4, y - 2, _colWidth + 1, _rowHeight + 1, kTextColorHi);
        textColor = kTextColorInv;
      }

      if(_stateList[pos])
        buffer = _onList[pos];
      else
        buffer = _offList[pos];

      if(isEditable())
      {
        // Highlight changes
        if(_changedList[pos])
        {
          s.fillRect(x - 3, y - 1, _colWidth-1, _rowHeight-1, kDbgChangedColor);
          s.drawString(_font, buffer, x, y, _colWidth, kDbgChangedTextColor);
        }
        else
          s.drawString(_font, buffer, x, y, _colWidth, textColor);
      }
      else
      {
        s.fillRect(x - 3, y - 1, _colWidth-1, _rowHeight-1, kBGColorHi);
        s.drawString(_font, buffer, x, y, _colWidth, kTextColor);
      }
    }
  }
}
