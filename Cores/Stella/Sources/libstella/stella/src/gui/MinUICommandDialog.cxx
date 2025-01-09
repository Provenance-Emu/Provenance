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

#include "Console.hxx"
#include "TIA.hxx"
#include "Switches.hxx"
#include "Dialog.hxx"
#include "Font.hxx"
#include "EventHandler.hxx"
#include "StateManager.hxx"
#include "RewindManager.hxx"
#include "HighScoresManager.hxx"
#include "HighScoresDialog.hxx"
#include "OSystem.hxx"
#include "Widget.hxx"
#include "StellaSettingsDialog.hxx"
#include "OptionsDialog.hxx"
#include "TIASurface.hxx"

#include "MinUICommandDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MinUICommandDialog::MinUICommandDialog(OSystem& osystem, DialogContainer& parent)
  : Dialog(osystem, parent, osystem.frameBuffer().font(), "Commands")
{
  constexpr int HBORDER = 10;
  constexpr int VBORDER = 10;
  constexpr int HGAP = 8;
  constexpr int VGAP = 5;

  const int buttonWidth = _font.getStringWidth(" Load State 0") + 20,
    buttonHeight = _font.getLineHeight() + 8,
    rowHeight = buttonHeight + VGAP;

  // Set real dimensions
  _w = 3 * (buttonWidth + 5) + HBORDER * 2;
  _h = 6 * rowHeight - VGAP + VBORDER * 2 + _th;
  ButtonWidget* bw = nullptr;
  WidgetArray wid;
  int xoffset = HBORDER, yoffset = VBORDER + _th;

  const auto ADD_CD_BUTTON = [&](string_view label, int cmd)
  {
    auto* b = new ButtonWidget(this, _font, xoffset, yoffset,
                               buttonWidth, buttonHeight, label, cmd);
    yoffset += buttonHeight + VGAP;
    return b;
  };

  // Column 1
  bw = ADD_CD_BUTTON(GUI::SELECT, kSelectCmd);
  wid.push_back(bw);
  bw = ADD_CD_BUTTON("Reset", kResetCmd);
  wid.push_back(bw);
  myColorButton = ADD_CD_BUTTON("", kColorCmd);
  wid.push_back(myColorButton);
  myLeftDiffButton = ADD_CD_BUTTON("", kLeftDiffCmd);
  wid.push_back(myLeftDiffButton);
  myRightDiffButton = ADD_CD_BUTTON("", kRightDiffCmd);
  wid.push_back(myRightDiffButton);
  myHighScoresButton = ADD_CD_BUTTON("Highscores" + ELLIPSIS, kHighScoresCmd);
  wid.push_back(myHighScoresButton);

  // Column 2
  xoffset += buttonWidth + HGAP;
  yoffset = VBORDER + _th;

  mySaveStateButton = ADD_CD_BUTTON("", kSaveStateCmd);
  wid.push_back(mySaveStateButton);
  myStateSlotButton = ADD_CD_BUTTON("Change Slot", kStateSlotCmd);
  wid.push_back(myStateSlotButton);
  myLoadStateButton = ADD_CD_BUTTON("", kLoadStateCmd);
  wid.push_back(myLoadStateButton);
  myRewindButton = ADD_CD_BUTTON("Rewind", kRewindCmd);
  wid.push_back(myRewindButton);
  myUnwindButton = ADD_CD_BUTTON("Unwind", kUnwindCmd);
  wid.push_back(myUnwindButton);
  bw = ADD_CD_BUTTON("Exit Game", kExitGameCmd);
  wid.push_back(bw);

  // Column 3
  xoffset += buttonWidth + HGAP;
  yoffset = VBORDER + _th;

  myTVFormatButton = ADD_CD_BUTTON("", kFormatCmd);
  wid.push_back(myTVFormatButton);
  myStretchButton = ADD_CD_BUTTON("", kStretchCmd);
  wid.push_back(myStretchButton);
  myPhosphorButton = ADD_CD_BUTTON("", kPhosphorCmd);
  wid.push_back(myPhosphorButton);
  bw = ADD_CD_BUTTON("Fry", kFry);
  wid.push_back(bw);
  bw = ADD_CD_BUTTON("Settings" + ELLIPSIS, kSettings);
  wid.push_back(bw);
  bw = ADD_CD_BUTTON("Close", GuiObject::kCloseCmd);
  wid.push_back(bw);

  ////  Bottom row
  //xoffset = HBORDER + (buttonWidth + HGAP) / 2;
  //bw = ADD_CD_BUTTON("Exit Game", kExitGameCmd);
  //wid.push_back(bw);
  //xoffset += buttonWidth + HGAP;
  //yoffset -= buttonHeight + VGAP;
  //bw = ADD_CD_BUTTON("Close", GuiObject::kCloseCmd);
  //wid.push_back(bw);

  addToFocusList(wid);

  // We don't have a close/cancel button, but we still want the cancel
  // event to be processed
  processCancelWithoutWidget(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::loadConfig()
{
  // Column 1
  myColorButton->setLabel(instance().console().switches().tvColor() ? "Color Mode" : "B/W Mode");
  myLeftDiffButton->setLabel(GUI::LEFT_DIFF + (instance().console().switches().leftDifficultyA() ? " A" : " B"));
  myRightDiffButton->setLabel(GUI::RIGHT_DIFF + (instance().console().switches().rightDifficultyA() ? " A" : " B"));
  myHighScoresButton->setEnabled(instance().highScores().enabled());

  // Column 2
  updateSlot(instance().state().currentSlot());
  updateWinds();

  // Column 3
  updateTVFormat();
  myStretchButton->setLabel(instance().settings().getBool("tia.fs_stretch") ? "Stretched" : "4:3 Format");
  myPhosphorButton->setLabel(instance().frameBuffer().tiaSurface().phosphorEnabled() ? "Phosphor On" : "Phosphor Off");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  switch (key)
  {
    case KBDK_F8: // front  ("Skill P2")
      instance().eventHandler().leaveMenuMode();
      break;

    default:
      Dialog::handleKeyDown(key, mod);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::handleCommand(CommandSender* sender, int cmd,
                                  int data, int id)
{
  bool consoleCmd = false, stateCmd = false;
  Event::Type event = Event::NoType;

  switch(cmd)
  {
    // Column 1
    case kSelectCmd:
      event = Event::ConsoleSelect;
      consoleCmd = true;
      break;

    case kResetCmd:
      event = Event::ConsoleReset;
      consoleCmd = true;
      break;

    case kColorCmd:
      event = Event::ConsoleColorToggle;
      consoleCmd = true;
      break;

    case kLeftDiffCmd:
      event = Event::ConsoleLeftDiffToggle;
      consoleCmd = true;
      break;

    case kRightDiffCmd:
      event = Event::ConsoleRightDiffToggle;
      consoleCmd = true;
      break;

    case kHighScoresCmd:
      openHighscores();
      break;

    // Column 2
    case kSaveStateCmd:
      event = Event::SaveState;
      consoleCmd = true;
      break;

    case kStateSlotCmd:
    {
      event = Event::NextState;
      stateCmd = true;
      const int slot = (instance().state().currentSlot() + 1) % 10;
      updateSlot(slot);
      break;
    }

    case kLoadStateCmd:
      event = Event::LoadState;
      consoleCmd = true;
      break;

    case kRewindCmd:
      // rewind 5s
      instance().state().rewindStates(5);
      updateWinds();
      break;

    case kUnwindCmd:
      // unwind 5s
      instance().state().unwindStates(5);
      updateWinds();
      break;

    // Column 3
    case kFormatCmd:
      instance().console().selectFormat();
      updateTVFormat();
      break;

    case kStretchCmd:
      instance().eventHandler().leaveMenuMode();
      instance().eventHandler().handleEvent(Event::VidmodeIncrease);
      break;

    case kPhosphorCmd:
      instance().eventHandler().leaveMenuMode();
      instance().console().togglePhosphor();
      break;

    case kFry:
      instance().eventHandler().leaveMenuMode();
      instance().console().fry();
      break;

    case kSettings:
      openSettings();
      break;

    // Bottom row
    case GuiObject::kCloseCmd:
      instance().eventHandler().leaveMenuMode();
      break;

    case kExitGameCmd:
      instance().eventHandler().leaveMenuMode();
      instance().eventHandler().handleEvent(Event::ExitGame);
      break;

    default:
      return;
  }

  // Console commands should be performed right away, after leaving the menu
  // State commands require you to exit the menu manually
  if(consoleCmd)
  {
    instance().eventHandler().leaveMenuMode();
    instance().eventHandler().handleEvent(event);
    instance().console().switches().update();
    instance().console().tia().update();
    instance().eventHandler().handleEvent(event, false);
  }
  else if(stateCmd)
    instance().eventHandler().handleEvent(event);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::processCancel()
{
  instance().eventHandler().leaveMenuMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::updateSlot(int slot)
{
  ostringstream buf;
  buf << " " << slot;

  mySaveStateButton->setLabel("Save State" + buf.str());
  myLoadStateButton->setLabel("Load State" + buf.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::updateTVFormat()
{
  myTVFormatButton->setLabel(instance().console().getFormatString() + " Mode");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::updateWinds()
{
  const RewindManager& r = instance().state().rewindManager();

  myRewindButton->setEnabled(!r.atFirst());
  myUnwindButton->setEnabled(!r.atLast());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::openSettings()
{
  // Create an options dialog, similar to the in-game one
  if (instance().settings().getBool("basic_settings"))
  {
    myDialog = make_unique<StellaSettingsDialog>(instance(), parent(),
                                                 1280, 720, AppMode::launcher);
    myDialog->open();
  }
  else
  {
    myDialog = make_unique<OptionsDialog>(instance(), parent(), this,
                                          FBMinimum::Width, FBMinimum::Height,
                                          AppMode::launcher);
    myDialog->open();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MinUICommandDialog::openHighscores()
{
  myDialog = make_unique<HighScoresDialog>(instance(), parent(),
                                           1280, 720, AppMode::emulator);
  myDialog->open();
}
