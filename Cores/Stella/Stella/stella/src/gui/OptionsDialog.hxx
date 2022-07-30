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

#ifndef OPTIONS_DIALOG_HXX
#define OPTIONS_DIALOG_HXX

class CommandSender;
class DialogContainer;
class GuiObject;
class OSystem;

#include "OptionsMenu.hxx"
#include "Dialog.hxx"

class OptionsDialog : public Dialog
{
  public:
    OptionsDialog(OSystem& osystem, DialogContainer& parent, GuiObject* boss,
                  int max_w, int max_h, AppMode mode);
    ~OptionsDialog() override;

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    unique_ptr<Dialog>           myDialog;

    ButtonWidget* myRomAuditButton{nullptr};
    ButtonWidget* myGameInfoButton{nullptr};
    ButtonWidget* myCheatCodeButton{nullptr};

    GuiObject* myBoss{nullptr};
    // Indicates if this dialog is used for global (vs. in-game) settings
    AppMode myMode{AppMode::emulator};

    enum {
      kBasSetCmd   = 'BAST',
      kVidCmd      = 'VIDO',
      kEmuCmd      = 'EMUO',
      kInptCmd     = 'INPT',
      kUsrIfaceCmd = 'URIF',
      kSnapCmd     = 'SNAP',
      kAuditCmd    = 'RAUD',
      kInfoCmd     = 'INFO',
      kCheatCmd    = 'CHET',
      kLoggerCmd   = 'LOGG',
      kDevelopCmd  = 'DEVL',
      kHelpCmd     = 'HELP',
      kAboutCmd    = 'ABOU',
      kExitCmd     = 'EXIM'
    };

  private:
    // Following constructors and assignment operators not supported
    OptionsDialog() = delete;
    OptionsDialog(const OptionsDialog&) = delete;
    OptionsDialog(OptionsDialog&&) = delete;
    OptionsDialog& operator=(const OptionsDialog&) = delete;
    OptionsDialog& operator=(OptionsDialog&&) = delete;
};

#endif
