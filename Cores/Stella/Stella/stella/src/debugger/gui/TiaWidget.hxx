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

#ifndef TIA_WIDGET_HXX
#define TIA_WIDGET_HXX

class GuiObject;
class ButtonWidget;
class DataGridWidget;
class StaticTextWidget;
class ToggleBitWidget;
class TogglePixelWidget;
class EditTextWidget;
class ColorWidget;
class DelayQueueWidget;

#include "Widget.hxx"
#include "Command.hxx"

class TiaWidget : public Widget, public CommandSender
{
  public:
    TiaWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
              int x, int y, int w, int h);
    ~TiaWidget() override = default;

  private:
    DataGridWidget* myColorRegs{nullptr};

    ColorWidget* myCOLUP0Color{nullptr};
    ColorWidget* myCOLUP1Color{nullptr};
    ColorWidget* myCOLUPFColor{nullptr};
    ColorWidget* myCOLUBKColor{nullptr};

    CheckboxWidget* myFixedEnabled{nullptr};
    std::array<ColorWidget*, 8> myFixedColors{nullptr};

    TogglePixelWidget* myGRP0{nullptr};
    TogglePixelWidget* myGRP0Old{nullptr};
    TogglePixelWidget* myGRP1{nullptr};
    TogglePixelWidget* myGRP1Old{nullptr};

    DataGridWidget* myPosP0{nullptr};
    DataGridWidget* myPosP1{nullptr};
    DataGridWidget* myPosM0{nullptr};
    DataGridWidget* myPosM1{nullptr};
    DataGridWidget* myPosBL{nullptr};

    DataGridWidget* myHMP0{nullptr};
    DataGridWidget* myHMP1{nullptr};
    DataGridWidget* myHMM0{nullptr};
    DataGridWidget* myHMM1{nullptr};
    DataGridWidget* myHMBL{nullptr};

    DataGridWidget* myNusizP0{nullptr};
    DataGridWidget* myNusizP1{nullptr};
    DataGridWidget* myNusizM0{nullptr};
    DataGridWidget* myNusizM1{nullptr};
    DataGridWidget* mySizeBL{nullptr};
    EditTextWidget* myNusizP0Text{nullptr};
    EditTextWidget* myNusizP1Text{nullptr};

    CheckboxWidget* myRefP0{nullptr};
    CheckboxWidget* myRefP1{nullptr};
    CheckboxWidget* myDelP0{nullptr};
    CheckboxWidget* myDelP1{nullptr};
    CheckboxWidget* myDelBL{nullptr};

    TogglePixelWidget* myEnaM0{nullptr};
    TogglePixelWidget* myEnaM1{nullptr};
    TogglePixelWidget* myEnaBL{nullptr};
    TogglePixelWidget* myEnaBLOld{nullptr};

    CheckboxWidget* myResMP0{nullptr};
    CheckboxWidget* myResMP1{nullptr};

    /** Collision register bits */
    std::array<CheckboxWidget*, 15> myCollision{nullptr};

    std::array<TogglePixelWidget*, 3> myPF{nullptr};
    CheckboxWidget* myRefPF{nullptr};
    CheckboxWidget* myScorePF{nullptr};
    CheckboxWidget* myPriorityPF{nullptr};

    DelayQueueWidget* myDelayQueueWidget{nullptr};

    CheckboxWidget* myVSync{nullptr};
    CheckboxWidget* myVBlank{nullptr};

    // ID's for the various widgets
    // We need ID's, since there are more than one of several types of widgets
    enum {
      kP0_PFID,   kP0_BLID,   kP0_M1ID,   kP0_M0ID,   kP0_P1ID,
      kP1_PFID,   kP1_BLID,   kP1_M1ID,   kP1_M0ID,
      kM0_PFID,   kM0_BLID,   kM0_M1ID,
      kM1_PFID,   kM1_BLID,
      kBL_PFID,   // Make these first, since we want them to start from 0

      kRamID,
      kColorRegsID,
      kGRP0ID,    kGRP0OldID,
      kGRP1ID,    kGRP1OldID,
      kPosP0ID,   kPosP1ID,
      kPosM0ID,   kPosM1ID,   kPosBLID,
      kHMP0ID,    kHMP1ID,
      kHMM0ID,    kHMM1ID,    kHMBLID,
      kRefP0ID,   kRefP1ID,
      kDelP0ID,   kDelP1ID,   kDelBLID,
      kNusizP0ID, kNusizP1ID,
      kNusizM0ID, kNusizM1ID, kSizeBLID,
      kEnaM0ID,   kEnaM1ID,   kEnaBLID, kEnaBLOldID,
      kResMP0ID,  kResMP1ID,
      kPF0ID,     kPF1ID,     kPF2ID,
      kRefPFID,   kScorePFID, kPriorityPFID
    };

    // Strobe button and misc commands
    enum {
      kWsyncCmd = 'Swsy',
      kRsyncCmd = 'Srsy',
      kResP0Cmd = 'Srp0',
      kResP1Cmd = 'Srp1',
      kResM0Cmd = 'Srm0',
      kResM1Cmd = 'Srm1',
      kResBLCmd = 'Srbl',
      kHmoveCmd = 'Shmv',
      kHmclrCmd = 'Shmc',
      kCxChgCmd = 'Sccc',
      kCxclrCmd = 'Scxl',
      kDbgClCmd = 'DBGc',
      kVSyncCmd = 'Cvsn',
      kVBlankCmd = 'Cvbl'
    };

    // Color registers
    enum {
      kCOLUP0Addr,
      kCOLUP1Addr,
      kCOLUPFAddr,
      kCOLUBKAddr
    };

  private:
    void changeColorRegs();
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void loadConfig() override;

    // Following constructors and assignment operators not supported
    TiaWidget() = delete;
    TiaWidget(const TiaWidget&) = delete;
    TiaWidget(TiaWidget&&) = delete;
    TiaWidget& operator=(const TiaWidget&) = delete;
    TiaWidget& operator=(TiaWidget&&) = delete;
};

#endif
