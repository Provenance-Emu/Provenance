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

#include "Dialog.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "MessageDialog.hxx"
#include "MessageMenu.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MessageMenu::MessageMenu(OSystem& osystem)
  : DialogContainer(osystem)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MessageMenu::~MessageMenu()
{
  delete myMessageDialog;  myMessageDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog* MessageMenu::baseDialog()
{
  if (myMessageDialog == nullptr)
    myMessageDialog = new MessageDialog(myOSystem, *this,
      myOSystem.frameBuffer().font(), FBMinimum::Width, FBMinimum::Height);

  return myMessageDialog;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageMenu::setMessage(string_view title, const StringList& text,
                             bool yesNo)
{
  MessageDialog::setMessage(title, text, yesNo);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MessageMenu::setMessage(string_view title, string_view text, bool yesNo)
{
  MessageDialog::setMessage(title, text, yesNo);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool MessageMenu::confirmed()
{
  if (myMessageDialog != nullptr)
    return myMessageDialog->confirmed();

  return false;
}
