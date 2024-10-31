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
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "EditTextWidget.hxx"
#include "GuiObject.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "Widget.hxx"
#include "InputTextDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
InputTextDialog::InputTextDialog(GuiObject* boss, const GUI::Font& font,
                                 const StringList& labels, string_view title)
  : Dialog(boss->instance(), boss->parent(), font, title),
    CommandSender(boss)
{
  initialize(font, font, labels);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
InputTextDialog::InputTextDialog(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont,
                                 const StringList& labels, string_view title)
  : Dialog(boss->instance(), boss->parent(), lfont, title),
    CommandSender(boss)
{
  initialize(lfont, nfont, labels);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
InputTextDialog::InputTextDialog(OSystem& osystem, DialogContainer& parent,
                                 const GUI::Font& font, const StringList& labels,
                                 string_view title, int widthChars)
  : Dialog(osystem, parent, font, title),
    CommandSender(nullptr)
{
  clear();
  initialize(font, font, labels, widthChars);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::initialize(const GUI::Font& lfont, const GUI::Font& nfont,
                                 const StringList& labels, int widthChars)
{
  const int lineHeight   = Dialog::lineHeight(),
            fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  uInt32 xpos = 0, lwidth = 0;
  WidgetArray wid;

  // Calculate real dimensions
  _w = HBORDER * 2 + fontWidth * widthChars;
  _h = buttonHeight + lineHeight + VGAP
    + static_cast<int>(labels.size()) * (lineHeight + VGAP)
    + _th + VBORDER * 2;

  // Determine longest label
  size_t maxIdx = 0;
  for(size_t i = 0; i < labels.size(); ++i)
  {
    if(labels[i].length() > lwidth)
    {
      lwidth = static_cast<int>(labels[i].length());
      maxIdx = i;
    }
  }
  if(!labels.empty())
    lwidth = lfont.getStringWidth(labels[maxIdx]);

  // Create editboxes for all labels
  int ypos = VBORDER + _th;
  for(const auto& label: labels)
  {
    xpos = HBORDER;
    auto* s = new StaticTextWidget(this, lfont, xpos, ypos + 2,
                                   lwidth, fontHeight, label);
    myLabel.push_back(s);

    xpos += lwidth + fontWidth;
    auto* w = new EditTextWidget(this, nfont, xpos, ypos,
                                 _w - xpos - HBORDER, lineHeight);
    wid.push_back(w);

    myInput.push_back(w);
    ypos += lineHeight + VGAP;
  }

  xpos = HBORDER; ypos += VGAP;
  myMessage = new StaticTextWidget(this, lfont, xpos, ypos, _w - 2 * xpos, fontHeight);
  myMessage->setTextColor(kTextColorEm);

  addToFocusList(wid);

  // Add OK and Cancel buttons
  wid.clear();
  addOKCancelBGroup(wid, lfont);
  addBGroupToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::show()
{
  myEnableCenter = true;
  open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::show(uInt32 x, uInt32 y, const Common::Rect& bossRect)
{
  const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();
  myXOrig = bossRect.x() + x * scale;
  myYOrig = bossRect.y() + y * scale;

  // Only show dialog if we're inside the visible area
  if(!bossRect.contains(myXOrig, myYOrig))
    return;

  myEnableCenter = false;
  open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setPosition()
{
  if(!myEnableCenter)
  {
    // First set position according to original coordinates
    surface().setDstPos(myXOrig, myYOrig);

    // Now make sure that the entire menu can fit inside the screen bounds
    // If not, we reset its position
    if(!instance().frameBuffer().screenRect().contains(
        myXOrig, myXOrig, surface().dstRect()))
      surface().setDstPos(myXOrig, myYOrig);
  }
  else
    Dialog::setPosition();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setMessage(string_view title)
{
  myMessage->setLabel(title);
  myErrorFlag = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& InputTextDialog::getResult(int idx)
{
  if(static_cast<uInt32>(idx) < myInput.size())
    return myInput[idx]->getText();
  else
    return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setText(string_view str, int idx)
{
  if(static_cast<uInt32>(idx) < myInput.size())
    myInput[idx]->setText(str);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setTextFilter(const EditableWidget::TextFilter& f, int idx)
{
  if(static_cast<uInt32>(idx) < myInput.size())
    myInput[idx]->setTextFilter(f);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setMaxLen(int len, int idx)
{
  myInput[idx]->setMaxLen(len);
  myInput[idx]->setWidth((len + 1) * Dialog::fontWidth());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setToolTip(string_view str, int idx)
{
  if(static_cast<uInt32>(idx) < myLabel.size())
    myLabel[idx]->setToolTip(str);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setFocus(int idx)
{
  if(static_cast<uInt32>(idx) < myInput.size())
    Dialog::setFocus(getFocusList()[idx]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::setEditable(bool editable, int idx)
{
  myInput[idx]->setEditable(editable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputTextDialog::handleCommand(CommandSender* sender, int cmd,
                                    int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
    case EditableWidget::kAcceptCmd:
    {
      // Send a signal to the calling class that a selection has been made
      // Since we aren't derived from a widget, we don't have a 'data' or 'id'
      if(myCmd)
        sendCommand(myCmd, 0, 0);

      // We don't close, but leave the parent to do it
      // If the data isn't valid, the parent may wait until it is
      break;
    }

    case EditableWidget::kChangedCmd:
      // Erase the invalid message once editing is restarted
      if(myErrorFlag)
      {
        myMessage->setLabel("");
        myErrorFlag = false;
      }
      break;

    case EditableWidget::kCancelCmd:
      Dialog::handleCommand(sender, GuiObject::kCloseCmd, data, id);
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, id);
      break;
  }
}
