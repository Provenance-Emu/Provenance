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

#ifndef CARTRIDGE4A50_HXX
#define CARTRIDGE4A50_HXX

class System;

#include "bspf.hxx"
#include "Cart.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "Cart4A50Widget.hxx"
#endif

/**
  Bankswitching method as defined/created by John Payson (aka Supercat),
  documented at https://stella-emu.github.io/4A50.html.

  In this bankswitching scheme the 2600's 4K cartridge address space
  is broken into four segments.  The first 2K segment accesses any 2K
  region of RAM, or of the first 32K of ROM.  The second 1.5K segment
  accesses the first 1.5K of any 2K region of RAM, or of the last 32K
  of ROM.  The 3rd 256 byte segment points to any 256 byte page of
  RAM or ROM.  The last 256 byte segment always points to the last 256
  bytes of ROM.

  Because of the complexity of this scheme, the cart reports having
  only one actual bank, in which pieces of it can be swapped out in
  many different ways.  It contains so many hotspots and possibilities
  for the ROM address space to change that we just consider the bank to
  have changed on every poke operation (for any RAM) or an actual bankswitch.

  NOTE: This scheme hasn't been fully implemented, and may never be (there
        is only one test ROM, and it hasn't been extended any further).
        In particular, the following functionality is missing:
          - hires helper functions
          - 1E00 page wrap

  @author  Eckhard Stolberg & Stephen Anthony
*/
class Cartridge4A50 : public Cartridge
{
  friend class Cartridge4A50Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
    */
    Cartridge4A50(const ByteBuffer& image, size_t size, string_view md5,
                  const Settings& settings);
    ~Cartridge4A50() override = default;

  public:
    /**
      Reset cartridge to its power-on state
    */
    void reset() override;

    /**
      Install cartridge in the specified system.  Invoked by the system
      when the cartridge is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Patch the cartridge ROM.

      @param address  The ROM address to patch
      @param value    The value to place into the address
      @return    Success or failure of the patch operation
    */
    bool patch(uInt16 address, uInt8 value) override;

    /**
      Access the internal ROM image for this cartridge.

      @param size  Set to the size of the internal ROM image data
      @return  A reference to the internal ROM image data
    */
    const ByteBuffer& getImage(size_t& size) const override;

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
    string name() const override { return "Cartridge4A50"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new Cartridge4A50Widget(boss, lfont, nfont, x, y, w, h, *this);
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
  #ifdef DEBUGGER_SUPPORT
    /**
      Query the given address type for the associated access flags.

      @param address  The address to query
    */
    Device::AccessFlags getAccessFlags(uInt16 address) const override;
    /**
      Change the given address to use the given access flags.

      @param address  The address to modify
      @param flags    A bitfield of AccessType directives for the given address
    */
    void setAccessFlags(uInt16 address, Device::AccessFlags flags) override;
  #endif
    /**
      Check all possible hotspots
    */
    void checkBankSwitch(uInt16 address, uInt8 value);

    /**
      Methods to perform all the ways that banks can be switched
    */
    inline void bankROMLower(uInt16 value)
    {
      myIsRomLow = true;
      mySliceLow = value << 11;
      myBankChanged = true;
    }

    inline void bankRAMLower(uInt16 value)
    {
      myIsRomLow = false;
      mySliceLow = value << 11;
      myBankChanged = true;
    }

    inline void bankROMMiddle(uInt16 value)
    {
      myIsRomMiddle = true;
      mySliceMiddle = value << 11;
      myBankChanged = true;
    }

    inline void bankRAMMiddle(uInt16 value)
    {
      myIsRomMiddle = false;
      mySliceMiddle = value << 11;
      myBankChanged = true;
    }

    inline void bankROMHigh(uInt16 value)
    {
      myIsRomHigh = true;
      mySliceHigh = value << 8;
      myBankChanged = true;
    }

    inline void bankRAMHigh(uInt16 value)
    {
      myIsRomHigh = false;
      mySliceHigh = value << 8;
      myBankChanged = true;
    }

  private:
    // The 128K ROM image of the cartridge
    ByteBuffer myImage;

    // The 32K of RAM on the cartridge
    std::array<uInt8, 32_KB> myRAM;

    // (Actual) Size of the ROM image
    size_t mySize{0};

    // Indicates the slice mapped into each of the three segments
    uInt16 mySliceLow{0};     // index pointer for $1000-$17ff slice
    uInt16 mySliceMiddle{0};  // index pointer for $1800-$1dff slice
    uInt16 mySliceHigh{0};    // index pointer for $1e00-$1eff slice

    // Indicates whether the given slice is mapped to ROM or RAM
    bool myIsRomLow{true};    // true = ROM -- false = RAM at $1000-$17ff
    bool myIsRomMiddle{true}; // true = ROM -- false = RAM at $1800-$1dff
    bool myIsRomHigh{true};   // true = ROM -- false = RAM at $1e00-$1eFF

    // The previous address and data values (from peek and poke)
    uInt16 myLastAddress{0};
    uInt8 myLastData{0};

  private:
    // Following constructors and assignment operators not supported
    Cartridge4A50() = delete;
    Cartridge4A50(const Cartridge4A50&) = delete;
    Cartridge4A50(Cartridge4A50&&) = delete;
    Cartridge4A50& operator=(const Cartridge4A50&) = delete;
    Cartridge4A50& operator=(Cartridge4A50&&) = delete;
};

#endif
