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

#ifndef RIOT_RAM_WIDGET_HXX
#define RIOT_RAM_WIDGET_HXX

class GuiObject;
class InputTextDialog;
class ButtonWidget;
class DataGridWidget;
class DataGridOpsWidget;
class EditTextWidget;
class StaticTextWidget;
class CartDebug;

#include "RamWidget.hxx"

class RiotRamWidget : public RamWidget
{
  public:
    RiotRamWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
                  int x, int y, int w);
    ~RiotRamWidget() override = default;

    string getLabel(int addr) const override;

  private:
    uInt8 getValue(int addr) const override;
    void setValue(int addr, uInt8 value) override;

    void fillList(uInt32 start, uInt32 size, IntArray& alist,
                  IntArray& vlist, BoolArray& changed) const override;
    uInt32 readPort(uInt32 start) const override;
    const ByteArray& currentRam(uInt32 start) const override;

  private:
    CartDebug& myDbg;

  private:
    // Following constructors and assignment operators not supported
    RiotRamWidget() = delete;
    RiotRamWidget(const RiotRamWidget&) = delete;
    RiotRamWidget(RiotRamWidget&&) = delete;
    RiotRamWidget& operator=(const RiotRamWidget&) = delete;
    RiotRamWidget& operator=(RiotRamWidget&&) = delete;
};

#endif
