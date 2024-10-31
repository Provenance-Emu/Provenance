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

#ifndef Cartridge03E0_HXX
#define Cartridge03E0_HXX

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#include "System.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart03E0Widget.hxx"
#endif

/**
  This is the cartridge class for Parker Brothers' 8K games with special
  Brazilian bankswitching.  In this bankswitching scheme the 2600's 4K
  cartridge address space is broken into four 1K segments.

  The desired 1K bank of the ROM is selected as follows:
    If A12 == 0, A9 == 1, A8 == 1, A7 == 1 ($0380..$03ff):
      A4 == 0 ($03e0) loads the bank number for segment #0
      A5 == 0 ($03d0) loads the bank number for segment #1
      A6 == 0 ($03b0) loads the bank number for segment #2
    Bits A0, A1, A2 determine the bank number (0..7)

  The last 1K segment always points to the last 1K of the ROM image.

  Because of the complexity of this scheme, the cart reports having
  only one actual bank, in which pieces of it can be swapped out in
  many different ways.

  @author  Thomas Jentzsch
*/
class Cartridge03E0 : public CartridgeEnhanced
{
  friend class Cartridge03E0Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    Cartridge03E0(const ByteBuffer& image, size_t size, string_view md5,
                  const Settings& settings, size_t bsSize = 8_KB);
    ~Cartridge03E0() override = default;

  public:
    /**
      Install cartridge in the specified system.  Invoked by the system
      when the cartridge is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "Cartridge03E0"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
      const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge03E0Widget(boss, lfont, nfont, x, y, w, h, *this);
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

    uInt16 hotspot() const override { return 0x0380; }

  private:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 10; // = 1K = 0x0400

    // Previous Device's page access
    std::array<System::PageAccess, 2> myHotSpotPageAccess;

  private:
    // Following constructors and assignment operators not supported
    Cartridge03E0() = delete;
    Cartridge03E0(const Cartridge03E0&) = delete;
    Cartridge03E0(Cartridge03E0&&) = delete;
    Cartridge03E0& operator=(const Cartridge03E0&) = delete;
    Cartridge03E0& operator=(Cartridge03E0&&) = delete;
};

#endif
