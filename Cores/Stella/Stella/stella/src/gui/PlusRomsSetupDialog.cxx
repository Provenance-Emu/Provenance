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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "OSystem.hxx"
#include "EventHandler.hxx"

#include "PlusRomsSetupDialog.hxx"

static constexpr int MAX_NICK_LEN = 16;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PlusRomsSetupDialog::PlusRomsSetupDialog(OSystem& osystem, DialogContainer& parent,
                                         const GUI::Font& font)
  : InputTextDialog(osystem, parent, font, "Nickname", "PlusROM backends setup", MAX_NICK_LEN)
{
  EditableWidget::TextFilter filter = [](char c) {
    return isalnum(c) || (c == ' ') || (c == '_') || (c == '.');
  };

  setTextFilter(filter);
  setToolTip("Enter your PlusROM backends nickname here.");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusRomsSetupDialog::loadConfig()
{
  setText(instance().settings().getString("plusroms.nick"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusRomsSetupDialog::saveConfig()
{
  instance().settings().setValue("plusroms.nick", getResult());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusRomsSetupDialog::handleCommand(CommandSender* sender, int cmd,
                                        int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
    case EditableWidget::kAcceptCmd:
      saveConfig();
      instance().eventHandler().leaveMenuMode();
      break;

    case kCloseCmd:
      instance().eventHandler().leaveMenuMode();
      break;

    case EditableWidget::kCancelCmd:
      break;

    default:
      InputTextDialog::handleCommand(sender, cmd, data, id);
      break;
  }
}
