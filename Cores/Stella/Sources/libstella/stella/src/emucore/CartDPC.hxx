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

#ifndef CARTRIDGE_DPC_HXX
#define CARTRIDGE_DPC_HXX

#include "CartF8.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartDPCWidget.hxx"
#endif

/**
  Cartridge class used for Pitfall II.  There are two 4K program banks, a
  2K display bank, and the DPC chip.  The bankswitching itself is the same
  as F8 scheme (hotspots at $1FF8 and $1FF9).  DPC chip access is mapped to
  $1000 - $1080 ($1000 - $103F is read port, $1040 - $107F is write port).

  For complete details on the DPC chip see David P. Crane's United States
  Patent Number 4,644,495.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class CartridgeDPC : public CartridgeF8
{
  friend class CartridgeDPCWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeDPC(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings, size_t bsSize = 10_KB);
    ~CartridgeDPC() override = default;

  public:
    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Notification method invoked by the system when the console type
      has changed.  We need this to inform the Thumbulator that the
      timing has changed.

      @param timing  Enum representing the new console type
    */

    void consoleChanged(ConsoleTiming timing) override;
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
    string name() const override { return "CartridgeDPC"; }

    /**
      Change the DPC audio pitch

      @param pitch  The new pitch value
    */
    void setDpcPitch(double pitch) { myDpcPitch = pitch; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeDPCWidget(boss, lfont, nfont, x, y, w, h, *this);
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
    /**
      Clocks the random number generator to move it to its next state
    */
    void clockRandomNumberGenerator();

    /**
      Updates any data fetchers in music mode based on the number of
      CPU cycles which have passed since the last update.
    */
    void updateMusicModeDataFetchers();

  private:
    // Console clock rate
    double myClockRate{1193191.66666667};

    // Pointer to the 2K display ROM image of the cartridge
    uInt8* myDisplayImage{nullptr};

    // The top registers for the data fetchers
    std::array<uInt8, 8> myTops{0};

    // The bottom registers for the data fetchers
    std::array<uInt8, 8> myBottoms{0};

    // The counter registers for the data fetchers
    std::array<uInt16, 8> myCounters{0};

    // The flag registers for the data fetchers
    std::array<uInt8, 8> myFlags{0};

    // The music mode DF5, DF6, & DF7 enabled flags
    std::array<bool, 3> myMusicMode{false};

    // The random number generator register
    uInt8 myRandomNumber{1};  // DPC's RNG register (must be non-zero)

    // System cycle count from when the last update to music data fetchers occurred
    uInt64 myAudioCycles{0};

    // Fractional DPC music OSC clocks unused during the last update
    double myFractionalClocks{0.0};

    // DPC pitch
    double myDpcPitch{0.0};

  private:
    // Following constructors and assignment operators not supported
    CartridgeDPC() = delete;
    CartridgeDPC(const CartridgeDPC&) = delete;
    CartridgeDPC(CartridgeDPC&&) = delete;
    CartridgeDPC& operator=(const CartridgeDPC&) = delete;
    CartridgeDPC& operator=(CartridgeDPC&&) = delete;
};

#endif
