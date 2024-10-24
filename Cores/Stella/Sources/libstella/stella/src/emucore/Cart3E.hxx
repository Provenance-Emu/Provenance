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

#ifndef CARTRIDGE3E_HXX
#define CARTRIDGE3E_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart3EWidget.hxx"
#endif

/**
  This is the cartridge class for Tigervision's bankswitched
  games with RAM (basically, 3F plus up to 32K of RAM). This
  code is basically Brad's Cart3F code plus 32K RAM support.

  In this bankswitching scheme the 2600's 4K cartridge
  address space is broken into two 2K segments.  The last 2K
  segment always points to the last 2K of the ROM image.

  The lower 2K of address space maps to either one of the 2K ROM banks
  (up to 256 of them, though only 240 are supposed to be used for
  compatibility with the Kroko Cart and Cuttle Cart 2), or else one
  of the 1K RAM banks (up to 32 of them). Like other carts with RAM,
  this takes up twice the address space that it should: The lower 1K
  is the read port, and the upper 1K is the write port (maps to the
  same memory).

  To map ROM, the desired bank number of the first 2K segment is selected
  by storing its value into $3F. To map RAM in the first 2K segment
  instead, store the RAM bank number into $3E.

  This implementation of 3E bankswitching numbers the RAM banks (up to 32)
  after the ROM banks (up to 256).

  All 32K of potential RAM is available to a game using this class, even
  though real cartridges might not have the full 32K: We have no way to
  tell how much RAM the game expects. This may change in the future (we
  may add a stella.pro property for this), but for now it shouldn't cause
  any problems. (Famous last words...)

  @author  B. Watson, Thomas Jentzsch
*/

class Cartridge3E : public CartridgeEnhanced
{
  friend class Cartridge3EWidget;

  public:
    /**
      Create a new cartridge using the specified image and size.

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
                       (where 0 means variable-sized ROM)
    */
    Cartridge3E(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 0);
    ~Cartridge3E() override = default;

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
    string name() const override { return "Cartridge3E"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge3EWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
    /**
      Get the byte at the specified address

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
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

  protected:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 11; // = 2K = 0x0800

    // The number of RAM banks
    static constexpr uInt16 RAM_BANKS = 32;

    // RAM size
    static constexpr size_t RAM_SIZE = RAM_BANKS << (BANK_SHIFT - 1); // = 32K = 0x8000;

    // Write port for extra RAM is at high address
    static constexpr bool RAM_HIGH_WP = true;

  private:
    // Following constructors and assignment operators not supported
    Cartridge3E() = delete;
    Cartridge3E(const Cartridge3E&) = delete;
    Cartridge3E(Cartridge3E&&) = delete;
    Cartridge3E& operator=(const Cartridge3E&) = delete;
    Cartridge3E& operator=(Cartridge3E&&) = delete;
};

#endif
