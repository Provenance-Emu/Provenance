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

#ifndef CART_DEBUG_WIDGET_HXX
#define CART_DEBUG_WIDGET_HXX

class GuiObject;
class StringListWidget;

namespace GUI {
  class Font;
}

#include "Base.hxx"  // not needed here, but all child classes need it
#include "Command.hxx"
#include "Widget.hxx"

class CartDebugWidget : public Widget, public CommandSender
{
  public:
    CartDebugWidget(GuiObject* boss, const GUI::Font& lfont,
                    const GUI::Font& nfont,
                    int x, int y, int w, int h);
    ~CartDebugWidget() override = default;

  public:
    int addBaseInformation(size_t bytes, string_view manufacturer,
        string_view desc, const uInt16 maxlines = 10);

    // Inform the ROM Widget that the underlying cart has somehow changed
    void invalidate();

    // Some carts need to save old state in the debugger, so that we can
    // implement change tracking; most carts probably won't do anything here
    virtual void saveOldState() { }

    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override { }

    // Query internal state of the cart (usually just bankswitching info)
    virtual string bankState() { return "0 (non-bankswitched)"; }

    // To make the Cartridge RAM show up in the debugger, implement
    // the following 9 functions for cartridges with internal RAM
    virtual uInt32 internalRamSize() { return 0; }
    virtual uInt32 internalRamRPort(int start) { return 0; }
    virtual string internalRamDescription() { return EmptyString; }
    virtual const ByteArray& internalRamOld(int start, int count) { return myRamOld; }
    virtual const ByteArray& internalRamCurrent(int start, int count) { return myRamCurrent; }
    virtual void internalRamSetValue(int addr, uInt8 value) { }
    virtual uInt8 internalRamGetValue(int addr) { return 0; }
    virtual string internalRamLabel(int addr) { return "Not available/applicable"; }
    virtual string tabLabel() { return " Cartridge RAM "; }

  protected:
    // Arrays used to hold current and previous internal RAM values
    ByteArray myRamOld, myRamCurrent;

    // Font used for 'normal' text; _font is for 'label' text
    const GUI::Font& _nfont;

    // These will be needed by most of the child classes;
    // we may as well make them protected variables
    int myFontWidth{0}, myFontHeight{0}, myLineHeight{0}, myButtonHeight{0};

    ostringstream& buffer() { myBuffer.str(""); return myBuffer; }

  private:
    StringListWidget* myDesc{nullptr};
    ostringstream myBuffer;

  private:
    // Following constructors and assignment operators not supported
    CartDebugWidget() = delete;
    CartDebugWidget(const CartDebugWidget&) = delete;
    CartDebugWidget(CartDebugWidget&&) = delete;
    CartDebugWidget& operator=(const CartDebugWidget&) = delete;
    CartDebugWidget& operator=(CartDebugWidget&&) = delete;
};

#endif
