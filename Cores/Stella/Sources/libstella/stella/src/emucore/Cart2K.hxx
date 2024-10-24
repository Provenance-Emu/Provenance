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

#ifndef CARTRIDGE2K_HXX
#define CARTRIDGE2K_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart2KWidget.hxx"
#endif

/**
  This is the standard Atari 2K cartridge.  These cartridges are not
  bankswitched, however, the data repeats twice in the 2600's 4K cartridge
  addressing space.  For 'Sub2K' ROMs (ROMs less than 2K in size), the
  data repeats in intervals based on the size of the ROM (which will
  always be a power of 2).

  @author  Stephen Anthony, Thomas Jentzsch
*/
class Cartridge2K : public CartridgeEnhanced
{
  friend class Cartridge2KWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image (<= 2048 bytes)
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    Cartridge2K(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 2_KB);
    ~Cartridge2K() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "Cartridge2K"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge2KWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16, uInt8) override { return false; }

  private:
    // Following constructors and assignment operators not supported
    Cartridge2K() = delete;
    Cartridge2K(const Cartridge2K&) = delete;
    Cartridge2K(Cartridge2K&&) = delete;
    Cartridge2K& operator=(const Cartridge2K&) = delete;
    Cartridge2K& operator=(Cartridge2K&&) = delete;
};

#endif
