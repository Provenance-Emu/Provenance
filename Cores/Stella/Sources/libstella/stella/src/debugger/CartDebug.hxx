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

#ifndef CART_DEBUG_HXX
#define CART_DEBUG_HXX

class Settings;
class CartDebugWidget;

// Function type for CartDebug instance methods
class CartDebug;
using CartMethod = int (CartDebug::*)();

#include <map>
#include <set>
#include <list>

#include "bspf.hxx"
#include "DebuggerSystem.hxx"
#include "Device.hxx"

class CartState : public DebuggerState
{
  public:
    ByteArray ram;    // The actual data values
    ShortArray rport; // Address for reading from RAM
    ShortArray wport; // Address for writing to RAM
    string bank;      // Current banking layout
};

class CartDebug : public DebuggerSystem
{
  // The disassembler needs special access to this class
  friend class DiStella;

  public:
    struct DisassemblyTag {
      Device::AccessType type{Device::NONE};
      uInt16 address{0};
      string label;
      string disasm;
      string ccount;
      string ctotal;
      string bytes;
      bool hllabel{false};
    };
    using DisassemblyList = vector<DisassemblyTag>;
    struct Disassembly {
      DisassemblyList list;
      int fieldwidth{0};
    };

    // Determine 'type' of address (ie, what part of the system accessed)
    enum class AddrType { TIA, IO, ZPRAM, ROM };
    static AddrType addressType(uInt16 addr);

  public:
    CartDebug(Debugger& dbg, Console& console, const OSystem& osystem);
    ~CartDebug() override = default;

    const DebuggerState& getState() override;
    const DebuggerState& getOldState() override { return myOldState; }

    void saveOldState() override;
    string toString() override;

    // Used to get/set the debug widget, which contains cart-specific
    // functionality
    CartDebugWidget* getDebugWidget() const { return myDebugWidget; }
    void setDebugWidget(CartDebugWidget* w) { myDebugWidget = w; }


    // Return the address of the last CPU read
    int lastReadAddress();
    // Return the address of the last CPU write
    int lastWriteAddress();

    // Return the base (= non-mirrored) address of the last CPU read
    int lastReadBaseAddress();
    // Return the base (= non-mirrored) address of the last CPU write
    int lastWriteBaseAddress();

    /**
      Disassemble from the given address and its bank using the Distella disassembler
      Address-to-label mappings (and vice-versa) are also determined here

      @param address The address to start with
      @param force  Force a re-disassembly, even if the state hasn't changed

      @return  True if disassembly changed from previous call, else false
    */
    bool disassembleAddr(uInt16 address, bool force = false);

    /**
      Disassemble from the current PC and its bank using the Distella disassembler
      Address-to-label mappings (and vice-versa) are also determined here

      @param force  Force a re-disassembly, even if the state hasn't changed

      @return  True if disassembly changed from previous call, else false
    */
    bool disassemblePC(bool force = false);

    /**
      Disassemble the given bank using the Distella disassembler
      Address-to-label mappings (and vice-versa) are also determined here

      @param bank  The bank to disassemble

      @return  True if disassembly changed from previous call, else false
    */
    bool disassembleBank(int bank);


    // First, a call is made to disassemble(), which updates the disassembly
    // list, is required; it will figure out when an actual complete
    // disassembly is required, and when the previous results can be used
    //
    // Later, successive calls to disassembly() simply return the
    // previous results; no disassembly is done in this case
    /**
      Get the results from the most recent call to disassemble()
    */
    const Disassembly& disassembly() const { return myDisassembly; }

    /**
      Determine the line in the disassembly that corresponds to the given address.

      @param address  The address to search for

      @return Line number of the address, else -1 if no such address exists
    */
    int addressToLine(uInt16 address) const;

    /**
      Disassemble from the starting address the specified number of lines.
      Note that automatic code determination is turned off for this method;

      @param start  The start address for disassembly
      @param lines  The number of disassembled lines to generate

      @return  The disassembly represented as a string
    */
    string disassembleLines(uInt16 start, uInt16 lines) const;

