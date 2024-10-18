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

#ifndef CARTRIDGE_HXX
#define CARTRIDGE_HXX

class Properties;
class FSNode;
class CartDebugWidget;
class CartRamWidget;
class GuiObject;
class Settings;

#include <functional>

#include "bspf.hxx"
#include "Device.hxx"
#ifdef DEBUGGER_SUPPORT
  namespace GUI {
    class Font;
  }
#endif

/**
  A cartridge is a device which contains the machine code for a
  game and handles any bankswitching performed by the cartridge.
  A 'bank' is defined as a 4K block that is visible in the
  0x1000-0x2000 area (or its mirrors).

  @author  Bradford W. Mott
*/
class Cartridge : public Device
{
  public:
    using StartBankFromPropsFunc = std::function<int()>;

    /**
      Callback type for general cart messages
    */
    using messageCallback = std::function<void(const string&)>;

    // Maximum size of a ROM cart that Stella can support
    static constexpr size_t maxSize() { return 512_KB; }

  public:
    /**
      Create a new cartridge

      @param settings  A reference to the various settings (read-only)
      @param md5       The md5sum of the cart image
    */
    Cartridge(const Settings& settings, string_view md5);
    ~Cartridge() override = default;

    /**
      Set/query some information about this cartridge.
    */
    void setAbout(string_view about, string_view type, string_view id);
    const string& about() const { return myAbout; }
    const string& detectedType() const { return myDetectedType; }
    const string& multiCartID() const  { return myMultiCartID;  }

    /**
      Save the internal (patched) ROM image.

      @param out  The output file to save the image
    */
    bool saveROM(const FSNode& out) const;

    /**
      Lock/unlock bankswitching and other hotspot capabilities. The debugger
      will lock the hotspots before querying the cart state, otherwise reading
      values could inadvertantly cause e.g. a bankswitch to occur.
    */
    void lockHotspots()   { myHotspotsLocked = true;  }
    void unlockHotspots() { myHotspotsLocked = false; }
    bool hotspotsLocked() const { return myHotspotsLocked; }

    void enableRandomHotspots(bool enable) { myRandomHotspots = enable; }

    /**
      Get the default startup bank for a cart.  This is the bank where
      the system will look at address 0xFFFC to determine where to
      start running code.

      @return  The startup bank
    */
    uInt16 startBank() const { return myStartBank; }

    /**
      Set the function to use when we want to query the 'Cartridge.StartBank'
      ROM property.
    */
    void setStartBankFromPropsFunc(const StartBankFromPropsFunc& func) {
      myStartBankFromPropsFunc = func;
    }

    /**
      Answer whether the bank has changed since the last time this
      method was called.  Each cart class is able to override this
      method to deal with its specific functionality.  In those cases,
      the derived class is still responsible for calling this base
      function.

      @return  Whether the bank was changed
    */
    virtual bool bankChanged();

    /**
      Query the internal RAM size of the cart.

      @return The internal RAM size
    */
    virtual uInt32 internalRamSize() const { return 0; }

    /**
      Read a byte from cart internal RAM.

      @return The value of the interal RAM byte
    */
    virtual uInt8 internalRamGetValue(uInt16 addr) const { return 0; }

    /**
      Answer whether this is a PlusROM cart.  Note that until the
      initialize method has been called, this will always return false.

      @return  Whether this is actually a PlusROM cart
    */
    virtual bool isPlusROM() const { return false; }

    /**
      Set the callback for displaying messages
    */
    virtual void setMessageCallback(const messageCallback& callback)
    {
      myMsgCallback = callback;
    }

  #ifdef DEBUGGER_SUPPORT
    /**
      To be called at the start of each instruction.
      Clears information about all accesses to cart RAM.
    */
    void clearAllRAMAccesses() {
      myRamReadAccesses.clear();
      myRamWriteAccess = 0;
    }

    /**
      To be called at the end of each instruction.
      Answers whether an access in the last instruction cycle generated
      an illegal read RAM access.

      @return  Address of illegal access if one occurred, else 0
    */
    inline uInt16 getIllegalRAMReadAccess() const {
      return myRamReadAccesses.size() > 0 ? myRamReadAccesses[0] : 0;
    }

    /**
      To be called at the end of each instruction.
      Answers whether an access in the last instruction cycle generated
      an illegal RAM write access.

      @return  Address of illegal access if one occurred, else 0
    */
    inline uInt16 getIllegalRAMWriteAccess() const { return myRamWriteAccess; }

