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

#ifndef MESSAGE_DIALOG_HXX
#define MESSAGE_DIALOG_HXX

class CommandSender;
class DialogContainer;
class OSystem;

#include "MessageBox.hxx"

class MessageDialog : public Dialog
{
  public:
    MessageDialog(OSystem& osystem, DialogContainer& parent,
                  const GUI::Font& font, int max_w, int max_h);
    ~MessageDialog() override;

    // Define the message displayed
    static void setMessage(string_view title, string_view text,
                           bool yesNo = false);
    static void setMessage(string_view title, const StringList& text,
                           bool yesNo = false);
    bool confirmed() { return myConfirmed; }

  protected:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    static string myTitle;
    static StringList myText;
    static bool myYesNo;
    static bool myConfirmed;

    // Show a message
    GUI::MessageBox* myMsg{nullptr};

  private:
    // Following constructors and assignment operators not supported
    MessageDialog() = delete;
    MessageDialog(const MessageDialog&) = delete;
    MessageDialog(MessageDialog&&) = delete;
    MessageDialog& operator=(const MessageDialog&) = delete;
    MessageDialog& operator=(MessageDialog&&) = delete;
};

#endif
