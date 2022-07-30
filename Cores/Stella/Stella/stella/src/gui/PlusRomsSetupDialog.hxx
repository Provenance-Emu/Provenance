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

#ifndef PLUSROMS_SETUP_DIALOG_HXX
#define PLUSROMS_SETUP_DIALOG_HXX

#include "InputTextDialog.hxx"

/**
  The dialog for PlusROMs setup.

  @author  Thomas Jentzsch
*/
class PlusRomsSetupDialog: public InputTextDialog
{
  public:
    PlusRomsSetupDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font);
    ~PlusRomsSetupDialog() override = default;

  protected:
    void loadConfig() override;
    void saveConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    // Following constructors and assignment operators not supported
    PlusRomsSetupDialog() = delete;
    PlusRomsSetupDialog(const PlusRomsSetupDialog&) = delete;
    PlusRomsSetupDialog(PlusRomsSetupDialog&&) = delete;
    PlusRomsSetupDialog& operator=(const PlusRomsSetupDialog&) = delete;
    PlusRomsSetupDialog& operator=(PlusRomsSetupDialog&&) = delete;
  };

#endif
