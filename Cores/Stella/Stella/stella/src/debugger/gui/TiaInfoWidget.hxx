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

#ifndef TIA_INFO_WIDGET_HXX
#define TIA_INFO_WIDGET_HXX

class GuiObject;
class EditTextWidget;
class CheckboxWidget;

#include "Widget.hxx"
#include "Command.hxx"


class TiaInfoWidget : public Widget, public CommandSender
{
  public:
    TiaInfoWidget(GuiObject *boss, const GUI::Font& lfont, const GUI::Font& nfont,
                  int x, int y, int max_w);
    ~TiaInfoWidget() override = default;

    void loadConfig() override;

  private:
    EditTextWidget* myFrameCount{nullptr};
    EditTextWidget* myFrameCycles{nullptr};
    EditTextWidget* myTotalCycles{nullptr};
    EditTextWidget* myDeltaCycles{nullptr};
    EditTextWidget* myWSyncCylces{nullptr};
    EditTextWidget* myTimerCylces{nullptr};

    EditTextWidget* myScanlineCount{nullptr};
    EditTextWidget* myScanlineCountLast{nullptr};
    EditTextWidget* myScanlineCycles{nullptr};
    EditTextWidget* myPixelPosition{nullptr};
    EditTextWidget* myColorClocks{nullptr};

  private:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    // Following constructors and assignment operators not supported
    TiaInfoWidget() = delete;
    TiaInfoWidget(const TiaInfoWidget&) = delete;
    TiaInfoWidget(TiaInfoWidget&&) = delete;
    TiaInfoWidget& operator=(const TiaInfoWidget&) = delete;
    TiaInfoWidget& operator=(TiaInfoWidget&&) = delete;
};

#endif
