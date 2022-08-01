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

#ifndef HELP_DIALOG_HXX
#define HELP_DIALOG_HXX

class DialogContainer;
class CommandSender;
class ButtonWidget;
class StaticTextWidget;
class OSystem;

#include "Dialog.hxx"
#include "bspf.hxx"

class HelpDialog : public Dialog
{
  public:
    HelpDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font);
    ~HelpDialog() override = default;

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateStrings(uInt8 page, uInt8 lines, string& title);
    void displayInfo();
    void loadConfig() override { displayInfo(); }

  private:
    static constexpr uInt32 LINES_PER_PAGE = 10;
    ButtonWidget* myNextButton{nullptr};
    ButtonWidget* myPrevButton{nullptr};
    ButtonWidget* myUpdateButton{nullptr};

    StaticTextWidget* myTitle;
    std::array<StaticTextWidget*, LINES_PER_PAGE> myKey{nullptr};
    std::array<StaticTextWidget*, LINES_PER_PAGE> myDesc{nullptr};
    std::array<string, LINES_PER_PAGE> myKeyStr;
    std::array<string, LINES_PER_PAGE> myDescStr;

    uInt8 myPage{1};
    uInt8 myNumPages{5};

    enum {
      kUpdateCmd = 'upCm'
    };


  private:
    // Following constructors and assignment operators not supported
    HelpDialog() = delete;
    HelpDialog(const HelpDialog&) = delete;
    HelpDialog(HelpDialog&&) = delete;
    HelpDialog& operator=(const HelpDialog&) = delete;
    HelpDialog& operator=(HelpDialog&&) = delete;
};

#endif
