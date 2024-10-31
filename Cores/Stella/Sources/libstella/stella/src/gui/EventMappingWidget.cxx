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
#include "GuiObject.hxx"
#include "PopUpWidget.hxx"
#include "FrameBuffer.hxx"
#include "EventHandler.hxx"
#include "Event.hxx"
#include "EditTextWidget.hxx"
#include "StringListWidget.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "ComboDialog.hxx"
#include "Variant.hxx"

#include "EventMappingWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventMappingWidget::EventMappingWidget(GuiObject* boss, const GUI::Font& font,
                                       int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss)
{
  const int lineHeight   = boss->dialog().lineHeight(),
            fontWidth    = boss->dialog().fontWidth(),
            buttonHeight = boss->dialog().buttonHeight(),
            buttonWidth  = boss->dialog().buttonWidth("Defaults"),
            VBORDER      = boss->dialog().vBorder(),
            HBORDER      = boss->dialog().hBorder(),
            VGAP         = boss->dialog().vGap();
  constexpr int ACTION_LINES = 2;
  int xpos = HBORDER, ypos = VBORDER;
  const int listWidth = _w - buttonWidth - HBORDER * 2 - fontWidth;
  int listHeight = _h - (2 + ACTION_LINES) * lineHeight - VBORDER + 2;

  VariantList items;

  items.clear();
  VarList::push_back(items, "Emulation", Event::Group::Emulation);
  VarList::push_back(items, " Miscellaneous", Event::Group::Misc);
  VarList::push_back(items, " Video & Audio", Event::Group::AudioVideo);
  VarList::push_back(items, " States", Event::Group::States);
  VarList::push_back(items, " Console", Event::Group::Console);
  VarList::push_back(items, " Joystick", Event::Group::Joystick);
  VarList::push_back(items, " Paddles", Event::Group::Paddles);
  VarList::push_back(items, " Driving", Event::Group::Driving);
  VarList::push_back(items, " Keyboard", Event::Group::Keyboard);
  VarList::push_back(items, " Input Devices & Ports", Event::Group::Devices);
  VarList::push_back(items, " Combo", Event::Group::Combo);
  VarList::push_back(items, " Debug", Event::Group::Debug);
  VarList::push_back(items, "User Interface", Event::Group::Menu);

  myFilterPopup = new PopUpWidget(boss, font, xpos, ypos,
                                  listWidth - font.getStringWidth("Events ") - PopUpWidget::dropDownWidth(font),
                                  lineHeight, items, "Events ", 0, kFilterCmd);
  myFilterPopup->setTarget(this);
  addFocusWidget(myFilterPopup);
  ypos += lineHeight * 1.5;
  listHeight -= lineHeight * 1.5;

  myActionsList = new StringListWidget(boss, font, xpos, ypos, listWidth, listHeight);
  myActionsList->setTarget(this);
  myActionsList->setEditable(false);
  addFocusWidget(myActionsList);

  // Add remap, erase, cancel and default buttons
  xpos = _w - HBORDER - buttonWidth + 2;
  myMapButton = new ButtonWidget(boss, font, xpos, ypos,
                                 buttonWidth, buttonHeight,
                                 "Map" + ELLIPSIS, kStartMapCmd);
  myMapButton->setTarget(this);
  addFocusWidget(myMapButton);

  ypos += buttonHeight + VGAP;
  myCancelMapButton = new ButtonWidget(boss, font, xpos, ypos,
                                       buttonWidth, buttonHeight,
                                       "Cancel", kStopMapCmd);
  myCancelMapButton->setToolTip("Cancel current mapping.");
  myCancelMapButton->setTarget(this);
  myCancelMapButton->clearFlags(Widget::FLAG_ENABLED);
  addFocusWidget(myCancelMapButton);

  ypos += buttonHeight + VGAP * 2;
  myEraseButton = new ButtonWidget(boss, font, xpos, ypos,
                                   buttonWidth, buttonHeight,
                                   "Erase", kEraseCmd);
  myEraseButton->setTarget(this);
  myEraseButton->setToolTip("Erase any mapping for selected event.");
  addFocusWidget(myEraseButton);

  ypos += buttonHeight + VGAP;
  myResetButton = new ButtonWidget(boss, font, xpos, ypos,
                                   buttonWidth, buttonHeight,
                                   "Reset", kResetCmd);
  myResetButton->setToolTip("Reset mapping for selected event to defaults.");
  myResetButton->setTarget(this);
  addFocusWidget(myResetButton);

  ypos += buttonHeight + VGAP * 2;
  myComboButton = new ButtonWidget(boss, font, xpos, ypos,
                                    buttonWidth, buttonHeight,
                                    "Combo" + ELLIPSIS, kComboCmd);
  myComboButton->setTarget(this);
  addFocusWidget(myComboButton);

  myComboDialog = make_unique<ComboDialog>(boss, font, EventHandler::getComboList());

  // Show message for currently selected event
  xpos = HBORDER;
  ypos = myActionsList->getBottom() + VGAP * 2;
  auto* t = new StaticTextWidget(boss, font, xpos, ypos+2, "Action");

  myKeyMapping = new EditTextWidget(boss, font, xpos + t->getWidth() + fontWidth, ypos,
                                    _w - xpos - t->getWidth() - fontWidth - HBORDER + 2,
                                    lineHeight + font.getFontHeight() * (ACTION_LINES - 1), "");
  myKeyMapping->setEditable(false, true);
  myKeyMapping->clearFlags(Widget::FLAG_RETAIN_FOCUS);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::loadConfig()
{
  if(myFirstTime)
  {
    myFilterPopup->setSelectedIndex(0);
    myFirstTime = false;
  }

  // Make sure remapping is turned off, just in case the user didn't properly
  // exit last time
  if(myRemapStatus)
    stopRemapping();

  updateActions();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::saveConfig()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::updateActions()
{
  myEventGroup = static_cast<Event::Group>(myFilterPopup->getSelectedTag().toInt());
  myEventMode = myEventGroup == Event::Group::Menu
    ? EventMode::kMenuMode
    : EventMode::kEmulationMode;

  myActionsList->setList(EventHandler::getActionList(myEventGroup));
  myActionSelected = myActionsList->getSelected();
  drawKeyMapping();
  enableButtons(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::setDefaults()
{
  instance().eventHandler().setDefaultMapping(Event::NoType, myEventMode);
  drawKeyMapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::startRemapping()
{
  if(myActionSelected < 0 || myRemapStatus)
    return;

  // Set the flags for the next event that arrives
  myRemapStatus = true;

  // Reset all previous events for determining correct axis/hat values
  myLastStick = -1;
  myLastButton = JOY_CTRL_NONE;
  myLastAxis = JoyAxis::NONE;
  myLastDir = JoyDir::NONE;
  myLastHat = -1;
  myLastHatDir = JoyHatDir::CENTER;

  // Reset the previously aggregated key mappings
  myMod = myLastKey = 0;

  // Disable all other widgets while in remap mode, except enable 'Cancel'
  enableButtons(false);

  // And show a message indicating which key is being remapped
  ostringstream buf;
  buf << "Select action for '"
      << EventHandler::actionAtIndex(myActionSelected, myEventGroup)
      << "' event";
  myKeyMapping->setTextColor(kTextColorEm);
  myKeyMapping->setText(buf.str());

  // Make sure that this widget receives all raw data, before any
  // pre-processing occurs
  myActionsList->setFlags(Widget::FLAG_WANTS_RAWDATA);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::eraseRemapping()
{
  if(myActionSelected < 0)
    return;

  const Event::Type event =
    EventHandler::eventAtIndex(myActionSelected, myEventGroup);
  instance().eventHandler().eraseMapping(event, myEventMode);

  drawKeyMapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::resetRemapping()
{
  if(myActionSelected < 0)
    return;

  const Event::Type event =
    EventHandler::eventAtIndex(myActionSelected, myEventGroup);
  instance().eventHandler().setDefaultMapping(event, myEventMode);

  drawKeyMapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::stopRemapping()
{
  // Turn off remap mode
  myRemapStatus = false;

  // Reset all previous events for determining correct axis/hat values
  myLastStick = -1;
  myLastButton = JOY_CTRL_NONE;
  myLastAxis = JoyAxis::NONE;
  myLastDir = JoyDir::NONE;
  myLastHat = -1;
  myLastHatDir = JoyHatDir::CENTER;

  // And re-enable all the widgets
  enableButtons(true);

  // Make sure the list widget is in a known state
  drawKeyMapping();

  // Widget is now free to process events normally
  myActionsList->clearFlags(Widget::FLAG_WANTS_RAWDATA);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::drawKeyMapping()
{
  if(myActionSelected >= 0)
  {
    myKeyMapping->setTextColor(kTextColor);
    myKeyMapping->setText(EventHandler::keyAtIndex(myActionSelected, myEventGroup));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::enableButtons(bool state)
{
  myActionsList->setEnabled(state);
  myMapButton->setEnabled(state);
  myCancelMapButton->setEnabled(!state);
  myEraseButton->setEnabled(state);
  myResetButton->setEnabled(state);

  const Event::Type e = EventHandler::eventAtIndex(myActionSelected, myEventGroup);

  myComboButton->setEnabled(state && e >= Event::Combo1 && e <= Event::Combo16);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventMappingWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  // Remap keys in remap mode
  if (myRemapStatus && myActionSelected >= 0)
  {
    // Mod keys are only recorded if no other key has been recorded before
    if (key < KBDK_LCTRL || key > KBDK_RGUI
      || (!myLastKey || (myLastKey >= KBDK_LCTRL && myLastKey <= KBDK_RGUI)))
    {
      myLastKey = key;
    }
    myMod |= mod;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventMappingWidget::handleKeyUp(StellaKey key, StellaMod mod)
{
  // Remap keys in remap mode
  if (myRemapStatus && myActionSelected >= 0
    && (mod & (KBDM_CTRL | KBDM_SHIFT | KBDM_ALT | KBDM_GUI)) == 0)
  {
    const Event::Type event =
      EventHandler::eventAtIndex(myActionSelected, myEventGroup);

    // if not pressed alone, map left and right modifier keys
    if(myLastKey < KBDK_LCTRL || myLastKey > KBDK_RGUI)
    {
      if(myMod & KBDM_CTRL)
        myMod |= KBDM_CTRL;
      if(myMod & KBDM_SHIFT)
        myMod |= KBDM_SHIFT;
      if(myMod & KBDM_ALT)
        myMod |= KBDM_ALT;
      if(myMod & KBDM_GUI)
        myMod |= KBDM_GUI;
    }
    if (instance().eventHandler().addKeyMapping(event, myEventMode,
        static_cast<StellaKey>(myLastKey), static_cast<StellaMod>(myMod)))
      stopRemapping();
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::handleJoyDown(int stick, int button, bool longPress)
{
  // Remap joystick buttons in remap mode
  if(myRemapStatus && myActionSelected >= 0)
  {
    myLastStick = stick;
    myLastButton = button;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::handleJoyUp(int stick, int button)
{
  // Remap joystick buttons in remap mode
  if (myRemapStatus && myActionSelected >= 0)
  {
    if (myLastStick == stick && myLastButton == button)
    {
      EventHandler& eh = instance().eventHandler();
      const Event::Type event =
          EventHandler::eventAtIndex(myActionSelected, myEventGroup);

      // map either button/hat, solo button or button/axis combinations
      if(myLastHat != -1)
      {
        if(eh.addJoyHatMapping(event, myEventMode, stick, button, myLastHat, myLastHatDir))
          stopRemapping();
      }
      else
        if (eh.addJoyMapping(event, myEventMode, stick, button, myLastAxis, myLastDir))
          stopRemapping();
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button)
{
  // Remap joystick axes in remap mode
  // There are two phases to detection:
  //   First, detect an axis 'on' event
  //   Then, detect the same axis 'off' event
  if(myRemapStatus && myActionSelected >= 0)
  {
    // Detect the first axis event that represents 'on'
    if((myLastStick == -1 || myLastStick == stick) && myLastAxis == JoyAxis::NONE && adir != JoyDir::NONE)
    {
      myLastStick = stick;
      myLastAxis = axis;
      myLastDir = adir;
    }
    // Detect the first axis event that matches a previously set
    // stick and axis, but turns the axis 'off'
    else if(myLastStick == stick && axis == myLastAxis && adir == JoyDir::NONE)
    {
      EventHandler& eh = instance().eventHandler();
      const Event::Type event =
          EventHandler::eventAtIndex(myActionSelected, myEventGroup);

      if(eh.addJoyMapping(event, myEventMode, stick, myLastButton, axis, myLastDir))
        stopRemapping();
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventMappingWidget::handleJoyHat(int stick, int hat, JoyHatDir hdir, int button)
{
  // Remap joystick hats in remap mode
  // There are two phases to detection:
  //   First, detect a hat direction event
  //   Then, detect the same hat 'center' event
  if(myRemapStatus && myActionSelected >= 0)
  {
    // Detect the first hat event that represents a valid direction
    if((myLastStick == -1 || myLastStick == stick) && myLastHat == -1 && hdir != JoyHatDir::CENTER)
    {
      myLastStick = stick;
      myLastHat = hat;
      myLastHatDir = hdir;

      return true;
    }
    // Detect the first hat event that matches a previously set
    // stick and hat, but centers the hat
    else if(myLastStick == stick && hat == myLastHat && hdir == JoyHatDir::CENTER)
    {
      EventHandler& eh = instance().eventHandler();
      const Event::Type event =
          EventHandler::eventAtIndex(myActionSelected, myEventGroup);

      if(eh.addJoyHatMapping(event, myEventMode, stick, myLastButton, hat, myLastHatDir))
      {
        stopRemapping();
        return true;
      }
    }
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventMappingWidget::handleCommand(CommandSender* sender, int cmd,
                                       int data, int id)
{
  switch(cmd)
  {
    case kFilterCmd:
      updateActions();
      break;

    case ListWidget::kSelectionChangedCmd:
      if(myActionsList->getSelected() >= 0)
      {
        myActionSelected = myActionsList->getSelected();
        drawKeyMapping();
        enableButtons(true);
      }
      break;

    case ListWidget::kDoubleClickedCmd:
      if(myActionsList->getSelected() >= 0)
      {
        myActionSelected = myActionsList->getSelected();
        startRemapping();
      }
      break;

    case kStartMapCmd:
      startRemapping();
      break;

    case kStopMapCmd:
      stopRemapping();
      break;

    case kEraseCmd:
      eraseRemapping();
      break;

    case kResetCmd:
      resetRemapping();
      break;

    case kComboCmd:
      if(myComboDialog)
        myComboDialog->show(
          EventHandler::eventAtIndex(myActionSelected, myEventGroup),
          EventHandler::actionAtIndex(myActionSelected, myEventGroup));
      break;

    default:
      break;
  }
}
