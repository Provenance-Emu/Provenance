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

#ifndef CARTRIDGEEFSC_HXX
#define CARTRIDGEEFSC_HXX

class System;

#include "bspf.hxx"
#include "CartEF.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartEFSCWidget.hxx"
#endif

/**
  Cartridge class used for Homestar Runner by Paul Slocum.
  There are 16 4K banks (total of 64K ROM) with 128 bytes of RAM.
  Accessing $1FE0 - $1FEF switches to each bank.
  RAM read port is $1080 - $10FF, write port is $1000 - $107F.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class CartridgeEFSC : public CartridgeEF
{
  friend class CartridgeEFSCWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeEFSC(const ByteBuffer& image, size_t size, string_view md5,
                  const Settings& settings, size_t bsSize = 64_KB);
    ~CartridgeEFSC() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeEFSC"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeEFSCWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    uInt16 getStartBank() const override { return 15; }

  private:
    // RAM size
    static constexpr size_t RAM_SIZE = 0x80;

  private:
    // Following constructors and assignment operators not supported
    CartridgeEFSC() = delete;
    CartridgeEFSC(const CartridgeEFSC&) = delete;
    CartridgeEFSC(CartridgeEFSC&&) = delete;
    CartridgeEFSC& operator=(const CartridgeEFSC&) = delete;
    CartridgeEFSC& operator=(CartridgeEFSC&&) = delete;
};

#endif
