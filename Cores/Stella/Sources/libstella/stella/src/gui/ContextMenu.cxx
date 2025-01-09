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
#include "EventHandler.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "ScrollBarWidget.hxx"
#include "PopUpWidget.hxx"
#include "ContextMenu.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ContextMenu::ContextMenu(GuiObject* boss, const GUI::Font& font,
                         const VariantList& items, int cmd, int width)
  : Dialog(boss->instance(), boss->parent(), font),
    CommandSender(boss),
    _rowHeight{font.getLineHeight()},
    _cmd{cmd},
    _maxWidth{width}
{
  setArrows();
  addItems(items);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::addItems(const VariantList& items)
{
  _entries.clear();
  _entries = items;

  // Resize to largest string
  int maxwidth = _maxWidth;
  for(const auto& e: _entries)
    maxwidth = std::max(maxwidth, _font.getStringWidth(e.first) + _textOfs * 2 + 2);

  _x = _y = 0;
  _w = maxwidth;
  _h = 1;  // recalculate this in ::recalc()

  _scrollUpColor = _firstEntry > 0 ? kScrollColor : kColor;
  _scrollDnColor = (_firstEntry + _numEntries < static_cast<int>(_entries.size())) ?
      kScrollColor : kColor;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::show(uInt32 x, uInt32 y, const Common::Rect& bossRect, int item)
{
  const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();
  _xorig = bossRect.x() + x * scale;
  _yorig = bossRect.y() + y * scale;

  // Only show menu if we're inside the visible area
  if(!bossRect.contains(_xorig, _yorig))
    return;

  recalc(instance().frameBuffer().imageRect());
  open();
  setSelectedIndex(item);
  moveToSelected();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setPosition()
{
  // First set position according to original coordinates
  surface().setDstPos(_xorig, _yorig);

  // Now make sure that the entire menu can fit inside the screen bounds
  // If not, we reset its position
  if(!instance().frameBuffer().screenRect().contains(
      _xorig, _yorig, surface().dstRect()))
    surface().setDstPos(_xorig, _yorig);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::recalc(const Common::Rect& image)
{
  // Now is the time to adjust the height
  // If it's higher than the screen, we need to scroll through
  const uInt32 maxentries = std::min<uInt32>(18, (image.h() - 2) / _rowHeight);
  if(_entries.size() > maxentries)
  {
    // We show two less than the max, so we have room for two scroll buttons
    _numEntries = maxentries - 2;
    _h = maxentries * _rowHeight + 2;
    _showScroll = true;
  }
  else
  {
    _numEntries = static_cast<int>(_entries.size());
    _h = static_cast<int>(_entries.size()) * _rowHeight + 2;
    _showScroll = false;
  }
  _isScrolling = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setSelectedIndex(int idx)
{
  if(idx >= 0 && idx < static_cast<int>(_entries.size()))
    _selectedItem = idx;
  else
    _selectedItem = -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setSelected(const Variant& tag, const Variant& defaultTag)
{
  const auto SEARCH_AND_SELECT = [&](const Variant& t)
  {
    for(uInt32 item = 0; item < _entries.size(); ++item)
    {
      if(BSPF::equalsIgnoreCase(_entries[item].second.toString(), t.toString()))
      {
        setSelectedIndex(item);
        return true;
      }
    }
    return false;
  };

  // First try searching for a valid tag
  const bool tagSelected = tag != "" && SEARCH_AND_SELECT(tag);

  // Otherwise use the default tag
  if(!tagSelected)
    SEARCH_AND_SELECT(defaultTag);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setSelectedMax()
{
  setSelectedIndex(static_cast<int>(_entries.size()) - 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::clearSelection()
{
  _selectedItem = -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int ContextMenu::getSelected() const
{
  return _selectedItem;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& ContextMenu::getSelectedName() const
{
  return (_selectedItem >= 0) ? _entries[_selectedItem].first : EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setSelectedName(string_view name)
{
  if(_selectedItem >= 0)
    _entries[_selectedItem].first = name;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Variant& ContextMenu::getSelectedTag() const
{
  return (_selectedItem >= 0) ? _entries[_selectedItem].second : EmptyVariant;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::sendSelectionUp()
{
  if(isVisible() || _selectedItem <= 0)
    return false;

  _selectedItem--;
  sendCommand(_cmd ? _cmd : ContextMenu::kItemSelectedCmd, _selectedItem, _id);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::sendSelectionDown()
{
  if(isVisible() || _selectedItem >= static_cast<int>(_entries.size()) - 1)
    return false;

  _selectedItem++;
  sendCommand(_cmd ? _cmd : ContextMenu::kItemSelectedCmd, _selectedItem, _id);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::sendSelectionFirst()
{
  if(isVisible())
    return false;

  _selectedItem = 0;
  sendCommand(_cmd ? _cmd : ContextMenu::kItemSelectedCmd, _selectedItem, _id);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::sendSelectionLast()
{
  if(isVisible())
    return false;

  _selectedItem = static_cast<int>(_entries.size()) - 1;
  sendCommand(_cmd ? _cmd : ContextMenu::kItemSelectedCmd, _selectedItem, _id);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  // Compute over which item the mouse is...
  const int item = findItem(x, y);

  // Only do a selection when the left button is in the dialog
  if(b == MouseButton::LEFT)
  {
    if(item != -1)
    {
      _isScrolling = _showScroll && ((item == 0) || (item == _numEntries+1));
      sendSelection();
    }
    else
      close();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleMouseMoved(int x, int y)
{
  // Compute over which item the mouse is...
  const int item = findItem(x, y);
  if(item == -1)
    return;

  // ...and update the selection accordingly
  drawCurrentSelection(item);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::handleMouseClicks(int x, int y, MouseButton b)
{
  // Let continuous mouse clicks come through, as the scroll buttons need them
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleMouseWheel(int x, int y, int direction)
{
  // Wheel events are only relevant in scroll mode
  if(_showScroll)
  {
    if(direction < 0)
      scrollUp(ScrollBarWidget::getWheelLines());
    else if(direction > 0)
      scrollDown(ScrollBarWidget::getWheelLines());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  handleEvent(instance().eventHandler().eventForKey(EventMode::kMenuMode, key, mod));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleJoyUp(int stick, int button)
{
  handleEvent(instance().eventHandler().eventForJoyButton(EventMode::kMenuMode, stick, button));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button)
{
  if(adir != JoyDir::NONE)  // we don't care about 'axis off' events
    handleEvent(instance().eventHandler().eventForJoyAxis(EventMode::kMenuMode, stick, axis, adir, button));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ContextMenu::handleJoyHat(int stick, int hat, JoyHatDir hdir, int button)
{
  handleEvent(instance().eventHandler().eventForJoyHat(EventMode::kMenuMode, stick, hat, hdir, button));
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::handleEvent(Event::Type e)
{
  switch(e)
  {
    case Event::UISelect:
      sendSelection();
      break;
    case Event::UIUp:
    case Event::UILeft:
      moveUp();
      break;
    case Event::UIDown:
    case Event::UIRight:
      moveDown();
      break;
    case Event::UIPgUp:
      movePgUp();
      break;
    case Event::UIPgDown:
      movePgDown();
      break;
    case Event::UIHome:
      moveToFirst();
      break;
    case Event::UIEnd:
      moveToLast();
      break;
    case Event::UICancel:
    case Event::UIOK:
      close();
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int ContextMenu::findItem(int x, int y) const
{
  if(x >= 0 && x < _w && y >= 0 && y < _h)
    return (y - 4) / _rowHeight;

  return -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::drawCurrentSelection(int item)
{
  // Change selection
  if(_selectedOffset != item)
  {
    _selectedOffset = item;
    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::sendSelection()
{
  // Select the correct item when scrolling; we have to take into account
  // that the viewable items are no longer 1-to-1 with the entries
  int item = _firstEntry + _selectedOffset;

  if(_showScroll)
  {
    if(_selectedOffset == 0)  // scroll up
    {
      scrollUp();  return;
    }
    else if(_selectedOffset == _numEntries+1) // scroll down
    {
      scrollDown();  return;
    }
    else if(_isScrolling)
      return;
    else
      item--;
  }

  // We remove the dialog when the user has selected an item
  // Make sure the dialog is removed before sending any commands,
  // since one consequence of sending a command may be to add another
  // dialog/menu
  close();

  // Send any command associated with the selection
  _selectedItem = item;
  sendCommand(_cmd ? _cmd : ContextMenu::kItemSelectedCmd, _selectedItem, _id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::moveUp()
{
  if(_showScroll)
  {
    // Reaching the top of the list means we have to scroll up, but keep the
    // current item offset
    // Otherwise, the offset should decrease by 1
    if(_selectedOffset == 1)
      scrollUp();
    else if(_selectedOffset > 1)
      drawCurrentSelection(_selectedOffset-1);
  }
  else
  {
    if(_selectedOffset > 0)
      drawCurrentSelection(_selectedOffset-1);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::moveDown()
{
  if(_showScroll)
  {
    // Reaching the bottom of the list means we have to scroll down, but keep the
    // current item offset
    // Otherwise, the offset should increase by 1
    if(_selectedOffset == _numEntries)
      scrollDown();
    else if(_selectedOffset < static_cast<int>(_entries.size()))
      drawCurrentSelection(_selectedOffset+1);
  }
  else
  {
    if(_selectedOffset < static_cast<int>(_entries.size()) - 1)
      drawCurrentSelection(_selectedOffset+1);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::movePgUp()
{
  if(_firstEntry == 0)
    moveToFirst();
  else
    scrollUp(_numEntries);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::movePgDown()
{
  if(_firstEntry == static_cast<int>(_entries.size() - _numEntries))
    moveToLast();
  else
    scrollDown(_numEntries);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::moveToFirst()
{
  _firstEntry = 0;
  _scrollUpColor = kColor;
  _scrollDnColor = kScrollColor;

  drawCurrentSelection(_firstEntry + (_showScroll ? 1 : 0));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::moveToLast()
{
  _firstEntry = static_cast<int>(_entries.size()) - _numEntries;
  _scrollUpColor = kScrollColor;
  _scrollDnColor = kColor;

  drawCurrentSelection(_numEntries - (_showScroll ? 0 : 1));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::moveToSelected()
{
  if(_selectedItem < 0 || _selectedItem >= static_cast<int>(_entries.size()))
    return;

  // First jump immediately to the item
  _firstEntry = _selectedItem;
  int offset = 0;

  // Now check if we've gone past the current 'window' size, and scale
  // back accordingly
  const int max_offset = static_cast<int>(_entries.size()) - _numEntries;
  if(_firstEntry > max_offset)
  {
    offset = _firstEntry - max_offset;
    _firstEntry -= offset;
  }

  _scrollUpColor = _firstEntry > 0 ? kScrollColor : kColor;
  _scrollDnColor = _firstEntry < max_offset ? kScrollColor : kColor;

  drawCurrentSelection(offset + (_showScroll ? 1 : 0));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::scrollUp(int distance)
{
  if(_firstEntry == 0)
    return;

  _firstEntry = std::max(_firstEntry - distance, 0);
  _scrollUpColor = _firstEntry > 0 ? kScrollColor : kColor;
  _scrollDnColor = kScrollColor;

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::scrollDown(int distance)
{
  const int max_offset = static_cast<int>(_entries.size()) - _numEntries;
  if(_firstEntry == max_offset)
    return;

  _firstEntry = std::min(_firstEntry + distance, max_offset);
  _scrollUpColor = kScrollColor;
  _scrollDnColor = _firstEntry < max_offset ? kScrollColor : kColor;

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::setArrows()
{
  static constexpr std::array<uInt32, 8> up_arrow = {
    0b00011000,
    0b00011000,
    0b00111100,
    0b00111100,
    0b01111110,
    0b01111110,
    0b11111111,
    0b11111111
  };
  static constexpr std::array<uInt32, 8> down_arrow = {
    0b11111111,
    0b11111111,
    0b01111110,
    0b01111110,
    0b00111100,
    0b00111100,
    0b00011000,
    0b00011000
  };

  static constexpr std::array<uInt32, 12> up_arrow_large = {
    0b000001100000,
    0b000001100000,
    0b000011110000,
    0b000011110000,
    0b000111111000,
    0b000111111000,
    0b001111111100,
    0b001111111100,
    0b011111111110,
    0b011111111110,
    0b111111111111,
    0b111111111111
  };
  static constexpr std::array<uInt32, 12> down_arrow_large = {
    0b111111111111,
    0b111111111111,
    0b011111111110,
    0b011111111110,
    0b001111111100,
    0b001111111100,
    0b000111111000,
    0b000111111000,
    0b000011110000,
    0b000011110000,
    0b000001100000,
    0b000001100000
  };

  if(_font.getFontHeight() < 24)
  {
    _textOfs = 2;
    _arrowSize = 8;
    _upImg = up_arrow.data();
    _downImg = down_arrow.data();
  }
  else
  {
    _textOfs = 4;
    _arrowSize = 12;
    _upImg = up_arrow_large.data();
    _downImg = down_arrow_large.data();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ContextMenu::drawDialog()
{
  // Normally we add widgets and let Dialog::draw() take care of this
  // logic.  But for some reason, this Dialog was written differently
  // by the ScummVM guys, so I'm not going to mess with it.
  FBSurface& s = surface();

  // Draw menu border and background
  s.fillRect(_x+1, _y+1, _w-2, _h-2, kWidColor);
  s.frameRect(_x, _y, _w, _h, kTextColor);

  // Draw the entries, taking scroll buttons into account
  const int x = _x + 1, w = _w - 2;
  int y = _y + 1;

  // Show top scroll area
  int offset = _selectedOffset;
  if(_showScroll)
  {
    s.hLine(x, y+_rowHeight-1, w+2, kColor);
    s.drawBitmap(_upImg, ((_w-_x)>>1)-4, (_rowHeight>>1)+y-4, _scrollUpColor, _arrowSize);
    y += _rowHeight;
    offset--;
  }

  for(int i = _firstEntry, current = 0; i < _firstEntry + _numEntries; ++i, ++current)
  {
    const bool hilite = offset == current;
    if(hilite) s.fillRect(x, y, w, _rowHeight, kTextColorHi);
    s.drawString(_font, _entries[i].first, x + _textOfs, y + 2, w,
                 !hilite ? kTextColor : kTextColorInv);
    y += _rowHeight;
  }

  // Show bottom scroll area
  if(_showScroll)
  {
    s.hLine(x, y, w+2, kColor);
    s.drawBitmap(_downImg, ((_w-_x)>>1)-4, (_rowHeight>>1)+y-4, _scrollDnColor, _arrowSize);
  }

  clearDirty();
}
