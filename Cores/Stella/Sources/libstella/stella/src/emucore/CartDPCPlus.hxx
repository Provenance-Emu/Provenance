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

#ifndef CARTRIDGE_DPC_PLUS_HXX
#define CARTRIDGE_DPC_PLUS_HXX

class System;

#ifdef DEBUGGER_SUPPORT
  #include "CartDPCPlusWidget.hxx"
#endif

#include "bspf.hxx"
#include "CartARM.hxx"

/**
  Cartridge class used for DPC+, derived from Pitfall II.  There are six 4K
  program banks, a 4K display bank, 1K frequency table and the DPC chip.
  DPC chip access is mapped to $1000 - $1080 ($1000 - $103F is read port,
  $1040 - $107F is write port).
  Program banks are accessible by read/write to $1FF6 - $1FFB.

  FIXME: THIS NEEDS TO BE UPDATED

  For complete details on the DPC chip see David P. Crane's United States
  Patent Number 4,644,495.

  @authors  Darrell Spice Jr, Fred Quimby, Stephen Anthony, Bradford W. Mott
*/
class CartridgeDPCPlus : public CartridgeARM
{
  friend class CartridgeDPCPlusWidget;
  friend class CartridgeRamDPCPlusWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
    */
    CartridgeDPCPlus(const ByteBuffer& image, size_t size, string_view md5,
                     const Settings& settings);
    ~CartridgeDPCPlus() override = default;

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

      @param bank     The bank that should be installed in the system
      @param segment  The segment the bank should be using

      @return  true, if bank has changed
    */
    bool bank(uInt16 bank, uInt16 segment = 0) override;

    /**
      Get the current bank.

      @param address The address to use when querying the bank
    */
    uInt16 getBank(uInt16 address = 0) const override;

    /**
      Query the number of banks supported by the cartridge.
    */
    uInt16 romBankCount() const override;

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
    string name() const override { return "CartridgeDPC+"; }

    /**
      Query the internal RAM size of the cart.

      @return The internal RAM size
    */
    uInt32 internalRamSize() const override { return static_cast<uInt32>(myDPCRAM.size()); }

    /**
      Read a byte from cart internal RAM.

      @return The value of the interal RAM byte
    */
    uInt8 internalRamGetValue(uInt16 addr) const override;

    /**
      Answer whether this is a PlusROM cart.  Note that until the
      initialize method has been called, this will always return false.

      @return  Whether this is actually a PlusROM cart
    */
    bool isPlusROM() const override { return myPlusROM->isValid(); }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeDPCPlusWidget(boss, lfont, nfont, x, y, w, h, *this);
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
      Checks if startup bank randomization is enabled.  For this scheme,
      randomization is not supported, since the ARM code is always in a
      pre-defined bank, and we *must* start from there.
    */
    bool randomStartBank() const override { return false; }

    /**
      Sets the initial state of the DPC pointers and RAM
    */
    void setInitialState() override;

    /**
      Clocks the random number generator to move it to its next state
    */
    void clockRandomNumberGenerator();

    /**
      Clocks the random number generator to move it to its prior state
    */
    void priorClockRandomNumberGenerator();

    /**
      Updates any data fetchers in music mode based on the number of
      CPU cycles which have passed since the last update.
    */
    void updateMusicModeDataFetchers();

    /**
      Call Special Functions
    */
    void callFunction(uInt8 value);

  private:
    // The ROM image and size
    ByteBuffer myImage;
    size_t mySize{0};

    // Pointer to the 24K program ROM image of the cartridge
    uInt8* myProgramImage{nullptr};

    // Pointer to the 4K display ROM image of the cartridge
    uInt8* myDisplayImage{nullptr};

    // The DPC 8k RAM image, used as:
    //   3K DPC+ driver
    //   4K Display Data
    //   1K Frequency Data
    std::array<uInt8, 8_KB> myDPCRAM;

    // Pointer to the 1K frequency table
    uInt8* myFrequencyImage{nullptr};

    // The top registers for the data fetchers
    std::array<uInt8, 8> myTops;

    // The bottom registers for the data fetchers
    std::array<uInt8, 8> myBottoms;

    // The counter registers for the data fetchers
    std::array<uInt16, 8> myCounters;

    // The counter registers for the fractional data fetchers
    std::array<uInt32, 8> myFractionalCounters;

    // The fractional increments for the data fetchers
    std::array<uInt8, 8> myFractionalIncrements;

    // The Fast Fetcher Enabled flag
    bool myFastFetch{false};

    // Flags that last byte peeked was A9 (LDA #)
    bool myLDAimmediate{false};

    // Parameter for special functions
    std::array<uInt8, 8> myParameter;

    // Parameter pointer for special functions
    uInt8 myParameterPointer{0};

    // The music mode counters
    std::array<uInt32, 3> myMusicCounters;

    // The music frequency
    std::array<uInt32, 3> myMusicFrequencies;

    // The music waveforms
    std::array<uInt16, 3> myMusicWaveforms;

    // The random number generator register
    uInt32 myRandomNumber{1};

    // System cycle count from when the last update to music data fetchers occurred
    uInt64 myAudioCycles{0};

    // System cycle count when the last Thumbulator::run() occurred
    uInt64 myARMCycles{0};

    // Fractional DPC music OSC clocks unused during the last update
    double myFractionalClocks{0.0};

    // Indicates the offset into the ROM image (aligns to current bank)
    uInt16 myBankOffset{0};

    // MD5 value of the 3K DPC+ driver. Used to determine which mask to use,
    // and shown in the Cartridge tab of the debugger
    string myDriverMD5;

    // Older DPC+ driver code had different behaviour wrt the mask used
    // to retrieve 'DFxFRACLOW' (fractional data pointer low byte)
    // ROMs built with an old DPC+ driver and using the newer mask can
    // result in 'jittering' in the playfield display
    // For current versions, this is 0x0F00FF; older versions need 0x0F0000
    uInt32 myFractionalLowMask{0x0F00FF};

  private:
    // Following constructors and assignment operators not supported
    CartridgeDPCPlus() = delete;
    CartridgeDPCPlus(const CartridgeDPCPlus&) = delete;
    CartridgeDPCPlus(CartridgeDPCPlus&&) = delete;
    CartridgeDPCPlus& operator=(const CartridgeDPCPlus&) = delete;
    CartridgeDPCPlus& operator=(CartridgeDPCPlus&&) = delete;
};

#endif
