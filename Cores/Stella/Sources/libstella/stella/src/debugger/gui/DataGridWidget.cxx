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
#include "ToolTip.hxx"
#include "Font.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "DataGridWidget.hxx"
#include "DataGridOpsWidget.hxx"
#include "RamWidget.hxx"
#include "ScrollBarWidget.hxx"
#include "StellaKeys.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DataGridWidget::DataGridWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int cols, int rows,
                               int colchars, int bits,
                               Common::Base::Fmt base,
                               bool useScrollbar)
  : EditableWidget(boss, font, x, y,
                   cols*(colchars * font.getMaxCharWidth() + 8) + 1,
                   font.getLineHeight()*rows + 1),
    _rows{rows},
    _cols{cols},
    _rowHeight{font.getLineHeight()},
    _colWidth{colchars * font.getMaxCharWidth() + 8},
    _bits{bits},
    _base{base}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_RETAIN_FOCUS | Widget::FLAG_WANTS_RAWDATA;
  _editMode = false;

  // Make sure all lists contain some default values
  _hiliteList.clear();
  int size = _rows * _cols;
  while(size--)
  {
    _addrList.push_back(0);
    _valueList.push_back(0);
    _valueStringList.push_back(EmptyString);
    _toolTipList.push_back(EmptyString);
    _changedList.push_back(false);
    _hiliteList.push_back(false);
  }

  // Set lower and upper bounds to sane values
  setRange(0, 1 << bits);
  // Limit number of chars allowed
  setMaxLen(colchars);

  // Add a scrollbar if necessary
  if(useScrollbar)
  {
    _scrollBar = new ScrollBarWidget(boss, font, _x + _w, _y,
                                     ScrollBarWidget::scrollBarWidth(_font), _h);
    _scrollBar->setTarget(this);
    _scrollBar->_numEntries = 1;
    _scrollBar->_currentPos = 0;
    _scrollBar->_entriesPerPage = 1;
    _scrollBar->_wheel_lines = 1;
  }

  // Add filtering
  switch(base)
  {
    case Common::Base::Fmt::_16:
    case Common::Base::Fmt::_16_1:
    case Common::Base::Fmt::_16_2:
    case Common::Base::Fmt::_16_4:
    case Common::Base::Fmt::_16_8:
      setTextFilter([](char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
      });
      break;
    case Common::Base::Fmt::_10:
      setTextFilter([](char c) {
        return (c >= '0' && c <= '9');
      });
      break;
    case Common::Base::Fmt::_2:
    case Common::Base::Fmt::_2_8:
    case Common::Base::Fmt::_2_16:
      setTextFilter([](char c) { return (c >= '0' && c <= '1'); });
      break;
    default:
      break;  // no filtering for now
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setList(const IntArray& alist, const IntArray& vlist,
                             const BoolArray& changed)
{
  /*
  cerr << "alist.size() = "     << alist.size()
       << ", vlist.size() = "   << vlist.size()
       << ", changed.size() = " << changed.size()
       << ", _rows*_cols = "    << _rows * _cols << "\n\n";
  */
  const size_t size = vlist.size();  // assume the alist is the same size

  const bool dirty = _editMode
    || !std::equal(_valueList.begin(), _valueList.end(),
                   vlist.begin(), vlist.end())
    || !std::equal(_changedList.begin(), _changedList.end(),
                   changed.begin(), changed.end());

  _addrList.clear();
  _valueList.clear();
  _valueStringList.clear();
  _changedList.clear();

  _addrList    = alist;
  _valueList   = vlist;
  _changedList = changed;

  // An efficiency thing
  for(size_t i = 0; i < size; ++i)
    _valueStringList.push_back(Common::Base::toString(_valueList[i], _base));

  /*
  cerr << "_addrList.size() = "     << _addrList.size()
       << ", _valueList.size() = "   << _valueList.size()
       << ", _changedList.size() = " << _changedList.size()
       << ", _valueStringList.size() = " << _valueStringList.size()
       << ", _rows*_cols = "    << _rows * _cols << "\n\n";
  */
  enableEditMode(false);

  if(dirty)
  {
    // Send item selected signal for starting with cell 0
    sendCommand(DataGridWidget::kSelectionChangedCmd, _selectedItem, _id);

    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setList(int a, int v, bool c)
{
  IntArray alist, vlist;
  BoolArray changed;

  alist.push_back(a);
  vlist.push_back(v);
  changed.push_back(c);

  setList(alist, vlist, changed);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setList(int a, int v)
{
  IntArray alist, vlist;
  BoolArray changed;

  alist.push_back(a);
  vlist.push_back(v);
  const bool diff = _addrList.size() == 1 ? getSelectedValue() != v : false;
  changed.push_back(diff);

  setList(alist, vlist, changed);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setEditable(bool editable, bool hiliteBG)
{
  // Override parent method; enable hilite when widget is not editable
  EditableWidget::setEditable(editable, hiliteBG);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setHiliteList(const BoolArray& hilitelist)
{
  assert(hilitelist.size() == uInt32(_rows * _cols));
  _hiliteList.clear();
  _hiliteList = hilitelist;

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setNumRows(int rows)
{
  if(_scrollBar)
    _scrollBar->_numEntries = rows;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setSelectedValue(int value)
{
  setValue(_selectedItem, value, _valueList[_selectedItem] != value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setValue(int position, int value)
{
  setValue(position, value, _valueList[position] != value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setValueInternal(int position, int value, bool changed)
{
  setValue(position, value, changed, false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setValue(int position, int value, bool changed,
                              bool emitSignal)
{
  if(position >= 0 && position < static_cast<int>(_valueList.size()))
  {
    // Correctly format the data for viewing
    editString() = Common::Base::toString(value, _base);

    _valueStringList[position] = editString();
    _changedList[position] = changed;
    _valueList[position] = value;

    if(emitSignal)
      sendCommand(DataGridWidget::kItemDataChangedCmd, position, _id);

    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setRange(int lower, int upper)
{
  _lowerBound = std::max(0, lower);
  _upperBound = std::min(1 << _bits, upper);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if (!isEnabled())
    return;

  resetSelection();
  // First check whether the selection changed
  int newSelectedItem = findItem(x, y);
  if (newSelectedItem > static_cast<int>(_valueList.size()) - 1)
    newSelectedItem = -1;

  if (_selectedItem != newSelectedItem)
  {
    if (_editMode)
      abortEditMode();

    _selectedItem = newSelectedItem;
    _currentRow = _selectedItem / _cols;
    _currentCol = _selectedItem - (_currentRow * _cols);

    sendCommand(DataGridWidget::kSelectionChangedCmd, _selectedItem, _id);
    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  // If this was a double click and the mouse is still over the selected item,
  // send the double click command
  if (clickCount == 2 && (_selectedItem == findItem(x, y)))
  {
    sendCommand(DataGridWidget::kItemDoubleClickedCmd, _selectedItem, _id);

    // Start edit mode
    if(isEditable() && !_editMode)
      startEditMode();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::handleMouseWheel(int x, int y, int direction)
{
  if(_scrollBar)
    _scrollBar->handleMouseWheel(x, y, direction);
  else if(isEditable())
  {
    if(direction > 0)
      decrementCell();
    else if(direction < 0)
      incrementCell();
  }
  dialog().tooltip().hide();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int DataGridWidget::findItem(int x, int y) const
{
  int row = (y - 1) / _rowHeight;
  if(row >= _rows) row = _rows - 1;

  int col = x / _colWidth;
  if(col >= _cols) col = _cols - 1;

  return row * _cols + col;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DataGridWidget::handleText(char text)
{
  if(_editMode)
  {
    // Class EditableWidget handles all text editing related key presses for us
    return EditableWidget::handleText(text);
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DataGridWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  // Ignore all mod keys
  if(StellaModTest::isControl(mod) || StellaModTest::isAlt(mod))
    return false;

  bool handled = true;
  bool dirty = false;

  if (_editMode)
  {
    // Class EditableWidget handles all single-key presses for us
    handled = EditableWidget::handleKeyDown(key, mod);
  }
  else
  {
    switch(key)
    {
      case KBDK_RETURN:
      case KBDK_KP_ENTER:
        if (_currentRow >= 0 && _currentCol >= 0)
        {
          dirty = true;
          _selectedItem = _currentRow*_cols + _currentCol;
          startEditMode();
        }
        break;

      case KBDK_UP:
        if (_currentRow > 0)
        {
          _currentRow--;
          dirty = true;
        }
        else if(_currentCol > 0)
        {
          _currentRow = _rows - 1;
          _currentCol--;
          dirty = true;
        }
        break;

      case KBDK_DOWN:
        if (_currentRow < _rows - 1)
        {
          _currentRow++;
          dirty = true;
        }
        else if(_currentCol < _cols - 1)
        {
          _currentRow = 0;
          _currentCol++;
          dirty = true;
        }
        break;

      case KBDK_LEFT:
        if (_currentCol > 0)
        {
          _currentCol--;
          dirty = true;
        }
        else if(_currentRow > 0)
        {
          _currentCol = _cols - 1;
          _currentRow--;
          dirty = true;
        }
        break;

      case KBDK_RIGHT:
        if (_currentCol < _cols - 1)
        {
          _currentCol++;
          dirty = true;
        }
        else if(_currentRow < _rows - 1)
        {
          _currentCol = 0;
          _currentRow++;
          dirty = true;
        }
        break;

      case KBDK_PAGEUP:
        if(StellaModTest::isShift(mod) && _scrollBar)
          handleMouseWheel(0, 0, -1);
        else if (_currentRow > 0)
        {
          _currentRow = 0;
          dirty = true;
        }
        break;

      case KBDK_PAGEDOWN:
        if(StellaModTest::isShift(mod) && _scrollBar)
          handleMouseWheel(0, 0, +1);
        else if (_currentRow < _rows - 1)
        {
          _currentRow = _rows - 1;
          dirty = true;
        }
        break;

      case KBDK_HOME:
        if (_currentCol > 0)
        {
          _currentCol = 0;
          dirty = true;
        }
        break;

      case KBDK_END:
        if (_currentCol < _cols - 1)
        {
          _currentCol = _cols - 1;
          dirty = true;
        }
        break;

      case KBDK_N: // negate
        if(isEditable())
          negateCell();
        break;

      case KBDK_I: // invert
        if(isEditable())
          invertCell();
        break;

      case KBDK_MINUS: // decrement
      case KBDK_KP_MINUS:
        if(isEditable())
          decrementCell();
        break;

      case KBDK_EQUALS: // increment
      case KBDK_KP_PLUS:
        if(isEditable())
          incrementCell();
        break;

      case KBDK_COMMA: // shift left
        if(isEditable())
          lshiftCell();
        break;

      case KBDK_PERIOD: // shift right
        if(isEditable())
          rshiftCell();
        break;

      case KBDK_Z: // zero
        if(isEditable())
          zeroCell();
        break;

      default:
        handled = false;
    }
  }

  if (dirty)
  {
    const int oldItem = _selectedItem;
    _selectedItem = _currentRow*_cols + _currentCol;

    if(_selectedItem != oldItem)
      sendCommand(DataGridWidget::kSelectionChangedCmd, _selectedItem, _id);

    setDirty();
    dialog().tooltip().hide();
  }

  _currentKeyDown = key;
  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DataGridWidget::handleKeyUp(StellaKey key, StellaMod mod)
{
  if (key == _currentKeyDown)
    _currentKeyDown = KBDK_UNKNOWN;
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::receivedFocusWidget()
{
  // Enable the operations widget and make it send its signals here
  if(_opsWidget)
  {
    _opsWidget->setEnabled(true);
    _opsWidget->setTarget(this);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::lostFocusWidget()
{
  enableEditMode(false);

  // Disable the operations widget
  if(_opsWidget)
    _opsWidget->setEnabled(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::handleCommand(CommandSender* sender, int cmd,
                                   int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kSetPositionCmd:
      // Chain access; pass to parent
      sendCommand(GuiObject::kSetPositionCmd, data, _id);
      break;

    case kDGZeroCmd:
      zeroCell();
      break;

    case kDGInvertCmd:
      invertCell();
      break;

    case kDGNegateCmd:
      negateCell();
      break;

    case kDGIncCmd:
      incrementCell();
      break;

    case kDGDecCmd:
      decrementCell();
      break;

    case kDGShiftLCmd:
      lshiftCell();
      break;

    case kDGShiftRCmd:
      rshiftCell();
      break;

    default:
      return;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setToolTip(int column, int row, string_view text)
{
  if(row >= 0 && row < _rows && column >= 0 && column < _cols)
    _toolTipList[row * _cols + column] = text;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int DataGridWidget::getToolTipIndex(const Common::Point& pos) const
{
  const int col = (pos.x - getAbsX()) / _colWidth;
  const int row = (pos.y - getAbsY()) / _rowHeight;

  if(row >= 0 && row < _rows && col >= 0 && col < _cols)
    return row * _cols + col;
  else
    return -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DataGridWidget::getToolTip(const Common::Point& pos) const
{
  const int idx = getToolTipIndex(pos);

  if(idx < 0)
    return EmptyString;

  const Int32 val = _valueList[idx];
  ostringstream buf;

  if(_toolTipList[idx] != EmptyString)
    buf << _toolTipList[idx];
  else
    buf << _toolTipText;
   buf << "$" << Common::Base::toString(val, Common::Base::Fmt::_16)
       << " = #" << val;
  if(val < 0x100)
  {
    if(val >= 0x80)
      buf << '/' << -(0x100 - val);
    buf << " = %" << Common::Base::toString(val, Common::Base::Fmt::_2);
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DataGridWidget::changedToolTip(const Common::Point& oldPos,
                                    const Common::Point& newPos) const
{
  return getToolTipIndex(oldPos) != getToolTipIndex(newPos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();

  s.fillRect(_x, _y, _w, _h, hilite && isEnabled() && isEditable() ? _bgcolorhi : _bgcolor);
  // Draw the internal grid and labels
  const int linewidth = _cols * _colWidth;
  s.frameRect(_x, _y, _w, _h, hilite && isEnabled() && isEditable() ? kWidColorHi : kColor);
  for(int row = 1; row <= _rows-1; row++)
    s.hLine(_x+1, _y + (row * _rowHeight), _x + linewidth-1, kBGColorLo);

  const int lineheight = _rows * _rowHeight;
  for(int col = 1; col <= _cols-1; col++)
    s.vLine(_x + (col * _colWidth), _y+1, _y + lineheight-1, kBGColorLo);

  // Draw the list items
  for(int row = 0; row < _rows; row++)
  {
    for(int col = 0; col < _cols; col++)
    {
      const int x = _x + 4 + (col * _colWidth);
      const int y = _y + 2 + (row * _rowHeight);
      const int pos = row*_cols + col;
      ColorId textColor = kTextColor;

      // Draw the selected item inverted, on a highlighted background.
      if (_currentRow == row && _currentCol == col &&
          _hasFocus && !_editMode)
      {
        s.fillRect(x - 4, y - 2, _colWidth+1, _rowHeight+1, kTextColorHi);
        textColor = kTextColorInv;
      }

      if (_selectedItem == pos && _editMode)
      {
        adjustOffset();
        s.drawString(_font, editString(), x, y, _colWidth, textColor,
                     TextAlign::Left, -_editScrollOffset, false);
      }
      else
      {
        if(_changedList[pos])
        {
          s.fillRect(x - 3, y - 1, _colWidth-1, _rowHeight-1, kDbgChangedColor);

          if(_hiliteList[pos])
            textColor = kDbgColorHi;
          else
            textColor = kDbgChangedTextColor;
        }
        else if(_hiliteList[pos])
          textColor = kDbgColorHi;

        s.drawString(_font, _valueStringList[pos], x, y, _colWidth, textColor);
      }
    }
  }

  // Only draw the caret while editing, and if it's in the current viewport
  if(_editMode)
    drawCaretSelection();

  // Draw the scrollbar
  if(_scrollBar)
    _scrollBar->recalc();  // takes care of the draw

  // Cross out the grid?
  if(_crossGrid)
  {
    s.line(_x + 1, _y + 1, _x + _w - 2, _y + _h - 1, kColor);
    s.line(_x + _w - 2, _y + 1, _x + 1, _y + _h - 1, kColor);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect DataGridWidget::getEditRect() const
{
  const uInt32 rowoffset = _currentRow * _rowHeight;
  const uInt32 coloffset = _currentCol * _colWidth + 4;

  return {
    1 + coloffset, rowoffset,
    _colWidth + coloffset - 5, _rowHeight + rowoffset
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int DataGridWidget::getWidth() const
{
  return _w + (_scrollBar ? ScrollBarWidget::scrollBarWidth(_font) : 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::setCrossed(bool enable)
{
  if(_crossGrid != enable)
  {
    _crossGrid = enable;
    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::startEditMode()
{
  if (isEditable() && !_editMode && _selectedItem >= 0)
  {
    dialog().tooltip().hide();
    enableEditMode(true);
    setText("", true);  // Erase current entry when starting editing
    backupString() = "@@"; // dummy value to process Escape correctly key when nothing is entered
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::endEditMode()
{
  if (!_editMode)
    return;

  enableEditMode(false);

  // Update the both the string representation and the real data
  if(!editString().empty() && editString()[0] != '$' &&
     editString()[0] != '#' && editString()[0] != '\\')
  {
    switch(_base)
    {
      case Common::Base::Fmt::_16:
      case Common::Base::Fmt::_16_1:
      case Common::Base::Fmt::_16_2:
      case Common::Base::Fmt::_16_4:
      case Common::Base::Fmt::_16_8:
        editString().insert(0, 1, '$');
        break;
      case Common::Base::Fmt::_2:
      case Common::Base::Fmt::_2_8:
      case Common::Base::Fmt::_2_16:
        editString().insert(0, 1, '\\');
        break;
      case Common::Base::Fmt::_10:
        editString().insert(0, 1, '#');
        break;
      case Common::Base::Fmt::_DEFAULT:
      default:  // TODO - properly handle all other cases
        break;
    }
  }
  const int value = instance().debugger().stringToValue(editString());
  if(value < _lowerBound || value >= _upperBound)
  {
    abortEditMode();
    return;
  }

  setSelectedValue(value);
  commit();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::abortEditMode()
{
  if(_editMode)
  {
    abort();
    // Undo any changes made
    assert(_selectedItem >= 0);
    enableEditMode(false);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::negateCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(mask != _upperBound - 1)     // ignore when values aren't byte-aligned
    return;

  value = ((~value) + 1) & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::invertCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(mask != _upperBound - 1)     // ignore when values aren't byte-aligned
    return;

  value = ~value & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::decrementCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(value <= _lowerBound)        // take care of wrap-around
    value = _upperBound;

  value = (value - 1) & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::incrementCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(value >= _upperBound - 1)    // take care of wrap-around
    value = _lowerBound - 1;

  value = (value + 1) & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::lshiftCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(mask != _upperBound - 1)     // ignore when values aren't byte-aligned
    return;

  value = (value << 1) & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::rshiftCell()
{
  const int mask  = (1 << _bits) - 1;
  int value = getSelectedValue();
  if(mask != _upperBound - 1)     // ignore when values aren't byte-aligned
    return;

  value = (value >> 1) & mask;
  setSelectedValue(value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DataGridWidget::zeroCell()
{
  setSelectedValue(0);
}
