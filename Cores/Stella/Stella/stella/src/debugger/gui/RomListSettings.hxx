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

#ifndef ROM_LIST_SETTINGS_HXX
#define ROM_LIST_SETTINGS_HXX

class CheckboxWidget;
class EditTextWidget;

#include "Command.hxx"
#include "Dialog.hxx"

/**
 * A dialog which controls the settings for the RomListWidget.
 * Currently, all Distella disassembler options are located here as well.
 */
class RomListSettings : public Dialog, public CommandSender
{
  public:
    RomListSettings(GuiObject* boss, const GUI::Font& font);
    ~RomListSettings() override = default;

    bool isShading() const override { return false; }

    /** Show dialog onscreen at the specified coordinates
        ('data' will be the currently selected line number in RomListWidget) */
    void show(uInt32 x, uInt32 y, const Common::Rect& bossRect, int data = -1);

    /** This dialog uses its own positioning, so we override Dialog::setPosition() */
    void setPosition() override;

  private:
    uInt32 _xorig{0}, _yorig{0};
    int _item{0}; // currently selected line number in the disassembly list

    CheckboxWidget* myShowTentative{nullptr};
    CheckboxWidget* myShowAddresses{nullptr};
    CheckboxWidget* myShowGFXBinary{nullptr};
    CheckboxWidget* myUseRelocation{nullptr};

  private:
    void loadConfig() override;
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    // Following constructors and assignment operators not supported
    RomListSettings() = delete;
    RomListSettings(const RomListSettings&) = delete;
    RomListSettings(RomListSettings&&) = delete;
    RomListSettings& operator=(const RomListSettings&) = delete;
    RomListSettings& operator=(RomListSettings&&) = delete;
};

#endif
