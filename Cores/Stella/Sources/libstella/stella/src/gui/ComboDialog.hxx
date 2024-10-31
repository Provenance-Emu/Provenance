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

#ifndef COMBO_DIALOG_HXX
#define COMBO_DIALOG_HXX

class PopUpWidget;
class StaticTextWidget;
class OSystem;

#include "Dialog.hxx"
#include "bspf.hxx"

class ComboDialog : public Dialog
{
  public:
    ComboDialog(GuiObject* boss, const GUI::Font& font, const VariantList& combolist);
    ~ComboDialog() override = default;

    /** Place the dialog onscreen and center it */
    void show(Event::Type event, string_view name);

  private:
    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    Event::Type myComboEvent{Event::NoType};
    std::array<PopUpWidget*, 8> myEvents{nullptr};

  private:
    // Following constructors and assignment operators not supported
    ComboDialog() = delete;
    ComboDialog(const ComboDialog&) = delete;
    ComboDialog(ComboDialog&&) = delete;
    ComboDialog& operator=(const ComboDialog&) = delete;
    ComboDialog& operator=(ComboDialog&&) = delete;
};

#endif
