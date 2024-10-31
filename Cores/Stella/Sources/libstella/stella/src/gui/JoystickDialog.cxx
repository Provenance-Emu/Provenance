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
#include "Widget.hxx"
#include "Font.hxx"
#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "StringListWidget.hxx"
#include "Variant.hxx"
#include "JoystickDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
JoystickDialog::JoystickDialog(GuiObject* boss, const GUI::Font& font,
                               int max_w, int max_h)
  : Dialog(boss->instance(), boss->parent(), font, "Controller database", 0, 0, max_w, max_h)
{
  WidgetArray wid;
  const int lineHeight   = Dialog::lineHeight(),
            //fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Remove"),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();
  // Joystick list
  int xpos = HBORDER, ypos = VBORDER + _th;
  const int w = _w - 2 * xpos;
  const int h = _h - buttonHeight - ypos - VBORDER * 2;
  myJoyList = new StringListWidget(this, font, xpos, ypos, w, h);
  myJoyList->setEditable(false);
  wid.push_back(myJoyList);

  // Joystick ID
  ypos = _h - VBORDER - (buttonHeight + lineHeight) / 2;
  auto* t = new StaticTextWidget(this, font, xpos, ypos, "Controller ID ");
  xpos += t->getWidth();
  myJoyText = new EditTextWidget(this, font, xpos, ypos - 2,
      font.getStringWidth("Unplugged "), lineHeight, "");
  myJoyText->setEditable(false);

  // Port
  VariantList ports;
  VarList::push_back(ports, "Auto",  static_cast<Int32>(PhysicalJoystick::Port::AUTO));
  VarList::push_back(ports, "Left",  static_cast<Int32>(PhysicalJoystick::Port::LEFT));
  VarList::push_back(ports, "Right", static_cast<Int32>(PhysicalJoystick::Port::RIGHT));

  myJoyPort = new PopUpWidget(this, font, myJoyText->getRight() + fontWidth * 2, ypos - 1,
    font.getStringWidth("Right"), lineHeight, ports, "Port ", 0, kPortCmd);
  myJoyPort->setToolTip("Define default mapping port.");
  wid.push_back(myJoyPort);

  // Add buttons at bottom
  xpos = _w - buttonWidth - HBORDER;
  ypos = _h - VBORDER - buttonHeight;
  myCloseBtn = new ButtonWidget(this, font, xpos, ypos,
      buttonWidth, buttonHeight, "Close", GuiObject::kCloseCmd);
  addOKWidget(myCloseBtn);  addCancelWidget(myCloseBtn);

  xpos -= buttonWidth + fontWidth;
  myRemoveBtn = new ButtonWidget(this, font, xpos, ypos,
      buttonWidth, buttonHeight, "Remove", kRemoveCmd);
  myRemoveBtn->clearFlags(Widget::FLAG_ENABLED);

  // Now we can finally add the widgets to the focus list
  wid.push_back(myRemoveBtn);
  wid.push_back(myCloseBtn);
  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoystickDialog::loadConfig()
{
  myJoyIDs.clear();

  StringList sticks;
  for(const auto& _entry : instance().eventHandler().physicalJoystickList())
  {
    sticks.push_back(_entry.name);
    myJoyIDs.push_back(_entry.ID);
    myJoyPorts.push_back(static_cast<int>(_entry.port));
  }
  myJoyList->setList(sticks);
  myJoyList->setSelected(0);
  if(sticks.empty())
  {
    myRemoveBtn->setEnabled(false);
    myJoyText->setText("");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoystickDialog::handleEvent(Event::Type event)
{
  if(event == Event::Type::UIReload)
    loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoystickDialog::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      close();
      break;

    case kPortCmd:
      myJoyPorts[myJoyList->getSelected()] = myJoyPort->getSelected();
      instance().eventHandler().setPhysicalJoystickPortInDatabase(
          myJoyList->getSelectedString(),
          static_cast<PhysicalJoystick::Port>(myJoyPort->getSelected()));
      break;

    case kRemoveCmd:
      instance().eventHandler().removePhysicalJoystickFromDatabase(
          myJoyList->getSelectedString());
      loadConfig();
      break;

    case ListWidget::kSelectionChangedCmd:
    {
      const bool isPlugged = myJoyIDs[data] >= 0;
      if(isPlugged)
      {
        ostringstream buf;
        buf << "C" << myJoyIDs[data];
        myJoyText->setText(buf.str());
        myJoyPort->setSelected(myJoyPorts[data]);
      }
      else
      {
        myJoyText->setText("Unplugged");
        myJoyPort->setText("");
      }
      myJoyPort->setEnabled(isPlugged);
      myRemoveBtn->setEnabled(!isPlugged);
      break;
    }
    default:
      Dialog::handleCommand(sender, cmd, data, id);
      break;
  }
}
