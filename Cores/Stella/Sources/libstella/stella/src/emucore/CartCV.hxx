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

#ifndef CARTRIDGECV_HXX
#define CARTRIDGECV_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartCVWidget.hxx"
#endif

/**
  Cartridge class used for Commavid's extra-RAM games.

  $F000-$F3FF read from RAM
  $F400-$F7FF write to RAM
  $F800-$FFFF ROM

  @author  Eckhard Stolberg, Thomas Jentzsch
*/
class CartridgeCV : public CartridgeEnhanced
{
  friend class CartridgeCVWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeCV(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 4_KB);
    ~CartridgeCV() override = default;

  public:
    /**
      Reset cartridge to its power-on state
    */
    void reset() override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeCV"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeCVWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16, uInt8) override { return false; }

  protected:
    // Initial RAM data from the cart (doesn't always exist)
    ByteBuffer myInitialRAM{nullptr};

  private:
    // RAM size
    static constexpr uInt32 RAM_SIZE = 0x400; // 1K

    // Write port for extra RAM is at high address
    static constexpr bool RAM_HIGH_WP = true;

  private:
    // Following constructors and assignment operators not supported
    CartridgeCV() = delete;
    CartridgeCV(const CartridgeCV&) = delete;
    CartridgeCV(CartridgeCV&&) = delete;
    CartridgeCV& operator=(const CartridgeCV&) = delete;
    CartridgeCV& operator=(CartridgeCV&&) = delete;
};

#endif
