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

#ifndef INPUT_DIALOG_HXX
#define INPUT_DIALOG_HXX

class OSystem;
class GuiObject;
class TabWidget;
class EventMappingWidget;
class CheckboxWidget;
class EditTextWidget;
class JoystickDialog;
class PopUpWidget;
class SliderWidget;
class StaticTextWidget;
namespace GUI {
  class MessageBox;
}

#include "Dialog.hxx"
#include "bspf.hxx"

class InputDialog : public Dialog
{
  public:
    InputDialog(OSystem& osystem, DialogContainer& parent,
                const GUI::Font& font, int max_w, int max_h);
    ~InputDialog() override;

  protected:
    // disable repeat during and directly after mapping events
    bool repeatEnabled() override;

  private:
    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleKeyUp(StellaKey key, StellaMod mod) override;
    void handleJoyDown(int stick, int button, bool longPress) override;
    void handleJoyUp(int stick, int button) override;
    void handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button) override;
    bool handleJoyHat(int stick, int hat, JoyHatDir hdir, int button) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void addDevicePortTab();
    void addMouseTab();

    void handleMouseControlState();
    void handleCursorState();
    void updateDejitterAveraging();
    void updateDejitterReaction();
    void updateAutoFireRate();
    void eraseEEPROM();

  private:
    enum {
      kDDeadzoneChanged   = 'DDch',
      kADeadzoneChanged   = 'ADch',
      kPSpeedChanged      = 'Ppch',
      kDejitterAvChanged  = 'JAch',
      kDejitterReChanged  = 'JRch',
      kDPSpeedChanged     = 'DSch',
      kAutoFireChanged    = 'AFch',
      kAutoFireRate       = 'AFra',
      kTBSpeedChanged     = 'TBch',
      kDCSpeedChanged     = 'DCch',
      kDBButtonPressed    = 'DBbp',
      kEEButtonPressed    = 'EEbp',
      kConfirmEEEraseCmd  = 'EEcf',
      kMouseCtrlChanged   = 'MCch',
      kCursorStateChanged = 'CSch',
      kMPSpeedChanged     = 'PMch',
    };

    TabWidget* myTab{nullptr};

    EventMappingWidget* myEventMapper{nullptr};
//    EventMappingWidget* myMenuEventMapper{nullptr};

    CheckboxWidget*   mySAPort{nullptr};

    PopUpWidget*      myAVoxPort{nullptr};

    SliderWidget*     myDigitalDeadzone{nullptr};
    SliderWidget*     myAnalogDeadzone{nullptr};
    SliderWidget*     myPaddleSpeed{nullptr};
    SliderWidget*     myPaddleLinearity{nullptr};
    SliderWidget*     myDejitterBase{nullptr};
    SliderWidget*     myDejitterDiff{nullptr};
    SliderWidget*     myDPaddleSpeed{nullptr};
    CheckboxWidget*   myAutoFire{nullptr};
    SliderWidget*     myAutoFireRate{nullptr};
    CheckboxWidget*   myAllowAll4{nullptr};
    CheckboxWidget*   myModCombo{nullptr};

    ButtonWidget*     myJoyDlgButton{nullptr};
    ButtonWidget*     myEraseEEPROMButton{nullptr};

    PopUpWidget*      myMouseControl{nullptr};
    StaticTextWidget* myMouseSensitivity{nullptr};
    SliderWidget*     myMPaddleSpeed{nullptr};
    SliderWidget*     myTrackBallSpeed{nullptr};
    SliderWidget*     myDrivingSpeed{nullptr};
    PopUpWidget*      myCursorState{nullptr};
    CheckboxWidget*   myGrabMouse{nullptr};

    // Show the list of joysticks that the eventhandler knows about
    unique_ptr<JoystickDialog> myJoyDialog;

    // Show a message about the dangers of using this function
    unique_ptr<GUI::MessageBox> myConfirmMsg;

    // Maximum width and height for this dialog
    int myMaxWidth{0}, myMaxHeight{0};

  private:
    // Following constructors and assignment operators not supported
    InputDialog() = delete;
    InputDialog(const InputDialog&) = delete;
    InputDialog(InputDialog&&) = delete;
    InputDialog& operator=(const InputDialog&) = delete;
    InputDialog& operator=(InputDialog&&) = delete;
};

#endif
