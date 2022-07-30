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

#ifndef CARTRIDGE_ARM_WIDGET_HXX
#define CARTRIDGE_ARM_WIDGET_HXX

#include "CartARM.hxx"
#include "CartDebugWidget.hxx"

class CheckboxWidget;
class SliderWidget;
class PopUpWidget;
class DataGridWidget;

/**
  Abstract base class for ARM cart widgets.

  @author  Thomas Jentzsch
*/
class CartridgeARMWidget : public CartDebugWidget
{
  public:
    CartridgeARMWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeARM& cart);
    ~CartridgeARMWidget() override = default;

  protected:
    void addCycleWidgets(int xpos, int ypos);

    void saveOldState() override;
    void loadConfig() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    void handleChipType();
    void handleMamLock();
    void handleMamMode();
    void handleArmCycles();

  private:
    struct CartState {
      uInt32 mamMode{0};
      uIntArray armRun;
      uIntArray armPrevRun;
    };

    CartridgeARM& myCart;

    CheckboxWidget*   myIncCycles{nullptr};
    SliderWidget*     myCycleFactor{nullptr};
    PopUpWidget*      myChipType{nullptr};
    CheckboxWidget*   myLockMamMode{nullptr};
    PopUpWidget*      myMamMode{nullptr};
    StaticTextWidget* myCyclesLabel{nullptr};
    DataGridWidget*   myPrevThumbCycles{nullptr};
    DataGridWidget*   myPrevThumbInstructions{nullptr};
    DataGridWidget*   myThumbCycles{nullptr};
    DataGridWidget*   myThumbInstructions{nullptr};

    CartState myOldState;

    enum {
      kChipChanged      = 'chCh',
      kMamLockChanged   = 'mlCh',
      kMamModeChanged   = 'mmCh',
      kIncCyclesChanged = 'inCH',
      kFactorChanged    = 'fcCH'
    };

  private:
    // Following constructors and assignment operators not supported
    CartridgeARMWidget() = delete;
    CartridgeARMWidget(const CartridgeARMWidget&) = delete;
    CartridgeARMWidget(CartridgeARMWidget&&) = delete;
    CartridgeARMWidget& operator=(const CartridgeARMWidget&) = delete;
    CartridgeARMWidget& operator=(CartridgeARMWidget&&) = delete;
};

#endif
