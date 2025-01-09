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

#ifndef CARTRIDGE_3EPLUS_HXX
#define CARTRIDGE_3EPLUS_HXX

class System;

#include "bspf.hxx"
#include "Cart3E.hxx"

#ifdef DEBUGGER_SUPPORT
  #include "Cart3EPlusWidget.hxx"
#endif

/**
  Cartridge class for new tiling engine "Boulder Dash" format games with RAM.
  Kind of a combination of 3F and 3E, with better switchability.
  B.Watson's Cart3E was used as a template for building this implementation.

  Note: In descriptions $F000 is equivalent to $1000 -- that is, we only deal
  with the low 13 bits of addressing. Stella code uses $1000, I'm used to $F000
  So, mask with top bits clear :) when reading this document.

  In this scheme, the 4K address space is broken into four 1K ROM/512b RAM segments
  living at 0x1000, 0x1400, 0x1800, 0x1C00 (or, same thing, 0xF000... etc.),

  The destination segment (0-3) is held in the top bits of the value written to
  $3E (for RAM switching) or $3F (for ROM switching). The low 6 bits give
  the actual bank number (0-63) corresponding to 512 byte blocks for RAM and
  1024 byte blocks for ROM. The maximum size is therefore 32K RAM and 64K ROM.

  D7D6         indicate the segment number (0-3)
  D5D4D3D2D1D0 indicate the actual # (0-63) from the image/ram

  ROM:
  The last 1K ROM ($FC00-$FFFF) segment in the 6502 address space (ie: $1C00-$1FFF)
  is initialised to point to the FIRST 1K of the ROM image, so the reset vectors
  must be placed at the end of the first 1K in the ROM image.

  Note: This is DIFFERENT to 3E which switches in the UPPER segment and this
  segment is fixed.  This allows variable sized ROM without having to detect size.

  ROM switching (write of segment+bank number to $3F) D7D6 upper 2 bits of bank #
  indicates the destination segment (0-3, corresponding to $F000, $F400, $F800,
  $FC00), and lower 6 bits indicate the 1K bank to switch in.

  Can handle 64 x 1K ROM banks (64K total).

  D7 D6 D5D4D3D2D1D0
  0  0   x x x x x x   switch a 1K ROM bank xxxxxx to $F000
  0  1                 switch a 1K ROM bank xxxxxx to $F400
  1  0                 switch a 1K ROM bank xxxxxx to $F800
  1  1                 switch a 1K ROM bank xxxxxx to $FC00

  RAM switching (write of segment+bank number to $3E) with D7D6 upper 2 bits of
  bank # indicates the destination RAM segment (0-3, corresponding to $F000,
  $F400, $F800, $FC00).

  Can handle 64 x 512 byte RAM banks (32K total)

  D7 D6 D5D4D3D2D1D0
  0  0   x x x x x x   switch a 512 byte RAM bank xxxxxx to $F000 with write @ $F200
  0  1                 switch a 512 byte RAM bank xxxxxx to $F400 with write @ $F600
  1  0                 switch a 512 byte RAM bank xxxxxx to $F800 with write @ $FA00
  1  1                 switch a 512 byte RAM bank xxxxxx to $FC00 with write @ $FE00

  @author  Thomas Jentzsch and Stephen Anthony
*/

class Cartridge3EPlus: public Cartridge3E
{
  friend class Cartridge3EPlusWidget;

  public:
    /**
      Create a new cartridge using the specified image and size

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
                       (where 0 means variable-sized ROM)
    */
    Cartridge3EPlus(const ByteBuffer& image, size_t size, string_view md5,
                    const Settings& settings, size_t bsSize = 0);
    ~Cartridge3EPlus() override = default;

  public:
    /** Reset device to its power-on state */
    void reset() override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "Cartridge3E+"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge3EPlusWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    /**
      Checks if startup bank randomization is enabled.  For this scheme,
      randomization is not supported (see above).
    */
    bool randomStartBank() const override { return false; }

    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    /**
      Get the number of segments supported by the cartridge.
    */
    uInt16 calcNumSegments() const override { return 4; }


  private:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 10; // = 1K = 0x0400

    // The size of extra RAM in ROM address space
    static constexpr uInt16 RAM_BANKS = 64;

    // RAM size
    static constexpr size_t RAM_SIZE = RAM_BANKS << (BANK_SHIFT - 1); // = 32K = 0x8000;

  private:
    // Following constructors and assignment operators not supported
    Cartridge3EPlus() = delete;
    Cartridge3EPlus(const Cartridge3EPlus&) = delete;
    Cartridge3EPlus(Cartridge3EPlus&&) = delete;
    Cartridge3EPlus& operator=(const Cartridge3EPlus&) = delete;
    Cartridge3EPlus& operator=(Cartridge3EPlus&&) = delete;
};

#endif
