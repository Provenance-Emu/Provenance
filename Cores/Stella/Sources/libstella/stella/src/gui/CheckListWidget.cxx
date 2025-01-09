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

#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "ScrollBarWidget.hxx"
#include "CheckListWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CheckListWidget::CheckListWidget(GuiObject* boss, const GUI::Font& font,
                                 int x, int y, int w, int h)
  : ListWidget(boss, font, x, y, w, h)
{
  int ypos = _y + 2;

  // rowheight is determined by largest item on a line,
  // possibly meaning that number of rows will change
  _lineHeight = std::max(_lineHeight, CheckboxWidget::boxSize(_font));
  _rows = h / _lineHeight;

  // Create a CheckboxWidget for each row in the list
  for(int i = 0; i < _rows; ++i)
  {
    auto* t = new CheckboxWidget(boss, font, _x + 2, ypos, "",
                                 CheckboxWidget::kCheckActionCmd);
    t->setTextColor(kTextColor);
    t->setTarget(this);
    t->setID(i);
    ypos += _lineHeight;

    _checkList.push_back(t);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheckListWidget::setList(const StringList& list, const BoolArray& state)
{
  _list = list;
  _stateList = state;

  assert(_list.size() == _stateList.size());

  // Enable all checkboxes
  for(int i = 0; i < _rows; ++i)
    _checkList[i]->setFlags(Widget::FLAG_ENABLED);

  // Then turn off any extras
  if(static_cast<int>(_stateList.size()) < _rows)
    for(int i = static_cast<int>(_stateList.size()); i < _rows; ++i)
      _checkList[i]->clearFlags(Widget::FLAG_ENABLED);

  ListWidget::recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheckListWidget::setLine(int line, string_view str, const bool& state)
{
  if(line >= static_cast<int>(_list.size()))
    return;

  _list[line]      = str;
  _stateList[line] = state;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheckListWidget::drawWidget(bool hilite)
{
//cerr << "CheckListWidget::drawWidget\n";
  FBSurface& s = _boss->dialog().surface();
  const int len = static_cast<int>(_list.size());

  // Draw a thin frame around the list and to separate columns
  s.frameRect(_x, _y, _w, _h, hilite ? kWidColorHi : kColor);
  s.vLine(_x + CheckboxWidget::boxSize(_font) + 5, _y, _y + _h - 1, kColor);

  // Draw the list items
  for (int i = 0, pos = _currentPos; i < _rows && pos < len; i++, pos++)
  {
    // Draw checkboxes for correct lines (takes scrolling into account)
    _checkList[i]->setState(_stateList[pos]);
    _checkList[i]->setDirty();
    _checkList[i]->draw();

    const int y = _y + 2 + _lineHeight * i + 2;
    ColorId textColor = kTextColor;

    const Common::Rect r(getEditRect());

    // Draw the selected item inverted, on a highlighted background.
    if (_selectedItem == pos)
    {
      if(_hasFocus && !_editMode)
      {
        s.fillRect(_x + r.x() - 3, _y + 1 + _lineHeight * i,
                   _w - r.x(), _lineHeight, kTextColorHi);
        textColor = kTextColorInv;
      }
      else
        s.frameRect(_x + r.x() - 3, _y + 1 + _lineHeight * i,
                    _w - r.x(), _lineHeight, kTextColorHi);
    }

    if (_selectedItem == pos && _editMode)
    {
      adjustOffset();
      s.drawString(_font, editString(), _x + r.x(), y, r.w(), kTextColor,
                   TextAlign::Left, -_editScrollOffset, false);
    }
    else
      s.drawString(_font, _list[pos], _x + r.x(), y, r.w(), textColor);
  }

  // Only draw the caret while editing, and if it's in the current viewport
  if(_editMode &&
     (!_useScrollbar ||
     ((_selectedItem >= _scrollBar->_currentPos) &&
      (_selectedItem < _scrollBar->_currentPos + _rows))))
    drawCaretSelection();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect CheckListWidget::getEditRect() const
{
  const uInt32 yoffset = (_selectedItem - _currentPos) * _lineHeight,
               xoffset = CheckboxWidget::boxSize(_font) + 10;

  return {
    2 + xoffset, 1 + yoffset,
    _w - (xoffset - 15), _lineHeight + yoffset
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CheckListWidget::getState(int line) const
{
  if(line >= 0 && line < static_cast<int>(_stateList.size()))
    return _stateList[line];
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CheckListWidget::handleEvent(Event::Type e)
{
  if(e == Event::UISelect)
  {
    // Simulate a mouse button click
    _checkList[ListWidget::getSelected()]->handleMouseUp(0, 0, MouseButton::LEFT, 0);
    return true;
  }
  else
    return ListWidget::handleEvent(e);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheckListWidget::handleCommand(CommandSender* sender, int cmd,
                                    int data, int id)
{
  if(cmd == CheckboxWidget::kCheckActionCmd)
  {
    // Figure out which line has been checked
    const int line = _currentPos + id;
    _stateList[line] = static_cast<bool>(data);

    // Let the boss know about it
    sendCommand(CheckListWidget::kListItemChecked, line, _id);
  }
  else
    ListWidget::handleCommand(sender, cmd, data, id);
}
