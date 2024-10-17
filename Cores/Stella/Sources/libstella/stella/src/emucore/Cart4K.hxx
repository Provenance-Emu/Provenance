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

#ifndef CARTRIDGE4K_HXX
#define CARTRIDGE4K_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart4KWidget.hxx"
#endif

/**
  This is the standard Atari 4K cartridge.  These cartridges are
  not bankswitched.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class Cartridge4K : public CartridgeEnhanced
{
  friend class Cartridge4KWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    Cartridge4K(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 4_KB);
    ~Cartridge4K() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "Cartridge4K"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge4KWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16, uInt8) override { return false; }

  private:
    // Following constructors and assignment operators not supported
    Cartridge4K() = delete;
    Cartridge4K(const Cartridge4K&) = delete;
    Cartridge4K(Cartridge4K&&) = delete;
    Cartridge4K& operator=(const Cartridge4K&) = delete;
    Cartridge4K& operator=(Cartridge4K&&) = delete;
};

#endif
