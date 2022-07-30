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

#include "Dialog.hxx"
#include "OSystem.hxx"
#include "Settings.hxx"
#include "CommandDialog.hxx"
#include "MinUICommandDialog.hxx"
#include "CommandMenu.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CommandMenu::CommandMenu(OSystem& osystem)
  : DialogContainer(osystem)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CommandMenu::~CommandMenu()
{
  delete myBaseDialog;  myBaseDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog* CommandMenu::baseDialog()
{
  if (myBaseDialog == nullptr) {
    if(myOSystem.settings().getBool("minimal_ui"))
      myBaseDialog = new MinUICommandDialog(myOSystem, *this);
    else
      myBaseDialog = new CommandDialog(myOSystem, *this);
  }

  return myBaseDialog;
}
