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

#ifndef CARTRIDGEF0_HXX
#define CARTRIDGEF0_HXX

#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartF0Widget.hxx"
#endif

/**
  Cartridge class used for Dynacom Megaboy
  There are 16 4K banks.
  Accessing $1FF0 switches to next bank.

  @author  Eckhard Stolberg, Thomas Jentzsch
*/
class CartridgeF0 : public CartridgeEnhanced
{
  friend class CartridgeF0Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeF0(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 64_KB);
    ~CartridgeF0() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeF0"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeF0Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    uInt16 hotspot() const override { return 0x1FF0; }

    uInt16 getStartBank() const override { return 15; }

  private:
    // Following constructors and assignment operators not supported
    CartridgeF0() = delete;
    CartridgeF0(const CartridgeF0&) = delete;
    CartridgeF0(CartridgeF0&&) = delete;
    CartridgeF0& operator=(const CartridgeF0&) = delete;
    CartridgeF0& operator=(CartridgeF0&&) = delete;
};

#endif
