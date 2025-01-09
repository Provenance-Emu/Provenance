
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

#ifndef CARTRIDGE_E7_HXX
#define CARTRIDGE_E7_HXX

#include "System.hxx"
#include "bspf.hxx"
#include "Cart.hxx"
#include "PlusROM.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartE7Widget.hxx"
#endif


/**
  This is the abstract cartridge class for M-Network
  bankswitched games.
  In this bankswitching scheme the 2600's 4K cartridge address
  space is broken into two 2K segments.

  Kevin Horton describes E7 as follows:

  "Only M-Network used this scheme. This has to be the
  most complex method used in any cart! :-)  It allows
  for the capability of 2K of RAM; although it doesn't
  have to be used (in fact, only one cart used it).
  There are now 8 2K banks, instead of 4.  The last 2K
  in the cart always points to the last 2K of the ROM
  image, while the first 2K is selectable.  You access
  1FE0 to 1FE6 to select which 2K bank. Note that you
  cannot select the last 2K of the ROM image into the
  lower 2K of the cart!  Accessing 1FE7 selects 1K of
  RAM at 1000-17FF instead of ROM!  The 2K of RAM is
  broken up into two 1K sections.  One 1K section is
  mapped in at 1000-17FF if 1FE7 has been accessed.
  1000-13FF is the write port, while 1400-17FF is the
  read port.  The second 1K of RAM appears at 1800-19FF.
  1800-18FF is the write port while 1900-19FF is the
  read port.  You select which 256 byte block appears
  here by accessing 1FE8 to 1FEB.

  This cart reports having 8 banks; one for each of the possible
  7 banks in the lower 2K area, and the last for RAM in the lower
  2K area."

  There are 8K, 12K and 16K variations, with or without RAM.

  @author  Bradford W. Mott, Thomas Jentzsch
*/
class CartridgeE7 : public Cartridge
{
    friend class CartridgeE7Widget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
    */
    CartridgeE7(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings);
    ~CartridgeE7() override = default;

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
      Get the number of segments supported by the cartridge.
    */
    uInt16 segmentCount() const override { return NUM_SEGMENTS; }

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

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeE7"; }

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
        if (myPlusROM->isValid())
            myPlusROM->setMessageCallback(myMsgCallback);
    }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
      */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeE7Widget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  protected:
    /**
      Class initialization
    */
    void initialize(const ByteBuffer& image, size_t size);

    /**
      Install pages for the specified 256 byte bank of RAM

      @param bank The bank that should be installed in the system
    */
    void bankRAM(uInt16 bank);

    /**
      Check hotspots and switch bank if triggered.
    */
    void checkSwitchBank(uInt16 address);

    // Size of a ROM or RAM bank
    static constexpr size_t BANK_SIZE = 0x800; // 2K

  private:
    // Size of RAM in the cart
    static constexpr uInt32 RAM_SIZE = 0x800; // 1K + 4 * 256B = 2K
    // Number of segments within the 4K address space
    static constexpr uInt32 NUM_SEGMENTS = 2;

    /**
      Query the size of the BS type.
    */
    uInt16 romSize() const;

    void setAccess(uInt16 addrFrom, uInt16 size, uInt16 directOffset,
                   uInt8* directData, uInt16 codeOffset,
                   System::PageAccessType type, uInt16 addrMask = 0);

  private:
    // Pointer to a dynamically allocated ROM image of the cartridge
    ByteBuffer myImage;

    // Size of the ROM image
    size_t mySize{0};

    // The 2K of RAM
    std::array<uInt8, RAM_SIZE> myRAM;

    // Indicates which bank is in the segment
    std::array<uInt16, NUM_SEGMENTS> myCurrentBank;

    // Indicates which 256 byte bank of RAM is being used
    uInt16 myCurrentRAM{0};

    // The number of the RAM bank (== bankCount() - 1)
    uInt32 myRAMBank{0};

    // Handle PlusROM functionality, if available
    unique_ptr<PlusROM> myPlusROM;

  private:
    // Following constructors and assignment operators not supported
    CartridgeE7() = delete;
    CartridgeE7(const CartridgeE7&) = delete;
    CartridgeE7(CartridgeE7&&) = delete;
    CartridgeE7& operator=(const CartridgeE7&) = delete;
    CartridgeE7& operator=(CartridgeE7&&) = delete;
};

#endif
