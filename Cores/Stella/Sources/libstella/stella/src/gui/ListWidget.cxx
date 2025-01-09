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

#include "OSystem.hxx"
#include "Widget.hxx"
#include "ScrollBarWidget.hxx"
#include "Dialog.hxx"
#include "FrameBuffer.hxx"
#include "StellaKeys.hxx"
#include "EventHandler.hxx"
#include "ListWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ListWidget::ListWidget(GuiObject* boss, const GUI::Font& font,
                       int x, int y, int w, int h, bool useScrollbar)
  : EditableWidget(boss, font, x, y, 16, 16),
    _useScrollbar{useScrollbar}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG | Widget::FLAG_RETAIN_FOCUS;
  _bgcolor = kWidColor;
  _bgcolorhi = kWidColor;
  _textcolor = kTextColor;
  _textcolorhi = kTextColor;

  _editMode = false;

  _cols = w / _fontWidth;
  _rows = h / _lineHeight;

  // Set real dimensions
  _h = h + 2;

  // Create scrollbar and attach to the list
  if(_useScrollbar)
  {
    _w = w - ScrollBarWidget::scrollBarWidth(_font);
    _scrollBar = new ScrollBarWidget(boss, font, _x + _w, _y,
                                     ScrollBarWidget::scrollBarWidth(_font), _h);
    _scrollBar->setTarget(this);
  }
  else
    _w = w - 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::setHeight(int h)
{
  Widget::setHeight(h);
  if(_useScrollbar)
    _scrollBar->setHeight(h);

  _rows = (h - 2) / _lineHeight;
  recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::setSelected(int item)
{
  setDirty();

  if(item < 0 || item >= static_cast<int>(_list.size()))
    return;

  if(isEnabled())
  {
    if(_editMode)
      abortEditMode();

    _selectedItem = item;
    sendCommand(ListWidget::kSelectionChangedCmd, _selectedItem, _id);

    _currentPos = _selectedItem - _rows / 2;
    scrollToSelected();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::setSelected(string_view item)
{
  int selected = -1;
  if(!_list.empty())
  {
    if(item.empty())
      selected = 0;
    else
    {
      uInt32 itemToSelect = 0;
      for(const auto& iter: _list)
      {
        if(item == iter)
        {
          selected = itemToSelect;
          break;
        }
        ++itemToSelect;
      }
      if(itemToSelect > _list.size() || selected == -1)
        selected = 0;
    }
  }
  setSelected(selected);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::setHighlighted(int item)
{
  if(item < -1 || item >= static_cast<int>(_list.size()))
    return;

  if(isEnabled())
  {
    if(_editMode)
      abortEditMode();

    _highlightedItem = item;

    // Only scroll the list if we're about to pass the page boundary
    if(_currentPos == 0)
      _currentPos = _highlightedItem;
    else if(_highlightedItem == _currentPos + _rows)
      _currentPos += _rows;

    scrollToHighlighted();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& ListWidget::getSelectedString() const
{
  return (_selectedItem >= 0 && _selectedItem < static_cast<int>(_list.size()))
            ? _list[_selectedItem] : EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::scrollTo(int item)
{
  const int size = static_cast<int>(_list.size());
  if (item >= size)
    item = size - 1;
  if (item < 0)
    item = 0;

  if(_currentPos != item)
  {
    _currentPos = item;
    scrollBarRecalc();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int ListWidget::getWidth() const
{
  return _w + ScrollBarWidget::scrollBarWidth(_font);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::recalc()
{
  const int size = static_cast<int>(_list.size());

  if(_currentPos >= size - _rows)
  {
    if(size <= _rows)
      _currentPos = 0;
    else
      _currentPos = size - _rows;
  }
  if (_currentPos < 0)
    _currentPos = 0;

  if(_selectedItem >= size)
    _selectedItem = size - 1;
  if(_selectedItem < 0)
    _selectedItem = 0;

  _editMode = false;

  if(_useScrollbar)
  {
    _scrollBar->_numEntries = static_cast<int>(_list.size());
    _scrollBar->_entriesPerPage = _rows;
    // disable scrollbar if no longer necessary
    scrollBarRecalc();
  }

  // Reset to normal data entry
  abortEditMode();

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::scrollBarRecalc()
{
  if(_useScrollbar)
  {
    _scrollBar->_currentPos = _currentPos;
    _scrollBar->recalc();
    sendCommand(ListWidget::kScrolledCmd, _currentPos, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if (!isEnabled())
    return;

  resetSelection();
  // First check whether the selection changed
  const int newSelectedItem = findItem(x, y);
  if (newSelectedItem >= static_cast<int>(_list.size()))
    return;

  if (_selectedItem != newSelectedItem)
  {
    if (_editMode)
      abortEditMode();
    _selectedItem = newSelectedItem;
    sendCommand(ListWidget::kSelectionChangedCmd, _selectedItem, _id);
    setDirty();
  }

  // TODO: Determine where inside the string the user clicked and place the
  // caret accordingly. See _editScrollOffset and EditTextWidget::handleMouseDown.
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  // If this was a double click and the mouse is still over the selected item,
  // send the double click command
  if (clickCount == 2 && (_selectedItem == findItem(x, y)))
  {
    sendCommand(ListWidget::kDoubleClickedCmd, _selectedItem, _id);

    // Start edit mode
    if(isEditable() && !_editMode)
      startEditMode();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleMouseWheel(int x, int y, int direction)
{
  if(_useScrollbar)
    _scrollBar->handleMouseWheel(x, y, direction);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int ListWidget::findItem(int x, int y) const
{
  return (y - 1) / _lineHeight + _currentPos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ListWidget::handleText(char text)
{
  // Class EditableWidget handles all text editing related key presses for us
  return _editMode ? EditableWidget::handleText(text) : true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ListWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  // Ignore all Alt-mod keys
  if(StellaModTest::isAlt(mod))
    return false;

  bool handled = true;
  if (!_editMode)
  {
    switch(key)
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

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleJoyDown(int stick, int button, bool longPress)
{
  if (longPress)
    sendCommand(ListWidget::kLongButtonPressCmd, _selectedItem, _id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleJoyUp(int stick, int button)
{
  const Event::Type e = _boss->instance().eventHandler().eventForJoyButton(EventMode::kMenuMode, stick, button);

  handleEvent(e);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ListWidget::handleEvent(Event::Type e)
{
  if(!isEnabled() || _editMode)
    return false;

  bool handled = true;
  const int oldSelectedItem = _selectedItem;
  const int size = static_cast<int>(_list.size());

  switch(e)
  {
    case Event::UISelect:
      if (_selectedItem >= 0)
      {
        if (isEditable())
          startEditMode();
        else
          sendCommand(ListWidget::kActivatedCmd, _selectedItem, _id);
      }
      break;

    case Event::UIUp:
      if (_selectedItem > 0)
        _selectedItem--;
      break;

    case Event::UIDown:
      if (_selectedItem < size - 1)
        _selectedItem++;
      break;

    case Event::UIPgUp:
    case Event::UILeft:
      _selectedItem -= _rows - 1;
      if (_selectedItem < 0)
        _selectedItem = 0;
      break;

    case Event::UIPgDown:
    case Event::UIRight:
      _selectedItem += _rows - 1;
      if (_selectedItem >= size)
        _selectedItem = size - 1;
      break;

    case Event::UIHome:
      _selectedItem = 0;
      break;

    case Event::UIEnd:
      _selectedItem = size - 1;
      break;

    case Event::UIPrevDir:
      sendCommand(ListWidget::kParentDirCmd, _selectedItem, _id);
      break;

    default:
      handled = false;
  }

  if (_selectedItem != oldSelectedItem)
  {
    if(_useScrollbar)
    {
      _scrollBar->draw();
      scrollToSelected();
    }

    sendCommand(ListWidget::kSelectionChangedCmd, _selectedItem, _id);
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::lostFocusWidget()
{
  _editMode = false;

  // Reset to normal data entry
  abortEditMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  if (cmd == GuiObject::kSetPositionCmd)
  {
    if (_currentPos != data)
    {
      _currentPos = data;
      setDirty();

      // Let boss know the list has scrolled
      sendCommand(ListWidget::kScrolledCmd, _currentPos, _id);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::scrollToCurrent(int item)
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

  if (_currentPos < 0 || _rows > static_cast<int>(_list.size()))
    _currentPos = 0;
  else if (_currentPos + _rows > static_cast<int>(_list.size()))
    _currentPos = static_cast<int>(_list.size()) - _rows;

  if(_useScrollbar)
  {
    const int oldScrollPos = _scrollBar->_currentPos;
    _scrollBar->_currentPos = _currentPos;
    _scrollBar->recalc();

    setDirty();

    if(oldScrollPos != _currentPos)
      sendCommand(ListWidget::kScrolledCmd, _currentPos, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::startEditMode()
{
  if (isEditable() && !_editMode && _selectedItem >= 0)
  {
    _editMode = true;
    setText(_list[_selectedItem]);

    // Widget gets raw data while editing
    EditableWidget::startEditMode();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::endEditMode()
{
  if (!_editMode)
    return;

  // Send a message that editing finished with a return/enter key press
  _editMode = false;
  _list[_selectedItem] = editString();
  sendCommand(ListWidget::kDataChangedCmd, _selectedItem, _id);

  // Reset to normal data entry
  EditableWidget::endEditMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ListWidget::abortEditMode()
{
  // Undo any changes made
  _editMode = false;

  // Reset to normal data entry
  EditableWidget::abortEditMode();
}
