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

#ifndef MIN_UI_HELP_DIALOG_HXX
#define MIN_UI_HELP_DIALOG_HXX

class DialogContainer;
class CommandSender;
class ButtonWidget;
class StaticTextWidget;
class OSystem;

#include "Dialog.hxx"
#include "bspf.hxx"

class R77HelpDialog : public Dialog
{
  public:
    R77HelpDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font);
    ~R77HelpDialog() override = default;

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateStrings(uInt8 page, uInt8 lines, string& title);
    void displayInfo();
    static void formatWidget(const string& label, StaticTextWidget* widget);
    void loadConfig() override;

  private:
    static constexpr uInt32 LINES_PER_PAGE = 13;
    ButtonWidget* myNextButton{nullptr};
    ButtonWidget* myPrevButton{nullptr};

    StaticTextWidget* myTitle{nullptr};
    std::array<StaticTextWidget*, LINES_PER_PAGE> myJoy{nullptr};
    std::array<StaticTextWidget*, LINES_PER_PAGE> myBtn{nullptr};
    std::array<StaticTextWidget*, LINES_PER_PAGE> myDesc{nullptr};
    std::array<string, LINES_PER_PAGE> myJoyStr;
    std::array<string, LINES_PER_PAGE> myBtnStr;
    std::array<string, LINES_PER_PAGE> myDescStr;

    uInt8 myPage{1};
    uInt8 myNumPages{4};

  private:
    // Following constructors and assignment operators not supported
    R77HelpDialog() = delete;
    R77HelpDialog(const R77HelpDialog&) = delete;
    R77HelpDialog(R77HelpDialog&&) = delete;
    R77HelpDialog& operator=(const R77HelpDialog&) = delete;
    R77HelpDialog& operator=(R77HelpDialog&&) = delete;
};

#endif
