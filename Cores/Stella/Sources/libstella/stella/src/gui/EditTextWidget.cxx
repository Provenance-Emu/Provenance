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

#include "FBSurface.hxx"
#include "Dialog.hxx"
#include "ToolTip.hxx"
#include "Font.hxx"
#include "EditTextWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EditTextWidget::EditTextWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int w, int h, string_view text)
  : EditableWidget(boss, font, x, y, w, h + 2, text)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG
    | Widget::FLAG_RETAIN_FOCUS | Widget::FLAG_TRACK_MOUSE;

  EditableWidget::startEditMode();  // We're always in edit mode

  if(_font.getFontHeight() < 24)
    _textOfs = 3;
  else
    _textOfs = 5;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::setText(string_view str, bool changed)
{
  EditableWidget::setText(str, changed);

  if(_changed != changed)
  {
    _changed = changed;
    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if(b == MouseButton::LEFT)
  {
    if(!isEditable())
      return;

    resetSelection();
    if(setCaretPos(toCaretPos(x)))
      setDirty();
  }
  EditableWidget::handleMouseDown(x, y, b, clickCount);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();

  // Highlight changes
  if(_changed)
    s.fillRect(_x, _y, _w, _h, kDbgChangedColor);
  else if(!isEditable() || !isEnabled())
    s.fillRect(_x, _y, _w, _h, kDlgColor);

  // Draw a thin frame around us.
  s.frameRect(_x, _y, _w, _h, hilite && isEditable() && isEnabled() ? kWidColorHi : kColor);

  // Draw the text
  adjustOffset();
  s.drawString(_font, editString(), _x + _textOfs, _y + 2, getEditRect().w(), getEditRect().h(),
               _changed && isEnabled()
               ? kDbgChangedTextColor
               : isEnabled() ? _textcolor : kColor,
               TextAlign::Left, scrollOffset(), !isEditable());

  // Draw the caret and selection
  drawCaretSelection();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect EditTextWidget::getEditRect() const
{
  return {
    static_cast<uInt32>(_textOfs), 1,
    static_cast<uInt32>(_w - _textOfs), static_cast<uInt32>(_h)
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::lostFocusWidget()
{
  EditableWidget::lostFocusWidget();
  // If we loose focus, 'commit' the user changes
  commit();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::startEditMode()
{
  EditableWidget::startEditMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::endEditMode()
{
  // Editing is always enabled
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EditTextWidget::abortEditMode()
{
  // Editing is always enabled
  abort();
}