    /**
      Add a directive to the disassembler.  Directives are basically overrides
      for the automatic code determination algorithm in Distella, since some
      things can't be automatically determined.  For now, these directives
      have exactly the same syntax as in a distella configuration file.

      @param type   Currently, CODE/DATA/GFX/PGFX/COL/PCOL/BCOL/AUD/ROW are supported
      @param start  The start address (inclusive) to mark with the given type
      @param end    The end address (inclusive) to mark with the given type
      @param bank   Bank to which these directive apply (0 indicated current bank)

      @return  True if directive was added, else false if it was removed
    */
    bool addDirective(Device::AccessType type, uInt16 start, uInt16 end,
                      int bank = -1);

    // The following are convenience methods that query the cartridge object
    // for the desired information.
    /**
      Get the current bank in use by the cartridge
      (non-const because of use in YaccParser)
    */
    int getBank(uInt16 addr);


    int getPCBank();

    /**
      Get the total number of banks supported by the cartridge.
    */
    int romBankCount() const;

    /**
      Add a label and associated address.
      Labels that reference either TIA or RIOT spaces will not be processed.
    */
    bool addLabel(const string& label, uInt16 address);

    /**
      Remove the given label and its associated address.
      Labels that reference either TIA or RIOT spaces will not be processed.
    */
    bool removeLabel(const string& label);

    /**
      Accessor methods for labels and addresses

      The mapping from address to label can be one-to-many (ie, an
      address can have different labels depending on its context, and
      whether its being read or written; if isRead is true, the context
      is a read, else it's a write
      If places is not -1 and a label hasn't been defined, return a
      formatted hexidecimal address
    */
    bool getLabel(ostream& buf, uInt16 addr, bool isRead,
                  int places = -1, bool isRam = false) const;
    string getLabel(uInt16 addr, bool isRead,
                    int places = -1, bool isRam = false) const;
    int getAddress(const string& label) const;

    /**
      Load constants from list file (as generated by DASM).
    */
    string loadListFile();

    /**
      Load user equates from symbol file (as generated by DASM).
    */
    string loadSymbolFile();

    /**
      Load/save Distella config files (Distella directives)
    */
    string loadConfigFile();
    string saveConfigFile();

    /**
      Save disassembly and ROM file
    */
    string saveDisassembly(string path = EmptyString);
    string saveRom(string path = EmptyString);

    /**
      Save access counters file
    */
    string saveAccessFile(string path = EmptyString);

    /**
      Show Distella directives (both set by the user and determined by Distella)
      for the given bank (or all banks, if no bank is specified).
    */
    string listConfig(int bank = -1);

    /**
      Clear Distella directives (set by the user) for the given bank
      (or all banks, if no bank is specified.)
    */
    string clearConfig(int bank = -1);

    /**
      Methods used by the command parser for tab-completion
      In this case, return completions from the equate list(s)
    */
    void getCompletions(string_view in, StringList& completions) const;

    // Convert given address to corresponding access type and append to buf
    void accessTypeAsString(ostream& buf, uInt16 addr) const;

    // Convert access enum type to corresponding string and append to buf
    static void AccessTypeAsString(ostream& buf, Device::AccessType type);

  private:
    using AddrToLineList = std::map<uInt16, int>;
    using AddrToLabel = std::map<uInt16, string>;
    using LabelToAddr = std::map<string, uInt16,
        std::function<bool(const string&, const string&)>>;

    using AddrTypeArray = std::array<uInt16, 0x1000>;

    struct DirectiveTag {
      Device::AccessType type{Device::NONE};
      uInt16 start{0};
      uInt16 end{0};
    };
    using AddressList = std::list<uInt16>;
    using DirectiveList = std::list<DirectiveTag>;

