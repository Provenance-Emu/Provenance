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

#ifndef CARTRIDGECHETIRY_HXX
#define CARTRIDGECHETIRY_HXX

class System;

#include "bspf.hxx"
#include "Cart.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartCTYWidget.hxx"
#endif

/**
  The 'Chetiry' bankswitch scheme was developed by Chris D. Walton for a
  Tetris clone game by the same name.  It makes use of a Harmony cart,
  whereby ARM code in bank 0 is executed to implement the bankswitch scheme.
  The implementation here does not execute this ARM code, and instead
  implements the bankswitching directly.  Its functionality is similar to
  several other schemes, as follows:

  F4SC:
    The scheme contains 8 4K banks, with the first bank being inaccessible
    (due to containing ARM code).  The remaining banks (1 - 7) are accessed
    at hotspots $FF5 - $FFB, exactly the same as F4SC.

    There is 64 bytes of RAM (vs. 128 bytes in F4SC) at $1000 - $107F
    ($1000 - $103F is write port, $1040 - $107F is read port).

  FA2:
    The first four bytes of RAM are actually a kind of hotspot, with the
    following functionality.  Data is accessed from Harmony EEPROM in
    the same fashion as the FA2 scheme.

    Write Addresses:
      $1000 = Operation Type (see discussion of hotspot $1FF4 below)
      $1001 = Set Random Seed Value
      $1002 = Reset Fetcher To Beginning Of Tune
      $1003 = Advance Fetcher To Next Tune Position

    Read Addresses:
      $1040 = Error Code after operation
      $1041 = Get Next Random Number (8-bit LFSR)
      $1042 = Get Tune Position (Low Byte)
      $1043 = Get Tune Position (High Byte)

    RAM Load And Save Operations:

      Address $1FF4 is used as a special hotspot to trigger loading and saving
      of the RAM, similar to FA2 bankswitching. The operation to perform is
      given using the first byte of the extra RAM. The format of this byte is
      XXXXYYYY, where XXXX is an index and YYYY is the operation to perform.
      There are 4 different operation types:

        1 = Load Tune (index = tune)
        2 = Load Score Table (index = table)
        3 = Save Score Table (index = table)
        4 = Wipe All Score Tables (set all 256 bytes of EEPROM to $00)

      The score table functionality is based on 256 bytes from Harmony
      EEPROM, of which there are 4 64-byte 'tables'.  The 'index' for
      operations 2 and 3 can therefore be in the range 0 - 3, indicating
      which table to use.  For this implementation, the 256 byte EEPROM
      is serialized to a file.

      The tune table functionality is also based on Harmony EEPROM, where
      7 4K tunes are stored (28K total).  The 'index' for operation 1 can
      therefore be in the range 0 - 6, indicating which tune to load.

  DPC+:
    The music functionality is quite similar to the DPC+ scheme.

    Fast Fetcher
      The music frequency value is fetched using a fast fetcher operation.
      This operation is aliased to the instruction "LDA #$F2". Whenever this
      instruction is executed, the $F2 value is replaced with the frequency
      value calculated from the tune data. The pointer to the tune data does
      not advance until address $1003 is written. When a new tune is loaded,
      the pointer is reset to the beginning of the tune. This also happens
      when the end of the tune is reached or when address $1002 is written to.

      The calculation of the frequency value is essentially the same as DPC.
      There are 3 different channels that are combined together, and only a
      square waveform is used.  The data is formatted so that the three notes
      for each position appear consecutively (note0, note1, note2).  Moving
      to the next tune position means incrementing by 3 bytes. The end of the
      tune is marked by a note value of 1. A note value of 0 means that the
      current value should not be updated, i.e continue with the previous
      non-zero value.

  @author  Stephen Anthony and Chris D. Walton
*/
class CartridgeCTY : public Cartridge
{
  friend class CartridgeCTYWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the settings object
    */
    CartridgeCTY(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings);
    ~CartridgeCTY() override = default;

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
    string name() const override { return "CartridgeCTY"; }

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
      return new CartridgeCTYWidget(boss, lfont, nfont, x, y, w, h, *this);
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
      Either load or save internal RAM to Harmony EEPROM (represented by
      a file in emulation).

      @return  The value at $FF4 with bit 6 set or cleared (depending on
               whether the RAM access was busy or successful)
    */
    uInt8 ramReadWrite();

    /**
      Actions initiated by accessing $FF4 hotspot.
    */
    void loadTune(uInt8 index);
    void loadScore(uInt8 index);
    void saveScore(uInt8 index);
    void wipeAllScores();

    /**
      Updates any data fetchers in music mode based on the number of
      CPU cycles which have passed since the last update.
    */
    void updateMusicModeDataFetchers();

    void updateTune();

  private:
    // The 32K ROM image of the cartridge
    ByteBuffer myImage;

    // The 28K ROM image of the music
    std::array<uInt8, 28_KB> myTuneData;

    // The 64 bytes of RAM accessible at $1000 - $1080
    std::array<uInt8, 64> myRAM;

    // Console clock rate
    double myClockRate{1193191.66666667};

    // Operation type (written to $1000, used by hotspot $1FF4)
    uInt8 myOperationType{0};

    // Pointer to the 28K frequency table (points to the start of one
    // of seven 4K tunes in myTuneData)
    const uInt8* myFrequencyImage{nullptr};

    // The counter register for the data fetcher
    uInt16 myTunePosition{0};

    // The music mode counters
    std::array<uInt32, 3> myMusicCounters{0};

    // The music frequency
    std::array<uInt32, 3> myMusicFrequencies{0};

    // Flags that last byte peeked was A9 (LDA #)
    bool myLDAimmediate{false};

    // The random number generator register
    uInt32 myRandomNumber{0x2B435044};

    // The time after which the first request of a load/save operation
    // will actually be completed
    // Due to Harmony EEPROM constraints, a read/write isn't instantaneous,
    // so we need to emulate the delay as well
    uInt64 myRamAccessTimeout{0};

    // Full pathname of the file to use when emulating load/save
    // of internal RAM to Harmony cart EEPROM
    string myEEPROMFile;

    // System cycle count from when the last update to music data fetchers occurred
    uInt64 myAudioCycles{0};

    // Fractional DPC music OSC clocks unused during the last update
    double myFractionalClocks{0.0};

    // Indicates the offset into the ROM image (aligns to current bank)
    uInt16 myBankOffset{0};

    static const std::array<uInt32, 63> ourFrequencyTable;

  private:
    // Following constructors and assignment operators not supported
    CartridgeCTY() = delete;
    CartridgeCTY(const CartridgeCTY&) = delete;
    CartridgeCTY(CartridgeCTY&&) = delete;
    CartridgeCTY& operator=(const CartridgeCTY&) = delete;
    CartridgeCTY& operator=(CartridgeCTY&&) = delete;
};

#endif
