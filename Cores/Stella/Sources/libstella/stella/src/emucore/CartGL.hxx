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

#ifndef CARTRIDGEGL_HXX
#define CARTRIDGEGL_HXX

#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartGLWidget.hxx"
#endif
#include "System.hxx"

/**
  Cartridge class used for the GameLine Master module. In this bankswitching 
  scheme the 2600's 4K cartridge address space is broken into four 1K segments.
  The desired 1K bank of the ROM or RAM is selected as follows:
  - $0480 + x: 1st 1K segment
  - $0580 + x: 2nd 1K segment
  - $0880 + x: 3rd 1K segment
  - $0980 + x: 4th 1K segment
  Where x is defined as follows:
  - bits 0..3: mapped 1K bank (0..3 = ROM bank, 4..f = RAM bank)
  - bit 5: 0 = read, 1 = write (RAM only)
  Initially bank 0 is mapped to all four segments.
  The scheme supports 4K ROM and 2K RAM.

  $0c80.. and $0d80.. control the modem (not implemented, except for PROM access).
  
  @author  Thomas Jentzsch
*/
class CartridgeGL : public CartridgeEnhanced
{
  friend class CartridgeGLWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeGL(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 4_KB);
    ~CartridgeGL() override = default;

  public:
    /**
      Reset device to its power-on state
    */
    void reset() override;

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
    string name() const override { return "CartridgeGL"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeGLWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
    /**
      Get the byte at the specified address.

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address) override;

  private:
    bool checkSwitchBank(uInt16 address, uInt8) override;

  protected:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 10; // = 1K = 0x0400

    // The number of RAM banks
    static constexpr uInt16 RAM_BANKS = 12;

    // RAM size
    static constexpr size_t RAM_SIZE = RAM_BANKS << BANK_SHIFT; // = 12K;

  private:
    // Initial RAM data from the cart (doesn't always exist)
    ByteBuffer myInitialRAM{nullptr};

    bool myEnablePROM{false};

    System::PageAccess myOrgAccess;

  private:
    // Following constructors and assignment operators not supported
    CartridgeGL() = delete;
    CartridgeGL(const CartridgeGL&) = delete;
    CartridgeGL(CartridgeGL&&) = delete;
    CartridgeGL& operator=(const CartridgeGL&) = delete;
    CartridgeGL& operator=(CartridgeGL&&) = delete;
};

#endif