    struct BankInfo {
      uInt16 start{0};             // start of address space
      uInt16 end{0};               // end of address space
      uInt16 offset{0};            // ORG value
      size_t size{0};              // size of a bank (in bytes)
      AddressList addressList;     // addresses which PC has hit
      DirectiveList directiveList; // overrides for automatic code determination
    };

    // Address type information determined by Distella
    AddrTypeArray myDisLabels, myDisDirectives;

    // Information on equates used in the disassembly
    struct ReservedEquates {
      std::array<bool, 16>  TIARead{false};
      std::array<bool, 64>  TIAWrite{false};
      std::array<bool, 32>  IOReadWrite{false};
      std::array<bool, 128> ZPRAM{false};
      AddrToLabel Label{};
      bool breakFound{false};
    };
    ReservedEquates myReserved;

    /**
      Disassemble from the given address using the Distella disassembler
      Address-to-label mappings (and vice-versa) are also determined here

      @param bank   The current bank to disassemble
      @param PC     A program counter to start with
      @param force  Force a re-disassembly, even if the state hasn't changed

      @return  True if disassembly changed from previous call, else false
    */
    bool disassemble(int bank, uInt16 PC, Disassembly& disassembly,
                     AddrToLineList& addrToLineList, bool force = false);

    // Actually call DiStella to fill the DisassemblyList structure
    // Return whether the search address was actually in the list
    bool fillDisassemblyList(BankInfo& bankinfo, Disassembly& disassembly,
                             AddrToLineList& addrToLineList, uInt16 search);

    // Analyze of bank of ROM, generating a list of Distella directives
    // based on its disassembly
    void getBankDirectives(ostream& buf, const BankInfo& info) const;

    // Get access enum type from 'flags', taking precendence into account
    static Device::AccessType accessTypeAbsolute(Device::AccessFlags flags);

    // Convert all access types in 'flags' to corresponding string and
    // append to buf
    static void AccessTypeAsString(ostream& buf, Device::AccessFlags flags);

  private:
    const OSystem& myOSystem;

    CartState myState;
    CartState myOldState;

    CartDebugWidget* myDebugWidget{nullptr};

    // A complete record of relevant diassembly information for each bank
    // (ROM banks, RAM banks, ZP RAM)
    vector<BankInfo> myBankInfo;

    // Used for the disassembly display, and mapping from addresses
    // to corresponding lines of text in that display
    Disassembly myDisassembly;
    AddrToLineList myAddrToLineList;
    bool myAddrToLineIsROM{true};

    // Mappings from label to address (and vice versa) for items
    // defined by the user (either through a DASM symbol file or manually
    // from the commandline in the debugger)
    AddrToLabel myUserLabels;
    LabelToAddr myUserAddresses;

    // Mappings from label to address (and vice versa) for constants
    // defined through a DASM lst file
    // AddrToLabel myUserCLabels;
    // LabelToAddr myUserCAddresses;

    // Mappings for labels to addresses for system-defined equates
    // Because system equate addresses can have different names
    // (depending on access in read vs. write mode), we can only create
    // a mapping from labels to addresses; addresses to labels are
    // handled differently
    LabelToAddr mySystemAddresses;

    // The maximum length of all labels currently defined
    uInt16 myLabelLength{8};  // longest pre-defined label

    /// Table of instruction mnemonics
    static std::array<string_view, 16>  ourTIAMnemonicR; // read mode
    static std::array<string_view, 64>  ourTIAMnemonicW; // write mode
    static std::array<string_view, 32>  ourIOMnemonic;
    static std::array<string_view, 128> ourZPMnemonic;

  private:
    // Following constructors and assignment operators not supported
    CartDebug() = delete;
    CartDebug(const CartDebug&) = delete;
    CartDebug(CartDebug&&) = delete;
    CartDebug& operator=(const CartDebug&) = delete;
    CartDebug& operator=(CartDebug&&) = delete;
};

#endif
