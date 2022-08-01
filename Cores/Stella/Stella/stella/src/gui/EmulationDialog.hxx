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

#ifndef EMULATION_DIALOG_HXX
#define EMULATION_DIALOG_HXX

class RadioButtonGroup;

#include "Dialog.hxx"

class EmulationDialog : public Dialog
{
  public:
    EmulationDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font,
                    int max_w, int max_h);
    ~EmulationDialog() override = default;

  private:
    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    SliderWidget*     mySpeed{nullptr};
    CheckboxWidget*   myUseVSync{nullptr};
    CheckboxWidget*   myTurbo{nullptr};
    CheckboxWidget*   myUIMessages{nullptr};
    CheckboxWidget*   myFastSCBios{nullptr};
    CheckboxWidget*   myUseThreads{nullptr};
    CheckboxWidget*   myAutoPauseWidget{nullptr};
    CheckboxWidget*   myConfirmExitWidget{nullptr};
    RadioButtonGroup* mySaveOnExitGroup{nullptr};
    CheckboxWidget*   myAutoSlotWidget{nullptr};

    enum {
      kSpeedupChanged = 'EDSp',
    };

  private:
    // Following constructors and assignment operators not supported
    EmulationDialog() = delete;
    EmulationDialog(const EmulationDialog&) = delete;
    EmulationDialog(EmulationDialog&&) = delete;
    EmulationDialog& operator=(const EmulationDialog&) = delete;
    EmulationDialog& operator=(EmulationDialog&&) = delete;
};

#endif
