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

#ifndef CARTRIDGEX07_HXX
#define CARTRIDGEX07_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartX07Widget.hxx"
#endif

/**
  Bankswitching method as defined/created by John Payson (aka Supercat)
  and Fred Quimby (aka batari).

  This bankswitching method has 16 4K banks that can be accessed at
  addresses $1000 to $1FFF. The bankswitching hotspots are all below
  $1000. X07 uses two types of hotspots:

  0 1xxx nnnn 1101 -- Switch to bank nnnn
  0 0xxx 0nxx xxxx -- If in bank 111x, switch to bank 111n.
                      In any other bank, do not switch.

  Note that the latter will hit on almost any TIA access.

  @author  Eckhard Stolberg, Thomas Jentzsch
*/
class CartridgeX07 : public CartridgeEnhanced
{
  friend class CartridgeX07Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeX07(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings, size_t bsSize = 64_KB);
    ~CartridgeX07() override = default;

  public:
    /**
      Install cartridge in the specified system.  Invoked by the system
      when the cartridge is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeX07"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeX07Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
    /**
      Get the byte at the specified address.

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address) override;

    /**
      Change the byte at the specified address to the given value

      @param address The address where the value should be stored
      @param value The value to be stored at the address
      @return  True if the poke changed the device address space, else false
    */
    bool poke(uInt16 address, uInt8 value) override;

  private:
    bool checkSwitchBank(uInt16 address, uInt8) override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeX07() = delete;
    CartridgeX07(const CartridgeX07&) = delete;
    CartridgeX07(CartridgeX07&&) = delete;
    CartridgeX07& operator=(const CartridgeX07&) = delete;
    CartridgeX07& operator=(CartridgeX07&&) = delete;
};

#endif
