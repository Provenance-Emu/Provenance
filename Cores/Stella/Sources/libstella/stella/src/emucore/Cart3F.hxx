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

#ifndef CARTRIDGE3F_HXX
#define CARTRIDGE3F_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart3FWidget.hxx"
#endif

/**
  This is the cartridge class for Tigervision's bankswitched
  games.  In this bankswitching scheme the 2600's 4K cartridge
  address space is broken into two 2K segments.  The last 2K
  segment always points to the last 2K of the ROM image.  The
  desired bank number of the first 2K segment is selected by
  storing its value into $3F.  Actually, any write to location
  $00 to $3F will change banks.  Although, the Tigervision games
  only used 8K this bankswitching scheme supports up to 512K.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class Cartridge3F : public CartridgeEnhanced
{
  friend class Cartridge3FWidget;

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
    Cartridge3F(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 0);
    ~Cartridge3F() override = default;

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
    string name() const override { return "Cartridge3F"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge3FWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    uInt16 hotspot() const override { return 0x003F; }

  private:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 11; // = 2K = 0x0800

  private:
    // Following constructors and assignment operators not supported
    Cartridge3F() = delete;
    Cartridge3F(const Cartridge3F&) = delete;
    Cartridge3F(Cartridge3F&&) = delete;
    Cartridge3F& operator=(const Cartridge3F&) = delete;
    Cartridge3F& operator=(Cartridge3F&&) = delete;
};

#endif
