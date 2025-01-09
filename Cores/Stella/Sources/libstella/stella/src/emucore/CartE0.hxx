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

#ifndef CARTRIDGEE0_HXX
#define CARTRIDGEE0_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartE0Widget.hxx"
#endif

/**
  This is the cartridge class for Parker Brothers' 8K games.  In
  this bankswitching scheme the 2600's 4K cartridge address space
  is broken into four 1K segments.  The desired 1K bank of the
  ROM is selected by accessing $1FE0 to $1FE7 for the first 1K.
  $1FE8 to $1FEF selects the bank for the second 1K, and $1FF0 to
  $1FF7 selects the bank for the third 1K.  The last 1K segment
  always points to the last 1K of the ROM image.

  Because of the complexity of this scheme, the cart reports having
  only one actual bank, in which pieces of it can be swapped out in
  many different ways.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class CartridgeE0 : public CartridgeEnhanced
{
  friend class CartridgeE0Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeE0(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 8_KB);
    ~CartridgeE0() override = default;

  public:
    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeE0"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeE0Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8) override;

    uInt16 hotspot() const override { return 0x1FE0; }

  private:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 10; // = 1K = 0x0400

  private:
    // Following constructors and assignment operators not supported
    CartridgeE0() = delete;
    CartridgeE0(const CartridgeE0&) = delete;
    CartridgeE0(CartridgeE0&&) = delete;
    CartridgeE0& operator=(const CartridgeE0&) = delete;
    CartridgeE0& operator=(CartridgeE0&&) = delete;
};

#endif
