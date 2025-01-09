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
#include "StellaKeys.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "ContextMenu.hxx"
#include "OSystem.hxx"
#include "EventHandler.hxx"
#include "UndoHandler.hxx"
#include "ToolTip.hxx"
#include "EditableWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EditableWidget::EditableWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int w, int h, string_view str)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss),
    _editString{str},
    myUndoHandler{make_unique<UndoHandler>()},
    _filter{[](char c) { return isprint(c) && c != '\"'; }}
{
  _bgcolor = kWidColor;
  _bgcolorhi = kWidColor;
  _bgcolorlo = kDlgColor;
  _textcolor = kTextColor;
  _textcolorhi = kTextColor;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::setText(string_view str, bool changed)
{
  const string oldEditString = _editString;
  _backupString = str;
  // Filter input string
  _editString = "";
  for(const auto c: str)
    if(_filter(tolower(c)))
      _editString.push_back(c);
  if(_maxLen)
    _editString = _editString.substr(0, _maxLen);

  if(oldEditString != _editString)
    setDirty();

  myUndoHandler->reset();
  myUndoHandler->doo(_editString);

  _caretPos = static_cast<int>(_editString.size());
  _selectSize = 0;

  _editScrollOffset = (_font.getStringWidth(_editString) - (getEditRect().w()));
  if (_editScrollOffset < 0)
    _editScrollOffset = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::tick()
{
  if(_hasFocus && isEditable() && _editMode && isVisible() && _boss->isVisible())
  {
    _caretTimer++;
    if(_caretTimer > 40) // switch every 2/3rd seconds
    {
      _caretTimer = 0;
      _caretEnabled = !_caretEnabled;
      setDirty();
    }
  }
  Widget::tick();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::wantsToolTip() const
{
  return !(_hasFocus && isEditable() && _editMode) && Widget::wantsToolTip();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::setEditable(bool editable, bool hiliteBG)
{
  _editable = editable;
  if(_editable)
  {
    setFlags(Widget::FLAG_WANTS_RAWDATA | Widget::FLAG_RETAIN_FOCUS);
    _bgcolor = kWidColor;
  }
  else
  {
    clearFlags(Widget::FLAG_WANTS_RAWDATA | Widget::FLAG_RETAIN_FOCUS);
    _bgcolor = hiliteBG ? kBGColorHi : kWidColor;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::receivedFocusWidget()
{
  _caretTimer = 0;
  _caretEnabled = true;
  dialog().tooltip().hide();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::lostFocusWidget()
{
  myUndoHandler->reset();
  _selectSize = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EditableWidget::toCaretPos(int x) const
{
  int i = 0;

  x += caretOfs();
  for(i = 0; i < static_cast<int>(_editString.size()); ++i)
  {
    x -= _font.getCharWidth(_editString[i]);
    if(x <= 0)
      break;
  }
  return i;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  // Grab right mouse button for context menu, send left to base class
  if(b == MouseButton::RIGHT && isEnabled() && !mouseMenu().isVisible())
  {
    VariantList items;
  #ifndef BSPF_MACOS
    if(isEditable())
      VarList::push_back(items, " Cut     Ctrl+X ", "cut");
    VarList::push_back(items, " Copy    Ctrl+C ", "copy");
    if(isEditable())
      VarList::push_back(items, " Paste   Ctrl+V ", "paste");
  #else
    if(isEditable())
      VarList::push_back(items, " Cut      Cmd+X ", "cut");
    VarList::push_back(items, " Copy     Cmd+C ", "copy");
    if(isEditable())
      VarList::push_back(items, " Paste    Cmd+V ", "paste");
  #endif
    mouseMenu().addItems(items);

    // Add menu at current x,y mouse location
    mouseMenu().show(x + getAbsX(), y + getAbsY(), dialog().surface().dstRect());
    return;
  }
  else if(b == MouseButton::LEFT && isEnabled())
  {
    _isDragging = true;

    if(clickCount == 2)
    {
      // If left mouse button is double clicked, mark word under cursor
      markWord();
      return;
    }
  }
  Widget::handleMouseDown(x, y, b, clickCount);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ContextMenu& EditableWidget::mouseMenu()
{
  // add mouse context menu
  if(myMouseMenu == nullptr)
    myMouseMenu = make_unique<ContextMenu>(this, _font);

  return *myMouseMenu;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  _isDragging = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::handleMouseMoved(int x, int y)
{
  if(isEditable() && _isDragging)
  {
    const int deltaPos = toCaretPos(x) - _caretPos;

    if(deltaPos)
    {
      moveCaretPos(deltaPos);
      setDirty();
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == ContextMenu::kItemSelectedCmd)
  {
    const string_view rmb = mouseMenu().getSelectedTag().toString();

    if(rmb == "cut")
    {
      if(cutSelectedText())
        sendCommand(EditableWidget::kChangedCmd, 0, _id);
    }
    else if(rmb == "copy")
    {
      if(!isEditable())
      {
        // Copy everything if widget is not editable
        _caretPos = 0;
        _selectSize = static_cast<int>(_editString.length());
      }
      copySelectedText();
    }
    else if(rmb == "paste")
    {
      if(pasteSelectedText())
        sendCommand(EditableWidget::kChangedCmd, 0, _id);
    }
    setDirty();
  }
  else
    Widget::handleCommand(sender, cmd, data, id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::tryInsertChar(char c, int pos)
{
  if(_filter(tolower(c)))
  {
    if(_selectSize < 0)   // left to right selection
      pos += _selectSize; // adjust to new position after removing selected text
    killSelectedText();
    if(!_maxLen || static_cast<int>(_editString.length()) < _maxLen)
    {
      myUndoHandler->doChar(); // aggregate single chars
      _editString.insert(pos, 1, c);
      return true;
    }
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::handleText(char text)
{
  if(!_editable)
    return true;

  if(tryInsertChar(text, _caretPos))
  {
    setCaretPos(_caretPos + 1);
    sendCommand(EditableWidget::kChangedCmd, 0, _id);
    setDirty();
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  if(!_editable)
    return false;

  bool handled = true;
  const Event::Type event = instance().eventHandler().eventForKey(EventMode::kEditMode, key, mod);

  switch(event)
  {
    case Event::MoveLeftChar:
      if(_selectSize)
        handled = setCaretPos(selectStartPos());
      else if(_caretPos > 0)
        handled = setCaretPos(_caretPos - 1);
      _selectSize = 0;
      break;

    case Event::MoveRightChar:
      if(_selectSize)
        handled = setCaretPos(selectEndPos());
      else if(_caretPos < static_cast<int>(_editString.size()))
        handled = setCaretPos(_caretPos + 1);
      _selectSize = 0;
      break;

    case Event::MoveLeftWord:
      handled = moveWord(-1, false);
      _selectSize = 0;
      break;

    case Event::MoveRightWord:
      handled = moveWord(+1, false);
      _selectSize = 0;
      break;

    case Event::MoveHome:
      handled = setCaretPos(0);
      _selectSize = 0;
      break;

    case Event::MoveEnd:
      handled = setCaretPos(static_cast<int>(_editString.size()));
      _selectSize = 0;
      break;

    case Event::SelectLeftChar:
      if(_caretPos > 0)
        handled = moveCaretPos(-1);
      break;

    case Event::SelectRightChar:
      if(_caretPos < static_cast<int>(_editString.size()))
        handled = moveCaretPos(+1);
      break;

    case Event::SelectLeftWord:
      handled = moveWord(-1, true);
      break;

    case Event::SelectRightWord:
      handled = moveWord(+1, true);
      break;

    case Event::SelectHome:
      handled = moveCaretPos(-_caretPos);
      break;

    case Event::SelectEnd:
      handled = moveCaretPos(static_cast<int>(_editString.size()) - _caretPos);
      break;

    case Event::SelectAll:
      if(setCaretPos(static_cast<int>(_editString.size())))
        _selectSize = -static_cast<int>(_editString.size());
      break;

    case Event::Backspace:
      handled = killSelectedText();
      if(!handled)
        handled = killChar(-1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::Delete:
      handled = killSelectedText();
      if(!handled)
        handled = killChar(+1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::DeleteLeftWord:
      handled = killWord(-1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::DeleteRightWord:
      handled = killWord(+1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::DeleteEnd:
      handled = killLine(+1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::DeleteHome:
      handled = killLine(-1);
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::Cut:
      handled = cutSelectedText();
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::Copy:
      handled = copySelectedText();
      break;

    case Event::Paste:
      handled = pasteSelectedText();
      if(handled)
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      break;

    case Event::Undo:
    case Event::Redo:
    {
      const string oldString = _editString;

      myUndoHandler->endChars(_editString);
      // Reverse Y and Z for QWERTZ keyboards
      if(event == Event::Redo)
        handled = myUndoHandler->redo(_editString);
      else
        handled = myUndoHandler->undo(_editString);

      if(handled)
      {
        // Put caret at last difference
        myUndoHandler->lastDiff(_editString, oldString);
        setCaretPos(myUndoHandler->lastDiff(_editString, oldString));
        _selectSize = 0;
        sendCommand(EditableWidget::kChangedCmd, key, _id);
      }
      break;
    }

    case Event::EndEdit:
      // confirm edit and exit editmode
      endEditMode();
      sendCommand(EditableWidget::kAcceptCmd, 0, _id);
      break;

    case Event::AbortEdit:
      handled = isChanged();
      abortEditMode();
      sendCommand(EditableWidget::kCancelCmd, 0, _id);
      break;

    default:
      handled = false;
      break;
  }

  if(handled)
  {
    myUndoHandler->endChars(_editString);
    setDirty();
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EditableWidget::getCaretOffset() const
{
  int caretOfs = 0;
  for (int i = 0; i < _caretPos; i++)
    caretOfs += _font.getCharWidth(_editString[i]);

  caretOfs -= _editScrollOffset;

  return caretOfs;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditableWidget::drawCaretSelection()
{
  // Only draw if item is visible
  if (!_editable || !isVisible() || !_boss->isVisible() || !_hasFocus)
    return;

  // Draw the selection
  if(_selectSize)
  {
    FBSurface& s = _boss->dialog().surface();
    const Common::Rect& editRect = getEditRect();
    string text = selectString();

    int x = editRect.x();
    int y = editRect.y();
    int w = editRect.w();
    const int h = editRect.h();
    int wt = static_cast<int>(text.length()) * _boss->dialog().fontWidth() + 1;
    int dx = selectStartPos() * _boss->dialog().fontWidth() - _editScrollOffset;

    if(dx < 0)
    {
      // selected text starts left of displayed rect
      text = text.substr(-(dx - 1) / _boss->dialog().fontWidth());
      wt += dx;
      dx = 0;
    }
    else
      x += dx;
    // limit selection to the right of displayed rect
    w = std::min(w - dx + 1, wt);

    x += _x;
    y += _y;

    s.fillRect(x - 1, y + 1, w + 1, h - 3, kTextColorHi);
    s.drawString(_font, text, x, y + 1 + _dyText, w, h,
                 kTextColorInv, TextAlign::Left, 0, false);
  }

  // Draw the caret
  if(_caretEnabled ^ (_selectSize != 0))
  {
    FBSurface& s = _boss->dialog().surface();
    const Common::Rect& editRect = getEditRect();
    int x = editRect.x();
    int y = editRect.y();
    const ColorId color = _caretEnabled ? kTextColorHi : kTextColorInv;

    x += getCaretOffset();
    x += _x;
    y += _y;

    s.vLine(x, y + 1, y + editRect.h() - 3, color);
    s.vLine(x - 1, y + 1, y + editRect.h() - 3, color);
    clearDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::setCaretPos(int newPos)
{
  assert(newPos >= 0 && newPos <= int(_editString.size()));
  _caretPos = newPos;

  _caretTimer = 0;
  _caretEnabled = true;

  return adjustOffset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::moveCaretPos(int direction)
{
  if(setCaretPos(_caretPos + direction))
  {
    _selectSize -= direction;
    _caretTimer = 0;
    _caretEnabled = true;
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::adjustOffset()
{
  // check if the caret is still within the textbox; if it isn't,
  // adjust _editScrollOffset

  // For some reason (differences in ScummVM event handling??),
  // this method should always return true.

  const int caretOfs = getCaretOffset();
  const int editWidth = getEditRect().w();

  if (caretOfs < 0)
  {
    // scroll left
    _editScrollOffset += caretOfs;
  }
  else if (caretOfs >= editWidth)
  {
    // scroll right
    _editScrollOffset -= (editWidth - caretOfs);
  }
  else if (_editScrollOffset > 0)
  {
    const int strWidth = _font.getStringWidth(_editString);
    if (strWidth - _editScrollOffset < editWidth)
    {
      // scroll right
      _editScrollOffset = (strWidth - editWidth);
      if (_editScrollOffset < 0)
        _editScrollOffset = 0;
    }
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EditableWidget::scrollOffset() const
{
  return _editable ? -_editScrollOffset : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::killChar(int direction, bool addEdit)
{
  bool handled = false;

  if(direction == -1)      // Delete previous character (backspace)
  {
    if(_caretPos > 0)
    {
      _caretPos--;
      if(_selectSize < 0)
        _selectSize++;
      handled = true;
    }
  }
  else if(direction == 1)  // Delete next character (delete)
  {
    if(_caretPos < static_cast<int>(_editString.size()))
    {
      if(_selectSize > 0)
        _selectSize--;
      handled = true;
    }
  }

  if(handled)
  {
    myUndoHandler->endChars(_editString);
    _editString.erase(_caretPos, 1);
    setCaretPos(_caretPos);

    if(addEdit)
      myUndoHandler->doo(_editString);
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::killLine(int direction)
{
  int count = 0;

  if(direction == -1)  // erase from current position to beginning of line
    count = _caretPos;
  else if(direction == +1)  // erase from current position to end of line
    count = static_cast<int>(_editString.size()) - _caretPos;

  if(count > 0)
  {
    for(int i = 0; i < count; i++)
      killChar(direction, false);

    myUndoHandler->doo(_editString);
    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::killWord(int direction)
{
  bool space = true;
  int count = 0, currentPos = _caretPos;

  if(direction == -1)  // move to first character of previous word
  {
    while(currentPos > 0)
    {
      if(BSPF::isWhiteSpace(_editString[currentPos - 1]))
      {
        if(!space)
          break;
      }
      else
        space = false;

      currentPos--;
      count++;
    }
  }
  else if(direction == +1)  // move to first character of next word
  {
    while(currentPos < static_cast<int>(_editString.size()))
    {
      if(currentPos && BSPF::isWhiteSpace(_editString[currentPos - 1]))
      {
        if(!space)
          break;
      }
      else
        space = false;

      currentPos++;
      count++;
    }
  }

  if(count > 0)
  {
    for(int i = 0; i < count; i++)
      killChar(direction, false);

    myUndoHandler->doo(_editString);
    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::moveWord(int direction, bool select)
{
  bool handled = false;
  bool space = true;
  int currentPos = _caretPos;

  if(direction == -1)  // move to first character of previous word
  {
    while (currentPos > 0)
    {
      if (BSPF::isWhiteSpace(_editString[currentPos - 1]))
      {
        if (!space)
          break;
      }
      else
        space = false;

      currentPos--;
      if(select)
        _selectSize++;
    }
    setCaretPos(currentPos);
    handled = true;
  }
  else if(direction == +1)  // move to first character of next word
  {
    while (currentPos < static_cast<int>(_editString.size()))
    {
      if (currentPos && BSPF::isWhiteSpace(_editString[currentPos - 1]))
      {
        if (!space)
          break;
      }
      else
        space = false;

      currentPos++;
      if(select)
        _selectSize--;
    }
    setCaretPos(currentPos);
    handled = true;
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::markWord()
{
  _selectSize = 0;

  while(_caretPos + _selectSize < static_cast<int>(_editString.size()))
  {
    if(BSPF::isWhiteSpace(_editString[_caretPos + _selectSize]))
      break;
    _selectSize++;
  }

  while(_caretPos > 0)
  {
    if(BSPF::isWhiteSpace(_editString[_caretPos - 1]))
      break;
    _caretPos--;
    _selectSize++;
  }
  return _selectSize > 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string EditableWidget::selectString() const
{
  if(_selectSize)
  {
    int caretPos = _caretPos;
    int selectSize = _selectSize;

    if(selectSize < 0)
    {
      caretPos += selectSize;
      selectSize = -selectSize;
    }
    return _editString.substr(caretPos, selectSize);
  }
  return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EditableWidget::selectStartPos() const
{
  if(_selectSize < 0)
    return _caretPos + _selectSize;
  else
    return _caretPos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EditableWidget::selectEndPos() const
{
  if(_selectSize > 0)
    return _caretPos + _selectSize;
  else
    return _caretPos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::killSelectedText(bool addEdit)
{
  if(_selectSize)
  {
    myUndoHandler->endChars(_editString);
    if(_selectSize < 0)
    {
      _caretPos += _selectSize;
      _selectSize = -_selectSize;
    }
    _editString.erase(_caretPos, _selectSize);
    setCaretPos(_caretPos);
    _selectSize = 0;
    if(addEdit)
      myUndoHandler->doo(_editString);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::cutSelectedText()
{
  return copySelectedText() && killSelectedText();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::copySelectedText()
{
  const string selected = selectString();

  // only copy if anything is selected, else keep old copied text
  if(!selected.empty())
  {
    instance().eventHandler().copyText(selected);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EditableWidget::pasteSelectedText()
{
  const bool selected = !selectString().empty();
  string pasted;

  myUndoHandler->endChars(_editString);

  // retrieve the pasted text
  instance().eventHandler().pasteText(pasted);
  // remove the currently selected text
  killSelectedText(false);
  // insert filtered paste text instead
  ostringstream buf;
  bool lastOk = true; // only one filler char per invalid character (block)

  for(const auto c : pasted)
    if(_filter(tolower(c)))
    {
      buf << c;
      lastOk = true;
    }
    else
    {
      if(lastOk)
        buf << '_';
      lastOk = false;
    }

  _editString.insert(_caretPos, buf.str());
  // position cursor at the end of pasted text
  setCaretPos(_caretPos + static_cast<int>(buf.str().length()));

  if(selected || !pasted.empty())
  {
    myUndoHandler->doo(_editString);
    return true;
  }
  return false;
}
