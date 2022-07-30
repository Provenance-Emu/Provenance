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

#ifndef OPTIONS_MENU_HXX
#define OPTIONS_MENU_HXX

class OSystem;
class StellaSettingsDialog;
class OptionsDialog;

#include "DialogContainer.hxx"

/**
  The base dialog for all configuration menus in Stella.

  @author  Stephen Anthony
*/
class OptionsMenu : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit OptionsMenu(OSystem& osystem);
    ~OptionsMenu() override;

  private:
    Dialog* baseDialog() override;
    StellaSettingsDialog* stellaSettingDialog{nullptr};
    OptionsDialog* optionsDialog{nullptr};

  private:
    // Following constructors and assignment operators not supported
    OptionsMenu() = delete;
    OptionsMenu(const OptionsMenu&) = delete;
    OptionsMenu(OptionsMenu&&) = delete;
    OptionsMenu& operator=(const OptionsMenu&) = delete;
    OptionsMenu& operator=(OptionsMenu&&) = delete;
};

#endif
