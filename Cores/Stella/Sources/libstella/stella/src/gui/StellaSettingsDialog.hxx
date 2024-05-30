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

#ifndef STELLA_OPTIONS_DIALOG_HXX
#define STELLA_OPTIONS_DIALOG_HXX

class PopUpWidget;

#include "Props.hxx"
#include "OptionsMenu.hxx"
#include "Dialog.hxx"

#if defined(RETRON77)
  #include "R77HelpDialog.hxx"
#else
  #include "HelpDialog.hxx"
#endif

namespace GUI {
  class Font;
  class MessageBox;
}

class StellaSettingsDialog : public Dialog
{
  public:
    StellaSettingsDialog(OSystem& osystem, DialogContainer& parent,
      int max_w, int max_h, AppMode mode);
    ~StellaSettingsDialog() override;

  private:
    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void addVideoOptions(WidgetArray& wid, int xpos, int& ypos);
    void addUIOptions(WidgetArray& wid, int xpos, int& ypos);
    void addGameOptions(WidgetArray& wid, int xpos, int& ypos);

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void handleOverscanChange();

    // switch to advanced settings after user confirmation
    void switchSettingsMode();

    // load the properties for the controller settings
    void loadControllerProperties(const Properties& props);

    // convert internal setting values to user friendly levels
    static int levelToValue(int level);
    static int valueToLevel(int value);

    void openHelp();

    void updateControllerStates();

  private:
    // UI theme
    PopUpWidget*      myThemePopup{nullptr};
    PopUpWidget*      myPositionPopup{nullptr};

    // TV effects
    PopUpWidget*      myTVMode{nullptr};

    // TV scanline intensity
    SliderWidget*     myTVScanIntense{nullptr};

    // TV phosphor effect
    SliderWidget*     myTVPhosLevel{nullptr};

    // TV Overscan
    SliderWidget*     myTVOverscan{nullptr};

    // Controller properties
    StaticTextWidget* myGameSettings{nullptr};

    StaticTextWidget* myLeftPortLabel{nullptr};
    StaticTextWidget* myRightPortLabel{nullptr};
    PopUpWidget*      myLeftPort{nullptr};
    StaticTextWidget* myLeftPortDetected{nullptr};
    PopUpWidget*      myRightPort{nullptr};
    StaticTextWidget* myRightPortDetected{nullptr};

    unique_ptr<GUI::MessageBox> myConfirmMsg;
  #if defined(RETRON77)
    unique_ptr<R77HelpDialog> myHelpDialog;
  #else
    unique_ptr<HelpDialog> myHelpDialog;
  #endif

    // Indicates if this dialog is used for global (vs. in-game) settings
    AppMode myMode{AppMode::emulator};

    enum {
      kAdvancedSettings = 'SSad',
      kConfirmSwitchCmd = 'SScf',
      kHelp             = 'SShl',
      kScanlinesChanged = 'SSsc',
      kPhosphorChanged  = 'SSph',
      kOverscanChanged  = 'SSov',
      kLeftCChanged     = 'LCch',
      kRightCChanged    = 'RCch',
    };

    // Game properties for currently loaded ROM
    Properties myGameProperties;

    // Following constructors and assignment operators not supported
    StellaSettingsDialog() = delete;
    StellaSettingsDialog(const StellaSettingsDialog&) = delete;
    StellaSettingsDialog(StellaSettingsDialog&&) = delete;
    StellaSettingsDialog& operator=(const StellaSettingsDialog&) = delete;
    StellaSettingsDialog& operator=(StellaSettingsDialog&&) = delete;
};

#endif
