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
#include "Console.hxx"
#include "EventHandler.hxx"
#include "Font.hxx"
#include "MessageBox.hxx"
#include "StringParser.hxx"

#include "MessageDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MessageDialog::MessageDialog(OSystem& osystem, DialogContainer& parent,
                             const GUI::Font& font, int max_w, int max_h)
  : Dialog(osystem, parent, font)
{
  _w = _h = 10; // must not be 0
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MessageDialog::~MessageDialog()
{
  delete myMsg;  myMsg = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageDialog::loadConfig()
{
  // ugly, but I can't do better
  delete myMsg;

  myMsg = new GUI::MessageBox(this, _font, myText,
                              FBMinimum::Width, FBMinimum::Height, kOKCmd, kCloseCmd,
                              myYesNo ? "Yes" : "Ok", myYesNo ? "No" : "Cancel",
                              myTitle, true);
  myMsg->show();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageDialog::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch (cmd)
  {
    case kOKCmd:
    case kCloseCmd:
      myConfirmed = cmd == kOKCmd;
      instance().eventHandler().handleEvent(Event::ExitMode);
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageDialog::setMessage(string_view title, const StringList& text,
                               bool yesNo)
{
  myTitle = title;
  myText = text;
  myYesNo = yesNo;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageDialog::setMessage(string_view title, string_view text,
                               bool yesNo)
{
  setMessage(title, StringParser(text).stringList(), yesNo);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string MessageDialog::myTitle;
StringList MessageDialog::myText;
bool MessageDialog::myYesNo = false;
bool MessageDialog::myConfirmed = false;
