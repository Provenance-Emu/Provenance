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

#ifndef CARTRIDGEF8_HXX
#define CARTRIDGEF8_HXX

#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartF8Widget.hxx"
#endif

/**
  Cartridge class used for Atari's 8K bankswitched games.  There are two
  4K banks, accessible by read/write to $1FF8 - $1FF9.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class CartridgeF8 : public CartridgeEnhanced
{
  friend class CartridgeF8Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeF8(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 8_KB);
    ~CartridgeF8() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeF8"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeF8Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    uInt16 hotspot() const override { return 0x1FF8; }

    uInt16 getStartBank() const override { return 1; }

  private:
    // Following constructors and assignment operators not supported
    CartridgeF8() = delete;
    CartridgeF8(const CartridgeF8&) = delete;
    CartridgeF8(CartridgeF8&&) = delete;
    CartridgeF8& operator=(const CartridgeF8&) = delete;
    CartridgeF8& operator=(CartridgeF8&&) = delete;
};

#endif
