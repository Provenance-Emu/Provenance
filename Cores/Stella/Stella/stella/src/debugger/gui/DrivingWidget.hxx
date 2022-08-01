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

#ifndef DRIVING_WIDGET_HXX
#define DRIVING_WIDGET_HXX

class Controller;
class ButtonWidget;
class CheckboxWidget;
class DataGridWidget;

#include "ControllerWidget.hxx"

class DrivingWidget : public ControllerWidget
{
  public:
    DrivingWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                  Controller& controller, bool embedded = false);
    ~DrivingWidget() override = default;

  private:
    enum {
      kGrayUpCmd   = 'DWup',
      kGrayDownCmd = 'DWdn',
      kFireCmd     = 'DWfr'
    };
    ButtonWidget *myGrayUp{nullptr}, *myGrayDown{nullptr};
    DataGridWidget* myGrayValue{nullptr};
    CheckboxWidget* myFire{nullptr};

    int myGrayIndex{0};

    static constexpr std::array<uInt8, 4> ourGrayTable = {
      { 0x03, 0x01, 0x00, 0x02 }
    };

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void setValue(int idx);

    // Following constructors and assignment operators not supported
    DrivingWidget() = delete;
    DrivingWidget(const DrivingWidget&) = delete;
    DrivingWidget(DrivingWidget&&) = delete;
    DrivingWidget& operator=(const DrivingWidget&) = delete;
    DrivingWidget& operator=(DrivingWidget&&) = delete;
};

#endif
