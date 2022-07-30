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

#ifndef DELAY_QUEUE_WIDGET_HXX
#define DELAY_QUEUE_WIDGET_HXX

#include "Widget.hxx"

class DelayQueueWidget : public Widget
{
  public:
    DelayQueueWidget(
      GuiObject* boss,
      const GUI::Font& font,
      int x, int y
    );
    ~DelayQueueWidget() override = default;

    void loadConfig() override;

  protected:
    void drawWidget(bool hilite) override;

  private:
    std::array<string, 4> myLines;

  private:
    DelayQueueWidget() = delete;
    DelayQueueWidget(const DelayQueueWidget&) = delete;
    DelayQueueWidget(DelayQueueWidget&&) = delete;
    DelayQueueWidget& operator=(const DelayQueueWidget&) = delete;
    DelayQueueWidget& operator=(DelayQueueWidget&&) = delete;
};

#endif // DELAY_QUEUE_WIDGET_HXX
