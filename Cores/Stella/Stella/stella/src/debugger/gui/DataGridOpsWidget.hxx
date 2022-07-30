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

#ifndef DATA_GRID_OPS_WIDGET_HXX
#define DATA_GRID_OPS_WIDGET_HXX

#include "Widget.hxx"
#include "Command.hxx"

// DataGridWidget operations
enum {
  kDGZeroCmd   = 'DGze',
  kDGInvertCmd = 'DGiv',
  kDGNegateCmd = 'DGng',
  kDGIncCmd    = 'DGic',
  kDGDecCmd    = 'DGdc',
  kDGShiftLCmd = 'DGls',
  kDGShiftRCmd = 'DGrs'
};

class DataGridOpsWidget : public Widget, public CommandSender
{
  public:
    DataGridOpsWidget(GuiObject* boss, const GUI::Font& font, int x, int y);
    ~DataGridOpsWidget() override = default;

    void setTarget(CommandReceiver* target) override;
    void setEnabled(bool e) override;

  private:
    ButtonWidget* _zeroButton{nullptr};
    ButtonWidget* _invButton{nullptr};
    ButtonWidget* _negButton{nullptr};
    ButtonWidget* _incButton{nullptr};
    ButtonWidget* _decButton{nullptr};
    ButtonWidget* _shiftLeftButton{nullptr};
    ButtonWidget* _shiftRightButton{nullptr};

  private:
    // Following constructors and assignment operators not supported
    DataGridOpsWidget() = delete;
    DataGridOpsWidget(const DataGridOpsWidget&) = delete;
    DataGridOpsWidget(DataGridOpsWidget&&) = delete;
    DataGridOpsWidget& operator=(const DataGridOpsWidget&) = delete;
    DataGridOpsWidget& operator=(DataGridOpsWidget&&) = delete;
};

#endif