    /**
      Query the access counters

      @return  The access counters as comma separated string
    */
    string getAccessCounters() const override;

    /**
      Determine the bank's origin

      @param bank  The bank to query
      @param PC    The current PC
      @return  The origin of the bank
    */
    uInt16 bankOrigin(uInt16 bank, uInt16 PC = 0) const;
  #endif

  public:
    //////////////////////////////////////////////////////////////////////
    // The following methods are cart-specific and will usually be
    // implemented in derived classes.  Carts which don't support
    // bankswitching (for any reason) do not have to provide an
    // implementation for bankswitch-related methods.
    //////////////////////////////////////////////////////////////////////
    /**
      Set the specified bank.  This is used only when the bankswitching
      scheme defines banks in a standard format (ie, 0 for first bank,
      1 for second, etc).  Carts which will handle their own bankswitching
      completely or non-bankswitched carts can ignore this method.

      @param bank     The bank that should be installed in the system
      @param segment  The segment the bank should be using

      @return  true, if bank has changed
    */
    virtual bool bank(uInt16 bank, uInt16 segment = 0) { return false; }

    /**
      Get the current bank for the provided address. Carts which have only
      one bank (either real or virtual) always report that bank as zero.

      @param address  Query the bank used for this specific address
                      Derived classes are free to ignore this; it only
                      makes sense in some situations.
    */
    virtual uInt16 getBank(uInt16 address = 0) const { return 0; }

    /**
      Get the current bank for a bank segment.

      @param segment  The segment to get the bank for
    */
    virtual uInt16 getSegmentBank(uInt16 segment = 0) const { return getBank(); }

    /**
      Query the number of ROM 'banks' supported by the cartridge.  Note that
      this information is cart-specific, where each cart basically defines
      what a 'bank' is.

      For the normal Atari-manufactured carts, a standard bank is a 4K
      block that is directly accessible in the 4K address space.  In other
      cases where ROMs have 2K blocks in some preset area, the bankCount
      is the number of such blocks.  Finally, in some esoteric schemes,
      the number of ways that the addressing can change (multiple ROM and
      RAM segments at multiple access points) is so complicated that the
      cart will report having only one 'virtual' bank.
    */
    virtual uInt16 romBankCount() const { return 1; }

    /**
      Query the number of RAM 'banks' supported by the cartridge.  Note that
      this information is cart-specific, where each cart basically defines
      what a 'bank' is.
    */
    virtual uInt16 ramBankCount() const { return 0; }

    /**
      Query whether the current PC allows code execution.

      @return  true, if code execution is allowed
    */
    virtual bool canExecute(uInt16 PC) const { return true; }

    /**
      Get the number of segments supported by the cartridge.
    */
    virtual uInt16 segmentCount() const { return 1; }

    /**
      Get the size of a bank.

      @param bank  The bank to get the size for
      @return  The bank's size
    */
    virtual uInt16 bankSize(uInt16 bank = 0) const;

    /**
      Patch the cartridge ROM.

      @param address  The ROM address to patch
      @param value    The value to place into the address
      @return    Success or failure of the patch operation
    */
    virtual bool patch(uInt16 address, uInt8 value) = 0;

    /**
      Access the internal ROM image for this cartridge.

      @param size  Set to the size of the internal ROM image data
      @return  A reference to the internal ROM image data
    */
    virtual const ByteBuffer& getImage(size_t& size) const = 0;

    /**
      Get a descriptor for the cart name.

      @return The name of the cart
    */
    virtual string name() const = 0;

    /**
      Informs the cartridge about the name of the nvram file it will
      use; not all carts support this.

      @param path  The full path of the nvram file
    */
    virtual void setNVRamFile(string_view path) { }

    /**
      Thumbulator only supports 16-bit ARM code.  Some Harmony/Melody drivers,
      such as BUS and CDF, feature 32-bit ARM code subroutines.  This is used
      to pass values back to the cartridge class to emulate those subroutines.
    */
    virtual uInt32 thumbCallback(uInt8 function, uInt32 value1, uInt32 value2) { return 0; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get optional debugger widget responsible for displaying info about the cart.
      This can be used when the debugWidget runs out of space.
    */
    virtual CartDebugWidget* infoWidget(GuiObject* boss, const GUI::Font& lfont,
                                        const GUI::Font& nfont, int x, int y, int w, int h)
    {
      return nullptr;
    }

    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.  This will need to be overridden and implemented by
      each specific cart type, since the bankswitching/inner workings
      of each cart type can be very different from each other.
    */
    virtual CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
                                         const GUI::Font& nfont, int x, int y, int w, int h)
    {
      return nullptr;
    }
  #endif

