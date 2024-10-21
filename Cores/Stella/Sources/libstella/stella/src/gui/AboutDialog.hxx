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

#ifndef ABOUT_DIALOG_HXX
#define ABOUT_DIALOG_HXX

class OSystem;
class DialogContainer;
class CommandSender;
class ButtonWidget;
class StaticTextWidget;
class WhatsNewDialog;

#include "Dialog.hxx"

class AboutDialog : public Dialog
{
  public:
    AboutDialog(OSystem& osystem, DialogContainer& parent,
                const GUI::Font& font);
    ~AboutDialog() override;

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateStrings(int page, int lines, string& title);
    void displayInfo();
    static string getUrl(string_view text);

    void loadConfig() override { displayInfo(); }

  private:
    ButtonWidget* myWhatsNewButton{nullptr};
    ButtonWidget* myNextButton{nullptr};
    ButtonWidget* myPrevButton{nullptr};

    StaticTextWidget* myTitle{nullptr};
    vector<StaticTextWidget*> myDesc;
    vector<string> myDescStr;

    int myPage{1};
    int myNumPages{4};
    int myLinesPerPage{13};

    unique_ptr<WhatsNewDialog> myWhatsNewDialog;

    enum {
      kWhatsNew = 'ADWN'
    };

  private:
    // Following constructors and assignment operators not supported
    AboutDialog() = delete;
    AboutDialog(const AboutDialog&) = delete;
    AboutDialog(AboutDialog&&) = delete;
    AboutDialog& operator=(const AboutDialog&) = delete;
    AboutDialog& operator=(AboutDialog&&) = delete;
};

#endif
