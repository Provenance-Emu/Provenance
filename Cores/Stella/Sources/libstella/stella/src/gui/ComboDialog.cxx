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
#include "Control.hxx"
#include "Dialog.hxx"
#include "EventHandler.hxx"
#include "OSystem.hxx"
#include "PopUpWidget.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "ComboDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ComboDialog::ComboDialog(GuiObject* boss, const GUI::Font& font,
                         const VariantList& combolist)
  : Dialog(boss->instance(), boss->parent(), font, "Add...")
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  WidgetArray wid;

  // Get maximum width of popupwidget
  int pwidth = 0;
  for (const auto& s : combolist)
    pwidth = std::max(font.getStringWidth(s.first), pwidth);

  // Set real dimensions
  _w = 8 * fontWidth + pwidth + PopUpWidget::dropDownWidth(font) + HBORDER * 2;
  _h = 8 * (lineHeight + VGAP) + VGAP + buttonHeight + VBORDER * 2 + _th;
  int xpos = HBORDER, ypos = VBORDER + _th;

  // Add event popup for 8 events
  myEvents.fill(nullptr);
  const auto ADD_EVENT_POPUP = [&](int idx, string_view label)
  {
    myEvents[idx] = new PopUpWidget(this, font, xpos, ypos,
                        pwidth, lineHeight, combolist, label);
    wid.push_back(myEvents[idx]);
    ypos += lineHeight + VGAP;
  };
  ADD_EVENT_POPUP(0, "Event 1 ");
  ADD_EVENT_POPUP(1, "Event 2 ");
  ADD_EVENT_POPUP(2, "Event 3 ");
  ADD_EVENT_POPUP(3, "Event 4 ");
  ADD_EVENT_POPUP(4, "Event 5 ");
  ADD_EVENT_POPUP(5, "Event 6 ");
  ADD_EVENT_POPUP(6, "Event 7 ");
  ADD_EVENT_POPUP(7, "Event 8 ");

  // Add Defaults, OK and Cancel buttons
  addDefaultsOKCancelBGroup(wid, font);

  addToFocusList(wid);

  setHelpAnchor("Combo");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ComboDialog::show(Event::Type event, string_view name)
{
  // Make sure the event is allowed
  if(event >= Event::Combo1 && event <= Event::Combo16)
  {
    myComboEvent = event;
    setTitle("Add events for " + string{name});
    open();
  }
  else
    myComboEvent = Event::NoType;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ComboDialog::loadConfig()
{
  StringList events = instance().eventHandler().getComboListForEvent(myComboEvent);

  const size_t size = std::min<size_t>(events.size(), 8);
  for(size_t i = 0; i < size; ++i)
    myEvents[i]->setSelected("", events[i]);

  // Fill any remaining items to 'None'
  if(size < 8)
    for(size_t i = size; i < 8; ++i)
      myEvents[i]->setSelected("None", "-1");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ComboDialog::saveConfig()
{
  StringList events;
  for(int i = 0; i < 8; ++i)
    events.push_back(myEvents[i]->getSelectedTag().toString());

  instance().eventHandler().setComboListForEvent(myComboEvent, events);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ComboDialog::setDefaults()
{
  for(int i = 0; i < 8; ++i)
    myEvents[i]->setSelected("None", "-1");

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ComboDialog::handleCommand(CommandSender* sender, int cmd,
                                int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kDefaultsCmd:
      setDefaults();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}
