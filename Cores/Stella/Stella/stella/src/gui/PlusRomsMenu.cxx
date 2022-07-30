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
#include "FrameBuffer.hxx"
#include "PlusRomsSetupDialog.hxx"

#include "PlusRomsMenu.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PlusRomsMenu::PlusRomsMenu(OSystem& osystem)
  : DialogContainer(osystem)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PlusRomsMenu::~PlusRomsMenu()
{
  delete myPlusRomsSetupDialog;  myPlusRomsSetupDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog* PlusRomsMenu::baseDialog()
{
  return &plusRomsSetupDialog();
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PlusRomsSetupDialog& PlusRomsMenu::plusRomsSetupDialog()
{
  if(myPlusRomsSetupDialog == nullptr)
    myPlusRomsSetupDialog = new PlusRomsSetupDialog(myOSystem, *this, myOSystem.frameBuffer().font());

  return *myPlusRomsSetupDialog;
}
