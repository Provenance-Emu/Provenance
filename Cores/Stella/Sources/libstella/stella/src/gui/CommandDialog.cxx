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
#include "PaletteHandler.hxx"
#include "TIA.hxx"
#include "Switches.hxx"
#include "Dialog.hxx"
#include "Font.hxx"
#include "EventHandler.hxx"
#include "StateManager.hxx"
#include "OSystem.hxx"
#include "Widget.hxx"
#include "AudioSettings.hxx"
#include "Sound.hxx"
#include "TIASurface.hxx"
#include "CommandDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CommandDialog::CommandDialog(OSystem& osystem, DialogContainer& parent)
  : Dialog(osystem, parent, osystem.frameBuffer().font(), "Commands")
{
  const int buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = _font.getStringWidth("Time Machine On") + Dialog::fontWidth() * 2,
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
            //INDENT       = Dialog::indent();
  const int HGAP      = Dialog::buttonGap(),
            rowHeight = buttonHeight + VGAP;
  // Set real dimensions
  _w = 3 * (buttonWidth + HGAP) - HGAP + HBORDER * 2;
  _h = 6 * rowHeight - VGAP + VBORDER * 2 + _th;
  ButtonWidget* bw = nullptr;
  WidgetArray wid;
  int xoffset = HBORDER, yoffset = VBORDER + _th;

  const auto ADD_CD_BUTTON = [&](string_view label, int cmd,
    Event::Type event1 = Event::NoType, Event::Type event2 = Event::NoType)
  {
    auto* b = new ButtonWidget(this, _font, xoffset, yoffset,
        buttonWidth, buttonHeight, label, cmd);
    b->setToolTip(event1, event2);
    yoffset += buttonHeight + VGAP;
    return b;
  };

  // Column 1
  bw = ADD_CD_BUTTON(GUI::SELECT, kSelectCmd, Event::ConsoleSelect);
  wid.push_back(bw);
  bw = ADD_CD_BUTTON("Reset", kResetCmd, Event::ConsoleReset);
  wid.push_back(bw);
  myColorButton = ADD_CD_BUTTON("", kColorCmd, Event::ConsoleColor, Event::ConsoleBlackWhite);
  wid.push_back(myColorButton);
  myLeftDiffButton = ADD_CD_BUTTON("", kLeftDiffCmd,
    Event::ConsoleLeftDiffA, Event::ConsoleLeftDiffB);
  wid.push_back(myLeftDiffButton);
  myRightDiffButton = ADD_CD_BUTTON("", kRightDiffCmd,
    Event::ConsoleRightDiffA, Event::ConsoleRightDiffB);
  wid.push_back(myRightDiffButton);

  // Column 2
  xoffset += buttonWidth + HGAP;
  yoffset = VBORDER + _th;

  mySaveStateButton = ADD_CD_BUTTON("", kSaveStateCmd, Event::SaveState);
  wid.push_back(mySaveStateButton);
  myStateSlotButton = ADD_CD_BUTTON("Change Slot", kStateSlotCmd, Event::NextState);
  wid.push_back(myStateSlotButton);
  myLoadStateButton = ADD_CD_BUTTON("", kLoadStateCmd, Event::LoadState);
  wid.push_back(myLoadStateButton);
  bw = ADD_CD_BUTTON("Snapshot", kSnapshotCmd, Event::TakeSnapshot);
  wid.push_back(bw);
  myTimeMachineButton = ADD_CD_BUTTON("", kTimeMachineCmd, Event::TimeMachineMode);
  wid.push_back(myTimeMachineButton);
  bw = ADD_CD_BUTTON("Exit Game", kExitCmd, Event::ExitMode);
  wid.push_back(bw);

  // Column 3
  xoffset += buttonWidth + HGAP;
  yoffset = VBORDER + _th;

  myTVFormatButton = ADD_CD_BUTTON("", kFormatCmd, Event::FormatIncrease);
  wid.push_back(myTVFormatButton);
  myPaletteButton = ADD_CD_BUTTON("", kPaletteCmd, Event::PaletteIncrease);
  wid.push_back(myPaletteButton);
  myPhosphorButton = ADD_CD_BUTTON("", kPhosphorCmd, Event::TogglePhosphor);
  wid.push_back(myPhosphorButton);
  mySoundButton = ADD_CD_BUTTON("", kSoundCmd, Event::SoundToggle);
  wid.push_back(mySoundButton);
  bw = ADD_CD_BUTTON("Reload ROM", kReloadRomCmd, Event::ReloadConsole);
  wid.push_back(bw);

  addToFocusList(wid);

  // We don't have a close/cancel button, but we still want the cancel
  // event to be processed
  processCancelWithoutWidget(true);

  setHelpAnchor("CommandMenu");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CommandDialog::loadConfig()
{
  // Column 1
  myColorButton->setLabel(instance().console().switches().tvColor() ? "Color Mode" : "B/W Mode");
  myLeftDiffButton->setLabel(GUI::LEFT_DIFF + (instance().console().switches().leftDifficultyA() ? " A" : " B"));
  myRightDiffButton->setLabel(GUI::RIGHT_DIFF + (instance().console().switches().rightDifficultyA() ? " A" : " B"));
  // Column 2
  updateSlot(instance().state().currentSlot());
  myTimeMachineButton->setLabel(instance().state().mode() == StateManager::Mode::TimeMachine ?
                                "Time Machine On" : "No Time Machine");
  // Column 3
  updateTVFormat();
  updatePalette();
  myPhosphorButton->setLabel(instance().frameBuffer().tiaSurface().phosphorEnabled() ? "Phosphor On" : "Phosphor Off");
  mySoundButton->setLabel(instance().audioSettings().enabled() ? "Sound On" : "Sound Off");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CommandDialog::handleCommand(CommandSender* sender, int cmd,
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

    // Column 2
    case kSaveStateCmd:
      event = Event::SaveState;
      consoleCmd = true;
      break;

    case kStateSlotCmd:
    {
      event = Event::NextState;
      stateCmd = true;
      updateSlot((instance().state().currentSlot() + 1) % 10);
      break;
    }
    case kLoadStateCmd:
      event = Event::LoadState;
      consoleCmd = true;
      break;

    case kSnapshotCmd:
      instance().eventHandler().leaveMenuMode();
      instance().eventHandler().handleEvent(Event::TakeSnapshot);
      break;

    case kTimeMachineCmd:
      instance().eventHandler().leaveMenuMode();
      instance().toggleTimeMachine();
      break;

    case kExitCmd:
      instance().eventHandler().leaveMenuMode();
      instance().eventHandler().handleEvent(Event::ExitGame);
      break;

    // Column 3
    case kFormatCmd:
      instance().console().selectFormat();
      updateTVFormat();
      break;

    case kPaletteCmd:
      instance().frameBuffer().tiaSurface().paletteHandler().cyclePalette();
      updatePalette();
      break;

    case kPhosphorCmd:
      instance().eventHandler().leaveMenuMode();
      instance().console().togglePhosphor();
      break;

    case kSoundCmd:
    {
      instance().eventHandler().leaveMenuMode();
      instance().sound().toggleMute();
      break;
    }
    case kReloadRomCmd:
      instance().eventHandler().leaveMenuMode();
      instance().reloadConsole();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
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
void CommandDialog::processCancel()
{
  instance().eventHandler().leaveMenuMode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CommandDialog::updateSlot(int slot)
{
  ostringstream buf;
  buf << " " << slot;

  mySaveStateButton->setLabel("Save State" + buf.str());
  myLoadStateButton->setLabel("Load State" + buf.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CommandDialog::updateTVFormat()
{
  myTVFormatButton->setLabel(instance().console().getFormatString() + " Mode");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CommandDialog::updatePalette()
{
  string palette, label;

  palette = instance().settings().getString("palette");
  if(BSPF::equalsIgnoreCase(palette, PaletteHandler::SETTING_STANDARD))
    label = "Stella Palette";
  else if(BSPF::equalsIgnoreCase(palette, PaletteHandler::SETTING_Z26))
    label = "Z26 Palette";
  else if(BSPF::equalsIgnoreCase(palette, PaletteHandler::SETTING_USER))
    label = "User Palette";
  else
    label = "Custom Palette";
  myPaletteButton->setLabel(label);
}
