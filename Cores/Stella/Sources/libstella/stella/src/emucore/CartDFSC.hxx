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

#ifndef CARTRIDGEDFSC_HXX
#define CARTRIDGEDFSC_HXX

class System;

#include "bspf.hxx"
#include "CartDF.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartDFSCWidget.hxx"
#endif

/**
  There are 32 4K banks (total of 128K ROM) with 128 bytes of RAM.
  Accessing $1FC0 - $1FDF switches to each bank.
  RAM read port is $1080 - $10FF, write port is $1000 - $107F.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class CartridgeDFSC : public CartridgeDF
{
  friend class CartridgeDFSCWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeDFSC(const ByteBuffer& image, size_t size, string_view md5,
                  const Settings& settings, size_t bsSize = 128_KB);
    ~CartridgeDFSC() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeDFSC"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeDFSCWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    // RAM size
    static constexpr size_t RAM_SIZE = 0x80;

private:
    // Following constructors and assignment operators not supported
    CartridgeDFSC() = delete;
    CartridgeDFSC(const CartridgeDFSC&) = delete;
    CartridgeDFSC(CartridgeDFSC&&) = delete;
    CartridgeDFSC& operator=(const CartridgeDFSC&) = delete;
    CartridgeDFSC& operator=(CartridgeDFSC&&) = delete;
};

#endif
