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

#ifndef CHEAT_CODE_DIALOG_HXX
#define CHEAT_CODE_DIALOG_HXX

class DialogContainer;
class CommandSender;
class Widget;
class ButtonWidget;
class StaticTextWidget;
class CheckListWidget;
class EditTextWidget;
class OptionsDialog;
class InputTextDialog;
class OSystem;

#include "Dialog.hxx"

class CheatCodeDialog : public Dialog
{
  public:
    CheatCodeDialog(OSystem& osystem, DialogContainer& parent,
                   const GUI::Font& font);
    ~CheatCodeDialog() override;

  protected:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void loadConfig() override;
    void saveConfig() override;

  private:
    void addCheat();
    void editCheat();
    void removeCheat();
    void addOneShotCheat();

  private:
    CheckListWidget* myCheatList{nullptr};
    unique_ptr<InputTextDialog> myCheatInput;

    ButtonWidget* myEditButton{nullptr};
    ButtonWidget* myRemoveButton{nullptr};

    enum {
      kAddCheatCmd       = 'CHTa',
      kEditCheatCmd      = 'CHTe',
      kAddOneShotCmd     = 'CHTo',
      kCheatAdded        = 'CHad',
      kCheatEdited       = 'CHed',
      kOneShotCheatAdded = 'CHoa',
      kRemCheatCmd       = 'CHTr'
    };

  private:
    // Following constructors and assignment operators not supported
    CheatCodeDialog() = delete;
    CheatCodeDialog(const CheatCodeDialog&) = delete;
    CheatCodeDialog(CheatCodeDialog&&) = delete;
    CheatCodeDialog& operator=(const CheatCodeDialog&) = delete;
    CheatCodeDialog& operator=(CheatCodeDialog&&) = delete;
};

#endif
