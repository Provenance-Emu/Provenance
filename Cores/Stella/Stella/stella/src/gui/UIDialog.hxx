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

#ifndef UI_DIALOG_HXX
#define UI_DIALOG_HXX

#include "Dialog.hxx"
#include "bspf.hxx"

class UIDialog : public Dialog, public CommandSender
{
  public:
    UIDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font,
             GuiObject* boss, int max_w, int max_h);
    ~UIDialog() override = default;

  private:
    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void handleLauncherSize();
    void handleRomViewer();

  private:
    enum
    {
      kDialogFont = 'UIDf',
      kListDelay  = 'UILd',
      kMouseWheel = 'UIMw',
      kControllerDelay = 'UIcd',
      kChooseRomDirCmd = 'LOrm', // rom select
      kRomViewer = 'UIRv',
      kChooseSnapLoadDirCmd = 'UIsl' // snapshot dir (load files)
    };

    TabWidget* myTab{nullptr};

    // Launcher options
    EditTextWidget*   myRomPath{nullptr};
    CheckboxWidget*   myFollowLauncherWidget{nullptr};
    SliderWidget*     myLauncherWidthSlider{nullptr};
    SliderWidget*     myLauncherHeightSlider{nullptr};
    PopUpWidget*      myLauncherFontPopup{nullptr};
    CheckboxWidget*   myFavoritesWidget{nullptr};
    CheckboxWidget*   myLauncherExtensionsWidget{nullptr};
    CheckboxWidget*   myLauncherButtonsWidget{nullptr};
    SliderWidget*     myRomViewerSize{nullptr};
    ButtonWidget*     myOpenBrowserButton{nullptr};
    EditTextWidget*   mySnapLoadPath{nullptr};
    CheckboxWidget*   myLauncherExitWidget{nullptr};

    // Misc options
    PopUpWidget*      myPalettePopup{nullptr};
    PopUpWidget*      myDialogFontPopup{nullptr};
    CheckboxWidget*   myHidpiWidget{nullptr};
    PopUpWidget*      myPositionPopup{nullptr};
    CheckboxWidget*   myCenter{nullptr};
    SliderWidget*     myListDelaySlider{nullptr};
    SliderWidget*     myWheelLinesSlider{nullptr};
    SliderWidget*     myControllerRateSlider{nullptr};
    SliderWidget*     myControllerDelaySlider{nullptr};
    SliderWidget*     myDoubleClickSlider{nullptr};

    // Indicates if this dialog is used for global (vs. in-game) settings
    bool myIsGlobal{false};

  private:
    // Following constructors and assignment operators not supported
    UIDialog() = delete;
    UIDialog(const UIDialog&) = delete;
    UIDialog(UIDialog&&) = delete;
    UIDialog& operator=(const UIDialog&) = delete;
    UIDialog& operator=(UIDialog&&) = delete;
};

#endif
