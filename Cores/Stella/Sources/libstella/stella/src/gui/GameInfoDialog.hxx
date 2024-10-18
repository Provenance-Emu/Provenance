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

#ifndef GAME_INFO_DIALOG_HXX
#define GAME_INFO_DIALOG_HXX

class OSystem;
class GuiObject;
class EditTextWidget;
class PopUpWidget;
class StaticTextWidget;
class RadioButtonGroup;
class TabWidget;
class SliderWidget;
class QuadTariDialog;

#include "Dialog.hxx"
#include "Command.hxx"
#include "Props.hxx"
#include "HighScoresManager.hxx"

class GameInfoDialog : public Dialog, public CommandSender
{
  public:
    GameInfoDialog(OSystem& osystem, DialogContainer& parent,
                   const GUI::Font& font, GuiObject* boss, int max_w, int max_h);
    ~GameInfoDialog() override;

  private:
    void loadConfig() override;
    void saveConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void setDefaults() override;

    void addEmulationTab();
    void addConsoleTab();
    void addControllersTab();
    void addCartridgeTab();
    void addHighScoresTab();

    // load the properties for the 'Emulation' tab
    void loadEmulationProperties(const Properties& props);
    // load the properties for the 'Console' tab
    void loadConsoleProperties(const Properties& props);
    // load the properties for the 'Controller' tab
    void loadControllerProperties(const Properties& props);
    // load the properties for the 'Cartridge' tab
    void loadCartridgeProperties(const Properties& props);
    // load the properties for the 'High Scores' tab
    void loadHighScoresProperties(const Properties& props);
    // load the properties of the 'High Scores' tab
    void saveHighScoresProperties();
    // save properties from all tabs into the local properties object
    void saveProperties();

    // en/disable tabs and widgets depending on multicart bankswitch type selected
    void updateMultiCart();
    // update 'BS Type' list
    void updateBSTypes();
    // update 'Controller' tab widgets
    void updateControllerStates();
    // erase SaveKey/AtariVox pages for current game
    void eraseEEPROM();
    // update link button
    void updateLink();
    // update 'High Scores' tab widgets
    void updateHighScoresWidgets();
    // set formatted memory value for given address field
    void setAddressVal(const EditTextWidget* address, EditTextWidget* val,
                       bool isBCD = true, bool zeroBased = false, uInt8 maxVal = 255);
    void exportCurrentPropertiesToDisk(const FSNode& node);

  private:
    TabWidget* myTab{nullptr};

    // Emulation properties
    StaticTextWidget* myBSTypeLabel{nullptr};
    PopUpWidget*      myBSType{nullptr};
    CheckboxWidget*   myBSFilter{nullptr};
    StaticTextWidget* myTypeDetected{nullptr};
    PopUpWidget*      myStartBank{nullptr};
    PopUpWidget*      myFormat{nullptr};
    StaticTextWidget* myFormatDetected{nullptr};
    SliderWidget*     myVCenter{nullptr};
    CheckboxWidget*   myPhosphor{nullptr};
    SliderWidget*     myPPBlend{nullptr};
    CheckboxWidget*   mySound{nullptr};

    // Console properties
    RadioButtonGroup* myLeftDiffGroup{nullptr};
    RadioButtonGroup* myRightDiffGroup{nullptr};
    RadioButtonGroup* myTVTypeGroup{nullptr};

    // Controller properties
    StaticTextWidget* myLeftPortLabel{nullptr};
    StaticTextWidget* myRightPortLabel{nullptr};
    PopUpWidget*      myLeftPort{nullptr};
    StaticTextWidget* myLeftPortDetected{nullptr};
    PopUpWidget*      myRightPort{nullptr};
    StaticTextWidget* myRightPortDetected{nullptr};
    ButtonWidget*     myQuadTariButton{nullptr};
    CheckboxWidget*   mySwapPorts{nullptr};
    CheckboxWidget*   mySwapPaddles{nullptr};
    StaticTextWidget* myEraseEEPROMLabel{nullptr};
    ButtonWidget*     myEraseEEPROMButton{nullptr};
    StaticTextWidget* myEraseEEPROMInfo{nullptr};
    StaticTextWidget* myPaddlesCenter{nullptr};
    SliderWidget*     myPaddleXCenter{nullptr};
    SliderWidget*     myPaddleYCenter{nullptr};
    CheckboxWidget*   myMouseControl{nullptr};
    PopUpWidget*      myMouseX{nullptr};
    PopUpWidget*      myMouseY{nullptr};
    SliderWidget*     myMouseRange{nullptr};

