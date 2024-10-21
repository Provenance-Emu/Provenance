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

#ifndef CARTRIDGEENHANCED_HXX
#define CARTRIDGEENHANCED_HXX

class System;

#include "bspf.hxx"
#include "Cart.hxx"
#include "PlusROM.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartEnhancedWidget.hxx"
#endif

/**
  Enhanced cartridge base class used for multiple cart types.

  @author  Thomas Jentzsch
*/
class CartridgeEnhanced : public Cartridge
{
  friend class CartridgeEnhancedWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeEnhanced(const ByteBuffer& image, size_t size,
                      string_view md5, const Settings& settings,
                      size_t bsSize);
    ~CartridgeEnhanced() override = default;

  public:
    /**
      Install cartridge in the specified system.  Invoked by the system
      when the cartridge is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Install pages for the specified bank in the system.

      @param bank     The bank that should be installed in the system
      @param segment  The segment the bank should be using

      @return  true, if bank has changed
    */
    bool bank(uInt16 bank, uInt16 segment = 0) override;

    /**
      Get the current bank.

      @param address  The address to use when querying the bank
    */
    uInt16 getBank(uInt16 address = 0) const override;

    /**
      Get the current bank for a bank segment.

      @param segment  The segment to get the bank for
    */
    uInt16 getSegmentBank(uInt16 segment = 0) const override;

    /**
      Query the number of banks supported by the cartridge.
    */
    uInt16 romBankCount() const override;

    /**
      Query the number of RAM 'banks' supported by the cartridge.
    */
    uInt16 ramBankCount() const override;

    /**
      Query whether the current PC allows code execution.

      @return  true, if code execution is allowed
    */
    bool canExecute(uInt16 PC) const override {
      return !(PC & 0x1000) || (PC & ROM_MASK) >= myRomOffset || executableCartRam();
    }

    /**
      Query whether the cart RAM allows code execution.

      @return  true, if code execution is allowed
    */
    virtual bool executableCartRam() const { return true; }

    /**
      Get the number of segments supported by the cartridge.
    */
    uInt16 segmentCount() const override { return myBankSegs; }

    /**
      Check if the segment at that address contains a RAM bank

      @param  address  The address which defines the segment

      @return  true, if the segment is currently mapped to a RAM bank
     */
    bool isRamBank(uInt16 address) const;

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

    /**
      Get the hotspot in ROM address space.

      @return  The first hotspot address (usually in ROM) space or 0
    */
    virtual uInt16 hotspot() const { return 0; }
    // TODO: handle cases where there the hotspots cover multiple pages

    /**
      Answer whether this is a PlusROM cart.  Note that until the
      initialize method has been called, this will always return false.

      @return  Whether this is actually a PlusROM cart
    */
    bool isPlusROM() const override { return myPlusROM->isValid(); }

    /**
      Set the callback for displaying messages
    */
    void setMessageCallback(const messageCallback& callback) override
    {
      Cartridge::setMessageCallback(callback);
      if(myPlusROM->isValid())
        myPlusROM->setMessageCallback(myMsgCallback);
    }

  protected:
    // The '2 ^ N = bank segment size' exponent
    uInt16 myBankShift{BANK_SHIFT};             // default 12 (-> one 4K segment)

    // The size of a bank's segment
    uInt16 myBankSize{static_cast<uInt16>(4_KB)};

    // The mask for a bank segment
    uInt16 myBankMask{ROM_MASK};

    // Usually myBankShift - 1
    uInt16 myRamBankShift{0};

  protected:
    // The extra RAM size
    size_t myRamSize{RAM_SIZE};                 // default 0

    // The number of RAM banks
    uInt16 myRamBankCount{RAM_BANKS};           // default 0

    // The mask for the extra RAM
    uInt16 myRamMask{0};                        // RAM_SIZE - 1, but doesn't matter when RAM_SIZE is 0

    // The number of segments a bank is split into (default 1)
    uInt16 myBankSegs{1};

