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

#ifndef CARTRIDGEWD_HXX
#define CARTRIDGEWD_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartWDWidget.hxx"
#endif

/**
  This is the cartridge class for a "Wickstead Design" prototype cart.
  The ROM has 64 bytes of RAM.
  In this bankswitching scheme the 2600's 4K cartridge address space
  is broken into four 1K segments.  The desired arrangement of 1K banks
  is selected by accessing $30 - $3F of TIA address space.  The banks
  are mapped into all 4 segments at once as follows:

    $0030, $0038: 0,0,1,3
    $0031, $0039: 0,1,2,3
    $0032, $003A: 4,5,6,7
    $0033, $003B: 7,4,2,3

    $0034, $003C: 0,0,6,7
    $0035, $003D: 0,1,7,6
    $0036, $003E: 2,3,4,5
    $0037, $003F: 6,0,5,1


  (Removed: In the uppermost (third) segment, the byte at $3FC is overwritten by 0.)

  The 64 bytes of RAM are accessible at $1000 - $103F (read port) and
  $1040 - $107F (write port).  Because the RAM takes 128 bytes of address
  space, the range $1000 - $107F of segment 0 ROM will never be available.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class CartridgeWD : public CartridgeEnhanced
{
  friend class CartridgeWDWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeWD(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 8_KB);
    ~CartridgeWD() override = default;

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
      Install pages for the specified bank in the system.

      @param bank The bank that should be installed in the system
    */
    bool bank(uInt16 bank, uInt16 = 0) override;

    /**
      Get the current bank.

      @param address The address to use when querying the bank
    */
    uInt16 getBank(uInt16 address = 0) const override;

    /**
      Save the current state of this cart to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    bool save(Serializer& out) const override;

    /**
      Load the current state of this cart from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    bool load(Serializer& in) override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeWD"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeWDWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
    /**
      Get the byte at the specified address.

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address) override;

    /**
      Change the byte at the specified address to the given value.

      @param address The address where the value should be stored
      @param value The value to be stored at the address
      @return  True if the poke changed the device address space, else false
    */
    bool poke(uInt16 address, uInt8 value) override;

  private:
    /**
      Checks if startup bank randomization is enabled.  For this scheme,
      randomization is not supported.
    */
    bool randomStartBank() const override { return false; }

    bool checkSwitchBank(uInt16, uInt8) override { return false; }

    uInt16 hotspot() const override { return 0x0030; }

  private:
    // Indicates the cycle at which a bankswitch was initiated
    uInt64 myCyclesAtBankswitchInit{0};

    // Indicates the bank we wish to switch to in the future
    uInt16 myPendingBank{0};

    // Indicates which bank is currently active
    uInt16 myCurrentBank{0};

    // The arrangement of banks to use on each hotspot read
    struct BankOrg {
      uInt8 zero{0}, one{0}, two{0}, three{0};
    };
    static constexpr std::array<BankOrg, 8> ourBankOrg = {{
                       //             0 1 2 3 4 5 6 7
      { 0, 0, 1, 3 },  // Bank 0,  8  2 1 - 1 - - - -
      { 0, 1, 2, 3 },  // Bank 1,  9  1 1 1 1 - - - -
      { 4, 5, 6, 7 },  // Bank 2, 10  - - - - 1 1 1 1
      { 7, 4, 2, 3 },  // Bank 3, 11  - - 1 1 1 - - 1
      { 0, 0, 6, 7 },  // Bank 4, 12  2 - - - - - 1 1
      { 0, 1, 7, 6 },  // Bank 5, 13  1 1 - - - - 1 1
      { 2, 3, 4, 5 },  // Bank 6, 14  - - 1 1 1 1 - -
      { 6, 0, 5, 1 }   // Bank 7, 15  1 1 - - - 1 1 -
                       // count       7 4 3 4 3 3 4 4
    }};

  private:
    // log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 10; // = 1K = 0x0400

    // RAM size
    static constexpr size_t RAM_SIZE = 0x40;

    // Write port for extra RAM is at low address by default
    static constexpr bool RAM_HIGH_WP = true;

  private:
    // Following constructors and assignment operators not supported
    CartridgeWD() = delete;
    CartridgeWD(const CartridgeWD&) = delete;
    CartridgeWD(CartridgeWD&&) = delete;
    CartridgeWD& operator=(const CartridgeWD&) = delete;
    CartridgeWD& operator=(CartridgeWD&&) = delete;
};

#endif
