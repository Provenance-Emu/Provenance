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

#ifndef MIN_UI_COMMAND_DIALOG_HXX
#define MIN_UI_COMMAND_DIALOG_HXX

class Properties;
class CommandSender;
class DialogContainer;
class OSystem;

#include "Dialog.hxx"

class MinUICommandDialog : public Dialog
{
  public:
    MinUICommandDialog(OSystem& osystem, DialogContainer& parent);
    ~MinUICommandDialog() override = default;

  protected:
    void loadConfig() override;
    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateSlot(int slot);
    void updateWinds();
    void updateTVFormat();
    void openSettings();
    void openHighscores();
    void processCancel() override;

    // column 0
    ButtonWidget* myColorButton{nullptr};
    ButtonWidget* myLeftDiffButton{nullptr};
    ButtonWidget* myRightDiffButton{nullptr};
    ButtonWidget* myHighScoresButton{nullptr};
    // column 1
    ButtonWidget* mySaveStateButton{nullptr};
    ButtonWidget* myStateSlotButton{nullptr};
    ButtonWidget* myLoadStateButton{nullptr};
    ButtonWidget* myRewindButton{nullptr};
    ButtonWidget* myUnwindButton{nullptr};
    // column 2
    ButtonWidget* myTVFormatButton{nullptr};
    ButtonWidget* myStretchButton{nullptr};
    ButtonWidget* myPhosphorButton{nullptr};

    unique_ptr<Dialog> myDialog;

    enum
    {
      kSelectCmd     = 'Csel',
      kResetCmd      = 'Cres',
      kColorCmd      = 'Ccol',
      kLeftDiffCmd   = 'Cldf',
      kRightDiffCmd  = 'Crdf',
      kHighScoresCmd = 'Chsc',
      kSaveStateCmd  = 'Csst',
      kStateSlotCmd  = 'Ccst',
      kLoadStateCmd  = 'Clst',
      kSnapshotCmd   = 'Csnp',
      kRewindCmd     = 'Crew',
      kUnwindCmd     = 'Cunw',
      kFormatCmd     = 'Cfmt',
      kStretchCmd    = 'Cstr',
      kPhosphorCmd   = 'Cpho',
      kSettings      = 'Cscn',
      kFry           = 'Cfry',
      kExitGameCmd   = 'Cext'
    };

  private:
    // Following constructors and assignment operators not supported
    MinUICommandDialog() = delete;
    MinUICommandDialog(const MinUICommandDialog&) = delete;
    MinUICommandDialog(MinUICommandDialog&&) = delete;
    MinUICommandDialog& operator=(const MinUICommandDialog&) = delete;
    MinUICommandDialog& operator=(MinUICommandDialog&&) = delete;
};

#endif
