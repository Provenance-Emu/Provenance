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

#ifndef DEVELOPER_DIALOG_HXX
#define DEVELOPER_DIALOG_HXX

class OSystem;
class GuiObject;
class TabWidget;
class CheckboxWidget;
class PopUpWidget;
class RadioButtonGroup;
class RadioButtonWidget;
class SliderWidget;
class StaticTextWidget;
class ColorWidget;

namespace GUI {
  class Font;
}

#include "bspf.hxx"
#include "Dialog.hxx"
#include "DevSettingsHandler.hxx"

class DeveloperDialog : public Dialog, DevSettingsHandler
{
  public:
    DeveloperDialog(OSystem& osystem, DialogContainer& parent,
                const GUI::Font& font, int max_w, int max_h);
    ~DeveloperDialog() override = default;

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void loadConfig() override;
    void saveConfig() override;
    void setDefaults() override;

  private:
    enum
    {
      kPlrSettings          = 'DVpl',
      kDevSettings          = 'DVdv',
      kConsole              = 'DVco',
      kTIAType              = 'DVtt',
      kTVJitter             = 'DVjt',
      kTimeMachine          = 'DTtm',
      kSizeChanged          = 'DTsz',
      kUncompressedChanged  = 'DTuc',
      kIntervalChanged      = 'DTin',
      kHorizonChanged       = 'DThz',
      kP0ColourChangedCmd   = 'GOp0',
      kM0ColourChangedCmd   = 'GOm0',
      kP1ColourChangedCmd   = 'GOp1',
      kM1ColourChangedCmd   = 'GOm1',
      kPFColourChangedCmd   = 'GOpf',
      kBLColourChangedCmd   = 'GObl',
  #ifdef DEBUGGER_SUPPORT
      kDFontSizeChanged     = 'UIfs',
  #endif
    };

    // MUST be aligned with RewindManager!
    static constexpr int NUM_INTERVALS = 7;
    static constexpr int NUM_HORIZONS = 8;

    static constexpr int DEBUG_COLORS = 6;

    TabWidget* myTab{nullptr};
    // Emulator widgets
    RadioButtonGroup*   mySettingsGroupEmulation{nullptr};
    CheckboxWidget*     myFrameStatsWidget{nullptr};
    CheckboxWidget*     myDetectedInfoWidget{nullptr};
    CheckboxWidget*     myExternAccessWidget{nullptr};
    PopUpWidget*        myConsoleWidget{nullptr};
    StaticTextWidget*   myLoadingROMLabel{nullptr};
    CheckboxWidget*     myRandomBankWidget{nullptr};
    CheckboxWidget*     myRandomizeTIAWidget{nullptr};
    CheckboxWidget*     myRandomizeRAMWidget{nullptr};
    StaticTextWidget*   myRandomizeCPULabel{nullptr};
    std::array<CheckboxWidget*, 5> myRandomizeCPUWidget{nullptr};
    CheckboxWidget*     myRandomHotspotsWidget{nullptr};
    CheckboxWidget*     myUndrivenPinsWidget{nullptr};
#ifdef DEBUGGER_SUPPORT
    CheckboxWidget*     myRWPortBreakWidget{nullptr};
    CheckboxWidget*     myWRPortBreakWidget{nullptr};
#endif
    CheckboxWidget*     myThumbExceptionWidget{nullptr};

    // TIA widgets
    RadioButtonGroup*   mySettingsGroupTia{nullptr};
    PopUpWidget*        myTIATypeWidget{nullptr};
    StaticTextWidget*   myInvPhaseLabel{nullptr};
    CheckboxWidget*     myPlInvPhaseWidget{nullptr};
    CheckboxWidget*     myMsInvPhaseWidget{nullptr};
    CheckboxWidget*     myBlInvPhaseWidget{nullptr};
    StaticTextWidget*   myPlayfieldLabel{nullptr};
    CheckboxWidget*     myPFBitsWidget{nullptr};
    CheckboxWidget*     myPFColorWidget{nullptr};
    CheckboxWidget*     myPFScoreWidget{nullptr};
    StaticTextWidget*   myBackgroundLabel{nullptr};
    CheckboxWidget*     myBKColorWidget{nullptr};
    StaticTextWidget*   mySwapLabel{nullptr};
    CheckboxWidget*     myPlSwapWidget{nullptr};
    CheckboxWidget*     myBlSwapWidget{nullptr};

    // Video widgets
    RadioButtonGroup*   mySettingsGroupVideo{nullptr};
    CheckboxWidget*     myTVJitterWidget{nullptr};
    SliderWidget*       myTVJitterRecWidget{nullptr};
    SliderWidget*       myTVJitterSenseWidget{nullptr};
    CheckboxWidget*     myColorLossWidget{nullptr};
    CheckboxWidget*     myDebugColorsWidget{nullptr};
    std::array<PopUpWidget*, DEBUG_COLORS> myDbgColour{nullptr};
    std::array<ColorWidget*, DEBUG_COLORS> myDbgColourSwatch{nullptr};

    // States widgets
    RadioButtonGroup*   mySettingsGroupTM{nullptr};
    CheckboxWidget*     myTimeMachineWidget{nullptr};
    SliderWidget*       myStateSizeWidget{nullptr};
    SliderWidget*       myUncompressedWidget{nullptr};
    PopUpWidget*        myStateIntervalWidget{nullptr};
    PopUpWidget*        myStateHorizonWidget{nullptr};

#ifdef DEBUGGER_SUPPORT
    // Debugger UI widgets
    SliderWidget*       myDebuggerWidthSlider{nullptr};
    SliderWidget*       myDebuggerHeightSlider{nullptr};
    PopUpWidget*        myDebuggerFontSize{nullptr};
    PopUpWidget*        myDebuggerFontStyle{nullptr};
    CheckboxWidget*     myGhostReadsTrapWidget{nullptr};
#endif

    bool mySettings{false};

  private:
    void addEmulationTab(const GUI::Font& font);
    void addTimeMachineTab(const GUI::Font& font);
    void addTiaTab(const GUI::Font& font);
    void addVideoTab(const GUI::Font& font);
    void addDebuggerTab(const GUI::Font& font);

    void getWidgetStates(SettingsSet set);
    void setWidgetStates(SettingsSet set);

    void handleSettings(bool devSettings);
    void handleTVJitterChange();
    void handleConsole();

    void handleTia();

    void handleDebugColours(int idx, int color);
    void handleDebugColours(string_view colors);

    void handleTimeMachine();
    void handleSize();
    void handleUncompressed();
    void handleInterval();
    void handleHorizon();
    void handleFontSize();

    // Following constructors and assignment operators not supported
    DeveloperDialog() = delete;
    DeveloperDialog(const DeveloperDialog&) = delete;
    DeveloperDialog(DeveloperDialog&&) = delete;
    DeveloperDialog& operator=(const DeveloperDialog&) = delete;
    DeveloperDialog& operator=(DeveloperDialog&&) = delete;
};

#endif
