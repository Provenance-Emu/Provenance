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

#ifndef POINTINGDEVICE_WIDGET_HXX
#define POINTINGDEVICE_WIDGET_HXX

class Controller;
class DataGridWidget;

#include "ControllerWidget.hxx"

class PointingDeviceWidget : public ControllerWidget
{
  public:
    PointingDeviceWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                         Controller& controller);
    ~PointingDeviceWidget() override = default;

  private:
    enum {
      kTBLeft = 'TWlf',
      kTBRight = 'TWrt',
      kTBUp = 'TWup',
      kTBDown = 'TWdn',
      kTBFire = 'TWfr'
    };
    ButtonWidget *myGrayLeft{nullptr}, *myGrayRight{nullptr};
    DataGridWidget* myGrayValueH{nullptr};
    ButtonWidget *myGrayUp{nullptr}, *myGrayDown{nullptr};
    DataGridWidget* myGrayValueV{nullptr};
    CheckboxWidget* myFire{nullptr};

  private:
    virtual uInt8 getGrayCodeTable(const int index, const int direction) const = 0;

    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void setGrayCodeH();
    void setGrayCodeV();
    void setValue(DataGridWidget* grayValue, const int index, const int direction);

    // Following constructors and assignment operators not supported
    PointingDeviceWidget() = delete;
    PointingDeviceWidget(const PointingDeviceWidget&) = delete;
    PointingDeviceWidget(PointingDeviceWidget&&) = delete;
    PointingDeviceWidget& operator=(const PointingDeviceWidget&) = delete;
    PointingDeviceWidget& operator=(PointingDeviceWidget&&) = delete;
};

#endif