    // The offset into ROM space for reading from ROM
    // This is zero for types without RAM and with banked RAM
    // - xxSC  = 0x0100
    // - FA(2) = 0x0200
    // - CV    = 0x0800
    uInt16 myRomOffset{0};

    // The offset into ROM space for writing to RAM
    // - xxSC  = 0x0000
    // - FA(2) = 0x0000
    // - CV    = 0x0400
    uInt16 myWriteOffset{0};

    // The offset into ROM space for reading from RAM
    // - xxSC  = 0x0080
    // - FA(2) = 0x0100
    // - CV    = 0x0000
    uInt16 myReadOffset{0};

    // Flag, true if write port is at high and read port is at low address
    bool myRamWpHigh{RAM_HIGH_WP};

    // Pointer to a dynamically allocated ROM image of the cartridge
    ByteBuffer myImage{nullptr};

    // Contains the offset into the ROM image for each of the bank segments
    DWordBuffer myCurrentSegOffset{nullptr};

    // Indicates whether to use direct ROM peeks or not
    bool myDirectPeek{true};

    // Pointer to a dynamically allocated RAM area of the cartridge
    ByteBuffer myRAM{nullptr};

    // The size of the ROM image
    size_t mySize{0};

    // Handle PlusROM functionality, if available
    unique_ptr<PlusROM> myPlusROM;

  protected:
    // The mask for 6507 address space
    static constexpr uInt16 ADDR_MASK = 0x1FFF;

    // The offset into address space for accessing ROM
    static constexpr uInt16 ROM_OFFSET = 0x1000;

    // The mask for ROM address space
    static constexpr uInt16 ROM_MASK = 0x0FFF;

  private:
    // Calculated as: log(ROM bank segment size) / log(2)
    static constexpr uInt16 BANK_SHIFT = 12;  // default = 4K

    // The size of extra RAM in ROM address space
    static constexpr size_t RAM_SIZE = 0;     // default = none

    // The number of RAM banks
    static constexpr uInt16 RAM_BANKS = 0;

    // Write port for extra RAM is at low address by default
    static constexpr bool RAM_HIGH_WP = false;

    // The maximum shift (for a 4K bank size)
    static constexpr uInt16 MAX_BANK_SHIFT = 12;  // -> 4K

  protected:
    /**
      Check hotspots and switch bank if triggered.

      @param address  The address to check
      @param value    The optional value used to determine the bank switched to

      @return  True if a bank switch happened.
    */
    virtual bool checkSwitchBank(uInt16 address, uInt8 value) = 0;

    /**
      Calculate the number of segments supported by the cartridge.
    */
    virtual uInt16 calcNumSegments() const;

  private:
    /**
      Get the ROM's startup bank.

      @return  The bank the ROM will start in
    */
    virtual uInt16 getStartBank() const { return 0; }

    /**
      Get the ROM offset of the segment of the given address.

      @param address  The address to get the offset for
      @return  The calculated offset
    */
    uInt32 romAddressSegmentOffset(uInt16 address) const {
      return myCurrentSegOffset[((address & ROM_MASK) >> myBankShift) % myBankSegs];
    }

    /**
      Get the RAM offset of the segment of the given address.
      The RAM banks are half the size of a ROM bank.

      @param address  The address to get the offset for
      @return  The calculated offset
    */
    uInt16 ramAddressSegmentOffset(uInt16 address) const {
      return static_cast<uInt16>(
        (myCurrentSegOffset[((address & ROM_MASK) >> myBankShift) % myBankSegs] - mySize) 
        >> (myBankShift - myRamBankShift));
    }

  private:
    // Following constructors and assignment operators not supported
    CartridgeEnhanced() = delete;
    CartridgeEnhanced(const CartridgeEnhanced&) = delete;
    CartridgeEnhanced(CartridgeEnhanced&&) = delete;
    CartridgeEnhanced& operator=(const CartridgeEnhanced&) = delete;
    CartridgeEnhanced& operator=(CartridgeEnhanced&&) = delete;
};

#endif
