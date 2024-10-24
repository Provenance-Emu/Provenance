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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef GLOBAL_PROPS_DIALOG_HXX
#define GLOBAL_PROPS_DIALOG_HXX

class CommandSender;
class DialogContainer;
class CheckboxWidget;
class PopUpWidget;
class OSystem;

#include "Dialog.hxx"
#include "bspf.hxx"

class GlobalPropsDialog : public Dialog, public CommandSender
{
  public:
    GlobalPropsDialog(GuiObject* boss, const GUI::Font& font);
    ~GlobalPropsDialog() override = default;

  private:
    int addHoldWidgets(const GUI::Font& font, int x, int y, WidgetArray& wid);

    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    enum {
      kJ0Up, kJ0Down, kJ0Left, kJ0Right, kJ0Fire,
      kJ1Up, kJ1Down, kJ1Left, kJ1Right, kJ1Fire
    };

    PopUpWidget* myBSType{nullptr};
    PopUpWidget* myLeftDiff{nullptr};
    PopUpWidget* myRightDiff{nullptr};
    PopUpWidget* myTVType{nullptr};

    std::array<CheckboxWidget*, 10> myJoy{nullptr};
    CheckboxWidget* myHoldSelect{nullptr};
    CheckboxWidget* myHoldReset{nullptr};
    CheckboxWidget* myDebug{nullptr};

    static const std::array<string, 10> ourJoyState;

  private:
    // Following constructors and assignment operators not supported
    GlobalPropsDialog() = delete;
    GlobalPropsDialog(const GlobalPropsDialog&) = delete;
    GlobalPropsDialog(GlobalPropsDialog&&) = delete;
    GlobalPropsDialog& operator=(const GlobalPropsDialog&) = delete;
    GlobalPropsDialog& operator=(GlobalPropsDialog&&) = delete;
};

#endif
