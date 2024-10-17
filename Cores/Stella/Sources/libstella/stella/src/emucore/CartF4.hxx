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

#ifndef CARTRIDGEF4_HXX
#define CARTRIDGEF4_HXX

#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartF4Widget.hxx"
#endif

/**
  Cartridge class used for Atari's 32K bankswitched games.  There are eight
  4K banks, accessible by read/write to $1FF4 - $1FFB.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class CartridgeF4 : public CartridgeEnhanced
{
  friend class CartridgeF4Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeF4(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 32_KB);
    ~CartridgeF4() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeF4"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeF4Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8) override;

    uInt16 hotspot() const override { return 0x1FF4; }

private:
    // Following constructors and assignment operators not supported
    CartridgeF4() = delete;
    CartridgeF4(const CartridgeF4&) = delete;
    CartridgeF4(CartridgeF4&&) = delete;
    CartridgeF4& operator=(const CartridgeF4&) = delete;
    CartridgeF4& operator=(CartridgeF4&&) = delete;
};

#endif
