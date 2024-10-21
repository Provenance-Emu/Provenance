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

#ifndef CARTRIDGE_BUS_HXX
#define CARTRIDGE_BUS_HXX

class System;

#include "bspf.hxx"
#include "CartARM.hxx"

/**
  Cartridge class used for BUS.

  THIS BANKSWITCHING SCHEME IS EXPERIMENTAL, AND MAY BE REMOVED
  IN A FUTURE RELEASE.

  There are seven 4K program banks, a 4K Display Data RAM,
  1K C Variable and Stack, and the BUS chip.
  BUS chip access is mapped to $1000 - $103F.

  @authors: Darrell Spice Jr, Chris Walton, Fred Quimby,
            Stephen Anthony, Bradford W. Mott
*/
class CartridgeBUS : public CartridgeARM
{
  friend class CartridgeBUSWidget;
  friend class CartridgeBUSInfoWidget;
  friend class CartridgeRamBUSWidget;

  enum class BUSSubtype {
    BUS0, // very old demos when BUS was in flux, not supported in Stella
    BUS1, // draconian_20161102.bin
    BUS2, // 128bus_20170120.bin, 128chronocolour_20170101.bin, parrot_20161231_NTSC.bin
    BUS3  // rpg_20170616_NTSC.bin
  };


  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
    */
    CartridgeBUS(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings);
    ~CartridgeBUS() override = default;

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
    string name() const override;

    uInt8 busOverdrive(uInt16 address);

  /**
   Used for Thumbulator to pass values back to the cartridge
   */
  uInt32 thumbCallback(uInt8 function, uInt32 value1, uInt32 value2) override;

  /**
    Query the internal RAM size of the cart.

    @return The internal RAM size
  */
  uInt32 internalRamSize() const override { return static_cast<uInt32>(myRAM.size()); }

  /**
    Read a byte from cart internal RAM.

    @return The value of the interal RAM byte
  */
  uInt8 internalRamGetValue(uInt16 addr) const override;


  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont, int x, int y, int w, int h) override;

    CartDebugWidget* infoWidget(GuiObject* boss, const GUI::Font& lfont,
                                const GUI::Font& nfont, int x, int y, int w, int h) override;

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
      Updates any data fetchers in music mode based on the number of
      CPU cycles which have passed since the last update.
    */
    void updateMusicModeDataFetchers();

    /**
      Call Special Functions
    */
    void callFunction(uInt8 value);

    uInt32 getDatastreamPointer(uInt8 index) const;
    void setDatastreamPointer(uInt8 index, uInt32 value);

    uInt32 getDatastreamIncrement(uInt8 index) const;
    void setDatastreamIncrement(uInt8 index, uInt32 value);

    uInt32 getAddressMap(uInt8 index) const;
    void setAddressMap(uInt8 index, uInt32 value);

    uInt8 readFromDatastream(uInt8 index);

    uInt32 getWaveform(uInt8 index) const;
    uInt32 getWaveformSize(uInt8 index) const;
    uInt32 getSample();
    void setupVersion();
    uInt32 scanBUSDriver(uInt32 value);

  private:
    // The 32K ROM image of the cartridge
    ByteBuffer myImage;

    // Pointer to the 28K program ROM image of the cartridge
    uInt8* myProgramImage{nullptr};

    // Pointer to the 4K display ROM image of the cartridge
    uInt8* myDisplayImage{nullptr};

    // Pointer to the 2K BUS driver image in RAM
    uInt8* myDriverImage{nullptr};

    // The BUS 8k RAM image, used as:
    //   $0000 - 2K BUS driver
    //   $0800 - 4K Display Data
    //   $1800 - 2K C Variable & Stack
    std::array<uInt8, 8_KB> myRAM;

    // Indicates the offset into the ROM image (aligns to current bank)
    uInt16 myBankOffset{0};

    // Address to override the bus for
    uInt16 myBusOverdriveAddress{0};

    // set to address of ZP if last byte peeked was $84 (STY ZP)
    uInt16 mySTYZeroPageAddress{0};

    // set to address of the JMP operand if last byte peeked was 4C
    // *and* the next two bytes in ROM are 00 00
    uInt16 myJMPoperandAddress{0};

    // System cycle count from when the last update to music data fetchers occurred
    uInt64 myAudioCycles{0};

    // ARM cycle count from when the last callFunction() occurred
    uInt64 myARMCycles{0};

    // Pointer to the array of datastream pointers
    uInt16 myDatastreamBase{0}; // was DSxPTR

    // Pointer to the array of datastream increments
    uInt16 myDatastreamIncrementBase{0};  // was DSxINC

    // Pointer to the array of datastream maps
    uInt16 myDatastreamMapBase{0};  // was DSMAPS

    // Pointer to the beginning of the waveform data block
    uInt16 myWaveformBase{0}; // was WAVEFORM

    // The music mode counters
    std::array<uInt32, 3> myMusicCounters{0};

    // The music frequency
    std::array<uInt32, 3> myMusicFrequencies{0};

    // The music waveform sizes
    std::array<uInt8, 3> myMusicWaveformSize{0};

    // Fractional DPC music OSC clocks unused during the last update
    double myFractionalClocks{0.0};

    // Controls mode, lower nybble sets Fast Fetch, upper nybble sets audio
    // -0 = Bus Stuffing ON
    // -F = Bus Stuffing OFF
    // 0- = Packed Digital Sample
    // F- = 3 Voice Music
    uInt8 myMode{0};

    uInt8 myFastJumpActive{false};

  // BUS subtype
  BUSSubtype myBUSSubtype{BUSSubtype::BUS1};

  private:
    // Following constructors and assignment operators not supported
    CartridgeBUS() = delete;
    CartridgeBUS(const CartridgeBUS&) = delete;
    CartridgeBUS(CartridgeBUS&&) = delete;
    CartridgeBUS& operator=(const CartridgeBUS&) = delete;
    CartridgeBUS& operator=(CartridgeBUS&&) = delete;
};

#endif
