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

#ifndef CART_RAM_WIDGET_HXX
#define CART_RAM_WIDGET_HXX

class GuiObject;
class DataGridOpsWidget;
class StringListWidget;
class InternalRamWidget;
class CartDebugWidget;

#include "RamWidget.hxx"
#include "Widget.hxx"
#include "Command.hxx"

class CartRamWidget : public Widget, public CommandSender
{
  public:
    CartRamWidget(GuiObject* boss, const GUI::Font& lfont,
                  const GUI::Font& nfont,
                  int x, int y, int w, int h, CartDebugWidget& cartDebug);
    ~CartRamWidget() override = default;

    void loadConfig() override;
    void setOpsWidget(DataGridOpsWidget* w);

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  protected:
    // Font used for 'normal' text; _font is for 'label' text
    const GUI::Font& _nfont;

    // These will be needed by most of the child classes;
    // we may as well make them protected variables
    int myFontWidth{0}, myFontHeight{0}, myLineHeight{0}, myButtonHeight{0};

  private:
    // Following constructors and assignment operators not supported
    CartRamWidget() = delete;
    CartRamWidget(const CartRamWidget&) = delete;
    CartRamWidget(CartRamWidget&&) = delete;
    CartRamWidget& operator=(const CartRamWidget&) = delete;
    CartRamWidget& operator=(CartRamWidget&&) = delete;

  private:
    class InternalRamWidget : public RamWidget
    {
      public:
        InternalRamWidget(GuiObject* boss, const GUI::Font& lfont,
                          const GUI::Font& nfont,
                          int x, int y, int w, int h,
                          CartDebugWidget& dbg);
        ~InternalRamWidget() override = default;
        string getLabel(int addr) const override;

      private:
        uInt8 getValue(int addr) const override;
        void setValue(int addr, uInt8 value) override;

        void fillList(uInt32 start, uInt32 size, IntArray& alist,
                      IntArray& vlist, BoolArray& changed) const override;
        uInt32 readPort(uInt32 start) const override;
        const ByteArray& currentRam(uInt32 start) const override;

      private:
        CartDebugWidget& myCart;

      private:
        // Following constructors and assignment operators not supported
        InternalRamWidget() = delete;
        InternalRamWidget(const InternalRamWidget&) = delete;
        InternalRamWidget(InternalRamWidget&&) = delete;
        InternalRamWidget& operator=(const InternalRamWidget&) = delete;
        InternalRamWidget& operator=(InternalRamWidget&&) = delete;
    };

  private:
    StringListWidget* myDesc{nullptr};
    InternalRamWidget* myRam{nullptr};
};

#endif
