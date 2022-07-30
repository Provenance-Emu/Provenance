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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef DISTELLA_HXX
#define DISTELLA_HXX

#include <queue>

#include "Base.hxx"
#include "CartDebug.hxx"
#include "Device.hxx"
#include "bspf.hxx"

/**
  This class is a wrapper around the Distella code.  Much of the code remains
  exactly the same, except that generated data is now redirected to a
  DisassemblyList structure rather than being printed.

  All 7800-related stuff has been removed, as well as some commandline options.
  Over time, some of the configurability of Distella may be added again.

  @authors  Stephen Anthony and Thomas Jentzsch
            Original distella developers (http://distella.sf.net)
*/
class DiStella
{
  public:
    // A list of options that can be applied to the disassembly
    // This will eventually grow to include all options supported by
    // standalone Distella
    struct Settings {
      Common::Base::Fmt gfxFormat{Common::Base::Fmt::_2};
      bool resolveCode{true};   // Attempt to detect code vs. data sections
      bool showAddresses{true}; // Show PC addresses (always off for external output)
      bool aFlag{false};        // Turns 'A' off in accumulator instructions (-a in Distella)
      bool fFlag{true};         // Forces correct address length (-f in Distella)
      bool rFlag{false};        // Relocate calls out of address range (-r in Distella)
      bool bFlag{false};        // Process break routine (-b in Distella)
      int bytesWidth{8+1};      // Number of bytes to use per line (with .byte xxx)
    };
    static Settings settings;  // Default settings

  public:
    /**
      Disassemble the current state of the System from the given start address.

      @param dbg         The CartDebug instance containing all label information
      @param list        The results of the disassembly are placed here
      @param info        Various info about the current bank
      @param settings    The various distella flags/options to use
      @param labels      Array storing label info determined by Distella
      @param directives  Array storing directive info determined by Distella
      @param reserved    The TIA/RIOT addresses referenced in the disassembled code
    */
    DiStella(const CartDebug& dbg, CartDebug::DisassemblyList& list,
             CartDebug::BankInfo& info, const DiStella::Settings& settings,
             CartDebug::AddrTypeArray& labels,
             CartDebug::AddrTypeArray& directives,
             CartDebug::ReservedEquates& reserved);

  private:
    /**
    Enumeration of the addressing type (RAM, ROM, RIOT, TIA...)
    */
    enum class AddressType : int
    {
      INVALID,
      ROM,
      TIA,
      RIOT,
      ROM_MIRROR,
      ZP_RAM
    };


  private:
    // Indicate that a new line of disassembly has been completed
    // In the original Distella code, this indicated a new line to be printed
    // Here, we add a new entry to the DisassemblyList
    void addEntry(Device::AccessType type);

    // Process directives given in the list
    // Directives are basically the contents of a distella configuration file
    void processDirectives(const CartDebug::DirectiveList& directives);

    // These functions are part of the original Distella code
    void disasm(uInt32 distart, int pass);
    void disasmPass1(CartDebug::AddressList& debuggerAddresses);
    void disasmFromAddress(uInt32 distart);

    bool check_range(uInt16 start, uInt16 end) const;
    AddressType mark(uInt32 address, uInt16 mask, bool directive = false);
    bool checkBit(uInt16 address, uInt16 mask, bool useDebugger = true) const;
    bool checkBits(uInt16 address, uInt16 mask, uInt16 notMask, bool useDebugger = true) const;
    void outputGraphics();
    void outputColors();
    void outputBytes(Device::AccessType type);

    // Convenience methods to generate appropriate labels
    inline void labelA12High(stringstream& buf, uInt8 op, uInt16 addr, AddressType labfound)
    {
      if(!myDbg.getLabel(buf, addr, true))
        buf << "L" << Common::Base::HEX4 << addr;
    }
    inline void labelA12Low(stringstream& buf, uInt8 op, uInt16 addr, AddressType labfound)
    {
      myDbg.getLabel(buf, addr, ourLookup[op].rw_mode == RWMode::READ, 2);
      if (labfound == AddressType::TIA)
      {
        if(ourLookup[op].rw_mode == RWMode::READ)
          myReserved.TIARead[addr & 0x0F] = true;
        else
          myReserved.TIAWrite[addr & 0x3F] = true;
      }
      else if (labfound == AddressType::RIOT)
        myReserved.IOReadWrite[(addr & 0xFF) - 0x80] = true;
      else if (labfound == AddressType::ZP_RAM)
        myReserved.ZPRAM[(addr & 0xFF) - 0x80] = true;
    }

  private:
    const CartDebug& myDbg;
    CartDebug::DisassemblyList& myList;
    const Settings& mySettings;
    CartDebug::ReservedEquates& myReserved;
    stringstream myDisasmBuf;
    std::queue<uInt16> myAddressQueue;
    uInt16 myOffset{0}, myPC{0}, myPCEnd{0};
    uInt16 mySegType{0};

    struct resource {
      uInt16 start{0};
      uInt16 end{0};
      uInt16 length{0};
    } myAppData;

    /* Stores info on how each address is marked, both in the general
       case as well as when manual directives are enabled (in which case
       the directives take priority
       The address mark type is defined in CartDebug.hxx
    */
    CartDebug::AddrTypeArray& myLabels;
    CartDebug::AddrTypeArray& myDirectives;

    /**
      Enumeration of the 6502 addressing modes
    */
    enum class AddressingMode : uInt8
    {
      IMPLIED, ACCUMULATOR, IMMEDIATE,
      ZERO_PAGE, ZERO_PAGE_X, ZERO_PAGE_Y,
      ABSOLUTE, ABSOLUTE_X, ABSOLUTE_Y,
      ABS_INDIRECT, INDIRECT_X, INDIRECT_Y,
      RELATIVE, ASS_CODE
    };

    /**
      Enumeration of the 6502 access modes
    */
    enum class AccessMode : uInt8
    {
      NONE, AC, XR, YR, SP, SR, PC, IMM, ZERO, ZERX, ZERY,
      ABS, ABSX, ABSY, AIND, INDX, INDY, REL, FC, FD, FI,
      FV, ADDR,

      ACIM, /* Source: AC & IMMED (bus collision) */
      ANXR, /* Source: AC & XR (bus collision) */
      AXIM, /* Source: (AC | #EE) & XR & IMMED (bus collision) */
      ACNC, /* Dest: AC and Carry = Negative */
      ACXR, /* Dest: AC, XR */

      SABY, /* Source: (ABS_Y & SP) (bus collision) */
      ACXS, /* Dest: AC, XR, SP */
      STH0, /* Dest: Store (src & Addr_Hi+1) to (Addr +0x100) */
      STH1,
      STH2,
      STH3
    };

    /**
      Enumeration of the 6502 read/write mode
      (if the opcode is reading or writing its operand)
    */
    enum class RWMode : uInt8
    {
      READ, WRITE, NONE
    };

    struct Instruction_tag {
      const char* const mnemonic{nullptr};
      AddressingMode addr_mode{AddressingMode::IMPLIED};
      AccessMode     source{AccessMode::NONE};
      RWMode         rw_mode{RWMode::NONE};
      uInt8          cycles{0};
      uInt8          bytes{0};
    };
    static const std::array<Instruction_tag, 256> ourLookup;

  private:
    // Following constructors and assignment operators not supported
    DiStella() = delete;
    DiStella(const DiStella&) = delete;
    DiStella(DiStella&&) = delete;
    DiStella& operator=(const DiStella&) = delete;
    DiStella& operator=(DiStella&&) = delete;
};

#endif
