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

#ifndef MESSAGE_BOX_HXX
#define MESSAGE_BOX_HXX

class GuiObject;
class StaticTextWidget;

#include "Dialog.hxx"
#include "Command.hxx"

namespace GUI {

/**
 * Show a simple message box containing the given text, with buttons
 * prompting the user to accept or reject.  If the user selects 'OK',
 * the value of 'okCmd' is returned.
 */
class MessageBox : public Dialog, public CommandSender
{
  public:
    MessageBox(GuiObject* boss, const GUI::Font& font, const StringList& text,
               int max_w, int max_h, int okCmd = 0, int cancelCmd = 0,
               string_view okText = "OK", string_view cancelText = "Cancel",
               string_view title = "",
               bool focusOKButton = true);
    MessageBox(GuiObject* boss, const GUI::Font& font, const StringList& text,
               int max_w, int max_h, int okCmd = 0,
               string_view okText = "OK", string_view cancelText = "Cancel",
               string_view title = "",
               bool focusOKButton = true);
    MessageBox(GuiObject* boss, const GUI::Font& font, string_view text,
               int max_w, int max_h, int okCmd = 0,
               string_view okText = "OK", string_view cancelText = "Cancel",
               string_view title = "",
               bool focusOKButton = true);
    MessageBox(GuiObject* boss, const GUI::Font& font, string_view text,
               int max_w, int max_h, int okCmd, int cancelCmd,
               string_view okText = "OK", string_view cancelText = "Cancel",
               string_view title = "",
               bool focusOKButton = true);
    ~MessageBox() override = default;

    /** Place the input dialog onscreen and center it */
    void show() { open(); }

  private:
    void addText(const GUI::Font& font, const StringList& text);
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    int myOkCmd{0};
    int myCancelCmd{0};

  private:
    // Following constructors and assignment operators not supported
    MessageBox() = delete;
    MessageBox(const MessageBox&) = delete;
    MessageBox(MessageBox&&) = delete;
    MessageBox& operator=(const MessageBox&) = delete;
    MessageBox& operator=(MessageBox&&) = delete;
};

} // namespace GUI

#endif
