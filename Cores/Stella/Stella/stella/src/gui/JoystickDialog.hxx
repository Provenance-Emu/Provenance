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

#ifndef JOYSTICK_DIALOG_HXX
#define JOYSTICK_DIALOG_HXX

class CommandSender;
class GuiObject;
class ButtonWidget;
class EditTextWidgetWidget;
class StringListWidget;

#include "Dialog.hxx"

/**
 * Show a listing of joysticks currently stored in the eventhandler database,
 * and allow to remove those that aren't currently being used.
 */
class JoystickDialog : public Dialog
{
  public:
    JoystickDialog(GuiObject* boss, const GUI::Font& font,
                   int max_w, int max_h);
    ~JoystickDialog() override = default;

    /** Place the dialog onscreen and center it */
    void show() { open(); }

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    StringListWidget* myJoyList{nullptr};
    EditTextWidget*   myJoyText{nullptr};

    ButtonWidget* myRemoveBtn{nullptr};
    ButtonWidget* myCloseBtn{nullptr};

    IntArray myJoyIDs;

    enum { kRemoveCmd = 'JDrm' };

  private:
    // Following constructors and assignment operators not supported
    JoystickDialog() = delete;
    JoystickDialog(const JoystickDialog&) = delete;
    JoystickDialog(JoystickDialog&&) = delete;
    JoystickDialog& operator=(const JoystickDialog&) = delete;
    JoystickDialog& operator=(JoystickDialog&&) = delete;
};

#endif
