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

#ifndef SAVEKEY_WIDGET_HXX
#define SAVEKEY_WIDGET_HXX

class Controller;

#include "FlashWidget.hxx"

class SaveKeyWidget : public FlashWidget
{
  public:
    SaveKeyWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                  Controller& controller, bool embedded = false);
    ~SaveKeyWidget() override = default;

  private:
    void eraseCurrent() override;
    bool isPageUsed(uInt32 page) override;

    // Following constructors and assignment operators not supported
    SaveKeyWidget() = delete;
    SaveKeyWidget(const SaveKeyWidget&) = delete;
    SaveKeyWidget(SaveKeyWidget&&) = delete;
    SaveKeyWidget& operator=(const SaveKeyWidget&) = delete;
    SaveKeyWidget& operator=(SaveKeyWidget&&) = delete;
};

#endif
