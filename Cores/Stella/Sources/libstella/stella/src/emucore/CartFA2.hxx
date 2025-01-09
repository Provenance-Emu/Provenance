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

#ifndef CARTRIDGEFA2_HXX
#define CARTRIDGEFA2_HXX

class System;

#include "bspf.hxx"
#include "CartFA.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartFA2Widget.hxx"
#endif

/**
  This is an extended version of the CBS RAM Plus bankswitching scheme
  supported by the Harmony cartridge.

  There are six (or seven) 4K banks, accessible by read/write to $1FF5 -
  $1FFA (or $1FFB), and 256 bytes of RAM.

  The 256 bytes of RAM can be loaded/saved to Harmony cart flash by
  accessing $1FF4 (see ramReadWrite() for more information), which is
  emulated by storing in a file.
  RAM read port is $1100 - $11FF, write port is $1000 - $10FF.

  For 29K versions of the scheme, the first 1K is ARM code (implements
  actual bankswitching on the Harmony cart), which is completely ignored
  by the emulator.  Also supported is a 32K variant.  In any event, only
  data at 1K - 29K of the ROM is used.

  @author  Chris D. Walton, Thomas Jentzsch
*/
class CartridgeFA2 : public CartridgeFA
{
  friend class CartridgeFA2Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the settings object
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeFA2(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings, size_t bsSize = 28_KB);
    ~CartridgeFA2() override = default;

  public:
    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeFA2"; }

    /**
      Informs the cartridge about the name of the nvram file it will use.

      @param path  The full path of the nvram file
    */
    void setNVRamFile(string_view path) override;

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeFA2Widget(boss, lfont, nfont, x, y, w, h, *this);
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
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    uInt16 hotspot() const override { return 0x1FF5; }

    uInt16 getStartBank() const override { return 0; }

    /**
      Either load or save internal RAM to Harmony flash (represented by
      a file in emulation).

      @return  The value at $FF4 with bit 6 set or cleared (depending on
               whether the RAM access was busy or successful)
    */
    uInt8 ramReadWrite();

    /**
      Modify Harmony flash directly (represented by a file in emulation),
      ignoring any timing emulation.  This is for use strictly in the
      debugger, so you can have low-level access to the Flash media.

      @param operation  0 for erase, 1 for read, 2 for write
    */
    void flash(uInt8 operation);

  private:
    // The time after which the first request of a load/save operation
    // will actually be completed
    // Due to flash RAM constraints, a read/write isn't instantaneous,
    // so we need to emulate the delay as well
    uInt64 myRamAccessTimeout{0};

    // Full pathname of the file to use when emulating load/save
    // of internal RAM to Harmony cart flash
    string myFlashFile;

  private:
    // Following constructors and assignment operators not supported
    CartridgeFA2() = delete;
    CartridgeFA2(const CartridgeFA2&) = delete;
    CartridgeFA2(CartridgeFA2&&) = delete;
    CartridgeFA2& operator=(const CartridgeFA2&) = delete;
    CartridgeFA2& operator=(CartridgeFA2&&) = delete;
};

#endif