    // Allow assigning the four QuadTari controllers
    unique_ptr<QuadTariDialog> myQuadTariDialog;

    // Cartridge properties
    EditTextWidget*   myName{nullptr};
    EditTextWidget*   myMD5{nullptr};
    EditTextWidget*   myManufacturer{nullptr};
    EditTextWidget*   myModelNo{nullptr};
    EditTextWidget*   myRarity{nullptr};
    EditTextWidget*   myNote{nullptr};
    EditTextWidget*   myUrl{nullptr};
    ButtonWidget*     myUrlButton{nullptr};
    EditTextWidget*   myBezelName{nullptr};
    ButtonWidget*     myBezelButton{nullptr};
    StaticTextWidget* myBezelDetected{nullptr};

    // High Scores properties
    CheckboxWidget*   myHighScores{nullptr};
    //CheckboxWidget*   myARMGame{nullptr};

    StaticTextWidget* myVariationsLabel{nullptr};
    EditTextWidget*   myVariations{nullptr};
    StaticTextWidget* myVarAddressLabel{nullptr};
    EditTextWidget*   myVarAddress{nullptr};
    EditTextWidget*   myVarAddressVal{nullptr};
    CheckboxWidget*   myVarsBCD{nullptr};
    CheckboxWidget*   myVarsZeroBased{nullptr};

    StaticTextWidget* myScoreLabel{nullptr};
    StaticTextWidget* myScoreDigitsLabel{nullptr};
    PopUpWidget*      myScoreDigits{nullptr};
    StaticTextWidget* myTrailingZeroesLabel{nullptr};
    PopUpWidget*      myTrailingZeroes{nullptr};
    CheckboxWidget*   myScoreBCD{nullptr};
    CheckboxWidget*   myScoreInvert{nullptr};

    StaticTextWidget* myScoreAddressesLabel{nullptr};
    EditTextWidget*   myScoreAddress[HSM::MAX_SCORE_ADDR]{nullptr};
    EditTextWidget*   myScoreAddressVal[HSM::MAX_SCORE_ADDR]{nullptr};
    StaticTextWidget* myCurrentScoreLabel{nullptr};
    StaticTextWidget* myCurrentScore{nullptr};

    StaticTextWidget* mySpecialLabel{nullptr};
    EditTextWidget*   mySpecialName{nullptr};
    StaticTextWidget* mySpecialAddressLabel{nullptr};
    EditTextWidget*   mySpecialAddress{nullptr};
    EditTextWidget*   mySpecialAddressVal{nullptr};
    CheckboxWidget*   mySpecialBCD{nullptr};
    CheckboxWidget*   mySpecialZeroBased{nullptr};

    StaticTextWidget* myHighScoreNotesLabel{nullptr};
    EditTextWidget*   myHighScoreNotes{nullptr};

    enum {
      kBSTypeChanged    = 'Btch',
      kBSFilterChanged  = 'Bfch',
      kVCenterChanged   = 'Vcch',
      kPhosphorChanged  = 'PPch',
      kPPBlendChanged   = 'PBch',
      kLeftCChanged     = 'LCch',
      kRightCChanged    = 'RCch',
      kQuadTariPressed  = 'QTpr',
      kMCtrlChanged     = 'MCch',
      kEEButtonPressed  = 'EEgb',
      kHiScoresChanged  = 'HSch',
      kPXCenterChanged  = 'Pxch',
      kPYCenterChanged  = 'Pych',
      kExportPressed    = 'Expr',
      kLinkPressed      = 'Lkpr',
      kBezelFilePressed = 'BFpr'
    };

    enum { kLinkId };

    // Game properties for currently loaded ROM
    Properties myGameProperties;
    // Filename of the currently loaded ROM
    FSNode myGameFile;

  private:
    // Following constructors and assignment operators not supported
    GameInfoDialog() = delete;
    GameInfoDialog(const GameInfoDialog&) = delete;
    GameInfoDialog(GameInfoDialog&&) = delete;
    GameInfoDialog& operator=(const GameInfoDialog&) = delete;
    GameInfoDialog& operator=(GameInfoDialog&&) = delete;
};

#endif