  protected:
    /**
      Get a random value to use when a read from the write port happens.
      Sometimes a RWP means that RAM should be overwritten, sometimes not.

      Internally, this method also keeps track of illegal accesses.

      @param dest     The location to place the value, when an overwrite should happen
      @param address  The address of the illegal read
      @return  The value read, whether it is overwritten or not
    */
    uInt8 peekRAM(uInt8& dest, uInt16 address);

    /**
      Use the given value when writing to RAM.

      Internally, this method also keeps track of legal accesses, and removes
      them from the illegal list.

      @param dest     The final location (including address) to place the value
      @param address  The address of the legal write
      @param value    The value to write to the given address
    */
    void pokeRAM(uInt8& dest, uInt16 address, uInt8 value);

    /**
      Create an array that holds code-access information for every byte
      of the ROM (indicated by 'size').  Note that this is only used by
      the debugger, and is unavailable otherwise.

      @param size  The size of the code-access array to create
    */
    void createRomAccessArrays(size_t size);

    /**
      Fill the given RAM array with (possibly random) data.

      @param arr  Pointer to the RAM array
      @param size The size of the RAM array
      @param val  If provided, the value to store in the RAM array
    */
    void initializeRAM(uInt8* arr, size_t size, uInt8 val = 0) const;

    /**
      Set the start bank to be used when the cart is reset.  This method
      will take both randomization and properties settings into account.
      See the actual method for more information on the logic used.

      NOTE: If this method is used, it *must* be called from the cart reset()
            method, *not* from the c'tor.

      @param defaultBank  The default bank to use during reset, if
                          randomization or properties aren't being used

      @return  The bank number that was determined
    */
    uInt16 initializeStartBank(uInt16 defaultBank);

    /**
      Checks if initial RAM randomization is enabled.

      @return  Whether the initial RAM should be randomized
    */
    bool randomInitialRAM() const;

    /**
      Checks if startup bank randomization is enabled.

      @return  Whether the startup bank(s) should be randomized
    */
    virtual bool randomStartBank() const;

  protected:
    // Settings class for the application
    const Settings& mySettings;

    // Indicates if the bank has changed somehow (a bankswitch has occurred)
    bool myBankChanged{true};

    // The array containing information about every byte of ROM indicating
    // whether it is used as code, data, graphics etc.
    std::unique_ptr<Device::AccessFlags[]> myRomAccessBase;

    // The array containing information about every byte of ROM indicating
    // how often it is accessed.
    std::unique_ptr<Device::AccessCounter[]> myRomAccessCounter;


    // Contains address of illegal RAM write access or 0
    uInt16 myRamWriteAccess{0};

    // Total size of ROM access area (might include RAM too)
    uInt32 myAccessSize{0};

    // Callback to output messages
    messageCallback myMsgCallback{nullptr};

    // Semi-random values to use when a read from write port occurs
    std::array<uInt8, 256> myRWPRandomValues;

    // If myRandomHotspots is true, peeks to hotspots return semi-random values.
    bool myRandomHotspots{false};

  private:
    // The startup bank to use (where to look for the reset vector address)
    uInt16 myStartBank{0};

    // If myHotspotsLocked is true, ignore attempts at bankswitching. This is used
    // by the debugger, when disassembling/dumping ROM.
    bool myHotspotsLocked{false};

    // Contains various info about this cartridge
    // This needs to be stored separately from child classes, since
    // sometimes the information in both do not match
    // (ie, detected type could be '2in1' while name of cart is '4K')
    string myAbout, myDetectedType, myMultiCartID;

    // Used when we want the 'Cartridge.StartBank' ROM property
    StartBankFromPropsFunc myStartBankFromPropsFunc;

    // Used to answer whether an access in the last instruction cycle
    // generated an illegal read RAM access. Contains address of illegal
    // access.
    ShortArray myRamReadAccesses;

    // Following constructors and assignment operators not supported
    Cartridge() = delete;
    Cartridge(const Cartridge&) = delete;
    Cartridge(Cartridge&&) = delete;
    Cartridge& operator=(const Cartridge&) = delete;
    Cartridge& operator=(Cartridge&&) = delete;
};

#endif
