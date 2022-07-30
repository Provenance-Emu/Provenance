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

#ifndef FLASH_WIDGET_HXX
#define FLASH_WIDGET_HXX

class Controller;
class ButtonWidget;

#include "ControllerWidget.hxx"

class FlashWidget : public ControllerWidget
{
  public:
    FlashWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                Controller& controller);
    ~FlashWidget() override = default;

  protected:
    void init(GuiObject* boss, const GUI::Font& font, int x, int y, bool embedded);

  private:
    enum { kEEPROMEraseCurrent = 'eeEC' };

    bool myEmbedded{false};
    ButtonWidget* myEEPROMEraseCurrent{nullptr};

    static constexpr uInt32 MAX_PAGES = 5;
    std::array<StaticTextWidget*, MAX_PAGES> myPage{nullptr};

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    /**
      Erase the EEPROM pages used by the current ROM
    */
    virtual void eraseCurrent() = 0;

    /**
      Check if a page is used by the current ROM
    */
    virtual bool isPageUsed(uInt32 page) = 0;

    // Following constructors and assignment operators not supported
    FlashWidget() = delete;
    FlashWidget(const FlashWidget&) = delete;
    FlashWidget(FlashWidget&&) = delete;
    FlashWidget& operator=(const FlashWidget&) = delete;
    FlashWidget& operator=(FlashWidget&&) = delete;
};

#endif
