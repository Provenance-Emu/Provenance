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
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "DiStella.hxx"
#include "Widget.hxx"
#include "Dialog.hxx"
#include "ToolTip.hxx"
#include "StellaKeys.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "ScrollBarWidget.hxx"
#include "RomListSettings.hxx"
#include "RomListWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomListWidget::RomListWidget(GuiObject* boss, const GUI::Font& lfont,
                             const GUI::Font& nfont,
                             int x, int y, int w, int h)
  : EditableWidget(boss, nfont, x, y, 16, 16)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG | Widget::FLAG_RETAIN_FOCUS;
  _bgcolor = kWidColor;
  _bgcolorhi = kWidColor;
  _textcolor = kTextColor;
  _textcolorhi = kTextColor;

  _editMode = false;
  _dyText = -1; // fixes the vertical position of selected text

  _cols = w / _fontWidth;
  _rows = h / _lineHeight;

  // Set real dimensions
  _w = w - ScrollBarWidget::scrollBarWidth(_font);
  _h = h + 2;

  // Create scrollbar and attach to the list
  myScrollBar = new ScrollBarWidget(boss, lfont, _x + _w, _y,
                                    ScrollBarWidget::scrollBarWidth(_font), _h);
  myScrollBar->setTarget(this);

  // Add settings menu
  myMenu = make_unique<RomListSettings>(this, lfont);

  // Take advantage of a wide debugger window when possible
  const int fontWidth = lfont.getMaxCharWidth(),
            numchars = w / fontWidth;

  _labelWidth = std::max(14, static_cast<int>(0.45 * (numchars - 8 - 8 - 9 - 2))) * fontWidth - 1;
  _bytesWidth = 9 * fontWidth;

  ///////////////////////////////////////////////////////
  // Add checkboxes
  int ypos = _y + 2;

  // rowheight is determined by largest item on a line,
  // possibly meaning that number of rows will change
  _lineHeight = std::max(_lineHeight, CheckboxWidget::boxSize(_font));
  _rows = h / _lineHeight;

  // Create a CheckboxWidget for each row in the list
  for(int i = 0; i < _rows; ++i)
  {
    auto* t = new CheckboxWidget(boss, lfont, _x + 2, ypos, "",
        CheckboxWidget::kCheckActionCmd);
    t->setTarget(this);
    t->setID(i);
    t->setFill(CheckboxWidget::FillType::Circle);
    t->setTextColor(kTextColorEm);
    ypos += _lineHeight;

    myCheckList.push_back(t);
  }

  // Add filtering
  const EditableWidget::TextFilter f = [&](char c)
  {
    switch(_base)
    {
      case Common::Base::Fmt::_16:
      case Common::Base::Fmt::_16_1:
      case Common::Base::Fmt::_16_2:
      case Common::Base::Fmt::_16_4:
      case Common::Base::Fmt::_16_8:
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || c == ' ';

      case Common::Base::Fmt::_2:
      case Common::Base::Fmt::_2_8:
      case Common::Base::Fmt::_2_16:
        return c == '0' || c == '1' || c == ' ';

      case Common::Base::Fmt::_10:
        return (c >= '0' && c <= '9') || c == ' ';

      case Common::Base::Fmt::_DEFAULT:
      default:  // TODO - properly handle all other cases
        return false;
    }
  };
  setTextFilter(f);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::setList(const CartDebug::Disassembly& disasm)
{
  myDisasm = &disasm;

  // Enable all checkboxes
  for(int i = 0; i < _rows; ++i)
    myCheckList[i]->setFlags(Widget::FLAG_ENABLED);

  // Then turn off any extras
  if(static_cast<int>(myDisasm->list.size()) < _rows)
    for(int i = static_cast<int>(myDisasm->list.size()); i < _rows; ++i)
      myCheckList[i]->clearFlags(Widget::FLAG_ENABLED);

  recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::setSelected(int item)
{
  if(item < -1 || item >= static_cast<int>(myDisasm->list.size()))
    return;

  if(isEnabled())
  {
    if(_editMode)
      abortEditMode();

    _currentPos = _selectedItem = item;
    scrollToSelected();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::setHighlighted(int item)
{
  if(item < -1 || item >= static_cast<int>(myDisasm->list.size()))
    return;

  if(isEnabled())
  {
    if(_editMode)
      abortEditMode();

    _highlightedItem = item;

    // Only scroll the list if we're about to pass the page boundary
    if (_highlightedItem < _currentPos)
    {
      _currentPos -= _rows;
      if (_currentPos < 0)
        _currentPos = 0;
    }
    else if(_highlightedItem == _currentPos + _rows)
      _currentPos += _rows;

    scrollToHighlighted();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int RomListWidget::findItem(int x, int y) const
{
  return (y - 1) / _lineHeight + _currentPos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::recalc()
{
  const int size = static_cast<int>(myDisasm->list.size());

  if (_currentPos >= size)
    _currentPos = size - 1;
  if (_currentPos < 0)
    _currentPos = 0;

  if(_selectedItem < 0 || _selectedItem >= size)
    _selectedItem = 0;

  _editMode = false;

  myScrollBar->_numEntries     = static_cast<int>(myDisasm->list.size());
  myScrollBar->_entriesPerPage = _rows;

  // Reset to normal data entry
  abortEditMode();

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::scrollToCurrent(int item)
{
  // Only do something if the current item is not in our view port
  if (item < _currentPos)
  {
    // it's above our view
    _currentPos = item;
  }
  else if (item >= _currentPos + _rows )
  {
    // it's below our view
    _currentPos = item - _rows + 1;
  }

  const int size = static_cast<int>(myDisasm->list.size());
  if (_currentPos < 0 || _rows > size)
    _currentPos = 0;
  else if (_currentPos + _rows > size)
    _currentPos = size - _rows;

  myScrollBar->_currentPos = _currentPos;
  myScrollBar->recalc();

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if (!isEnabled())
    return;

  resetSelection();
  // Grab right mouse button for context menu, left for selection/edit mode
  if(b == MouseButton::RIGHT)
  {
    // Set selected and add menu at current x,y mouse location
    _selectedItem = findItem(x, y);
    scrollToSelected();
    dialog().tooltip().hide();
    myMenu->show(x + getAbsX(), y + getAbsY(),
                 dialog().surface().dstRect(), _selectedItem);
  }
  else
  {
    // First check whether the selection changed
    int newSelectedItem = findItem(x, y);
    if (newSelectedItem > static_cast<int>(myDisasm->list.size()) - 1)
      newSelectedItem = -1;

    if (_selectedItem != newSelectedItem)
    {
      if (_editMode)
        abortEditMode();
      _selectedItem = newSelectedItem;
      setDirty();
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  // If this was a double click and the mouse is still over the selected item,
  // send the double click command
  if (clickCount == 2 && (_selectedItem == findItem(x, y)))
  {
    // Start edit mode
    if(isEditable() && !_editMode)
      startEditMode();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::handleMouseWheel(int x, int y, int direction)
{
  myScrollBar->handleMouseWheel(x, y, direction);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomListWidget::handleText(char text)
{
  if(_editMode)
  {
    // Class EditableWidget handles all text editing related key presses for us
    return EditableWidget::handleText(text);
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomListWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  // Ignore all Alt-mod keys
  if(StellaModTest::isAlt(mod))
    return false;

  bool handled = true;
  const int oldSelectedItem = _selectedItem;

  if (_editMode)
  {
    // Class EditableWidget handles all single-key presses for us
    handled = EditableWidget::handleKeyDown(key, mod);
  }
  else
  {
    switch (key)
    {
      case KBDK_SPACE:
        // Snap list back to currently highlighted line
        if(_highlightedItem >= 0)
        {
          _currentPos = _highlightedItem;
          scrollToHighlighted();
        }
        break;

      default:
        handled = false;
    }
  }

  if (_selectedItem != oldSelectedItem)
  {
    myScrollBar->draw();
    scrollToSelected();
  }

  _currentKeyDown = key;
  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomListWidget::handleKeyUp(StellaKey key, StellaMod mod)
{
  if (key == _currentKeyDown)
    _currentKeyDown = KBDK_UNKNOWN;
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomListWidget::handleEvent(Event::Type e)
{
  if(!isEnabled() || _editMode)
    return false;

  bool handled = true;
  const int oldSelectedItem = _selectedItem;

  switch(e)
  {
    case Event::UISelect:
      if (_selectedItem >= 0)
      {
        if (isEditable())
          startEditMode();
      }
      break;

    case Event::UIUp:
      if (_selectedItem > 0)
        _selectedItem--;
      break;

    case Event::UIDown:
      if (_selectedItem < static_cast<int>(myDisasm->list.size()) - 1)
        _selectedItem++;
      break;

    case Event::UIPgUp:
      _selectedItem -= _rows - 1;
      if (_selectedItem < 0)
        _selectedItem = 0;
      break;

    case Event::UIPgDown:
      _selectedItem += _rows - 1;
      if (_selectedItem >= static_cast<int>(myDisasm->list.size()))
        _selectedItem = static_cast<int>(myDisasm->list.size()) - 1;
      break;

    case Event::UIHome:
      _selectedItem = 0;
      break;

    case Event::UIEnd:
      _selectedItem = static_cast<int>(myDisasm->list.size()) - 1;
      break;

    default:
      handled = false;
  }

  if (_selectedItem != oldSelectedItem)
  {
    myScrollBar->draw();
    scrollToSelected();
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch (cmd)
  {
    case CheckboxWidget::kCheckActionCmd:
      // We let the parent class handle this
      // Pass it as a kRLBreakpointChangedCmd command, since that's the intent
      sendCommand(RomListWidget::kBPointChangedCmd, _currentPos+id, 0);
      break;

    case GuiObject::kSetPositionCmd:
      if (_currentPos != data)
      {
        _currentPos = data;
        setDirty();
      }
      break;

    default:
      // Let the parent class handle all other commands directly
      sendCommand(cmd, data, id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::lostFocusWidget()
{
  _editMode = false;

  // Reset to normal data entry
  abortEditMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Point RomListWidget::getToolTipIndex(const Common::Point& pos) const
{
  const Common::Rect& r = getEditRect();
  const int col = (pos.x - r.x() - getAbsX()) / _font.getMaxCharWidth();
  const int row = (pos.y - getAbsY()) / _lineHeight;

  if(col < 0 || col >= 8
     || row < 0 || row + _currentPos >= static_cast<int>(myDisasm->list.size()))
    return Common::Point(-1, -1);
  else
    return Common::Point(col, row + _currentPos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string RomListWidget::getToolTip(const Common::Point& pos) const
{
  const Common::Point& idx = getToolTipIndex(pos);

  if(idx.y < 0)
    return EmptyString;

  const string bytes = myDisasm->list[idx.y].bytes;

  if(static_cast<Int32>(bytes.length()) < idx.x + 1)
    return EmptyString;

  Int32 val = 0;
  if(bytes.length() == 8 && bytes[2] != ' ')
  {
    // Binary value
    val = static_cast<Int32>(stol(bytes, nullptr, 2));
  }
  else
  {
    // 1..3 hex values
    if(idx.x == 2)
      // Skip gap after first byte
      return EmptyString;

    string valStr;

    if(idx.x < 2 || bytes.length() < 8)
      // 1 or 2 hex bytes, get one hex byte
      valStr = bytes.substr((static_cast<size_t>(idx.x) / 3) * 3, 2);
    else
      // 3 hex bytes, get two rightmost hex bytes
      valStr = bytes.substr(6, 2) + bytes.substr(3, 2);

    val = static_cast<Int32>(stol(valStr, nullptr, 16));
  }
  ostringstream buf;

  buf << _toolTipText
    << "$" << Common::Base::toString(val, Common::Base::Fmt::_16)
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
bool RomListWidget::changedToolTip(const Common::Point& oldPos,
                                   const Common::Point& newPos) const
{
  return getToolTipIndex(oldPos) != getToolTipIndex(newPos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();
  const CartDebug::DisassemblyList& dlist = myDisasm->list;
  constexpr ColorId textColor = kTextColor;

  const Common::Rect& r = getEditRect();
  const Common::Rect& l = getLineRect();

  // Draw a thin frame around the list and to separate columns
  s.frameRect(_x, _y, _w + 1, _h, hilite ? kWidColorHi : kColor);
  s.vLine(_x + CheckboxWidget::boxSize(_font) + 5, _y, _y + _h - 1, kColor);

  // Draw the list items
  const int cycleCountW = _fontWidth * 8,
      noTypeDisasmW = _w - l.x() - _labelWidth,
      noCodeDisasmW = noTypeDisasmW - r.w(),
      actualWidth = myDisasm->fieldwidth * _fontWidth,
      codeDisasmW = std::min(actualWidth, noCodeDisasmW - cycleCountW);

  const int len = static_cast<int>(dlist.size());
  const int xpos = _x + CheckboxWidget::boxSize(_font) + 10;
  int ypos = _y + 2;
  for(int i = 0, pos = _currentPos; i < _rows && pos < len; i++, pos++, ypos += _lineHeight)
  {
    ColorId bytesColor = textColor;

    // Mark checkboxes dirty for correct lines (takes scrolling into account)
    myCheckList[i]->setState(instance().debugger().
                             checkBreakPoint(dlist[pos].address,
                             instance().debugger().cartDebug().getBank(dlist[pos].address)));
    myCheckList[i]->setDirty();
    // All checkboxes have to be redrawn because RomListWidget clears its whole area
    // Also draw immediately, because chain order is not deterministic
    myCheckList[i]->draw();

    // Draw highlighted item in a frame
    if(_highlightedItem == pos)
      s.frameRect(_x + l.x() - 3, ypos - 1, _w - l.x(), _lineHeight, kWidColorHi);

    // Draw the selected item inverted, on a highlighted background.
    if(_selectedItem == pos && _hasFocus)
    {
      if(!_editMode)
      {
        s.fillRect(_x + r.x() - 3, ypos - 1, r.w(), _lineHeight, kTextColorHi);
        bytesColor = kTextColorInv;
      }
      else
        s.frameRect(_x + r.x() - 3, ypos - 1, r.w(), _lineHeight, kWidColorHi);
    }

    // Draw labels
    s.drawString(_font, dlist[pos].label, xpos, ypos, _labelWidth,
                  dlist[pos].hllabel ? textColor : kColor);

    // Bytes are only editable if they represent code, graphics, or accessible data
    // Otherwise, the disassembly should get all remaining space
    if(dlist[pos].type & (Device::CODE | Device::GFX | Device::PGFX |
       Device::COL | Device::PCOL | Device::BCOL | Device::DATA))
    {
      if(dlist[pos].type == Device::CODE)
      {
        // Draw mnemonic
        s.drawString(_font, dlist[pos].disasm.substr(0, 7), xpos + _labelWidth, ypos,
                      7 * _fontWidth, textColor);
        // Draw operand
        if(dlist[pos].disasm.length() > 8)
          s.drawString(_font, dlist[pos].disasm.substr(8), xpos + _labelWidth + 7 * _fontWidth, ypos,
                        codeDisasmW - 7 * _fontWidth, textColor);
        // Draw cycle count
        s.drawString(_font, dlist[pos].ccount, xpos + _labelWidth + codeDisasmW, ypos,
                      cycleCountW, textColor);
      }
      else
      {
        // Draw disassembly only
        s.drawString(_font, dlist[pos].disasm, xpos + _labelWidth, ypos,
                      noCodeDisasmW - 4, kTextColor);
      }

      // Draw separator
      s.vLine(_x + r.x() - 7, ypos, ypos + _lineHeight - 1, kColor);

      // Draw bytes
      {
        if(_selectedItem == pos && _editMode)
        {
          adjustOffset();
          s.drawString(_font, editString(), _x + r.x(), ypos, r.w(), textColor,
                        TextAlign::Left, -_editScrollOffset, false);

          drawCaretSelection();
        }
        else
        {
          s.drawString(_font, dlist[pos].bytes, _x + r.x(), ypos, r.w(), bytesColor);
        }
      }
    }
    else
    {
      // Draw disassembly, giving it all remaining horizontal space
      s.drawString(_font, dlist[pos].disasm, xpos + _labelWidth, ypos,
                    noTypeDisasmW, textColor);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect RomListWidget::getLineRect() const
{
  const uInt32
      yoffset = std::max(0, (_selectedItem - _currentPos) * _lineHeight),
      xoffset = CheckboxWidget::boxSize(_font) + 10;

  return {
    2 + xoffset, 1 + yoffset,
    _w - (xoffset - 15), _lineHeight + yoffset
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect RomListWidget::getEditRect() const
{
  const uInt32 yoffset = std::max(0, (_selectedItem - _currentPos) * _lineHeight);

  return {
    static_cast<uInt32>(2 + _w - _bytesWidth), 1 + yoffset + 1,
    static_cast<uInt32>(_w), _lineHeight + yoffset + 1
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::startEditMode()
{
  if (isEditable() && !_editMode && _selectedItem >= 0)
  {
    // Does this line represent an editable area?
    if(myDisasm->list[_selectedItem].bytes.empty())
      return;

    _editMode = true;
    dialog().tooltip().hide();
    switch(myDisasm->list[_selectedItem].type)
    {
      case Device::GFX:
      case Device::PGFX:
        _base = DiStella::settings.gfxFormat;
        break;
      default:
        _base = Common::Base::format();
    }

    // Widget gets raw data while editing
    EditableWidget::startEditMode();
    setText(myDisasm->list[_selectedItem].bytes);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::endEditMode()
{
  if (!_editMode)
    return;

  // Send a message that editing finished with a return/enter key press
  // The parent then calls getText() to get the newly entered data
  _editMode = false;
  sendCommand(RomListWidget::kRomChangedCmd, _selectedItem, static_cast<int>(_base));

  // Reset to normal data entry
  EditableWidget::endEditMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListWidget::abortEditMode()
{
  // Undo any changes made
  _editMode = false;

  // Reset to normal data entry
  EditableWidget::abortEditMode();
}
