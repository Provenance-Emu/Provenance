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
#include "FrameBufferConstants.hxx"
#include "OptionsDialog.hxx"
#include "StellaSettingsDialog.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "bspf.hxx"
#include "OptionsMenu.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OptionsMenu::OptionsMenu(OSystem& osystem)
  : DialogContainer(osystem)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OptionsMenu::~OptionsMenu()
{
  delete stellaSettingDialog;  stellaSettingDialog = nullptr;
  delete optionsDialog;  optionsDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog* OptionsMenu::baseDialog()
{
  if (myOSystem.settings().getBool("basic_settings"))
  {
    if (stellaSettingDialog == nullptr)
      stellaSettingDialog = new StellaSettingsDialog(myOSystem, *this,
                                                     1280, 720, Dialog::AppMode::emulator);
    return stellaSettingDialog;
  }
  else
  {
    if (optionsDialog == nullptr)
      optionsDialog = new OptionsDialog(myOSystem, *this, nullptr,
        FBMinimum::Width, FBMinimum::Height, Dialog::AppMode::emulator);
    return optionsDialog;
  }
}
