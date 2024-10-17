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

#ifndef RIOT_WIDGET_HXX
#define RIOT_WIDGET_HXX

class GuiObject;
class StaticTextWidget;
class ButtonWidget;
class DataGridWidget;
class PopUpWidget;
class ToggleBitWidget;
class ControllerWidget;
class Controller;

#include "Command.hxx"

class RiotWidget : public Widget, public CommandSender
{
  public:
    RiotWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
               int x, int y, int w, int h);
    ~RiotWidget() override = default;

  private:
    static ControllerWidget* addControlWidget(
        GuiObject* boss, const GUI::Font& font,
        int x, int y, Controller& controller);

    void handleConsole();
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void loadConfig() override;

  private:
    ToggleBitWidget* mySWCHAReadBits{nullptr};
    ToggleBitWidget* mySWCHAWriteBits{nullptr};
    ToggleBitWidget* mySWACNTBits{nullptr};
    ToggleBitWidget* mySWCHBReadBits{nullptr};
    ToggleBitWidget* mySWCHBWriteBits{nullptr};
    ToggleBitWidget* mySWBCNTBits{nullptr};

    DataGridWidget* myLeftINPT{nullptr};
    DataGridWidget* myRightINPT{nullptr};
    CheckboxWidget* myINPTLatch{nullptr};
    CheckboxWidget* myINPTDump{nullptr};

    std::array<StaticTextWidget*, 4> myTimWriteLabel{nullptr};
    DataGridWidget* myTimWrite{nullptr};
    DataGridWidget* myTimAvail{nullptr};
    DataGridWidget* myTimRead{nullptr};
    DataGridWidget* myTimTotal{nullptr};

    ControllerWidget *myLeftControl{nullptr}, *myRightControl{nullptr};
    PopUpWidget *myP0Diff{nullptr}, *myP1Diff{nullptr};
    PopUpWidget *myTVType{nullptr};
    CheckboxWidget* mySelect{nullptr};
    CheckboxWidget* myReset{nullptr};
    CheckboxWidget* myPause{nullptr};

    PopUpWidget *myConsole{nullptr};

    // ID's for the various widgets
    // We need ID's, since there are more than one of several types of widgets
    enum {
      kTim1TID, kTim8TID, kTim64TID, kTim1024TID, kTimWriteID,
      kSWCHABitsID, kSWACNTBitsID, kSWCHBBitsID, kSWBCNTBitsID,
      kP0DiffChanged, kP1DiffChanged, kTVTypeChanged, kSelectID, kResetID,
      kSWCHARBitsID, kSWCHBRBitsID, kPauseID, kConsoleID
    };

  private:
    // Following constructors and assignment operators not supported
    RiotWidget() = delete;
    RiotWidget(const RiotWidget&) = delete;
    RiotWidget(RiotWidget&&) = delete;
    RiotWidget& operator=(const RiotWidget&) = delete;
    RiotWidget& operator=(RiotWidget&&) = delete;
};

#endif
