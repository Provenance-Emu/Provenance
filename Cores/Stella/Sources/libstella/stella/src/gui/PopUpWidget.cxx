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
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "ContextMenu.hxx"
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "PopUpWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PopUpWidget::PopUpWidget(GuiObject* boss, const GUI::Font& font,
                         int x, int y, int w, int h, const VariantList& items,
                         string_view label, int labelWidth, int cmd)
  : EditableWidget(boss, font, x, y - 1, w, h + 2),
    _label{label},
    _labelWidth{labelWidth}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_RETAIN_FOCUS
    | Widget::FLAG_TRACK_MOUSE;
  _bgcolor = kDlgColor;
  _bgcolorhi = kDlgColor;     // do not highlight the background
  _textcolor = kTextColor;
  _textcolorhi = kTextColor;  // do not highlight the label

  setTextFilter([](char c) {
    return (isprint(c) && c != '\"') || c == '\x1c' || c == '\x1d'; // DEGREE || ELLIPSIS
  });
  setEditable(false);

  if(!_label.empty() && _labelWidth == 0)
    _labelWidth = _font.getStringWidth(_label);

  setArrow();

  _w = w + _labelWidth + dropDownWidth(font); // 23

  // vertically center the arrows and text
  myTextY   = (_h - _font.getFontHeight()) / 2;
  myArrowsY = (_h - _arrowHeight) / 2;

  myMenu = make_unique<ContextMenu>(this, font, items, cmd,
                                    w + dropDownWidth(font));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setID(uInt32 id)
{
  myMenu->setID(id);

  Widget::setID(id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::addItems(const VariantList& items)
{
  myMenu->addItems(items);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setSelected(const Variant& tag, const Variant& def)
{
  myMenu->setSelected(tag, def);
  setText(myMenu->getSelectedName());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setSelectedIndex(int idx, bool changed)
{
  if(_changed != changed)
  {
    _changed = changed;
    setDirty();
  }
  myMenu->setSelectedIndex(idx);
  setText(myMenu->getSelectedName());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setSelectedMax(bool changed)
{
  if(_changed != changed)
  {
    _changed = changed;
    setDirty();
  }
  _changed = changed;
  myMenu->setSelectedMax();
  setText(myMenu->getSelectedName());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::clearSelection()
{
  myMenu->clearSelection();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int PopUpWidget::getSelected() const
{
  return myMenu->getSelected();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& PopUpWidget::getSelectedName() const
{
  return myMenu->getSelectedName();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setSelectedName(string_view name)
{
  myMenu->setSelectedName(name);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Variant& PopUpWidget::getSelectedTag() const
{
  return myMenu->getSelectedTag();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if(b == MouseButton::LEFT)
  {
    resetSelection();
    if(!isEditable() || x > _w - dropDownWidth(_font))
    {
      if(isEnabled() && !myMenu->isVisible())
      {
        // Add menu just underneath parent widget
        myMenu->show(getAbsX() + _labelWidth, getAbsY() + getHeight(),
                     dialog().surface().dstRect(), myMenu->getSelected());
      }
    }
    else
    {
      if(setCaretPos(toCaretPos(x)))
        setDirty();
    }
  }
  EditableWidget::handleMouseDown(x, y, b, clickCount);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::handleMouseWheel(int x, int y, int direction)
{
  if(isEnabled() && !myMenu->isVisible())
  {
    if(direction < 0)
      myMenu->sendSelectionUp();
    else
      myMenu->sendSelectionDown();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PopUpWidget::handleEvent(Event::Type e)
{
  if(!isEnabled())
    return false;

  switch(e)
  {
    case Event::UISelect:
      handleMouseDown(0, 0, MouseButton::LEFT, 0);
      return true;
    case Event::UIUp:
    case Event::UILeft:
    case Event::UIPgUp:
      return myMenu->sendSelectionUp();
    case Event::UIDown:
    case Event::UIRight:
    case Event::UIPgDown:
      return myMenu->sendSelectionDown();
    case Event::UIHome:
      return myMenu->sendSelectionFirst();
    case Event::UIEnd:
      return myMenu->sendSelectionLast();
    default:
      return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  // Intercept all events sent through the PromptWidget
  // They're likely from our ContextMenu, indicating a redraw is required
  setText(myMenu->getSelectedName());
  dialog().setDirty();

  // Pass the cmd on to our parent
  sendCommand(cmd, data, id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::setArrow()
{
  // Small down arrow
  static constexpr std::array<uInt32, 7> down_arrow = {
    0b100000001,
    0b110000011,
    0b111000111,
    0b011101110,
    0b001111100,
    0b000111000,
    0b000010000,
  };
  // Large down arrow
  static constexpr std::array<uInt32, 10> down_arrow_large = {
    0b1000000000001,
    0b1100000000011,
    0b1110000000111,
    0b1111000001111,
    0b0111100011110,
    0b0011110111100,
    0b0001111111000,
    0b0000111110000,
    0b0000011100000,
    0b0000001000000
  };

  if(_font.getFontHeight() < 24)
  {
    _textOfs = 3;
    _arrowWidth = 9;
    _arrowHeight = 7;
    _arrowImg = down_arrow.data();
  }
  else
  {
    _textOfs = 5;
    _arrowWidth = 13;
    _arrowHeight = 10;
    _arrowImg = down_arrow_large.data();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::drawWidget(bool hilite)
{
  FBSurface& s = dialog().surface();

  const int x = _x + _labelWidth;
  int w = _w - _labelWidth;

  // Draw the label, if any
  if(_labelWidth > 0)
    s.drawString(_font, _label, _x, _y + myTextY, _labelWidth,
                 isEnabled() ? _textcolor : kColor, TextAlign::Left);

  // Draw a thin frame around us.
  s.frameRect(x, _y, w, _h, isEnabled() && hilite ? kWidColorHi : kColor);
  if(isEnabled() && hilite)
    s.frameRect(x + w - (_arrowWidth * 2 - 1), _y, (_arrowWidth * 2 - 1), _h, kWidColorHi);

  // Fill the background
  const ColorId bgCol = isEditable() ? kWidColor : kDlgColor;
  s.fillRect(x + 1, _y + 1, w - (_arrowWidth * 2 - 1), _h - 2,
             _changed ? kDbgChangedColor : bgCol);
  s.fillRect(x + w - (_arrowWidth * 2 - 2), _y + 1, (_arrowWidth * 2 - 3), _h - 2,
             isEnabled() && hilite ? kBtnColorHi : bgCol);
  // Draw an arrow pointing down at the right end to signal this is a dropdown/popup
  s.drawBitmap(_arrowImg, x + w - (_arrowWidth * 1.5 - 1), _y + myArrowsY + 1,
               !isEnabled() ? kColor : kTextColor, _arrowWidth, _arrowHeight);

  // Draw the selected entry, if any
  const string& name = editString();
  const bool editable = isEditable();

  w -= dropDownWidth(_font);
  const TextAlign align = (_font.getStringWidth(name) > w && !editable) ?
                           TextAlign::Right : TextAlign::Left;
  adjustOffset();
  s.drawString(_font, name, x + _textOfs, _y + myTextY, w,
               !isEnabled() ? kColor : _changed ? kDbgChangedTextColor : kTextColor,
               align, editable ? -_editScrollOffset : 0, !editable);

  if(editable)
    drawCaretSelection();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect PopUpWidget::getEditRect() const
{
  return {
    static_cast<uInt32>(_labelWidth + _textOfs), 1,
    static_cast<uInt32>(_w - _textOfs - dropDownWidth(_font)),
    static_cast<uInt32>(_h)
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::endEditMode()
{
  // Editing is always enabled
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PopUpWidget::abortEditMode()
{
  // Editing is always enabled
}
