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

#ifndef COMMAND_DIALOG_HXX
#define COMMAND_DIALOG_HXX

class CommandSender;
class DialogContainer;
class OSystem;

#include "Dialog.hxx"

class CommandDialog : public Dialog
{
  public:
    CommandDialog(OSystem& osystem, DialogContainer& parent);
    ~CommandDialog() override = default;

  protected:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateSlot(int slot);
    void updateTVFormat();
    void updatePalette();
    void processCancel() override;

    // column 0
    ButtonWidget* myColorButton{nullptr};
    ButtonWidget* myLeftDiffButton{nullptr};
    ButtonWidget* myRightDiffButton{nullptr};
    // column 1
    ButtonWidget* mySaveStateButton{nullptr};
    ButtonWidget* myStateSlotButton{nullptr};
    ButtonWidget* myLoadStateButton{nullptr};
    ButtonWidget* myTimeMachineButton{nullptr};
    // column 2
    ButtonWidget* myTVFormatButton{nullptr};
    ButtonWidget* myPaletteButton{nullptr};
    ButtonWidget* myPhosphorButton{nullptr};
    ButtonWidget* mySoundButton{nullptr};

    enum {
      kSelectCmd      = 'Csel',
      kResetCmd       = 'Cres',
      kColorCmd       = 'Ccol',
      kLeftDiffCmd    = 'Cldf',
      kRightDiffCmd   = 'Crdf',
      kSaveStateCmd   = 'Csst',
      kStateSlotCmd   = 'Ccst',
      kLoadStateCmd   = 'Clst',
      kSnapshotCmd    = 'Csnp',
      kTimeMachineCmd = 'Ctim',
      kFormatCmd      = 'Cfmt',
      kPaletteCmd     = 'Cpal',
      kPhosphorCmd    = 'Cpho',
      kSoundCmd       = 'Csnd',
      kReloadRomCmd   = 'Crom',
      kExitCmd        = 'Clex'
    };

  private:
    // Following constructors and assignment operators not supported
    CommandDialog() = delete;
    CommandDialog(const CommandDialog&) = delete;
    CommandDialog(CommandDialog&&) = delete;
    CommandDialog& operator=(const CommandDialog&) = delete;
    CommandDialog& operator=(CommandDialog&&) = delete;
};

#endif
